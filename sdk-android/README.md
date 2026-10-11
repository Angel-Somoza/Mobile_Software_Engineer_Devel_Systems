# qr-scanner — SDK nativo Android

SDK en Kotlin que abre la cámara, pide el permiso, lee un código QR con el formato `product:<id>`, lo valida y devuelve **un único resultado por sesión**. Se distribuye como archivo `.aar` y no depende de Flutter, del cliente REST ni de las entidades de pedidos.

La app Flutter lo consume a través de un puente propio con `MethodChannel`.

---

## Requisitos

| Herramienta | Versión |
|---|---|
| `minSdk` | 23 |
| `compileSdk` | 36 |
| Android Gradle Plugin | 8.9.1 o superior |
| Gradle | 8.11.1 o superior |
| Kotlin | 2.1.20 |
| JDK | 17 |

CameraX 1.6.2 exige `compileSdk` 36 y AGP 8.9.1 a cualquier proyecto que lo use, incluida la app que integre este SDK.

---

## Compilar y probar

Desde `sdk-android/`:

```bash
# Pruebas unitarias (JVM, no requieren dispositivo)
./gradlew :qr-scanner:testDebugUnitTest

# Pruebas instrumentadas (requieren un dispositivo o emulador conectado)
./gradlew :qr-scanner:connectedDebugAndroidTest

# Generar el AAR
./gradlew :qr-scanner:assembleRelease
```

En Windows usa `.\gradlew.bat` en lugar de `./gradlew`.

El AAR queda en `qr-scanner/build/outputs/aar/qr-scanner-release.aar`. La tarea `assembleRelease` lo copia automáticamente a `app/android/app/libs/` mediante la tarea `copyAarToApp`.

---

## Integración en una app Android nativa

### 1. Agregar el AAR

Copia `qr-scanner-release.aar` a `app/libs/` y declara las dependencias. **Un AAR local no incluye sus dependencias transitivas**, así que la app debe declararlas con las mismas versiones:

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

No hace falta declarar el permiso de cámara ni la Activity del escáner: vienen en el manifest del SDK y se fusionan automáticamente con el de la app.

### 2. Usarlo

```kotlin
import com.asomoza.qr_scanner.QrScanner
import com.asomoza.qr_scanner.scanner.ScanErrors
import com.asomoza.qr_scanner.scanner.ScanResult

QrScanner.start(this) { result ->
    runOnUiThread {
        when (result) {
            is ScanResult.Success -> showProduct(result.productId)
            is ScanResult.Failure -> when (result.error) {
                ScanErrors.PERMISSION_DENIED -> showMessage("Sin permiso de cámara")
                ScanErrors.CAMERA_UNAVAILABLE -> showMessage("Cámara no disponible")
                ScanErrors.INVALID_QR -> showMessage("QR inválido")
                ScanErrors.CANCELLED -> Unit
                ScanErrors.PROGRESS_SCAN -> showMessage("Ya hay un escaneo en curso")
            }
        }
    }
}

// Para cancelar desde la app (por ejemplo, al cerrar la pantalla que lo pidió):
QrScanner.cancel()
```

El callback puede llegar desde un hilo distinto al principal; usa `runOnUiThread` (o equivalente) antes de tocar la UI.

---

## API pública

Solo estos tipos son públicos. El resto del SDK (`QrScannerActivity`, `ScanManager`, `ScanAttempt`, `QrPayloadParser`) es `internal`.

### `object QrScanner`

| Función | Descripción |
|---|---|
| `start(context: Context, onResult: (ScanResult) -> Unit)` | Inicia una sesión y abre la pantalla de escaneo. Si ya hay una sesión activa, no abre otra y responde de inmediato con `Failure(PROGRESS_SCAN)`. Acepta una `Activity` o cualquier `Context`. |
| `cancel()` | Cancela la sesión activa: entrega `Failure(CANCELLED)` y cierra la pantalla. Si no hay sesión, no hace nada. |

### `sealed interface ScanResult`

| Tipo | Contenido |
|---|---|
| `Success(productId: Int)` | El QR tiene formato válido. El SDK **no** comprueba que el producto exista; eso lo decide la app. |
| `Failure(error: ScanErrors)` | La sesión terminó sin un ID válido. |

### `enum class ScanErrors`

| Valor | Cuándo ocurre |
|---|---|
| `PERMISSION_DENIED` | El usuario negó el permiso de cámara. |
| `CAMERA_UNAVAILABLE` | No se pudo abrir la cámara (no existe, está ocupada o falló CameraX). |
| `INVALID_QR` | Se leyó un QR que no cumple el formato. |
| `CANCELLED` | Botón atrás, `cancel()`, la app pasó a segundo plano o se destruyó quien pidió el escaneo. |
| `PROGRESS_SCAN` | Se llamó a `start` con una sesión ya activa. |

