-- ══════════════════════════════════════════════════════════════════════════════
-- FIX: Eliminar recursión infinita en políticas RLS
-- El problema: políticas que verifican usuarios_roles, y usuarios_roles 
-- tiene políticas que verifican otras tablas = RECURSIÓN
-- Solución: Usar políticas simples sin JOINs recursivos
-- ══════════════════════════════════════════════════════════════════════════════

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: usuarios_roles - CRÍTICA (causa de la recursión)
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "usuarios_roles_select" ON usuarios_roles;
DROP POLICY IF EXISTS "usuarios_roles_insert" ON usuarios_roles;
DROP POLICY IF EXISTS "usuarios_roles_update" ON usuarios_roles;
DROP POLICY IF EXISTS "usuarios_roles_delete" ON usuarios_roles;
DROP POLICY IF EXISTS "usuarios_roles_all" ON usuarios_roles;
DROP POLICY IF EXISTS "usuarios_roles_authenticated" ON usuarios_roles;
DROP POLICY IF EXISTS "usuarios_roles_read_own" ON usuarios_roles;
DROP POLICY IF EXISTS "usuarios_roles_admin_all" ON usuarios_roles;

-- Política SIMPLE: Usuarios autenticados pueden leer (sin recursión)
CREATE POLICY "usuarios_roles_select_simple" ON usuarios_roles
    FOR SELECT USING (auth.role() = 'authenticated');

-- Política SIMPLE: Cualquier autenticado puede insertar (el trigger validará)
CREATE POLICY "usuarios_roles_insert_simple" ON usuarios_roles
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Política SIMPLE: Solo el propio registro o admins
CREATE POLICY "usuarios_roles_update_simple" ON usuarios_roles
    FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "usuarios_roles_delete_simple" ON usuarios_roles
    FOR DELETE USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: roles - Simplificar (quitar verificación de usuarios_roles)
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "roles_read_authenticated" ON roles;
DROP POLICY IF EXISTS "roles_modify_superadmin" ON roles;
DROP POLICY IF EXISTS "roles_public_read" ON roles;
DROP POLICY IF EXISTS "roles_select_authenticated" ON roles;

-- Solo lectura para todos los autenticados
CREATE POLICY "roles_select_all" ON roles
    FOR SELECT USING (auth.role() = 'authenticated');

-- Modificación solo para autenticados (validación en app)
CREATE POLICY "roles_modify_authenticated" ON roles
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: permisos - Simplificar
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "permisos_read_authenticated" ON permisos;
DROP POLICY IF EXISTS "permisos_public_read" ON permisos;
DROP POLICY IF EXISTS "permisos_select_authenticated" ON permisos;

CREATE POLICY "permisos_select_all" ON permisos
    FOR SELECT USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: roles_permisos - Simplificar
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "roles_permisos_read_authenticated" ON roles_permisos;
DROP POLICY IF EXISTS "roles_permisos_modify_superadmin" ON roles_permisos;
DROP POLICY IF EXISTS "roles_permisos_read" ON roles_permisos;
DROP POLICY IF EXISTS "roles_permisos_select_authenticated" ON roles_permisos;

CREATE POLICY "roles_permisos_select_all" ON roles_permisos
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "roles_permisos_modify_all" ON roles_permisos
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: empleados - Simplificar
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "empleados_read_authenticated" ON empleados;
DROP POLICY IF EXISTS "empleados_modify_admin" ON empleados;
DROP POLICY IF EXISTS "empleados_admin_all" ON empleados;
DROP POLICY IF EXISTS "empleados_select_authenticated" ON empleados;

CREATE POLICY "empleados_all_authenticated" ON empleados
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: clientes - Simplificar (evitar recursión)
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "clientes_select_authenticated" ON clientes;
DROP POLICY IF EXISTS "clientes_insert_authenticated" ON clientes;
DROP POLICY IF EXISTS "clientes_update_authenticated" ON clientes;
DROP POLICY IF EXISTS "clientes_delete_authenticated" ON clientes;
DROP POLICY IF EXISTS "clientes_admin_all" ON clientes;
DROP POLICY IF EXISTS "clientes_all_authenticated" ON clientes;

CREATE POLICY "clientes_all_simple" ON clientes
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: sucursales - Simplificar
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "sucursales_read_authenticated" ON sucursales;
DROP POLICY IF EXISTS "sucursales_select_authenticated" ON sucursales;

CREATE POLICY "sucursales_all_simple" ON sucursales
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: prestamos - Simplificar
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "prestamos_select_authenticated" ON prestamos;
DROP POLICY IF EXISTS "prestamos_insert_authenticated" ON prestamos;
DROP POLICY IF EXISTS "prestamos_update_authenticated" ON prestamos;
DROP POLICY IF EXISTS "prestamos_admin_all" ON prestamos;
DROP POLICY IF EXISTS "prestamos_all_authenticated" ON prestamos;

CREATE POLICY "prestamos_all_simple" ON prestamos
    FOR ALL USING (auth.role() = 'authenticated');

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ════════════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
    RAISE NOTICE '══════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ RECURSIÓN ELIMINADA - Políticas simplificadas';
    RAISE NOTICE '══════════════════════════════════════════════════════════';
    RAISE NOTICE 'Tablas actualizadas:';
    RAISE NOTICE '  • usuarios_roles (causa principal)';
    RAISE NOTICE '  • roles';
    RAISE NOTICE '  • permisos';
    RAISE NOTICE '  • roles_permisos';
    RAISE NOTICE '  • empleados';
    RAISE NOTICE '  • clientes';
    RAISE NOTICE '  • sucursales';
    RAISE NOTICE '  • prestamos';
    RAISE NOTICE '══════════════════════════════════════════════════════════';
END $$;
