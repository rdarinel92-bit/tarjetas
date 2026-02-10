-- Verificar y configurar superadmin
DO $$
DECLARE
  v_user_id UUID;
  v_rol_id UUID;
  v_count INTEGER;
BEGIN
  -- Buscar usuario en auth.users
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'rdarinel92@gmail.com';
  
  IF v_user_id IS NULL THEN
    RAISE NOTICE '⚠️ Usuario rdarinel92@gmail.com NO encontrado en auth.users';
    RAISE NOTICE 'Debes hacer login primero en la app para crear tu cuenta';
    RETURN;
  END IF;
  
  RAISE NOTICE 'Usuario encontrado: %', v_user_id;
  
  -- Verificar si está en tabla usuarios
  SELECT COUNT(*) INTO v_count FROM usuarios WHERE id = v_user_id;
  IF v_count = 0 THEN
    INSERT INTO usuarios (id, email, nombre_completo) 
    VALUES (v_user_id, 'rdarinel92@gmail.com', 'Robert Darin (Superadmin)');
    RAISE NOTICE '✅ Usuario agregado a tabla usuarios';
  ELSE
    RAISE NOTICE '✓ Usuario ya existe en tabla usuarios';
  END IF;
  
  -- Obtener rol superadmin
  SELECT id INTO v_rol_id FROM roles WHERE nombre = 'superadmin';
  IF v_rol_id IS NULL THEN
    RAISE NOTICE '❌ Rol superadmin no encontrado';
    RETURN;
  END IF;
  
  -- Verificar si tiene rol asignado
  SELECT COUNT(*) INTO v_count FROM usuarios_roles WHERE usuario_id = v_user_id AND rol_id = v_rol_id;
  IF v_count = 0 THEN
    INSERT INTO usuarios_roles (usuario_id, rol_id) VALUES (v_user_id, v_rol_id);
    RAISE NOTICE '✅ Rol superadmin asignado';
  ELSE
    RAISE NOTICE '✓ Ya tiene rol superadmin asignado';
  END IF;
  
  RAISE NOTICE '════════════════════════════════════════════';
  RAISE NOTICE 'CONFIGURACIÓN COMPLETADA';
  RAISE NOTICE '════════════════════════════════════════════';
END $$;

-- Mostrar estado final
SELECT 
  u.email,
  u.nombre_completo,
  r.nombre as rol
FROM usuarios u
LEFT JOIN usuarios_roles ur ON ur.usuario_id = u.id
LEFT JOIN roles r ON r.id = ur.rol_id
WHERE u.email = 'rdarinel92@gmail.com';
