# 🔥 Configuración de Firebase para Push Notifications, Crashlytics y Analytics

## Pasos para configurar Firebase

### 1. Crear proyecto en Firebase Console
1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Crea un nuevo proyecto o usa uno existente
3. Nombre sugerido: `robert-darin-fintech`

### 2. Agregar app Android
1. En Firebase Console, click en "Agregar app" → Android
2. **Package name**: `com.robertdarin.fintech`
3. **App nickname**: Robert Darin Fintech
4. Click "Registrar app"

### 3. Descargar google-services.json
1. Firebase te dará un archivo `google-services.json`
2. **DESCÁRGALO Y COLÓCALO EN ESTA CARPETA**: `android/app/google-services.json`
3. El archivo debe quedar en: `c:\Users\rober\Desktop\robertdarin\android\app\google-services.json`

### 4. Habilitar servicios en Firebase Console

#### Push Notifications (FCM)
1. Cloud Messaging → Habilitar
2. Copiar **Server Key** para enviar notificaciones desde backend

#### Crashlytics
1. Ve a Crashlytics en el menú lateral
2. Click "Habilitar Crashlytics"
3. Los crashes aparecerán automáticamente después de compilar

#### Analytics
1. Ve a Analytics en el menú lateral
2. Ya viene habilitado por defecto
3. Los eventos aparecerán en 24-48 horas

### 5. Obtener Server Key para FCM
1. En Firebase Console → Configuración del proyecto → Cloud Messaging
2. Si dice "Cloud Messaging API (Legacy)" está deshabilitada, habilítala
3. Copia la **Server Key** (empieza con `AAAA...`)
4. Guárdala en Supabase en la tabla `configuracion_apis`:

```sql
UPDATE configuracion_apis 
SET api_key = 'TU_SERVER_KEY_AQUI', activo = true 
WHERE servicio = 'firebase_fcm';
```

### 6. Verificar configuración
Después de colocar `google-services.json`, ejecuta:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### 7. Probar Crashlytics (opcional)
Para forzar un crash de prueba y verificar que funciona:
```dart
// En cualquier botón de prueba:
FirebaseCrashlytics.instance.crash();
```

## 📊 Eventos de Analytics disponibles

El servicio `AnalyticsService` trackea automáticamente:
- `login` / `logout` - Sesiones de usuario
- `prestamo_creado` - Nuevos préstamos
- `pago_registrado` - Pagos realizados
- `tanda_creada` - Nuevas tandas
- `documento_aval_subido` - Documentos de avales
- `cobro_efectivo` - Cobros en efectivo
- `mora_generada` - Moras activas

## ⚠️ Importante
- El archivo `google-services.json` contiene credenciales sensibles
- NO lo subas a repositorios públicos
- Agrega `google-services.json` a `.gitignore` si usas Git

---
**V10.26 - Robert Darin Fintech**
