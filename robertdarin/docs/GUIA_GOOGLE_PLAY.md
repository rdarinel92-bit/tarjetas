# 🚀 GUÍA COMPLETA: Publicar Uniko en Google Play Store

## 📋 Estado de Preparación

| Requisito | Estado | Notas |
|-----------|--------|-------|
| ✅ Keystore creado | Listo | `android/keystores/robert-darin-key.jks` |
| ✅ key.properties | Listo | Configurado con credenciales |
| ✅ Firma de release | Listo | build.gradle.kts configurado |
| ✅ Versión actualizada | Listo | 10.52.0 (versionCode: 10520) |
| ✅ applicationId | Listo | `com.robertdarin.fintech` |
| ✅ targetSdk | Listo | 35 (Android 15) |
| ✅ Permisos | Listo | AndroidManifest.xml completo |
| ✅ ProGuard | Listo | Minificación habilitada |

---

## 🔧 PASO 1: Generar el App Bundle

### Opción A: Script automático (Recomendado)
```powershell
.\build_play_store.ps1
```

### Opción B: Comandos manuales
```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

### 📦 Archivo generado:
```
build\app\outputs\bundle\release\app-release.aab
```

---

## 📱 PASO 2: Google Play Console

### 2.1 Crear cuenta de desarrollador
1. Ir a: https://play.google.com/console
2. Pagar tarifa única de $25 USD
3. Verificar identidad (puede tardar 48h)

### 2.2 Crear nueva aplicación
1. Click en "Crear app"
2. Nombre: **Uniko - Gestión Financiera**
3. Idioma predeterminado: **Español (México)**
4. Tipo: **App**
5. Gratis o de pago: **Gratis**

---

## 📝 PASO 3: Ficha de Play Store

### 3.1 Información básica

**Nombre de la app:**
```
Uniko - Gestión Financiera
```

**Descripción breve (80 caracteres max):**
```
Tu negocio simplificado: préstamos, tandas, cobros y más en una sola app.
```

**Descripción completa (4000 caracteres max):**
```
🏦 UNIKO - Tu socio financiero digital

Uniko es la solución integral para gestionar tu negocio financiero. Ya sea que manejes préstamos personales, tandas de ahorro, servicios de climas o cobranza, Uniko te ayuda a mantener todo organizado y bajo control.

✨ CARACTERÍSTICAS PRINCIPALES:

💰 PRÉSTAMOS
• Gestión completa de préstamos personales
• Cálculo automático de intereses y amortizaciones
• Seguimiento de pagos y morosidad
• Generación de tablas de amortización
• Recordatorios automáticos de cobro

🤝 TANDAS (Ahorro Grupal)
• Crea y administra tandas de ahorro
• Control de participantes y turnos
• Notificaciones de pagos pendientes
• Historial completo de movimientos

💳 TARJETAS DIGITALES
• Emisión de tarjetas virtuales
• Control de límites y saldos
• Historial de transacciones

📊 REPORTES Y ANÁLISIS
• Dashboard con KPIs en tiempo real
• Reportes de cartera y morosidad
• Estadísticas de negocio
• Exportación de datos

🔔 NOTIFICACIONES INTELIGENTES
• Alertas de pagos próximos
• Recordatorios de cobro
• Notificaciones push en tiempo real

🔐 SEGURIDAD
• Autenticación segura
• Datos encriptados
• Respaldo automático en la nube

📱 INTERFAZ MODERNA
• Diseño intuitivo y elegante
• Modo oscuro premium
• Navegación fluida

👥 MULTIUSUARIO
• Roles y permisos configurables
• Gestión de empleados
• Control de acceso por sucursal

Uniko está diseñado para emprendedores, prestamistas, organizadores de tandas y cualquier persona que necesite gestionar finanzas de manera profesional.

¡Descarga Uniko y lleva tu negocio al siguiente nivel!

