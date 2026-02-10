-- ======================================================================
-- ASIGNAR ROL SUPERADMIN AL USUARIO RECIEN CREADO
-- Email: rdarinel992@gmail.com
-- Fecha: 21 Enero 2026
-- ======================================================================

DO $$
DECLARE
    v_user_id UUID;
    v_rol_id UUID;
BEGIN
    -- Obtener ID del usuario recien creado
    SELECT id INTO v_user_id FROM auth.users WHERE email = 'rdarinel992@gmail.com';

    IF v_user_id IS NULL THEN
        RAISE NOTICE 'Usuario rdarinel992@gmail.com no encontrado en auth.users; omitiendo asignacion';
    ELSE
        RAISE NOTICE 'Usuario encontrado: %', v_user_id;

        -- Insertar en tabla usuarios
        INSERT INTO usuarios (id, email, nombre_completo, activo, created_at, updated_at)
        VALUES (v_user_id, 'rdarinel992@gmail.com', 'Robert Darin (Superadmin)', true, NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET
            nombre_completo = 'Robert Darin (Superadmin)',
            activo = true,
            updated_at = NOW();

        RAISE NOTICE 'Usuario insertado/actualizado en tabla usuarios';

        -- Obtener rol superadmin
        SELECT id INTO v_rol_id FROM roles WHERE nombre = 'superadmin';

        IF v_rol_id IS NULL THEN
            RAISE NOTICE 'Rol superadmin no encontrado; omitiendo asignacion';
        ELSE
            -- Limpiar roles previos y asignar superadmin
            DELETE FROM usuarios_roles WHERE usuario_id = v_user_id;
            INSERT INTO usuarios_roles (usuario_id, rol_id) VALUES (v_user_id, v_rol_id);

            RAISE NOTICE 'Rol superadmin asignado correctamente';
            RAISE NOTICE '';
            RAISE NOTICE 'CONFIGURACION COMPLETADA - Ya puedes hacer login!';
        END IF;
    END IF;
END $$;
