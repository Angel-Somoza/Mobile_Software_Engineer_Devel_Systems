# Flash Scanner — Examen Mobile Software Engineer (Devel Systems)

Aplicación Flutter para registrar pedidos de demostración leyendo códigos QR con un **SDK nativo Android propio (Kotlin, AAR)**. Consulta el catálogo de DummyJSON, guarda todo en SQLite, funciona sin conexión y envía los pedidos pendientes de forma manual.

**Plataforma:** Android. iOS no implementado (no se contó con macOS/Xcode ni con un iPhone para compilar y probar).

## Enlaces de entrega

| Recurso | Enlace |
| --- | --- |
| Release | https://github.com/angel-somoza/mobile_software_engineer_devel_systems/releases/tag/v1.0.0 |
| AAR del SDK | https://github.com/angel-somoza/mobile_software_engineer_devel_systems/releases/download/v1.0.0/qr-scanner-release.aar |
| APK debug | https://github.com/angel-somoza/mobile_software_engineer_devel_systems/releases/download/v1.0.0/app-debug.apk |
| Video de demostración | https://www.youtube.com/watch?v=U7BxlihFlas |
| Commit entregado | Tag `v1.0.0` (el hash completo está en la descripción de la Release) |

## 1. Estructura del repositorio

```
.
├── sdk-android/            # SDK nativo Android (proyecto Gradle independiente)
│   ├── README.md           # Documentación detallada del SDK
│   └── qr-scanner/         # Módulo Android Library → genera qr-scanner-release.aar
├── app/                    # Aplicación Flutter
│   ├── lib/
│   │   ├── app/            # Estructura principal: barra inferior y botón de escaneo
│   │   ├── core/           # Base de datos (Drift), red, tema, widgets comunes
│   │   └── features/
│   │       ├── catalog/    # API REST, repositorio y pantalla de catálogo
│   │       ├── order/      # Carrito, guardado de pedidos, flujo de escaneo
│   │       ├── outbox/     # Cola de envío, estados, historial
│   │       └── scanner/    # Contrato Dart del puente (ScannerBridge)
│   ├── android/app/src/main/kotlin/.../MainActivity.kt   # Lado nativo del puente
│   └── test/               # Pruebas Dart
├── docs/qr/                # QR de prueba ya generados
└── AI_USAGE.md
```

## 2. Arquitectura y separación de responsabilidades

| Componente | Responsabilidad | Ubicación |
| --- | --- | --- |
| **SDK Android (Kotlin)** | Permiso de cámara, CameraX, ciclo de vida, decodificación con ML Kit, validación del QR, un único resultado terminal por sesión, cancelación, bloqueo de sesiones concurrentes | `sdk-android/qr-scanner` |
| **Puente Flutter** | Contrato Dart (`ScannerBridge`), MethodChannel, conversión de tipos, traducción de códigos de error a `ScanFailure` tipado | `app/lib/features/scanner` + `MainActivity.kt` |
| **App Flutter** | UI, cliente REST, catálogo, base de datos, carrito, pedidos y cola de envío | `app/lib` |

El SDK **no depende de Flutter** ni de las entidades de pedidos o del cliente REST. Solo devuelve un `productId: Int` o un error. Flutter decide si ese producto existe.

Organización por funcionalidad (*feature-first*) con capas `data`, `domain` y `presentation`. Gestión de estado e inyección de dependencias con **Riverpod** (`Provider`, `Notifier`, `StreamProvider`). La base local alimenta la interfaz mediante streams de Drift (`watch()`).

---

## 3. SDK Android — `qr-scanner`

Documentación completa en [`sdk-android/README.md`](sdk-android/README.md).

### API pública

```kotlin
object QrScanner {
    fun start(context: Context, onResult: (ScanResult) -> Unit)
    fun cancel()
}

sealed interface ScanResult {
    data class Success(val productId: Int) : ScanResult
    data class Failure(val error: ScanErrors) : ScanResult
}

enum class ScanErrors {
    PERMISSION_DENIED, CAMERA_UNAVAILABLE, INVALID_QR, CANCELLED, PROGRESS_SCAN
}
```

### Comportamiento

