# FitPulse Wear OS

Aplicacion Flutter para wearable/reloj inteligente.

## Incluye

- Pantalla de configuracion de PIN.
- Login/desbloqueo por PIN.
- Biometria opcional con `local_auth`.
- Dashboard protegido.
- Cierre de sesion.
- Modo demo sin conexion.
- Lectura opcional de metricas desde backend usando JWT.

## Requisitos

- Flutter SDK
- Emulador Wear OS o dispositivo Android compatible

## Instalacion

```bash
flutter pub get
```

## Ejecutar en Wear OS

Lista dispositivos:

```bash
flutter devices
```

Ejecuta en el emulador Wear OS:

```bash
flutter run -d emulator-5554
```

## Ejecutar con token real

Si tienes JWT generado por el backend/web:

```bash
flutter run -d emulator-5554 --dart-define=FITPULSE_TOKEN=tu_jwt
```

En emulador Android, el backend local de la PC se consume como:

```text
http://10.0.2.2:3000
```

## Pruebas de seguridad

- Intentar entrar sin PIN configurado.
- Crear PIN local.
- Cerrar sesion y verificar que vuelve al login.
- Probar PIN incorrecto y bloqueo por intentos.
- Revisar que el PIN se guarda como hash/salt mediante almacenamiento seguro.

## Entrega academica

Este repo cubre la practica de smartwatch: autenticacion por PIN, biometria
opcional, pantalla protegida, cierre de sesion y pruebas de seguridad en Wear OS.
