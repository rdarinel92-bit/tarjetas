-- Disable module profiles that can override superadmin role for a specific email
DO $$
DECLARE
  v_email text := 'rdarinel992@gmail.com';
  v_user_id uuid;
  v_rows int;
BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = v_email;
  IF v_user_id IS NULL THEN
    RAISE NOTICE 'User not found in auth.users: %', v_email;
    RETURN;
  END IF;

  -- Colaboradores
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='colaboradores') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='colaboradores' AND column_name='estado') THEN
      UPDATE colaboradores SET estado='inactivo'
      WHERE (auth_uid = v_user_id OR email = v_email) AND estado = 'activo';
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'colaboradores.estado -> inactivo: %', v_rows;
    END IF;
  END IF;

  -- Vendedoras Nice
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='nice_vendedoras') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='nice_vendedoras' AND column_name='activo') THEN
      UPDATE nice_vendedoras SET activo = false
      WHERE (auth_uid = v_user_id OR email = v_email) AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'nice_vendedoras.activo -> false: %', v_rows;
    END IF;
  END IF;

  -- Vendedores ventas
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ventas_vendedores') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ventas_vendedores' AND column_name='activo') THEN
      UPDATE ventas_vendedores SET activo = false
      WHERE (auth_uid = v_user_id OR email = v_email) AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'ventas_vendedores.activo -> false: %', v_rows;
    END IF;
  END IF;

  -- Tecnicos climas
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='climas_tecnicos') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='climas_tecnicos' AND column_name='activo') THEN
      UPDATE climas_tecnicos SET activo = false
      WHERE (auth_uid = v_user_id OR email = v_email) AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'climas_tecnicos.activo -> false: %', v_rows;
    END IF;
  END IF;

  -- Repartidores purificadora
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='purificadora_repartidores') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='purificadora_repartidores' AND column_name='activo') THEN
      UPDATE purificadora_repartidores SET activo = false
      WHERE (auth_uid = v_user_id OR email = v_email) AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'purificadora_repartidores.activo -> false: %', v_rows;
    END IF;
  END IF;

  -- Clientes modulo
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='clientes_modulo') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='clientes_modulo' AND column_name='activo') THEN
      UPDATE clientes_modulo SET activo = false
      WHERE auth_uid = v_user_id AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'clientes_modulo.activo -> false: %', v_rows;
    END IF;
  END IF;

  -- Clientes climas
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='climas_clientes') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='climas_clientes' AND column_name='activo') THEN
      UPDATE climas_clientes SET activo = false
      WHERE (auth_uid = v_user_id OR email = v_email) AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'climas_clientes.activo -> false: %', v_rows;
    END IF;
  END IF;

  -- Clientes purificadora
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='purificadora_clientes') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='purificadora_clientes' AND column_name='activo') THEN
      UPDATE purificadora_clientes SET activo = false
      WHERE (auth_uid = v_user_id OR email = v_email) AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'purificadora_clientes.activo -> false: %', v_rows;
    END IF;
  END IF;

  -- Clientes ventas
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='ventas_clientes') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ventas_clientes' AND column_name='activo') THEN
      UPDATE ventas_clientes SET activo = false
      WHERE (auth_uid = v_user_id OR email = v_email) AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'ventas_clientes.activo -> false: %', v_rows;
    END IF;
  END IF;

  -- Clientes nice
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='nice_clientes') THEN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='nice_clientes' AND column_name='activo') THEN
      UPDATE nice_clientes SET activo = false
      WHERE (auth_uid = v_user_id OR email = v_email) AND activo = true;
      GET DIAGNOSTICS v_rows = ROW_COUNT;
      RAISE NOTICE 'nice_clientes.activo -> false: %', v_rows;
    END IF;
  END IF;
END $$;