**Garantía:** cada sesión entrega **exactamente un** resultado, aunque ocurran varios eventos a la vez (por ejemplo, el usuario cancela justo cuando se detecta un QR). Lo asegura un `AtomicBoolean` en `ScanAttempt`.

---

## Formato del QR

Texto con prefijo exacto `product:` seguido de un entero positivo.

| Regla | Ejemplo rechazado |
|---|---|
| Prefijo exacto en minúsculas | `PRODUCT:1` |
| Solo dígitos, sin signo ni espacios | `product:-1`, `product:abc`, `product: 1` |
| Sin ceros iniciales ni cero | `product:01`, `product:0` |
| Debe caber en un `Int` de 32 bits | `product:99999999999` |

Validación: regex `[1-9][0-9]*` y luego `toIntOrNull()` para rechazar valores fuera de rango.


---

## Ciclo de vida y decisiones de diseño

| Situación | Comportamiento | Motivo |
|---|---|---|
| Se detecta un QR | Se valida, se entrega el resultado y se cierra la pantalla. | — |
| **El primer QR detectado es inválido** | La sesión termina con `INVALID_QR`. | Contrato simple de un resultado por sesión. La alternativa (ignorar QR inválidos y seguir buscando) queda como mejora posible. |
| Botón atrás | `CANCELLED`. | Se detecta en `onDestroy` con `isFinishing`, sin código especial para el botón. |
| La app pasa a segundo plano (Home, pantalla apagada, llamada) | `CANCELLED` y se cierra la pantalla. | El examen permite cancelar en lugar de restaurar. Evita que la llamada de Flutter quede pendiente indefinidamente. |
| Diálogo de permiso de cámara | **No** cancela. | Una bandera (`requestingPermission`) evita que el diálogo del sistema dispare la cancelación por segundo plano. |
| Cambio de configuración (tema, tamaño de letra, idioma) | **No** cancela; la Activity nueva retoma la misma sesión. | Se detecta con `isChangingConfigurations`. |
| Orientación | La pantalla del escáner está fijada en vertical. | En Android 16 con pantallas grandes el sistema puede ignorar el bloqueo; en ese caso la rotación se trata como un cambio de configuración más. |
| Se destruye la Activity o el motor de Flutter que pidió el escaneo | `CANCELLED` y se cierra la pantalla. | Quien pidió el resultado ya no existe; se evita dejar la cámara abierta y fugas de memoria. |
| Segundo `start` con sesión activa | `PROGRESS_SCAN`; la sesión activa no se altera. | `ScanManager` permite una sola sesión a la vez. |

### Liberación de recursos

- La cámara está atada al ciclo de vida de la Activity con `bindToLifecycle`; CameraX la libera al destruirse.
- En `onDestroy` se apagan el hilo de análisis (`ExecutorService.shutdown()`) y el detector de ML Kit (`BarcodeScanner.close()`).
- Cada cuadro analizado se cierra con `ImageProxy.close()` al terminar, tanto si hubo éxito como error.
- La pantalla se registra en la fachada al abrirse y se da de baja al destruirse, así el singleton nunca conserva una referencia a una Activity muerta.

### Funcionamiento sin conexión

`com.google.mlkit:barcode-scanning` incluye el modelo dentro del APK, así que la lectura funciona sin conexión desde la primera ejecución. No se descarga nada en tiempo de ejecución.

---

## Contrato del puente Flutter

Implementado en `app/android/app/src/main/kotlin/.../MainActivity.kt` con `MethodChannel`.

**Canal:** `com.asomoza.flash_orders/qr_scanner`

| Método | Argumentos | Respuesta de éxito | Errores |
|---|---|---|---|
| `startScan` | — | `int` con el `productId` | `PlatformException` con un código de la tabla siguiente |
| `cancelScan` | — | `null` | — |

| Código (`PlatformException.code`) | `ScanErrors` en Kotlin |
|---|---|
| `permissionDenied` | `PERMISSION_DENIED` |
| `cameraUnavailable` | `CAMERA_UNAVAILABLE` |
| `invalidQr` | `INVALID_QR` |
| `cancelled` | `CANCELLED` |
| `scanInProgress` | `PROGRESS_SCAN` |

- La traducción es explícita (`when` exhaustivo sin `else`): si se agrega un valor al enum, la app no compila hasta asignarle un código. El contrato con Dart no depende de los nombres internos de Kotlin.
- La cancelación se representa siempre como **error tipado** (`cancelled`).
- Toda respuesta se envía en el hilo principal (`runOnUiThread`).
- Al desconectarse el motor (`cleanUpFlutterEngine`) se cancela la sesión activa, de modo que ninguna llamada queda pendiente.

**¿Por qué `MethodChannel` y no Pigeon?** El contrato es pequeño (dos métodos, un entero de respuesta y cinco códigos de error). `MethodChannel` no requiere generación de código y deja visible la conversión de tipos y errores. Con un contrato más grande o con estructuras anidadas, Pigeon sería la mejor opción por su tipado seguro.

