drop extension if exists "pg_net";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.crear_empleado_completo(p_auth_user_id uuid, p_email text, p_nombre_completo text, p_telefono text, p_puesto text, p_salario numeric, p_sucursal_id uuid, p_rol_id uuid, p_comision_porcentaje numeric DEFAULT 0, p_comision_tipo text DEFAULT 'ninguna'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_admin_check BOOLEAN;
    v_empleado_id UUID;
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
    
    -- 1. Crear/actualizar perfil en usuarios
    INSERT INTO usuarios (id, email, nombre_completo, telefono)
    VALUES (p_auth_user_id, p_email, p_nombre_completo, p_telefono)
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        nombre_completo = EXCLUDED.nombre_completo,
        telefono = EXCLUDED.telefono,
        updated_at = NOW();
    
    -- 2. Crear registro de empleado
    INSERT INTO empleados (usuario_id, puesto, salario, sucursal_id, comision_porcentaje, comision_tipo, estado)
    VALUES (p_auth_user_id, p_puesto, p_salario, p_sucursal_id, p_comision_porcentaje, p_comision_tipo, 'activo')
    RETURNING id INTO v_empleado_id;
    
    -- 3. Asignar rol
    INSERT INTO usuarios_roles (usuario_id, rol_id)
    VALUES (p_auth_user_id, p_rol_id)
    ON CONFLICT (usuario_id, rol_id) DO NOTHING;
    
    -- 4. Registrar en auditoría
    INSERT INTO auditoria (tabla, accion, descripcion, usuario_id)
    VALUES ('empleados', 'INSERT', 'Empleado creado via RPC: ' || p_nombre_completo, auth.uid());
    
    RETURN jsonb_build_object(
        'success', true,
        'empleado_id', v_empleado_id,
        'usuario_id', p_auth_user_id,
        'message', 'Empleado creado correctamente'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$function$
;


