# 🔒 GUÍA DE PRODUCCIÓN - Robert Darin Fintech

> **DOCUMENTO CRÍTICO**: Seguir estas instrucciones ANTES de cualquier cambio en producción.

---

## 📋 CHECKLIST ANTES DE AGREGAR DATOS REALES

```
□ 1. Verificar plan de Supabase (Pro recomendado para backups)
□ 2. Hacer backup manual inicial
□ 3. Documentar fecha de inicio de producción
□ 4. Configurar alertas de monitoreo
□ 5. Tener copia del SQL actual (database_schema.sql)
```

---

## 🗄️ BACKUPS MANUALES EN SUPABASE

### Opción 1: Desde el Dashboard de Supabase

1. Ir a **Project Settings** → **Database**
2. Click en **Database Backups**
3. Click en **Create Backup** (si está disponible en tu plan)

### Opción 2: Usando pg_dump (Recomendado)

```bash
# Desde tu computadora con PostgreSQL instalado:
pg_dump "postgresql://postgres:[TU_PASSWORD]@db.[TU_PROJECT_REF].supabase.co:5432/postgres" > backup_$(date +%Y%m%d).sql
```

### Opción 3: Script SQL para Backup de Datos Críticos

Ejecutar en Supabase SQL Editor ANTES de cualquier cambio:

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- BACKUP DE DATOS CRÍTICOS - Ejecutar antes de cambios
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. Crear schema de backup si no existe
CREATE SCHEMA IF NOT EXISTS backup;

-- 2. Backup de clientes
DROP TABLE IF EXISTS backup.clientes_backup;
CREATE TABLE backup.clientes_backup AS SELECT *, NOW() as backup_date FROM clientes;

-- 3. Backup de préstamos
DROP TABLE IF EXISTS backup.prestamos_backup;
CREATE TABLE backup.prestamos_backup AS SELECT *, NOW() as backup_date FROM prestamos;

-- 4. Backup de amortizaciones
DROP TABLE IF EXISTS backup.amortizaciones_backup;
CREATE TABLE backup.amortizaciones_backup AS SELECT *, NOW() as backup_date FROM amortizaciones;

-- 5. Backup de pagos
DROP TABLE IF EXISTS backup.pagos_backup;
CREATE TABLE backup.pagos_backup AS SELECT *, NOW() as backup_date FROM pagos;

-- 6. Backup de tandas
DROP TABLE IF EXISTS backup.tandas_backup;
CREATE TABLE backup.tandas_backup AS SELECT *, NOW() as backup_date FROM tandas;

-- 7. Backup de tanda_participantes
DROP TABLE IF EXISTS backup.tanda_participantes_backup;
CREATE TABLE backup.tanda_participantes_backup AS SELECT *, NOW() as backup_date FROM tanda_participantes;

-- 8. Backup de avales
DROP TABLE IF EXISTS backup.avales_backup;
CREATE TABLE backup.avales_backup AS SELECT *, NOW() as backup_date FROM avales;

-- 9. Backup de usuarios
DROP TABLE IF EXISTS backup.usuarios_backup;
CREATE TABLE backup.usuarios_backup AS SELECT *, NOW() as backup_date FROM usuarios;

-- Verificar backups creados
SELECT 
    schemaname || '.' || tablename as tabla,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename)) as tamaño
FROM pg_tables 
WHERE schemaname = 'backup'
ORDER BY tablename;
```

---

## 🔄 RESTAURAR DATOS DESDE BACKUP

Si algo sale mal, ejecutar:

```sql
-- ═══════════════════════════════════════════════════════════════════════════════
-- RESTAURAR DATOS DESDE BACKUP
-- ⚠️ SOLO USAR EN EMERGENCIAS
-- ═══════════════════════════════════════════════════════════════════════════════

-- Ejemplo: Restaurar clientes
-- TRUNCATE clientes; -- Cuidado!
-- INSERT INTO clientes SELECT * FROM backup.clientes_backup;

-- Mejor opción: Restaurar registros específicos
-- INSERT INTO clientes 
-- SELECT * FROM backup.clientes_backup 
-- WHERE id NOT IN (SELECT id FROM clientes);
```

---

## ✅ REGLAS PARA CAMBIOS SEGUROS EN SQL

### PERMITIDO (Seguro para producción):

```sql
-- 1. Agregar nuevas tablas
CREATE TABLE IF NOT EXISTS nueva_tabla (...);

-- 2. Agregar nuevas columnas
ALTER TABLE existente ADD COLUMN IF NOT EXISTS nueva_columna TYPE;

