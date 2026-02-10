-- ══════════════════════════════════════════════════════════════════════════════
-- CENTRALIZACIÓN DE DATOS POR SUCURSAL
-- Flujo lógico: Todo registro operativo DEBE pertenecer a una sucursal
-- ══════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 1: Obtener ID de Sucursal Principal para asignar a registros huérfanos
-- ════════════════════════════════════════════════════════════════════════════════

-- Crear función para obtener sucursal principal
CREATE OR REPLACE FUNCTION get_sucursal_principal()
RETURNS UUID AS $$
DECLARE
    sucursal_id UUID;
BEGIN
    SELECT id INTO sucursal_id FROM sucursales 
    WHERE nombre ILIKE '%principal%' OR nombre ILIKE '%matriz%'
    LIMIT 1;
    
    IF sucursal_id IS NULL THEN
        SELECT id INTO sucursal_id FROM sucursales LIMIT 1;
    END IF;
    
    RETURN sucursal_id;
END;
$$ LANGUAGE plpgsql;

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 2: Asignar sucursal principal a registros sin sucursal
-- ════════════════════════════════════════════════════════════════════════════════

-- Actualizar CLIENTES sin sucursal
UPDATE clientes SET sucursal_id = get_sucursal_principal() 
WHERE sucursal_id IS NULL;

-- Actualizar EMPLEADOS sin sucursal
UPDATE empleados SET sucursal_id = get_sucursal_principal() 
WHERE sucursal_id IS NULL;

-- Actualizar PRESTAMOS sin sucursal
UPDATE prestamos SET sucursal_id = get_sucursal_principal() 
WHERE sucursal_id IS NULL;

-- Actualizar TANDAS sin sucursal
UPDATE tandas SET sucursal_id = get_sucursal_principal() 
WHERE sucursal_id IS NULL;

-- Actualizar INVENTARIO sin sucursal
UPDATE inventario SET sucursal_id = get_sucursal_principal() 
WHERE sucursal_id IS NULL;

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 3: Hacer sucursal_id OBLIGATORIO (NOT NULL)
-- ════════════════════════════════════════════════════════════════════════════════

-- CLIENTES: Todo cliente debe pertenecer a una sucursal
ALTER TABLE clientes 
    ALTER COLUMN sucursal_id SET NOT NULL,
    ALTER COLUMN sucursal_id SET DEFAULT get_sucursal_principal();

-- EMPLEADOS: Todo empleado trabaja en una sucursal
ALTER TABLE empleados 
    ALTER COLUMN sucursal_id SET NOT NULL,
    ALTER COLUMN sucursal_id SET DEFAULT get_sucursal_principal();

-- PRESTAMOS: Todo préstamo se otorga desde una sucursal
ALTER TABLE prestamos 
    ALTER COLUMN sucursal_id SET NOT NULL,
    ALTER COLUMN sucursal_id SET DEFAULT get_sucursal_principal();

