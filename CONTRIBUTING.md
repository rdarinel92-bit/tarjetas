# 🤝 Guía de Contribución

Gracias por tu interés en contribuir al proyecto Robert Darin Fintech.

## 📋 Tabla de Contenidos

- [Código de Conducta](#código-de-conducta)
- [Cómo Contribuir](#cómo-contribuir)
- [Convenciones de Código](#convenciones-de-código)
- [Flujo de Trabajo Git](#flujo-de-trabajo-git)
- [Reportar Bugs](#reportar-bugs)
- [Sugerir Mejoras](#sugerir-mejoras)

## 📜 Código de Conducta

Este proyecto se adhiere a un código de conducta profesional. Se espera que todos los participantes:

- Sean respetuosos y considerados
- Proporcionen feedback constructivo
- Acepten críticas de manera profesional
- Se enfoquen en lo que es mejor para el proyecto

## 🚀 Cómo Contribuir

### 1. Fork y Clone

```bash
# Fork el repositorio en GitHub
# Luego clona tu fork
git clone https://github.com/TU_USUARIO/tarjetas.git
cd tarjetas

# Agrega el upstream
git remote add upstream https://github.com/rdarinel92-bit/tarjetas.git
```

### 2. Crear Rama de Feature

```bash
# Sincroniza con main
git checkout main
git pull upstream main

# Crea tu rama
git checkout -b feature/mi-nueva-funcionalidad
# o
git checkout -b fix/arreglar-bug
```

### 3. Hacer Cambios

- Escribe código limpio y bien documentado
- Sigue las convenciones del proyecto
- Agrega tests si es necesario
- Actualiza documentación relevante

### 4. Commit

Usa convención de commits:

```bash
git commit -m "feat: agregar sistema de reportes"
git commit -m "fix: corregir cálculo de intereses"
git commit -m "docs: actualizar README con nuevas features"
```

**Tipos de commit:**
- `feat:` Nueva característica
- `fix:` Corrección de bug
- `docs:` Cambios en documentación
- `style:` Formato, espacios, punto y coma (no afecta código)
- `refactor:` Refactorización sin cambiar funcionalidad
- `perf:` Mejora de performance
- `test:` Agregar o corregir tests
- `chore:` Cambios en build, herramientas, etc.

### 5. Push y Pull Request

```bash
# Push a tu fork
git push origin feature/mi-nueva-funcionalidad

# Crea Pull Request en GitHub
# Describe claramente qué cambia y por qué
```

## 🎨 Convenciones de Código

### Flutter (Dart)

**Naming:**
```dart
// Classes: PascalCase
class PrestamoCard extends StatelessWidget {}

// Variables y funciones: camelCase
void calcularInteres() {}
final String nombreCliente;

// Constantes: lowerCamelCase o SCREAMING_SNAKE_CASE
const int maxPrestamos = 100;
const String API_KEY = "...";

// Archivos: snake_case
prestamo_card_widget.dart
auth_viewmodel.dart
```

**Estructura:**
```dart
// 1. Imports
import 'package:flutter/material.dart';

// 2. Clase
class MiWidget extends StatelessWidget {
  // 3. Propiedades
  final String title;
  
  // 4. Constructor
  const MiWidget({Key? key, required this.title}) : super(key: key);
  
  // 5. Métodos públicos
  @override
  Widget build(BuildContext context) {
    return Container();
  }
  
  // 6. Métodos privados
  void _metodoPrivado() {}
}
```

### Web (HTML/CSS/JS)

**JavaScript:**
```javascript
// Variables: camelCase
const userName = 'John';
let isActive = true;

// Funciones: camelCase
function calculateTotal() {}
const formatPhone = (phone) => {};

// Constantes: SCREAMING_SNAKE_CASE o camelCase
const CONFIG = { url: '...' };
const maxRetries = 3;

// Comentarios estructurados
// ═══════════════════════════════════════════════════════════════════
// SECCIÓN PRINCIPAL
// ═══════════════════════════════════════════════════════════════════
```

**HTML/CSS:**
```html
<!-- IDs semánticos -->
<div id="businessName"></div>
<button id="submitBtn"></button>

<!-- Classes con BEM parcial -->
<div class="form-group">
  <input class="form-input" />
</div>
```

**CSS Variables:**
```css
:root {
  --primary: #D4AF37;
  --bg-dark: #0D0D14;
  --text-white: #FFFFFF;
}
```

### SQL

```sql
-- Nombres en snake_case
CREATE TABLE prestamos_diarios (
  id UUID PRIMARY KEY,
  cliente_id UUID REFERENCES clientes(id),
  monto_total DECIMAL(10, 2),
  created_at TIMESTAMP DEFAULT NOW()
);

-- Funciones RPC descriptivas
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_negocio_id UUID)
RETURNS JSON AS $$
BEGIN
  -- implementación
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 🔀 Flujo de Trabajo Git

### Branches

```
main                  # Producción estable
├── develop           # Desarrollo activo
│   ├── feature/*     # Nuevas características
│   ├── fix/*         # Correcciones
│   └── refactor/*    # Refactorizaciones
└── hotfix/*          # Arreglos urgentes de producción
```

### Workflow típico

```bash
# 1. Actualizar main
git checkout main
git pull upstream main

# 2. Crear feature
git checkout -b feature/nueva-funcionalidad

# 3. Trabajo + commits
git add .
git commit -m "feat: implementar X"

# 4. Actualizar con main (rebase)
git fetch upstream
git rebase upstream/main

# 5. Push
git push origin feature/nueva-funcionalidad

# 6. Pull Request en GitHub
```

## 🐛 Reportar Bugs

Al reportar un bug, incluye:

**Información del sistema:**
- Versión de la app (ej: v10.30)
- Dispositivo (ej: Samsung Galaxy S21, Android 13)
- Navegador (para web): Chrome 120, Safari 17

**Descripción del bug:**
- ¿Qué esperabas que pasara?
- ¿Qué pasó realmente?
- Pasos para reproducir
- Screenshots/videos si es posible

**Ejemplo:**
```markdown
## Bug: Error al registrar pago

**Esperado:** El pago se registra y actualiza saldo
**Actual:** Se muestra error "No se pudo procesar"

**Pasos:**
1. Ir a Préstamos → Detalle
2. Click en "Registrar Pago"
3. Ingresar monto y fecha
4. Click "Guardar"

**Dispositivo:** Samsung A54, Android 14
**Versión:** 10.30

**Screenshot:** [adjuntar]
```

## 💡 Sugerir Mejoras

Para nuevas features o mejoras:

1. **Primero busca** si ya existe un issue similar
2. **Describe claramente** qué problema resuelve
3. **Propón solución** si tienes una idea
4. **Justifica** por qué es útil para el proyecto

**Template:**
```markdown
## Feature: Sistema de recordatorios automáticos

**Problema:**
Los clientes olvidan fechas de pago y generan mora.

**Solución propuesta:**
Enviar SMS/Push 3 días antes del vencimiento.

**Beneficios:**
- Reduce mora en ~30%
- Mejora experiencia de usuario
- Aumenta recuperación

**Alternativas consideradas:**
- Email (baja tasa de apertura)
- WhatsApp (requiere integración externa)

**Estimación de esfuerzo:** ~3 días
```

## ✅ Checklist antes de PR

- [ ] El código compila sin errores
- [ ] Sigue las convenciones del proyecto
- [ ] Tests pasan (si aplica)
- [ ] Documentación actualizada
- [ ] Commits con mensajes descriptivos
- [ ] Branch actualizada con main
- [ ] Probado en dispositivo/navegador

## 🔍 Review de Código

Cuando hagas review de un PR:

**✅ Buenas prácticas:**
- Sé constructivo y amable
- Explica el "por qué", no solo el "qué"
- Sugiere alternativas si es posible
- Reconoce lo bueno también

**❌ Evitar:**
- Críticas personales
- Comentarios vagos
- Pedir cambios sin justificación
- Aprobar sin revisar

## 📞 Contacto

Para dudas sobre contribuciones:
- Abre un issue con la etiqueta `question`
- Revisa la [documentación](.github/copilot-instructions.md)

---

¡Gracias por contribuir! 🎉
