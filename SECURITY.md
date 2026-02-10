# 🔒 Política de Seguridad

## Versiones Soportadas

| Versión | Soportada          |
| ------- | ------------------ |
| 10.30   | :white_check_mark: |
| 10.20   | :white_check_mark: |
| < 10.0  | :x:                |

## 🛡️ Medidas de Seguridad Implementadas

### App Flutter

- ✅ **Autenticación segura** con Supabase Auth
- ✅ **Almacenamiento encriptado** con `flutter_secure_storage`
- ✅ **Autenticación biométrica** (huella/Face ID)
- ✅ **Hash de contenido** (SHA-256) en mensajes críticos
- ✅ **Auditoría completa** de acciones con IP y geolocalización
- ✅ **Certificado SSL pinning** (producción)
- ✅ **Obfuscación de código** en releases

### Backend (Supabase)

- ✅ **Row Level Security (RLS)** en todas las tablas
- ✅ **Políticas granulares** por rol de usuario
- ✅ **Anon Key pública** segura (solo lectura con RLS)
- ✅ **Conexión HTTPS** obligatoria
- ✅ **Rate limiting** en Edge Functions
- ✅ **Validación de entrada** en triggers de BD

### Web Apps

- ✅ **Content Security Policy** (CSP)
- ✅ **HTTPs obligatorio** en producción
- ✅ **Sanitización de inputs** cliente y servidor
- ✅ **Protección XSS** con validación estricta
- ✅ **Sin eval()** ni innerHTML inseguro
- ✅ **Anon Key ofuscada** (pero no secreta)

## 🚨 Reportar una Vulnerabilidad

Si descubres una vulnerabilidad de seguridad, **NO abras un issue público**.

### Proceso de Reporte

1. **Contacta directamente** al equipo de desarrollo:
   - Email: security@robertdarin.com (preferido)
   - O crea un **Security Advisory** privado en GitHub

2. **Incluye en tu reporte:**
   - Descripción detallada de la vulnerabilidad
   - Pasos para reproducir el problema
   - Impacto potencial (severidad)
   - Sugerencias de solución (opcional)
   - Tu información de contacto
   - CVE asociado (si existe)

3. **Qué esperar:**
   - Confirmación de recepción: **24 horas**
   - Evaluación inicial: **72 horas**
   - Actualizaciones regulares sobre el progreso
   - Resolución según severidad:
     - Crítica: 7 días
     - Alta: 14 días
     - Media: 30 días
     - Baja: 90 días

4. **Proceso de divulgación:**
   - Trabajaremos contigo en la solución
   - Te acreditaremos públicamente (si lo deseas)
   - Publicaremos fix antes de divulgar detalles
   - Coordinaremos timing de divulgación pública

## 🎯 Scope de Seguridad

### ✅ En Scope

- App móvil Flutter (Android/iOS)
- Aplicaciones web (index.html, pollos/)
- APIs y Edge Functions de Supabase
- Autenticación y autorización
- Manejo de datos sensibles
- Dependencias con vulnerabilidades conocidas

### ❌ Fuera de Scope

- Ataques de ingeniería social
- Denial of Service (DoS/DDoS)
- Vulnerabilidades en infraestructura de hosting
- Bugs que requieren acceso físico al dispositivo
- Problemas en versiones no soportadas (< 10.0)

## 🔐 Mejores Prácticas para Contribuidores

### Código Seguro

```dart
// ✅ Bueno: Validación de entrada
if (monto > 0 && monto <= MAX_AMOUNT) {
  // procesar
}

// ❌ Malo: Sin validación
processAmount(monto);
```

```dart
// ✅ Bueno: Consultas parametrizadas
await supabase.from('prestamos')
  .select()
  .eq('id', prestamoId);

// ❌ Malo: Concatenación de strings (SQL injection)
await supabase.rpc('query', {'sql': 'SELECT * WHERE id=$prestamoId'});
```

```javascript
// ✅ Bueno: Sanitizar antes de mostrar
element.textContent = userInput;

// ❌ Malo: XSS vulnerable
element.innerHTML = userInput;
```

### Datos Sensibles

- ❌ **NUNCA** commitear:
  - Claves API privadas
  - Contraseñas o tokens
  - Certificados o keystores
  - `google-services.json` o similar
  - Variables de entorno con secrets

- ✅ **SÍ** usar:
  - Variables de entorno
  - `flutter_secure_storage` para secrets
  - `.gitignore` apropiado
  - Secrets de GitHub para CI/CD

### Dependencias

```bash
# Verificar vulnerabilidades conocidas
flutter pub outdated
dart pub audit

# Actualizar dependencias seguras
flutter pub upgrade --major-versions
```

### Configuración de Producción

```yaml
# pubspec.yaml - NO incluir en debug
flutter:
  obfuscate: true
  split-debug-info: /debug-symbols/
```

## 📋 Checklist de Seguridad para PRs

Antes de hacer push de código sensible:

- [ ] No hay credenciales hardcodeadas
- [ ] Inputs validados y sanitizados
- [ ] Queries usan prepared statements
- [ ] Errores no revelan información sensible
- [ ] Archivos de configuración en .gitignore
- [ ] Dependencias actualizadas sin CVEs conocidos
- [ ] Logs no contienen información sensible
- [ ] Permisos verificados (RLS, roles)

## 🏆 Programa de Recompensas

Actualmente **no** tenemos un programa de bug bounty monetario, pero:

- ✅ Reconocimiento público en CHANGELOG
- ✅ Badge de "Security Contributor"
- ✅ Mención en release notes
- ✅ Nuestro agradecimiento eterno 🙏

## 📚 Recursos de Seguridad

### Flutter Security
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)

### Web Security
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/)

### Supabase Security
- [RLS Documentation](https://supabase.com/docs/guides/auth/row-level-security)
- [Security Best Practices](https://supabase.com/docs/guides/platform/going-into-prod)

## 🔄 Historial de Seguridad

### 2026-02-10
- ✅ Implementación completa de RLS en todas las tablas
- ✅ Auditoría de código frontend/backend
- ✅ Documento SECURITY.md creado

### 2025-12-15 (v10.0)
- ✅ Migración a autenticación biométrica
- ✅ Sistema de auditoría legal implementado
- ✅ Hash de contenido en mensajes críticos

---

**Última actualización:** Febrero 2026  
**Contacto de seguridad:** security@robertdarin.com

Gracias por ayudar a mantener Robert Darin Fintech seguro 🔒