-- TANDAS: Toda tanda se administra desde una sucursal
ALTER TABLE tandas 
    ALTER COLUMN sucursal_id SET NOT NULL,
    ALTER COLUMN sucursal_id SET DEFAULT get_sucursal_principal();

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 4: Crear ÍNDICES para mejorar consultas por sucursal
-- ════════════════════════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_clientes_sucursal ON clientes(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_empleados_sucursal ON empleados(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_prestamos_sucursal ON prestamos(sucursal_id);
CREATE INDEX IF NOT EXISTS idx_tandas_sucursal ON tandas(sucursal_id);

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 5: Crear TRIGGERS para asignar sucursal automáticamente
-- ════════════════════════════════════════════════════════════════════════════════

-- Trigger para clientes: si no se especifica sucursal, usar la principal
CREATE OR REPLACE FUNCTION set_default_sucursal()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.sucursal_id IS NULL THEN
        NEW.sucursal_id := get_sucursal_principal();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_clientes_default_sucursal ON clientes;
CREATE TRIGGER trg_clientes_default_sucursal
    BEFORE INSERT ON clientes
    FOR EACH ROW EXECUTE FUNCTION set_default_sucursal();

DROP TRIGGER IF EXISTS trg_empleados_default_sucursal ON empleados;
CREATE TRIGGER trg_empleados_default_sucursal
    BEFORE INSERT ON empleados
    FOR EACH ROW EXECUTE FUNCTION set_default_sucursal();

DROP TRIGGER IF EXISTS trg_prestamos_default_sucursal ON prestamos;
CREATE TRIGGER trg_prestamos_default_sucursal
    BEFORE INSERT ON prestamos
    FOR EACH ROW EXECUTE FUNCTION set_default_sucursal();

DROP TRIGGER IF EXISTS trg_tandas_default_sucursal ON tandas;
CREATE TRIGGER trg_tandas_default_sucursal
    BEFORE INSERT ON tandas
    FOR EACH ROW EXECUTE FUNCTION set_default_sucursal();

-- ════════════════════════════════════════════════════════════════════════════════
-- PASO 6: Crear VISTA consolidada para ver todo por sucursal
-- ════════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW vista_resumen_sucursal AS
SELECT 
    s.id AS sucursal_id,
    s.nombre AS sucursal_nombre,
    (SELECT COUNT(*) FROM clientes c WHERE c.sucursal_id = s.id) AS total_clientes,
    (SELECT COUNT(*) FROM empleados e WHERE e.sucursal_id = s.id) AS total_empleados,
    (SELECT COUNT(*) FROM prestamos p WHERE p.sucursal_id = s.id) AS total_prestamos,
    (SELECT COUNT(*) FROM prestamos p WHERE p.sucursal_id = s.id AND p.estado = 'activo') AS prestamos_activos,
    (SELECT COALESCE(SUM(p.monto), 0) FROM prestamos p WHERE p.sucursal_id = s.id AND p.estado = 'activo') AS capital_activo,
    (SELECT COUNT(*) FROM tandas t WHERE t.sucursal_id = s.id) AS total_tandas,
    (SELECT COUNT(*) FROM tandas t WHERE t.sucursal_id = s.id AND t.estado = 'activa') AS tandas_activas
FROM sucursales s
ORDER BY s.nombre;

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN FINAL
-- ════════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
    clientes_sin_suc INT;
    empleados_sin_suc INT;
    prestamos_sin_suc INT;
    tandas_sin_suc INT;
BEGIN
    SELECT COUNT(*) INTO clientes_sin_suc FROM clientes WHERE sucursal_id IS NULL;
    SELECT COUNT(*) INTO empleados_sin_suc FROM empleados WHERE sucursal_id IS NULL;
    SELECT COUNT(*) INTO prestamos_sin_suc FROM prestamos WHERE sucursal_id IS NULL;
    SELECT COUNT(*) INTO tandas_sin_suc FROM tandas WHERE sucursal_id IS NULL;
    
    RAISE NOTICE '══════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ CENTRALIZACIÓN POR SUCURSAL COMPLETADA';
    RAISE NOTICE '══════════════════════════════════════════════════════════════════';
    RAISE NOTICE '';
    RAISE NOTICE '📊 VERIFICACIÓN DE INTEGRIDAD:';
    RAISE NOTICE '   • Clientes sin sucursal: %', clientes_sin_suc;
    RAISE NOTICE '   • Empleados sin sucursal: %', empleados_sin_suc;
    RAISE NOTICE '   • Préstamos sin sucursal: %', prestamos_sin_suc;
    RAISE NOTICE '   • Tandas sin sucursal: %', tandas_sin_suc;
    RAISE NOTICE '';
    RAISE NOTICE '🔧 CAMBIOS APLICADOS:';
    RAISE NOTICE '   1. sucursal_id ahora es OBLIGATORIO en tablas críticas';
    RAISE NOTICE '   2. Triggers asignan sucursal principal automáticamente';
    RAISE NOTICE '   3. Índices creados para consultas rápidas por sucursal';
    RAISE NOTICE '   4. Vista vista_resumen_sucursal disponible';
    RAISE NOTICE '══════════════════════════════════════════════════════════════════';
END $$;
