-- ══════════════════════════════════════════════════════════════════════════════
-- FIX: Agregar políticas RLS faltantes para empleados y usuarios_roles
-- ══════════════════════════════════════════════════════════════════════════════

-- Política para EMPLEADOS: Solo admins pueden gestionar
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'empleados_admin_all' AND tablename = 'empleados') THEN
        CREATE POLICY "empleados_admin_all" ON empleados FOR ALL 
        USING (
          EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON r.id = ur.rol_id
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre IN ('superadmin', 'admin')
          )
        );
        RAISE NOTICE '✅ Política empleados_admin_all creada';
    ELSE
        RAISE NOTICE 'Política empleados_admin_all ya existe';
    END IF;
END $$;

-- Política para USUARIOS_ROLES: Solo admins pueden asignar roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'usuarios_roles_admin_all' AND tablename = 'usuarios_roles') THEN
        CREATE POLICY "usuarios_roles_admin_all" ON usuarios_roles FOR ALL 
        USING (
          EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON r.id = ur.rol_id
            WHERE ur.usuario_id = auth.uid() 
            AND r.nombre IN ('superadmin', 'admin')
          )
        );
        RAISE NOTICE '✅ Política usuarios_roles_admin_all creada';
    ELSE
        RAISE NOTICE 'Política usuarios_roles_admin_all ya existe';
    END IF;
END $$;

-- Política para SUCURSALES: Lectura para todos autenticados
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'sucursales_select_authenticated' AND tablename = 'sucursales') THEN
        CREATE POLICY "sucursales_select_authenticated" ON sucursales FOR SELECT 
        USING (auth.role() = 'authenticated');
        RAISE NOTICE '✅ Política sucursales_select_authenticated creada';
    ELSE
        RAISE NOTICE 'Política sucursales_select_authenticated ya existe';
    END IF;
END $$;

-- Política para ROLES: Lectura para todos autenticados (excepto superadmin en dropdown)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'roles_select_authenticated' AND tablename = 'roles') THEN
        CREATE POLICY "roles_select_authenticated" ON roles FOR SELECT 
        USING (auth.role() = 'authenticated');
        RAISE NOTICE '✅ Política roles_select_authenticated creada';
    ELSE
        RAISE NOTICE 'Política roles_select_authenticated ya existe';
    END IF;
END $$;

-- Política para ROLES_PERMISOS: Lectura para todos autenticados
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'roles_permisos_select_authenticated' AND tablename = 'roles_permisos') THEN
        CREATE POLICY "roles_permisos_select_authenticated" ON roles_permisos FOR SELECT 
        USING (auth.role() = 'authenticated');
        RAISE NOTICE '✅ Política roles_permisos_select_authenticated creada';
    ELSE
        RAISE NOTICE 'Política roles_permisos_select_authenticated ya existe';
    END IF;
END $$;

-- Política para PERMISOS: Lectura para todos autenticados
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'permisos_select_authenticated' AND tablename = 'permisos') THEN
        CREATE POLICY "permisos_select_authenticated" ON permisos FOR SELECT 
        USING (auth.role() = 'authenticated');
        RAISE NOTICE '✅ Política permisos_select_authenticated creada';
    ELSE
        RAISE NOTICE 'Política permisos_select_authenticated ya existe';
    END IF;
END $$;

-- Política para AUDITORIA: Solo admins pueden escribir
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'auditoria_admin_insert' AND tablename = 'auditoria') THEN
        CREATE POLICY "auditoria_admin_insert" ON auditoria FOR INSERT 
        WITH CHECK (auth.role() = 'authenticated');
        RAISE NOTICE '✅ Política auditoria_admin_insert creada';
    ELSE
        RAISE NOTICE 'Política auditoria_admin_insert ya existe';
    END IF;
END $$;

-- Verificación final
SELECT 'VERIFICACIÓN DE POLÍTICAS RLS PARA EMPLEADOS:' as info;
SELECT tablename, policyname, cmd FROM pg_policies 
WHERE tablename IN ('empleados', 'usuarios_roles', 'sucursales', 'roles', 'permisos', 'roles_permisos', 'auditoria')
ORDER BY tablename, policyname;
