-- ══════════════════════════════════════════════════════════════════════════════
-- FIX: Políticas RLS para roles, permisos y formulario de empleados
-- Permite a usuarios autenticados LEER roles y permisos
-- ══════════════════════════════════════════════════════════════════════════════

-- 1. Desactivar temporalmente RLS para poder recrear políticas
-- NOTA: Las políticas se recrean de forma segura

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: roles - Todos los usuarios autenticados pueden VER roles
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "roles_public_read" ON roles;
DROP POLICY IF EXISTS "roles_select_authenticated" ON roles;
DROP POLICY IF EXISTS "roles_modify_superadmin" ON roles;

-- Política: Cualquier usuario autenticado puede leer roles
CREATE POLICY "roles_read_authenticated" ON roles
    FOR SELECT USING (true);

-- Política: Solo superadmin puede modificar roles
CREATE POLICY "roles_modify_superadmin" ON roles
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON r.id = ur.rol_id
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin'
        )
    );

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: permisos - Todos los usuarios autenticados pueden VER permisos
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "permisos_public_read" ON permisos;
DROP POLICY IF EXISTS "permisos_select_authenticated" ON permisos;

CREATE POLICY "permisos_read_authenticated" ON permisos
    FOR SELECT USING (true);

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: roles_permisos - Usuarios autenticados pueden VER asignaciones
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "roles_permisos_read" ON roles_permisos;
DROP POLICY IF EXISTS "roles_permisos_select_authenticated" ON roles_permisos;

CREATE POLICY "roles_permisos_read_authenticated" ON roles_permisos
    FOR SELECT USING (true);

-- Solo superadmin puede modificar roles_permisos
CREATE POLICY "roles_permisos_modify_superadmin" ON roles_permisos
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON r.id = ur.rol_id
            WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin'
        )
    );

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: sucursales - Usuarios autenticados pueden VER sucursales
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "sucursales_select_authenticated" ON sucursales;
DROP POLICY IF EXISTS "sucursales_read_authenticated" ON sucursales;

CREATE POLICY "sucursales_read_authenticated" ON sucursales
    FOR SELECT USING (true);

-- ════════════════════════════════════════════════════════════════════════════════
-- TABLA: empleados - Admin y superadmin pueden gestionar
-- ════════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "empleados_admin_all" ON empleados;

CREATE POLICY "empleados_read_authenticated" ON empleados
    FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "empleados_modify_admin" ON empleados
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON r.id = ur.rol_id
            WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin')
        )
    );

-- ════════════════════════════════════════════════════════════════════════════════
-- VERIFICACIÓN
-- ════════════════════════════════════════════════════════════════════════════════
DO $$
BEGIN
    RAISE NOTICE '✅ Políticas RLS actualizadas para:';
    RAISE NOTICE '   - roles (lectura para todos)';
    RAISE NOTICE '   - permisos (lectura para todos)';
    RAISE NOTICE '   - roles_permisos (lectura para todos)';
    RAISE NOTICE '   - sucursales (lectura para todos)';
    RAISE NOTICE '   - empleados (lectura autenticados, escritura admin)';
END $$;
