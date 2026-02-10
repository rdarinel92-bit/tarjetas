# 🚀 Guía de Publicación en Google Play Store
## Robert Darin Fintech v10.35

---

## 📋 CHECKLIST PRE-PUBLICACIÓN

### ✅ Completado Automáticamente
- [x] Application ID único: `com.robertdarin.fintech`
- [x] VersionCode: 1035 (incrementar en cada actualización)
- [x] VersionName: 10.35.0
- [x] Target SDK: 35 (Android 15)
- [x] Min SDK: 21 (Android 5.0+)
- [x] Permisos declarados correctamente
- [x] ProGuard configurado
- [x] Network Security Config (solo HTTPS)
- [x] Política de Privacidad
- [x] Términos y Condiciones

### 📝 Pendiente (Manual)
- [ ] Generar keystore de producción
- [ ] Configurar key.properties
- [ ] Crear cuenta de desarrollador Google Play ($25 USD)
- [ ] Preparar capturas de pantalla
- [ ] Crear ícono de alta resolución
- [ ] Escribir descripción de la app

---

## 🔑 PASO 1: GENERAR KEYSTORE DE PRODUCCIÓN

### Opción A: Línea de Comandos
```bash
cd android/keystores
keytool -genkey -v -keystore robert-darin-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias robertdarin
```

### Responder a las preguntas:
```
Contraseña del almacén de claves: [TU_PASSWORD_SEGURO]
Nombre y apellido: Robert Darin
Unidad organizativa: Fintech
Nombre de la organización: Robert Darin
Ciudad: Tu Ciudad
Estado: Tu Estado  
Código de país: MX
```

### ⚠️ IMPORTANTE
- Guarda el keystore y contraseñas en lugar SEGURO
- Si pierdes el keystore, NO podrás actualizar la app nunca
- Haz backup en la nube (Google Drive, etc.)

---

## 🔑 PASO 2: CONFIGURAR key.properties

1. Copia el archivo template:
```bash
cd android
copy key.properties.template key.properties
```

2. Edita `key.properties` con tus valores:
```properties
storePassword=TU_PASSWORD
keyPassword=TU_PASSWORD
keyAlias=robertdarin
storeFile=../keystores/robert-darin-key.jks
```

---

## 📦 PASO 3: GENERAR APP BUNDLE (RECOMENDADO)

Google Play prefiere App Bundle (.aab) sobre APK:

```bash
# Limpiar build anterior
flutter clean
flutter pub get

# Generar App Bundle
flutter build appbundle --release
```

El archivo se genera en:
```
build/app/outputs/bundle/release/app-release.aab
```

### O generar APK tradicional:
```bash
flutter build apk --release
```

---

## 🏪 PASO 4: CREAR CUENTA DE GOOGLE PLAY CONSOLE

1. Ve a: https://play.google.com/console
2. Inicia sesión con cuenta Google
3. Paga tarifa única de $25 USD
4. Completa información del desarrollador

---

## 📝 PASO 5: CREAR FICHA DE LA APP

### Información Básica
- **Nombre:** Robert Darin Fintech
- **Descripción corta (80 caracteres):**
  ```
  Gestiona préstamos, tandas y cobros de tu negocio financiero fácilmente
  ```
- **Descripción larga:**
  ```
  Robert Darin Fintech es la solución completa para administrar tu negocio 
  de préstamos y servicios financieros.

  ✨ CARACTERÍSTICAS PRINCIPALES:
  
  📊 PRÉSTAMOS
  • Préstamos mensuales con amortización automática
  • Arquilado (préstamos diarios) con 4 variantes
  • Cálculo automático de intereses
  • Seguimiento de pagos y vencimientos
  
  💰 TANDAS
  • Gestión de tandas con múltiples participantes
  • Control de turnos y pagos
  • Notificaciones automáticas
  
  📱 COBROS
  • Registro de pagos en campo
  • Comprobantes con foto
  • Geolocalización de cobranzas
  • Confirmación en tiempo real
  
  👥 CLIENTES
  • Base de datos completa de clientes
  • Historial de préstamos
  • Sistema de avales
  
  📈 REPORTES
  • Dashboard con KPIs
  • Reportes financieros
  • Exportación a PDF
  
  🔒 SEGURIDAD
  • Autenticación segura
  • Roles y permisos
  • Auditoría completa
  
  🎨 DISEÑO PREMIUM
  • Interfaz moderna y elegante
  • Tema oscuro profesional
  • Fácil de usar
  
  Ideal para prestamistas, cajas de ahorro, tandas y negocios financieros.
  ```

