# Copilot Instructions - Tarjetas Digitales

## Arquitectura General

Este proyecto es un **sistema de tarjetas digitales de contacto** con pedidos online, construido sin frameworks JavaScript. Todo el código está autocontenido en archivos HTML monolíticos con CSS y JS inline.

### Componentes Principales

1. **`/index.html`** - Tarjeta digital de presentación profesional (3873 líneas)
   - Sistema modular multi-negocio con códigos QR
   - Formulario dinámico configurable desde Supabase
   - Chat en tiempo real visitante-negocio
   - Secciones: servicios, redes sociales, horarios, ubicación, galería, catálogo, reseñas, agendamiento
   
2. **`/pollos/index.html`** - Sistema de pedidos de pollos asados (1430 líneas)
   - Calculadora de cantidad de pollos por personas
   - Carrito de compras con productos configurables
   - Integración WhatsApp para finalizar pedidos

3. **`/app/` y `/downloads/`** - Aplicaciones Android (.apk ~100MB)
   - App nativa para gestión del negocio
   - Sincronizada con las tarjetas web

## Backend: Supabase

**Base de datos PostgreSQL** accedida vía REST API con Row Level Security (RLS).

### Tablas Principales

```
tarjetas_servicio           - Tarjetas digitales por negocio/módulo
tarjetas_servicio_escaneos  - Tracking de visitas y acciones
tarjetas_servicio_solicitudes - Leads de formulario de contacto
formularios_qr_config       - Configuración dinámica de formularios
formularios_qr_envios       - Envíos de formularios personalizados
tarjetas_chat              - Mensajes de chat visitante-negocio
pollos_config              - Configuración del sistema de pollos
pollos_pedidos             - Pedidos realizados
climas_solicitudes_qr      - Solicitudes específicas del módulo climas
```

### Autenticación

- **Anon Key pública** en frontend (segura con RLS habilitado)
- Ofuscada pero no encriptada: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (dividida en array `_p`)
- URL base: `https://qtfsxfvxqiihnofrpmmu.supabase.co`

## Sistema de Módulos

Las tarjetas soportan 10 módulos de negocio con iconos y comportamientos específicos:

```javascript
const MODULO_ICONS = {
    climas: '❄️',     // Aire acondicionado
    finanzas: '💰',   // Servicios financieros
    prestamos: '🏦',  // Préstamos
    tandas: '👥',     // Tandas/grupos
    cobranza: '📋',   // Cobranza
    servicios: '🔧', // Servicios generales
    agua: '💧',       // Purificación de agua
    nice: '✨',       // Marca Nice
    ventas: '🛒',     // Ventas
    general: '💼'     // Propósito general
};
```

### Módulo Climas (ejemplo de especialización)

Envía solicitudes a `climas_solicitudes_qr` con mapeo específico de campos:
```javascript
{
    negocio_id, nombre_completo, telefono, email,
    direccion, tipo_servicio, notas_cliente, 
    estado: 'nueva', fuente: 'qr_web'
}
```

## Formularios Dinámicos

**Clave**: Los formularios se configuran desde la app y se sincronizan automáticamente.

### Jerarquía de Configuración
1. Config específica de tarjeta (`tarjeta_servicio_id`)
2. Config por módulo del negocio (`negocio_id + modulo`)
3. Config general del negocio (`negocio_id + modulo='general'`)
4. Campos por defecto (hardcoded)

### Estructura de `formularios_qr_config`
```javascript
{
    titulo_header: 'Texto personalizado',
    subtitulo_header: 'Subtítulo',
    color_header: '#00D9FF',
    mensaje_exito: 'Mensaje confirmación',
    campos: [
        {
            id: 'nombre',
            tipo: 'text|textarea|select|tel|email|number|date',
            label: 'Nombre completo',
            placeholder: '¿Cómo te llamas?',
            requerido: true,
            orden: 1,
            opciones: ['Op1', 'Op2'], // para tipo select
            activo: true
        }
    ]
}
```

## Flujo de Tracking

Cada interacción se registra en `tarjetas_servicio_escaneos`:

```javascript
{
    tarjeta_id: uuid,
    plataforma: 'ios|android|web',
    user_agent: string,
    accion: 'ver|whatsapp|llamar|guardar_contacto|compartir|formulario|chat_mensaje'
}
```

## Sistema de Chat

**Arquitectura sin WebSockets**: Polling cada 5 segundos cuando el chat está abierto.

### Identificación de Visitante
```javascript
// Generado una vez y guardado en localStorage
visitanteId = 'v_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
```