---

## Dependencias y licencias

| Dependencia | Versión | Uso | Licencia |
|---|---|---|---|
| `androidx.camera:camera-core` | 1.6.2 | Cámara | Apache 2.0 |
| `androidx.camera:camera-camera2` | 1.6.2 | Implementación Camera2 | Apache 2.0 |
| `androidx.camera:camera-lifecycle` | 1.6.2 | Ciclo de vida de la cámara | Apache 2.0 |
| `androidx.camera:camera-view` | 1.6.2 | `PreviewView` | Apache 2.0 |
| `com.google.mlkit:barcode-scanning` | 17.3.0 | Decodificación QR (modelo incluido) | Términos de servicio de ML Kit (Google APIs Terms of Service) |
| Kotlin stdlib | 2.1.20 | — | Apache 2.0 |

Solo para pruebas (no se incluyen en el AAR):

| Dependencia | Versión | Licencia |
|---|---|---|
| `junit:junit` | 4.13.2 | Eclipse Public License 1.0 |
| `androidx.test.ext:junit-ktx` | 1.3.0 | Apache 2.0 |
| `androidx.test:runner` | 1.7.0 | Apache 2.0 |
| `androidx.test:rules` | 1.7.0 | Apache 2.0 |

ML Kit puede enviar a Google métricas anónimas de uso del SDK, según sus términos. Esto no afecta la lectura sin conexión.

---

## Pruebas

### Automatizadas

| Tipo | Dónde corre | Qué cubre |
|---|---|---|
| Unitarias (22) — `src/test/` | JVM | Validación de QR válidos, inválidos y fuera de rango; una sola terminación por sesión ante detecciones repetidas; `ScanManager` con una sola sesión activa, incluida una prueba concurrente. |
| Instrumentadas (2) — `src/androidTest/` | Dispositivo o emulador | `QrScannerLifecycleTest`: con la Activity real, cancelar entrega exactamente un `CANCELLED`, cierra la pantalla y deja la fachada sin sesión ni referencia a la pantalla; después de cancelar se puede iniciar otra sesión. |

### Manuales (dispositivo físico)

| Caso | Resultado |
|---|---|
| `product:1`, `product:2`, `product:3`, `product:999999` | `Success` con el ID |
| `product:0`, `product:-1`, `product:01`, `PRODUCT:1`, `product:abc`, `hola`, `product:99999999999` | `INVALID_QR` |
| Negar el permiso | `PERMISSION_DENIED` |
| Aceptar el permiso en el diálogo | La sesión continúa y se abre la cámara |
| Botón atrás | `CANCELLED` |
| `cancelScan()` desde Flutter con la cámara abierta | `CANCELLED` y la cámara se cierra |
| Home / apagar pantalla | `CANCELLED` |
| "No conservar actividades" activado | Al destruirse `MainActivity`, la sesión se cancela y el escáner se cierra |

### Entornos

| Entorno | Uso |
|---|---|
| Xiaomi 2306EPN60G, Android 14 (MIUI) | Lectura real con cámara y pruebas manuales |
| Emulador `Medium_Phone` (AVD), Android 17 | Pruebas instrumentadas |

---

## Limitaciones conocidas

- **El primer QR detectado termina la sesión**, aunque sea inválido. Para leer otro, la app debe iniciar una sesión nueva.
- **Pruebas instrumentadas en Xiaomi/MIUI:** no pueden ejecutarse sin configuración extra. MIUI bloquea que la app de prueba abra pantallas desde segundo plano, y además requiere activar "Depuración USB (Ajustes de seguridad)" para que `GrantPermissionRule` otorgue el permiso de cámara. Por eso se ejecutaron en emulador.
- **Al pasar a segundo plano se cancela la sesión** en lugar de restaurarla al volver. Es una decisión deliberada (ver tabla de ciclo de vida).
- Solo se usa la cámara trasera.

---

## Estructura

```
qr-scanner/src/
├── main/java/com/asomoza/qr_scanner/
│   ├── QrScanner.kt               Fachada pública
│   ├── camera/
│   │   └── QrScannerActivity.kt   Permiso, CameraX, ML Kit y ciclo de vida
│   ├── scanner/
│   │   ├── ScanManager.kt         Una sola sesión activa
│   │   ├── ScanAttempt.kt         Una sola terminación por sesión
│   │   ├── ScanResult.kt          Resultado público
│   │   └── ScanErrors.kt          Errores públicos
│   └── parser/
│       └── QrPayloadParser.kt     Validación del formato product:<id>
├── test/                          Pruebas unitarias (JVM)
└── androidTest/                   Pruebas instrumentadas
    ├── AndroidManifest.xml        Activity anfitriona solo para pruebas
    └── java/.../QrScannerLifecycleTest.kt
```
