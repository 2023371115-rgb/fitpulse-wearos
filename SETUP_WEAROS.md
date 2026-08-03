# Poner a correr FitPulse en el emulador Wear OS

Tu proyecto Flutter actualmente solo tiene la plataforma **web** generada
(`/web`). Para probarlo en un smartwatch (emulador Wear OS de Android
Studio) necesitas agregar la plataforma Android. Sigue estos pasos en tu
máquina (requieren el SDK de Flutter y Android Studio instalados; este
entorno de análisis no tiene Flutter disponible para ejecutarlo).

## 1. Agregar la plataforma Android al proyecto

```bash
cd flutter_devices_app
flutter create --platforms=android .
flutter pub get
```

Esto genera la carpeta `android/`.

## 2. Habilitar biometría en Android

`local_auth` requiere que `MainActivity` extienda de
`FlutterFragmentActivity` en lugar de `FlutterActivity`.

Edita `android/app/src/main/kotlin/.../MainActivity.kt`:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

Y agrega el permiso en `android/app/src/main/AndroidManifest.xml`
(dentro de `<manifest>`, antes de `<application>`):

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

## 3. Marcar la app como compatible con Wear OS (opcional pero recomendado)

En el mismo `AndroidManifest.xml`, dentro de `<application>`:

```xml
<uses-feature android:name="android.hardware.type.watch" />
<meta-data android:name="com.google.android.wearable.standalone" android:value="true" />
```

## 4. Crear el emulador Wear OS

En Android Studio: **Device Manager → Create Device → categoría "Wear OS"**
(por ejemplo "Wear OS Large Round"), con imagen de sistema Android 13/14
(Wear OS 4). Estas imágenes incluyen huella dactilar simulable.

## 5. Ejecutar

```bash
flutter devices          # confirma que el emulador Wear OS aparece
flutter run -d <device-id>
```

## 6. Probar biometría en el emulador

El emulador de Wear OS simula la huella igual que el de teléfono:

```bash
adb -s emulator-XXXX emu finger touch 1
```

(primero regístrala en el emulador: Settings → Security → Fingerprint,
sigue el asistente usando el mismo comando `adb emu finger touch 1`
cuando lo pida).

## 7. Backend

El backend Node (`server.js`) sigue corriendo en tu máquina/host, no en el
reloj. Si usas el emulador, cambia `_kBackendBase` en
`lib/screens/dashboard_screen.dart` de `http://localhost:3000` a la IP de
tu host visible desde el emulador (normalmente `10.0.2.2:3000` en
emuladores Android), y usa **HTTPS** en producción (ver reporte de
seguridad, hallazgo V-04).
