-- =====================================================================================
-- MIGRACIÓN: Fix crear_empleado_completo para incluir negocio_id
-- Fecha: 2026-02-07
-- Descripción: La función original no insertaba negocio_id, rompiendo multi-tenancy
-- =====================================================================================

CREATE OR REPLACE FUNCTION public.crear_empleado_completo(
    p_auth_user_id uuid,
    p_email text,
    p_nombre_completo text,
    p_telefono text,
    p_puesto text,
    p_salario numeric,
    p_sucursal_id uuid,
    p_rol_id uuid,
    p_comision_porcentaje numeric DEFAULT 0,
    p_comision_tipo text DEFAULT 'ninguna'::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_admin_check BOOLEAN;
    v_empleado_id UUID;
    v_negocio_id UUID;
    v_usuario_negocio_id UUID;
BEGIN
    -- Verificar que el usuario actual es admin o superior
    SELECT EXISTS (
        SELECT 1 FROM usuarios_roles ur
        JOIN roles r ON r.id = ur.rol_id
        WHERE ur.usuario_id = auth.uid() 
        AND r.nombre IN ('superadmin', 'admin')
    ) INTO v_admin_check;
    
    IF NOT v_admin_check THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No tienes permisos para crear empleados. Tu usuario no tiene rol de admin/superadmin asignado.'
        );
    END IF;
    
    -- Obtener negocio_id de la sucursal
    SELECT negocio_id INTO v_negocio_id 
    FROM sucursales 
    WHERE id = p_sucursal_id;
    
    -- Si la sucursal no tiene negocio_id, intentar obtenerlo del usuario actual
    IF v_negocio_id IS NULL THEN
        SELECT negocio_id INTO v_negocio_id
        FROM usuarios
        WHERE id = auth.uid();
    END IF;
    
    -- Obtener negocio_id del usuario actual para el registro de usuarios
    SELECT negocio_id INTO v_usuario_negocio_id
    FROM usuarios
    WHERE id = auth.uid();
    
    -- 1. Crear/actualizar perfil en usuarios CON negocio_id
    INSERT INTO usuarios (id, email, nombre_completo, telefono, negocio_id)
    VALUES (p_auth_user_id, p_email, p_nombre_completo, p_telefono, COALESCE(v_negocio_id, v_usuario_negocio_id))
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        nombre_completo = EXCLUDED.nombre_completo,
        telefono = EXCLUDED.telefono,
        negocio_id = COALESCE(EXCLUDED.negocio_id, usuarios.negocio_id),
        updated_at = NOW();
    
    -- 2. Crear registro de empleado CON negocio_id
    INSERT INTO empleados (
        usuario_id, 
        puesto, 
        salario, 
        sucursal_id, 
        comision_porcentaje, 
        comision_tipo, 
        estado,
        negocio_id,
        nombre,
        email,
        telefono
    )
    VALUES (
        p_auth_user_id, 
        p_puesto, 
        p_salario, 
        p_sucursal_id, 
        p_comision_porcentaje, 
        p_comision_tipo, 
        'activo',
        v_negocio_id,
        p_nombre_completo,
        p_email,
        p_telefono
    )
    RETURNING id INTO v_empleado_id;
    
    -- 3. Asignar rol
    INSERT INTO usuarios_roles (usuario_id, rol_id)
    VALUES (p_auth_user_id, p_rol_id)
    ON CONFLICT (usuario_id, rol_id) DO NOTHING;
    
    -- 4. Crear relación empleado-negocio en tabla empleados_negocios
    IF v_negocio_id IS NOT NULL THEN
        INSERT INTO empleados_negocios (empleado_id, negocio_id, auth_uid, rol_modulo)
        VALUES (v_empleado_id, v_negocio_id, p_auth_user_id, 'operador')
        ON CONFLICT DO NOTHING;
    END IF;
    
    -- 5. Registrar en auditoría CON negocio_id
    INSERT INTO auditoria (tabla, accion, descripcion, usuario_id, negocio_id)
    VALUES ('empleados', 'INSERT', 'Empleado creado via RPC: ' || p_nombre_completo, auth.uid(), v_negocio_id);
    
    RETURN jsonb_build_object(
        'success', true,
        'empleado_id', v_empleado_id,
        'usuario_id', p_auth_user_id,
        'negocio_id', v_negocio_id,
        'message', 'Empleado creado correctamente con negocio asignado'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$;

-- Actualizar comentario
COMMENT ON FUNCTION public.crear_empleado_completo IS 
'Crea un empleado completo con usuario, rol, negocio_id y registro de auditoría. Requiere ser admin o superior. V10.53 - Fix multi-tenancy';
