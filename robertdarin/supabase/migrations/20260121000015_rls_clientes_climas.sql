-- ═══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN 15: RLS PARA CLIENTES DE CLIMAS
-- Robert Darin Platform v10.52
-- Fecha: 21 Enero 2026
-- 
-- Objetivo: Asegurar que los clientes del módulo climas solo vean sus propios datos
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. MEJORES POLÍTICAS RLS PARA climas_clientes
-- ═══════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "climas_clientes_access" ON climas_clientes;
DROP POLICY IF EXISTS "climas_clientes_cliente_select" ON climas_clientes;
DROP POLICY IF EXISTS "climas_clientes_admin_all" ON climas_clientes;

-- Política para clientes: solo ven SU propio registro
CREATE POLICY "climas_clientes_cliente_select" ON climas_clientes
    FOR SELECT USING (
        auth_uid = auth.uid() -- Solo su propio registro
        OR EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin', 'admin_climas', 'tecnico_climas')
        )
    );

-- Política para admin/superadmin: acceso total
CREATE POLICY "climas_clientes_admin_all" ON climas_clientes
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin', 'admin_climas')
        )
    );

-- 2. MEJORES POLÍTICAS RLS PARA climas_equipos
-- ═══════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "climas_equipos_access" ON climas_equipos;
DROP POLICY IF EXISTS "climas_equipos_cliente_select" ON climas_equipos;
DROP POLICY IF EXISTS "climas_equipos_admin_all" ON climas_equipos;

-- Política para clientes: solo ven SUS equipos
CREATE POLICY "climas_equipos_cliente_select" ON climas_equipos
    FOR SELECT USING (
        cliente_id IN (SELECT id FROM climas_clientes WHERE auth_uid = auth.uid())
        OR EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin', 'admin_climas', 'tecnico_climas')
        )
    );

-- Política para admin/superadmin: acceso total
CREATE POLICY "climas_equipos_admin_all" ON climas_equipos
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin', 'admin_climas', 'tecnico_climas')
        )
    );

-- 3. MEJORES POLÍTICAS RLS PARA climas_ordenes_servicio
-- ═══════════════════════════════════════════════════════════════════════════════
DROP POLICY IF EXISTS "climas_ordenes_access" ON climas_ordenes_servicio;
DROP POLICY IF EXISTS "climas_ordenes_cliente_select" ON climas_ordenes_servicio;
DROP POLICY IF EXISTS "climas_ordenes_admin_all" ON climas_ordenes_servicio;

-- Política para clientes: solo ven SUS órdenes
CREATE POLICY "climas_ordenes_cliente_select" ON climas_ordenes_servicio
    FOR SELECT USING (
        cliente_id IN (SELECT id FROM climas_clientes WHERE auth_uid = auth.uid())
        OR EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin', 'admin_climas', 'tecnico_climas')
        )
    );

-- Política para admin/técnico: acceso total
CREATE POLICY "climas_ordenes_admin_all" ON climas_ordenes_servicio
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM usuarios_roles ur
            JOIN roles r ON ur.rol_id = r.id
            WHERE ur.usuario_id = auth.uid()
            AND r.nombre IN ('superadmin', 'admin', 'admin_climas', 'tecnico_climas')
        )
    );

-- 4. LOG DE APLICACIÓN
-- ═══════════════════════════════════════════════════════════════════════════════
DO $$ 
BEGIN
    RAISE NOTICE '✅ RLS para clientes de climas aplicado correctamente';
    RAISE NOTICE '   - climas_clientes: clientes solo ven su registro';
    RAISE NOTICE '   - climas_equipos: clientes solo ven sus equipos';
    RAISE NOTICE '   - climas_ordenes_servicio: clientes solo ven sus órdenes';
END $$;
