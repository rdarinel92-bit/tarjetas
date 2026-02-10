# 📝 Changelog

Todos los cambios notables en este proyecto serán documentados aquí.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/lang/es/).

## [No Publicado]

### 🎉 Agregado
- README.md principal con documentación completa del ecosistema
- CONTRIBUTING.md con guías de contribución
- .gitignore optimizado para Flutter + Web
- CHANGELOG.md para tracking de versiones

### 🔧 Actualizado
- .github/copilot-instructions.md ahora incluye documentación completa de Flutter

---

## [2.0.0] - 2026-02-10

### ✨ Sistema de Pollos - Mejoras Completas

#### Agregado
- 💬 **Integración WhatsApp**: Envío directo de pedidos por WhatsApp
- 🎨 **Tema claro/oscuro**: Toggle persistente en localStorage
- 🔍 **Búsqueda en tiempo real**: Filtro de productos instantáneo
- ✅ **Validaciones en tiempo real**: Teléfono (10 dígitos), nombre (3+ chars)
- 💾 **Persistencia del carrito**: Guarda en localStorage automáticamente
- 🕒 **Historial de pedidos**: Últimos 5 pedidos con opción "Repetir"
- 📤 **Compartir menú**: Web Share API + fallback a clipboard
- 📅 **Selector de fecha/hora**: Planifica entrega futura
- 🔔 **Toast notifications**: Feedback visual en todas las acciones
- 📳 **Vibración**: Feedback táctil en móviles al agregar productos

#### Mejorado
- Formulario con indicadores visuales (error/éxito)
- Botón enviar solo activo con datos completos
- Mejor manejo de errores con mensajes claros
- Scroll automático en acciones importantes
- Calculadora de pollos más intuitiva

#### Cambiado
- Botón principal ahora dice "Enviar por WhatsApp"
- Campos de fecha/hora con valores por defecto inteligentes
- Validación de teléfono acepta solo números

---

## [10.30] - 2026-01-19

### 🚀 App Flutter - Performance y RPCs

#### Agregado
- **Funciones RPC optimizadas**:
  - `get_dashboard_stats()` - KPIs con cache
  - `get_cuotas_vencidas()` - Mora con info de aval
  - `get_resumen_cartera()` - Por estado y sucursal
  - `get_historial_pagos_cliente()` - Historial completo
  - `get_nice_dashboard_vendedora()` - Dashboard MLM
- **Sistema de cache de estadísticas**: TTL de 1 hora
- **Índices de performance**: Compuestos y parciales
- **Vistas materializadas**: Resúmenes mensuales
- **Activity log**: Tracking ligero de acciones
- **Script deploy_supabase.ps1**: CLI para migraciones

#### Mejorado
- Performance de queries hasta 5x más rápido
- Dashboard carga instantáneamente con cache
- Búsquedas con pg_trgm para fuzzy search

---

## [10.20] - 2026-01-10

### 💎 Módulo Nice Joyería MLM

#### Agregado
- Sistema completo de venta por catálogo
- 6 niveles MLM: Inicio → Bronce → Plata → Oro → Platino → Diamante
- Comisiones multinivel (3 niveles de profundidad)
- 8 categorías de productos
- Gestión de catálogos por temporada
- Clientes por vendedora
- Dashboard específico para vendedoras
- Ranking mensual de vendedoras

---

## [10.0] - 2025-12-15

### 🎯 Release Mayor - Arquitectura V2

#### Agregado
- **Chat nativo avanzado**: Mensajes de texto, imagen, documento, audio
- **Sistema de roles**: 4 niveles con 23 permisos granulares
- **Auditoría legal**: Expedientes para juicios
- **Firebase**: Push notifications, Analytics, Crashlytics
- **Deep Links**: QR codes abren la app directamente
- **Autenticación biométrica**: Huella/Face ID

#### Cambiado
- Arquitectura completa a Clean Architecture
- Migración a Supabase 2.0
- Diseño premium 4K con glassmorphism
- Provider para manejo de estado

#### Deprecated
- Sistema de chat legacy (tablas `chats`, `mensajes`)

---

## [1.0.0] - 2025-10-01

### 🚀 Release Inicial

#### Agregado
- **Módulo de préstamos**: Mensuales, quincenales, semanales
- **Sistema de tandas**: Ahorro grupal con turnos
- **Gestión de avales**: Garantías múltiples
- **Dashboard básico**: Métricas principales
- **Autenticación**: Login/Registro con Supabase
- **Roles básicos**: Admin y Operador

---

## Tipos de Cambios

- `Agregado` - Para nuevas características
- `Cambiado` - Para cambios en funcionalidad existente
- `Deprecated` - Para características que pronto se eliminarán
- `Eliminado` - Para características eliminadas
- `Mejorado` - Para mejoras sin cambiar API
- `Corregido` - Para corrección de bugs
- `Seguridad` - Para vulnerabilidades corregidas

---

[No Publicado]: https://github.com/rdarinel92-bit/tarjetas/compare/v10.30...HEAD
[2.0.0]: https://github.com/rdarinel92-bit/tarjetas/compare/v10.30...v2.0.0
[10.30]: https://github.com/rdarinel92-bit/tarjetas/compare/v10.20...v10.30
[10.20]: https://github.com/rdarinel92-bit/tarjetas/compare/v10.0...v10.20
[10.0]: https://github.com/rdarinel92-bit/tarjetas/compare/v1.0.0...v10.0
[1.0.0]: https://github.com/rdarinel92-bit/tarjetas/releases/tag/v1.0.0
