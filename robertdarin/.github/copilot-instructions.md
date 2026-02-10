# 🤖 INSTRUCCIONES PARA ASISTENTES DE IA - Robert Darin Fintech

> **DOCUMENTO CRÍTICO**: Lee esto COMPLETAMENTE antes de hacer cualquier cambio.
> Este archivo garantiza continuidad entre sesiones y asistentes.

---

## 🎯 IDENTIDAD DEL PROYECTO

**Nombre**: Robert Darin Fintech  
**Tipo**: Aplicación móvil financiera empresarial (préstamos, tandas, cobros)  
**Versión Actual**: 10.5  
**Plataforma**: Flutter + Supabase  
**Usuario Principal**: rdarinel992@gmail.com (superadmin)  
**Idioma de UI**: Español (México)

---

## ⛔ REGLAS ABSOLUTAS - NUNCA VIOLAR

### 1. NO ELIMINAR NADA
```
❌ PROHIBIDO eliminar archivos existentes
❌ PROHIBIDO eliminar funciones o métodos
❌ PROHIBIDO eliminar pantallas o widgets
❌ PROHIBIDO simplificar código "para limpieza"
❌ PROHIBIDO remover imports aunque parezcan no usarse
```

### 2. NO CREAR PROYECTOS NUEVOS
```
❌ PROHIBIDO crear nuevos proyectos Flutter
❌ PROHIBIDO cambiar la estructura de carpetas base
❌ PROHIBIDO modificar pubspec.yaml sin solicitud explícita
❌ PROHIBIDO cambiar configuración de Supabase
```

### 3. SOLO CONSTRUIR Y MEJORAR
```
✅ PERMITIDO agregar nuevas funcionalidades
✅ PERMITIDO mejorar pantallas existentes
✅ PERMITIDO agregar nuevas tablas al SQL
✅ PERMITIDO crear nuevos modelos/screens/services
✅ PERMITIDO corregir bugs sin eliminar lógica
```

---

## 📁 ESTRUCTURA DEL PROYECTO

```
robertdarin/
├── lib/
│   ├── main.dart                    # Entry point + rutas
│   ├── core/
│   │   ├── supabase_client.dart     # Conexión Supabase
│   │   └── permisos_rol.dart        # Sistema de permisos
│   ├── data/
│   │   └── models/                  # 20+ modelos de datos
│   ├── modules/
│   │   ├── clientes/                # CRUD clientes
│   │   └── finanzas/
│   │       ├── prestamos/           # Motor de préstamos
│   │       └── tandas/              # Sistema de tandas
│   ├── services/                    # Servicios de negocio
│   ├── ui/
│   │   ├── components/              # Widgets reutilizables
│   │   ├── navigation/              # Rutas y shell
│   │   ├── screens/                 # 40+ pantallas
│   │   └── viewmodels/              # Estado de UI
│   └── providers/                   # Providers globales
├── database_schema.sql              # ⚠️ SQL MAESTRO (2200+ líneas)
├── BASE_LINE_SNAPSHOT.md            # Estado certificado del sistema
├── CORE_SYSTEM_ARCHITECTURE.md      # Arquitectura técnica
└── pubspec.yaml                     # Dependencias Flutter
```

---

## 🗄️ BASE DE DATOS (Supabase PostgreSQL)

### Archivo Maestro
**Ubicación**: `database_schema.sql`  
**Secciones**: 33  
**Tablas**: 67+  

### Secciones Principales
| # | Sección | Tablas Clave |
|---|---------|--------------|
| 1 | Identidad | roles, permisos, usuarios |
| 2 | Empresarial | negocios, sucursales, empleados |
| 4 | Préstamos | prestamos, amortizaciones |
| 5 | Tandas | tandas, tanda_participantes |
| 6 | Avales | avales, prestamos_avales |
| 7 | Pagos | pagos, comprobantes_prestamo |
| 28 | Auditoría Legal | expedientes_legales, seguimiento_judicial |
| 29 | Préstamos Diarios | prestamos_diarios, pagos_diarios |
| 32 | Propiedades | mis_propiedades, pagos_propiedades |