📧 Soporte: soporte@robertdarin.com
🌐 Web: www.robertdarin.com
```

### 3.2 Gráficos requeridos

| Tipo | Tamaño | Cantidad |
|------|--------|----------|
| Ícono de app | 512x512 px | 1 |
| Gráfico de funciones | 1024x500 px | 1 |
| Capturas de pantalla (teléfono) | 1080x1920 px | 2-8 |
| Capturas de pantalla (tablet 7") | 1080x1920 px | Opcional |
| Capturas de pantalla (tablet 10") | 1920x1200 px | Opcional |

### 3.3 Categorización

- **Categoría:** Finanzas
- **Etiquetas:** préstamos, finanzas, tandas, gestión, negocios
- **Clasificación de contenido:** Completar cuestionario
- **Público objetivo:** Adultos (18+)

---

## 📋 PASO 4: Configuración de la app

### 4.1 Política de privacidad
```
https://www.robertdarin.com/privacidad
```
(Ya tienes el archivo en: `docs/politica-privacidad.html`)

### 4.2 Declaraciones

**¿Tu app usa anuncios?** No

**¿Tu app es una app de noticias?** No

**¿Tu app tiene funciones sociales?** Sí (chat interno)

**¿Tu app accede a datos de salud?** No

**¿Tu app accede a datos financieros?** Sí
- Declarar: "La app gestiona información de préstamos y pagos"

**¿Tu app usa datos de ubicación?** Sí
- Declarar: "Para geolocalización de cobros"

---

## 🔐 PASO 5: Firma de la app

### 5.1 Play App Signing (Recomendado)
Google Play gestionará la firma de tu app. Esto es más seguro.

1. En Play Console, ir a: **Configuración > Firma de la app**
2. Seleccionar: **Usar Play App Signing**
3. Subir tu keystore o dejar que Google genere uno nuevo

### 5.2 Información del Keystore actual
```
Alias: robertdarin
Archivo: android/keystores/robert-darin-key.jks
Validez: 10,000 días (~27 años)
Algoritmo: RSA 2048
```

---

## 📤 PASO 6: Subir la versión

1. Ir a: **Producción > Crear nueva versión**
2. Subir el archivo `app-release.aab`
3. Notas de la versión:

```
🎉 Versión 10.52.0

✨ Novedades:
• Nuevo logo profesional de Uniko
• Tarjetas de presentación con código QR
• Panel de control mejorado para superadmin
• Optimizaciones de rendimiento

🐛 Correcciones:
• Mejoras de estabilidad general
• Optimización de carga de datos
```

4. Click en **Revisar versión**
5. Click en **Iniciar lanzamiento a producción**

---

## ⏱️ PASO 7: Revisión de Google

- **Tiempo estimado:** 1-7 días (primera vez puede ser más)
- **Estado:** Puedes verlo en Play Console

### Posibles motivos de rechazo:
- Política de privacidad faltante
- Capturas de pantalla no representativas
- Permisos sin justificar
- Contenido inapropiado

---

## 📊 PASO 8: Post-lanzamiento

### Monitoreo
- **Android Vitals:** Crashes, ANRs, rendimiento
- **Estadísticas:** Descargas, retención, calificaciones
- **Reseñas:** Responder a usuarios

### Actualizaciones
- Incrementar `versionCode` en cada actualización
- Subir nuevo `.aab`
- Escribir notas de versión

---

## 🆘 Solución de problemas

### Error: "App not signed correctly"
```powershell
# Verificar firma del AAB
jarsigner -verify -verbose -certs build\app\outputs\bundle\release\app-release.aab
```

### Error: "Version code already used"
- Incrementar `versionCode` en `build.gradle.kts`

### Error: "Target SDK too low"
- Ya está configurado en targetSdk = 35

---

## 📞 Contacto y Soporte

- **Email:** soporte@robertdarin.com
- **Web:** www.robertdarin.com

---

**Última actualización:** Enero 2026
**Versión de la app:** 10.52.0
