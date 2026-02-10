# Arquitectura Maestra - Robert Darin Fintech (V10.5)

Este documento proporciona una visión general técnica y operativa para el desarrollo continuo del proyecto.

> ⚠️ **IMPORTANTE**: Leer `.github/copilot-instructions.md` para reglas completas de desarrollo.

---

## 1. Visión General del Proyecto
Plataforma Fintech de nivel corporativo para la gestión de préstamos, tandas (ahorro grupal) y administración de personal. El sistema es **multi-rol** y **multi-usuario**, con dashboards diferenciados y un chat nativo avanzado.

### Módulos Principales (V10.5)
- **Préstamos Tradicionales**: Mensuales, quincenales, semanales
- **Préstamos Diarios (Arquilado)**: Cobro diario con cuota fija
- **Tandas**: Ahorro grupal con turnos asignados
- **Avales**: Sistema de garantías múltiples
- **Cobros**: Registro y confirmación de pagos
- **Mis Propiedades**: Tracking de pagos de terrenos/inmuebles
- **Auditoría Legal**: Expedientes para juicios
- **Centro de Control**: Configuración global (superadmin)

## 2. Stack Tecnológico
| Componente | Tecnología | Versión |
|------------|------------|---------|
| **Frontend** | Flutter | SDK >=3.3.0 <4.0.0 |
| **Backend** | Supabase | v2.0.8 |
| **Base de datos** | PostgreSQL | Via Supabase |
| **Auth** | Supabase Auth | Integrado |
| **Storage** | Supabase Storage | Integrado |
| **Estado** | Provider | v6.1.2 |
| **Arquitectura** | Clean Architecture | Modelos → Repos → Controllers → Views |
| **Diseño** | Premium 4K / Glassmorphism | Custom |

## 3. Lógica de Roles y Seguridad
Existen 4 niveles de acceso definidos en `database_schema.sql` y `auth_viewmodel.dart`:

| Rol | Nivel | Acceso |
|-----|-------|--------|
| **Superadmin** | 1 | Control total: Auditoría, Roles, Sucursales, Usuarios, Configuración |
| **Admin** | 2 | Gerente: Clientes, Préstamos, Empleados, Reportes |
| **Operador** | 3 | Cajero: Registro de cobros, visualización operativa |
| **Cliente** | 4 | Usuario final: Sus deudas, ahorros, garantías |

### Permisos Granulares (23 permisos base)
```
usuarios.*     → ver, crear, editar, eliminar
clientes.*     → ver, crear, editar, eliminar
prestamos.*    → ver, crear, aprobar, eliminar
pagos.*        → ver, registrar, eliminar
tandas.*       → ver, crear, administrar
reportes.*     → ver, exportar
configuracion.*→ ver, editar
auditoria.*    → ver
```

## 4. Módulos Críticos e Inteligencia

### A. Motor de Préstamos (V2.4)
- **Ubicación**: `lib/modules/finanzas/prestamos/`
- **Calculadora Dual**: Interés % o Cuota Fija
- **Frecuencias**: Semanal, Quincenal, Mensual (campo `frecuencia_pago`)
- **Amortización**: Generación automática de cuotas
- **Documentos**: Tabla `comprobantes_prestamo` para contratos/pagarés

### B. Gestión de Tandas (V2.0)
- **Ubicación**: `lib/modules/finanzas/tandas/`
- **Asignación Manual**: Superadmin asigna clientes a turnos
- **Avales**: Soporte para garantías en tandas
- **Tracking**: `ha_pagado_cuota_actual`, `ha_recibido_bolsa`

### C. Sistema de Chat Nativo (V2.0)
- **Tablas Legacy**: `chats`, `mensajes` (chat 1-a-1)
- **Tablas Avanzadas**: `chat_conversaciones`, `chat_mensajes`, `chat_participantes`
- **Tipos de mensaje**: texto, imagen, documento, audio, ubicación
- **Integridad**: Campo `hash_contenido` para verificación
- **Privacidad**: RLS por participante

### D. Sistema de Notificaciones
- **Tabla**: `notificaciones`
- **Tipos**: info, warning, success, error, pago, cobranza
- **Auto-trigger**: Notificación automática en pagos vencidos
- **Deep links**: Campo `enlace` para navegación directa

### E. Auditoría Completa
- **Básica**: Tabla `auditoria` (acción, módulo, detalles JSONB)
- **Acceso**: Tabla `auditoria_acceso` (IP, geo, dispositivo, hash)
- **Legal**: Tabla `auditoria_legal` (firmas, contratos, hash documento)

