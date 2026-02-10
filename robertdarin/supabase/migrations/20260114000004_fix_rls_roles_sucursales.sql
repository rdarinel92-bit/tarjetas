-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Corregir Políticas RLS para Roles y Sucursales
-- Fecha: 2026-01-14
-- Descripción: Asegura que los usuarios autenticados puedan leer roles y sucursales
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. HABILITAR RLS EN TABLAS SI NO ESTÁ HABILITADO
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permisos ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles_permisos ENABLE ROW LEVEL SECURITY;

-- 2. ELIMINAR POLÍTICAS EXISTENTES SI HAY CONFLICTO (DROP IF EXISTS no existe, usamos nombre único)
DROP POLICY IF EXISTS "roles_select_all" ON roles;
DROP POLICY IF EXISTS "roles_public_read" ON roles;
DROP POLICY IF EXISTS "permisos_select_all" ON permisos;
DROP POLICY IF EXISTS "permisos_public_read" ON permisos;
DROP POLICY IF EXISTS "roles_permisos_read" ON roles_permisos;
DROP POLICY IF EXISTS "sucursales_select" ON sucursales;
DROP POLICY IF EXISTS "sucursales_authenticated" ON sucursales;

-- 3. CREAR POLÍTICAS CORRECTAS PARA LECTURA PÚBLICA DE ROLES

-- ROLES: Cualquier usuario autenticado puede leer
CREATE POLICY "roles_public_read" ON roles
    FOR SELECT 
    USING (true);

-- PERMISOS: Cualquier usuario autenticado puede leer
CREATE POLICY "permisos_public_read" ON permisos
    FOR SELECT 
    USING (true);

-- ROLES_PERMISOS: Cualquier usuario autenticado puede leer
CREATE POLICY "roles_permisos_read" ON roles_permisos
    FOR SELECT 
    USING (true);

-- SUCURSALES: Usuarios autenticados pueden leer
CREATE POLICY "sucursales_select" ON sucursales
    FOR SELECT 
    USING (auth.role() = 'authenticated');

-- SUCURSALES: Modificación solo para admins/superadmins
CREATE POLICY "sucursales_modify_admin" ON sucursales
    FOR ALL 
    USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur 
            JOIN roles r ON ur.rol_id = r.id 
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre IN ('superadmin', 'admin')
        )
    );

-- 4. VERIFICAR DATOS EXISTEN
DO $$
DECLARE
    v_roles_count INT;
    v_sucursales_count INT;
BEGIN
    SELECT COUNT(*) INTO v_roles_count FROM roles;
    SELECT COUNT(*) INTO v_sucursales_count FROM sucursales;
    
    RAISE NOTICE '📊 Roles disponibles: %', v_roles_count;
    RAISE NOTICE '📊 Sucursales disponibles: %', v_sucursales_count;
    
    IF v_roles_count = 0 THEN
        RAISE WARNING '⚠️ No hay roles en la BD';
    END IF;
    
    IF v_sucursales_count = 0 THEN
        RAISE WARNING '⚠️ No hay sucursales en la BD';
    END IF;
    
    RAISE NOTICE '✅ Políticas RLS configuradas correctamente';
END $$;
