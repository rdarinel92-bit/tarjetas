# 📋 Declaración de Permisos - Uniko v1.0.0

## Para Google Play Console - Data Safety & Permissions

---

## 🔐 Resumen de Permisos Solicitados

| Permiso | Categoría | Justificación |
|---------|-----------|---------------|
| INTERNET | Red | Conexión con servidor backend |
| ACCESS_NETWORK_STATE | Red | Verificar conectividad |
| CAMERA | Hardware | Capturar comprobantes de pago |
| ACCESS_FINE_LOCATION | Ubicación | Geolocalizar cobros y servicios |
| ACCESS_COARSE_LOCATION | Ubicación | Respaldo de ubicación |
| POST_NOTIFICATIONS | Sistema | Alertas de pagos y recordatorios |
| READ_MEDIA_IMAGES | Almacenamiento | Seleccionar comprobantes existentes |

---

## 📍 JUSTIFICACIÓN DE UBICACIÓN

### ¿Por qué Uniko necesita acceso a la ubicación?

Uniko es una plataforma de gestión financiera y servicios de campo que requiere ubicación en **PRIMER PLANO ÚNICAMENTE** para:

#### 1. Rutas de Cobranza (Payment Collection Routes)
- Los cobradores de campo registran su ubicación exacta al momento de recibir pagos en efectivo
- Esto proporciona un comprobante geolocalizado para auditoría y seguridad
- Protege tanto al cobrador como al cliente con evidencia de la transacción

#### 2. Servicios Técnicos de Clima/HVAC (Field Service)
- Los técnicos comparten su ubicación para que los clientes puedan rastrear cuándo llegará el servicio
- Similar a servicios de entrega o transporte

#### 3. Verificación de Pagos con QR (Payment Verification)
- Al generar códigos QR de cobro, se registra la ubicación como evidencia
- Previene fraudes y proporciona trazabilidad de transacciones

### ⚠️ IMPORTANTE: NO usamos ACCESS_BACKGROUND_LOCATION
- La ubicación SOLO se accede cuando el usuario activamente realiza una acción
- No hay rastreo en segundo plano
- No hay recopilación pasiva de ubicación
- El usuario siempre está consciente cuando se accede a su ubicación

---

## 📷 JUSTIFICACIÓN DE CÁMARA

### ¿Por qué Uniko necesita acceso a la cámara?

#### 1. Comprobantes de Pago
- Capturar fotografías de recibos de pago
- Documentar transacciones en efectivo

#### 2. Documentos de Identificación
- Fotografiar INE/IFE para verificación de clientes
- Digitalizar documentos de avales

#### 3. Escaneo de Códigos QR
- Escanear QR para procesar pagos
- Leer códigos de servicios

### Nota: La cámara NO es requerida
```xml
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```
La app funciona sin cámara, solo es una característica opcional.

---

## 🔔 JUSTIFICACIÓN DE NOTIFICACIONES

### ¿Por qué Uniko necesita enviar notificaciones?

1. **Recordatorios de pago**: Alertar a clientes sobre pagos próximos a vencer
2. **Confirmaciones**: Notificar cuando un pago fue recibido exitosamente
3. **Alertas de mora**: Informar sobre pagos atrasados
4. **Mensajes del sistema**: Comunicaciones importantes del administrador
5. **Actualizaciones de servicios**: Estado de órdenes de servicio técnico

---

## 📊 DATA SAFETY - Datos Recopilados

### Información Personal
| Dato | Propósito | Compartido | Opcional |
|------|-----------|------------|----------|
| Nombre | Identificación de cuenta | No | No |
| Email | Login y comunicaciones | No | No |
| Teléfono | Contacto y verificación | No | No |
| Dirección | Servicios a domicilio | No | Sí |

### Información Financiera
| Dato | Propósito | Compartido | Opcional |
|------|-----------|------------|----------|
| Historial de pagos | Gestión de préstamos | No | No |
| Montos de préstamos | Cálculo de amortizaciones | No | No |

### Ubicación
| Dato | Propósito | Compartido | Opcional |
|------|-----------|------------|----------|
| Ubicación precisa | Geolocalizar cobros | No | Sí |

### Fotos
| Dato | Propósito | Compartido | Opcional |
|------|-----------|------------|----------|
| Comprobantes | Evidencia de pagos | No | Sí |
| Documentos | Verificación de identidad | No | Sí |

---

## 🔒 Seguridad de Datos

- **Encriptación en tránsito**: Todas las conexiones usan HTTPS/TLS
- **Almacenamiento seguro**: Datos almacenados en Supabase con RLS
- **Sin venta de datos**: Los datos NUNCA se venden a terceros
- **Eliminación de cuenta**: Usuario puede solicitar eliminación completa

---

## 📝 Texto para Google Play Console

### Short Description (80 caracteres)
```
Gestiona préstamos, tandas, cobros y servicios técnicos en una sola app.
```

### Full Description
```
Uniko es tu plataforma integral para gestión financiera y servicios:

✅ PRÉSTAMOS
- Calcula amortizaciones automáticamente
- Genera contratos digitales
- Rastrea pagos y vencimientos

✅ TANDAS (Ahorro Grupal)
- Organiza grupos de ahorro
- Controla turnos y aportaciones
- Notifica automáticamente

✅ COBRANZA DE CAMPO
- Rutas optimizadas para cobradores
- Comprobantes geolocalizados
- Historial completo de pagos

✅ SERVICIOS TÉCNICOS
- Agenda citas de servicio
- Seguimiento en tiempo real
- Portal para clientes

🔒 SEGURO Y CONFIABLE
- Datos encriptados
- Respaldos automáticos
- Control de acceso por roles

Ideal para: Prestamistas, organizadores de tandas, empresas de servicios y cobranza.
```

---

## ✅ Checklist Pre-Publicación

- [x] AndroidManifest.xml con justificaciones
- [x] No usa ACCESS_BACKGROUND_LOCATION
- [x] Cámara marcada como no requerida
- [x] Network Security Config (solo HTTPS)
- [x] Política de privacidad disponible
- [x] Términos de servicio disponibles

---

**Última actualización**: Enero 2026
**Versión**: 1.0.0
**Package**: com.robertdarin.fintech