## 5. Estructura de Navegación
```
lib/ui/navigation/
├── app_routes.dart      → Mapa central de rutas
└── app_shell.dart       → Menú lateral por rol

Componentes Premium:
├── PremiumScaffold      → AppBar + Logout + Back button
├── PremiumCard          → Cards con glassmorphism
└── PremiumButton        → Botones estilizados
```

## 6. Base de Datos (SQL Maestro V8.0)

### Tablas Principales (18 tablas)
```
IDENTIDAD:        roles, permisos, roles_permisos, usuarios, usuarios_roles
EMPRESA:          sucursales, empleados
CLIENTES:         clientes, expediente_clientes
FINANZAS:         prestamos, amortizaciones, avales, pagos, comprobantes_prestamo
DIARIOS:          prestamos_diarios, pagos_diarios
TANDAS:           tandas, tanda_participantes
COMUNICACIÓN:     chat_conversaciones, chat_mensajes, chat_participantes, chats, mensajes
PROPIEDADES:      mis_propiedades, pagos_propiedades
LEGAL:            expedientes_legales, seguimiento_judicial, intentos_cobro
SISTEMA:          calendario, auditoria, auditoria_acceso, auditoria_legal, notificaciones, configuracion
```

### Características de Seguridad
- **RLS**: Activo en TODAS las tablas
- **Políticas**: Granulares por operación (SELECT/INSERT/UPDATE/DELETE)
- **Funciones Helper**: `usuario_tiene_rol()`, `es_admin_o_superior()`
- **Triggers**: Auto-asignación superadmin, updated_at automático

### Índices de Rendimiento (30+)
Optimización en campos de búsqueda frecuente:
- Clientes: nombre, email, telefono, sucursal_id
- Préstamos: cliente_id, estado, fecha_creacion
- Pagos: prestamo_id, fecha_pago, cliente_id
- Amortizaciones: prestamo_id, estado, fecha_vencimiento
- Chat: conversacion_id, created_at

## 7. Modelos Flutter (19 archivos)

### Patrón de Modelo con Supabase
```dart
class PrestamoModel {
  // Campos
  final String id;
  final String clienteId;
  // ...

  // Constructor
  PrestamoModel({required this.id, ...});

  // Deserialización
  factory PrestamoModel.fromMap(Map<String, dynamic> map) {...}

  // Para UPDATE (incluye id)
  Map<String, dynamic> toMap() {...}

  // Para INSERT (sin id - Supabase lo genera)
  Map<String, dynamic> toMapForInsert() {...}
}
```

## 8. Providers Configurados (main.dart)
```dart
providers: [
  ChangeNotifierProvider(create: (_) => AuthViewModel()),
  Provider(create: (_) => PrestamosController(repository: PrestamosRepository())),
  Provider(create: (_) => TandasController(repository: TandasRepository())),
  Provider(create: (_) => UsuariosController(repository: UsuariosRepository())),
  Provider(create: (_) => AvalesController(repository: AvalesRepository())),
  Provider(create: (_) => PagosController(repository: PagosRepository())),
]
```

## 9. Reglas de Desarrollo (⚠️ IMPORTANTE)

| Regla | Descripción |
|-------|-------------|
| 🚫 No Eliminar | Prohibido borrar pantallas o módulos existentes |
| 🎨 No Simplificar | Mantener componentes Premium y estética 4K |
| ✅ Validación | Todo formulario valida antes de enviar a Supabase |
| 📦 toMapForInsert | Usar para INSERT (sin id), toMap para UPDATE |
| 🔐 RLS | Respetar políticas de seguridad por fila |
| 📝 Backup | Solo actualizar BASE_LINE_SNAPSHOT.md bajo instrucción directa |

## 10. Configuración del Sistema (Tabla configuracion)

| Clave | Valor Default | Descripción |
|-------|---------------|-------------|
| tasa_interes_default | 5 | Tasa mensual % |
| plazo_maximo_meses | 24 | Máximo plazo |
| monto_minimo_prestamo | 1000 | Mínimo préstamo |
| monto_maximo_prestamo | 500000 | Máximo préstamo |
| dias_gracia_pago | 3 | Días antes de vencido |
| requiere_aval | true | Aval obligatorio |
| nombre_empresa | Robert Darin Fintech | Nombre |
| moneda | MXN | Moneda del sistema |

---

**VERSIÓN:** 10.5
**ÚLTIMA ACTUALIZACIÓN:** 10 de Enero, 2026
**DOCUMENTACIÓN:** Preparada para transferencia de asistente

> 📖 Ver `.github/copilot-instructions.md` para guía completa de desarrollo
