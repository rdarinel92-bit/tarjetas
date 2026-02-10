# 🚀 Robert Darin Fintech - Ecosistema Completo

> Plataforma Fintech de nivel empresarial para gestión de préstamos, tandas, cobros y tarjetas digitales de contacto.

[![Flutter](https://img.shields.io/badge/Flutter-3.3.0-blue.svg)](https://flutter.dev/)
[![Supabase](https://img.shields.io/badge/Supabase-2.0.8-green.svg)](https://supabase.com/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

## 📱 Componentes del Proyecto

### 1. App Móvil (Flutter) - `/robertdarin/`
Aplicación Android para gestión integral de negocio con **12,000+ líneas** de código Dart.

**Módulos principales:**
- 💰 **Préstamos**: Mensuales, quincenales, semanales y diarios (arquilado)
- 👥 **Tandas**: Sistema de ahorro grupal con turnos asignados
- 🛡️ **Avales**: Gestión de garantías múltiples
- 💬 **Chat Nativo**: Mensajería en tiempo real con tipos: texto, imagen, documento, audio
- 👤 **Roles y Permisos**: 4 niveles (Superadmin, Admin, Operador, Cliente) con 23 permisos granulares
- 💎 **Nice Joyería MLM**: Venta por catálogo con 6 niveles y comisiones multinivel
- 📊 **Dashboards Avanzados**: Analytics interactivos con gráficas profesionales
- 🔐 **Auditoría Legal**: Sistema de expedientes para gestión judicial

**Stack técnico:**
```yaml
Flutter SDK: >=3.3.0 <4.0.0
Backend: Supabase (PostgreSQL + Auth + Storage)
Estado: Provider
Notificaciones: Firebase Cloud Messaging
Deep Links: app_links (QR → App)
Gráficas: fl_chart
Seguridad: flutter_secure_storage + local_auth
```

### 2. Tarjetas Digitales Web - `/index.html`
Sistema de tarjetas de contacto digitales con QR codes (3,873 líneas).

**Características:**
- ✨ Tarjeta 3D interactiva con reverso tipo tarjeta de presentación
- 📝 Formularios dinámicos configurables desde Supabase
- 💬 Chat visitante-negocio con polling cada 5s
- 📊 Tracking completo de interacciones
- 🎨 Tema claro/oscuro con persistencia
- 📱 PWA instalable (Progressive Web App)
- 🔗 Integración: WhatsApp, Maps, Waze, vCard, QR

**Sistema modular de 10 tipos de negocio:**
```javascript
climas, finanzas, prestamos, tandas, cobranza, 
servicios, agua, nice, ventas, general
```

### 3. Sistema de Pedidos - `/pollos/index.html`
Plataforma de pedidos online para pollos asados (1,430 líneas mejorada).

**Nuevas características v2.0:**
- 🔍 Búsqueda en tiempo real de productos
- 💬 Envío directo por WhatsApp
- 💾 Persistencia del carrito en localStorage
- 📋 Historial de últimos 5 pedidos
- ✅ Validaciones en tiempo real (teléfono, nombre)
- 🎨 Tema claro/oscuro
- 📤 Compartir menú (Web Share API)
- 📅 Selector de fecha/hora de entrega
- 🔔 Toast notifications y vibración
- 🧮 Calculadora de pollos por personas

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────┐
│                  FRONTEND LAYER                      │
├─────────────────────────────────────────────────────┤
│  Flutter App          Web Tarjetas     Web Pollos   │
│  (Android/iOS)        (index.html)    (pollos/)     │
└──────────────┬────────────────┬───────────┬─────────┘
               │                │           │
               ▼                ▼           ▼
┌─────────────────────────────────────────────────────┐
│              SUPABASE BACKEND LAYER                  │
├─────────────────────────────────────────────────────┤
│  • PostgreSQL Database (40+ tables)                 │
│  • Row Level Security (RLS) por rol                 │
│  • Auth & User Management                           │
│  • Storage (documentos, imágenes)                   │
│  • Edge Functions & RPCs optimizadas                │
│  • Realtime Subscriptions (chat)                    │
└─────────────────────────────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────────────┐
│           EXTERNAL SERVICES LAYER                    │
├─────────────────────────────────────────────────────┤
│  • Firebase (Push, Analytics, Crashlytics)          │
│  • WhatsApp Business API                            │
│  • Google Maps & Waze                               │
│  • QR Code Generation                               │
└─────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Requisitos previos
- Flutter SDK 3.3.0+
- Android Studio / VS Code
- Node.js 18+ (para web)
- Supabase CLI (opcional)
- Git

### 1. Clonar repositorio
```bash
git clone https://github.com/rdarinel92-bit/tarjetas.git
cd tarjetas
```

### 2. Configurar App Flutter
```bash
cd robertdarin
flutter pub get
flutter run
```

### 3. Probar Web Apps
```bash
# Servidor simple con Python
python -m http.server 8000

# Abrir en navegador:
# http://localhost:8000?codigo=DEMO
# http://localhost:8000/pollos/
```

### 4. Configurar Firebase (opcional)
```bash
cd robertdarin/android/app
# Agregar google-services.json
# Ver: docs/FIREBASE_SETUP.md
```

## 📊 Base de Datos Supabase

### Tablas principales (40+)

**Core del sistema:**
```sql
usuarios                    -- Usuarios multi-rol con permisos
negocios                   -- Empresas/sucursales
clientes                   -- Base de clientes
prestamos                  -- Préstamos con amortización
cuotas_prestamo           -- Calendario de pagos
pagos                     -- Registro de cobros
tandas                    -- Ahorro grupal
participantes_tanda       -- Clientes en tandas
avales                    -- Garantías de préstamos
```

**Tarjetas digitales:**
```sql
tarjetas_servicio         -- Tarjetas por negocio/módulo
tarjetas_servicio_escaneos -- Tracking de visitas
tarjetas_servicio_solicitudes -- Leads del formulario
formularios_qr_config     -- Config dinámica desde app
tarjetas_chat            -- Chat visitante-negocio
```

**Sistema de pollos:**
```sql
pollos_config            -- Configuración del negocio
pollos_productos         -- Catálogo de productos
pollos_pedidos          -- Pedidos realizados
pollos_pedido_detalle   -- Items del pedido
```

### Funciones RPC optimizadas
```sql
get_dashboard_stats(negocio_id)           -- KPIs con cache
get_cuotas_vencidas(negocio_id, limit)    -- Mora con info de aval
get_resumen_cartera(negocio_id)           -- Estado por sucursal
get_historial_pagos_cliente(cliente_id)   -- Historial completo
get_estado_cuenta_prestamo(prestamo_id)   -- Desglose de préstamo
```

## 🎨 Características Destacadas

### ✨ App Flutter

**Diseño Premium 4K:**
- Glassmorphism y efectos avanzados
- Animaciones fluidas con flutter_animate
- Componentes reutilizables premium

**Seguridad:**
- Autenticación biométrica (huella/Face ID)
- Almacenamiento seguro (flutter_secure_storage)
- Auditoría completa de acciones
- Hash de contenido para integridad

**Performance:**
- Cache de estadísticas (1 hora)
- Índices compuestos en BD
- Vistas materializadas
- Lazy loading de listas

### 🌐 Web Tarjetas

**Sin frameworks:** Vanilla JS para máxima velocidad y portabilidad

**Mobile-first:**
- PWA instalable
- Soporte iOS y Android
- Responsive 100%
- Funciona offline parcialmente

**Integraciones:**
- vCard para guardar contacto
- Share API nativa
- QR codes dinámicos
- Deep links a WhatsApp

## 📁 Estructura del Proyecto

```
tarjetas/
├── .github/
│   └── copilot-instructions.md    # Guía para IA
├── robertdarin/                    # 🎯 App Flutter
│   ├── lib/
│   │   ├── modules/               # Módulos por feature
│   │   │   ├── auth/
│   │   │   ├── chat/
│   │   │   ├── clientes/
│   │   │   ├── finanzas/
│   │   │   │   ├── prestamos/
│   │   │   │   ├── tandas/
│   │   │   │   └── avales/
│   │   │   └── roles/
│   │   ├── ui/                   # Navegación y componentes
│   │   ├── data/                 # Modelos y repositorios
│   │   └── core/                 # Utils y theme
│   ├── android/                  # Build Android
│   ├── ios/                      # Build iOS
│   ├── docs/                     # Documentación técnica
│   ├── supabase/                 # Migraciones SQL
│   └── pubspec.yaml
├── index.html                     # 🌐 Tarjetas digitales
├── pollos/
│   └── index.html                 # 🍗 Sistema de pedidos
├── app/                           # APKs publicados
└── README.md                      # Este archivo
```

## 🔧 Scripts Útiles

### Flutter
```bash
# Build APK producción
cd robertdarin
flutter build apk --release

# Build App Bundle (Play Store)
flutter build appbundle --release

# Análisis de código
flutter analyze

# Tests
flutter test
```

### Supabase (PowerShell)
```powershell
# Aplicar migraciones
./deploy_supabase.ps1 push

# Descargar schema remoto
./deploy_supabase.ps1 pull

# Ver estado
./deploy_supabase.ps1 status

# Comparar diferencias
./deploy_supabase.ps1 diff
```

### Web
```bash
# Servidor local
python -m http.server 8000

# Minificar (requiere terser)
npx terser index.html -c -m -o index.min.html
```

## 📚 Documentación

- [Arquitectura Core](robertdarin/CORE_SYSTEM_ARCHITECTURE.md)
- [Snapshot Baseline](robertdarin/BASE_LINE_SNAPSHOT.md)
- [Guía Firebase](robertdarin/android/app/FIREBASE_SETUP.md)
- [Políticas Privacidad](robertdarin/docs/POLITICA_PRIVACIDAD.md)
- [Guía Play Store](robertdarin/docs/GUIA_GOOGLE_PLAY.md)
- [Copilot Instructions](.github/copilot-instructions.md)

## 🔐 Seguridad

- ✅ Row Level Security (RLS) en todas las tablas
- ✅ Anon Key pública segura en frontend
- ✅ Hash SHA-256 para integridad de mensajes
- ✅ Auditoría completa con IP y geolocalización
- ✅ Autenticación biométrica en app
- ✅ Almacenamiento encriptado local

## 📈 Métricas del Proyecto

| Métrica | Valor |
|---------|-------|
| Líneas de código Dart | ~12,000 |
| Líneas HTML/JS (web) | ~5,300 |
| Tablas en BD | 40+ |
| Funciones RPC | 15+ |
| Módulos Flutter | 5 principales |
| Pantallas | 50+ |
| Versión actual | 10.30 |

## 🛠️ Tecnologías

**Frontend:**
- Flutter 3.3.0+
- Dart
- HTML5/CSS3/JavaScript (vanilla)

**Backend:**
- Supabase (PostgreSQL 15)
- Edge Functions
- Realtime

**Cloud:**
- Firebase Cloud Messaging
- Firebase Crashlytics
- Firebase Analytics

**Herramientas:**
- VS Code / Android Studio
- Git / GitHub
- Supabase CLI
- PowerShell (scripts)

## 🤝 Contribución

Este es un proyecto privado. Para colaboradores:

1. Fork del repositorio
2. Crear rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit cambios (`git commit -am 'Add: nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Crear Pull Request

### Convenciones de commits
```
feat: Nueva característica
fix: Corrección de bug
docs: Cambios en documentación
style: Formato, punto y coma, etc
refactor: Refactorización de código
test: Agregar tests
chore: Mantenimiento
```

## 📄 Licencia

Propietario - Todos los derechos reservados © 2026 Robert Darin

## 👨‍💻 Autor

**Robert Darin**
- GitHub: [@rdarinel92-bit](https://github.com/rdarinel92-bit)

## 📞 Soporte

Para soporte y consultas sobre el proyecto, contactar al equipo de desarrollo.

---

**Última actualización:** Febrero 2026  
**Versión:** 10.30  
**Estado:** ✅ En producción activa
