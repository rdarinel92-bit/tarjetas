-- ═══════════════════════════════════════════════════════════════════════════════
-- EJECUTAR EN: Supabase Dashboard > SQL Editor
-- Paso 2 de 2: SOLUCIÓN
-- ═══════════════════════════════════════════════════════════════════════════════

-- 1. ASEGURAR QUE TU USUARIO TENGA ROL SUPERADMIN
INSERT INTO usuarios_roles (usuario_id, rol_id)
SELECT u.id, r.id
FROM usuarios u
CROSS JOIN roles r
WHERE u.email = 'rdarinel92@gmail.com' 
AND r.nombre = 'superadmin'
AND NOT EXISTS (
    SELECT 1 FROM usuarios_roles ur2 
    WHERE ur2.usuario_id = u.id AND ur2.rol_id = r.id
);

-- 2. CREAR FUNCIÓN RPC (con SECURITY DEFINER para bypass RLS)
CREATE OR REPLACE FUNCTION crear_empleado_completo(
    p_auth_user_id UUID,
    p_email TEXT,
    p_nombre_completo TEXT,
    p_telefono TEXT,
    p_puesto TEXT,
    p_salario NUMERIC,
    p_sucursal_id UUID,
    p_rol_id UUID,
    p_comision_porcentaje NUMERIC DEFAULT 0,
    p_comision_tipo TEXT DEFAULT 'ninguna'
)
RETURNS JSONB AS $$
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
            'error', 'No tienes permisos. Tu usuario no tiene rol superadmin asignado.'
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
    
    RETURN jsonb_build_object(
        'success', true,
        'empleado_id', v_empleado_id,
        'message', 'Empleado creado correctamente'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. VERIFICAR
SELECT '✅ SOLUCIÓN APLICADA' as resultado;
SELECT routine_name, 'FUNCIÓN CREADA' as estado 
FROM information_schema.routines WHERE routine_name = 'crear_empleado_completo';
