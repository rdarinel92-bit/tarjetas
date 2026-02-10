# 🚀 Quick Start - Robert Darin Fintech

Guía rápida para comenzar a desarrollar.

## ⚡ Setup Inicial (5 minutos)

### 1. Clonar y configurar

```bash
git clone https://github.com/rdarinel92-bit/tarjetas.git
cd tarjetas
```

### 2. Flutter App

```bash
cd robertdarin
flutter pub get
flutter run
```

### 3. Web Apps

```bash
# Desde la raíz del proyecto
./scripts/dev.sh

# O manualmente:
python3 -m http.server 8000

# Abrir:
# http://localhost:8000/?codigo=DEMO
# http://localhost:8000/pollos/
```

## 🛠️ Scripts Disponibles

### Flutter

```bash
# Build completo (interactivo)
./scripts/build.sh

# Opciones: APK debug/release, App Bundle, iOS, análisis

# Tests con cobertura
./scripts/test.sh

# Análisis rápido
cd robertdarin && flutter analyze
```

### Web

```bash
# Servidor de desarrollo
./scripts/dev.sh

# Puerto personalizado
./scripts/dev.sh 3000
```

### Deployment

```bash
# Deploy automático (commit + push)
./scripts/deploy.sh
```

## 📦 Dependencias

### Flutter
- Flutter SDK 3.3.0+
- Android Studio o Xcode (para builds nativos)
- Java 17+ (para Android)

### Web
- Python 3.x (para servidor local)
- Navegador moderno (Chrome, Firefox, Safari)

### Opcional
- Node.js 18+ (para utilidades de minificación)
- Supabase CLI (para gesionar BD)

## 🎯 Flujo de Desarrollo Típico

### Nueva Feature

```bash
# 1. Crear rama
git checkout -b feature/mi-feature

# 2. Desarrollar
cd robertdarin
flutter run
# ... hacer cambios ...

# 3. Tests
flutter test

# 4. Commit
git add .
git commit -m "feat: agregar mi feature"

# 5. Push y PR
git push origin feature/mi-feature
# Crear Pull Request en GitHub
```

### Hotfix Urgente

```bash
# 1. Rama desde main
git checkout main
git pull
git checkout -b hotfix/issue-critico

# 2. Arreglar
# ... hacer cambios ...

# 3. Deploy directo
./scripts/build.sh  # Opción 2: APK Release
./scripts/deploy.sh

# 4. Merge a main
git checkout main
git merge hotfix/issue-critico
git push
```

## 🔧 Configuración de Entorno

### Firebase (App)

1. Descargar `google-services.json` de Firebase Console
2. Colocar en `robertdarin/android/app/`
3. Rebuild app

### Supabase

Las credenciales están en el código (RLS protegido).
Para cambiar proyecto:

1. Editar URLs en `lib/core/config/supabase_config.dart`
2. Actualizar Anon Key
3. Aplicar migraciones: `cd supabase && ./deploy_supabase.ps1 push`

### Variables de Entorno

Crear `robertdarin/.env` (opcional):

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-key
FIREBASE_API_KEY=tu-key
```

## 📱 Builds de Producción

### Android APK

```bash
cd robertdarin
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
# Copiar a: ../app/robertdarin-latest.apk
```

### Play Store (App Bundle)

```bash
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
# Subir a Google Play Console
```

### iOS (requiere macOS)

```bash
flutter build ios --release
# Abrir Xcode y archivar
```

## 🧪 Testing

### Unit Tests

```bash
cd robertdarin
flutter test
```

### Integration Tests

```bash
flutter test integration_test/
```

### Coverage

```bash
flutter test --coverage
# Ver: coverage/lcov.info
```

## 📊 Métricas de Código

```bash
# Líneas de código Dart
find robertdarin/lib -name '*.dart' | xargs wc -l

# Análisis de complejidad
flutter analyze

# Formato
flutter format lib/
```

## 🐛 Debugging

### Flutter DevTools

```bash
flutter run
# En otra terminal:
flutter pub global activate devtools
flutter pub global run devtools
```

### Logs en tiempo real

```bash
# Android
adb logcat | grep flutter

# iOS
idevicesyslog | grep Runner
```

### Chrome DevTools (Web apps)

1. Abrir con F12
2. Buscar errores en Console
3. Network tab para requests a Supabase

## 🚀 CI/CD con GitHub Actions

Ya configurado automáticamente:

- **Push a `main`**: Build APK + App Bundle
- **Pull Request**: Tests + análisis
- **Tag `v*`**: Release automático

## 📚 Recursos

- [Documentación completa](README.md)
- [Arquitectura](robertdarin/CORE_SYSTEM_ARCHITECTURE.md)
- [Changelog](CHANGELOG.md)
- [Contribución](CONTRIBUTING.md)
- [Copilot Instructions](.github/copilot-instructions.md)

## 🆘 Troubleshooting

### "Flutter command not found"
```bash
export PATH="$PATH:$HOME/flutter/bin"
```

### "Build failed - Gradle error"
```bash
cd robertdarin/android
./gradlew clean
cd ../..
flutter clean
flutter pub get
```

### "Supabase timeout"
- Verificar conexión a internet
- Revisar RLS policies en Supabase Dashboard
- Comprobar Anon Key válida

### "Web app no carga datos"
- Abrir Console (F12) para ver errores
- Verificar parámetro `?codigo=` en URL
- Comprobar tabla `tarjetas_servicio` tiene datos

## 💡 Tips

- Usa `hot reload` (r) al desarrollar en Flutter
- Actualiza dependencias: `flutter pub outdated`
- Pre-commit: `flutter analyze && flutter test`
- Material Icons: https://fonts.google.com/icons

---

¿Dudas? Revisa la [documentación completa](README.md) o abre un issue.