- `start()` crea una sesión (`ScanAttempt`) y abre `QrScannerActivity`, que pide el permiso de cámara si hace falta, enlaza CameraX (`Preview` + `ImageAnalysis`) y analiza los cuadros con ML Kit.
- **Un solo resultado por sesión:** `ScanAttempt` usa un `AtomicBoolean`. La primera terminación gana (éxito, error o cancelación) y todo lo demás se ignora, incluidas las detecciones repetidas y los callbacks tardíos.
- **El primer QR detectado termina la sesión**, aunque sea inválido. Para leer otro se inicia una sesión nueva.
- **Segunda apertura con una sesión activa:** `ScanManager` responde de inmediato `PROGRESS_SCAN` al segundo llamador sin afectar la sesión en curso.
- **Validación del QR** (`QrPayloadParser`): prefijo exacto `product:`, ID que cumple `[1-9][0-9]*` y cabe en `Int`. Si no cabe → `INVALID_QR` (motivo interno `OUT_OF_RANGE`).
- **Cierre de la pantalla:** cuando la sesión termina por cualquier motivo (incluido `cancel()` desde fuera), la fachada avisa a la Activity y esta se cierra.
- **Liberación de recursos:** al destruir la Activity se cierra el `BarcodeScanner`, se apaga el executor de análisis y la pantalla se da de baja de la fachada. CameraX se libera con el ciclo de vida.

### Decisión de ciclo de vida

| Evento | Comportamiento |
| --- | --- |
| Segundo plano (`onStop`: Home, pantalla apagada) | La sesión **se cancela** (`CANCELLED`) y la pantalla se cierra. No se restaura. |
| Cambio de configuración (tema, tamaño de letra, idioma) | No cancela (`isChangingConfigurations`); la Activity nueva retoma la sesión. La pantalla está fijada en vertical. |
| Diálogo de permiso | No cancela mientras se espera la respuesta del permiso. |
| Usuario cierra la pantalla (atrás) | `onDestroy` con `isFinishing` → `CANCELLED`. |

Elegí cancelar en lugar de restaurar la sesión para evitar callbacks tardíos y fugas. El llamador siempre recibe una respuesta terminal.

### Dependencias del AAR