### Categoría
- **Tipo:** Aplicación
- **Categoría:** Finanzas
- **Subcategoría:** Gestión financiera

### Clasificación de Contenido
- Completar cuestionario IARC
- Clasificación esperada: Para todos

---

## 📸 PASO 6: CAPTURAS DE PANTALLA

### Requerimientos:
- **Teléfono:** Mínimo 2, máximo 8 (JPEG o PNG de 24 bits)
- **Dimensiones:** 320px a 3840px (sin exceder relación 2:1)
- **Recomendado:** 1080 x 1920 px

### Pantallas sugeridas para capturar:
1. Dashboard principal
2. Lista de préstamos
3. Detalle de préstamo con amortización
4. Pantalla de tandas
5. Registro de cobro/pago
6. Lista de clientes
7. Reportes/KPIs
8. Pantalla de moras

---

## 🖼️ PASO 7: GRÁFICOS REQUERIDOS

### Ícono de Alta Resolución
- **Tamaño:** 512 x 512 px
- **Formato:** PNG de 32 bits con alfa
- **Sin transparencia** en los bordes

### Gráfico de Funciones (Feature Graphic)
- **Tamaño:** 1024 x 500 px
- **Se muestra en la parte superior de la ficha**

---

## 🔗 PASO 8: POLÍTICA DE PRIVACIDAD

Sube la política de privacidad a un sitio web público:

**Opciones gratuitas:**
1. GitHub Pages
2. Google Sites
3. Notion (página pública)

**URL sugerida:** 
```
https://tu-sitio.com/privacidad
```

El contenido está en: `docs/POLITICA_PRIVACIDAD.md`

---

## ⚙️ PASO 9: CONFIGURACIÓN DE LANZAMIENTO

### Tipo de Lanzamiento
- **Producción:** Para todos los usuarios
- **Prueba cerrada:** Invitar testers específicos (recomendado primero)
- **Prueba abierta:** Cualquiera puede probar

### Países
- Seleccionar México y países de interés

### Precios
- **Gratis** (modelo recomendado)
- Monetización futura via suscripciones (si aplica)

---

## 📤 PASO 10: SUBIR Y PUBLICAR

1. En Play Console > Versiones > Producción
2. Crear nueva versión
3. Subir `app-release.aab`
4. Agregar notas de la versión:
   ```
   Versión 10.6.0
   
   ✨ Novedades:
   • Sistema de moras para préstamos y tandas
   • 4 variantes de arquilado (diario)
   • Mejoras de rendimiento
   • Correcciones de errores
   ```
5. Revisar y publicar

---

## ⏱️ TIEMPOS DE REVISIÓN

- **Primera revisión:** 7-14 días
- **Actualizaciones:** 1-3 días
- Google puede solicitar información adicional

---

## 🔄 PARA FUTURAS ACTUALIZACIONES

1. Incrementar `versionCode` en `build.gradle.kts`:
   ```kotlin
   versionCode = 107  // Incrementar siempre
   versionName = "10.7.0"
   ```

2. Regenerar App Bundle:
   ```bash
   flutter build appbundle --release
   ```

3. Subir nueva versión en Play Console

---

## 📞 SOPORTE

- **Email:** rdarinel92@gmail.com
- **Documentación:** Ver carpeta `docs/`

---

## 🎯 RESUMEN RÁPIDO

```bash
# 1. Generar keystore (solo una vez)
keytool -genkey -v -keystore android/keystores/robert-darin-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias robertdarin

# 2. Configurar key.properties
# (editar manualmente)

# 3. Generar bundle
flutter clean
flutter pub get
flutter build appbundle --release

# 4. Subir a Play Console
# (proceso manual en web)
```

---

**Última actualización:** 19 de enero de 2026  
**Versión preparada:** 10.35.0
