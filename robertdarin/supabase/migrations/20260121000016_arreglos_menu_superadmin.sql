-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Arreglos Menú Superadmin V10.52
-- Fecha: 2026-01-21
-- Descripción: Agregar columna created_at a tabla auditoria para compatibilidad
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Agregar columna created_at a auditoria (usa fecha como source si existe data)
ALTER TABLE auditoria ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ;

-- Actualizar valores existentes desde la columna fecha
UPDATE auditoria SET created_at = fecha WHERE created_at IS NULL AND fecha IS NOT NULL;

-- Default para nuevos registros
UPDATE auditoria SET created_at = NOW() WHERE created_at IS NULL;

-- Hacer not null con default
ALTER TABLE auditoria ALTER COLUMN created_at SET DEFAULT NOW();

-- 2. Verificar que existen las políticas necesarias para Mi Capital
DO $$
BEGIN
    -- Política para activos_capital
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'activos_capital' AND policyname = 'activos_capital_access'
    ) THEN
        CREATE POLICY "activos_capital_access" ON activos_capital
            FOR ALL USING (
                negocio_id IN (SELECT negocio_id FROM empleados WHERE usuario_id = auth.uid())
                OR EXISTS (
                    SELECT 1 FROM usuarios_roles ur
                    JOIN roles r ON ur.rol_id = r.id
                    WHERE ur.usuario_id = auth.uid()
                    AND r.nombre IN ('superadmin', 'admin')
                )
            );
    END IF;

    -- Política para envios_capital
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'envios_capital' AND policyname = 'envios_capital_access'
    ) THEN
        CREATE POLICY "envios_capital_access" ON envios_capital
            FOR ALL USING (
                negocio_id IN (SELECT negocio_id FROM empleados WHERE usuario_id = auth.uid())
                OR EXISTS (
                    SELECT 1 FROM usuarios_roles ur
                    JOIN roles r ON ur.rol_id = r.id
                    WHERE ur.usuario_id = auth.uid()
                    AND r.nombre IN ('superadmin', 'admin')
                )
            );
    END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- Habilitar RLS si no está
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE activos_capital ENABLE ROW LEVEL SECURITY;
ALTER TABLE envios_capital ENABLE ROW LEVEL SECURITY;

-- ═══════════════════════════════════════════════════════════════════════════
-- ✅ Migración completada
-- ═══════════════════════════════════════════════════════════════════════════