### Reglas SQL
```sql
-- SIEMPRE usar este patrón para nuevas tablas:
CREATE TABLE IF NOT EXISTS nueva_tabla (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- campos...
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- SIEMPRE habilitar RLS:
ALTER TABLE nueva_tabla ENABLE ROW LEVEL SECURITY;

-- SIEMPRE crear política básica:
CREATE POLICY "nueva_tabla_authenticated" ON nueva_tabla 
    FOR ALL USING (auth.role() = 'authenticated');
```

---

## 🎨 ESTILO VISUAL (CRÍTICO)

### Colores del Sistema
```dart
// Fondo principal - SIEMPRE usar
const Color fondoApp = Color(0xFF0D0D14);

// Colores de acento
const Color accentCyan = Color(0xFF00D9FF);
const Color accentPurple = Color(0xFF8B5CF6);
const Color successGreen = Color(0xFF10B981);
const Color warningYellow = Color(0xFFFBBF24);
const Color errorRed = Color(0xFFEF4444);

// Cards y superficies
const Color cardBg = Color(0xFF1A1A2E);
const Color cardBgLight = Color(0xFF16213E);
```

### Componentes Premium
```dart
// SIEMPRE usar PremiumScaffold en lugar de Scaffold normal
PremiumScaffold(
  title: 'Título',
  body: // contenido,
)

// SIEMPRE usar gradientes en headers
gradient: LinearGradient(
  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
)

// SIEMPRE usar bordes redondeados
borderRadius: BorderRadius.circular(16)
```

---

## 🔐 SISTEMA DE ROLES

### Jerarquía
```
superadmin > admin > operador > cliente
```

### Archivo de Permisos
**Ubicación**: `lib/core/permisos_rol.dart`

### Módulos Disponibles
```dart
modDashboard, modClientes, modPrestamos, modTandas, modAvales,
modEmpleados, modPagos, modChat, modCalendario, modReportes,
modAuditoria, modAuditoriaLegal, modUsuarios, modRoles,
modSucursales, modConfiguracion, modControlCenter, modCobros,
modNotificaciones, modDashboardKpi, modMisPropiedades
```

### Para Agregar Nuevo Módulo
1. Agregar constante en `permisos_rol.dart`:
   ```dart
   static const String modNuevoModulo = 'nuevo_modulo';
   ```
2. Agregar a permisos de roles (superadmin siempre)
3. Agregar MenuItemConPermiso en drawerItems
4. Agregar ruta en `app_routes.dart`
5. Agregar import y ruta en `main.dart`

---

## 📱 PATRONES DE CÓDIGO

### Modelo de Datos
```dart
class MiModelo {
  final String id;
  final String nombre;
  final DateTime createdAt;

  MiModelo({required this.id, required this.nombre, required this.createdAt});

  // SIEMPRE incluir fromMap
  factory MiModelo.fromMap(Map<String, dynamic> map) {
    return MiModelo(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      createdAt: DateTime.parse(map['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  // SIEMPRE incluir toMap (para UPDATE)
  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
  };

  // SIEMPRE incluir toMapForInsert (para INSERT - sin id)
  Map<String, dynamic> toMapForInsert() => {
    'nombre': nombre,
  };
}
```

### Pantalla Estándar
```dart
import 'package:flutter/material.dart';
import '../components/premium_scaffold.dart';
import '../../core/supabase_client.dart';

class MiNuevaPantalla extends StatefulWidget {
  const MiNuevaPantalla({super.key});
  @override
  State<MiNuevaPantalla> createState() => _MiNuevaPantallaState();
}

class _MiNuevaPantallaState extends State<MiNuevaPantalla> {
  bool _isLoading = true;
  List<dynamic> _datos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final res = await AppSupabase.client
          .from('mi_tabla')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _datos = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumScaffold(
      title: 'Mi Pantalla',
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    // Implementación...
  }
}
```

---

## 🚀 PROCESO PARA NUEVAS FUNCIONALIDADES

