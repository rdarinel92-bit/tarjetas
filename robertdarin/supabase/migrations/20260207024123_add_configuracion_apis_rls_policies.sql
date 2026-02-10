-- Migración: Agregar políticas RLS para configuracion_apis
-- Solo superadmin y admin pueden ver, solo superadmin puede modificar

-- Política SELECT: superadmin y admin pueden ver configuraciones
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'configuracion_apis_select') THEN
        CREATE POLICY "configuracion_apis_select" ON configuracion_apis FOR SELECT USING (
            auth.role() = 'authenticated' AND 
            EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
                    WHERE ur.usuario_id = auth.uid() AND r.nombre IN ('superadmin', 'admin'))
        );
    END IF;
END $$;

-- Política ALL (INSERT/UPDATE/DELETE): solo superadmin puede modificar
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'configuracion_apis_modify') THEN
        CREATE POLICY "configuracion_apis_modify" ON configuracion_apis FOR ALL USING (
            EXISTS (SELECT 1 FROM usuarios_roles ur JOIN roles r ON ur.rol_id = r.id 
                    WHERE ur.usuario_id = auth.uid() AND r.nombre = 'superadmin')
        );
    END IF;
END $$;
