-- ══════════════════════════════════════════════════════════════════════════════
-- FIX: Políticas RLS para permitir lectura de catálogos
-- Las tablas de catálogo (sucursales, roles, permisos) deben ser legibles
-- tanto por usuarios anónimos como autenticados
-- ══════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════════
-- SUCURSALES - Permitir lectura pública
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "sucursales_all_simple" ON sucursales;
DROP POLICY IF EXISTS "sucursales_read_authenticated" ON sucursales;
DROP POLICY IF EXISTS "sucursales_select_public" ON sucursales;

-- Lectura pública (anon + authenticated)
CREATE POLICY "sucursales_select_public" ON sucursales
    FOR SELECT USING (true);

-- Modificación solo para autenticados
CREATE POLICY "sucursales_modify_authenticated" ON sucursales
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- ROLES - Permitir lectura pública
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "roles_select_all" ON roles;
DROP POLICY IF EXISTS "roles_modify_authenticated" ON roles;
DROP POLICY IF EXISTS "roles_select_public" ON roles;

-- Lectura pública
CREATE POLICY "roles_select_public" ON roles
    FOR SELECT USING (true);

-- Modificación solo para autenticados
CREATE POLICY "roles_modify_authenticated" ON roles
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- PERMISOS - Permitir lectura pública
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "permisos_select_all" ON permisos;
DROP POLICY IF EXISTS "permisos_select_public" ON permisos;

-- Lectura pública
CREATE POLICY "permisos_select_public" ON permisos
    FOR SELECT USING (true);

-- ════════════════════════════════════════════════════════════════════════════════
-- ROLES_PERMISOS - Permitir lectura pública
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "roles_permisos_select_all" ON roles_permisos;
DROP POLICY IF EXISTS "roles_permisos_modify_all" ON roles_permisos;
DROP POLICY IF EXISTS "roles_permisos_select_public" ON roles_permisos;

-- Lectura pública
CREATE POLICY "roles_permisos_select_public" ON roles_permisos
    FOR SELECT USING (true);

-- Modificación solo para autenticados
CREATE POLICY "roles_permisos_modify_authenticated" ON roles_permisos
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ════════════════════════════════════════════════════════════════════════════════
DO $$
DECLARE
    suc_count INT;
    rol_count INT;
    perm_count INT;
BEGIN
    SELECT COUNT(*) INTO suc_count FROM sucursales;
    SELECT COUNT(*) INTO rol_count FROM roles;
    SELECT COUNT(*) INTO perm_count FROM permisos;
    
    RAISE NOTICE '══════════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ POLÍTICAS DE LECTURA PÚBLICA APLICADAS';
    RAISE NOTICE '══════════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Datos disponibles:';
    RAISE NOTICE '  • Sucursales: %', suc_count;
    RAISE NOTICE '  • Roles: %', rol_count;
    RAISE NOTICE '  • Permisos: %', perm_count;
    RAISE NOTICE '══════════════════════════════════════════════════════════════════';
END $$;