-- 3. Agregar índices
CREATE INDEX IF NOT EXISTS idx_nuevo ON tabla(columna);

-- 4. Agregar funciones (CREATE OR REPLACE es seguro)
CREATE OR REPLACE FUNCTION mi_funcion() ...;

-- 5. Inserts con ON CONFLICT
INSERT INTO tabla (...) VALUES (...) ON CONFLICT DO NOTHING;

-- 6. Agregar políticas RLS nuevas
CREATE POLICY IF NOT EXISTS "nueva_policy" ON tabla ...;
```

### ⚠️ PRECAUCIÓN (Revisar antes):

```sql
-- 1. Modificar tipo de columna (puede fallar si hay datos incompatibles)
ALTER TABLE tabla ALTER COLUMN columna TYPE nuevo_tipo;

-- 2. Agregar NOT NULL a columna existente
ALTER TABLE tabla ALTER COLUMN columna SET NOT NULL;
-- Primero verificar: SELECT * FROM tabla WHERE columna IS NULL;

-- 3. Updates masivos (siempre con WHERE específico)
UPDATE tabla SET columna = valor WHERE condicion_especifica;
```

### ❌ PROHIBIDO (Nunca en producción):

```sql
-- 1. DROP TABLE (destruye datos)
DROP TABLE tabla; -- ❌ NUNCA

-- 2. TRUNCATE (borra todos los datos)
TRUNCATE tabla; -- ❌ NUNCA

-- 3. DELETE sin WHERE
DELETE FROM tabla; -- ❌ NUNCA

-- 4. DROP COLUMN con datos importantes
ALTER TABLE tabla DROP COLUMN columna; -- ❌ Verificar primero
```

---

## 📊 VERIFICAR INTEGRIDAD ANTES DE CAMBIOS

Ejecutar ANTES de aplicar cambios:

```sql
-- Ver cantidad de registros por tabla principal
SELECT 
    'clientes' as tabla, COUNT(*) as registros FROM clientes
UNION ALL SELECT 'prestamos', COUNT(*) FROM prestamos
UNION ALL SELECT 'amortizaciones', COUNT(*) FROM amortizaciones
UNION ALL SELECT 'pagos', COUNT(*) FROM pagos
UNION ALL SELECT 'tandas', COUNT(*) FROM tandas
UNION ALL SELECT 'avales', COUNT(*) FROM avales
UNION ALL SELECT 'usuarios', COUNT(*) FROM usuarios
ORDER BY registros DESC;
```

Ejecutar DESPUÉS de aplicar cambios y comparar números.

---

## 🚀 PROCESO PARA APLICAR CAMBIOS EN PRODUCCIÓN

### Paso 1: Backup
```sql
-- Ejecutar script de backup completo (arriba)
```

### Paso 2: Probar en Ambiente de Prueba
- Crear proyecto de prueba en Supabase (gratis)
- Aplicar cambios ahí primero
- Verificar que funciona

### Paso 3: Aplicar en Producción
- Hacer backup
- Aplicar cambios en horario de bajo uso
- Verificar inmediatamente

### Paso 4: Verificar
```sql
-- Contar registros después del cambio
-- Verificar que la app funciona
-- Revisar logs de errores
```

---

## 🔐 RECOMENDACIONES ADICIONALES

### 1. Usar Plan Pro de Supabase ($25/mes)
- Backups automáticos diarios
- Más conexiones
- Soporte prioritario

### 2. Exportar Datos Semanalmente
Descargar CSV de tablas críticas cada semana.

### 3. Versionado del SQL
Cada vez que hagas cambios:
1. Copiar `database_schema.sql` actual
2. Renombrar como `database_schema_v10.9_backup.sql`
3. Hacer cambios en el original
4. Documentar cambios

### 4. Ambiente de Staging
Considera tener 2 proyectos en Supabase:
- **robertdarin-prod**: Datos reales
- **robertdarin-dev**: Para pruebas

---

## 📞 EN CASO DE EMERGENCIA

1. **NO ENTRAR EN PÁNICO**
2. No hacer más cambios
3. Verificar backups disponibles
4. Restaurar desde backup si es necesario
5. Documentar qué pasó

---

## 📅 CALENDARIO DE MANTENIMIENTO SUGERIDO

| Frecuencia | Tarea |
|------------|-------|
| Diario | Verificar que la app funciona |
| Semanal | Exportar CSV de datos críticos |
| Mensual | Backup completo manual |
| Antes de cambios | Backup + verificar integridad |

---

**FECHA DE INICIO PRODUCCIÓN**: _______________

**RESPONSABLE**: _______________

**VERSIÓN SQL INICIAL**: V10.9

