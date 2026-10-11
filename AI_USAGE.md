# Uso de inteligencia artificial


## 1. Herramientas utilizadas

- **Claude** (Anthropic), modelo Claude Opus 5.5, a través de la app de Claude (claude.ai), en modo conversación guiada.

## 2. Tareas en las que ayudó y archivos afectados

La forma de trabajo fue guiada: Claude explicaba cada paso con base en la documentación oficial de Flutter (canales de plataforma), CameraX y ML Kit, y yo aplicaba, compilaba y probaba cada cambio en el dispositivo.

| Tarea | Archivos / componentes |
|---|---|
| Tarea de Gradle para copiar el AAR a la app automáticamente | `sdk-android/qr-scanner/build.gradle.kts` (`copyAarToApp`) |
| Detección de QR con CameraX `ImageAnalysis` + ML Kit | `QrScannerActivity.kt` |
| Cancelación al pasar a segundo plano sin afectar el diálogo de permiso ni los cambios de configuración | `QrScannerActivity.kt` (`onStop`, `requestingPermission`) |
| Prueba instrumentada de cancelación y liberación de recursos | `src/androidTest/.../QrScannerLifecycleTest.kt`, `src/androidTest/AndroidManifest.xml` |
| Borrador de documentación del SDK y de este archivo | `sdk-android/README.md`, `AI_USAGE.md` |

### App Flutter

| Tarea | Archivos / componentes |
|---|---|
| Esquema de la base y prueba | `core/database/app_database.dart`, `test/core/database` |
| Cliente REST con timeouts y errores tipados; catálogo con caché offline | `core/network/*`, `features/catalog/*` |
| Contrato Dart del puente y prueba de contrato | `features/scanner/*` |
| Carrito, búsqueda por ID (base → API) y guardado atómico | `features/order/*` |
| Cola de envío: estados, reclamo atómico, clasificación de errores, recuperación al arrancar | `features/outbox/*`, `main.dart` |
| Pruebas Dart de catálogo, pedido, cola y puente con dobles | `test/features/*` |
| Implementación de la UI a partir de mi diseño en Figma; colores y estados | `lib/app/*`, `core/theme/*`, `core/widgets/*`, pantallas |
| Cliente HTTP con registro en logcat (solo debug) | `core/network/logging_client.dart` |
| Icono de la app y su configuración | `assets/icon/*`, `pubspec.yaml` |

**Trabajo propio sin IA en esta fase** : 
lógica pura del SDK (`QrPayloadParser`, `ScanAttempt`, `ScanManager`, `ScanResult`, `ScanErrors`), usando figma para el diseno de la pantalla de main.

## 3. Prompts representativos

Trabajé con la IA en una conversación guiada, pidiendo avanzar paso a paso según la documentación oficial y que me explicara cada cambio antes de aplicarlo.

- **Pruebas:** le pedí apoyo con la prueba instrumentada y con las pruebas Dart, y le envié las salidas de Gradle y de `flutter test` cuando fallaban.
- **App Flutter:** le pedí implementar el catálogo, la base de datos, el carrito y la cola de envío según el examen.
- **UI:** le compartí mi diseño de Figma y le pedí implementarlo.

## 4. Cambios que hice sobre las propuestas

- Simplifiqué el esquema propuesto: precio en `double` en lugar de centavos y sin clave foránea, conservando la miniatura del producto.
- La UI sigue mi diseño de Figma (encabezado, cuadrícula de dos columnas, barra inferior con botón central).



## 5. Verificación, fallos encontrados y lo que sigue sin comprobarse

### Cómo se verificó

- Cada cambio se compiló desde la terminal y se probó en un Xiaomi 2306EPN60G con Android 14.
- Lectura real con cámara de los 11 QR de prueba (válidos, inválidos y fuera de rango), cancelación con botón atrás, cancelación desde Flutter, permiso negado y aceptado, paso a segundo plano y destrucción forzada de la Activity ("No conservar actividades").
- Revisión de `logcat` para confirmar apertura y cierre de la cámara y liberación de los casos de uso de CameraX en cada sesión.
- Pruebas unitarias (22) y pruebas instrumentadas (2) en verde; las instrumentadas en emulador.
- Los QR generados por el script se decodificaron antes de usarlos para confirmar su contenido.

### Fallos encontrados durante el proceso

En la integración y configuración:

- CameraX 1.6.2 exige `compileSdk` 36 y AGP 8.9.1; solo se detectó al armar el APK de prueba.
- MIUI bloquea que la app de prueba otorgue permisos y abra pantallas desde segundo plano; las pruebas instrumentadas se movieron al emulador.

Errores en las propuestas de la IA:

- La primera versión de la prueba instrumentada usaba `waitForIdleSync()`, que se bloqueaba indefinidamente porque ML Kit publica resultados en el hilo principal en cada cuadro. Se reemplazó por una espera con límite de tiempo y se agregó una regla `Timeout` de 30 segundos.
- La IA afirmó que ninguna espera de la prueba podía superar los 5 segundos, lo cual era falso para `waitForIdleSync()`.
- Sugirió abrir el escáner desde el contexto de la aplicación en la prueba, lo que falla en dispositivos que restringen abrir pantallas desde segundo plano; se cambió a una Activity anfitriona con `ActivityScenario`.

### Lo que sigue sin comprobarse

- Las pruebas instrumentadas no se ejecutaron en un dispositivo físico (solo en emulador), por las restricciones de MIUI.
- No se probó en tablets ni pantallas grandes, donde Android 16 puede ignorar el bloqueo de orientación.
- No se probó en un dispositivo sin cámara para forzar `CAMERA_UNAVAILABLE` de forma real.