| Dependencia | Versión | Licencia |
| --- | --- | --- |
| `androidx.camera:camera-core/camera2/lifecycle/view` | 1.6.2 | Apache 2.0 |
| `com.google.mlkit:barcode-scanning` (modelo **incluido** en el APK) | 17.3.0 | [ML Kit Terms](https://developers.google.com/ml-kit/terms) |

Uso la variante *bundled* de ML Kit, así que el modelo viaja dentro del APK y la lectura funciona **sin conexión** desde la instalación, sin descargar nada.

> El AAR **no incluye** sus dependencias transitivas (un AAR local no lleva POM). La aplicación que lo integre debe declararlas. CameraX 1.6.2 exige `compileSdk` 36 y AGP 8.9.1 o superior.

### Integración en una app Android nativa

```kotlin
dependencies {
    implementation(files("libs/qr-scanner-release.aar"))
    implementation("androidx.camera:camera-core:1.6.2")
    implementation("androidx.camera:camera-camera2:1.6.2")
    implementation("androidx.camera:camera-lifecycle:1.6.2")
    implementation("androidx.camera:camera-view:1.6.2")
    implementation("com.google.mlkit:barcode-scanning:17.3.0")
}
```

```kotlin
QrScanner.start(activity) { result ->
    runOnUiThread {
        when (result) {
            is ScanResult.Success -> println("Producto ${result.productId}")
            is ScanResult.Failure -> println("Error ${result.error}")
        }
    }
}

QrScanner.cancel()
```

El callback puede llegar desde el hilo de análisis; hay que volver al hilo principal antes de tocar la UI. El permiso `CAMERA` y la Activity se agregan solos por la fusión de manifiestos (manifest merge).

---

## 4. Puente Flutter

**Elección: MethodChannel.** El contrato es pequeño (dos métodos, un `int` y cinco códigos de error), así que la generación de código de Pigeon no compensaba. Los códigos se mapean de forma explícita y se prueban con un canal simulado (`TestDefaultBinaryMessenger`).

- Canal: `com.asomoza.flash_orders/qr_scanner`
- Lado nativo: `MainActivity.kt`
- Lado Dart: `lib/features/scanner/data/scanner_bridge.dart`

### Contrato

```dart
abstract interface class ScannerBridge {
  Future<int> scanProduct();   
  Future<void> cancelScan();
}
```

| Método del canal | Respuesta nativa | Resultado Dart |
| --- | --- | --- |
| `startScan` | `success(productId: Int)` | `int` |
| `startScan` | `error("permissionDenied")` | `ScanFailure(permissionDenied)` |
| `startScan` | `error("cameraUnavailable")` | `ScanFailure(cameraUnavailable)` |
| `startScan` | `error("invalidQr")` | `ScanFailure(invalidQr)` |
| `startScan` | `error("cancelled")` | `ScanFailure(cancelled)` |
| `startScan` | `error("scanInProgress")` | `ScanFailure(scanInProgress)` |
| Canal no registrado / código desconocido | — | `ScanFailure(unknown)` |
| `cancelScan` | `success(null)` | `void` |

En Kotlin, la traducción `ScanErrors → código` es un `when` exhaustivo sin `else`: si se agrega un valor al enum, la app no compila hasta asignarle un código. Así el contrato con Dart no depende de los nombres internos del SDK.

**Criterio de cancelación:** la cancelación se trata siempre como **error tipado** (`ScanFailure(cancelled)`), igual en todo el recorrido.

**Ninguna llamada queda pendiente:** cada `startScan` recibe exactamente una respuesta, porque el SDK garantiza un único resultado terminal y responde en el hilo principal. Al limpiar el motor Flutter (`cleanUpFlutterEngine`) se llama `QrScanner.cancel()`, y el `Result` pendiente se resuelve como `cancelled`.

---

## 5. Formato de los QR y datos de prueba

Contenido: `product:<id>`, con prefijo en minúsculas y un ID entero positivo sin ceros iniciales, signos ni espacios.

| Texto | Resultado |
| --- | --- |
| `product:1`, `product:2`, `product:3` | Válido |
| `product:0`, `product:-1`, `product:01` | `invalidQr` |
| `PRODUCT:1`, `product:abc`, `hola` | `invalidQr` |
| `product:99999999999` | `invalidQr` (fuera de rango de `Int`) |
| `product:999999` | Válido. DummyJSON responde 404 → "Producto no encontrado" (sin línea agregada) |

Las imágenes ya generadas están en [`docs/qr/`](docs/qr/) (un PNG por caso y `sheet.png` con todos). Para regenerarlas:


Basta con mostrarlos en otra pantalla.

**Escanear dos veces el mismo producto** (en sesiones distintas) **aumenta su cantidad en 1**.

---

## 6. REST (DummyJSON)

| Operación | Solicitud |
| --- | --- |
| Catálogo | `GET https://dummyjson.com/products?limit=30&select=id,title,price,thumbnail` |
| Producto por ID | `GET https://dummyjson.com/products/{id}` (404 → no encontrado) |
| Enviar pedido | `POST https://dummyjson.com/carts/add` con `Content-Type: application/json` |

Cuerpo del POST: `{"userId": 1, "products": [{"id": 1, "quantity": 2}, ...]}`. DummyJSON responde `201 Created`.

**Diferencia con el enunciado:** al catálogo le agrego el parámetro documentado `select` para pedir solo los campos usados. La respuesta baja de unos 44 KB a unos 4 KB y evita saltos de cuadros al abrir la app.

Timeouts: 10 s en el catálogo y 15 s en el envío. Valido el código HTTP y el JSON. El `id` que devuelve el POST se guarda solo como **referencia simulada**: no es la identidad del pedido y no se verifica con un GET posterior.

En compilaciones de desarrollo, un cliente HTTP decorador (`LoggingClient`) registra en logcat cada petición, su respuesta y el tiempo, con la etiqueta `[HTTP]`. En release no se registra nada.

---

## 7. Persistencia — SQLite con Drift

**Por qué Drift:** SQLite real con esquema tipado, transacciones, restricciones (`CHECK quantity > 0`) y consultas reactivas (`watch()`) que alimentan la UI directamente desde la base. Además permite una base en memoria para pruebas deterministas.

| Tabla | Campos |
| --- | --- |
| `products` | `id` (remoto), `title`, `price`, `thumbnailUrl`, `updatedAt` |
| `orders` | `id` local autoincremental (estable), `status`, `createdAt`, `updatedAt`, `attempts`, `lastError`, `remoteReference` |
| `order_lines` | `orderId`, `productId`, `productTitle` y `price` (copia al guardar), `quantity > 0` |

- **Refrescar el catálogo** hace un *upsert* de productos en un solo lote. Si la descarga falla, la copia anterior se conserva y los pedidos no se tocan.
- **Guardar un pedido** inserta la cabecera y las líneas en **una sola transacción**. Si falla una línea, no se guarda nada.
- **Búsqueda tras escanear:** primero la base local. Si el producto no está ahí, se consulta REST y se guarda. Sin red → "No disponible offline".
- El carrito todavía no guardado vive en memoria. Los pedidos guardados sobreviven al cierre de la app.

**Total estimado:** suma de `precio × cantidad` en `double`, sin descuentos, impuestos ni envío. Se muestra **redondeado a 2 decimales** (`toStringAsFixed(2)`) solo al mostrarlo y etiquetado como estimado. Los precios de DummyJSON están en dólares, por eso se muestran como `USD`. No intenta coincidir con los cálculos de DummyJSON.

---

## 8. Cola de envío y estados

| Estado interno | Etiqueta en la UI | Comportamiento |
| --- | --- | --- |
| `pending` | Pendiente | Guardado; entra en "Enviar pendientes" |
| `sending` | Enviando | Intento activo; no se puede reclamar otra vez |
| `confirmed` | Confirmado simulado | HTTP 2xx con JSON válido; **excluido** de envíos futuros |
| `failed` | Error | Fallo conocido (HTTP 4xx/5xx, sin conexión antes de enviar); entra en el siguiente lote y se puede reintentar desde su tarjeta |
| `unknown` | Resultado desconocido | Timeout, conexión perdida durante el envío, JSON inválido o app cerrada durante `sending`; **no entra en el lote**, solo se puede reintentar manualmente tras un aviso de posible duplicado |

Cada estado se muestra con texto, icono y color, nunca solo con color.

### Garantías locales contra duplicados

- **Reclamo atómico:** `claimForSending` pasa `pending|failed → sending` con un `UPDATE ... WHERE status IN (...)` dentro de una transacción. Si otro flujo ya lo reclamó, devuelve `null` y no se hace POST.
- **Doble toque:** `OutboxController` ignora "Enviar pendientes" mientras hay un lote en curso, y el botón se deshabilita.
- **Reintento:** reutiliza el mismo ID local y solo incrementa `attempts`.
- **Resultado tardío:** los estados finales solo se escriben si el pedido sigue en `sending`.
- **Recuperación al arrancar:** `recoverInterruptedSends()` pasa todo pedido en `sending` a `unknown`, con una explicación, antes de mostrar la primera pantalla.

### Clasificación de errores

| Fallo | Estado | Motivo |
| --- | --- | --- |
| `failed host lookup`, `network is unreachable`, `connection refused`, `connection failed` | `failed` | La solicitud no salió del teléfono |
| HTTP fuera de 2xx | `failed` | El servidor respondió un error conocido |
| Timeout | `unknown` | Pudo haber llegado |
| Conexión perdida durante el envío | `unknown` | Pudo haber llegado |
| 2xx con JSON inválido | `unknown` | No se puede confirmar |

La clasificación de errores de red se hace por el mensaje del sistema operativo, porque `package:http` reporta todos como `ClientException`. Si un mensaje no coincide, el error cae en `unknown`, que es el lado seguro: nunca se reenvía en silencio.

### Qué haría falta en una API real

- **Clave de idempotencia** (`Idempotency-Key` = UUID del pedido local) reconocida por el servidor, para que un reintento no cree un segundo pedido.
- **Consulta de estado** (`GET /orders?clientId=...` o por clave) para resolver los `unknown` sin reenviar.
- Un ID persistente devuelto por el servidor y códigos de error que distingan rechazos definitivos de transitorios.

---

## 9. UI y experiencia de uso

- Diseño propio, partiendo de un boceto en Figma: título grande en peso ligero con subtítulo en mayúsculas, catálogo en cuadrícula de dos columnas e icono de la app con el mismo degradado.
- Dos pestañas (**Catálogo** e **Historial**) más un **botón central de escaneo** con degradado magenta–naranja, acoplado a una curva de la barra inferior. El pedido actual se abre desde el carrito, que muestra el número de artículos. Historial muestra cuántos pedidos faltan por enviar.
- Encabezados fijos: el carrito siempre está visible al recorrer el catálogo.
- Después de escanear, agregar, guardar o enviar: snackbar con icono y texto según el resultado (agregado, no encontrado, offline, QR inválido, permiso denegado, cancelado...).
- Estados de carga, vacío, error y sin conexión con mensaje explicativo y acción para reintentar. Sin conexión, un aviso indica que se muestra el catálogo guardado.
- Accesibilidad básica: etiquetas en los iconos (`Semantics`, `tooltip`), áreas táctiles de 48 dp o más y colores de estado con contraste de al menos 4.5:1.
- Paleta y estilos centralizados en `core/theme`. Tipografía: Roboto, la fuente del sistema en Android.

---

## 10. Instalación y compilación

Para solo probar la app, instala el **APK de la Release** en un teléfono Android 6.0 o superior.

### Requisitos

| Herramienta | Versión |
| --- | --- |
| Flutter | TODO (`flutter --version`) |
| Dart SDK | `^3.13.5` (según `pubspec.yaml`) |
| JDK | 17 |
| Android SDK | compileSdk 36, minSdk 23 |
| SDK (`sdk-android`) | Gradle 8.11.1, AGP 8.9.1, Kotlin 2.1.20 |
| App (`app/android`) | Gradle 9.3.1 |

### Paquetes de la app

| Paquete | Uso |
| --- | --- |
| `flutter_riverpod` | Estado e inyección de dependencias |
| `drift`, `drift_flutter` | Base de datos SQLite |
| `http` | Cliente REST |
| `drift_dev`, `build_runner` (dev) | Generación del código de Drift |
| `flutter_launcher_icons` (dev) | Generación del icono |

Las versiones exactas están en `app/pubspec.lock`.

### Pasos

> **Importante:** la app consume el AAR desde `app/android/app/libs/`, que **no está versionado**. Compila el SDK antes que la app.

```bash
# 1. Compilar el SDK (genera el AAR y lo copia a app/android/app/libs/)
cd sdk-android
./gradlew :qr-scanner:assembleRelease        # Windows: .\gradlew.bat
# AAR: sdk-android/qr-scanner/build/outputs/aar/qr-scanner-release.aar

# 2. Compilar y ejecutar la app
cd ../app
flutter pub get
flutter run                 # dispositivo conectado
flutter build apk --debug   # APK: build/app/outputs/flutter-apk/app-debug.apk
```

El código generado de Drift (`app_database.g.dart`) está versionado. Solo si cambias el esquema hay que regenerarlo con `dart run build_runner build`.

Alternativa: descarga el AAR de la Release y colócalo en `app/android/app/libs/qr-scanner-release.aar`.

---

## 11. Pruebas

```bash
# Kotlin, unitarias
cd sdk-android && ./gradlew :qr-scanner:testDebugUnitTest
# Kotlin, instrumentadas (requiere dispositivo o emulador; ver limitaciones con MIUI)
cd sdk-android && ./gradlew :qr-scanner:connectedDebugAndroidTest
# Dart
cd app && flutter test
```

Las pruebas Dart usan `MockClient` de `package:http/testing.dart`, una base Drift en memoria (`NativeDatabase.memory()`) y un doble del puente. **No dependen de DummyJSON.**

### Cobertura de las pruebas

| Área | Pruebas |
| --- | --- |
| Parser QR (Kotlin) | IDs 1–3 válidos; `0`, `-1`, `01`, mayúsculas, no numérico, decimales, espacios, no ASCII inválidos; límite `Int.MAX_VALUE` / `2147483648` |
| Sesión (Kotlin) | Detecciones repetidas → un resultado; cancelar y luego detectar ignora la detección; entre dos terminales gana la primera |
| ScanManager (Kotlin) | Segundo inicio → `PROGRESS_SCAN`; inicios concurrentes → una sola sesión; liberación tras éxito, error o cancelación |
| Instrumentada (Kotlin) | `cancel()` entrega `CANCELLED`, cierra la pantalla y libera la sesión; luego se puede iniciar otra |
| Base de datos (Dart) | Guardado y lectura de pedido con líneas; rechazo de cantidad 0 |
| Catálogo (Dart) | Guarda y lee desde la base; sin red conserva la copia anterior; error HTTP, JSON inválido y timeout no modifican la base; upsert sin duplicados |
| Pedido (Dart) | Persistencia y recuperación; copia de nombre y precio; transacción atómica; cantidades y total; producto local sin red; 999999 no agrega línea; no guardado y sin red → offline; doble guardado |
| Cola (Dart) | Éxito con el formato esperado; HTTP → error; sin red → error; timeout, conexión perdida o JSON inválido → desconocido; confirmado no se reenvía; reintento con el mismo ID; desconocido fuera del lote; doble ejecución y doble toque; recuperación de `sending` |
| Puente (Dart) | Conversión de `productId`; propagación de cada código; canal no registrado → `unknown`; `cancelScan` |

### Matriz de ejecución real

| Qué | Dónde | Resultado |
| --- | --- | --- |
| `flutter test` | Windows 11, local | 42 pruebas OK |
| `testDebugUnitTest` | Windows 11, JVM local | 22 pruebas OK |
| `connectedDebugAndroidTest` | Emulador Android Studio `Medium_Phone` (Android 17) | 2 pruebas OK |
| `connectedDebugAndroidTest` | Xiaomi 2306EPN60G (Android 14) | No ejecutable por restricciones de MIUI (ver limitaciones) |
| Lectura de los 11 QR de prueba con cámara real | Xiaomi 2306EPN60G | OK |
| Flujo manual completo (secciones 2 y 12) | Xiaomi 2306EPN60G | OK |
| Cancelación, permiso, segundo plano y "No conservar actividades" | Xiaomi 2306EPN60G | OK |

---

## 12. Reproducir el flujo offline

1. Instala el APK **con conexión** y abre la app: el catálogo se descarga y se guarda.
2. Pulsa el botón de escaneo y lee `product:1` (acepta el permiso). El producto se agrega al pedido. Repite con `product:2` y ajusta las cantidades en el carrito.
3. Activa el **modo avión**. Aparece el aviso de que se muestra el catálogo guardado.
4. Agrega productos desde el catálogo y escanea `product:3`: se agrega desde la caché. Guarda el pedido → queda **Pendiente** en Historial.
5. Escanea un ID que no esté en caché (por ejemplo `product:50`) → "No disponible offline".
6. **Cierra la app por completo** (quítala de recientes) y vuelve a abrirla: el catálogo y el pedido pendiente siguen ahí.
7. Todavía sin conexión, pulsa **Enviar pendientes** → **Error** "Sin conexión", intentos: 1.
8. Desactiva el modo avión y pulsa **Enviar pendientes** → el mismo pedido pasa a **Confirmado simulado**, intentos: 2, con su referencia simulada.
9. El confirmado ya no cuenta como pendiente: si guardas otro pedido y vuelves a enviar, solo se envía el nuevo y el confirmado no cambia.

Recuperación tras rechazar el permiso: rechaza el permiso de cámara → mensaje "Sin permiso de cámara". Vuelve a pulsar escanear para que se pida de nuevo. Si se rechazó de forma permanente, actívalo en Ajustes → Apps → Flash Scanner → Permisos.

---

## 13. Dispositivo probado

| Campo | Valor |
| --- | --- |
| Modelo | Xiaomi 2306EPN60G |
| Versión de Android | 14 (MIUI) |
| Emulador | Android Studio `Medium_Phone` (Android 17), solo pruebas instrumentadas |
| Limitaciones | MIUI bloquea que la app de prueba otorgue permisos y abra pantallas desde segundo plano, por eso las pruebas instrumentadas se ejecutaron en el emulador |

---

## 14. Limitaciones conocidas y pendientes

| Tema | Detalle |
| --- | --- |
| Primer QR | El primer QR detectado termina la sesión, aunque sea inválido |
| Segundo plano | La sesión se cancela en lugar de restaurarse (decisión explicada en la sección 3) |
| Pruebas instrumentadas en MIUI | Requieren "Depuración USB (Ajustes de seguridad)" y aun así MIUI impide abrir pantallas desde la app de prueba; se ejecutaron en emulador |
| Clasificación de errores de red | Depende del texto del mensaje del sistema; si no coincide, el pedido queda como `unknown` (lado seguro) |
| Servicio externo | No hay modo de fixtures en la app porque DummyJSON estuvo disponible durante todo el desarrollo; las pruebas automatizadas sí usan dobles HTTP |
| AAR | No publica sus dependencias transitivas; hay que declararlas a mano |
| Puente | El lado nativo vive en `MainActivity`, no en un plugin local separado |
| Cancelación desde la UI | `cancelScan()` está en el contrato y probado, pero la UI cancela con el botón atrás del escáner |
| Paquete | `applicationId` sigue siendo `com.example.app` |
| No probado | Tablets y plegables; dispositivo sin cámara para forzar `cameraUnavailable` real |
| iOS | No implementado: sin macOS/Xcode ni iPhone |

---
## 15. Tiempo aproximado

Unas **26horas** de trabajo efectivo en 4 días (8–11 de octubre de 2026):

| Parte | Horas aprox. |
| --- |--------------|
| SDK Android (parser, sesión, cámara, pruebas) | 5            |
| Puente MethodChannel | 10           |
| App Flutter (base de datos, catálogo, pedidos, cola) | 5            |
| UI | 5            |
| Documentación | 1            |

## 16. Uso de IA

Ver [`AI_USAGE.md`](AI_USAGE.md).