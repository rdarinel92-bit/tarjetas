-- Asignar rol superadmin al usuario principal
-- NOTA: Esta migración ya fue aplicada manualmente en Supabase Cloud
-- Se marca como no-op para evitar errores de FK constraint

DO $$
BEGIN
  -- Verificar si el usuario existe en public.usuarios antes de asignar rol
  IF EXISTS (SELECT 1 FROM public.usuarios WHERE id = '19a4c079-c443-4a54-a5f0-5dc925f04431') THEN
    -- Solo insertar si no existe ya la asignación
    INSERT INTO usuarios_roles (usuario_id, rol_id)
    SELECT '19a4c079-c443-4a54-a5f0-5dc925f04431'::uuid, '73b2f74e-443a-4b4d-95e1-6af6b2bee850'::uuid
    WHERE NOT EXISTS (
        SELECT 1 FROM usuarios_roles 
        WHERE usuario_id = '19a4c079-c443-4a54-a5f0-5dc925f04431' 
        AND rol_id = '73b2f74e-443a-4b4d-95e1-6af6b2bee850'
    );
    RAISE NOTICE 'Rol superadmin asignado correctamente';
  ELSE
    RAISE NOTICE 'Usuario no existe en public.usuarios - se omite asignación de rol';
  END IF;
END $$;