### Mensajes bidireccionales
```javascript
// tabla: tarjetas_chat
{
    tarjeta_id, negocio_id, visitante_id,
    visitante_nombre: string | null,
    mensaje: string,
    es_respuesta: boolean, // false=visitante, true=negocio
    created_at
}
```

**Notificación sonora**: Web Audio API genera beep al recibir respuesta del negocio.

## Características PWA

- Manifest inline (base64): instalable como app
- Tema: `#0D0D14` (oscuro) / `#F8F9FA` (claro)
- Theme color: `#D4AF37` (dorado)
- Mobile-first: viewport `user-scalable=no`
- iOS optimizado: `-webkit-` prefixes, safe areas

## Integraciones Externas

### WhatsApp Business
```javascript
const waUrl = `https://wa.me/${formatPhone(number)}?text=${encodeURIComponent(mensaje)}`;
// formatPhone: agrega código país (52 para México si falta)
```

### Mapas
- Google Maps: `https://www.google.com/maps?q=lat,lng`
- Waze: `https://waze.com/ul?ll=lat,lng&navigate=yes`

### QR Code
```javascript
const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(url)}&bgcolor=ffffff&color=1A1A1A`;
```

### vCard
Generado client-side para botón "Guardar Contacto":
```
BEGIN:VCARD
VERSION:3.0
FN:Nombre Negocio
ORG:Nombre Negocio
TEL;TYPE=CELL:5512345678
EMAIL:correo@ejemplo.com
ADR;TYPE=WORK:;;Dirección;Ciudad;
URL:https://...
NOTE:Contacto de tarjeta digital
END:VCARD
```

## Convenciones de Desarrollo

### Estructura de Código
- **Todo inline**: No hay archivos externos CSS/JS
- **Secciones delimitadas**: Comentarios con `═══` para bloques grandes
- **IDs semánticos**: `#businessName`, `#submitBtn`, `#chatMessages`
- **BEM parcial**: `.form-group`, `.chat-message.sent`, `.quick-btn.whatsapp`

### Estados y Animaciones
- `.hidden` = `display: none !important`
- `.loading` en botones = spinner visible, texto oculto
- Animaciones: `fadeIn`, `slideUp`, `bounceIn`, `shake`, `pulse`
- Transiciones: 0.3s ease (estándar)

### Responsive
```css
@media (max-width: 380px) { /* teléfonos pequeños */ }
@media (min-width: 381px) and (max-width: 480px) { /* teléfonos estándar */ }
/* Desktop > 480px usa estilos base */
```

### Paleta de Colores
```css
--primary: #D4AF37;        /* Dorado */
--bg-dark: #0D0D14;        /* Negro profundo */
--bg-card: #1A1A2E;        /* Gris oscuro */
--whatsapp: #25D366;       /* Verde WhatsApp */
--success: #10B981;        /* Verde éxito */
--error: #EF4444;          /* Rojo error */
```

## Debugging

### Console Logs Estructurados
```javascript
console.log('🚀 Iniciando...');
console.log('🔄 Supabase request:', endpoint);
console.log('✅ Tarjeta cargada:', nombre);
console.error('❌ Error:', error);
```

### Errores Comunes
1. **"Tarjeta no encontrada"**: Verificar `?codigo=XXX` en URL
2. **Timeout 10s**: Supabase no responde, revisar conexión
3. **Formulario no envía**: Campos requeridos vacíos
4. **Chat no carga**: `visitanteId` no generado

## Testing Local

```bash
# Servir con cualquier servidor estático
python -m http.server 8000
# Abrir: http://localhost:8000?codigo=DEMO&negocio=1&modulo=general

# No requiere build ni instalación de dependencias
```

## URLs de Producción

- Tarjeta: `https://tudominio.com/?codigo=ABC123`
- Pollos: `https://tudominio.com/pollos/`
- Parámetros opcionales: `&negocio=ID&modulo=TIPO`

## Notas Importantes

⚠️ **No usar frameworks**: El proyecto es deliberadamente vanilla para máxima portabilidad y velocidad.

✅ **Seguridad**: Las Anon Keys de Supabase son seguras en frontend si RLS está correctamente configurado.

📱 **Mobile-first**: Siempre probar en móvil real, no solo DevTools.

🎨 **Tema claro/oscuro**: Persistido en `localStorage.rd_theme`.

💬 **Chat**: No usa WebSockets por restricciones de Supabase free tier con RLS.

📊 **Analytics**: Cada interacción genera registro automático vía `registrarAccion()`.
