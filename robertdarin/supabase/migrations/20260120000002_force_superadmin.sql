-- Forzar asignación de superadmin con verificación previa
-- NOTA: Esta migración ya fue aplicada manualmente en Supabase Cloud

DO $$
BEGIN
  -- Solo ejecutar si el usuario existe en public.usuarios
  IF EXISTS (SELECT 1 FROM public.usuarios WHERE id = '19a4c079-c443-4a54-a5f0-5dc925f04431') THEN
    INSERT INTO usuarios_roles (usuario_id, rol_id)
    VALUES ('19a4c079-c443-4a54-a5f0-5dc925f04431'::uuid, '73b2f74e-443a-4b4d-95e1-6af6b2bee850'::uuid)
    ON CONFLICT (usuario_id, rol_id) DO NOTHING;
    RAISE NOTICE 'Rol superadmin forzado correctamente';
  ELSE
    RAISE NOTICE 'Usuario no existe en public.usuarios - se omite';
  END IF;
END $$;