### Checklist Obligatorio
```
□ 1. Verificar que no existe funcionalidad similar
□ 2. Agregar tabla(s) en database_schema.sql si necesario
□ 3. Crear modelo(s) en lib/data/models/
□ 4. Crear servicio si hay lógica compleja
□ 5. Crear pantalla en lib/ui/screens/
□ 6. Agregar ruta en app_routes.dart
□ 7. Agregar import y ruta en main.dart
□ 8. Si requiere permiso: agregar módulo en permisos_rol.dart
□ 9. Verificar compilación: flutter build apk --release
□ 10. Actualizar BASE_LINE_SNAPSHOT.md si es cambio mayor
```

---

## 📋 MÓDULOS EXISTENTES (NO DUPLICAR)

| Módulo | Pantalla | Función |
|--------|----------|---------|
| Dashboard | DashboardScreen | Panel principal |
| Clientes | ClientesScreen | CRUD clientes |
| Préstamos | PrestamosScreen | Préstamos mensuales |
| Préstamos Diarios | PrestamoDiarioScreen | Arquilado/diario |
| Tandas | TandasScreen | Ahorro grupal |
| Avales | AvalesScreen | Garantías |
| Pagos | PagosScreen | Registro de pagos |
| Cobros | CobrosPendientesScreen | Confirmar/rechazar |
| Empleados | EmpleadosScreen | CRUD empleados |
| Sucursales | SucursalesScreen | CRUD sucursales |
| Chat | ChatListaScreen | Mensajería |
| Calendario | CalendarioScreen | Eventos |
| Reportes | ReportesScreen | Informes |
| Auditoría | AuditoriaScreen | Logs sistema |
| Auditoría Legal | AuditoriaLegalScreen | Expedientes juicio |
| Usuarios | UsuariosScreen | Gestión usuarios |
| Roles | RolesPermisosScreen | Permisos |
| Configuración | SettingsScreen | Ajustes |
| Control Center | SuperadminControlCenterScreen | Config global |
| Mis Propiedades | MisPropiedadesScreen | Terrenos/pagos |
| Notificaciones | NotificacionesScreen | Alertas |
| Dashboard KPIs | DashboardAvanzadoScreen | Métricas |

---

## 🔧 COMANDOS ÚTILES

```bash
# Compilar APK
flutter build apk --release

# Ubicación del APK generado
build/app/outputs/flutter-apk/app-release.apk

# Ver errores
flutter analyze

# Limpiar build
flutter clean && flutter pub get
```

---

## 📞 INFORMACIÓN DE CONTEXTO

### Supabase
- **URL**: Configurado en lib/core/supabase_client.dart
- **Tablas**: Ver database_schema.sql
- **Storage Buckets**: comprobantes, documentos, avatares

### Usuario de Pruebas
- **Email**: rdarinel992@gmail.com
- **Rol**: superadmin (asignado automáticamente por SQL)

---

## ⚠️ ERRORES COMUNES A EVITAR

1. **No usar `Scaffold` directamente** → Usar `PremiumScaffold`
2. **No hardcodear colores** → Usar constantes del tema
3. **No olvidar `if (mounted)`** → Antes de setState en async
4. **No usar `id` en INSERT** → Usar `toMapForInsert()`
5. **No crear tablas sin RLS** → Siempre habilitar seguridad
6. **No modificar sin leer contexto** → Leer BASE_LINE_SNAPSHOT.md primero

---

## 📚 ARCHIVOS DE REFERENCIA

| Archivo | Propósito |
|---------|-----------|
| `BASE_LINE_SNAPSHOT.md` | Estado certificado actual |
| `CORE_SYSTEM_ARCHITECTURE.md` | Arquitectura técnica |
| `database_schema.sql` | SQL maestro completo |
| `pubspec.yaml` | Dependencias |
| Esta guía | Instrucciones para IA |

---

**VERSIÓN DE INSTRUCCIONES**: 1.0  
**FECHA**: 10 de Enero, 2026  
**COMPATIBILIDAD**: Claude, GPT-4, Copilot, cualquier LLM

> 💡 **REGLA DE ORO**: Ante la duda, PREGUNTAR antes de modificar.
