


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."actualizar_contador_leidos"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.leida = true AND OLD.leida = false AND NEW.notificacion_masiva_id IS NOT NULL THEN
        UPDATE notificaciones_masivas 
        SET leidos_count = leidos_count + 1 
        WHERE id = NEW.notificacion_masiva_id;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."actualizar_contador_leidos"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_nivel_vendedora"("p_vendedora_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_ventas_mes NUMERIC;
    v_nuevo_nivel_id UUID;
    v_nivel_actual TEXT;
    v_nivel_nuevo TEXT;
    v_negocio_id UUID;
BEGIN
    -- Obtener ventas del mes y negocio
    SELECT 
        COALESCE(SUM(total), 0),
        v.negocio_id
    INTO v_ventas_mes, v_negocio_id
    FROM nice_vendedoras v
    LEFT JOIN nice_pedidos p ON p.vendedora_id = v.id 
        AND p.estado = 'entregado'
        AND EXTRACT(MONTH FROM p.fecha_pedido) = EXTRACT(MONTH FROM CURRENT_DATE)
        AND EXTRACT(YEAR FROM p.fecha_pedido) = EXTRACT(YEAR FROM CURRENT_DATE)
    WHERE v.id = p_vendedora_id
    GROUP BY v.negocio_id;
    
    -- Obtener nivel actual
    SELECT n.nombre INTO v_nivel_actual
    FROM nice_vendedoras v
    JOIN nice_niveles n ON n.id = v.nivel_id
    WHERE v.id = p_vendedora_id;
    
    -- Buscar nivel correspondiente a las ventas
    SELECT id, nombre INTO v_nuevo_nivel_id, v_nivel_nuevo
    FROM nice_niveles
    WHERE negocio_id = v_negocio_id
        AND ventas_minimas_mes <= v_ventas_mes
    ORDER BY ventas_minimas_mes DESC
    LIMIT 1;
    
    -- Actualizar si hay cambio de nivel
    IF v_nuevo_nivel_id IS NOT NULL THEN
        UPDATE nice_vendedoras
        SET nivel_id = v_nuevo_nivel_id,
            ventas_mes = v_ventas_mes
        WHERE id = p_vendedora_id;
    END IF;
    
    RETURN COALESCE(v_nivel_nuevo, v_nivel_actual);
END;
$$;


ALTER FUNCTION "public"."actualizar_nivel_vendedora"("p_vendedora_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_ultimo_mensaje_conversacion"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  UPDATE chat_conversaciones 
  SET ultimo_mensaje = NEW.contenido_texto,
      fecha_ultimo_mensaje = NEW.created_at,
      updated_at = NOW()
  WHERE id = NEW.conversacion_id;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."actualizar_ultimo_mensaje_conversacion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."actualizar_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."actualizar_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."aplicar_mora_automatica"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_config RECORD;
  v_dias_mora INTEGER;
  v_monto_mora NUMERIC;
  v_negocio_id UUID;
BEGIN
  -- Solo procesar si cambió a estado 'vencido'
  IF NEW.estado = 'vencido' AND (OLD.estado IS NULL OR OLD.estado != 'vencido') THEN
    
    -- Obtener negocio del préstamo
    SELECT p.negocio_id INTO v_negocio_id
    FROM prestamos p
    WHERE p.id = NEW.prestamo_id;
    
    -- Obtener configuración
    SELECT * INTO v_config
    FROM configuracion_moras
    WHERE negocio_id = v_negocio_id;
    
    -- Si hay configuración y está habilitado el automático
    IF v_config IS NOT NULL AND v_config.prestamos_aplicar_automatico THEN
      v_dias_mora := CURRENT_DATE - NEW.fecha_vencimiento;
      
      -- Solo si pasaron los días de gracia
      IF v_dias_mora > v_config.prestamos_dias_gracia THEN
        v_dias_mora := v_dias_mora - v_config.prestamos_dias_gracia;
        v_monto_mora := ROUND(NEW.monto_cuota * LEAST(v_dias_mora * v_config.prestamos_mora_diaria, v_config.prestamos_mora_maxima) / 100, 2);
        
        -- Insertar registro de mora (si no existe)
        INSERT INTO moras_prestamos (
          prestamo_id,
          amortizacion_id,
          dias_mora,
          monto_cuota_original,
          porcentaje_mora_aplicado,
          monto_mora,
          monto_total_con_mora,
          generado_automatico
        )
        VALUES (
          NEW.prestamo_id,
          NEW.id,
          v_dias_mora,
          NEW.monto_cuota,
          LEAST(v_dias_mora * v_config.prestamos_mora_diaria, v_config.prestamos_mora_maxima),
          v_monto_mora,
          NEW.monto_cuota + v_monto_mora,
          TRUE
        )
        ON CONFLICT (amortizacion_id) WHERE amortizacion_id IS NOT NULL DO UPDATE
        SET dias_mora = EXCLUDED.dias_mora,
            porcentaje_mora_aplicado = EXCLUDED.porcentaje_mora_aplicado,
            monto_mora = EXCLUDED.monto_mora,
            monto_total_con_mora = EXCLUDED.monto_total_con_mora,
            updated_at = NOW();
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."aplicar_mora_automatica"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."asignar_superadmin_si_no_existe"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE 
  superadmin_count INTEGER;
  superadmin_rol_id UUID;
BEGIN
  SELECT id INTO superadmin_rol_id FROM roles WHERE nombre = 'superadmin';
  IF superadmin_rol_id IS NULL THEN
    RETURN NEW;
  END IF;
  
  SELECT count(*) INTO superadmin_count 
  FROM usuarios_roles 
  WHERE rol_id = superadmin_rol_id;
  
  IF superadmin_count = 0 THEN
    INSERT INTO usuarios_roles (usuario_id, rol_id) 
    VALUES (NEW.id, superadmin_rol_id);
  END IF;
  RETURN NEW;
END; 
$$;


ALTER FUNCTION "public"."asignar_superadmin_si_no_existe"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."autoconfirmar_cobro_efectivo"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.tipo_metodo = 'efectivo' AND NEW.estado = 'pendiente' THEN
        NEW.estado := 'confirmado';
        NEW.fecha_confirmacion := NOW();
        NEW.confirmado_por := NEW.registrado_por;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."autoconfirmar_cobro_efectivo"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calcular_capital_total"("p_negocio_id" "uuid") RETURNS TABLE("capital_prestamos" numeric, "capital_activos" numeric, "total_enviado" numeric, "capital_total" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COALESCE((SELECT SUM(monto) FROM prestamos WHERE negocio_id = p_negocio_id AND estado IN ('activo', 'vigente')), 0)::DECIMAL,
        COALESCE((SELECT SUM(valor_actual) FROM activos_capital WHERE negocio_id = p_negocio_id AND estado = 'activo'), 0)::DECIMAL,
        COALESCE((SELECT SUM(monto_mxn) FROM envios_capital WHERE negocio_id = p_negocio_id), 0)::DECIMAL,
        (
            COALESCE((SELECT SUM(monto) FROM prestamos WHERE negocio_id = p_negocio_id AND estado IN ('activo', 'vigente')), 0) +
            COALESCE((SELECT SUM(valor_actual) FROM activos_capital WHERE negocio_id = p_negocio_id AND estado = 'activo'), 0)
        )::DECIMAL;
END;
$$;


ALTER FUNCTION "public"."calcular_capital_total"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calcular_comision_nice"("p_vendedora_id" "uuid", "p_monto_venta" numeric) RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_porcentaje NUMERIC;
BEGIN
    SELECT n.comision_ventas INTO v_porcentaje
    FROM nice_vendedoras v
    JOIN nice_niveles n ON n.id = v.nivel_id
    WHERE v.id = p_vendedora_id;
    
    IF v_porcentaje IS NULL THEN
        v_porcentaje := 20; -- Default 20%
    END IF;
    
    RETURN ROUND(p_monto_venta * v_porcentaje / 100, 2);
END;
$$;


ALTER FUNCTION "public"."calcular_comision_nice"("p_vendedora_id" "uuid", "p_monto_venta" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calcular_mora_prestamo"("p_prestamo_id" "uuid") RETURNS TABLE("cuotas_vencidas" integer, "monto_vencido" numeric, "dias_mora_max" integer, "mora_porcentaje" numeric)
    LANGUAGE "sql" STABLE
    AS $$
    SELECT 
        COUNT(*)::INTEGER,
        COALESCE(SUM(monto_cuota), 0),
        COALESCE(MAX(CURRENT_DATE - fecha_vencimiento), 0)::INTEGER,
        CASE 
            WHEN MAX(CURRENT_DATE - fecha_vencimiento) <= 0 THEN 0
            WHEN MAX(CURRENT_DATE - fecha_vencimiento) <= 7 THEN 5
            WHEN MAX(CURRENT_DATE - fecha_vencimiento) <= 30 THEN 10
            ELSE 15
        END::DECIMAL
    FROM amortizaciones
    WHERE prestamo_id = p_prestamo_id
    AND estado = 'vencido';
$$;


ALTER FUNCTION "public"."calcular_mora_prestamo"("p_prestamo_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calcular_mora_prestamo"("p_amortizacion_id" "uuid", "p_negocio_id" "uuid" DEFAULT NULL::"uuid") RETURNS TABLE("dias_mora" integer, "monto_cuota" numeric, "porcentaje_mora" numeric, "monto_mora" numeric, "monto_total" numeric)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_fecha_vencimiento DATE;
  v_monto_cuota NUMERIC;
  v_dias_mora INTEGER;
  v_mora_diaria NUMERIC := 1.0;
  v_mora_maxima NUMERIC := 30.0;
  v_dias_gracia INTEGER := 0;
  v_porcentaje_calculado NUMERIC;
BEGIN
  -- Obtener datos de la amortización
  SELECT a.fecha_vencimiento, a.monto_cuota
  INTO v_fecha_vencimiento, v_monto_cuota
  FROM amortizaciones a
  WHERE a.id = p_amortizacion_id;
  
  -- Calcular días de mora
  v_dias_mora := GREATEST(0, CURRENT_DATE - v_fecha_vencimiento);
  
  -- Si hay negocio_id, obtener configuración personalizada
  IF p_negocio_id IS NOT NULL THEN
    SELECT cm.prestamos_mora_diaria, cm.prestamos_mora_maxima, cm.prestamos_dias_gracia
    INTO v_mora_diaria, v_mora_maxima, v_dias_gracia
    FROM configuracion_moras cm
    WHERE cm.negocio_id = p_negocio_id;
  END IF;
  
  -- Restar días de gracia
  v_dias_mora := GREATEST(0, v_dias_mora - v_dias_gracia);
  
  -- Calcular porcentaje de mora (limitado al máximo)
  v_porcentaje_calculado := LEAST(v_dias_mora * v_mora_diaria, v_mora_maxima);
  
  RETURN QUERY SELECT
    v_dias_mora,
    v_monto_cuota,
    v_porcentaje_calculado,
    ROUND(v_monto_cuota * v_porcentaje_calculado / 100, 2),
    ROUND(v_monto_cuota * (1 + v_porcentaje_calculado / 100), 2);
END;
$$;


ALTER FUNCTION "public"."calcular_mora_prestamo"("p_amortizacion_id" "uuid", "p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calcular_rendimiento_inversionista"("p_colaborador_id" "uuid", "p_mes" integer DEFAULT NULL::integer, "p_anio" integer DEFAULT NULL::integer) RETURNS TABLE("total_invertido" numeric, "rendimiento_pactado" numeric, "rendimiento_mes" numeric, "rendimiento_acumulado" numeric)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.monto_invertido as total_invertido,
    COALESCE(c.rendimiento_pactado, 0) as rendimiento_pactado,
    (c.monto_invertido * COALESCE(c.rendimiento_pactado, 0) / 100) as rendimiento_mes,
    COALESCE(
      (SELECT SUM(monto) FROM colaborador_inversiones 
       WHERE colaborador_id = p_colaborador_id AND tipo = 'rendimiento'),
      0
    ) as rendimiento_acumulado
  FROM colaboradores c
  WHERE c.id = p_colaborador_id;
END;
$$;


ALTER FUNCTION "public"."calcular_rendimiento_inversionista"("p_colaborador_id" "uuid", "p_mes" integer, "p_anio" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."cliente_tiene_prestamo_activo"("p_cliente_id" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
    SELECT EXISTS (
        SELECT 1 FROM prestamos
        WHERE cliente_id = p_cliente_id
        AND estado IN ('activo', 'mora')
    );
$$;


ALTER FUNCTION "public"."cliente_tiene_prestamo_activo"("p_cliente_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."clientes_con_stripe"("p_negocio_id" "uuid") RETURNS TABLE("id" "uuid", "nombre" "text", "telefono" "text", "stripe_customer_id" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono, c.stripe_customer_id
    FROM clientes c
    WHERE c.negocio_id = p_negocio_id
    AND c.stripe_customer_id IS NOT NULL
    AND c.prefiere_efectivo = FALSE;
END;
$$;


ALTER FUNCTION "public"."clientes_con_stripe"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."clientes_solo_efectivo"("p_negocio_id" "uuid") RETURNS TABLE("id" "uuid", "nombre" "text", "telefono" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.nombre, c.telefono
    FROM clientes c
    WHERE c.negocio_id = p_negocio_id
    AND (c.stripe_customer_id IS NULL OR c.prefiere_efectivo = TRUE);
END;
$$;


ALTER FUNCTION "public"."clientes_solo_efectivo"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."climas_aprobar_solicitud_qr"("p_solicitud_id" "uuid", "p_crear_cliente" boolean DEFAULT true, "p_crear_orden" boolean DEFAULT false, "p_notas" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_solicitud RECORD;
    v_cliente_id UUID;
    v_orden_id UUID;
BEGIN
    -- Obtener solicitud
    SELECT * INTO v_solicitud 
    FROM climas_solicitudes_qr 
    WHERE id = p_solicitud_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;
    
    -- Crear cliente si se solicita
    IF p_crear_cliente THEN
        INSERT INTO climas_clientes (
            negocio_id, nombre, telefono, email, direccion, 
            colonia, ciudad, codigo_postal, referencia,
            latitud, longitud, tipo_cliente, notas, activo
        ) VALUES (
            v_solicitud.negocio_id,
            v_solicitud.nombre_completo,
            v_solicitud.telefono,
            v_solicitud.email,
            v_solicitud.direccion,
            v_solicitud.colonia,
            v_solicitud.ciudad,
            v_solicitud.codigo_postal,
            v_solicitud.referencia_ubicacion,
            v_solicitud.latitud,
            v_solicitud.longitud,
            CASE WHEN v_solicitud.tipo_espacio IN ('local_comercial', 'bodega') THEN 'comercial' ELSE 'residencial' END,
            COALESCE(v_solicitud.notas_cliente, '') || E'\n\nOrigen: Formulario QR',
            TRUE
        )
        RETURNING id INTO v_cliente_id;
    END IF;
    
    -- Actualizar solicitud
    UPDATE climas_solicitudes_qr SET
        estado = 'aprobado',
        cliente_creado_id = v_cliente_id,
        fecha_conversion = NOW(),
        notas_internas = COALESCE(notas_internas, '') || E'\n' || COALESCE(p_notas, ''),
        revisado_por = auth.uid(),
        fecha_revision = NOW(),
        updated_at = NOW()
    WHERE id = p_solicitud_id;
    
    -- Registrar en historial
    INSERT INTO climas_solicitud_historial (solicitud_id, estado_anterior, estado_nuevo, comentario, usuario_id)
    VALUES (p_solicitud_id, v_solicitud.estado, 'aprobado', p_notas, auth.uid());
    
    RETURN jsonb_build_object(
        'success', true,
        'cliente_id', v_cliente_id,
        'orden_id', v_orden_id,
        'message', 'Solicitud aprobada correctamente'
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;


ALTER FUNCTION "public"."climas_aprobar_solicitud_qr"("p_solicitud_id" "uuid", "p_crear_cliente" boolean, "p_crear_orden" boolean, "p_notas" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."climas_obtener_solicitud_por_token"("p_token" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_solicitud RECORD;
    v_mensajes JSONB;
BEGIN
    SELECT * INTO v_solicitud 
    FROM climas_solicitudes_qr 
    WHERE token_seguimiento = p_token;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'error', 'Solicitud no encontrada');
    END IF;
    
    -- Obtener mensajes del chat
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', id,
            'es_cliente', es_cliente,
            'remitente_nombre', remitente_nombre,
            'mensaje', mensaje,
            'tipo_mensaje', tipo_mensaje,
            'adjunto_url', adjunto_url,
            'created_at', created_at
        ) ORDER BY created_at ASC
    ), '[]'::jsonb) INTO v_mensajes
    FROM climas_chat_solicitud
    WHERE solicitud_id = v_solicitud.id;
    
    RETURN jsonb_build_object(
        'success', true,
        'solicitud', jsonb_build_object(
            'id', v_solicitud.id,
            'nombre', v_solicitud.nombre_completo,
            'estado', v_solicitud.estado,
            'tipo_servicio', v_solicitud.tipo_servicio,
            'created_at', v_solicitud.created_at,
            'respuesta', v_solicitud.notas_internas
        ),
        'mensajes', v_mensajes
    );
END;
$$;


ALTER FUNCTION "public"."climas_obtener_solicitud_por_token"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."confirmar_cobro_cliente"("p_codigo_qr" "text", "p_latitud" numeric, "p_longitud" numeric, "p_dispositivo" "text" DEFAULT NULL::"text") RETURNS TABLE("exito" boolean, "mensaje" "text", "qr_id" "uuid")
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_qr RECORD;
BEGIN
    -- Buscar el QR
    SELECT * INTO v_qr FROM qr_cobros 
    WHERE codigo_qr = p_codigo_qr;
    
    -- Validaciones
    IF v_qr IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Código QR no encontrado'::TEXT, NULL::UUID;
        RETURN;
    END IF;
    
    IF v_qr.estado != 'pendiente' THEN
        RETURN QUERY SELECT FALSE, 'Este código ya fue usado o expiró'::TEXT, v_qr.id;
        RETURN;
    END IF;
    
    IF v_qr.fecha_expiracion < NOW() THEN
        UPDATE qr_cobros SET estado = 'expirado' WHERE id = v_qr.id;
        RETURN QUERY SELECT FALSE, 'El código QR ha expirado'::TEXT, v_qr.id;
        RETURN;
    END IF;
    
    -- Confirmar el cobro
    UPDATE qr_cobros
    SET 
        cliente_confirmo = TRUE,
        cliente_confirmo_at = NOW(),
        cliente_latitud = p_latitud,
        cliente_longitud = p_longitud,
        cliente_dispositivo = p_dispositivo,
        estado = CASE WHEN cobrador_confirmo THEN 'confirmado' ELSE estado END,
        updated_at = NOW()
    WHERE id = v_qr.id;
    
    -- Si ambos confirmaron, marcar como confirmado
    IF v_qr.cobrador_confirmo THEN
        RETURN QUERY SELECT TRUE, 'Cobro confirmado exitosamente'::TEXT, v_qr.id;
    ELSE
        RETURN QUERY SELECT TRUE, 'Confirmación registrada, esperando al cobrador'::TEXT, v_qr.id;
    END IF;
END;
$$;


ALTER FUNCTION "public"."confirmar_cobro_cliente"("p_codigo_qr" "text", "p_latitud" numeric, "p_longitud" numeric, "p_dispositivo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."confirmar_cobro_cobrador"("p_qr_id" "uuid", "p_latitud" numeric, "p_longitud" numeric) RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE qr_cobros
    SET 
        cobrador_confirmo = TRUE,
        cobrador_confirmo_at = NOW(),
        cobrador_latitud = p_latitud,
        cobrador_longitud = p_longitud,
        updated_at = NOW()
    WHERE id = p_qr_id AND estado = 'pendiente';
    
    RETURN FOUND;
END;
$$;


ALTER FUNCTION "public"."confirmar_cobro_cobrador"("p_qr_id" "uuid", "p_latitud" numeric, "p_longitud" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_backup_completo"("p_notas" "text" DEFAULT NULL::"text") RETURNS TABLE("tabla" "text", "registros" integer, "estado" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'backup'
    AS $$
begin
  if not usuario_tiene_rol('superadmin') then
    raise exception 'No autorizado';
  end if;

  return query
  select * from backup.crear_backup_completo(p_notas);
end;
$$;


ALTER FUNCTION "public"."crear_backup_completo"("p_notas" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_empleado_completo"("p_auth_user_id" "uuid", "p_email" "text", "p_nombre_completo" "text", "p_telefono" "text", "p_puesto" "text", "p_salario" numeric, "p_sucursal_id" "uuid", "p_rol_id" "uuid", "p_comision_porcentaje" numeric DEFAULT 0, "p_comision_tipo" "text" DEFAULT 'ninguna'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
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
$$;


ALTER FUNCTION "public"."crear_empleado_completo"("p_auth_user_id" "uuid", "p_email" "text", "p_nombre_completo" "text", "p_telefono" "text", "p_puesto" "text", "p_salario" numeric, "p_sucursal_id" "uuid", "p_rol_id" "uuid", "p_comision_porcentaje" numeric, "p_comision_tipo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."crear_qr_cobro"("p_negocio_id" "uuid", "p_cobrador_id" "uuid", "p_cliente_id" "uuid", "p_tipo_cobro" "text", "p_referencia_id" "uuid", "p_monto" numeric, "p_concepto" "text") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_qr_id UUID;
    v_codigo_qr TEXT;
    v_codigo_verificacion TEXT;
    v_horas_expiracion INTEGER;
BEGIN
    -- Obtener configuración del negocio
    SELECT COALESCE(qr_expira_horas, 24) INTO v_horas_expiracion
    FROM qr_cobros_config WHERE negocio_id = p_negocio_id;
    
    IF v_horas_expiracion IS NULL THEN
        v_horas_expiracion := 24;
    END IF;
    
    -- Generar códigos únicos
    v_codigo_qr := generar_codigo_qr();
    v_codigo_verificacion := generar_codigo_verificacion();
    
    -- Insertar QR de cobro
    INSERT INTO qr_cobros (
        negocio_id, codigo_qr, codigo_verificacion,
        cobrador_id, cliente_id,
        tipo_cobro, referencia_id,
        monto, concepto,
        fecha_expiracion
    ) VALUES (
        p_negocio_id, v_codigo_qr, v_codigo_verificacion,
        p_cobrador_id, p_cliente_id,
        p_tipo_cobro, p_referencia_id,
        p_monto, p_concepto,
        NOW() + (v_horas_expiracion || ' hours')::INTERVAL
    ) RETURNING id INTO v_qr_id;
    
    RETURN v_qr_id;
END;
$$;


ALTER FUNCTION "public"."crear_qr_cobro"("p_negocio_id" "uuid", "p_cobrador_id" "uuid", "p_cliente_id" "uuid", "p_tipo_cobro" "text", "p_referencia_id" "uuid", "p_monto" numeric, "p_concepto" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."efectivo_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN COALESCE((
        SELECT SUM(monto)
        FROM pagos
        WHERE negocio_id = p_negocio_id
        AND metodo_pago IN ('efectivo', 'transferencia')
        AND fecha_pago BETWEEN p_fecha_inicio AND p_fecha_fin
    ), 0);
END;
$$;


ALTER FUNCTION "public"."efectivo_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ejecutar_mantenimiento_db"() RETURNS TABLE("tarea" "text", "registros_afectados" integer, "tiempo_ms" integer)
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_inicio TIMESTAMPTZ;
    v_registros INTEGER;
BEGIN
    -- 1. Limpiar caché expirado
    v_inicio := clock_timestamp();
    SELECT limpiar_cache_expirado() INTO v_registros;
    RETURN QUERY SELECT 'Limpiar caché'::TEXT, v_registros, 
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
    
    -- 2. Limpiar auditoría antigua
    v_inicio := clock_timestamp();
    SELECT limpiar_auditoria_antigua() INTO v_registros;
    RETURN QUERY SELECT 'Limpiar auditoría'::TEXT, v_registros,
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
    
    -- 3. Limpiar notificaciones
    v_inicio := clock_timestamp();
    SELECT limpiar_notificaciones_antiguas() INTO v_registros;
    RETURN QUERY SELECT 'Limpiar notificaciones'::TEXT, v_registros,
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
    
    -- 4. Refrescar vistas materializadas
    v_inicio := clock_timestamp();
    PERFORM refrescar_vistas_materializadas();
    RETURN QUERY SELECT 'Refrescar vistas'::TEXT, 0,
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
    
    -- 5. Actualizar estadísticas de tablas principales
    v_inicio := clock_timestamp();
    ANALYZE prestamos;
    ANALYZE amortizaciones;
    ANALYZE pagos;
    ANALYZE clientes;
    RETURN QUERY SELECT 'Actualizar estadísticas'::TEXT, 0,
        EXTRACT(MILLISECONDS FROM clock_timestamp() - v_inicio)::INTEGER;
END;
$$;


ALTER FUNCTION "public"."ejecutar_mantenimiento_db"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."es_admin_o_superior"() RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuarios_roles ur
    JOIN roles r ON r.id = ur.rol_id
    WHERE ur.usuario_id = auth.uid() 
    AND r.nombre IN ('superadmin', 'admin')
  );
END;
$$;


ALTER FUNCTION "public"."es_admin_o_superior"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generar_codigo_qr"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    codigo TEXT;
BEGIN
    -- Genera código alfanumérico de 12 caracteres (fácil de leer)
    codigo := UPPER(SUBSTRING(MD5(RANDOM()::TEXT || NOW()::TEXT) FROM 1 FOR 12));
    RETURN codigo;
END;
$$;


ALTER FUNCTION "public"."generar_codigo_qr"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generar_codigo_vendedora"("p_negocio_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_numero INTEGER;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(codigo_vendedora FROM 'VND-(\d+)') AS INTEGER)), 0) + 1
    INTO v_numero
    FROM nice_vendedoras
    WHERE negocio_id = p_negocio_id;
    
    RETURN 'VND-' || LPAD(v_numero::TEXT, 4, '0');
END;
$$;


ALTER FUNCTION "public"."generar_codigo_vendedora"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generar_codigo_verificacion"() RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
END;
$$;


ALTER FUNCTION "public"."generar_codigo_verificacion"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generar_folio_nice_pedido"("p_negocio_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_numero INTEGER;
    v_folio TEXT;
BEGIN
    SELECT COALESCE(MAX(CAST(SUBSTRING(folio FROM 'PED-NICE-(\d+)') AS INTEGER)), 0) + 1
    INTO v_numero
    FROM nice_pedidos
    WHERE negocio_id = p_negocio_id;
    
    v_folio := 'PED-NICE-' || LPAD(v_numero::TEXT, 6, '0');
    RETURN v_folio;
END;
$$;


ALTER FUNCTION "public"."generar_folio_nice_pedido"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_tarjeta_deep_link"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.qr_deep_link IS NULL OR NEW.qr_deep_link = '' THEN
        IF NEW.negocio_id IS NOT NULL THEN
            NEW.qr_deep_link = 'robertdarin://' || NEW.modulo || '/formulario?negocio=' ||
                NEW.negocio_id::TEXT || '&tarjeta=' || NEW.codigo;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."generate_tarjeta_deep_link"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cuotas_proximas"("p_negocio_id" "uuid" DEFAULT NULL::"uuid", "p_dias" integer DEFAULT 7) RETURNS TABLE("amortizacion_id" "uuid", "prestamo_id" "uuid", "cliente_id" "uuid", "cliente_nombre" "text", "numero_cuota" integer, "monto_cuota" numeric, "fecha_vencimiento" "date", "dias_para_vencer" integer, "estado" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id as amortizacion_id,
        a.prestamo_id,
        p.cliente_id,
        c.nombre as cliente_nombre,
        a.numero_cuota,
        a.monto_cuota,
        a.fecha_vencimiento,
        (a.fecha_vencimiento - CURRENT_DATE)::INTEGER as dias_para_vencer,
        a.estado
    FROM amortizaciones a
    JOIN prestamos p ON p.id = a.prestamo_id
    JOIN clientes c ON c.id = p.cliente_id
    WHERE a.estado = 'pendiente'
    AND a.fecha_vencimiento BETWEEN CURRENT_DATE AND (CURRENT_DATE + p_dias)
    AND (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
    ORDER BY a.fecha_vencimiento ASC;
END;
$$;


ALTER FUNCTION "public"."get_cuotas_proximas"("p_negocio_id" "uuid", "p_dias" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_cuotas_vencidas"("p_negocio_id" "uuid" DEFAULT NULL::"uuid", "p_limit" integer DEFAULT 100) RETURNS TABLE("amortizacion_id" "uuid", "prestamo_id" "uuid", "cliente_id" "uuid", "cliente_nombre" "text", "cliente_telefono" "text", "numero_cuota" integer, "monto_cuota" numeric, "fecha_vencimiento" "date", "dias_mora" integer, "monto_mora" numeric, "aval_nombre" "text", "aval_telefono" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id as amortizacion_id,
        a.prestamo_id,
        p.cliente_id,
        c.nombre as cliente_nombre,
        c.telefono as cliente_telefono,
        a.numero_cuota,
        a.monto_cuota,
        a.fecha_vencimiento,
        (CURRENT_DATE - a.fecha_vencimiento)::INTEGER as dias_mora,
        COALESCE(m.monto_mora, 0) as monto_mora,
        av.nombre as aval_nombre,
        av.telefono as aval_telefono
    FROM amortizaciones a
    JOIN prestamos p ON p.id = a.prestamo_id
    JOIN clientes c ON c.id = p.cliente_id
    LEFT JOIN moras_prestamos m ON m.amortizacion_id = a.id
    LEFT JOIN prestamos_avales pa ON pa.prestamo_id = p.id AND pa.orden = 1
    LEFT JOIN avales av ON av.id = pa.aval_id
    WHERE a.estado IN ('vencido', 'pendiente')
    AND a.fecha_vencimiento < CURRENT_DATE
    AND (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
    ORDER BY a.fecha_vencimiento ASC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_cuotas_vencidas"("p_negocio_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_dashboard_stats"("p_negocio_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_resultado JSONB;
    v_cache JSONB;
    v_fecha_inicio DATE;
    v_fecha_fin DATE;
BEGIN
    -- Definir periodo del mes actual
    v_fecha_inicio := date_trunc('month', CURRENT_DATE)::DATE;
    v_fecha_fin := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    
    -- Verificar cache
    SELECT datos INTO v_cache
    FROM cache_estadisticas
    WHERE tipo = 'dashboard_global'
      AND (negocio_id = p_negocio_id OR (p_negocio_id IS NULL AND negocio_id IS NULL))
      AND expira_en > NOW()
    LIMIT 1;
    
    IF v_cache IS NOT NULL THEN
        RETURN v_cache;
    END IF;
    
    -- Calcular estadísticas
    SELECT jsonb_build_object(
        -- Cartera
        'cartera_total', COALESCE((
            SELECT SUM(p.monto)
            FROM prestamos p
            WHERE p.estado IN ('activo', 'mora')
            AND (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ), 0),
        
        'cartera_vencida', COALESCE((
            SELECT SUM(a.monto_cuota)
            FROM amortizaciones a
            JOIN prestamos p ON p.id = a.prestamo_id
            WHERE a.estado = 'vencido'
            AND (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ), 0),
        
        -- Colocación del mes
        'colocado_mes', COALESCE((
            SELECT SUM(monto)
            FROM prestamos
            WHERE fecha_creacion >= v_fecha_inicio
            AND fecha_creacion <= v_fecha_fin
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ), 0),
        
        -- Recuperado del mes
        'recuperado_mes', COALESCE((
            SELECT SUM(monto)
            FROM pagos
            WHERE fecha_pago >= v_fecha_inicio
            AND fecha_pago <= v_fecha_fin
            AND prestamo_id IS NOT NULL
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ), 0),
        
        -- Clientes
        'total_clientes', (
            SELECT COUNT(*)
            FROM clientes
            WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        'clientes_activos', (
            SELECT COUNT(*)
            FROM clientes
            WHERE activo = true
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Préstamos
        'prestamos_activos', (
            SELECT COUNT(*)
            FROM prestamos
            WHERE estado = 'activo'
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        'prestamos_en_mora', (
            SELECT COUNT(*)
            FROM prestamos
            WHERE estado = 'mora'
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Pagos del mes
        'pagos_mes', (
            SELECT COUNT(*)
            FROM pagos
            WHERE fecha_pago >= v_fecha_inicio
            AND fecha_pago <= v_fecha_fin
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Tandas activas
        'tandas_activas', (
            SELECT COUNT(*)
            FROM tandas
            WHERE estado = 'activa'
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Empleados y sucursales
        'total_empleados', (
            SELECT COUNT(*)
            FROM empleados
            WHERE activo = true
        ),
        'total_sucursales', (
            SELECT COUNT(*)
            FROM sucursales
            WHERE activa = true
            AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
        ),
        
        -- Metadatos
        'fecha_calculo', NOW(),
        'periodo', to_char(CURRENT_DATE, 'YYYY-MM')
    ) INTO v_resultado;
    
    -- Guardar en cache (expira en 1 hora)
    INSERT INTO cache_estadisticas (negocio_id, tipo, periodo, datos, expira_en)
    VALUES (p_negocio_id, 'dashboard_global', to_char(CURRENT_DATE, 'YYYY-MM'), v_resultado, NOW() + INTERVAL '1 hour')
    ON CONFLICT (negocio_id, sucursal_id, tipo, periodo) 
    DO UPDATE SET datos = EXCLUDED.datos, expira_en = EXCLUDED.expira_en, fecha_calculo = NOW();
    
    RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."get_dashboard_stats"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_estadisticas_formularios"("p_negocio_id" "uuid") RETURNS TABLE("total_envios" integer, "nuevos" integer, "contactados" integer, "completados" integer, "tasa_conversion" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_envios,
        COUNT(*) FILTER (WHERE e.estado = 'nuevo')::INTEGER as nuevos,
        COUNT(*) FILTER (WHERE e.estado IN ('contactado', 'en_proceso'))::INTEGER as contactados,
        COUNT(*) FILTER (WHERE e.estado = 'completado')::INTEGER as completados,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(*) FILTER (WHERE e.estado = 'completado')::NUMERIC / COUNT(*)) * 100, 2)
            ELSE 0 
        END as tasa_conversion
    FROM formularios_qr_envios e
    WHERE e.negocio_id = p_negocio_id;
END;
$$;


ALTER FUNCTION "public"."get_estadisticas_formularios"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_estado_cuenta_prestamo"("p_prestamo_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_prestamo RECORD;
    v_resultado JSONB;
BEGIN
    -- Obtener datos del préstamo
    SELECT * INTO v_prestamo FROM prestamos WHERE id = p_prestamo_id;
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Préstamo no encontrado');
    END IF;
    
    SELECT jsonb_build_object(
        'prestamo', jsonb_build_object(
            'id', v_prestamo.id,
            'monto', v_prestamo.monto,
            'interes', v_prestamo.interes,
            'plazo_meses', v_prestamo.plazo_meses,
            'frecuencia', v_prestamo.frecuencia_pago,
            'estado', v_prestamo.estado,
            'fecha_creacion', v_prestamo.fecha_creacion
        ),
        'cliente', (
            SELECT jsonb_build_object(
                'id', c.id,
                'nombre', c.nombre,
                'telefono', c.telefono,
                'email', c.email
            )
            FROM clientes c WHERE c.id = v_prestamo.cliente_id
        ),
        'amortizaciones', (
            SELECT jsonb_agg(jsonb_build_object(
                'numero_cuota', a.numero_cuota,
                'monto_cuota', a.monto_cuota,
                'monto_capital', a.monto_capital,
                'monto_interes', a.monto_interes,
                'saldo_restante', a.saldo_restante,
                'fecha_vencimiento', a.fecha_vencimiento,
                'fecha_pago', a.fecha_pago,
                'estado', a.estado
            ) ORDER BY a.numero_cuota)
            FROM amortizaciones a WHERE a.prestamo_id = p_prestamo_id
        ),
        'pagos', (
            SELECT jsonb_agg(jsonb_build_object(
                'id', pg.id,
                'monto', pg.monto,
                'fecha_pago', pg.fecha_pago,
                'metodo_pago', pg.metodo_pago,
                'numero_cuota', a.numero_cuota
            ) ORDER BY pg.fecha_pago DESC)
            FROM pagos pg
            LEFT JOIN amortizaciones a ON a.id = pg.amortizacion_id
            WHERE pg.prestamo_id = p_prestamo_id
        ),
        'resumen', jsonb_build_object(
            'total_a_pagar', (SELECT SUM(monto_cuota) FROM amortizaciones WHERE prestamo_id = p_prestamo_id),
            'total_pagado', (SELECT COALESCE(SUM(monto), 0) FROM pagos WHERE prestamo_id = p_prestamo_id),
            'saldo_pendiente', (
                SELECT SUM(monto_cuota) 
                FROM amortizaciones 
                WHERE prestamo_id = p_prestamo_id AND estado IN ('pendiente', 'vencido')
            ),
            'cuotas_pagadas', (SELECT COUNT(*) FROM amortizaciones WHERE prestamo_id = p_prestamo_id AND estado IN ('pagado', 'pagada')),
            'cuotas_pendientes', (SELECT COUNT(*) FROM amortizaciones WHERE prestamo_id = p_prestamo_id AND estado = 'pendiente'),
            'cuotas_vencidas', (SELECT COUNT(*) FROM amortizaciones WHERE prestamo_id = p_prestamo_id AND estado = 'vencido'),
            'dias_mora_total', (
                SELECT COALESCE(SUM(CURRENT_DATE - fecha_vencimiento), 0)
                FROM amortizaciones 
                WHERE prestamo_id = p_prestamo_id AND estado = 'vencido'
            )
        ),
        'avales', (
            SELECT jsonb_agg(jsonb_build_object(
                'nombre', av.nombre,
                'telefono', av.telefono,
                'relacion', av.relacion,
                'orden', pa.orden
            ) ORDER BY pa.orden)
            FROM prestamos_avales pa
            JOIN avales av ON av.id = pa.aval_id
            WHERE pa.prestamo_id = p_prestamo_id
        ),
        'fecha_consulta', NOW()
    ) INTO v_resultado;
    
    RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."get_estado_cuenta_prestamo"("p_prestamo_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_formulario_config"("p_tarjeta_id" "uuid" DEFAULT NULL::"uuid", "p_negocio_id" "uuid" DEFAULT NULL::"uuid", "p_modulo" character varying DEFAULT 'general'::character varying) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_config JSONB;
BEGIN
    -- Primero buscar config específica de la tarjeta
    IF p_tarjeta_id IS NOT NULL THEN
        SELECT to_jsonb(f.*) INTO v_config
        FROM formularios_qr_config f
        WHERE f.tarjeta_servicio_id = p_tarjeta_id AND f.activo = true
        LIMIT 1;
        
        IF v_config IS NOT NULL THEN
            RETURN v_config;
        END IF;
    END IF;
    
    -- Si no, buscar config del módulo para el negocio
    IF p_negocio_id IS NOT NULL THEN
        SELECT to_jsonb(f.*) INTO v_config
        FROM formularios_qr_config f
        WHERE f.negocio_id = p_negocio_id 
          AND f.modulo = p_modulo 
          AND f.tarjeta_servicio_id IS NULL
          AND f.activo = true
        LIMIT 1;
        
        IF v_config IS NOT NULL THEN
            RETURN v_config;
        END IF;
    END IF;
    
    -- Retornar configuración por defecto
    RETURN jsonb_build_object(
        'nombre_formulario', 'Formulario de Contacto',
        'titulo_header', '¡Contáctanos!',
        'subtitulo_header', 'Completa el formulario',
        'color_header', '#00D9FF',
        'mensaje_exito', '¡Gracias! Te contactaremos pronto.',
        'campos', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'id', c.codigo,
                    'tipo', c.tipo,
                    'label', c.label,
                    'placeholder', c.placeholder,
                    'requerido', c.requerido_default,
                    'orden', c.orden_sugerido,
                    'activo', true,
                    'opciones', c.opciones
                ) ORDER BY c.orden_sugerido
            )
            FROM campos_formulario_catalogo c
            WHERE (c.modulo = 'general' OR c.modulo = p_modulo)
              AND c.activo = true
        )
    );
END;
$$;


ALTER FUNCTION "public"."get_formulario_config"("p_tarjeta_id" "uuid", "p_negocio_id" "uuid", "p_modulo" character varying) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_historial_pagos_cliente"("p_cliente_id" "uuid", "p_limit" integer DEFAULT 50) RETURNS TABLE("pago_id" "uuid", "prestamo_id" "uuid", "tanda_id" "uuid", "monto" numeric, "metodo_pago" "text", "fecha_pago" timestamp with time zone, "numero_cuota" integer, "tipo" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pg.id as pago_id,
        pg.prestamo_id,
        pg.tanda_id,
        pg.monto,
        pg.metodo_pago,
        pg.fecha_pago,
        a.numero_cuota,
        CASE 
            WHEN pg.prestamo_id IS NOT NULL THEN 'prestamo'
            WHEN pg.tanda_id IS NOT NULL THEN 'tanda'
            ELSE 'otro'
        END as tipo
    FROM pagos pg
    LEFT JOIN amortizaciones a ON a.id = pg.amortizacion_id
    WHERE pg.cliente_id = p_cliente_id
    ORDER BY pg.fecha_pago DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_historial_pagos_cliente"("p_cliente_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_nice_dashboard_vendedora"("p_vendedora_id" "uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_fecha_inicio DATE;
    v_fecha_fin DATE;
BEGIN
    v_fecha_inicio := date_trunc('month', CURRENT_DATE)::DATE;
    v_fecha_fin := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    
    RETURN (
        SELECT jsonb_build_object(
            'vendedora', (
                SELECT jsonb_build_object(
                    'id', v.id,
                    'nombre', v.nombre,
                    'codigo', v.codigo_vendedora,
                    'nivel', n.nombre,
                    'nivel_color', n.color,
                    'comision_porcentaje', n.comision_ventas,
                    'meta_mensual', v.meta_mensual,
                    'foto_url', v.foto_url
                )
                FROM nice_vendedoras v
                LEFT JOIN nice_niveles n ON n.id = v.nivel_id
                WHERE v.id = p_vendedora_id
            ),
            'ventas_mes', (
                SELECT COALESCE(SUM(total), 0)
                FROM nice_pedidos
                WHERE vendedora_id = p_vendedora_id
                AND estado = 'entregado'
                AND fecha_pedido >= v_fecha_inicio
                AND fecha_pedido <= v_fecha_fin
            ),
            'comisiones_pendientes', (
                SELECT COALESCE(SUM(monto), 0)
                FROM nice_comisiones
                WHERE vendedora_id = p_vendedora_id
                AND estado = 'pendiente'
            ),
            'pedidos_pendientes', (
                SELECT COUNT(*)
                FROM nice_pedidos
                WHERE vendedora_id = p_vendedora_id
                AND estado = 'pendiente'
            ),
            'clientes_total', (
                SELECT COUNT(*)
                FROM nice_clientes
                WHERE vendedora_id = p_vendedora_id
                AND activo = true
            ),
            'equipo_directo', (
                SELECT COUNT(*)
                FROM nice_vendedoras
                WHERE patrocinadora_id = p_vendedora_id
                AND activa = true
            ),
            'progreso_meta', (
                SELECT jsonb_build_object(
                    'ventas', COALESCE(SUM(total), 0),
                    'meta', v.meta_mensual,
                    'porcentaje', ROUND(COALESCE(SUM(total), 0) / NULLIF(v.meta_mensual, 0) * 100, 1)
                )
                FROM nice_vendedoras v
                LEFT JOIN nice_pedidos p ON p.vendedora_id = v.id
                    AND p.estado = 'entregado'
                    AND p.fecha_pedido >= v_fecha_inicio
                WHERE v.id = p_vendedora_id
                GROUP BY v.meta_mensual
            ),
            'ultimos_pedidos', (
                SELECT jsonb_agg(jsonb_build_object(
                    'id', p.id,
                    'folio', p.folio,
                    'cliente', c.nombre,
                    'total', p.total,
                    'estado', p.estado,
                    'fecha', p.fecha_pedido
                ) ORDER BY p.fecha_pedido DESC)
                FROM (
                    SELECT * FROM nice_pedidos 
                    WHERE vendedora_id = p_vendedora_id
                    ORDER BY fecha_pedido DESC
                    LIMIT 5
                ) p
                LEFT JOIN nice_clientes c ON c.id = p.cliente_id
            ),
            'fecha_consulta', NOW()
        )
    );
END;
$$;


ALTER FUNCTION "public"."get_nice_dashboard_vendedora"("p_vendedora_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_nice_ranking_mes"("p_negocio_id" "uuid", "p_limit" integer DEFAULT 10) RETURNS TABLE("posicion" integer, "vendedora_id" "uuid", "nombre" "text", "codigo" "text", "nivel" "text", "nivel_color" "text", "ventas_mes" numeric, "pedidos_mes" integer, "foto_url" "text")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_fecha_inicio DATE;
    v_fecha_fin DATE;
BEGIN
    v_fecha_inicio := date_trunc('month', CURRENT_DATE)::DATE;
    v_fecha_fin := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
    
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(p.total), 0) DESC)::INTEGER as posicion,
        v.id as vendedora_id,
        v.nombre,
        v.codigo_vendedora as codigo,
        n.nombre as nivel,
        n.color as nivel_color,
        COALESCE(SUM(p.total), 0) as ventas_mes,
        COUNT(p.id)::INTEGER as pedidos_mes,
        v.foto_url
    FROM nice_vendedoras v
    LEFT JOIN nice_niveles n ON n.id = v.nivel_id
    LEFT JOIN nice_pedidos p ON p.vendedora_id = v.id
        AND p.estado = 'entregado'
        AND p.fecha_pedido >= v_fecha_inicio
        AND p.fecha_pedido <= v_fecha_fin
    WHERE v.negocio_id = p_negocio_id
    AND v.activa = true
    GROUP BY v.id, v.nombre, v.codigo_vendedora, n.nombre, n.color, v.foto_url
    ORDER BY ventas_mes DESC
    LIMIT p_limit;
END;
$$;


ALTER FUNCTION "public"."get_nice_ranking_mes"("p_negocio_id" "uuid", "p_limit" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_resumen_cartera"("p_negocio_id" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN (
        SELECT jsonb_build_object(
            'por_estado', (
                SELECT jsonb_agg(jsonb_build_object(
                    'estado', estado,
                    'cantidad', cantidad,
                    'monto_total', monto_total
                ))
                FROM (
                    SELECT 
                        estado,
                        COUNT(*) as cantidad,
                        SUM(monto) as monto_total
                    FROM prestamos
                    WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
                    GROUP BY estado
                ) sub
            ),
            'por_sucursal', (
                SELECT jsonb_agg(jsonb_build_object(
                    'sucursal_id', sucursal_id,
                    'sucursal_nombre', sucursal_nombre,
                    'cantidad', cantidad,
                    'monto_activo', monto_activo
                ))
                FROM (
                    SELECT 
                        p.sucursal_id,
                        s.nombre as sucursal_nombre,
                        COUNT(*) as cantidad,
                        SUM(CASE WHEN p.estado = 'activo' THEN p.monto ELSE 0 END) as monto_activo
                    FROM prestamos p
                    LEFT JOIN sucursales s ON s.id = p.sucursal_id
                    WHERE (p.negocio_id = p_negocio_id OR p_negocio_id IS NULL)
                    GROUP BY p.sucursal_id, s.nombre
                ) sub
            ),
            'resumen_general', jsonb_build_object(
                'total_prestamos', (SELECT COUNT(*) FROM prestamos WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)),
                'total_colocado', (SELECT COALESCE(SUM(monto), 0) FROM prestamos WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)),
                'total_recuperado', (SELECT COALESCE(SUM(monto), 0) FROM pagos WHERE prestamo_id IS NOT NULL AND (negocio_id = p_negocio_id OR p_negocio_id IS NULL)),
                'porcentaje_mora', (
                    SELECT ROUND(
                        (COUNT(*) FILTER (WHERE estado = 'mora')::NUMERIC / 
                         NULLIF(COUNT(*) FILTER (WHERE estado IN ('activo', 'mora')), 0)::NUMERIC) * 100
                    , 2)
                    FROM prestamos 
                    WHERE (negocio_id = p_negocio_id OR p_negocio_id IS NULL)
                )
            ),
            'fecha_calculo', NOW()
        )
    );
END;
$$;


ALTER FUNCTION "public"."get_resumen_cartera"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_sucursal_principal"() RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    sucursal_id UUID;
BEGIN
    SELECT id INTO sucursal_id FROM sucursales 
    WHERE nombre ILIKE '%principal%' OR nombre ILIKE '%matriz%'
    LIMIT 1;
    
    IF sucursal_id IS NULL THEN
        SELECT id INTO sucursal_id FROM sucursales LIMIT 1;
    END IF;
    
    RETURN sucursal_id;
END;
$$;


ALTER FUNCTION "public"."get_sucursal_principal"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tarjeta_stats"("p_tarjeta_id" "uuid") RETURNS TABLE("total_escaneos" integer, "escaneos_hoy" integer, "escaneos_semana" integer, "escaneos_mes" integer, "conversiones" integer, "tasa_conversion" numeric)
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::INTEGER as total_escaneos,
        COUNT(*) FILTER (WHERE e.created_at >= CURRENT_DATE)::INTEGER as escaneos_hoy,
        COUNT(*) FILTER (WHERE e.created_at >= CURRENT_DATE - INTERVAL '7 days')::INTEGER as escaneos_semana,
        COUNT(*) FILTER (WHERE e.created_at >= CURRENT_DATE - INTERVAL '30 days')::INTEGER as escaneos_mes,
        COUNT(*) FILTER (WHERE e.genero_solicitud = true)::INTEGER as conversiones,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                ROUND((COUNT(*) FILTER (WHERE e.genero_solicitud = true)::NUMERIC / COUNT(*)) * 100, 2)
            ELSE 0 
        END as tasa_conversion
    FROM tarjetas_servicio_escaneos e
    WHERE e.tarjeta_id = p_tarjeta_id;
END;
$$;


ALTER FUNCTION "public"."get_tarjeta_stats"("p_tarjeta_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_tarjetas_negocio"("p_negocio_id" "uuid") RETURNS TABLE("tarjeta" "jsonb", "estadisticas" "jsonb")
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        to_jsonb(t.*) as tarjeta,
        (SELECT to_jsonb(s.*) FROM get_tarjeta_stats(t.id) s) as estadisticas
    FROM tarjetas_servicio t
    WHERE t.negocio_id = p_negocio_id AND t.activa = true
    ORDER BY t.created_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_tarjetas_negocio"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_tarjeta_escaneos"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE tarjetas_servicio 
    SET escaneos_total = escaneos_total + 1,
        ultimo_escaneo = NOW()
    WHERE id = NEW.tarjeta_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."increment_tarjeta_escaneos"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."inicializar_datos_nice"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Solo ejecutar para negocios tipo retail (NICE)
    IF NEW.tipo = 'retail' THEN
        
        -- 1. Insertar niveles MLM
        INSERT INTO nice_niveles (negocio_id, nombre, orden, comision_porcentaje, comision_equipo_porcentaje, meta_ventas_mensual, beneficios, color, icono, activo)
        VALUES
            (NEW.id, 'Bronce', 1, 20.00, 0.00, 5000.00, '["Precio preferencial 30% descuento", "Kit de inicio", "Capacitación básica"]', '#CD7F32', 'star_border', TRUE),
            (NEW.id, 'Plata', 2, 25.00, 3.00, 15000.00, '["Todo Bronce", "5% comisión equipo nivel 1", "Catálogo digital", "Soporte prioritario"]', '#C0C0C0', 'star_half', TRUE),
            (NEW.id, 'Oro', 3, 30.00, 5.00, 35000.00, '["Todo Plata", "7% comisión equipo", "Bonos trimestrales", "Reconocimiento público"]', '#FFD700', 'star', TRUE),
            (NEW.id, 'Platino', 4, 35.00, 8.00, 75000.00, '["Todo Oro", "10% comisión equipo", "Viaje anual", "Producto gratis mensual"]', '#E5E4E2', 'workspace_premium', TRUE),
            (NEW.id, 'Diamante', 5, 40.00, 12.00, 150000.00, '["Todo Platino", "15% comisión multinivel", "Auto programa", "Participación utilidades"]', '#B9F2FF', 'diamond', TRUE);
        
        -- 2. Insertar categorías de joyería
        INSERT INTO nice_categorias (negocio_id, nombre, descripcion, icono, color, orden, activa)
        VALUES
            (NEW.id, 'Anillos', 'Anillos de compromiso, bodas y moda', 'ring_volume', '#E91E63', 1, TRUE),
            (NEW.id, 'Collares', 'Cadenas, dijes y gargantillas', 'necklace', '#9C27B0', 2, TRUE),
            (NEW.id, 'Aretes', 'Aretes, huggies y piercings', 'earbuds', '#673AB7', 3, TRUE),
            (NEW.id, 'Pulseras', 'Pulseras, brazaletes y tobilleras', 'watch', '#3F51B5', 4, TRUE),
            (NEW.id, 'Relojes', 'Relojes de dama y caballero', 'schedule', '#2196F3', 5, TRUE),
            (NEW.id, 'Sets', 'Conjuntos y juegos de joyería', 'inventory_2', '#00BCD4', 6, TRUE),
            (NEW.id, 'Accesorios', 'Broches, pins y otros accesorios', 'category', '#009688', 7, TRUE);
        
        -- 3. Insertar catálogo inicial
        INSERT INTO nice_catalogos (negocio_id, nombre, descripcion, vigencia_inicio, vigencia_fin, imagen_portada, version, activo)
        VALUES
            (NEW.id, 'Catálogo 2026', 'Catálogo de lanzamiento ' || NEW.nombre, CURRENT_DATE, CURRENT_DATE + INTERVAL '1 year', NULL, '1.0', TRUE);
        
        -- 4. Insertar productos de ejemplo
        INSERT INTO nice_productos (negocio_id, categoria_id, sku, codigo_pagina, nombre, descripcion, material, precio_catalogo, precio_vendedora, costo, stock, stock_minimo, destacado, nuevo, activo)
        SELECT 
            NEW.id,
            cat.id,
            'NICE-' || LPAD(ROW_NUMBER() OVER()::TEXT, 4, '0'),
            'P' || LPAD(ROW_NUMBER() OVER()::TEXT, 3, '0'),
            prod.nombre,
            prod.descripcion,
            prod.material,
            prod.precio,
            ROUND(prod.precio * 0.70, 2),
            ROUND(prod.precio * 0.45, 2),
            prod.stock,
            5,
            prod.destacado,
            prod.nuevo,
            TRUE
        FROM (VALUES
            ('Anillo Solitario Clásico', 'Anillo con circón brillante central', 'Plata 925', 850.00, 25, TRUE, TRUE, 'Anillos'),
            ('Anillo Infinity Love', 'Símbolo del amor infinito', 'Oro 10k', 2200.00, 15, TRUE, FALSE, 'Anillos'),
            ('Collar Corazón Brillante', 'Dije corazón con cadena 45cm', 'Plata 925', 980.00, 20, TRUE, TRUE, 'Collares'),
            ('Collar Perlas Elegance', 'Perlas cultivadas 6mm', 'Perlas/Plata', 1500.00, 12, TRUE, FALSE, 'Collares'),
            ('Aretes Huggies Diamond', 'Aretes abrazadera con circones', 'Plata 925', 680.00, 35, TRUE, TRUE, 'Aretes'),
            ('Aretes Gota Cristal', 'Cristal Swarovski', 'Plata/Cristal', 950.00, 20, TRUE, FALSE, 'Aretes'),
            ('Pulsera Tennis Classic', '30 circones brillantes', 'Plata 925', 1400.00, 15, TRUE, TRUE, 'Pulseras'),
            ('Pulsera Charm Love', '5 dijes incluidos', 'Plata 925', 890.00, 22, TRUE, FALSE, 'Pulseras'),
            ('Reloj Glamour Rose', 'Reloj dama con cristales', 'Acero/Oro rosa', 1800.00, 10, TRUE, TRUE, 'Relojes'),
            ('Set Novia Completo', 'Collar + Aretes + Pulsera', 'Plata 925/Cristal', 4500.00, 5, TRUE, TRUE, 'Sets')
        ) AS prod(nombre, descripcion, material, precio, stock, destacado, nuevo, categoria)
        LEFT JOIN nice_categorias cat ON cat.nombre = prod.categoria AND cat.negocio_id = NEW.id;
        
        RAISE NOTICE 'NICE: Datos iniciales creados para negocio %', NEW.nombre;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."inicializar_datos_nice"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."invalidar_cache_estadisticas"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    DELETE FROM cache_estadisticas 
    WHERE (negocio_id = NEW.negocio_id OR negocio_id IS NULL)
    AND tipo = 'dashboard_global';
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."invalidar_cache_estadisticas"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."limpiar_auditoria_antigua"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_eliminados INTEGER := 0;
    v_temp INTEGER;
BEGIN
    DELETE FROM auditoria
    WHERE fecha < NOW() - INTERVAL '6 months';
    GET DIAGNOSTICS v_temp = ROW_COUNT;
    v_eliminados := v_eliminados + v_temp;
    
    DELETE FROM auditoria_acceso
    WHERE created_at < NOW() - INTERVAL '6 months';
    GET DIAGNOSTICS v_temp = ROW_COUNT;
    v_eliminados := v_eliminados + v_temp;
    
    RETURN v_eliminados;
END;
$$;


ALTER FUNCTION "public"."limpiar_auditoria_antigua"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."limpiar_cache_expirado"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_eliminados INTEGER;
BEGIN
    DELETE FROM cache_estadisticas
    WHERE expira_at < NOW();
    GET DIAGNOSTICS v_eliminados = ROW_COUNT;
    RETURN v_eliminados;
END;
$$;


ALTER FUNCTION "public"."limpiar_cache_expirado"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."limpiar_datos_antiguos"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Limpiar cache expirado
    DELETE FROM cache_estadisticas WHERE expira_en < NOW();
    
    -- Limpiar activity_log mayor a 90 días
    DELETE FROM activity_log WHERE created_at < NOW() - INTERVAL '90 days';
    
    -- Limpiar notificaciones leídas mayores a 30 días
    DELETE FROM notificaciones 
    WHERE leida = true 
    AND created_at < NOW() - INTERVAL '30 days';
END;
$$;


ALTER FUNCTION "public"."limpiar_datos_antiguos"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."limpiar_notificaciones_antiguas"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_eliminados INTEGER;
BEGIN
    DELETE FROM notificaciones
    WHERE leida = true 
    AND created_at < NOW() - INTERVAL '3 months';
    GET DIAGNOSTICS v_eliminados = ROW_COUNT;
    RETURN v_eliminados;
END;
$$;


ALTER FUNCTION "public"."limpiar_notificaciones_antiguas"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."log_activity"("p_accion" "text", "p_entidad" "text" DEFAULT NULL::"text", "p_entidad_id" "uuid" DEFAULT NULL::"uuid", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO activity_log (usuario_id, accion, entidad, entidad_id, metadata)
    VALUES (auth.uid(), p_accion, p_entidad, p_entidad_id, p_metadata)
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;


ALTER FUNCTION "public"."log_activity"("p_accion" "text", "p_entidad" "text", "p_entidad_id" "uuid", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notificar_cobro_confirmado"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $_$
BEGIN
    -- Cuando ambos confirman, insertar notificación para el admin
    IF NEW.cobrador_confirmo = TRUE AND NEW.cliente_confirmo = TRUE 
       AND (OLD.cobrador_confirmo = FALSE OR OLD.cliente_confirmo = FALSE) THEN
        
        -- Actualizar estado a confirmado
        NEW.estado := 'confirmado';
        
        -- Insertar notificación (si existe la tabla)
        INSERT INTO notificaciones (
            usuario_id,
            titulo,
            mensaje,
            tipo,
            leida
        )
        SELECT 
            ur.usuario_id,
            'Cobro Confirmado',
            'Cobro de $' || NEW.monto || ' confirmado - ' || NEW.concepto,
            'cobro_confirmado',
            FALSE
        FROM usuarios_roles ur
        JOIN roles r ON r.id = ur.rol_id
        WHERE r.nombre IN ('superadmin', 'admin');
    END IF;
    
    RETURN NEW;
END;
$_$;


ALTER FUNCTION "public"."notificar_cobro_confirmado"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notificar_pago_vencido"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  v_usuario_id UUID;
  v_cliente_nombre TEXT;
BEGIN
  IF NEW.estado = 'vencido' AND OLD.estado != 'vencido' THEN
    -- Obtener el usuario del cliente del préstamo
    SELECT c.nombre INTO v_cliente_nombre
    FROM prestamos p
    JOIN clientes c ON c.id = p.cliente_id
    WHERE p.id = NEW.prestamo_id;
    
    -- Notificar a todos los admins/operadores
    INSERT INTO notificaciones (usuario_id, titulo, mensaje, tipo)
    SELECT u.id, 
           'Pago Vencido',
           'El cliente ' || v_cliente_nombre || ' tiene un pago vencido (Cuota #' || NEW.numero_cuota || ')',
           'warning'
    FROM usuarios u
    JOIN usuarios_roles ur ON ur.usuario_id = u.id
    JOIN roles r ON r.id = ur.rol_id
    WHERE r.nombre IN ('superadmin', 'admin', 'operador');
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notificar_pago_vencido"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_estadisticas_cached"("p_negocio_id" "uuid", "p_tipo" "text" DEFAULT 'cartera'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_cache JSONB;
    v_resultado JSONB;
BEGIN
    -- Buscar en caché
    SELECT datos INTO v_cache
    FROM cache_estadisticas
    WHERE negocio_id = p_negocio_id 
    AND tipo = p_tipo
    AND expira_at > NOW();
    
    IF v_cache IS NOT NULL THEN
        RETURN v_cache;
    END IF;
    
    -- Calcular y guardar en caché
    IF p_tipo = 'cartera' THEN
        SELECT jsonb_build_object(
            'total_prestamos', COUNT(DISTINCT p.id),
            'activos', COUNT(DISTINCT p.id) FILTER (WHERE p.estado = 'activo'),
            'mora', COUNT(DISTINCT p.id) FILTER (WHERE p.estado = 'mora'),
            'capital_vigente', COALESCE(SUM(DISTINCT CASE WHEN p.estado IN ('activo', 'mora') THEN p.monto ELSE 0 END), 0),
            'por_cobrar', COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'pendiente'), 0),
            'vencido', COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'vencido'), 0)
        ) INTO v_resultado
        FROM prestamos p
        LEFT JOIN amortizaciones a ON a.prestamo_id = p.id
        WHERE p.negocio_id = p_negocio_id;
    ELSIF p_tipo = 'kpis' THEN
        SELECT jsonb_build_object(
            'nuevos_mes', COUNT(*) FILTER (WHERE fecha_creacion >= DATE_TRUNC('month', NOW())),
            'monto_colocado_mes', COALESCE(SUM(monto) FILTER (WHERE fecha_creacion >= DATE_TRUNC('month', NOW())), 0),
            'tasa_recuperacion', ROUND(
                COALESCE(
                    (COUNT(*) FILTER (WHERE estado = 'pagado')::DECIMAL / NULLIF(COUNT(*), 0) * 100), 0
                ), 2
            )
        ) INTO v_resultado
        FROM prestamos
        WHERE negocio_id = p_negocio_id;
    ELSE
        v_resultado := '{}'::JSONB;
    END IF;
    
    -- Guardar en caché
    INSERT INTO cache_estadisticas (negocio_id, tipo, datos, calculado_at, expira_at)
    VALUES (p_negocio_id, p_tipo, v_resultado, NOW(), NOW() + INTERVAL '15 minutes')
    ON CONFLICT (negocio_id, tipo) 
    DO UPDATE SET datos = EXCLUDED.datos, calculado_at = NOW(), expira_at = NOW() + INTERVAL '15 minutes';
    
    RETURN v_resultado;
END;
$$;


ALTER FUNCTION "public"."obtener_estadisticas_cached"("p_negocio_id" "uuid", "p_tipo" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_estadisticas_facturacion"("p_negocio_id" "uuid") RETURNS TABLE("total_facturas" bigint, "facturas_mes" bigint, "total_facturado" numeric, "facturado_mes" numeric, "timbradas" bigint, "pendientes" bigint, "canceladas" bigint)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT AS total_facturas,
        COUNT(*) FILTER (WHERE DATE_TRUNC('month', f.fecha_emision) = DATE_TRUNC('month', NOW()))::BIGINT AS facturas_mes,
        COALESCE(SUM(f.total) FILTER (WHERE f.estado != 'cancelada'), 0)::DECIMAL AS total_facturado,
        COALESCE(SUM(f.total) FILTER (WHERE DATE_TRUNC('month', f.fecha_emision) = DATE_TRUNC('month', NOW()) AND f.estado != 'cancelada'), 0)::DECIMAL AS facturado_mes,
        COUNT(*) FILTER (WHERE f.estado = 'timbrada')::BIGINT AS timbradas,
        COUNT(*) FILTER (WHERE f.estado = 'borrador')::BIGINT AS pendientes,
        COUNT(*) FILTER (WHERE f.estado = 'cancelada')::BIGINT AS canceladas
    FROM facturas f
    WHERE f.negocio_id = p_negocio_id;
END;
$$;


ALTER FUNCTION "public"."obtener_estadisticas_facturacion"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_saldo_prestamo"("p_prestamo_id" "uuid") RETURNS numeric
    LANGUAGE "sql" STABLE
    AS $$
    SELECT COALESCE(SUM(monto_cuota), 0)
    FROM amortizaciones
    WHERE prestamo_id = p_prestamo_id
    AND estado IN ('pendiente', 'vencido');
$$;


ALTER FUNCTION "public"."obtener_saldo_prestamo"("p_prestamo_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_siguiente_cuota"("p_prestamo_id" "uuid") RETURNS TABLE("amortizacion_id" "uuid", "numero_cuota" integer, "monto_cuota" numeric, "fecha_vencimiento" "date", "dias_vencido" integer)
    LANGUAGE "sql" STABLE
    AS $$
    SELECT 
        id,
        numero_cuota,
        monto_cuota,
        fecha_vencimiento,
        GREATEST(0, CURRENT_DATE - fecha_vencimiento)::INTEGER
    FROM amortizaciones
    WHERE prestamo_id = p_prestamo_id
    AND estado IN ('pendiente', 'vencido')
    ORDER BY numero_cuota
    LIMIT 1;
$$;


ALTER FUNCTION "public"."obtener_siguiente_cuota"("p_prestamo_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."obtener_siguiente_folio"("p_emisor_id" "uuid", "p_tipo" character varying DEFAULT 'factura'::character varying) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_folio INTEGER;
BEGIN
    IF p_tipo = 'factura' THEN
        UPDATE facturacion_emisores 
        SET folio_actual_facturas = folio_actual_facturas + 1
        WHERE id = p_emisor_id
        RETURNING folio_actual_facturas INTO v_folio;
    ELSIF p_tipo = 'nota_credito' THEN
        UPDATE facturacion_emisores 
        SET folio_actual_nc = folio_actual_nc + 1
        WHERE id = p_emisor_id
        RETURNING folio_actual_nc INTO v_folio;
    ELSIF p_tipo = 'pago' THEN
        UPDATE facturacion_emisores 
        SET folio_actual_pagos = folio_actual_pagos + 1
        WHERE id = p_emisor_id
        RETURNING folio_actual_pagos INTO v_folio;
    END IF;
    
    RETURN v_folio;
END;
$$;


ALTER FUNCTION "public"."obtener_siguiente_folio"("p_emisor_id" "uuid", "p_tipo" character varying) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refrescar_vistas_materializadas"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_cartera;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_kpis_mes;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_clientes;
    REFRESH MATERIALIZED VIEW mv_cobranza_dia;
END;
$$;


ALTER FUNCTION "public"."refrescar_vistas_materializadas"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_vistas_materializadas"() RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_mensual_prestamos;
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_mensual_pagos;
END;
$$;


ALTER FUNCTION "public"."refresh_vistas_materializadas"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."registrar_actividad_colaborador"("p_colaborador_id" "uuid", "p_accion" "text", "p_descripcion" "text" DEFAULT NULL::"text", "p_ip" "text" DEFAULT NULL::"text") RETURNS "uuid"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  v_negocio_id UUID;
  v_actividad_id UUID;
BEGIN
  SELECT negocio_id INTO v_negocio_id FROM colaboradores WHERE id = p_colaborador_id;
  
  INSERT INTO colaborador_actividad (colaborador_id, negocio_id, accion, descripcion, ip_address)
  VALUES (p_colaborador_id, v_negocio_id, p_accion, p_descripcion, p_ip)
  RETURNING id INTO v_actividad_id;
  
  RETURN v_actividad_id;
END;
$$;


ALTER FUNCTION "public"."registrar_actividad_colaborador"("p_colaborador_id" "uuid", "p_accion" "text", "p_descripcion" "text", "p_ip" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resumen_cartera_negocio"("p_negocio_id" "uuid") RETURNS TABLE("total_prestamos" bigint, "prestamos_activos" bigint, "prestamos_mora" bigint, "capital_vigente" numeric, "por_cobrar" numeric, "vencido" numeric, "recuperacion_mes" numeric)
    LANGUAGE "sql" STABLE
    AS $$
    SELECT 
        COUNT(DISTINCT p.id),
        COUNT(DISTINCT p.id) FILTER (WHERE p.estado = 'activo'),
        COUNT(DISTINCT p.id) FILTER (WHERE p.estado = 'mora'),
        COALESCE(SUM(DISTINCT CASE WHEN p.estado IN ('activo', 'mora') THEN p.monto ELSE 0 END), 0),
        COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'pendiente'), 0),
        COALESCE(SUM(a.monto_cuota) FILTER (WHERE a.estado = 'vencido'), 0),
        COALESCE((
            SELECT SUM(monto) 
            FROM pagos 
            WHERE negocio_id = p_negocio_id 
            AND fecha_pago >= DATE_TRUNC('month', NOW())
        ), 0)
    FROM prestamos p
    LEFT JOIN amortizaciones a ON a.prestamo_id = p.id
    WHERE p.negocio_id = p_negocio_id;
$$;


ALTER FUNCTION "public"."resumen_cartera_negocio"("p_negocio_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_default_sucursal"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.sucursal_id IS NULL THEN
        NEW.sucursal_id := get_sucursal_principal();
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_default_sucursal"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."stripe_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") RETURNS numeric
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN COALESCE((
        SELECT SUM(monto)
        FROM pagos
        WHERE negocio_id = p_negocio_id
        AND metodo_pago IN ('tarjeta_stripe', 'link_pago', 'domiciliacion')
        AND fecha_pago BETWEEN p_fecha_inicio AND p_fecha_fin
    ), 0);
END;
$$;


ALTER FUNCTION "public"."stripe_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_nice_comision_entrega"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_comision NUMERIC;
BEGIN
    -- Solo cuando cambia a 'entregado'
    IF NEW.estado = 'entregado' AND OLD.estado != 'entregado' THEN
        -- Calcular comisión
        v_comision := calcular_comision_nice(NEW.vendedora_id, NEW.total);
        
        -- Insertar comisión
        INSERT INTO nice_comisiones (vendedora_id, pedido_id, tipo, monto, porcentaje, descripcion, estado)
        VALUES (NEW.vendedora_id, NEW.id, 'venta', v_comision, 
                (SELECT n.comision_ventas FROM nice_vendedoras v JOIN nice_niveles n ON n.id = v.nivel_id WHERE v.id = NEW.vendedora_id),
                'Comisión por pedido ' || NEW.folio, 'pendiente');
        
        -- Actualizar comisión del pedido
        NEW.comision_vendedora := v_comision;
        
        -- Actualizar ventas de la vendedora
        UPDATE nice_vendedoras
        SET ventas_totales = ventas_totales + NEW.total,
            ventas_mes = ventas_mes + NEW.total
        WHERE id = NEW.vendedora_id;
        
        -- Verificar si sube de nivel
        PERFORM actualizar_nivel_vendedora(NEW.vendedora_id);
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_nice_comision_entrega"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trigger_nice_pedido_folio"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    IF NEW.folio IS NULL OR NEW.folio = '' THEN
        NEW.folio := generar_folio_nice_pedido(NEW.negocio_id);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trigger_nice_pedido_folio"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_climas_solicitud_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_climas_solicitud_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_formulario_config_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_formulario_config_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_propiedad_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_propiedad_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_tarjeta_servicio_timestamp"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_tarjeta_servicio_timestamp"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_tarjetas_config_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_tarjetas_config_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."usuario_tiene_rol"("rol_nombre" "text") RETURNS boolean
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM usuarios_roles ur
    JOIN roles r ON r.id = ur.rol_id
    WHERE ur.usuario_id = auth.uid() AND r.nombre = rol_nombre
  );
END;
$$;


ALTER FUNCTION "public"."usuario_tiene_rol"("rol_nombre" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verificar_cobro_completo"("p_qr_id" "uuid") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_qr RECORD;
BEGIN
    SELECT * INTO v_qr FROM qr_cobros WHERE id = p_qr_id;
    
    IF v_qr IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Verificar que ambos confirmaron y actualizar estado
    IF v_qr.cobrador_confirmo AND v_qr.cliente_confirmo THEN
        UPDATE qr_cobros SET estado = 'confirmado', updated_at = NOW() WHERE id = p_qr_id;
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$;


ALTER FUNCTION "public"."verificar_cobro_completo"("p_qr_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."verificar_integridad_datos"() RETURNS TABLE("tabla" "text", "registros" bigint, "ultimo_registro" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE
    AS $$
BEGIN
    RETURN QUERY
    SELECT 'usuarios'::TEXT, COUNT(*)::BIGINT, MAX(created_at) FROM usuarios
    UNION ALL SELECT 'clientes', COUNT(*), MAX(created_at) FROM clientes
    UNION ALL SELECT 'prestamos', COUNT(*), MAX(created_at) FROM prestamos
    UNION ALL SELECT 'amortizaciones', COUNT(*), MAX(created_at) FROM amortizaciones
    UNION ALL SELECT 'pagos', COUNT(*), MAX(created_at) FROM pagos
    UNION ALL SELECT 'tandas', COUNT(*), MAX(created_at) FROM tandas
    UNION ALL SELECT 'avales', COUNT(*), MAX(created_at) FROM avales
    UNION ALL SELECT 'negocios', COUNT(*), MAX(created_at) FROM negocios
    ORDER BY 1;
END;
$$;


ALTER FUNCTION "public"."verificar_integridad_datos"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."activity_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid",
    "accion" "text" NOT NULL,
    "entidad" "text",
    "entidad_id" "uuid",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "ip_address" "inet",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."activity_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."activos_capital" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" character varying(200) NOT NULL,
    "descripcion" "text",
    "tipo" character varying(50) NOT NULL,
    "costo_adquisicion" numeric(12,2) DEFAULT 0 NOT NULL,
    "valor_actual" numeric(12,2),
    "fecha_adquisicion" "date",
    "ubicacion" character varying(200),
    "asignado_a" "uuid",
    "estado" character varying(20) DEFAULT 'activo'::character varying,
    "equipo_clima_id" "uuid",
    "propiedad_id" "uuid",
    "notas" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."activos_capital" OWNER TO "postgres";


COMMENT ON TABLE "public"."activos_capital" IS 'Registro de activos y equipos de la empresa';



CREATE TABLE IF NOT EXISTS "public"."acuses_recibo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "notificacion_id" "uuid",
    "expediente_id" "uuid",
    "tipo" "text" NOT NULL,
    "numero_guia" "text",
    "fecha_envio" "date",
    "fecha_recepcion" "date",
    "receptor_nombre" "text",
    "receptor_identificacion" "text",
    "foto_acuse_url" "text",
    "hash_acuse" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."acuses_recibo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."aires_equipos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid" NOT NULL,
    "sucursal_id" "uuid",
    "marca" "text" NOT NULL,
    "modelo" "text" NOT NULL,
    "tipo" "text",
    "capacidad_btu" integer,
    "costo" numeric(12,2),
    "precio_venta" numeric(12,2),
    "stock" integer DEFAULT 0,
    "stock_minimo" integer DEFAULT 2,
    "ubicacion" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."aires_equipos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."aires_garantias" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "orden_servicio_id" "uuid",
    "equipo_id" "uuid",
    "tipo" "text",
    "duracion_meses" integer DEFAULT 12,
    "fecha_inicio" "date",
    "fecha_fin" "date",
    "condiciones" "text",
    "activa" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."aires_garantias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."aires_ordenes_servicio" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid" NOT NULL,
    "folio" "text",
    "cliente_nombre" "text" NOT NULL,
    "cliente_telefono" "text" NOT NULL,
    "cliente_direccion" "text" NOT NULL,
    "tipo_servicio" "text" NOT NULL,
    "equipo_id" "uuid",
    "tecnico_id" "uuid",
    "descripcion" "text",
    "fecha_programada" timestamp without time zone,
    "fecha_completada" timestamp without time zone,
    "estado" "text" DEFAULT 'pendiente'::"text",
    "costo_mano_obra" numeric(12,2),
    "costo_materiales" numeric(12,2),
    "total" numeric(12,2),
    "notas" "text",
    "fotos_antes" "jsonb" DEFAULT '[]'::"jsonb",
    "fotos_despues" "jsonb" DEFAULT '[]'::"jsonb",
    "firma_cliente" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."aires_ordenes_servicio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."aires_tecnicos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "negocio_id" "uuid" NOT NULL,
    "especialidad" "text",
    "certificaciones" "text"[],
    "zona_cobertura" "text",
    "disponible" boolean DEFAULT true,
    "calificacion" numeric(3,2) DEFAULT 5.00,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."aires_tecnicos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."alertas_sistema" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "titulo" "text" NOT NULL,
    "mensaje" "text" NOT NULL,
    "tipo" "text" DEFAULT 'info'::"text",
    "prioridad" integer DEFAULT 1,
    "activa" boolean DEFAULT true,
    "usuario_destino_id" "uuid",
    "leida" boolean DEFAULT false,
    "enlace" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."alertas_sistema" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."amortizaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid",
    "numero_cuota" integer NOT NULL,
    "monto_cuota" numeric(12,2) NOT NULL,
    "monto_capital" numeric(12,2),
    "monto_interes" numeric(12,2),
    "saldo_restante" numeric(12,2),
    "fecha_vencimiento" "date" NOT NULL,
    "fecha_pago" "date",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."amortizaciones" OWNER TO "postgres";


COMMENT ON COLUMN "public"."amortizaciones"."estado" IS 'pendiente, pagado, pagada, vencido, parcial';



CREATE TABLE IF NOT EXISTS "public"."aportaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "colaborador_id" "uuid" NOT NULL,
    "monto" numeric(15,2) NOT NULL,
    "concepto" "text" DEFAULT 'Aportación de capital'::"text",
    "fecha_aportacion" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tipo" "text" DEFAULT 'efectivo'::"text",
    "referencia" "text",
    "comprobante_url" "text",
    "notas" "text",
    "registrado_por" "uuid",
    "negocio_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "aportaciones_monto_check" CHECK (("monto" > (0)::numeric)),
    CONSTRAINT "aportaciones_tipo_check" CHECK (("tipo" = ANY (ARRAY['efectivo'::"text", 'transferencia'::"text", 'cheque'::"text", 'especie'::"text", 'otro'::"text"])))
);


ALTER TABLE "public"."aportaciones" OWNER TO "postgres";


COMMENT ON TABLE "public"."aportaciones" IS 'Registro de aportaciones de capital de inversionistas, socios y familiares';



COMMENT ON COLUMN "public"."aportaciones"."colaborador_id" IS 'FK al colaborador que realiza la aportación';



COMMENT ON COLUMN "public"."aportaciones"."monto" IS 'Monto de la aportación en pesos mexicanos';



COMMENT ON COLUMN "public"."aportaciones"."tipo" IS 'Método de aportación: efectivo, transferencia, cheque, especie, otro';



CREATE TABLE IF NOT EXISTS "public"."auditoria" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid",
    "accion" "text" NOT NULL,
    "modulo" "text",
    "detalles" "jsonb",
    "ip_address" "text",
    "fecha" timestamp without time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."auditoria" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."auditoria_acceso" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid",
    "rol_id" "uuid",
    "accion" "text" NOT NULL,
    "entidad" "text" NOT NULL,
    "entidad_id" "text",
    "ip" "text",
    "latitud" double precision,
    "longitud" double precision,
    "dispositivo" "text",
    "hash_contenido" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."auditoria_acceso" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."auditoria_accesos" AS
 SELECT "id",
    "usuario_id",
    "rol_id",
    "accion",
    "entidad",
    "entidad_id",
    "ip",
    "latitud",
    "longitud",
    "dispositivo",
    "hash_contenido",
    "created_at"
   FROM "public"."auditoria_acceso";


ALTER VIEW "public"."auditoria_accesos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."auditoria_legal" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid",
    "cliente_id" "uuid",
    "tipo_evento" "text" NOT NULL,
    "descripcion" "text",
    "documento_url" "text",
    "hash_documento" "text",
    "ip_usuario" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."auditoria_legal" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."aval_checkins" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "latitud" numeric(10,8) NOT NULL,
    "longitud" numeric(11,8) NOT NULL,
    "precision" numeric(10,2),
    "fecha" timestamp without time zone DEFAULT "now"(),
    "tipo" "text" DEFAULT 'voluntario'::"text",
    "direccion_aproximada" "text",
    "ip_dispositivo" "text",
    "dispositivo" "text",
    "notas" "text",
    "verificado_por" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."aval_checkins" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."avales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "prestamo_id" "uuid",
    "tanda_id" "uuid",
    "cliente_id" "uuid",
    "usuario_id" "uuid",
    "nombre" "text" NOT NULL,
    "email" "text",
    "telefono" "text",
    "direccion" "text",
    "identificacion" "text",
    "relacion" "text",
    "verificado" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "ubicacion_consentida" boolean DEFAULT false,
    "fecha_consentimiento_ubicacion" timestamp without time zone,
    "ultima_latitud" numeric(10,8),
    "ultima_longitud" numeric(11,8),
    "ultimo_checkin" timestamp without time zone,
    "firma_digital_url" "text",
    "fecha_firma" timestamp without time zone,
    "ine_url" "text",
    "ine_reverso_url" "text",
    "domicilio_url" "text",
    "selfie_url" "text",
    "ingresos_url" "text",
    "fcm_token" "text",
    "activo" boolean DEFAULT true
);


ALTER TABLE "public"."avales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cache_estadisticas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "tipo" "text" NOT NULL,
    "datos" "jsonb" NOT NULL,
    "calculado_at" timestamp with time zone DEFAULT "now"(),
    "expira_at" timestamp with time zone DEFAULT ("now"() + '00:15:00'::interval),
    "expira_en" timestamp with time zone DEFAULT ("now"() + '01:00:00'::interval)
);


ALTER TABLE "public"."cache_estadisticas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."calendario" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "titulo" "text" NOT NULL,
    "descripcion" "text",
    "fecha" timestamp without time zone NOT NULL,
    "fecha_fin" timestamp without time zone,
    "tipo" "text",
    "usuario_id" "uuid",
    "cliente_id" "uuid",
    "prestamo_id" "uuid",
    "completado" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."calendario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."campos_formulario_catalogo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "codigo" character varying(50) NOT NULL,
    "modulo" character varying(50) NOT NULL,
    "tipo" character varying(30) NOT NULL,
    "label" character varying(100) NOT NULL,
    "placeholder" "text",
    "hint" "text",
    "opciones" "jsonb" DEFAULT '[]'::"jsonb",
    "requerido_default" boolean DEFAULT false,
    "min_length" integer,
    "max_length" integer,
    "patron_regex" "text",
    "orden_sugerido" integer DEFAULT 99,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "campos_formulario_catalogo_tipo_check" CHECK ((("tipo")::"text" = ANY ((ARRAY['text'::character varying, 'email'::character varying, 'tel'::character varying, 'number'::character varying, 'textarea'::character varying, 'select'::character varying, 'radio'::character varying, 'checkbox'::character varying, 'date'::character varying, 'time'::character varying, 'file'::character varying, 'photo'::character varying, 'location'::character varying, 'signature'::character varying])::"text"[])))
);


ALTER TABLE "public"."campos_formulario_catalogo" OWNER TO "postgres";


COMMENT ON TABLE "public"."campos_formulario_catalogo" IS 'Catálogo de campos predefinidos para formularios';



CREATE TABLE IF NOT EXISTS "public"."cat_forma_pago" (
    "clave" character varying(2) NOT NULL,
    "descripcion" character varying(200) NOT NULL,
    "activo" boolean DEFAULT true
);


ALTER TABLE "public"."cat_forma_pago" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cat_regimen_fiscal" (
    "clave" character varying(3) NOT NULL,
    "descripcion" character varying(200) NOT NULL,
    "fisica" boolean DEFAULT false,
    "moral" boolean DEFAULT false,
    "activo" boolean DEFAULT true
);


ALTER TABLE "public"."cat_regimen_fiscal" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."cat_uso_cfdi" (
    "clave" character varying(4) NOT NULL,
    "descripcion" character varying(200) NOT NULL,
    "fisica" boolean DEFAULT true,
    "moral" boolean DEFAULT true,
    "activo" boolean DEFAULT true
);


ALTER TABLE "public"."cat_uso_cfdi" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."catalogo_forma_pago" AS
 SELECT "clave",
    "descripcion",
    "activo"
   FROM "public"."cat_forma_pago";


ALTER VIEW "public"."catalogo_forma_pago" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."catalogo_regimen_fiscal" AS
 SELECT "clave",
    "descripcion",
    "fisica",
    "moral",
    "activo"
   FROM "public"."cat_regimen_fiscal";


ALTER VIEW "public"."catalogo_regimen_fiscal" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."catalogo_uso_cfdi" AS
 SELECT "clave",
    "descripcion",
    "fisica",
    "moral",
    "activo"
   FROM "public"."cat_uso_cfdi";


ALTER VIEW "public"."catalogo_uso_cfdi" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chat_aval_cobrador" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "prestamo_id" "uuid",
    "admin_id" "uuid",
    "estado" "text" DEFAULT 'activo'::"text",
    "ultimo_mensaje" timestamp without time zone DEFAULT "now"(),
    "mensajes_no_leidos_aval" integer DEFAULT 0,
    "mensajes_no_leidos_admin" integer DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."chat_aval_cobrador" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chat_conversaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tipo_conversacion" "text" NOT NULL,
    "cliente_id" "uuid",
    "aval_id" "uuid",
    "prestamo_id" "uuid",
    "tanda_id" "uuid",
    "creado_por_usuario_id" "uuid",
    "estado" "text" DEFAULT 'activo'::"text",
    "ultimo_mensaje" "text",
    "fecha_ultimo_mensaje" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."chat_conversaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chat_mensajes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversacion_id" "uuid",
    "remitente_usuario_id" "uuid",
    "tipo_mensaje" "text" DEFAULT 'texto'::"text",
    "contenido_texto" "text",
    "archivo_url" "text",
    "latitud" double precision,
    "longitud" double precision,
    "hash_contenido" "text",
    "es_sistema" boolean DEFAULT false,
    "leido" boolean DEFAULT false,
    "fecha_lectura" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."chat_mensajes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chat_participantes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversacion_id" "uuid",
    "usuario_id" "uuid",
    "rol_chat" "text" DEFAULT 'participante'::"text",
    "silenciado" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."chat_participantes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."chats" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario1" "uuid",
    "usuario2" "uuid",
    "ultimo_mensaje" "text",
    "fecha_ultimo_mensaje" timestamp without time zone DEFAULT "now"(),
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."chats" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid",
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "telefono" "text",
    "direccion" "text",
    "email" "text",
    "curp" "text",
    "rfc" "text",
    "fecha_nacimiento" "date",
    "ocupacion" "text",
    "ingresos_mensuales" numeric(12,2),
    "sucursal_id" "uuid",
    "foto_url" "text",
    "activo" boolean DEFAULT true,
    "score_crediticio" integer DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "stripe_customer_id" "text",
    "prefiere_efectivo" boolean DEFAULT true,
    "tiene_tarjeta_guardada" boolean DEFAULT false,
    "apellidos" "text",
    "ciudad" "text",
    "estado" "text",
    "codigo_postal" "text",
    "ine_url" "text",
    "comprobante_domicilio_url" "text",
    "latitud" numeric(10,8),
    "longitud" numeric(11,8),
    "notas" "text",
    "ref_nombre_1" "text",
    "ref_telefono_1" "text",
    "ref_relacion_1" "text",
    "ref_nombre_2" "text",
    "ref_telefono_2" "text",
    "ref_relacion_2" "text",
    "empresa" "text",
    "antiguedad_laboral" "text",
    "clave_elector" "text"
);


ALTER TABLE "public"."clientes" OWNER TO "postgres";


COMMENT ON COLUMN "public"."clientes"."stripe_customer_id" IS 'ID del cliente en Stripe (cus_xxx)';



COMMENT ON COLUMN "public"."clientes"."prefiere_efectivo" IS 'TRUE = prefiere efectivo, FALSE = prefiere tarjeta';



CREATE TABLE IF NOT EXISTS "public"."clientes_bloqueados_mora" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "motivo" "text" NOT NULL,
    "dias_mora_maximo" integer NOT NULL,
    "monto_total_adeudado" numeric(12,2) NOT NULL,
    "prestamos_en_mora" "jsonb",
    "tandas_en_mora" "jsonb",
    "activo" boolean DEFAULT true,
    "fecha_desbloqueo" timestamp without time zone,
    "desbloqueado_por" "uuid",
    "motivo_desbloqueo" "text",
    "bloqueado_por" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."clientes_bloqueados_mora" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."clientes_modulo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "auth_uid" "uuid",
    "modulo" "text" NOT NULL,
    "codigo_cliente" "text",
    "saldo_pendiente" numeric(14,2) DEFAULT 0,
    "puntos_acumulados" integer DEFAULT 0,
    "nivel_cliente" "text" DEFAULT 'nuevo'::"text",
    "preferencias" "jsonb" DEFAULT '{}'::"jsonb",
    "historial_interacciones" integer DEFAULT 0,
    "ultima_interaccion" timestamp with time zone,
    "puede_pedir_credito" boolean DEFAULT false,
    "limite_credito" numeric(14,2) DEFAULT 0,
    "notificaciones_activas" boolean DEFAULT true,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."clientes_modulo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_calendario" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "orden_id" "uuid",
    "tecnico_id" "uuid",
    "fecha" "date" NOT NULL,
    "hora_inicio" time without time zone NOT NULL,
    "hora_fin" time without time zone,
    "duracion_estimada" integer DEFAULT 60,
    "confirmado" boolean DEFAULT false,
    "recordatorio_enviado" boolean DEFAULT false,
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_calendario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_catalogo_servicios_publico" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "codigo" "text",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "icono" "text",
    "precio_desde" numeric(12,2),
    "precio_hasta" numeric(12,2),
    "mostrar_precio" boolean DEFAULT true,
    "tiempo_estimado" "text",
    "categoria" "text" DEFAULT 'general'::"text",
    "en_promocion" boolean DEFAULT false,
    "precio_promocion" numeric(12,2),
    "texto_promocion" "text",
    "orden" integer DEFAULT 0,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_catalogo_servicios_publico" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_certificaciones_tecnico" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tecnico_id" "uuid",
    "nombre" "text" NOT NULL,
    "institucion" "text",
    "fecha_obtencion" "date",
    "fecha_vencimiento" "date",
    "documento_url" "text",
    "estado" "text" DEFAULT 'vigente'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_certificaciones_tecnico" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_chat_solicitud" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "solicitud_id" "uuid" NOT NULL,
    "es_cliente" boolean NOT NULL,
    "remitente_id" "uuid",
    "remitente_nombre" "text" NOT NULL,
    "mensaje" "text" NOT NULL,
    "tipo_mensaje" "text" DEFAULT 'texto'::"text",
    "adjunto_url" "text",
    "adjunto_nombre" "text",
    "leido" boolean DEFAULT false,
    "fecha_leido" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_chat_solicitud" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_checklist_respuestas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "orden_id" "uuid",
    "checklist_id" "uuid",
    "tecnico_id" "uuid",
    "respuestas" "jsonb" NOT NULL,
    "completado" boolean DEFAULT false,
    "fecha_completado" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_checklist_respuestas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_checklist_servicio" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "tipo_servicio" "text",
    "items" "jsonb" NOT NULL,
    "obligatorio" boolean DEFAULT true,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_checklist_servicio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_cliente_contactos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "nombre" "text" NOT NULL,
    "telefono" "text",
    "email" "text",
    "relacion" "text",
    "es_principal" boolean DEFAULT false,
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_cliente_contactos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_cliente_documentos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "tipo" character varying(50) NOT NULL,
    "nombre" "text",
    "url" "text" NOT NULL,
    "fecha_documento" "date",
    "notas" "text",
    "subido_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_cliente_documentos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_cliente_notas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "usuario_id" "uuid",
    "nota" "text" NOT NULL,
    "tipo" character varying(30) DEFAULT 'general'::character varying,
    "importante" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_cliente_notas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_clientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "auth_uid" "uuid",
    "codigo_cliente" "text",
    "nombre" "text" NOT NULL,
    "email" "text",
    "telefono" "text",
    "whatsapp" "text",
    "direccion" "text",
    "ciudad" "text",
    "codigo_postal" "text",
    "tipo" "text" DEFAULT 'residencial'::"text",
    "total_servicios" integer DEFAULT 0,
    "total_gastado" numeric(14,2) DEFAULT 0,
    "saldo_pendiente" numeric(14,2) DEFAULT 0,
    "notas" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "colonia" "text",
    "referencia" "text",
    "rfc" "text",
    "latitud" numeric(10,8),
    "longitud" numeric(11,8)
);


ALTER TABLE "public"."climas_clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_comisiones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "tecnico_id" "uuid",
    "orden_id" "uuid",
    "periodo" "text",
    "tipo" "text" DEFAULT 'servicio'::"text",
    "base_calculo" numeric(14,2) DEFAULT 0,
    "porcentaje" numeric(5,2) DEFAULT 0,
    "monto" numeric(14,2) DEFAULT 0,
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_pago" "date",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_comisiones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_comprobantes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "orden_id" "uuid",
    "tipo" "text" DEFAULT 'factura'::"text",
    "folio" "text" NOT NULL,
    "fecha" "date" DEFAULT CURRENT_DATE,
    "subtotal" numeric(14,2) DEFAULT 0,
    "iva" numeric(14,2) DEFAULT 0,
    "total" numeric(14,2) DEFAULT 0,
    "pagado" boolean DEFAULT false,
    "fecha_pago" "date",
    "metodo_pago" "text",
    "documento_url" "text",
    "xml_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_comprobantes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_config_formulario_qr" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "logo_url" "text",
    "color_primario" "text" DEFAULT '#00D9FF'::"text",
    "color_secundario" "text" DEFAULT '#8B5CF6'::"text",
    "mensaje_bienvenida" "text" DEFAULT '¡Bienvenido! Complete el formulario para recibir atención personalizada.'::"text",
    "campo_email_requerido" boolean DEFAULT false,
    "campo_direccion_requerido" boolean DEFAULT true,
    "campo_fotos_habilitado" boolean DEFAULT true,
    "max_fotos" integer DEFAULT 5,
    "servicios_habilitados" "jsonb" DEFAULT '["cotizacion", "instalacion", "mantenimiento", "reparacion"]'::"jsonb",
    "notificar_email" "text",
    "notificar_whatsapp" "text",
    "notificar_push" boolean DEFAULT true,
    "aviso_privacidad_url" "text",
    "terminos_condiciones_url" "text",
    "formulario_activo" boolean DEFAULT true,
    "mensaje_formulario_inactivo" "text" DEFAULT 'Lo sentimos, no estamos recibiendo solicitudes en este momento.'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_config_formulario_qr" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_configuracion" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "config_key" "text" NOT NULL,
    "config_value" "jsonb",
    "descripcion" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_configuracion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_cotizaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "numero" "text",
    "fecha" "date" DEFAULT CURRENT_DATE,
    "vigencia_dias" integer DEFAULT 30,
    "subtotal" numeric(12,2) DEFAULT 0,
    "iva" numeric(12,2) DEFAULT 0,
    "total" numeric(12,2) DEFAULT 0,
    "estado" character varying(20) DEFAULT 'pendiente'::character varying,
    "notas" "text",
    "productos" "jsonb" DEFAULT '[]'::"jsonb",
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_cotizaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_cotizaciones_v2" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "folio" "text",
    "fecha" "date" DEFAULT CURRENT_DATE,
    "vigencia_dias" integer DEFAULT 15,
    "items" "jsonb" NOT NULL,
    "subtotal" numeric(14,2) DEFAULT 0,
    "descuento" numeric(14,2) DEFAULT 0,
    "iva" numeric(14,2) DEFAULT 0,
    "total" numeric(14,2) DEFAULT 0,
    "notas" "text",
    "estado" "text" DEFAULT 'enviada'::"text",
    "fecha_respuesta" "date",
    "orden_generada_id" "uuid",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_cotizaciones_v2" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_equipos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "marca" "text",
    "modelo" "text",
    "tipo" "text",
    "capacidad" "text",
    "numero_serie" "text",
    "ubicacion" "text",
    "fecha_instalacion" "date",
    "fecha_garantia_fin" "date",
    "ultimo_servicio" "date",
    "proximo_servicio" "date",
    "estado" "text" DEFAULT 'activo'::"text",
    "foto_url" "text",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_equipos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_equipos_cliente" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "equipo_id" "uuid",
    "ubicacion" "text",
    "fecha_instalacion" "date",
    "garantia_hasta" "date",
    "ultimo_servicio" "date",
    "proximo_servicio" "date",
    "notas" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_equipos_cliente" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_garantias" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "equipo_id" "uuid",
    "orden_instalacion_id" "uuid",
    "numero_garantia" "text",
    "tipo_garantia" "text",
    "fecha_inicio" "date" NOT NULL,
    "fecha_fin" "date" NOT NULL,
    "cobertura" "text",
    "documento_url" "text",
    "activa" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_garantias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_incidencias" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "orden_id" "uuid",
    "tecnico_id" "uuid",
    "cliente_id" "uuid",
    "tipo" "text" NOT NULL,
    "descripcion" "text" NOT NULL,
    "fotos" "jsonb" DEFAULT '[]'::"jsonb",
    "gravedad" "text" DEFAULT 'media'::"text",
    "estado" "text" DEFAULT 'abierta'::"text",
    "resolucion" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_incidencias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_inventario_tecnico" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tecnico_id" "uuid",
    "producto_id" "uuid",
    "cantidad" integer DEFAULT 0,
    "cantidad_minima" integer DEFAULT 1,
    "ultima_recarga" "date",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_inventario_tecnico" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_mensajes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "orden_id" "uuid",
    "remitente" "text" NOT NULL,
    "remitente_nombre" "text",
    "mensaje" "text" NOT NULL,
    "tipo" "text" DEFAULT 'texto'::"text",
    "adjunto_url" "text",
    "leido" boolean DEFAULT false,
    "fecha_leido" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_mensajes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_metricas_tecnico" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tecnico_id" "uuid",
    "periodo" "text" NOT NULL,
    "ordenes_completadas" integer DEFAULT 0,
    "ordenes_canceladas" integer DEFAULT 0,
    "tiempo_promedio_servicio" integer DEFAULT 0,
    "calificacion_promedio" numeric(3,2) DEFAULT 0,
    "ingresos_generados" numeric(14,2) DEFAULT 0,
    "comision_generada" numeric(14,2) DEFAULT 0,
    "incidencias_reportadas" integer DEFAULT 0,
    "puntualidad_porcentaje" numeric(5,2) DEFAULT 100,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_metricas_tecnico" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_movimientos_inventario" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "producto_id" "uuid",
    "tipo" "text" NOT NULL,
    "cantidad" integer NOT NULL,
    "stock_anterior" integer,
    "stock_nuevo" integer,
    "orden_id" "uuid",
    "tecnico_id" "uuid",
    "motivo" "text",
    "documento_referencia" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_movimientos_inventario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_ordenes_servicio" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "equipo_id" "uuid",
    "tecnico_id" "uuid",
    "folio" "text",
    "tipo_servicio" "text" DEFAULT 'mantenimiento'::"text",
    "prioridad" "text" DEFAULT 'normal'::"text",
    "fecha_solicitud" timestamp with time zone DEFAULT "now"(),
    "fecha_programada" timestamp with time zone,
    "fecha_inicio" timestamp with time zone,
    "fecha_fin" timestamp with time zone,
    "direccion_servicio" "text",
    "descripcion_problema" "text",
    "diagnostico" "text",
    "trabajo_realizado" "text",
    "materiales_usados" "jsonb" DEFAULT '[]'::"jsonb",
    "costo_materiales" numeric(14,2) DEFAULT 0,
    "costo_mano_obra" numeric(14,2) DEFAULT 0,
    "total" numeric(14,2) DEFAULT 0,
    "metodo_pago" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "calificacion" integer,
    "comentario_cliente" "text",
    "fotos_antes" "jsonb" DEFAULT '[]'::"jsonb",
    "fotos_despues" "jsonb" DEFAULT '[]'::"jsonb",
    "firma_cliente_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "numero_orden" "text",
    "hora_programada" time without time zone,
    "firma_cliente" "text",
    "foto_antes" "text",
    "foto_despues" "text"
);


ALTER TABLE "public"."climas_ordenes_servicio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_pagos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "orden_servicio_id" "uuid",
    "monto" numeric(12,2) NOT NULL,
    "metodo_pago" "text" DEFAULT 'efectivo'::"text",
    "referencia" "text",
    "comprobante_url" "text",
    "fecha_pago" timestamp with time zone DEFAULT "now"(),
    "estado" "text" DEFAULT 'completado'::"text",
    "registrado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_pagos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_precios_servicio" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "tipo_servicio" "text",
    "descripcion" "text",
    "incluye" "text"[],
    "precio_base" numeric(14,2) DEFAULT 0,
    "tiempo_estimado" integer DEFAULT 60,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_precios_servicio" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_productos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "marca" "text",
    "modelo" "text",
    "tipo" character varying(50) DEFAULT 'split'::character varying,
    "capacidad_btu" integer,
    "precio_venta" numeric(10,2) DEFAULT 0,
    "precio_instalacion" numeric(10,2) DEFAULT 0,
    "garantia_meses" integer DEFAULT 12,
    "descripcion" "text",
    "imagen_url" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "codigo" "text",
    "costo" numeric(10,2) DEFAULT 0,
    "stock" integer DEFAULT 0,
    "stock_minimo" integer DEFAULT 5,
    "categoria" "text",
    "subcategoria" "text",
    "ubicacion_almacen" "text",
    "proveedor_principal" "text"
);


ALTER TABLE "public"."climas_productos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_recordatorios_mantenimiento" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "equipo_id" "uuid",
    "fecha_programada" "date" NOT NULL,
    "tipo" "text" DEFAULT 'mantenimiento_preventivo'::"text",
    "descripcion" "text",
    "notificado" boolean DEFAULT false,
    "fecha_notificacion" timestamp with time zone,
    "aceptado" boolean,
    "orden_generada_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_recordatorios_mantenimiento" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_registro_tiempo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "orden_id" "uuid",
    "tecnico_id" "uuid",
    "tipo" "text" NOT NULL,
    "ubicacion_lat" numeric(10,8),
    "ubicacion_lng" numeric(11,8),
    "foto_evidencia" "text",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_registro_tiempo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_solicitud_historial" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "solicitud_id" "uuid" NOT NULL,
    "estado_anterior" "text",
    "estado_nuevo" "text" NOT NULL,
    "comentario" "text",
    "usuario_id" "uuid",
    "usuario_nombre" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_solicitud_historial" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_solicitudes_cliente" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "equipo_id" "uuid",
    "tipo_solicitud" "text" DEFAULT 'mantenimiento'::"text",
    "urgencia" "text" DEFAULT 'normal'::"text",
    "descripcion" "text" NOT NULL,
    "fotos" "jsonb" DEFAULT '[]'::"jsonb",
    "disponibilidad_fecha" "date",
    "disponibilidad_horario" "text",
    "estado" "text" DEFAULT 'nueva'::"text",
    "orden_id" "uuid",
    "respuesta_negocio" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_solicitudes_cliente" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_solicitudes_qr" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre_completo" "text" NOT NULL,
    "telefono" "text" NOT NULL,
    "email" "text",
    "direccion" "text" NOT NULL,
    "colonia" "text",
    "ciudad" "text",
    "codigo_postal" "text",
    "referencia_ubicacion" "text",
    "latitud" numeric(10,8),
    "longitud" numeric(11,8),
    "tipo_servicio" "text" DEFAULT 'cotizacion'::"text" NOT NULL,
    "tiene_equipo_actual" boolean DEFAULT false,
    "marca_equipo_actual" "text",
    "modelo_equipo_actual" "text",
    "capacidad_btu_actual" integer,
    "antiguedad_equipo" "text",
    "problema_reportado" "text",
    "tipo_espacio" "text",
    "metros_cuadrados" numeric(8,2),
    "cantidad_equipos_deseados" integer DEFAULT 1,
    "presupuesto_estimado" "text",
    "horario_contacto_preferido" "text",
    "medio_contacto_preferido" "text" DEFAULT 'telefono'::"text",
    "disponibilidad_visita" "text",
    "fotos" "jsonb" DEFAULT '[]'::"jsonb",
    "notas_cliente" "text",
    "estado" "text" DEFAULT 'nueva'::"text",
    "revisado_por" "uuid",
    "fecha_revision" timestamp with time zone,
    "notas_internas" "text",
    "motivo_rechazo" "text",
    "cliente_creado_id" "uuid",
    "orden_creada_id" "uuid",
    "fecha_conversion" timestamp with time zone,
    "token_seguimiento" "text" DEFAULT "replace"(("gen_random_uuid"())::"text", '-'::"text", ''::"text"),
    "ip_origen" "text",
    "user_agent" "text",
    "fuente" "text" DEFAULT 'qr_tarjeta'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_solicitudes_qr" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_solicitudes_refacciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "tecnico_id" "uuid",
    "orden_id" "uuid",
    "items" "jsonb" NOT NULL,
    "estado" "text" DEFAULT 'pendiente'::"text",
    "notas" "text",
    "respuesta_admin" "text",
    "fecha_aprobacion" timestamp with time zone,
    "fecha_entrega" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_solicitudes_refacciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_tecnico_zonas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tecnico_id" "uuid",
    "zona_id" "uuid",
    "es_principal" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_tecnico_zonas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_tecnicos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "empleado_id" "uuid",
    "auth_uid" "uuid",
    "codigo" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "apellidos" "text",
    "telefono" "text",
    "email" "text",
    "especialidades" "text"[] DEFAULT '{}'::"text"[],
    "certificaciones" "text"[] DEFAULT '{}'::"text"[],
    "vehiculo_asignado" "text",
    "zona_cobertura" "text"[] DEFAULT '{}'::"text"[],
    "calificacion_promedio" numeric(3,2) DEFAULT 5.0,
    "total_servicios" integer DEFAULT 0,
    "servicios_mes" integer DEFAULT 0,
    "comision_servicio" numeric(5,2) DEFAULT 10,
    "disponible" boolean DEFAULT true,
    "en_servicio" boolean DEFAULT false,
    "ubicacion_actual" "jsonb",
    "foto_url" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "especialidad" "text",
    "nivel" "text" DEFAULT 'junior'::"text",
    "salario_base" numeric(12,2) DEFAULT 0
);


ALTER TABLE "public"."climas_tecnicos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."climas_zonas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "colonias" "text"[],
    "codigos_postales" "text"[],
    "poligono" "jsonb",
    "color" "text" DEFAULT '#00D9FF'::"text",
    "activa" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."climas_zonas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaborador_actividad" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "colaborador_id" "uuid",
    "negocio_id" "uuid",
    "accion" "text" NOT NULL,
    "descripcion" "text",
    "ip_address" "text",
    "dispositivo" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "tipo_accion" "text",
    "modulo" "text",
    "detalles" "jsonb" DEFAULT '{}'::"jsonb"
);


ALTER TABLE "public"."colaborador_actividad" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaborador_compensaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "colaborador_id" "uuid",
    "tipo_compensacion_id" "uuid",
    "periodo_inicio" "date" NOT NULL,
    "periodo_fin" "date" NOT NULL,
    "monto_base" numeric(14,2) DEFAULT 0,
    "porcentaje_aplicado" numeric(5,2),
    "monto_calculado" numeric(14,2) NOT NULL,
    "estado" "text" DEFAULT 'pendiente'::"text",
    "aprobado_por" "uuid",
    "fecha_aprobacion" timestamp with time zone,
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."colaborador_compensaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaborador_inversiones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "colaborador_id" "uuid",
    "negocio_id" "uuid",
    "tipo" "text" NOT NULL,
    "monto" numeric(14,2) NOT NULL,
    "descripcion" "text",
    "fecha" "date" DEFAULT CURRENT_DATE,
    "comprobante_url" "text",
    "aprobado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "referencia_bancaria" "text"
);


ALTER TABLE "public"."colaborador_inversiones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaborador_invitaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "tipo_id" "uuid",
    "email" "text" NOT NULL,
    "nombre" "text",
    "telefono" "text",
    "codigo_invitacion" "text" DEFAULT "upper"(SUBSTRING("md5"(("random"())::"text") FROM 1 FOR 8)),
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_envio" timestamp with time zone DEFAULT "now"(),
    "fecha_expiracion" timestamp with time zone DEFAULT ("now"() + '7 days'::interval),
    "fecha_respuesta" timestamp with time zone,
    "invitado_por" "uuid",
    "colaborador_creado_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "mensaje_personal" "text",
    "veces_enviada" integer DEFAULT 1
);


ALTER TABLE "public"."colaborador_invitaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaborador_pagos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "colaborador_id" "uuid",
    "compensacion_id" "uuid",
    "monto" numeric(14,2) NOT NULL,
    "metodo_pago" "text" DEFAULT 'transferencia'::"text",
    "referencia_bancaria" "text",
    "comprobante_url" "text",
    "fecha_pago" "date" NOT NULL,
    "estado" "text" DEFAULT 'completado'::"text",
    "notas" "text",
    "registrado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."colaborador_pagos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaborador_permisos_modulo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "colaborador_id" "uuid",
    "modulo" character varying(50) NOT NULL,
    "puede_ver" boolean DEFAULT true,
    "puede_crear" boolean DEFAULT false,
    "puede_editar" boolean DEFAULT false,
    "puede_eliminar" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "puede_exportar" boolean DEFAULT false,
    "solo_propios" boolean DEFAULT true
);


ALTER TABLE "public"."colaborador_permisos_modulo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaborador_rendimientos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inversion_id" "uuid",
    "colaborador_id" "uuid",
    "monto" numeric(12,2) DEFAULT 0 NOT NULL,
    "porcentaje" numeric(5,2) DEFAULT 0,
    "periodo" "text",
    "fecha_calculo" timestamp with time zone DEFAULT "now"(),
    "fecha_pago" timestamp with time zone,
    "estado" character varying(20) DEFAULT 'pendiente'::character varying,
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "periodo_inicio" "date",
    "periodo_fin" "date",
    "monto_base" numeric(14,2),
    "tasa_aplicada" numeric(5,2)
);


ALTER TABLE "public"."colaborador_rendimientos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaborador_tipos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "codigo" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "nivel_acceso" integer DEFAULT 1,
    "puede_ver_finanzas" boolean DEFAULT false,
    "puede_ver_clientes" boolean DEFAULT false,
    "puede_ver_prestamos" boolean DEFAULT false,
    "puede_operar" boolean DEFAULT false,
    "puede_aprobar" boolean DEFAULT false,
    "puede_emitir_facturas" boolean DEFAULT false,
    "puede_ver_reportes" boolean DEFAULT false,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."colaborador_tipos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."colaboradores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "usuario_id" "uuid",
    "auth_uid" "uuid",
    "tipo_id" "uuid",
    "nombre" "text" NOT NULL,
    "email" "text",
    "telefono" "text",
    "tiene_cuenta" boolean DEFAULT false,
    "permisos_custom" "jsonb" DEFAULT '{}'::"jsonb",
    "es_inversionista" boolean DEFAULT false,
    "monto_invertido" numeric(14,2) DEFAULT 0,
    "porcentaje_participacion" numeric(5,2) DEFAULT 0,
    "fecha_inversion" "date",
    "rendimiento_pactado" numeric(5,2),
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_inicio" "date" DEFAULT CURRENT_DATE,
    "fecha_fin" "date",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."colaboradores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comisiones_empleados" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "empleado_id" "uuid",
    "prestamo_id" "uuid",
    "monto_prestamo" numeric(12,2) NOT NULL,
    "ganancia_prestamo" numeric(12,2) NOT NULL,
    "porcentaje_comision" numeric(5,2) NOT NULL,
    "monto_comision" numeric(12,2) NOT NULL,
    "tipo_pago" "text" NOT NULL,
    "estado" "text" DEFAULT 'pendiente'::"text",
    "monto_pagado" numeric(12,2) DEFAULT 0,
    "fecha_generacion" timestamp without time zone DEFAULT "now"(),
    "fecha_pago_completo" timestamp without time zone,
    "notas" "text",
    "pagado_por" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."comisiones_empleados" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."compensacion_tipos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "tipo" "text" DEFAULT 'porcentaje'::"text",
    "valor" numeric(10,2),
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."compensacion_tipos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comprobantes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "tipo" character varying(30) NOT NULL,
    "referencia_tipo" character varying(30),
    "referencia_id" "uuid",
    "cliente_id" "uuid",
    "monto" numeric(12,2) NOT NULL,
    "fecha" "date" DEFAULT CURRENT_DATE,
    "descripcion" "text",
    "archivo_url" "text",
    "verificado" boolean DEFAULT false,
    "verificado_por" "uuid",
    "verificado_at" timestamp with time zone,
    "subido_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."comprobantes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."comprobantes_prestamo" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid",
    "tipo" "text" NOT NULL,
    "archivo_url" "text" NOT NULL,
    "fecha_subida" timestamp without time zone DEFAULT "now"(),
    "subido_por" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."comprobantes_prestamo" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."configuracion" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "clave" "text" NOT NULL,
    "valor" "text",
    "descripcion" "text",
    "tipo" "text" DEFAULT 'string'::"text",
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."configuracion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."configuracion_apis" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "servicio" "text" NOT NULL,
    "activo" boolean DEFAULT false,
    "modo_test" boolean DEFAULT false,
    "publishable_key" "text",
    "secret_key" "text",
    "webhook_secret" "text",
    "api_key" "text",
    "configuracion" "jsonb" DEFAULT '{}'::"jsonb",
    "ultima_verificacion" timestamp without time zone,
    "estado_conexion" "text" DEFAULT 'no_verificado'::"text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."configuracion_apis" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."configuracion_global" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre_app" character varying(100) DEFAULT 'Robert Darin Fintech'::character varying,
    "version" character varying(20) DEFAULT '6.1.0'::character varying,
    "modo_mantenimiento" boolean DEFAULT false,
    "max_avales_prestamo" integer DEFAULT 3,
    "max_avales_tanda" integer DEFAULT 2,
    "monto_min_prestamo" numeric(15,2) DEFAULT 1000,
    "monto_max_prestamo" numeric(15,2) DEFAULT 500000,
    "interes_default" numeric(5,2) DEFAULT 10.00,
    "email_soporte" character varying(100) DEFAULT 'soporte@robertdarin.com'::character varying,
    "telefono_soporte" character varying(20) DEFAULT '+52 555 123 4567'::character varying,
    "whatsapp" character varying(20) DEFAULT '+52 555 123 4567'::character varying,
    "color_acento" character varying(10) DEFAULT '#00BCD4'::character varying,
    "color_botones" character varying(10) DEFAULT '#4CAF50'::character varying,
    "color_alertas" character varying(10) DEFAULT '#FF5722'::character varying,
    "fondos_inteligentes" boolean DEFAULT false,
    "fondos_por_rol" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."configuracion_global" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."configuracion_moras" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "prestamos_mora_diaria" numeric(5,2) DEFAULT 1.0,
    "prestamos_mora_maxima" numeric(5,2) DEFAULT 30.0,
    "prestamos_dias_gracia" integer DEFAULT 0,
    "prestamos_aplicar_automatico" boolean DEFAULT true,
    "tandas_mora_diaria" numeric(5,2) DEFAULT 2.0,
    "tandas_mora_maxima" numeric(5,2) DEFAULT 50.0,
    "tandas_dias_gracia" integer DEFAULT 1,
    "tandas_aplicar_automatico" boolean DEFAULT true,
    "notificar_dias_antes" integer DEFAULT 3,
    "notificar_recordatorio_diario" boolean DEFAULT true,
    "notificar_al_aval" boolean DEFAULT true,
    "nivel_1_dias" integer DEFAULT 1,
    "nivel_2_dias" integer DEFAULT 7,
    "nivel_3_dias" integer DEFAULT 15,
    "nivel_4_dias" integer DEFAULT 30,
    "bloquear_cliente_dias" integer DEFAULT 60,
    "enviar_a_legal_dias" integer DEFAULT 90,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."configuracion_moras" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."contratos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "prestamo_id" "uuid",
    "tipo_contrato" "text" NOT NULL,
    "numero_contrato" "text",
    "fecha_inicio" "date" NOT NULL,
    "fecha_fin" "date",
    "contenido" "text",
    "plantilla_id" "uuid",
    "estado" "text" DEFAULT 'vigente'::"text",
    "firmado" boolean DEFAULT false,
    "fecha_firma" timestamp with time zone,
    "firma_cliente_url" "text",
    "firma_empresa_url" "text",
    "documento_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."contratos" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."conversaciones" AS
 SELECT "id",
    "tipo_conversacion",
    "cliente_id",
    "aval_id",
    "prestamo_id",
    "tanda_id",
    "creado_por_usuario_id",
    "estado",
    "ultimo_mensaje",
    "fecha_ultimo_mensaje",
    "created_at",
    "updated_at"
   FROM "public"."chat_conversaciones";


ALTER VIEW "public"."conversaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."documentos_aval" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "prestamo_id" "uuid",
    "tipo" "text" NOT NULL,
    "archivo_url" "text" NOT NULL,
    "firmado" boolean DEFAULT false,
    "fecha_firma" timestamp without time zone,
    "verificado" boolean DEFAULT false,
    "verificado_por" "uuid",
    "fecha_verificacion" timestamp without time zone,
    "notas" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "nombre_archivo" "text",
    "tamano_bytes" integer,
    "mime_type" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."documentos_aval" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."documentos_cliente" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "tipo_documento" "text" NOT NULL,
    "documento_url" "text" NOT NULL,
    "nombre_archivo" "text",
    "tamano_bytes" integer,
    "mime_type" "text",
    "verificado" boolean DEFAULT false,
    "verificado_por" "uuid",
    "fecha_verificacion" timestamp with time zone,
    "fecha_vencimiento" "date",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."documentos_cliente" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."empleados" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid",
    "sucursal_id" "uuid",
    "puesto" "text",
    "salario" numeric(12,2),
    "comision_porcentaje" numeric(5,2) DEFAULT 0,
    "comision_tipo" "text" DEFAULT 'ninguna'::"text",
    "fecha_contratacion" "date" DEFAULT CURRENT_DATE,
    "activo" boolean DEFAULT true,
    "estado" "text" DEFAULT 'activo'::"text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "negocio_id" "uuid",
    "nombre" "text",
    "apellidos" "text",
    "email" "text",
    "telefono" "text",
    "direccion" "text",
    "departamento" "text",
    "numero_empleado" "text",
    "curp" "text",
    "rfc" "text",
    "nss" "text",
    "cuenta_banco" "text",
    "banco" "text",
    "foto_url" "text",
    "salario_base" numeric(12,2),
    "tipo_pago_comision" "text",
    "fecha_ingreso" "date"
);


ALTER TABLE "public"."empleados" OWNER TO "postgres";


COMMENT ON COLUMN "public"."empleados"."estado" IS 'activo, inactivo, suspendido, baja';



CREATE TABLE IF NOT EXISTS "public"."empleados_negocios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "empleado_id" "uuid",
    "negocio_id" "uuid",
    "auth_uid" "uuid",
    "rol_modulo" "text" DEFAULT 'operador'::"text" NOT NULL,
    "modulos_acceso" "text"[] DEFAULT '{}'::"text"[],
    "permisos_especificos" "jsonb" DEFAULT '{}'::"jsonb",
    "es_administrador" boolean DEFAULT false,
    "zona_asignada" "text",
    "horario_trabajo" "jsonb" DEFAULT '{}'::"jsonb",
    "comision_porcentaje" numeric(5,2) DEFAULT 0,
    "meta_mensual" numeric(14,2) DEFAULT 0,
    "activo" boolean DEFAULT true,
    "fecha_asignacion" "date" DEFAULT CURRENT_DATE,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."empleados_negocios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."entregas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "pedido_id" "uuid",
    "pedido_tipo" character varying(30),
    "repartidor_id" "uuid",
    "direccion" "text" NOT NULL,
    "latitud" numeric(10,8),
    "longitud" numeric(11,8),
    "fecha_programada" "date",
    "hora_estimada" time without time zone,
    "fecha_entrega" timestamp with time zone,
    "estado" character varying(20) DEFAULT 'pendiente'::character varying,
    "notas" "text",
    "firma_cliente" "text",
    "foto_entrega" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."entregas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."envios_capital" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "fecha_envio" "date" DEFAULT CURRENT_DATE NOT NULL,
    "monto" numeric(12,2) NOT NULL,
    "moneda" character varying(3) DEFAULT 'MXN'::character varying,
    "tipo_cambio" numeric(8,4),
    "monto_mxn" numeric(12,2),
    "metodo_envio" character varying(50) DEFAULT 'transferencia'::character varying,
    "referencia" character varying(100),
    "banco_origen" character varying(100),
    "banco_destino" character varying(100),
    "empleado_id" "uuid",
    "nombre_receptor" character varying(150),
    "categoria" character varying(50) DEFAULT 'inversion'::character varying,
    "proposito" "text",
    "estado" character varying(20) DEFAULT 'enviado'::character varying,
    "fecha_recibido" timestamp with time zone,
    "confirmado_por" "uuid",
    "comprobante_url" "text",
    "notas" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "envios_capital_monto_check" CHECK (("monto" > (0)::numeric))
);


ALTER TABLE "public"."envios_capital" OWNER TO "postgres";


COMMENT ON TABLE "public"."envios_capital" IS 'Registro de envíos de dinero para inversión';



CREATE TABLE IF NOT EXISTS "public"."expediente_clientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "tipo_documento" "text" NOT NULL,
    "documento_url" "text" NOT NULL,
    "verificado" boolean DEFAULT false,
    "verificado_por" "uuid",
    "fecha_verificacion" timestamp without time zone,
    "fecha_subida" timestamp without time zone DEFAULT "now"(),
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."expediente_clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expedientes_legales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid" NOT NULL,
    "cliente_id" "uuid" NOT NULL,
    "fecha_generacion" timestamp without time zone DEFAULT "now"(),
    "hash_expediente" "text" NOT NULL,
    "estado_cuenta" "jsonb",
    "num_comunicaciones" integer DEFAULT 0,
    "num_pagos" integer DEFAULT 0,
    "total_adeudado" numeric(14,2),
    "dias_mora" integer,
    "estado" "text" DEFAULT 'generado'::"text",
    "abogado_asignado" "text",
    "numero_expediente_judicial" "text",
    "juzgado" "text",
    "notas_legales" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."expedientes_legales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factura_complementos_pago" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "emisor_id" "uuid",
    "uuid_fiscal" "uuid",
    "serie" character varying(25),
    "folio" integer,
    "fecha_timbrado" timestamp with time zone,
    "fecha_pago" timestamp with time zone NOT NULL,
    "forma_pago" character varying(2) NOT NULL,
    "moneda" character varying(3) DEFAULT 'MXN'::character varying,
    "tipo_cambio" numeric(10,4) DEFAULT 1,
    "monto" numeric(18,2) NOT NULL,
    "num_operacion" character varying(100),
    "rfc_emisor_cta_ord" character varying(13),
    "nom_banco_ord_ext" character varying(300),
    "cta_ordenante" character varying(50),
    "rfc_emisor_cta_ben" character varying(13),
    "cta_beneficiario" character varying(50),
    "estado" character varying(20) DEFAULT 'borrador'::character varying,
    "xml_content" "text",
    "pdf_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."factura_complementos_pago" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factura_conceptos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "factura_id" "uuid",
    "clave_prod_serv" character varying(8) NOT NULL,
    "clave_unidad" character varying(3) NOT NULL,
    "unidad" character varying(50),
    "no_identificacion" character varying(100),
    "descripcion" "text" NOT NULL,
    "cantidad" numeric(18,6) DEFAULT 1 NOT NULL,
    "valor_unitario" numeric(18,6) NOT NULL,
    "descuento" numeric(18,2) DEFAULT 0,
    "importe" numeric(18,2) NOT NULL,
    "objeto_imp" character varying(2) DEFAULT '02'::character varying,
    "cuenta_predial" character varying(150),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."factura_conceptos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factura_documentos_relacionados" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "complemento_pago_id" "uuid",
    "factura_id" "uuid",
    "id_documento" "uuid" NOT NULL,
    "serie" character varying(25),
    "folio" integer,
    "moneda" character varying(3) DEFAULT 'MXN'::character varying,
    "tipo_cambio" numeric(10,4) DEFAULT 1,
    "metodo_pago" character varying(3) DEFAULT 'PPD'::character varying,
    "num_parcialidad" integer,
    "imp_saldo_ant" numeric(18,2),
    "imp_pagado" numeric(18,2),
    "imp_saldo_insoluto" numeric(18,2),
    "objeto_imp" character varying(2) DEFAULT '02'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."factura_documentos_relacionados" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."factura_impuestos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "concepto_id" "uuid",
    "tipo" character varying(10) NOT NULL,
    "impuesto" character varying(3) NOT NULL,
    "tipo_factor" character varying(10) NOT NULL,
    "tasa_o_cuota" numeric(10,6),
    "base" numeric(18,2) NOT NULL,
    "importe" numeric(18,2),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."factura_impuestos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."facturacion_clientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_fintech_id" "uuid",
    "cliente_climas_id" "uuid",
    "cliente_ventas_id" "uuid",
    "cliente_purificadora_id" "uuid",
    "cliente_nice_id" "uuid",
    "rfc" character varying(13) NOT NULL,
    "razon_social" character varying(300) NOT NULL,
    "regimen_fiscal" character varying(3) NOT NULL,
    "uso_cfdi" character varying(4) DEFAULT 'G03'::character varying,
    "calle" character varying(200),
    "numero_exterior" character varying(50),
    "numero_interior" character varying(50),
    "colonia" character varying(200),
    "codigo_postal" character varying(5) NOT NULL,
    "municipio" character varying(200),
    "estado" character varying(100),
    "pais" character varying(100) DEFAULT 'México'::character varying,
    "email" character varying(255),
    "telefono" character varying(20),
    "num_reg_id_trib" character varying(50),
    "residencia_fiscal" character varying(3),
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."facturacion_clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."facturacion_emisores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "rfc" character varying(13) NOT NULL,
    "razon_social" character varying(300) NOT NULL,
    "nombre_comercial" character varying(300),
    "regimen_fiscal" character varying(3) NOT NULL,
    "regimen_fiscal_descripcion" character varying(200),
    "calle" character varying(200),
    "numero_exterior" character varying(50),
    "numero_interior" character varying(50),
    "colonia" character varying(200),
    "codigo_postal" character varying(5) NOT NULL,
    "municipio" character varying(200),
    "estado" character varying(100),
    "pais" character varying(100) DEFAULT 'México'::character varying,
    "certificado_cer" "text",
    "certificado_key" "text",
    "certificado_password" "text",
    "certificado_numero" character varying(50),
    "certificado_fecha_inicio" timestamp with time zone,
    "certificado_fecha_fin" timestamp with time zone,
    "proveedor_api" character varying(50) DEFAULT 'facturapi'::character varying,
    "api_key" "text",
    "api_secret" "text",
    "modo_pruebas" boolean DEFAULT false,
    "logo_url" "text",
    "color_primario" character varying(7) DEFAULT '#1E3A8A'::character varying,
    "serie_facturas" character varying(10) DEFAULT 'A'::character varying,
    "folio_actual_facturas" integer DEFAULT 1,
    "serie_notas_credito" character varying(10) DEFAULT 'NC'::character varying,
    "folio_actual_nc" integer DEFAULT 1,
    "serie_pagos" character varying(10) DEFAULT 'P'::character varying,
    "folio_actual_pagos" integer DEFAULT 1,
    "enviar_email_automatico" boolean DEFAULT true,
    "incluir_pdf" boolean DEFAULT true,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."facturacion_emisores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."facturacion_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "factura_id" "uuid",
    "accion" character varying(50) NOT NULL,
    "descripcion" "text",
    "resultado" character varying(20),
    "request_data" "jsonb",
    "response_data" "jsonb",
    "error_message" "text",
    "usuario_id" "uuid",
    "ip_address" character varying(45),
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."facturacion_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."facturacion_productos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "clave_producto_sat" "text" NOT NULL,
    "clave_unidad_sat" "text" NOT NULL,
    "descripcion" "text" NOT NULL,
    "valor_unitario" numeric(14,2) NOT NULL,
    "unidad" "text" DEFAULT 'PZA'::"text",
    "impuesto_iva" numeric(5,2) DEFAULT 16.00,
    "objeto_impuesto" "text" DEFAULT '02'::"text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."facturacion_productos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."facturas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "emisor_id" "uuid",
    "cliente_fiscal_id" "uuid",
    "tipo_comprobante" character varying(1) DEFAULT 'I'::character varying NOT NULL,
    "serie" character varying(25),
    "folio" integer,
    "uuid_fiscal" "uuid",
    "fecha_emision" timestamp with time zone DEFAULT "now"() NOT NULL,
    "fecha_timbrado" timestamp with time zone,
    "fecha_cancelacion" timestamp with time zone,
    "modulo_origen" character varying(50),
    "referencia_origen_id" "uuid",
    "referencia_tipo" character varying(50),
    "subtotal" numeric(18,2) DEFAULT 0 NOT NULL,
    "descuento" numeric(18,2) DEFAULT 0,
    "iva" numeric(18,2) DEFAULT 0,
    "isr_retenido" numeric(18,2) DEFAULT 0,
    "iva_retenido" numeric(18,2) DEFAULT 0,
    "ieps" numeric(18,2) DEFAULT 0,
    "total" numeric(18,2) DEFAULT 0 NOT NULL,
    "moneda" character varying(3) DEFAULT 'MXN'::character varying,
    "tipo_cambio" numeric(10,4) DEFAULT 1,
    "forma_pago" character varying(2) DEFAULT '99'::character varying,
    "metodo_pago" character varying(3) DEFAULT 'PUE'::character varying,
    "condiciones_pago" character varying(200),
    "uso_cfdi" character varying(4) DEFAULT 'G03'::character varying,
    "lugar_expedicion" character varying(5),
    "confirmacion" character varying(10),
    "estado" character varying(20) DEFAULT 'borrador'::character varying,
    "motivo_cancelacion" character varying(2),
    "uuid_sustitucion" "uuid",
    "xml_content" "text",
    "pdf_url" "text",
    "pac_response" "jsonb",
    "cadena_original" "text",
    "sello_cfdi" "text",
    "sello_sat" "text",
    "certificado_sat" character varying(50),
    "email_enviado" boolean DEFAULT false,
    "fecha_email" timestamp with time zone,
    "creado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."facturas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."firmas_avales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "prestamo_id" "uuid",
    "tipo_documento" "text" NOT NULL,
    "documento_id" "uuid",
    "firma_url" "text" NOT NULL,
    "ip_firma" "text",
    "dispositivo" "text",
    "user_agent" "text",
    "latitud" numeric(10,8),
    "longitud" numeric(11,8),
    "validada" boolean DEFAULT false,
    "validada_por" "uuid",
    "fecha_validacion" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."firmas_avales" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."firmas" AS
 SELECT "id",
    "aval_id",
    "prestamo_id",
    "tipo_documento",
    "documento_id",
    "firma_url",
    "ip_firma",
    "dispositivo",
    "user_agent",
    "latitud",
    "longitud",
    "validada",
    "validada_por",
    "fecha_validacion",
    "created_at"
   FROM "public"."firmas_avales";


ALTER VIEW "public"."firmas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."firmas_digitales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entidad_tipo" "text" NOT NULL,
    "entidad_id" "uuid" NOT NULL,
    "firmante_tipo" "text" NOT NULL,
    "firmante_id" "uuid",
    "firma_url" "text" NOT NULL,
    "ip_origen" "text",
    "dispositivo" "text",
    "geolocalizacion" "text",
    "latitud" numeric(10,8),
    "longitud" numeric(11,8),
    "fecha_firma" timestamp with time zone DEFAULT "now"(),
    "verificada" boolean DEFAULT false,
    "hash_documento" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."firmas_digitales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."fondos_pantalla" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" character varying(100) NOT NULL,
    "url" "text" NOT NULL,
    "tipo" character varying(20) DEFAULT 'imagen'::character varying,
    "activo" boolean DEFAULT false,
    "para_rol" character varying(50),
    "hora_inicio" time without time zone,
    "hora_fin" time without time zone,
    "orden" integer DEFAULT 0,
    "subido_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."fondos_pantalla" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."fondos" AS
 SELECT "id",
    "nombre",
    "url",
    "tipo",
    "activo",
    "para_rol",
    "hora_inicio",
    "hora_fin",
    "orden",
    "subido_por",
    "created_at"
   FROM "public"."fondos_pantalla";


ALTER VIEW "public"."fondos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."formularios_qr_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "tarjeta_servicio_id" "uuid",
    "modulo" character varying(50) NOT NULL,
    "nombre_formulario" character varying(100) DEFAULT 'Formulario de Contacto'::character varying NOT NULL,
    "titulo_header" "text" DEFAULT '¡Contáctanos!'::"text",
    "subtitulo_header" "text" DEFAULT 'Completa el formulario y te contactaremos pronto'::"text",
    "color_header" character varying(7) DEFAULT '#00D9FF'::character varying,
    "imagen_header_url" "text",
    "logo_url" "text",
    "mensaje_exito" "text" DEFAULT '¡Gracias! Tu solicitud ha sido enviada. Te contactaremos pronto.'::"text",
    "campos" "jsonb" DEFAULT '[{"id": "nombre", "tipo": "text", "label": "Nombre completo", "orden": 1, "activo": true, "requerido": true, "placeholder": "Tu nombre"}, {"id": "telefono", "tipo": "tel", "label": "Teléfono / WhatsApp", "orden": 2, "activo": true, "requerido": true, "placeholder": "10 dígitos"}, {"id": "email", "tipo": "email", "label": "Correo electrónico", "orden": 3, "activo": true, "requerido": false, "placeholder": "tu@email.com"}, {"id": "direccion", "tipo": "textarea", "label": "Dirección", "orden": 4, "activo": true, "requerido": false, "placeholder": "Calle, número, colonia..."}, {"id": "mensaje", "tipo": "textarea", "label": "¿En qué podemos ayudarte?", "orden": 5, "activo": true, "requerido": false, "placeholder": "Describe tu solicitud..."}]'::"jsonb",
    "campos_modulo" "jsonb" DEFAULT '[]'::"jsonb",
    "mostrar_horario" boolean DEFAULT true,
    "mostrar_telefono_negocio" boolean DEFAULT true,
    "mostrar_direccion_negocio" boolean DEFAULT true,
    "mostrar_redes_sociales" boolean DEFAULT true,
    "permitir_fotos" boolean DEFAULT true,
    "max_fotos" integer DEFAULT 3,
    "notificar_whatsapp" boolean DEFAULT true,
    "notificar_email" boolean DEFAULT true,
    "emails_notificacion" "text"[],
    "activo" boolean DEFAULT true,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "formularios_qr_config_modulo_check" CHECK ((("modulo")::"text" = ANY ((ARRAY['climas'::character varying, 'prestamos'::character varying, 'tandas'::character varying, 'cobranza'::character varying, 'servicios'::character varying, 'general'::character varying])::"text"[])))
);


ALTER TABLE "public"."formularios_qr_config" OWNER TO "postgres";


COMMENT ON TABLE "public"."formularios_qr_config" IS 'Configuración de formularios QR por negocio y módulo';



CREATE TABLE IF NOT EXISTS "public"."formularios_qr_envios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "formulario_config_id" "uuid",
    "tarjeta_servicio_id" "uuid",
    "negocio_id" "uuid",
    "modulo" character varying(50) NOT NULL,
    "datos" "jsonb" NOT NULL,
    "fotos" "text"[],
    "nombre" "text",
    "telefono" "text",
    "email" "text",
    "estado" character varying(30) DEFAULT 'nuevo'::character varying,
    "asignado_a" "uuid",
    "notas_internas" "text",
    "ip_address" "inet",
    "user_agent" "text",
    "origen" character varying(30) DEFAULT 'qr'::character varying,
    "contactado_at" timestamp with time zone,
    "completado_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "formularios_qr_envios_estado_check" CHECK ((("estado")::"text" = ANY ((ARRAY['nuevo'::character varying, 'visto'::character varying, 'contactado'::character varying, 'en_proceso'::character varying, 'completado'::character varying, 'cancelado'::character varying, 'spam'::character varying])::"text"[])))
);


ALTER TABLE "public"."formularios_qr_envios" OWNER TO "postgres";


COMMENT ON TABLE "public"."formularios_qr_envios" IS 'Historial de envíos de formularios QR';



CREATE TABLE IF NOT EXISTS "public"."intentos_cobro" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid" NOT NULL,
    "cliente_id" "uuid" NOT NULL,
    "cobrador_id" "uuid",
    "tipo" "text" NOT NULL,
    "resultado" "text" NOT NULL,
    "notas" "text",
    "latitud" numeric(10,8),
    "longitud" numeric(11,8),
    "duracion_llamada" integer,
    "grabacion_url" "text",
    "fecha" timestamp without time zone DEFAULT "now"(),
    "hash_registro" "text" NOT NULL,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."intentos_cobro" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventario" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "sucursal_id" "uuid",
    "codigo" "text",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "categoria" character varying(50),
    "unidad" character varying(20) DEFAULT 'pza'::character varying,
    "stock_actual" numeric(12,2) DEFAULT 0,
    "stock_minimo" numeric(12,2) DEFAULT 0,
    "stock_maximo" numeric(12,2),
    "precio_compra" numeric(10,2) DEFAULT 0,
    "precio_venta" numeric(10,2) DEFAULT 0,
    "ubicacion" "text",
    "imagen_url" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."inventario_movimientos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "inventario_id" "uuid",
    "tipo" character varying(20) NOT NULL,
    "cantidad" numeric(12,2) NOT NULL,
    "stock_anterior" numeric(12,2),
    "stock_nuevo" numeric(12,2),
    "referencia_tipo" character varying(30),
    "referencia_id" "uuid",
    "notas" "text",
    "usuario_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."inventario_movimientos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."links_pago" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "prestamo_id" "uuid",
    "tanda_id" "uuid",
    "amortizacion_id" "uuid",
    "concepto" "text" NOT NULL,
    "monto" numeric(12,2) NOT NULL,
    "stripe_payment_link_id" "text",
    "url_corta" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_expiracion" timestamp without time zone,
    "fecha_pago" timestamp without time zone,
    "enviado_por_whatsapp" boolean DEFAULT false,
    "fecha_envio_whatsapp" timestamp without time zone,
    "creado_por" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."links_pago" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."log_fraude" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tipo_entidad" "text" NOT NULL,
    "entidad_id" "uuid" NOT NULL,
    "accion" "text" NOT NULL,
    "motivo" "text",
    "severidad" integer DEFAULT 1,
    "ejecutado_por" "uuid",
    "ip_address" "text",
    "user_agent" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."log_fraude" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mensajes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "chat_id" "uuid",
    "emisor_id" "uuid",
    "contenido" "text" NOT NULL,
    "leido" boolean DEFAULT false,
    "fecha" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."mensajes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mensajes_aval_cobrador" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "chat_id" "uuid" NOT NULL,
    "emisor_id" "uuid" NOT NULL,
    "tipo_emisor" "text" NOT NULL,
    "mensaje" "text",
    "tipo_mensaje" "text" DEFAULT 'texto'::"text",
    "archivo_url" "text",
    "archivo_nombre" "text",
    "leido" boolean DEFAULT false,
    "fecha_leido" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."mensajes_aval_cobrador" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."metodos_pago" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tipo" character varying(30) DEFAULT 'transferencia'::character varying NOT NULL,
    "nombre" character varying(100) NOT NULL,
    "banco" character varying(100),
    "numero_cuenta" character varying(30),
    "clabe" character varying(20),
    "tarjeta" character varying(20),
    "titular" character varying(200),
    "qr_url" "text",
    "enlace_pago" "text",
    "instrucciones" "text",
    "activo" boolean DEFAULT true,
    "principal" boolean DEFAULT false,
    "orden" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."metodos_pago" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."mis_propiedades" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "tipo" "text" DEFAULT 'terreno'::"text",
    "descripcion" "text",
    "ubicacion" "text",
    "superficie_m2" numeric(10,2),
    "precio_total" numeric(14,2) NOT NULL,
    "enganche" numeric(14,2) DEFAULT 0,
    "saldo_inicial" numeric(14,2) NOT NULL,
    "monto_mensual" numeric(12,2) NOT NULL,
    "frecuencia_pago" "text" DEFAULT 'Mensual'::"text",
    "dia_pago" integer DEFAULT 15,
    "plazo_meses" integer,
    "fecha_compra" "date",
    "fecha_inicio_pagos" "date",
    "fecha_fin_estimada" "date",
    "vendedor_nombre" "text",
    "vendedor_telefono" "text",
    "vendedor_cuenta_banco" "text",
    "vendedor_banco" "text",
    "asignado_a" "uuid",
    "estado" "text" DEFAULT 'en_pagos'::"text",
    "notas" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."mis_propiedades" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."modulos_activos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "modulo_id" "text" NOT NULL,
    "tipo" "text" DEFAULT 'gavetero'::"text",
    "activo" boolean DEFAULT false,
    "configuracion" "jsonb" DEFAULT '{}'::"jsonb",
    "orden" integer DEFAULT 0,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."modulos_activos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."moras_prestamos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid",
    "amortizacion_id" "uuid",
    "dias_mora" integer NOT NULL,
    "monto_cuota_original" numeric(12,2) NOT NULL,
    "porcentaje_mora_aplicado" numeric(5,2) NOT NULL,
    "monto_mora" numeric(12,2) NOT NULL,
    "monto_total_con_mora" numeric(12,2) NOT NULL,
    "estado" "text" DEFAULT 'pendiente'::"text",
    "condonado_por" "uuid",
    "motivo_condonacion" "text",
    "fecha_condonacion" timestamp without time zone,
    "monto_mora_pagado" numeric(12,2) DEFAULT 0,
    "fecha_pago_mora" timestamp without time zone,
    "generado_automatico" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."moras_prestamos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."moras_tandas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tanda_id" "uuid",
    "participante_id" "uuid",
    "turno_numero" integer NOT NULL,
    "dias_mora" integer NOT NULL,
    "monto_aportacion_original" numeric(12,2) NOT NULL,
    "porcentaje_mora_aplicado" numeric(5,2) NOT NULL,
    "monto_mora" numeric(12,2) NOT NULL,
    "monto_total_con_mora" numeric(12,2) NOT NULL,
    "estado" "text" DEFAULT 'pendiente'::"text",
    "condonado_por" "uuid",
    "motivo_condonacion" "text",
    "fecha_condonacion" timestamp without time zone,
    "monto_mora_pagado" numeric(12,2) DEFAULT 0,
    "fecha_pago_mora" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."moras_tandas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."movimientos_capital" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "fecha" "date" DEFAULT CURRENT_DATE NOT NULL,
    "tipo" character varying(20) NOT NULL,
    "categoria" character varying(50) NOT NULL,
    "monto" numeric(12,2) NOT NULL,
    "descripcion" "text",
    "envio_id" "uuid",
    "prestamo_id" "uuid",
    "activo_id" "uuid",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."movimientos_capital" OWNER TO "postgres";


COMMENT ON TABLE "public"."movimientos_capital" IS 'Historial de movimientos de capital';



CREATE TABLE IF NOT EXISTS "public"."prestamos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "negocio_id" "uuid",
    "sucursal_id" "uuid",
    "monto" numeric(12,2) NOT NULL,
    "interes" numeric(5,2) DEFAULT 0,
    "plazo_meses" integer NOT NULL,
    "frecuencia_pago" "text" DEFAULT 'Mensual'::"text",
    "tipo_prestamo" "text" DEFAULT 'normal'::"text",
    "interes_diario" numeric(8,4) DEFAULT 0,
    "capital_al_final" boolean DEFAULT false,
    "estado" "text" DEFAULT 'activo'::"text",
    "proposito" "text",
    "garantia" "text",
    "aprobado_por" "uuid",
    "fecha_aprobacion" timestamp without time zone,
    "fecha_primer_pago" "date",
    "fecha_creacion" timestamp without time zone DEFAULT "now"(),
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "variante_arquilado" "text" DEFAULT 'clasico'::"text",
    "stripe_subscription_id" "text",
    "domiciliacion_activa" boolean DEFAULT false,
    "dia_cobro_automatico" integer DEFAULT 1
);


ALTER TABLE "public"."prestamos" OWNER TO "postgres";


COMMENT ON COLUMN "public"."prestamos"."estado" IS 'activo, pagado, vencido, mora, cancelado, liquidado';



COMMENT ON COLUMN "public"."prestamos"."domiciliacion_activa" IS 'Si TRUE, Stripe cobra automáticamente cada mes';



CREATE MATERIALIZED VIEW "public"."mv_cobranza_dia" AS
 SELECT "a"."prestamo_id",
    "p"."negocio_id",
    "p"."cliente_id",
    "c"."nombre" AS "cliente_nombre",
    "c"."telefono" AS "cliente_telefono",
    "a"."numero_cuota",
    "a"."monto_cuota",
    "a"."fecha_vencimiento",
    "a"."estado",
        CASE
            WHEN ("a"."fecha_vencimiento" < CURRENT_DATE) THEN 'vencido'::"text"
            WHEN ("a"."fecha_vencimiento" = CURRENT_DATE) THEN 'hoy'::"text"
            WHEN ("a"."fecha_vencimiento" = (CURRENT_DATE + 1)) THEN 'mañana'::"text"
            ELSE 'futuro'::"text"
        END AS "urgencia",
    "now"() AS "ultima_actualizacion"
   FROM (("public"."amortizaciones" "a"
     JOIN "public"."prestamos" "p" ON (("p"."id" = "a"."prestamo_id")))
     JOIN "public"."clientes" "c" ON (("c"."id" = "p"."cliente_id")))
  WHERE (("a"."estado" = ANY (ARRAY['pendiente'::"text", 'vencido'::"text"])) AND ("a"."fecha_vencimiento" <= (CURRENT_DATE + 7)))
  WITH NO DATA;


ALTER MATERIALIZED VIEW "public"."mv_cobranza_dia" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pagos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "prestamo_id" "uuid",
    "tanda_id" "uuid",
    "amortizacion_id" "uuid",
    "cliente_id" "uuid",
    "monto" numeric(12,2) NOT NULL,
    "metodo_pago" "text" DEFAULT 'efectivo'::"text",
    "fecha_pago" timestamp without time zone DEFAULT "now"(),
    "nota" "text",
    "comprobante_url" "text",
    "recibo_oficial_url" "text",
    "latitud" double precision,
    "longitud" double precision,
    "registrado_por" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "stripe_payment_id" "text",
    "stripe_charge_id" "text",
    "stripe_invoice_id" "text",
    "cobrado_automatico" boolean DEFAULT false
);


ALTER TABLE "public"."pagos" OWNER TO "postgres";


COMMENT ON COLUMN "public"."pagos"."metodo_pago" IS 'efectivo, transferencia, tarjeta_stripe, link_pago, domiciliacion';



CREATE MATERIALIZED VIEW "public"."mv_kpis_mes" AS
 SELECT "p"."negocio_id",
    "date_trunc"('month'::"text", "now"()) AS "mes",
    "count"(*) FILTER (WHERE ("p"."fecha_creacion" >= "date_trunc"('month'::"text", "now"()))) AS "nuevos_prestamos",
    COALESCE("sum"("p"."monto") FILTER (WHERE ("p"."fecha_creacion" >= "date_trunc"('month'::"text", "now"()))), (0)::numeric) AS "monto_colocado",
    COALESCE("sum"("pago"."monto"), (0)::numeric) AS "monto_cobrado",
    "count"(DISTINCT "pago"."id") AS "pagos_recibidos",
    "now"() AS "ultima_actualizacion"
   FROM ("public"."prestamos" "p"
     LEFT JOIN "public"."pagos" "pago" ON ((("pago"."negocio_id" = "p"."negocio_id") AND ("pago"."fecha_pago" >= "date_trunc"('month'::"text", "now"())))))
  GROUP BY "p"."negocio_id"
  WITH NO DATA;


ALTER MATERIALIZED VIEW "public"."mv_kpis_mes" OWNER TO "postgres";


CREATE MATERIALIZED VIEW "public"."mv_resumen_cartera" AS
 SELECT "p"."negocio_id",
    "count"(*) FILTER (WHERE ("p"."estado" = 'activo'::"text")) AS "prestamos_activos",
    "count"(*) FILTER (WHERE ("p"."estado" = 'mora'::"text")) AS "prestamos_mora",
    "count"(*) FILTER (WHERE ("p"."estado" = 'pagado'::"text")) AS "prestamos_pagados",
    "count"(*) FILTER (WHERE ("p"."estado" = 'vencido'::"text")) AS "prestamos_vencidos",
    COALESCE("sum"("p"."monto") FILTER (WHERE ("p"."estado" = ANY (ARRAY['activo'::"text", 'mora'::"text"]))), (0)::numeric) AS "capital_vigente",
    COALESCE("sum"("a"."monto_cuota") FILTER (WHERE ("a"."estado" = 'pendiente'::"text")), (0)::numeric) AS "por_cobrar",
    COALESCE("sum"("a"."monto_cuota") FILTER (WHERE ("a"."estado" = 'vencido'::"text")), (0)::numeric) AS "vencido",
    "now"() AS "ultima_actualizacion"
   FROM ("public"."prestamos" "p"
     LEFT JOIN "public"."amortizaciones" "a" ON (("a"."prestamo_id" = "p"."id")))
  GROUP BY "p"."negocio_id"
  WITH NO DATA;


ALTER MATERIALIZED VIEW "public"."mv_resumen_cartera" OWNER TO "postgres";


CREATE MATERIALIZED VIEW "public"."mv_resumen_mensual_pagos" AS
 SELECT ("date_trunc"('month'::"text", "fecha_pago"))::"date" AS "mes",
    "negocio_id",
    "count"(*) AS "total_pagos",
    "sum"("monto") AS "monto_recuperado",
    "avg"("monto") AS "pago_promedio",
    "count"(DISTINCT "cliente_id") AS "clientes_que_pagaron"
   FROM "public"."pagos" "pg"
  WHERE ("fecha_pago" IS NOT NULL)
  GROUP BY ("date_trunc"('month'::"text", "fecha_pago")), "negocio_id"
  WITH NO DATA;


ALTER MATERIALIZED VIEW "public"."mv_resumen_mensual_pagos" OWNER TO "postgres";


CREATE MATERIALIZED VIEW "public"."mv_resumen_mensual_prestamos" AS
 SELECT ("date_trunc"('month'::"text", "fecha_creacion"))::"date" AS "mes",
    "negocio_id",
    "count"(*) AS "total_prestamos",
    "sum"("monto") AS "monto_colocado",
    "avg"("monto") AS "monto_promedio",
    "avg"("interes") AS "interes_promedio",
    "count"(*) FILTER (WHERE ("estado" = 'pagado'::"text")) AS "prestamos_liquidados",
    "count"(*) FILTER (WHERE ("estado" = 'mora'::"text")) AS "prestamos_en_mora"
   FROM "public"."prestamos" "p"
  GROUP BY ("date_trunc"('month'::"text", "fecha_creacion")), "negocio_id"
  WITH NO DATA;


ALTER MATERIALIZED VIEW "public"."mv_resumen_mensual_prestamos" OWNER TO "postgres";


CREATE MATERIALIZED VIEW "public"."mv_top_clientes" AS
 SELECT "c"."negocio_id",
    "c"."id" AS "cliente_id",
    "c"."nombre",
    "count"("p"."id") AS "total_prestamos",
    COALESCE("sum"("p"."monto"), (0)::numeric) AS "monto_total",
    "count"(*) FILTER (WHERE ("p"."estado" = 'pagado'::"text")) AS "prestamos_pagados",
    COALESCE(("avg"(
        CASE
            WHEN ("p"."estado" = 'pagado'::"text") THEN 1
            ELSE 0
        END) * (100)::numeric), (0)::numeric) AS "tasa_cumplimiento",
    "now"() AS "ultima_actualizacion"
   FROM ("public"."clientes" "c"
     LEFT JOIN "public"."prestamos" "p" ON (("p"."cliente_id" = "c"."id")))
  WHERE ("c"."activo" = true)
  GROUP BY "c"."negocio_id", "c"."id", "c"."nombre"
  WITH NO DATA;


ALTER MATERIALIZED VIEW "public"."mv_top_clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."negocios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "tipo" "text" DEFAULT 'fintech'::"text",
    "propietario_id" "uuid",
    "rfc" "text",
    "razon_social" "text",
    "direccion_fiscal" "text",
    "telefono" "text",
    "email" "text",
    "logo_url" "text",
    "color_primario" "text" DEFAULT '#FF9800'::"text",
    "color_secundario" "text" DEFAULT '#1E1E2C'::"text",
    "activo" boolean DEFAULT true,
    "configuracion" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."negocios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_catalogos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "codigo" "text",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "imagen_portada_url" "text",
    "imagen_portada" "text",
    "pdf_url" "text",
    "fecha_inicio" "date",
    "fecha_fin" "date",
    "vigencia_inicio" "date",
    "vigencia_fin" "date",
    "version" "text" DEFAULT '1.0'::"text",
    "activo" boolean DEFAULT true,
    "orden" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."nice_catalogos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_categorias" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "icono" "text" DEFAULT 'diamond'::"text",
    "color" "text" DEFAULT '#E91E63'::"text",
    "imagen_url" "text",
    "orden" integer DEFAULT 0,
    "activa" boolean DEFAULT true,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."nice_categorias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_clientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "vendedora_id" "uuid",
    "auth_uid" "uuid",
    "nombre" "text" NOT NULL,
    "email" "text",
    "telefono" "text",
    "whatsapp" "text",
    "direccion" "text",
    "ciudad" "text",
    "fecha_nacimiento" "date",
    "preferencias" "jsonb" DEFAULT '{}'::"jsonb",
    "total_compras" numeric(14,2) DEFAULT 0,
    "puntos" integer DEFAULT 0,
    "nivel_cliente" "text" DEFAULT 'nuevo'::"text",
    "notas" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "apellidos" "text",
    "colonia" "text",
    "estado" "text",
    "codigo_postal" "text",
    "referencias" "text",
    "categorias_favoritas" "text"[],
    "talla_anillo" "text",
    "preferencias_color" "text",
    "cantidad_pedidos" integer DEFAULT 0,
    "ultima_compra" "date",
    "acepta_whatsapp" boolean DEFAULT true,
    "acepta_email" boolean DEFAULT true,
    "fecha_ultimo_contacto" "date",
    "es_vip" boolean DEFAULT false
);


ALTER TABLE "public"."nice_clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_comisiones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vendedora_id" "uuid",
    "pedido_id" "uuid",
    "tipo" "text" DEFAULT 'venta'::"text",
    "monto" numeric(14,2) NOT NULL,
    "porcentaje" numeric(5,2),
    "descripcion" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_pago" "date",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."nice_comisiones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_inventario_movimientos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "producto_id" "uuid",
    "vendedora_id" "uuid",
    "tipo_movimiento" "text" NOT NULL,
    "cantidad" integer NOT NULL,
    "stock_anterior" integer,
    "stock_posterior" integer,
    "referencia_id" "uuid",
    "referencia_tipo" "text",
    "motivo" "text",
    "realizado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."nice_inventario_movimientos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_inventario_vendedora" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "vendedora_id" "uuid",
    "producto_id" "uuid",
    "cantidad" integer DEFAULT 0,
    "cantidad_vendida" integer DEFAULT 0,
    "costo_unitario" numeric(14,2),
    "fecha_asignacion" "date" DEFAULT CURRENT_DATE,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."nice_inventario_vendedora" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_niveles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "codigo" "text",
    "nombre" "text" NOT NULL,
    "comision_ventas" numeric(5,2) DEFAULT 20,
    "comision_porcentaje" numeric(5,2) DEFAULT 20,
    "comision_equipo" numeric(5,2) DEFAULT 5,
    "comision_equipo_porcentaje" numeric(5,2) DEFAULT 5,
    "descuento_porcentaje" numeric(5,2) DEFAULT 25,
    "ventas_minimas_mes" numeric(14,2) DEFAULT 0,
    "meta_ventas_mensual" numeric(14,2) DEFAULT 0,
    "bono_reclutamiento" numeric(14,2) DEFAULT 0,
    "beneficios" "jsonb" DEFAULT '[]'::"jsonb",
    "color" "text" DEFAULT '#CD7F32'::"text",
    "icono" "text" DEFAULT 'star'::"text",
    "orden" integer DEFAULT 0,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "equipo_minimo" integer DEFAULT 0,
    "puntos_minimos" integer DEFAULT 0,
    "comision_equipo_n1" numeric(5,2) DEFAULT 0,
    "comision_equipo_n2" numeric(5,2) DEFAULT 0,
    "comision_equipo_n3" numeric(5,2) DEFAULT 0,
    "bono_liderazgo" numeric(12,2) DEFAULT 0,
    "insignia_url" "text"
);


ALTER TABLE "public"."nice_niveles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_pagos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pedido_id" "uuid",
    "monto" numeric(12,2) NOT NULL,
    "metodo_pago" "text" DEFAULT 'efectivo'::"text",
    "referencia" "text",
    "comprobante_url" "text",
    "fecha_pago" timestamp with time zone DEFAULT "now"(),
    "estado" "text" DEFAULT 'completado'::"text",
    "registrado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."nice_pagos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_pedido_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pedido_id" "uuid",
    "producto_id" "uuid",
    "cantidad" integer DEFAULT 1,
    "precio_unitario" numeric(14,2) NOT NULL,
    "descuento" numeric(14,2) DEFAULT 0,
    "subtotal" numeric(14,2) NOT NULL,
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."nice_pedido_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_pedidos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "vendedora_id" "uuid",
    "cliente_id" "uuid",
    "folio" "text",
    "fecha_pedido" timestamp with time zone DEFAULT "now"(),
    "fecha_entrega_estimada" "date",
    "fecha_entrega_real" "date",
    "subtotal" numeric(14,2) DEFAULT 0,
    "descuento" numeric(14,2) DEFAULT 0,
    "total" numeric(14,2) DEFAULT 0,
    "metodo_pago" "text" DEFAULT 'efectivo'::"text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "direccion_entrega" "text",
    "notas" "text",
    "comision_vendedora" numeric(14,2) DEFAULT 0,
    "comision_pagada" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "catalogo_id" "uuid",
    "envio" numeric(10,2) DEFAULT 0,
    "ganancia_vendedora" numeric(10,2) DEFAULT 0,
    "puntos_generados" integer DEFAULT 0,
    "tipo_envio" "text",
    "guia_envio" "text",
    "paqueteria" "text",
    "cliente_nombre" "text",
    "cliente_telefono" "text",
    "notas_vendedora" "text",
    "notas_internas" "text",
    "referencia_pago" "text",
    "comprobante_url" "text"
);


ALTER TABLE "public"."nice_pedidos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_productos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "catalogo_id" "uuid",
    "categoria_id" "uuid",
    "sku" "text",
    "codigo_pagina" "text",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "material" "text",
    "precio_catalogo" numeric(14,2) NOT NULL,
    "precio_vendedora" numeric(14,2),
    "costo" numeric(14,2),
    "stock" integer DEFAULT 0,
    "stock_minimo" integer DEFAULT 5,
    "imagen_url" "text",
    "imagenes_adicionales" "jsonb" DEFAULT '[]'::"jsonb",
    "destacado" boolean DEFAULT false,
    "nuevo" boolean DEFAULT false,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "imagen_principal_url" "text",
    "es_nuevo" boolean DEFAULT false,
    "es_destacado" boolean DEFAULT false,
    "es_oferta" boolean DEFAULT false,
    "precio_oferta" numeric(10,2),
    "disponible" boolean DEFAULT true,
    "veces_vendido" integer DEFAULT 0,
    "peso_gramos" numeric(8,2),
    "pagina_catalogo" integer,
    "talla" "text"
);


ALTER TABLE "public"."nice_productos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."nice_vendedoras" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "auth_uid" "uuid",
    "nivel_id" "uuid",
    "patrocinadora_id" "uuid",
    "codigo_vendedora" "text",
    "nombre" "text" NOT NULL,
    "email" "text",
    "telefono" "text",
    "whatsapp" "text",
    "direccion" "text",
    "ciudad" "text",
    "fecha_nacimiento" "date",
    "ine_url" "text",
    "foto_url" "text",
    "banco" "text",
    "clabe" "text",
    "numero_cuenta" "text",
    "fecha_ingreso" "date" DEFAULT CURRENT_DATE,
    "ventas_totales" numeric(14,2) DEFAULT 0,
    "ventas_mes" numeric(14,2) DEFAULT 0,
    "comisiones_pendientes" numeric(14,2) DEFAULT 0,
    "equipo_total" integer DEFAULT 0,
    "meta_mensual" numeric(14,2) DEFAULT 5000,
    "notas" "text",
    "activa" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "apellidos" "text",
    "estado" "text",
    "codigo_postal" "text",
    "rfc" "text",
    "curp" "text",
    "titular_cuenta" "text",
    "instagram" "text",
    "facebook" "text",
    "tiktok" "text",
    "verificada" boolean DEFAULT false,
    "comisiones_totales" numeric(12,2) DEFAULT 0,
    "puntos_acumulados" integer DEFAULT 0,
    "clientes_activos" integer DEFAULT 0,
    "equipo_directo" integer DEFAULT 0,
    "usuario_id" "uuid"
);


ALTER TABLE "public"."nice_vendedoras" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notificaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "usuario_id" "uuid",
    "titulo" "text" NOT NULL,
    "mensaje" "text" NOT NULL,
    "tipo" "text" DEFAULT 'info'::"text",
    "prioridad" "text" DEFAULT 'normal'::"text",
    "icono" "text",
    "leida" boolean DEFAULT false,
    "fecha_lectura" timestamp without time zone,
    "enlace" "text",
    "ruta_destino" character varying(100),
    "notificacion_masiva_id" "uuid",
    "referencia_id" "uuid",
    "referencia_tipo" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."notificaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notificaciones_documento_aval" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "documento_id" "uuid",
    "tipo_documento" "text" NOT NULL,
    "tipo_notificacion" "text" NOT NULL,
    "mensaje" "text" NOT NULL,
    "motivo_rechazo" "text",
    "leida" boolean DEFAULT false,
    "fecha_lectura" timestamp with time zone,
    "enviada_push" boolean DEFAULT false,
    "fecha_envio_push" timestamp with time zone,
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."notificaciones_documento_aval" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notificaciones_masivas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "titulo" character varying(200) NOT NULL,
    "mensaje" "text" NOT NULL,
    "tipo" character varying(50) DEFAULT 'anuncio'::character varying,
    "ruta_destino" character varying(100),
    "imagen_url" "text",
    "audiencia" character varying(50) DEFAULT 'todos'::character varying,
    "destinatarios_count" integer DEFAULT 0,
    "leidos_count" integer DEFAULT 0,
    "enviado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."notificaciones_masivas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notificaciones_mora" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "prestamo_id" "uuid" NOT NULL,
    "cliente_id" "uuid" NOT NULL,
    "tipo" "text" NOT NULL,
    "canal" "text" NOT NULL,
    "contenido" "text" NOT NULL,
    "fecha_envio" timestamp without time zone DEFAULT "now"(),
    "fecha_entrega" timestamp without time zone,
    "confirmacion_lectura" boolean DEFAULT false,
    "fecha_lectura" timestamp without time zone,
    "hash_notificacion" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."notificaciones_mora" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notificaciones_mora_aval" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "aval_id" "uuid" NOT NULL,
    "prestamo_id" "uuid" NOT NULL,
    "amortizacion_id" "uuid",
    "nivel_mora" "text" NOT NULL,
    "dias_mora" integer NOT NULL,
    "monto_vencido" numeric(12,2) NOT NULL,
    "mensaje" "text",
    "canal" "text" DEFAULT 'push'::"text",
    "enviada" boolean DEFAULT false,
    "fecha_envio" timestamp without time zone,
    "leida" boolean DEFAULT false,
    "fecha_lectura" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."notificaciones_mora_aval" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notificaciones_mora_cliente" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "tipo_deuda" "text" NOT NULL,
    "prestamo_id" "uuid",
    "tanda_id" "uuid",
    "nivel_mora" "text" NOT NULL,
    "titulo" "text" NOT NULL,
    "mensaje" "text" NOT NULL,
    "dias_mora" integer,
    "monto_pendiente" numeric(12,2),
    "monto_mora" numeric(12,2),
    "monto_total" numeric(12,2),
    "canal" "text" DEFAULT 'app'::"text",
    "enviado" boolean DEFAULT true,
    "leido" boolean DEFAULT false,
    "fecha_lectura" timestamp without time zone,
    "enviado_a_aval" boolean DEFAULT false,
    "aval_id" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."notificaciones_mora_cliente" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notificaciones_sistema" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tipo" "text" NOT NULL,
    "accion" "text" NOT NULL,
    "mensaje" "text",
    "destinatarios" "text" DEFAULT 'todos'::"text",
    "negocio_id" "uuid",
    "leido" boolean DEFAULT false,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "fecha" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."notificaciones_sistema" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pagos_comisiones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "comision_id" "uuid",
    "monto" numeric(12,2) NOT NULL,
    "metodo_pago" "text",
    "referencia" "text",
    "notas" "text",
    "pagado_por" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."pagos_comisiones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pagos_propiedades" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "propiedad_id" "uuid",
    "numero_pago" integer NOT NULL,
    "monto" numeric(12,2) NOT NULL,
    "fecha_programada" "date" NOT NULL,
    "fecha_pago" "date",
    "pagado_por" "uuid",
    "metodo_pago" "text",
    "referencia" "text",
    "comprobante_url" "text",
    "comprobante_filename" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "notas" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."pagos_propiedades" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."permisos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "clave_permiso" "text" NOT NULL,
    "descripcion" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."permisos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."preferencias_usuario" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "tema" character varying(50) DEFAULT 'oscuro'::character varying,
    "idioma" character varying(10) DEFAULT 'es'::character varying,
    "notificaciones_push" boolean DEFAULT true,
    "notificaciones_email" boolean DEFAULT true,
    "modo_compacto" boolean DEFAULT false,
    "configuracion_extra" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."preferencias_usuario" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."prestamos_avales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid" NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "orden" integer DEFAULT 1,
    "tipo" character varying(50) DEFAULT 'garante'::character varying,
    "porcentaje_responsabilidad" numeric(5,2) DEFAULT 100.00,
    "firma_digital" "text",
    "firmado_at" timestamp with time zone,
    "estado" character varying(20) DEFAULT 'pendiente'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."prestamos_avales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."promesas_pago" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid" NOT NULL,
    "cliente_id" "uuid" NOT NULL,
    "intento_cobro_id" "uuid",
    "monto_prometido" numeric(12,2) NOT NULL,
    "fecha_promesa" "date" NOT NULL,
    "fecha_compromiso" "date" NOT NULL,
    "cumplida" boolean DEFAULT false,
    "fecha_cumplimiento" timestamp without time zone,
    "notas" "text",
    "grabacion_url" "text",
    "hash_promesa" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."promesas_pago" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."promociones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "titulo" character varying(200) NOT NULL,
    "descripcion" "text",
    "imagen_url" "text",
    "ruta_destino" character varying(100),
    "tipo" character varying(50) DEFAULT 'general'::character varying,
    "activa" boolean DEFAULT true,
    "fecha_inicio" timestamp with time zone DEFAULT "now"(),
    "fecha_fin" timestamp with time zone,
    "prioridad" integer DEFAULT 0,
    "vistas" integer DEFAULT 0,
    "clicks" integer DEFAULT 0,
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."promociones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_pagos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "entrega_id" "uuid",
    "cliente_id" "uuid",
    "monto" numeric(12,2) NOT NULL,
    "metodo_pago" "text" DEFAULT 'efectivo'::"text",
    "referencia" "text",
    "comprobante_url" "text",
    "fecha_pago" timestamp with time zone DEFAULT "now"(),
    "estado" "text" DEFAULT 'completado'::"text",
    "registrado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "negocio_id" "uuid"
);


ALTER TABLE "public"."purificadora_pagos" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."puri_pagos" AS
 SELECT "id",
    "entrega_id",
    "cliente_id",
    "monto",
    "metodo_pago",
    "referencia",
    "comprobante_url",
    "fecha_pago",
    "estado",
    "registrado_por",
    "notas",
    "created_at"
   FROM "public"."purificadora_pagos";


ALTER VIEW "public"."puri_pagos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_cliente_contactos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "nombre" "text" NOT NULL,
    "telefono" "text",
    "relacion" "text",
    "es_principal" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_cliente_contactos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_cliente_documentos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "tipo" "text" NOT NULL,
    "nombre" "text",
    "url" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_cliente_documentos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_cliente_notas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "nota" "text" NOT NULL,
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_cliente_notas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_clientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "auth_uid" "uuid",
    "repartidor_id" "uuid",
    "codigo_cliente" "text",
    "nombre" "text" NOT NULL,
    "email" "text",
    "telefono" "text",
    "whatsapp" "text",
    "direccion" "text",
    "colonia" "text",
    "referencias" "text",
    "ciudad" "text",
    "codigo_postal" "text",
    "ubicacion_lat" numeric(10,8),
    "ubicacion_lng" numeric(11,8),
    "dia_preferido" "text",
    "hora_preferida" "text",
    "garrafones_prestados" integer DEFAULT 0,
    "deposito_garrafones" numeric(14,2) DEFAULT 0,
    "saldo" numeric(14,2) DEFAULT 0,
    "frecuencia_pedido" "text" DEFAULT 'semanal'::"text",
    "total_garrafones_comprados" integer DEFAULT 0,
    "ultimo_pedido" "date",
    "notas" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "garrafones_en_prestamo" integer DEFAULT 0,
    "garrafones_maximo" integer DEFAULT 10,
    "frecuencia_entrega" "text" DEFAULT 'semanal'::"text",
    "dias_entrega" "text"[],
    "saldo_pendiente" numeric(12,2) DEFAULT 0,
    "ultima_entrega" "date"
);


ALTER TABLE "public"."purificadora_clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_cortes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "repartidor_id" "uuid",
    "fecha" "date" DEFAULT CURRENT_DATE,
    "garrafones_salida" integer DEFAULT 0,
    "garrafones_vendidos" integer DEFAULT 0,
    "garrafones_devueltos" integer DEFAULT 0,
    "garrafones_vacios_recogidos" integer DEFAULT 0,
    "efectivo_esperado" numeric(14,2) DEFAULT 0,
    "efectivo_recibido" numeric(14,2) DEFAULT 0,
    "diferencia" numeric(14,2) DEFAULT 0,
    "entregas_completadas" integer DEFAULT 0,
    "entregas_fallidas" integer DEFAULT 0,
    "kilometros_recorridos" numeric(10,2),
    "observaciones" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "aprobado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "garrafones_regreso" integer DEFAULT 0,
    "garrafones_faltantes" integer DEFAULT 0,
    "total_ventas" numeric(12,2) DEFAULT 0,
    "total_cobranza_anterior" numeric(12,2) DEFAULT 0,
    "transferencias_recibidas" numeric(12,2) DEFAULT 0,
    "ruta_id" "uuid"
);


ALTER TABLE "public"."purificadora_cortes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_entregas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "repartidor_id" "uuid",
    "ruta_id" "uuid",
    "folio" "text",
    "fecha_programada" "date",
    "fecha_entrega" timestamp with time zone,
    "garrafones_entregados" integer DEFAULT 0,
    "garrafones_recogidos" integer DEFAULT 0,
    "productos_adicionales" "jsonb" DEFAULT '[]'::"jsonb",
    "subtotal" numeric(14,2) DEFAULT 0,
    "descuento" numeric(14,2) DEFAULT 0,
    "total" numeric(14,2) DEFAULT 0,
    "metodo_pago" "text",
    "pagado" boolean DEFAULT false,
    "monto_pagado" numeric(14,2) DEFAULT 0,
    "estado" "text" DEFAULT 'programada'::"text",
    "motivo_no_entrega" "text",
    "notas" "text",
    "ubicacion_entrega_lat" numeric(10,8),
    "ubicacion_entrega_lng" numeric(11,8),
    "firma_cliente_url" "text",
    "foto_entrega_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_entregas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_garrafones_historial" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "fecha" "date" DEFAULT CURRENT_DATE,
    "garrafones_inicio" integer DEFAULT 0,
    "garrafones_producidos" integer DEFAULT 0,
    "garrafones_vendidos" integer DEFAULT 0,
    "garrafones_prestados" integer DEFAULT 0,
    "garrafones_devueltos" integer DEFAULT 0,
    "garrafones_danados" integer DEFAULT 0,
    "garrafones_fin" integer DEFAULT 0,
    "observaciones" "text",
    "registrado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_garrafones_historial" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_gastos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "repartidor_id" "uuid",
    "ruta_id" "uuid",
    "fecha" "date" DEFAULT CURRENT_DATE,
    "concepto" "text" NOT NULL,
    "monto" numeric(12,2) NOT NULL,
    "categoria" "text" DEFAULT 'operativo'::"text",
    "comprobante_url" "text",
    "aprobado" boolean DEFAULT false,
    "aprobado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_gastos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_inventario_garrafones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "tipo_movimiento" "text" NOT NULL,
    "cantidad" integer NOT NULL,
    "garrafones_buenos" integer DEFAULT 0,
    "garrafones_danados" integer DEFAULT 0,
    "garrafones_en_prestamo" integer DEFAULT 0,
    "garrafones_disponibles" integer DEFAULT 0,
    "referencia_id" "uuid",
    "referencia_tipo" "text",
    "motivo" "text",
    "realizado_por" "uuid",
    "fecha" "date" DEFAULT CURRENT_DATE,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_inventario_garrafones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_precios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "producto_id" "uuid",
    "tipo_cliente" "text" DEFAULT 'general'::"text",
    "precio" numeric(10,2) NOT NULL,
    "precio_anterior" numeric(10,2),
    "vigente_desde" "date" DEFAULT CURRENT_DATE,
    "vigente_hasta" "date",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_precios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_produccion" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "fecha" "date" DEFAULT CURRENT_DATE NOT NULL,
    "garrafones_producidos" integer DEFAULT 0,
    "garrafones_defectuosos" integer DEFAULT 0,
    "litros_agua_usados" numeric(12,2) DEFAULT 0,
    "litros_desperdicio" numeric(12,2) DEFAULT 0,
    "costo_produccion" numeric(12,2) DEFAULT 0,
    "responsable_id" "uuid",
    "turno" "text" DEFAULT 'matutino'::"text",
    "observaciones" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_produccion" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_productos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "codigo" "text",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "tipo" "text" DEFAULT 'garrafon'::"text",
    "capacidad_litros" numeric(10,2),
    "precio_venta" numeric(14,2) NOT NULL,
    "precio_mayoreo" numeric(14,2),
    "deposito" numeric(14,2) DEFAULT 0,
    "stock" integer DEFAULT 0,
    "imagen_url" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."purificadora_productos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_repartidores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "empleado_id" "uuid",
    "auth_uid" "uuid",
    "codigo" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "apellidos" "text",
    "telefono" "text",
    "email" "text",
    "licencia_conducir" "text",
    "vigencia_licencia" "date",
    "vehiculo_asignado" "text",
    "capacidad_garrafones" integer DEFAULT 50,
    "rutas_asignadas" "text"[] DEFAULT '{}'::"text"[],
    "entregas_hoy" integer DEFAULT 0,
    "entregas_mes" integer DEFAULT 0,
    "garrafones_entregados_mes" integer DEFAULT 0,
    "comision_garrrafon" numeric(5,2) DEFAULT 2,
    "efectivo_en_mano" numeric(14,2) DEFAULT 0,
    "disponible" boolean DEFAULT true,
    "en_ruta" boolean DEFAULT false,
    "ubicacion_actual" "jsonb",
    "foto_url" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "licencia" "text",
    "vehiculo" "text",
    "placas" "text",
    "garrafones_asignados" integer DEFAULT 0,
    "estado" "text" DEFAULT 'activo'::"text"
);


ALTER TABLE "public"."purificadora_repartidores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."purificadora_rutas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "repartidor_id" "uuid",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "dia_semana" "text",
    "zona" "text",
    "orden_paradas" "jsonb" DEFAULT '[]'::"jsonb",
    "activa" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "dias_ruta" "text"[],
    "horario_inicio" time without time zone,
    "horario_fin" time without time zone,
    "clientes_total" integer DEFAULT 0,
    "zona_coordenadas" "jsonb"
);


ALTER TABLE "public"."purificadora_rutas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."qr_cobros" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "codigo_qr" "text" NOT NULL,
    "codigo_verificacion" "text",
    "cobrador_id" "uuid",
    "cliente_id" "uuid",
    "tipo_cobro" "text" NOT NULL,
    "referencia_id" "uuid" NOT NULL,
    "referencia_tabla" "text",
    "monto" numeric(12,2) NOT NULL,
    "concepto" "text" NOT NULL,
    "descripcion_adicional" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_expiracion" timestamp without time zone,
    "cobrador_confirmo" boolean DEFAULT false,
    "cobrador_confirmo_at" timestamp without time zone,
    "cobrador_latitud" numeric(10,8),
    "cobrador_longitud" numeric(11,8),
    "cobrador_direccion" "text",
    "cliente_confirmo" boolean DEFAULT false,
    "cliente_confirmo_at" timestamp without time zone,
    "cliente_latitud" numeric(10,8),
    "cliente_longitud" numeric(11,8),
    "cliente_dispositivo" "text",
    "cliente_ip" "text",
    "foto_comprobante_url" "text",
    "foto_selfie_url" "text",
    "firma_digital_cliente" "text",
    "pago_registrado" boolean DEFAULT false,
    "pago_id" "uuid",
    "notificacion_admin_enviada" boolean DEFAULT false,
    "notificacion_cliente_enviada" boolean DEFAULT false,
    "notas" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."qr_cobros" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."qr_cobros_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "qr_expira_horas" integer DEFAULT 24,
    "codigo_expira_minutos" integer DEFAULT 30,
    "requiere_confirmacion_cliente" boolean DEFAULT true,
    "requiere_gps" boolean DEFAULT true,
    "requiere_foto_comprobante" boolean DEFAULT false,
    "requiere_firma_digital" boolean DEFAULT false,
    "distancia_maxima_metros" integer DEFAULT 500,
    "notificar_admin_inmediato" boolean DEFAULT true,
    "notificar_cliente_recordatorio" boolean DEFAULT true,
    "monto_minimo_qr" numeric(12,2) DEFAULT 0,
    "monto_maximo_sin_foto" numeric(12,2) DEFAULT 5000,
    "hora_inicio_cobros" time without time zone DEFAULT '07:00:00'::time without time zone,
    "hora_fin_cobros" time without time zone DEFAULT '21:00:00'::time without time zone,
    "permitir_fines_semana" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."qr_cobros_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."qr_cobros_escaneos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "qr_cobro_id" "uuid",
    "escaneado_por" "uuid",
    "tipo_usuario" "text",
    "latitud" numeric(10,8),
    "longitud" numeric(11,8),
    "precision_gps" numeric(8,2),
    "direccion_aproximada" "text",
    "dispositivo" "text",
    "sistema_operativo" "text",
    "version_app" "text",
    "ip_address" "text",
    "accion" "text",
    "resultado" "text",
    "mensaje" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."qr_cobros_escaneos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."qr_cobros_estadisticas_diarias" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "fecha" "date" NOT NULL,
    "total_qr_generados" integer DEFAULT 0,
    "total_confirmados" integer DEFAULT 0,
    "total_expirados" integer DEFAULT 0,
    "total_cancelados" integer DEFAULT 0,
    "monto_total_confirmado" numeric(14,2) DEFAULT 0,
    "cobrador_top_id" "uuid",
    "cobrador_top_monto" numeric(14,2),
    "tiempo_promedio_confirmacion" integer,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."qr_cobros_estadisticas_diarias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."qr_cobros_reportes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "qr_cobro_id" "uuid",
    "reportado_por" "uuid",
    "tipo_reportante" "text",
    "tipo_problema" "text" NOT NULL,
    "descripcion" "text" NOT NULL,
    "fotos_evidencia" "text"[],
    "estado" "text" DEFAULT 'abierto'::"text",
    "resuelto_por" "uuid",
    "resolucion" "text",
    "fecha_resolucion" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."qr_cobros_reportes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."recordatorios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid",
    "titulo" "text" NOT NULL,
    "descripcion" "text",
    "fecha_recordatorio" timestamp without time zone NOT NULL,
    "completado" boolean DEFAULT false,
    "fecha_completado" timestamp without time zone,
    "publico" boolean DEFAULT false,
    "tipo" "text" DEFAULT 'general'::"text",
    "referencia_id" "uuid",
    "referencia_tipo" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."recordatorios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."referencias_aval" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "nombre" "text" NOT NULL,
    "telefono" "text" NOT NULL,
    "relacion" "text",
    "verificada" boolean DEFAULT false,
    "fecha_verificacion" timestamp without time zone,
    "notas" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."referencias_aval" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."registros_cobro" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "prestamo_id" "uuid",
    "tanda_id" "uuid",
    "amortizacion_id" "uuid",
    "cliente_id" "uuid" NOT NULL,
    "monto" numeric(15,2) NOT NULL,
    "metodo_pago_id" "uuid",
    "tipo_metodo" character varying(30) DEFAULT 'efectivo'::character varying,
    "estado" character varying(20) DEFAULT 'pendiente'::character varying,
    "referencia_pago" character varying(100),
    "comprobante_url" "text",
    "nota_cliente" "text",
    "nota_operador" "text",
    "latitud" double precision,
    "longitud" double precision,
    "registrado_por" "uuid",
    "confirmado_por" "uuid",
    "fecha_registro" timestamp with time zone DEFAULT "now"(),
    "fecha_confirmacion" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."registros_cobro" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."roles_permisos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "rol_id" "uuid",
    "permiso_id" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."roles_permisos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."seguimiento_judicial" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "expediente_id" "uuid" NOT NULL,
    "fecha" timestamp without time zone DEFAULT "now"(),
    "etapa" "text" NOT NULL,
    "descripcion" "text",
    "documento_url" "text",
    "proximo_paso" "text",
    "fecha_proxima_accion" "date",
    "responsable" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."seguimiento_judicial" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stripe_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "stripe_account_id" "text",
    "modo_produccion" boolean DEFAULT false,
    "cobrar_comision_cliente" boolean DEFAULT false,
    "porcentaje_comision" numeric(5,2) DEFAULT 3.6,
    "notificar_pago_exitoso" boolean DEFAULT true,
    "notificar_pago_fallido" boolean DEFAULT true,
    "permitir_tarjeta" boolean DEFAULT true,
    "permitir_oxxo" boolean DEFAULT false,
    "permitir_spei" boolean DEFAULT true,
    "webhook_secret" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."stripe_config" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stripe_transactions_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "stripe_event_id" "text",
    "stripe_payment_intent_id" "text",
    "stripe_charge_id" "text",
    "stripe_customer_id" "text",
    "tipo_evento" "text" NOT NULL,
    "monto" numeric(12,2),
    "moneda" "text" DEFAULT 'mxn'::"text",
    "comision_stripe" numeric(12,2),
    "monto_neto" numeric(12,2),
    "estado" "text",
    "mensaje_error" "text",
    "cliente_id" "uuid",
    "pago_id" "uuid",
    "webhook_payload" "jsonb",
    "procesado" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."stripe_transactions_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sucursales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "codigo" "text",
    "direccion" "text",
    "telefono" "text",
    "email" "text",
    "latitud" numeric(10,8),
    "longitud" numeric(11,8),
    "horario" "jsonb",
    "meta_mensual" numeric(14,2) DEFAULT 0,
    "activa" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."sucursales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tanda_pagos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tanda_participante_id" "uuid",
    "numero_semana" integer NOT NULL,
    "monto" numeric(12,2) NOT NULL,
    "fecha_programada" "date" NOT NULL,
    "fecha_pago" timestamp with time zone,
    "estado" "text" DEFAULT 'pendiente'::"text",
    "monto_pagado" numeric(12,2) DEFAULT 0,
    "comprobante_url" "text",
    "metodo_pago" "text" DEFAULT 'efectivo'::"text",
    "registrado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tanda_pagos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tanda_participantes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tanda_id" "uuid",
    "cliente_id" "uuid",
    "numero_turno" integer NOT NULL,
    "ha_pagado_cuota_actual" boolean DEFAULT false,
    "ha_recibido_bolsa" boolean DEFAULT false,
    "fecha_recepcion_bolsa" timestamp without time zone,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."tanda_participantes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tandas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "sucursal_id" "uuid",
    "nombre" "text" NOT NULL,
    "monto_por_persona" numeric(12,2) NOT NULL,
    "numero_participantes" integer NOT NULL,
    "turno" integer DEFAULT 1,
    "frecuencia" "text" DEFAULT 'Semanal'::"text",
    "estado" "text" DEFAULT 'activa'::"text",
    "fecha_inicio" timestamp without time zone DEFAULT "now"(),
    "fecha_fin" timestamp without time zone,
    "organizador_id" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "cobro_automatico_stripe" boolean DEFAULT false
);


ALTER TABLE "public"."tandas" OWNER TO "postgres";


COMMENT ON COLUMN "public"."tandas"."cobro_automatico_stripe" IS 'Si TRUE, las aportaciones se cobran automáticamente';



CREATE TABLE IF NOT EXISTS "public"."tandas_avales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tanda_id" "uuid" NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "orden" integer DEFAULT 1,
    "tipo" character varying(50) DEFAULT 'garante'::character varying,
    "porcentaje_responsabilidad" numeric(5,2) DEFAULT 100.00,
    "firma_digital" "text",
    "firmado_at" timestamp with time zone,
    "estado" character varying(20) DEFAULT 'pendiente'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tandas_avales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_alertas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "tipo" "text" NOT NULL,
    "titulo" "text" NOT NULL,
    "mensaje" "text",
    "prioridad" integer DEFAULT 1,
    "leida" boolean DEFAULT false,
    "fecha_lectura" timestamp with time zone,
    "accion_requerida" boolean DEFAULT false,
    "accion_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "negocio_id" "uuid",
    "titular_id" "uuid",
    "transaccion_id" "uuid",
    "fecha_leida" timestamp with time zone
);


ALTER TABLE "public"."tarjetas_alertas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid" NOT NULL,
    "proveedor" "text" DEFAULT 'stripe'::"text" NOT NULL,
    "api_key" "text",
    "api_secret" "text",
    "webhook_secret" "text",
    "api_base_url" "text",
    "webhook_url" "text",
    "account_id" "text",
    "program_id" "text",
    "modo_pruebas" boolean DEFAULT false,
    "limite_diario_default" numeric(14,2) DEFAULT 10000.00,
    "limite_mensual_default" numeric(14,2) DEFAULT 50000.00,
    "limite_transaccion_default" numeric(14,2) DEFAULT 5000.00,
    "tipo_tarjeta_default" "text" DEFAULT 'virtual'::"text",
    "red_default" "text" DEFAULT 'visa'::"text",
    "moneda_default" "text" DEFAULT 'MXN'::"text",
    "nombre_programa" "text" DEFAULT 'Robert Darin Cards'::"text",
    "logo_url" "text",
    "color_tarjeta" "text" DEFAULT '#1E3A8A'::"text",
    "activo" boolean DEFAULT false,
    "verificado" boolean DEFAULT false,
    "fecha_verificacion" timestamp with time zone,
    "verificado_por" "uuid",
    "notas" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "tarjetas_config_proveedor_check" CHECK (("proveedor" = ANY (ARRAY['stripe'::"text", 'rapyd'::"text", 'pomelo'::"text", 'galileo'::"text"]))),
    CONSTRAINT "tarjetas_config_red_default_check" CHECK (("red_default" = ANY (ARRAY['visa'::"text", 'mastercard'::"text", 'amex'::"text"])))
);


ALTER TABLE "public"."tarjetas_config" OWNER TO "postgres";


COMMENT ON TABLE "public"."tarjetas_config" IS 'Configuración de proveedores de tarjetas por negocio (Stripe, Rapyd, etc.)';



COMMENT ON COLUMN "public"."tarjetas_config"."proveedor" IS 'Proveedor activo: stripe, rapyd, pomelo, galileo';



COMMENT ON COLUMN "public"."tarjetas_config"."api_key" IS 'API Key del proveedor (encriptar en producción)';



COMMENT ON COLUMN "public"."tarjetas_config"."api_secret" IS 'API Secret del proveedor (encriptar en producción)';



COMMENT ON COLUMN "public"."tarjetas_config"."modo_pruebas" IS 'true=sandbox/test, false=producción';



CREATE TABLE IF NOT EXISTS "public"."tarjetas_digitales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid" NOT NULL,
    "negocio_id" "uuid",
    "codigo_tarjeta" "text",
    "proveedor" "text" DEFAULT 'stripe'::"text",
    "stripe_cardholder_id" "text",
    "stripe_card_id" "text",
    "external_card_id" "text",
    "ultimos_4" "text",
    "numero_enmascarado" "text",
    "marca" "text" DEFAULT 'visa'::"text",
    "tipo" "text" DEFAULT 'virtual'::"text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "modo_test" boolean DEFAULT false,
    "activa" boolean DEFAULT true,
    "limite_diario" numeric(12,2) DEFAULT 5000,
    "limite_mensual" numeric(12,2) DEFAULT 50000,
    "limite_transaccion" numeric(12,2) DEFAULT 2000,
    "moneda" "text" DEFAULT 'MXN'::"text",
    "fecha_emision" timestamp without time zone,
    "fecha_activacion" timestamp without time zone,
    "fecha_expiracion" "date",
    "fecha_vencimiento" "date",
    "fecha_bloqueo" timestamp without time zone,
    "motivo_bloqueo" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "bloqueada_por" "uuid",
    "ultimos_cuatro" character varying(4),
    "saldo_disponible" numeric(14,2) DEFAULT 0
);


ALTER TABLE "public"."tarjetas_digitales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_digitales_recargas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "monto" numeric(14,2) NOT NULL,
    "metodo_pago" "text" NOT NULL,
    "referencia_pago" "text",
    "comprobante_url" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_verificacion" timestamp with time zone,
    "verificado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tarjetas_digitales_recargas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_digitales_transacciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "tipo" "text" NOT NULL,
    "monto" numeric(14,2) NOT NULL,
    "concepto" "text",
    "descripcion" "text",
    "comercio" "text",
    "referencia" "text",
    "autorizacion" "text",
    "saldo_anterior" numeric(14,2),
    "saldo_posterior" numeric(14,2),
    "estado" "text" DEFAULT 'completada'::"text",
    "fecha" timestamp with time zone DEFAULT "now"(),
    "fecha_procesamiento" timestamp with time zone,
    "ip_origen" "text",
    "dispositivo" "text",
    "ubicacion_lat" numeric(10,8),
    "ubicacion_lng" numeric(11,8),
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tarjetas_digitales_transacciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_landing_config" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "modulo" character varying(50) NOT NULL,
    "titulo" "text",
    "subtitulo" "text",
    "descripcion" "text",
    "imagen_hero_url" "text",
    "cta_texto" character varying(50) DEFAULT 'Solicitar Servicio'::character varying,
    "cta_color" character varying(7) DEFAULT '#00D9FF'::character varying,
    "campos_formulario" "jsonb" DEFAULT '[{"campo": "nombre", "requerido": true}, {"campo": "telefono", "requerido": true}, {"campo": "email", "requerido": false}, {"campo": "direccion", "requerido": false}, {"campo": "mensaje", "requerido": false}]'::"jsonb",
    "ruta_app" "text",
    "activa" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tarjetas_landing_config" OWNER TO "postgres";


COMMENT ON TABLE "public"."tarjetas_landing_config" IS 'Configuración de landing pages por módulo y negocio';



CREATE TABLE IF NOT EXISTS "public"."tarjetas_log" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "accion" "text" NOT NULL,
    "descripcion" "text",
    "ip_origen" "text",
    "dispositivo" "text",
    "user_agent" "text",
    "exito" boolean DEFAULT true,
    "error_mensaje" "text",
    "usuario_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "negocio_id" "uuid",
    "resultado" "text" DEFAULT 'success'::"text"
);


ALTER TABLE "public"."tarjetas_log" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_recargas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "monto" numeric(14,2) NOT NULL,
    "metodo_pago" "text" DEFAULT 'manual'::"text" NOT NULL,
    "referencia_pago" "text",
    "comprobante_url" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_verificacion" timestamp with time zone,
    "verificado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "negocio_id" "uuid",
    "tipo" "text" DEFAULT 'recarga'::"text",
    "fecha_completado" timestamp with time zone,
    "saldo_anterior" numeric(14,2),
    "saldo_posterior" numeric(14,2)
);


ALTER TABLE "public"."tarjetas_recargas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_servicio" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "codigo" character varying(20) DEFAULT "upper"("substring"("md5"(("random"())::"text"), 1, 8)) NOT NULL,
    "nombre_tarjeta" character varying(100) NOT NULL,
    "modulo" character varying(50) NOT NULL,
    "nombre_negocio" character varying(150),
    "slogan" "text",
    "telefono_principal" character varying(20),
    "telefono_secundario" character varying(20),
    "whatsapp" character varying(20),
    "email" character varying(100),
    "direccion" "text",
    "ciudad" character varying(100),
    "logo_url" "text",
    "color_primario" character varying(7) DEFAULT '#00D9FF'::character varying,
    "color_secundario" character varying(7) DEFAULT '#8B5CF6'::character varying,
    "color_fondo" character varying(7) DEFAULT '#0D0D14'::character varying,
    "qr_deep_link" "text",
    "qr_web_fallback" "text",
    "qr_color" character varying(7) DEFAULT '#FFFFFF'::character varying,
    "qr_con_logo" boolean DEFAULT true,
    "servicios" "jsonb" DEFAULT '[]'::"jsonb",
    "horario_atencion" "text",
    "facebook" "text",
    "instagram" "text",
    "tiktok" "text",
    "template" character varying(30) DEFAULT 'profesional'::character varying,
    "activa" boolean DEFAULT true,
    "escaneos_total" integer DEFAULT 0,
    "ultimo_escaneo" timestamp with time zone,
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "tarjetas_servicio_modulo_check" CHECK ((("modulo")::"text" = ANY ((ARRAY['climas'::character varying, 'prestamos'::character varying, 'tandas'::character varying, 'cobranza'::character varying, 'servicios'::character varying, 'general'::character varying])::"text"[]))),
    CONSTRAINT "tarjetas_servicio_template_check" CHECK ((("template")::"text" = ANY ((ARRAY['profesional'::character varying, 'moderno'::character varying, 'minimalista'::character varying, 'clasico'::character varying, 'premium'::character varying, 'corporativo'::character varying])::"text"[])))
);


ALTER TABLE "public"."tarjetas_servicio" OWNER TO "postgres";


COMMENT ON TABLE "public"."tarjetas_servicio" IS 'Tarjetas de presentación/servicio con QR para diferentes módulos de negocio';



CREATE TABLE IF NOT EXISTS "public"."tarjetas_servicio_escaneos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "ip_address" "inet",
    "user_agent" "text",
    "plataforma" character varying(20),
    "ciudad_detectada" character varying(100),
    "pais_detectado" character varying(50),
    "accion" character varying(30) DEFAULT 'ver'::character varying,
    "genero_solicitud" boolean DEFAULT false,
    "solicitud_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "tarjetas_servicio_escaneos_accion_check" CHECK ((("accion")::"text" = ANY ((ARRAY['ver'::character varying, 'llamar'::character varying, 'whatsapp'::character varying, 'email'::character varying, 'mapa'::character varying, 'formulario'::character varying, 'otro'::character varying])::"text"[])))
);


ALTER TABLE "public"."tarjetas_servicio_escaneos" OWNER TO "postgres";


COMMENT ON TABLE "public"."tarjetas_servicio_escaneos" IS 'Registro de todos los escaneos QR de las tarjetas';



CREATE TABLE IF NOT EXISTS "public"."tarjetas_servicio_exportaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "formato" character varying(10) NOT NULL,
    "resolucion" character varying(20),
    "cantidad" integer DEFAULT 1,
    "notas" "text",
    "exportado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "tarjetas_servicio_exportaciones_formato_check" CHECK ((("formato")::"text" = ANY ((ARRAY['png'::character varying, 'pdf'::character varying, 'svg'::character varying, 'print'::character varying])::"text"[])))
);


ALTER TABLE "public"."tarjetas_servicio_exportaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_solicitudes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "solicitante_id" "uuid",
    "tipo_tarjeta" "text" DEFAULT 'virtual'::"text",
    "marca_preferida" "text" DEFAULT 'visa'::"text",
    "limite_solicitado" numeric(14,2),
    "motivo" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "fecha_revision" timestamp with time zone,
    "revisado_por" "uuid",
    "motivo_rechazo" "text",
    "tarjeta_emitida_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tarjetas_solicitudes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_templates" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" character varying(50) NOT NULL,
    "descripcion" "text",
    "preview_url" "text",
    "config" "jsonb" DEFAULT '{}'::"jsonb",
    "modulos_compatibles" "text"[] DEFAULT ARRAY['general'::"text"],
    "es_premium" boolean DEFAULT false,
    "activo" boolean DEFAULT true,
    "orden" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."tarjetas_templates" OWNER TO "postgres";


COMMENT ON TABLE "public"."tarjetas_templates" IS 'Templates de diseño predefinidos para las tarjetas';



CREATE TABLE IF NOT EXISTS "public"."tarjetas_titulares" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "nombre_completo" "text" NOT NULL,
    "email" "text",
    "telefono" "text",
    "direccion" "text",
    "ciudad" "text",
    "estado" "text",
    "codigo_postal" "text",
    "pais" "text" DEFAULT 'México'::"text",
    "fecha_nacimiento" "date",
    "curp" "text",
    "rfc" "text",
    "es_principal" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "external_id" "text",
    "kyc_status" "text" DEFAULT 'pendiente'::"text",
    "activo" boolean DEFAULT true,
    "usuario_id" "uuid",
    "empleado_id" "uuid",
    "tipo_persona" "text" DEFAULT 'fisica'::"text",
    "nombre" "text",
    "apellido_paterno" "text",
    "apellido_materno" "text",
    "razon_social" "text",
    "ine_clave" "text",
    "calle" "text",
    "numero_exterior" "text",
    "numero_interior" "text",
    "colonia" "text",
    "municipio" "text",
    "lugar_nacimiento" "text",
    "nacionalidad" "text" DEFAULT 'Mexicana'::"text",
    "kyc_nivel" integer DEFAULT 0,
    "kyc_fecha_aprobacion" timestamp with time zone,
    "kyc_motivo_rechazo" "text",
    "documento_ine_frontal_url" "text",
    "documento_ine_reverso_url" "text",
    "documento_comprobante_domicilio_url" "text",
    "selfie_url" "text",
    "bloqueado" boolean DEFAULT false,
    "motivo_bloqueo" "text"
);


ALTER TABLE "public"."tarjetas_titulares" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_transacciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid",
    "tipo" "text" NOT NULL,
    "monto" numeric(14,2) NOT NULL,
    "concepto" "text",
    "comercio" "text",
    "referencia" "text",
    "autorizacion" "text",
    "saldo_anterior" numeric(14,2),
    "saldo_posterior" numeric(14,2),
    "estado" "text" DEFAULT 'completada'::"text",
    "fecha_procesamiento" timestamp with time zone,
    "ip_origen" "text",
    "dispositivo" "text",
    "ubicacion_lat" numeric(10,8),
    "ubicacion_lng" numeric(11,8),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "negocio_id" "uuid",
    "external_transaction_id" "text",
    "monto_original" numeric(14,2),
    "moneda" "text" DEFAULT 'MXN'::"text",
    "moneda_original" "text",
    "tipo_cambio" numeric(12,6),
    "comercio_nombre" "text",
    "comercio_id" "text",
    "comercio_categoria" "text",
    "comercio_ciudad" "text",
    "comercio_pais" "text",
    "codigo_autorizacion" "text",
    "motivo_rechazo" "text",
    "codigo_rechazo" "text",
    "fecha_transaccion" timestamp with time zone DEFAULT "now"(),
    "fecha_liquidacion" timestamp with time zone
);


ALTER TABLE "public"."tarjetas_transacciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tarjetas_virtuales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "numero_tarjeta" "text",
    "cvv_hash" "text",
    "fecha_expiracion" "date" NOT NULL,
    "saldo" numeric(14,2) DEFAULT 0,
    "saldo_maximo" numeric(14,2) DEFAULT 50000,
    "estado" "text" DEFAULT 'activa'::"text",
    "pin_hash" "text",
    "intentos_fallidos" integer DEFAULT 0,
    "ultimo_uso" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "titular_id" "uuid",
    "external_card_id" "text",
    "numero_tarjeta_masked" "text",
    "ultimos_4_digitos" "text",
    "tipo" "text" DEFAULT 'virtual'::"text",
    "red" "text" DEFAULT 'visa'::"text",
    "categoria" "text" DEFAULT 'debito'::"text",
    "nombre_tarjeta" "text",
    "moneda" "text" DEFAULT 'MXN'::"text",
    "saldo_disponible" numeric(14,2) DEFAULT 0,
    "saldo_retenido" numeric(14,2) DEFAULT 0,
    "limite_diario" numeric(14,2) DEFAULT 10000,
    "limite_mensual" numeric(14,2) DEFAULT 50000,
    "limite_transaccion" numeric(14,2) DEFAULT 5000,
    "uso_diario" numeric(14,2) DEFAULT 0,
    "uso_mensual" numeric(14,2) DEFAULT 0,
    "solo_nacional" boolean DEFAULT false,
    "permitir_ecommerce" boolean DEFAULT true,
    "permitir_atm" boolean DEFAULT false,
    "permitir_internacional" boolean DEFAULT true,
    "motivo_bloqueo" "text",
    "fecha_bloqueo" timestamp with time zone,
    "bloqueado_por" "uuid",
    "etiqueta" "text",
    "notas" "text",
    "expires_at" timestamp with time zone
);


ALTER TABLE "public"."tarjetas_virtuales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."temas_app" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" character varying(50) NOT NULL,
    "descripcion" "text",
    "color_primario" character varying(10) DEFAULT '#1E1E2C'::character varying NOT NULL,
    "color_secundario" character varying(10) DEFAULT '#2D2D44'::character varying NOT NULL,
    "color_acento" character varying(10) DEFAULT '#00BCD4'::character varying NOT NULL,
    "color_texto" character varying(10) DEFAULT '#FFFFFF'::character varying,
    "activo" boolean DEFAULT false,
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."temas_app" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transacciones_tarjeta" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tarjeta_id" "uuid" NOT NULL,
    "stripe_transaction_id" "text",
    "tipo" "text" NOT NULL,
    "monto" numeric(12,2) NOT NULL,
    "moneda" "text" DEFAULT 'MXN'::"text",
    "comercio" "text",
    "categoria" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "motivo_rechazo" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."transacciones_tarjeta" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usuarios" (
    "id" "uuid" NOT NULL,
    "email" "text" NOT NULL,
    "nombre_completo" "text",
    "telefono" "text",
    "foto_url" "text",
    "created_at" timestamp without time zone DEFAULT "now"(),
    "updated_at" timestamp without time zone DEFAULT "now"(),
    "activo" boolean DEFAULT true,
    "ultimo_acceso" timestamp with time zone,
    "dispositivo_actual" "text",
    "ip_ultimo_acceso" "text"
);


ALTER TABLE "public"."usuarios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usuarios_negocios" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid",
    "negocio_id" "uuid",
    "rol_negocio" "text" DEFAULT 'admin'::"text",
    "permisos" "jsonb" DEFAULT '{}'::"jsonb",
    "activo" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."usuarios_negocios" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usuarios_roles" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid",
    "rol_id" "uuid",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."usuarios_roles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."usuarios_sucursales" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "usuario_id" "uuid" NOT NULL,
    "sucursal_id" "uuid" NOT NULL,
    "rol_en_sucursal" "text" DEFAULT 'empleado'::"text",
    "es_principal" boolean DEFAULT false,
    "activo" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."usuarios_sucursales" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_colaboradores_completos" AS
 SELECT "c"."id",
    "c"."negocio_id",
    "c"."usuario_id",
    "c"."auth_uid",
    "c"."tipo_id",
    "c"."nombre",
    "c"."email",
    "c"."telefono",
    "c"."tiene_cuenta",
    "c"."permisos_custom",
    "c"."es_inversionista",
    "c"."monto_invertido",
    "c"."porcentaje_participacion",
    "c"."fecha_inversion",
    "c"."rendimiento_pactado",
    "c"."estado",
    "c"."fecha_inicio",
    "c"."fecha_fin",
    "c"."notas",
    "c"."created_at",
    "c"."updated_at",
    "ct"."codigo" AS "tipo_codigo",
    "ct"."nombre" AS "tipo_nombre",
    "ct"."nivel_acceso",
    "ct"."puede_ver_finanzas",
    "ct"."puede_ver_clientes",
    "ct"."puede_ver_prestamos",
    "ct"."puede_operar",
    "ct"."puede_aprobar",
    "ct"."puede_emitir_facturas",
    "ct"."puede_ver_reportes",
    "n"."nombre" AS "negocio_nombre",
    "u"."nombre_completo" AS "usuario_nombre"
   FROM ((("public"."colaboradores" "c"
     LEFT JOIN "public"."colaborador_tipos" "ct" ON (("ct"."id" = "c"."tipo_id")))
     LEFT JOIN "public"."negocios" "n" ON (("n"."id" = "c"."negocio_id")))
     LEFT JOIN "public"."usuarios" "u" ON (("u"."id" = "c"."usuario_id")));


ALTER VIEW "public"."v_colaboradores_completos" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_facturas_completas" AS
 SELECT "f"."id",
    "f"."negocio_id",
    "f"."emisor_id",
    "f"."cliente_fiscal_id",
    "f"."tipo_comprobante",
    "f"."serie",
    "f"."folio",
    "f"."uuid_fiscal",
    "f"."fecha_emision",
    "f"."fecha_timbrado",
    "f"."fecha_cancelacion",
    "f"."modulo_origen",
    "f"."referencia_origen_id",
    "f"."referencia_tipo",
    "f"."subtotal",
    "f"."descuento",
    "f"."iva",
    "f"."isr_retenido",
    "f"."iva_retenido",
    "f"."ieps",
    "f"."total",
    "f"."moneda",
    "f"."tipo_cambio",
    "f"."forma_pago",
    "f"."metodo_pago",
    "f"."condiciones_pago",
    "f"."uso_cfdi",
    "f"."lugar_expedicion",
    "f"."confirmacion",
    "f"."estado",
    "f"."motivo_cancelacion",
    "f"."uuid_sustitucion",
    "f"."xml_content",
    "f"."pdf_url",
    "f"."pac_response",
    "f"."cadena_original",
    "f"."sello_cfdi",
    "f"."sello_sat",
    "f"."certificado_sat",
    "f"."email_enviado",
    "f"."fecha_email",
    "f"."creado_por",
    "f"."notas",
    "f"."created_at",
    "f"."updated_at",
    "e"."rfc" AS "emisor_rfc",
    "e"."razon_social" AS "emisor_razon_social",
    "e"."regimen_fiscal" AS "emisor_regimen",
    "c"."rfc" AS "cliente_rfc",
    "c"."razon_social" AS "cliente_razon_social",
    "c"."email" AS "cliente_email",
    COALESCE(( SELECT "count"(*) AS "count"
           FROM "public"."factura_conceptos"
          WHERE ("factura_conceptos"."factura_id" = "f"."id")), (0)::bigint) AS "num_conceptos",
        CASE
            WHEN (("f"."estado")::"text" = 'borrador'::"text") THEN 'Borrador'::character varying
            WHEN (("f"."estado")::"text" = 'timbrada'::"text") THEN 'Timbrada'::character varying
            WHEN (("f"."estado")::"text" = 'enviada'::"text") THEN 'Enviada'::character varying
            WHEN (("f"."estado")::"text" = 'pagada'::"text") THEN 'Pagada'::character varying
            WHEN (("f"."estado")::"text" = 'cancelada'::"text") THEN 'Cancelada'::character varying
            ELSE "f"."estado"
        END AS "estado_display",
        CASE "f"."tipo_comprobante"
            WHEN 'I'::"text" THEN 'Ingreso'::character varying
            WHEN 'E'::"text" THEN 'Egreso'::character varying
            WHEN 'T'::"text" THEN 'Traslado'::character varying
            WHEN 'N'::"text" THEN 'Nómina'::character varying
            WHEN 'P'::"text" THEN 'Pago'::character varying
            ELSE "f"."tipo_comprobante"
        END AS "tipo_display"
   FROM (("public"."facturas" "f"
     LEFT JOIN "public"."facturacion_emisores" "e" ON (("e"."id" = "f"."emisor_id")))
     LEFT JOIN "public"."facturacion_clientes" "c" ON (("c"."id" = "f"."cliente_fiscal_id")));


ALTER VIEW "public"."v_facturas_completas" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_nice_arbol_equipo" AS
 WITH RECURSIVE "arbol" AS (
         SELECT "v"."id",
            "v"."negocio_id",
            "v"."nombre",
            "v"."codigo_vendedora",
            "v"."patrocinadora_id",
            "v"."nivel_id",
            "v"."ventas_mes",
            "v"."activa",
            0 AS "nivel_profundidad",
            "v"."nombre" AS "ruta",
            ARRAY["v"."id"] AS "jerarquia"
           FROM "public"."nice_vendedoras" "v"
          WHERE ("v"."patrocinadora_id" IS NULL)
        UNION ALL
         SELECT "v"."id",
            "v"."negocio_id",
            "v"."nombre",
            "v"."codigo_vendedora",
            "v"."patrocinadora_id",
            "v"."nivel_id",
            "v"."ventas_mes",
            "v"."activa",
            ("a_1"."nivel_profundidad" + 1),
            (("a_1"."ruta" || ' > '::"text") || "v"."nombre"),
            ("a_1"."jerarquia" || "v"."id")
           FROM ("public"."nice_vendedoras" "v"
             JOIN "arbol" "a_1" ON (("v"."patrocinadora_id" = "a_1"."id")))
          WHERE (NOT ("v"."id" = ANY ("a_1"."jerarquia")))
        )
 SELECT "a"."id",
    "a"."negocio_id",
    "a"."nombre",
    "a"."codigo_vendedora",
    "a"."patrocinadora_id",
    "a"."nivel_id",
    "a"."ventas_mes",
    "a"."activa",
    "a"."nivel_profundidad",
    "a"."ruta",
    "a"."jerarquia",
    "n"."nombre" AS "nivel_nombre",
    "n"."color" AS "nivel_color",
    "p"."nombre" AS "patrocinadora_nombre",
    ( SELECT "count"(*) AS "count"
           FROM "public"."nice_vendedoras" "sub"
          WHERE ("sub"."patrocinadora_id" = "a"."id")) AS "equipo_directo"
   FROM (("arbol" "a"
     LEFT JOIN "public"."nice_niveles" "n" ON (("n"."id" = "a"."nivel_id")))
     LEFT JOIN "public"."nice_vendedoras" "p" ON (("p"."id" = "a"."patrocinadora_id")));


ALTER VIEW "public"."v_nice_arbol_equipo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_nice_clientes_completo" AS
 SELECT "c"."id",
    "c"."negocio_id",
    "c"."vendedora_id",
    "c"."auth_uid",
    "c"."nombre",
    "c"."email",
    "c"."telefono",
    "c"."whatsapp",
    "c"."direccion",
    "c"."ciudad",
    "c"."fecha_nacimiento",
    "c"."preferencias",
    "c"."total_compras",
    "c"."puntos",
    "c"."nivel_cliente",
    "c"."notas",
    "c"."activo",
    "c"."created_at",
    "c"."updated_at",
    "v"."nombre" AS "vendedora_nombre",
    "v"."codigo_vendedora",
    ( SELECT "count"(*) AS "count"
           FROM "public"."nice_pedidos" "p"
          WHERE ("p"."cliente_id" = "c"."id")) AS "total_pedidos",
    ( SELECT "max"("p"."fecha_pedido") AS "max"
           FROM "public"."nice_pedidos" "p"
          WHERE ("p"."cliente_id" = "c"."id")) AS "ultima_compra"
   FROM ("public"."nice_clientes" "c"
     LEFT JOIN "public"."nice_vendedoras" "v" ON (("v"."id" = "c"."vendedora_id")));


ALTER VIEW "public"."v_nice_clientes_completo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_nice_comisiones_completo" AS
 SELECT "c"."id",
    "c"."vendedora_id",
    "c"."pedido_id",
    "c"."tipo",
    "c"."monto",
    "c"."porcentaje",
    "c"."descripcion",
    "c"."estado",
    "c"."fecha_pago",
    "c"."created_at",
    "v"."nombre" AS "vendedora_nombre",
    "v"."codigo_vendedora",
    "p"."folio" AS "pedido_folio",
    "p"."total" AS "pedido_total"
   FROM (("public"."nice_comisiones" "c"
     LEFT JOIN "public"."nice_vendedoras" "v" ON (("v"."id" = "c"."vendedora_id")))
     LEFT JOIN "public"."nice_pedidos" "p" ON (("p"."id" = "c"."pedido_id")));


ALTER VIEW "public"."v_nice_comisiones_completo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_nice_inventario_vendedora" AS
 SELECT "i"."id",
    "i"."vendedora_id",
    "i"."producto_id",
    "i"."cantidad",
    "i"."cantidad_vendida",
    "i"."costo_unitario",
    "i"."fecha_asignacion",
    "i"."created_at",
    "v"."nombre" AS "vendedora_nombre",
    "v"."codigo_vendedora",
    "p"."nombre" AS "producto_nombre",
    "p"."sku" AS "producto_sku",
    "p"."precio_catalogo",
    "p"."precio_vendedora",
    "p"."imagen_url" AS "producto_imagen",
    "cat"."nombre" AS "categoria_nombre",
    ("i"."cantidad" - "i"."cantidad_vendida") AS "disponible",
    (("i"."cantidad")::numeric * "i"."costo_unitario") AS "valor_consignacion"
   FROM ((("public"."nice_inventario_vendedora" "i"
     LEFT JOIN "public"."nice_vendedoras" "v" ON (("v"."id" = "i"."vendedora_id")))
     LEFT JOIN "public"."nice_productos" "p" ON (("p"."id" = "i"."producto_id")))
     LEFT JOIN "public"."nice_categorias" "cat" ON (("cat"."id" = "p"."categoria_id")));


ALTER VIEW "public"."v_nice_inventario_vendedora" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_nice_pedidos_completo" AS
 SELECT "p"."id",
    "p"."negocio_id",
    "p"."vendedora_id",
    "p"."cliente_id",
    "p"."folio",
    "p"."fecha_pedido",
    "p"."fecha_entrega_estimada",
    "p"."fecha_entrega_real",
    "p"."subtotal",
    "p"."descuento",
    "p"."total",
    "p"."metodo_pago",
    "p"."estado",
    "p"."direccion_entrega",
    "p"."notas",
    "p"."comision_vendedora",
    "p"."comision_pagada",
    "p"."created_at",
    "p"."updated_at",
    "v"."nombre" AS "vendedora_nombre",
    "v"."codigo_vendedora",
    "v"."telefono" AS "vendedora_telefono",
    "c"."nombre" AS "cliente_nombre",
    "c"."telefono" AS "cliente_telefono",
    "c"."direccion" AS "cliente_direccion",
    ( SELECT "count"(*) AS "count"
           FROM "public"."nice_pedido_items" "i"
          WHERE ("i"."pedido_id" = "p"."id")) AS "total_items",
    ( SELECT COALESCE("sum"("i"."cantidad"), (0)::bigint) AS "coalesce"
           FROM "public"."nice_pedido_items" "i"
          WHERE ("i"."pedido_id" = "p"."id")) AS "total_piezas"
   FROM (("public"."nice_pedidos" "p"
     LEFT JOIN "public"."nice_vendedoras" "v" ON (("v"."id" = "p"."vendedora_id")))
     LEFT JOIN "public"."nice_clientes" "c" ON (("c"."id" = "p"."cliente_id")));


ALTER VIEW "public"."v_nice_pedidos_completo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_nice_productos_completo" AS
 SELECT "p"."id",
    "p"."negocio_id",
    "p"."catalogo_id",
    "p"."categoria_id",
    "p"."sku",
    "p"."codigo_pagina" AS "pagina_catalogo",
    "p"."nombre",
    "p"."descripcion",
    "p"."material",
    "p"."precio_catalogo",
    COALESCE("p"."precio_vendedora", ("p"."precio_catalogo" * 0.70)) AS "precio_vendedora",
    COALESCE("p"."costo", ("p"."precio_catalogo" * 0.45)) AS "costo",
    "p"."stock",
    "p"."stock_minimo",
    "p"."imagen_url" AS "imagen_principal_url",
    "p"."imagenes_adicionales",
    "p"."destacado" AS "es_destacado",
    "p"."nuevo" AS "es_nuevo",
    false AS "es_oferta",
    NULL::numeric AS "precio_oferta",
    "p"."activo",
    "p"."created_at",
    "p"."updated_at",
    "c"."nombre" AS "categoria_nombre",
    "c"."color" AS "categoria_color",
    "c"."icono" AS "categoria_icono",
    "cat"."nombre" AS "catalogo_nombre",
    "cat"."codigo" AS "catalogo_codigo",
        CASE
            WHEN ("p"."stock" > 0) THEN true
            ELSE false
        END AS "disponible",
    ("p"."precio_catalogo" - COALESCE("p"."precio_vendedora", ("p"."precio_catalogo" * 0.70))) AS "ganancia_vendedora",
    0 AS "veces_vendido"
   FROM (("public"."nice_productos" "p"
     LEFT JOIN "public"."nice_categorias" "c" ON (("c"."id" = "p"."categoria_id")))
     LEFT JOIN "public"."nice_catalogos" "cat" ON (("cat"."id" = "p"."catalogo_id")));


ALTER VIEW "public"."v_nice_productos_completo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_nice_vendedoras_completo" AS
 SELECT "v"."id",
    "v"."negocio_id",
    "v"."auth_uid",
    "v"."nivel_id",
    "v"."patrocinadora_id",
    "v"."codigo_vendedora",
    "v"."nombre",
    "v"."email",
    "v"."telefono",
    "v"."whatsapp",
    "v"."direccion",
    "v"."ciudad",
    "v"."fecha_nacimiento",
    "v"."ine_url",
    "v"."foto_url",
    "v"."banco",
    "v"."clabe",
    "v"."numero_cuenta",
    "v"."fecha_ingreso",
    "v"."ventas_totales",
    "v"."ventas_mes",
    "v"."comisiones_pendientes",
    "v"."equipo_total",
    "v"."meta_mensual",
    "v"."notas",
    "v"."activa",
    "v"."created_at",
    "v"."updated_at",
    "n"."nombre" AS "nivel_nombre",
    "n"."codigo" AS "nivel_codigo",
    "n"."comision_ventas" AS "nivel_comision",
    "n"."comision_equipo" AS "nivel_comision_equipo",
    "n"."descuento_porcentaje" AS "nivel_descuento",
    "n"."color" AS "nivel_color",
    "n"."ventas_minimas_mes" AS "nivel_meta",
    "p"."nombre" AS "patrocinadora_nombre",
    "p"."codigo_vendedora" AS "patrocinadora_codigo",
    ( SELECT "count"(*) AS "count"
           FROM "public"."nice_vendedoras" "sub"
          WHERE ("sub"."patrocinadora_id" = "v"."id")) AS "equipo_directo",
    ( SELECT COALESCE("sum"("ped"."total"), (0)::numeric) AS "coalesce"
           FROM "public"."nice_pedidos" "ped"
          WHERE (("ped"."vendedora_id" = "v"."id") AND ("ped"."estado" = 'entregado'::"text") AND (EXTRACT(month FROM "ped"."fecha_pedido") = EXTRACT(month FROM CURRENT_DATE)))) AS "ventas_mes_actual",
    ( SELECT "count"(*) AS "count"
           FROM "public"."nice_pedidos" "ped"
          WHERE (("ped"."vendedora_id" = "v"."id") AND ("ped"."estado" = 'pendiente'::"text"))) AS "pedidos_pendientes",
    ( SELECT COALESCE("sum"("com"."monto"), (0)::numeric) AS "coalesce"
           FROM "public"."nice_comisiones" "com"
          WHERE (("com"."vendedora_id" = "v"."id") AND ("com"."estado" = 'pendiente'::"text"))) AS "comisiones_por_cobrar"
   FROM (("public"."nice_vendedoras" "v"
     LEFT JOIN "public"."nice_niveles" "n" ON (("n"."id" = "v"."nivel_id")))
     LEFT JOIN "public"."nice_vendedoras" "p" ON (("p"."id" = "v"."patrocinadora_id")));


ALTER VIEW "public"."v_nice_vendedoras_completo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_nice_vendedoras_stats" AS
 SELECT "id",
    "negocio_id",
    "auth_uid",
    "nivel_id",
    "patrocinadora_id",
    "codigo_vendedora",
    "nombre",
    "email",
    "telefono",
    "whatsapp",
    "direccion",
    "ciudad",
    "fecha_nacimiento",
    "ine_url",
    "foto_url",
    "banco",
    "clabe",
    "numero_cuenta",
    "fecha_ingreso",
    "ventas_totales",
    "ventas_mes",
    "comisiones_pendientes",
    "equipo_total",
    "meta_mensual",
    "notas",
    "activa",
    "created_at",
    "updated_at",
    "nivel_nombre",
    "nivel_codigo",
    "nivel_comision",
    "nivel_comision_equipo",
    "nivel_descuento",
    "nivel_color",
    "nivel_meta",
    "patrocinadora_nombre",
    "patrocinadora_codigo",
    "equipo_directo",
    "ventas_mes_actual",
    "pedidos_pendientes",
    "comisiones_por_cobrar"
   FROM "public"."v_nice_vendedoras_completo";


ALTER VIEW "public"."v_nice_vendedoras_stats" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_qr_cobros_hoy" AS
 SELECT "negocio_id",
    "count"(*) FILTER (WHERE ("estado" = 'confirmado'::"text")) AS "cobros_confirmados",
    "count"(*) FILTER (WHERE ("estado" = 'pendiente'::"text")) AS "cobros_pendientes",
    "count"(*) FILTER (WHERE ("estado" = 'expirado'::"text")) AS "cobros_expirados",
    "sum"("monto") FILTER (WHERE ("estado" = 'confirmado'::"text")) AS "monto_confirmado",
    "sum"("monto") FILTER (WHERE ("estado" = 'pendiente'::"text")) AS "monto_pendiente"
   FROM "public"."qr_cobros"
  WHERE ("date"("created_at") = CURRENT_DATE)
  GROUP BY "negocio_id";


ALTER VIEW "public"."v_qr_cobros_hoy" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_qr_cobros_pendientes" AS
 SELECT "qr"."id",
    "qr"."codigo_qr",
    "qr"."monto",
    "qr"."concepto",
    "qr"."tipo_cobro",
    "qr"."estado",
    "qr"."created_at",
    "qr"."fecha_expiracion",
    "qr"."cobrador_confirmo",
    "qr"."cliente_confirmo",
    "c"."nombre" AS "cliente_nombre",
    "c"."telefono" AS "cliente_telefono",
    "u"."nombre_completo" AS "cobrador_nombre",
    "n"."nombre" AS "negocio_nombre",
        CASE
            WHEN ("qr"."fecha_expiracion" < "now"()) THEN 'expirado'::"text"
            WHEN ("qr"."cobrador_confirmo" AND "qr"."cliente_confirmo") THEN 'completado'::"text"
            WHEN "qr"."cobrador_confirmo" THEN 'esperando_cliente'::"text"
            WHEN "qr"."cliente_confirmo" THEN 'esperando_cobrador'::"text"
            ELSE 'pendiente_ambos'::"text"
        END AS "estado_detallado"
   FROM ((("public"."qr_cobros" "qr"
     LEFT JOIN "public"."clientes" "c" ON (("c"."id" = "qr"."cliente_id")))
     LEFT JOIN "public"."usuarios" "u" ON (("u"."id" = "qr"."cobrador_id")))
     LEFT JOIN "public"."negocios" "n" ON (("n"."id" = "qr"."negocio_id")))
  WHERE ("qr"."estado" = 'pendiente'::"text")
  ORDER BY "qr"."created_at" DESC;


ALTER VIEW "public"."v_qr_cobros_pendientes" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_resumen_cobros_metodo" AS
 SELECT "negocio_id",
    "date_trunc"('month'::"text", "fecha_pago") AS "mes",
    "metodo_pago",
    "count"(*) AS "total_transacciones",
    "sum"("monto") AS "monto_total",
    "avg"("monto") AS "promedio_transaccion"
   FROM "public"."pagos"
  WHERE ("fecha_pago" IS NOT NULL)
  GROUP BY "negocio_id", ("date_trunc"('month'::"text", "fecha_pago")), "metodo_pago"
  ORDER BY ("date_trunc"('month'::"text", "fecha_pago")) DESC, ("sum"("monto")) DESC;


ALTER VIEW "public"."v_resumen_cobros_metodo" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_tarjetas_cliente" AS
 SELECT "t"."id",
    "t"."cliente_id",
    "t"."negocio_id",
    "t"."codigo_tarjeta",
    "t"."ultimos_4",
    "t"."marca",
    "t"."tipo",
    "t"."estado",
    "t"."saldo_disponible",
    "t"."limite_diario",
    "t"."limite_mensual",
    "t"."fecha_vencimiento",
    "t"."activa",
    "t"."created_at",
    "c"."nombre" AS "cliente_nombre",
    "c"."telefono" AS "cliente_telefono",
    "c"."usuario_id" AS "cliente_usuario_id"
   FROM ("public"."tarjetas_digitales" "t"
     LEFT JOIN "public"."clientes" "c" ON (("t"."cliente_id" = "c"."id")))
  WHERE ("t"."activa" = true);


ALTER VIEW "public"."v_tarjetas_cliente" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_tarjetas_completas" AS
 SELECT "tv"."id",
    "tv"."negocio_id",
    "tv"."titular_id",
    "tv"."external_card_id",
    "tv"."numero_tarjeta_masked",
    "tv"."ultimos_4_digitos",
    "tv"."fecha_expiracion",
    "tv"."tipo",
    "tv"."red",
    "tv"."categoria",
    "tv"."nombre_tarjeta",
    "tv"."moneda",
    "tv"."saldo_disponible",
    "tv"."saldo_retenido",
    "tv"."limite_diario",
    "tv"."limite_mensual",
    "tv"."limite_transaccion",
    "tv"."uso_diario",
    "tv"."uso_mensual",
    "tv"."solo_nacional",
    "tv"."permitir_ecommerce",
    "tv"."permitir_atm",
    "tv"."permitir_internacional",
    "tv"."estado",
    "tv"."motivo_bloqueo",
    "tv"."fecha_bloqueo",
    "tv"."etiqueta",
    "tv"."notas",
    "tv"."created_at",
    "tv"."expires_at",
    "t"."nombre" AS "titular_nombre",
    "t"."apellido_paterno" AS "titular_apellido",
    "t"."email" AS "titular_email",
    "t"."telefono" AS "titular_telefono",
    "t"."kyc_status" AS "titular_kyc_status"
   FROM ("public"."tarjetas_virtuales" "tv"
     LEFT JOIN "public"."tarjetas_titulares" "t" ON (("t"."id" = "tv"."titular_id")));


ALTER VIEW "public"."v_tarjetas_completas" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."v_transacciones_completas" AS
 SELECT "tt"."id",
    "tv"."negocio_id",
    "tt"."tarjeta_id",
    "tt"."external_transaction_id",
    "tt"."tipo",
    "tt"."estado",
    "tt"."monto",
    "tt"."monto_original",
    COALESCE("tt"."moneda", "tv"."moneda", 'MXN'::"text") AS "moneda",
    "tt"."moneda_original",
    "tt"."tipo_cambio",
    COALESCE("tt"."comercio_nombre", "tt"."comercio") AS "comercio_nombre",
    "tt"."comercio_id",
    "tt"."comercio_categoria",
    "tt"."comercio_ciudad",
    "tt"."comercio_pais",
    COALESCE("tt"."codigo_autorizacion", "tt"."autorizacion") AS "codigo_autorizacion",
    "tt"."referencia",
    "tt"."motivo_rechazo",
    "tt"."codigo_rechazo",
    "tt"."saldo_anterior",
    "tt"."saldo_posterior",
    COALESCE("tt"."fecha_transaccion", "tt"."created_at") AS "fecha_transaccion",
    "tt"."fecha_liquidacion",
    "tt"."created_at",
    "tv"."numero_tarjeta_masked",
    "tv"."nombre_tarjeta",
    "tv"."etiqueta" AS "tarjeta_etiqueta",
    "t"."nombre" AS "titular_nombre",
    "t"."email" AS "titular_email"
   FROM (("public"."tarjetas_transacciones" "tt"
     JOIN "public"."tarjetas_virtuales" "tv" ON (("tv"."id" = "tt"."tarjeta_id")))
     LEFT JOIN "public"."tarjetas_titulares" "t" ON (("t"."id" = "tv"."titular_id")));


ALTER VIEW "public"."v_transacciones_completas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."validaciones_aval" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "puntaje_riesgo" integer DEFAULT 0,
    "nivel_riesgo" integer DEFAULT 1,
    "alertas" "jsonb" DEFAULT '[]'::"jsonb",
    "aprobado" boolean DEFAULT false,
    "revision_manual" boolean DEFAULT false,
    "revisado_por" "uuid",
    "fecha_revision" timestamp without time zone,
    "notas_revision" "text",
    "fecha" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."validaciones_aval" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."variantes_arquilado" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "nombre" "text" NOT NULL,
    "descripcion" "text" NOT NULL,
    "capital_al_final" boolean DEFAULT true,
    "permite_renovacion" boolean DEFAULT false,
    "intereses_acumulados" boolean DEFAULT false,
    "permite_abonos_capital" boolean DEFAULT false,
    "interes_minimo" numeric(5,2) DEFAULT 1.0,
    "interes_maximo" numeric(5,2) DEFAULT 20.0,
    "frecuencias_permitidas" "text"[] DEFAULT ARRAY['Semanal'::"text", 'Quincenal'::"text", 'Mensual'::"text"],
    "monto_minimo" numeric(12,2) DEFAULT 1000,
    "monto_maximo" numeric(12,2) DEFAULT 1000000,
    "plazo_minimo_periodos" integer DEFAULT 4,
    "plazo_maximo_periodos" integer DEFAULT 52,
    "activo" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."variantes_arquilado" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_categorias" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "imagen_url" "text",
    "orden" integer DEFAULT 0,
    "activa" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_categorias" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_cliente_contactos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "nombre" "text" NOT NULL,
    "cargo" "text",
    "telefono" "text",
    "email" "text",
    "es_principal" boolean DEFAULT false,
    "notas" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_cliente_contactos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_cliente_creditos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "limite_credito" numeric(14,2) DEFAULT 0,
    "credito_utilizado" numeric(14,2) DEFAULT 0,
    "credito_disponible" numeric(14,2) DEFAULT 0,
    "dias_credito" integer DEFAULT 30,
    "estado" "text" DEFAULT 'activo'::"text",
    "ultima_evaluacion" "date",
    "historial_pagos_score" integer DEFAULT 100,
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_cliente_creditos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_cliente_documentos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "tipo_documento" "text" NOT NULL,
    "nombre" "text" NOT NULL,
    "url" "text" NOT NULL,
    "tamano_bytes" integer,
    "verificado" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_cliente_documentos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_cliente_notas" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "cliente_id" "uuid",
    "nota" "text" NOT NULL,
    "tipo" "text" DEFAULT 'general'::"text",
    "creado_por" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_cliente_notas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_clientes" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "vendedor_id" "uuid",
    "auth_uid" "uuid",
    "codigo_cliente" "text",
    "nombre" "text" NOT NULL,
    "rfc" "text",
    "email" "text",
    "telefono" "text",
    "whatsapp" "text",
    "direccion" "text",
    "ciudad" "text",
    "codigo_postal" "text",
    "tipo" "text" DEFAULT 'minorista'::"text",
    "limite_credito" numeric(14,2) DEFAULT 0,
    "saldo_pendiente" numeric(14,2) DEFAULT 0,
    "dias_credito" integer DEFAULT 0,
    "descuento_default" numeric(5,2) DEFAULT 0,
    "total_compras" numeric(14,2) DEFAULT 0,
    "notas" "text",
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_clientes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_cotizaciones" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "vendedor_id" "uuid",
    "folio" "text",
    "fecha" "date" DEFAULT CURRENT_DATE,
    "vigencia_dias" integer DEFAULT 15,
    "subtotal" numeric(14,2) DEFAULT 0,
    "descuento" numeric(14,2) DEFAULT 0,
    "iva" numeric(14,2) DEFAULT 0,
    "total" numeric(14,2) DEFAULT 0,
    "estado" "text" DEFAULT 'vigente'::"text",
    "convertida_pedido_id" "uuid",
    "notas" "text",
    "condiciones" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_cotizaciones" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_pagos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pedido_id" "uuid",
    "monto" numeric(14,2) NOT NULL,
    "metodo_pago" "text" DEFAULT 'efectivo'::"text",
    "referencia" "text",
    "comprobante_url" "text",
    "fecha_pago" timestamp with time zone DEFAULT "now"(),
    "estado" "text" DEFAULT 'completado'::"text",
    "registrado_por" "uuid",
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_pagos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_pedidos_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pedido_id" "uuid",
    "producto_id" "uuid",
    "cantidad" integer DEFAULT 1,
    "precio_unitario" numeric(14,2) NOT NULL,
    "descuento" numeric(14,2) DEFAULT 0,
    "subtotal" numeric(14,2) NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_pedidos_items" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."ventas_pedido_lineas" AS
 SELECT "id",
    "pedido_id",
    "producto_id",
    "cantidad",
    "precio_unitario",
    "descuento",
    "subtotal",
    "created_at"
   FROM "public"."ventas_pedidos_items";


ALTER VIEW "public"."ventas_pedido_lineas" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_pedidos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "cliente_id" "uuid",
    "vendedor_id" "uuid",
    "numero_pedido" "text",
    "fecha_pedido" timestamp with time zone DEFAULT "now"(),
    "fecha_entrega" "date",
    "subtotal" numeric(14,2) DEFAULT 0,
    "descuento" numeric(14,2) DEFAULT 0,
    "impuestos" numeric(14,2) DEFAULT 0,
    "total" numeric(14,2) DEFAULT 0,
    "metodo_pago" "text" DEFAULT 'efectivo'::"text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "direccion_entrega" "text",
    "notas" "text",
    "facturado" boolean DEFAULT false,
    "factura_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "tipo_venta" "text" DEFAULT 'contado'::"text",
    "fecha_entrega_estimada" "date",
    "fecha_entregado" timestamp with time zone,
    "monto_pagado" numeric(12,2) DEFAULT 0,
    "saldo_pendiente" numeric(12,2) DEFAULT 0
);


ALTER TABLE "public"."ventas_pedidos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_pedidos_detalle" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "pedido_id" "uuid",
    "producto_id" "uuid",
    "cantidad" integer DEFAULT 1,
    "precio_unitario" numeric(10,2) NOT NULL,
    "descuento" numeric(10,2) DEFAULT 0,
    "subtotal" numeric(10,2) NOT NULL,
    "notas" "text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_pedidos_detalle" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_productos" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "categoria_id" "uuid",
    "sku" "text",
    "codigo_barras" "text",
    "nombre" "text" NOT NULL,
    "descripcion" "text",
    "unidad" "text" DEFAULT 'pieza'::"text",
    "precio_compra" numeric(14,2) DEFAULT 0,
    "precio_venta" numeric(14,2) NOT NULL,
    "precio_mayoreo" numeric(14,2),
    "cantidad_mayoreo" integer DEFAULT 10,
    "stock" integer DEFAULT 0,
    "stock_minimo" integer DEFAULT 5,
    "imagen_url" "text",
    "destacado" boolean DEFAULT false,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "marca" "text",
    "modelo" "text",
    "galeria" "text"[],
    "especificaciones" "jsonb" DEFAULT '{}'::"jsonb",
    "stock_maximo" integer
);


ALTER TABLE "public"."ventas_productos" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."ventas_vendedores" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "negocio_id" "uuid",
    "auth_uid" "uuid",
    "usuario_id" "uuid",
    "codigo" "text",
    "nombre" "text" NOT NULL,
    "email" "text",
    "telefono" "text",
    "zona" "text",
    "meta_mensual" numeric(14,2) DEFAULT 10000,
    "comision_porcentaje" numeric(5,2) DEFAULT 5,
    "ventas_mes" numeric(14,2) DEFAULT 0,
    "comisiones_pendientes" numeric(14,2) DEFAULT 0,
    "activo" boolean DEFAULT true,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."ventas_vendedores" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."verificaciones_identidad" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "aval_id" "uuid" NOT NULL,
    "ine_url" "text",
    "selfie_url" "text",
    "estado" "text" DEFAULT 'pendiente'::"text",
    "metodo" "text" DEFAULT 'manual'::"text",
    "confianza" numeric(5,2),
    "verificado_por" "uuid",
    "fecha_verificacion" timestamp without time zone,
    "motivo_rechazo" "text",
    "created_at" timestamp without time zone DEFAULT "now"()
);


ALTER TABLE "public"."verificaciones_identidad" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."vista_resumen_sucursal" AS
 SELECT "id" AS "sucursal_id",
    "nombre" AS "sucursal_nombre",
    ( SELECT "count"(*) AS "count"
           FROM "public"."clientes" "c"
          WHERE ("c"."sucursal_id" = "s"."id")) AS "total_clientes",
    ( SELECT "count"(*) AS "count"
           FROM "public"."empleados" "e"
          WHERE ("e"."sucursal_id" = "s"."id")) AS "total_empleados",
    ( SELECT "count"(*) AS "count"
           FROM "public"."prestamos" "p"
          WHERE ("p"."sucursal_id" = "s"."id")) AS "total_prestamos",
    ( SELECT "count"(*) AS "count"
           FROM "public"."prestamos" "p"
          WHERE (("p"."sucursal_id" = "s"."id") AND ("p"."estado" = 'activo'::"text"))) AS "prestamos_activos",
    ( SELECT COALESCE("sum"("p"."monto"), (0)::numeric) AS "coalesce"
           FROM "public"."prestamos" "p"
          WHERE (("p"."sucursal_id" = "s"."id") AND ("p"."estado" = 'activo'::"text"))) AS "capital_activo",
    ( SELECT "count"(*) AS "count"
           FROM "public"."tandas" "t"
          WHERE ("t"."sucursal_id" = "s"."id")) AS "total_tandas",
    ( SELECT "count"(*) AS "count"
           FROM "public"."tandas" "t"
          WHERE (("t"."sucursal_id" = "s"."id") AND ("t"."estado" = 'activa'::"text"))) AS "tandas_activas"
   FROM "public"."sucursales" "s"
  ORDER BY "nombre";


ALTER VIEW "public"."vista_resumen_sucursal" OWNER TO "postgres";


ALTER TABLE ONLY "public"."activity_log"
    ADD CONSTRAINT "activity_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."activos_capital"
    ADD CONSTRAINT "activos_capital_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."acuses_recibo"
    ADD CONSTRAINT "acuses_recibo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."aires_equipos"
    ADD CONSTRAINT "aires_equipos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."aires_garantias"
    ADD CONSTRAINT "aires_garantias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."aires_ordenes_servicio"
    ADD CONSTRAINT "aires_ordenes_servicio_folio_key" UNIQUE ("folio");



ALTER TABLE ONLY "public"."aires_ordenes_servicio"
    ADD CONSTRAINT "aires_ordenes_servicio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."aires_tecnicos"
    ADD CONSTRAINT "aires_tecnicos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."alertas_sistema"
    ADD CONSTRAINT "alertas_sistema_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."amortizaciones"
    ADD CONSTRAINT "amortizaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."amortizaciones"
    ADD CONSTRAINT "amortizaciones_prestamo_id_numero_cuota_key" UNIQUE ("prestamo_id", "numero_cuota");



ALTER TABLE ONLY "public"."aportaciones"
    ADD CONSTRAINT "aportaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."auditoria_acceso"
    ADD CONSTRAINT "auditoria_acceso_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."auditoria_legal"
    ADD CONSTRAINT "auditoria_legal_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."auditoria"
    ADD CONSTRAINT "auditoria_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."aval_checkins"
    ADD CONSTRAINT "aval_checkins_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."avales"
    ADD CONSTRAINT "avales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cache_estadisticas"
    ADD CONSTRAINT "cache_estadisticas_negocio_id_tipo_key" UNIQUE ("negocio_id", "tipo");



ALTER TABLE ONLY "public"."cache_estadisticas"
    ADD CONSTRAINT "cache_estadisticas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."calendario"
    ADD CONSTRAINT "calendario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."campos_formulario_catalogo"
    ADD CONSTRAINT "campos_formulario_catalogo_codigo_key" UNIQUE ("codigo");



ALTER TABLE ONLY "public"."campos_formulario_catalogo"
    ADD CONSTRAINT "campos_formulario_catalogo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."cat_forma_pago"
    ADD CONSTRAINT "cat_forma_pago_pkey" PRIMARY KEY ("clave");



ALTER TABLE ONLY "public"."cat_regimen_fiscal"
    ADD CONSTRAINT "cat_regimen_fiscal_pkey" PRIMARY KEY ("clave");



ALTER TABLE ONLY "public"."cat_uso_cfdi"
    ADD CONSTRAINT "cat_uso_cfdi_pkey" PRIMARY KEY ("clave");



ALTER TABLE ONLY "public"."chat_aval_cobrador"
    ADD CONSTRAINT "chat_aval_cobrador_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chat_conversaciones"
    ADD CONSTRAINT "chat_conversaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chat_mensajes"
    ADD CONSTRAINT "chat_mensajes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chat_participantes"
    ADD CONSTRAINT "chat_participantes_conversacion_id_usuario_id_key" UNIQUE ("conversacion_id", "usuario_id");



ALTER TABLE ONLY "public"."chat_participantes"
    ADD CONSTRAINT "chat_participantes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."chats"
    ADD CONSTRAINT "chats_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clientes_bloqueados_mora"
    ADD CONSTRAINT "clientes_bloqueados_mora_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clientes_modulo"
    ADD CONSTRAINT "clientes_modulo_cliente_id_modulo_key" UNIQUE ("cliente_id", "modulo");



ALTER TABLE ONLY "public"."clientes_modulo"
    ADD CONSTRAINT "clientes_modulo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."clientes"
    ADD CONSTRAINT "clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_calendario"
    ADD CONSTRAINT "climas_calendario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_catalogo_servicios_publico"
    ADD CONSTRAINT "climas_catalogo_servicios_publico_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_certificaciones_tecnico"
    ADD CONSTRAINT "climas_certificaciones_tecnico_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_chat_solicitud"
    ADD CONSTRAINT "climas_chat_solicitud_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_checklist_respuestas"
    ADD CONSTRAINT "climas_checklist_respuestas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_checklist_servicio"
    ADD CONSTRAINT "climas_checklist_servicio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_cliente_contactos"
    ADD CONSTRAINT "climas_cliente_contactos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_cliente_documentos"
    ADD CONSTRAINT "climas_cliente_documentos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_cliente_notas"
    ADD CONSTRAINT "climas_cliente_notas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_clientes"
    ADD CONSTRAINT "climas_clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_comisiones"
    ADD CONSTRAINT "climas_comisiones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_comprobantes"
    ADD CONSTRAINT "climas_comprobantes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_config_formulario_qr"
    ADD CONSTRAINT "climas_config_formulario_qr_negocio_id_key" UNIQUE ("negocio_id");



ALTER TABLE ONLY "public"."climas_config_formulario_qr"
    ADD CONSTRAINT "climas_config_formulario_qr_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_configuracion"
    ADD CONSTRAINT "climas_configuracion_negocio_id_config_key_key" UNIQUE ("negocio_id", "config_key");



ALTER TABLE ONLY "public"."climas_configuracion"
    ADD CONSTRAINT "climas_configuracion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_cotizaciones"
    ADD CONSTRAINT "climas_cotizaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_cotizaciones_v2"
    ADD CONSTRAINT "climas_cotizaciones_v2_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_equipos_cliente"
    ADD CONSTRAINT "climas_equipos_cliente_cliente_id_equipo_id_ubicacion_key" UNIQUE ("cliente_id", "equipo_id", "ubicacion");



ALTER TABLE ONLY "public"."climas_equipos_cliente"
    ADD CONSTRAINT "climas_equipos_cliente_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_equipos"
    ADD CONSTRAINT "climas_equipos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_garantias"
    ADD CONSTRAINT "climas_garantias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_incidencias"
    ADD CONSTRAINT "climas_incidencias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_inventario_tecnico"
    ADD CONSTRAINT "climas_inventario_tecnico_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_mensajes"
    ADD CONSTRAINT "climas_mensajes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_metricas_tecnico"
    ADD CONSTRAINT "climas_metricas_tecnico_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_metricas_tecnico"
    ADD CONSTRAINT "climas_metricas_tecnico_tecnico_id_periodo_key" UNIQUE ("tecnico_id", "periodo");



ALTER TABLE ONLY "public"."climas_movimientos_inventario"
    ADD CONSTRAINT "climas_movimientos_inventario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_ordenes_servicio"
    ADD CONSTRAINT "climas_ordenes_servicio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_pagos"
    ADD CONSTRAINT "climas_pagos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_precios_servicio"
    ADD CONSTRAINT "climas_precios_servicio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_productos"
    ADD CONSTRAINT "climas_productos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_recordatorios_mantenimiento"
    ADD CONSTRAINT "climas_recordatorios_mantenimiento_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_registro_tiempo"
    ADD CONSTRAINT "climas_registro_tiempo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_solicitud_historial"
    ADD CONSTRAINT "climas_solicitud_historial_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_solicitudes_cliente"
    ADD CONSTRAINT "climas_solicitudes_cliente_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_solicitudes_qr"
    ADD CONSTRAINT "climas_solicitudes_qr_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_solicitudes_refacciones"
    ADD CONSTRAINT "climas_solicitudes_refacciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_tecnico_zonas"
    ADD CONSTRAINT "climas_tecnico_zonas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_tecnico_zonas"
    ADD CONSTRAINT "climas_tecnico_zonas_tecnico_id_zona_id_key" UNIQUE ("tecnico_id", "zona_id");



ALTER TABLE ONLY "public"."climas_tecnicos"
    ADD CONSTRAINT "climas_tecnicos_negocio_id_codigo_key" UNIQUE ("negocio_id", "codigo");



ALTER TABLE ONLY "public"."climas_tecnicos"
    ADD CONSTRAINT "climas_tecnicos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."climas_zonas"
    ADD CONSTRAINT "climas_zonas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaborador_actividad"
    ADD CONSTRAINT "colaborador_actividad_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaborador_compensaciones"
    ADD CONSTRAINT "colaborador_compensaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaborador_inversiones"
    ADD CONSTRAINT "colaborador_inversiones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaborador_invitaciones"
    ADD CONSTRAINT "colaborador_invitaciones_codigo_invitacion_key" UNIQUE ("codigo_invitacion");



ALTER TABLE ONLY "public"."colaborador_invitaciones"
    ADD CONSTRAINT "colaborador_invitaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaborador_pagos"
    ADD CONSTRAINT "colaborador_pagos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaborador_permisos_modulo"
    ADD CONSTRAINT "colaborador_permisos_modulo_colaborador_id_modulo_key" UNIQUE ("colaborador_id", "modulo");



ALTER TABLE ONLY "public"."colaborador_permisos_modulo"
    ADD CONSTRAINT "colaborador_permisos_modulo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaborador_rendimientos"
    ADD CONSTRAINT "colaborador_rendimientos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaborador_tipos"
    ADD CONSTRAINT "colaborador_tipos_codigo_key" UNIQUE ("codigo");



ALTER TABLE ONLY "public"."colaborador_tipos"
    ADD CONSTRAINT "colaborador_tipos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."colaboradores"
    ADD CONSTRAINT "colaboradores_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."colaboradores"
    ADD CONSTRAINT "colaboradores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comisiones_empleados"
    ADD CONSTRAINT "comisiones_empleados_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."compensacion_tipos"
    ADD CONSTRAINT "compensacion_tipos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comprobantes"
    ADD CONSTRAINT "comprobantes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."comprobantes_prestamo"
    ADD CONSTRAINT "comprobantes_prestamo_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."configuracion_apis"
    ADD CONSTRAINT "configuracion_apis_negocio_id_servicio_key" UNIQUE ("negocio_id", "servicio");



ALTER TABLE ONLY "public"."configuracion_apis"
    ADD CONSTRAINT "configuracion_apis_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."configuracion"
    ADD CONSTRAINT "configuracion_clave_key" UNIQUE ("clave");



ALTER TABLE ONLY "public"."configuracion_global"
    ADD CONSTRAINT "configuracion_global_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."configuracion_moras"
    ADD CONSTRAINT "configuracion_moras_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."configuracion"
    ADD CONSTRAINT "configuracion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."contratos"
    ADD CONSTRAINT "contratos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documentos_aval"
    ADD CONSTRAINT "documentos_aval_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."documentos_cliente"
    ADD CONSTRAINT "documentos_cliente_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."empleados_negocios"
    ADD CONSTRAINT "empleados_negocios_empleado_id_negocio_id_key" UNIQUE ("empleado_id", "negocio_id");



ALTER TABLE ONLY "public"."empleados_negocios"
    ADD CONSTRAINT "empleados_negocios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."empleados"
    ADD CONSTRAINT "empleados_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."entregas"
    ADD CONSTRAINT "entregas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."envios_capital"
    ADD CONSTRAINT "envios_capital_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expediente_clientes"
    ADD CONSTRAINT "expediente_clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expedientes_legales"
    ADD CONSTRAINT "expedientes_legales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factura_complementos_pago"
    ADD CONSTRAINT "factura_complementos_pago_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factura_conceptos"
    ADD CONSTRAINT "factura_conceptos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factura_documentos_relacionados"
    ADD CONSTRAINT "factura_documentos_relacionados_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."factura_impuestos"
    ADD CONSTRAINT "factura_impuestos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facturacion_clientes"
    ADD CONSTRAINT "facturacion_clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facturacion_emisores"
    ADD CONSTRAINT "facturacion_emisores_negocio_id_rfc_key" UNIQUE ("negocio_id", "rfc");



ALTER TABLE ONLY "public"."facturacion_emisores"
    ADD CONSTRAINT "facturacion_emisores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facturacion_logs"
    ADD CONSTRAINT "facturacion_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facturacion_productos"
    ADD CONSTRAINT "facturacion_productos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."facturas"
    ADD CONSTRAINT "facturas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."firmas_avales"
    ADD CONSTRAINT "firmas_avales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."firmas_digitales"
    ADD CONSTRAINT "firmas_digitales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fondos_pantalla"
    ADD CONSTRAINT "fondos_pantalla_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."formularios_qr_config"
    ADD CONSTRAINT "formularios_qr_config_negocio_id_modulo_key" UNIQUE ("negocio_id", "modulo");



ALTER TABLE ONLY "public"."formularios_qr_config"
    ADD CONSTRAINT "formularios_qr_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."formularios_qr_envios"
    ADD CONSTRAINT "formularios_qr_envios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."intentos_cobro"
    ADD CONSTRAINT "intentos_cobro_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventario_movimientos"
    ADD CONSTRAINT "inventario_movimientos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."inventario"
    ADD CONSTRAINT "inventario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."links_pago"
    ADD CONSTRAINT "links_pago_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."log_fraude"
    ADD CONSTRAINT "log_fraude_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mensajes_aval_cobrador"
    ADD CONSTRAINT "mensajes_aval_cobrador_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mensajes"
    ADD CONSTRAINT "mensajes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."metodos_pago"
    ADD CONSTRAINT "metodos_pago_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."mis_propiedades"
    ADD CONSTRAINT "mis_propiedades_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."modulos_activos"
    ADD CONSTRAINT "modulos_activos_negocio_id_modulo_id_key" UNIQUE ("negocio_id", "modulo_id");



ALTER TABLE ONLY "public"."modulos_activos"
    ADD CONSTRAINT "modulos_activos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moras_prestamos"
    ADD CONSTRAINT "moras_prestamos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."moras_tandas"
    ADD CONSTRAINT "moras_tandas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."movimientos_capital"
    ADD CONSTRAINT "movimientos_capital_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."negocios"
    ADD CONSTRAINT "negocios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_catalogos"
    ADD CONSTRAINT "nice_catalogos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_categorias"
    ADD CONSTRAINT "nice_categorias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_clientes"
    ADD CONSTRAINT "nice_clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_comisiones"
    ADD CONSTRAINT "nice_comisiones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_inventario_movimientos"
    ADD CONSTRAINT "nice_inventario_movimientos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_inventario_vendedora"
    ADD CONSTRAINT "nice_inventario_vendedora_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_inventario_vendedora"
    ADD CONSTRAINT "nice_inventario_vendedora_vendedora_id_producto_id_key" UNIQUE ("vendedora_id", "producto_id");



ALTER TABLE ONLY "public"."nice_niveles"
    ADD CONSTRAINT "nice_niveles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_pagos"
    ADD CONSTRAINT "nice_pagos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_pedido_items"
    ADD CONSTRAINT "nice_pedido_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_pedidos"
    ADD CONSTRAINT "nice_pedidos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_productos"
    ADD CONSTRAINT "nice_productos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nice_vendedoras"
    ADD CONSTRAINT "nice_vendedoras_negocio_id_codigo_vendedora_key" UNIQUE ("negocio_id", "codigo_vendedora");



ALTER TABLE ONLY "public"."nice_vendedoras"
    ADD CONSTRAINT "nice_vendedoras_negocio_id_email_key" UNIQUE ("negocio_id", "email");



ALTER TABLE ONLY "public"."nice_vendedoras"
    ADD CONSTRAINT "nice_vendedoras_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notificaciones_documento_aval"
    ADD CONSTRAINT "notificaciones_documento_aval_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notificaciones_masivas"
    ADD CONSTRAINT "notificaciones_masivas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notificaciones_mora_aval"
    ADD CONSTRAINT "notificaciones_mora_aval_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notificaciones_mora_cliente"
    ADD CONSTRAINT "notificaciones_mora_cliente_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notificaciones_mora"
    ADD CONSTRAINT "notificaciones_mora_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notificaciones"
    ADD CONSTRAINT "notificaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notificaciones_sistema"
    ADD CONSTRAINT "notificaciones_sistema_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pagos_comisiones"
    ADD CONSTRAINT "pagos_comisiones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pagos_propiedades"
    ADD CONSTRAINT "pagos_propiedades_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."permisos"
    ADD CONSTRAINT "permisos_clave_permiso_key" UNIQUE ("clave_permiso");



ALTER TABLE ONLY "public"."permisos"
    ADD CONSTRAINT "permisos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."preferencias_usuario"
    ADD CONSTRAINT "preferencias_usuario_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."preferencias_usuario"
    ADD CONSTRAINT "preferencias_usuario_usuario_id_key" UNIQUE ("usuario_id");



ALTER TABLE ONLY "public"."prestamos_avales"
    ADD CONSTRAINT "prestamos_avales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."prestamos_avales"
    ADD CONSTRAINT "prestamos_avales_prestamo_id_aval_id_key" UNIQUE ("prestamo_id", "aval_id");



ALTER TABLE ONLY "public"."prestamos"
    ADD CONSTRAINT "prestamos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."promesas_pago"
    ADD CONSTRAINT "promesas_pago_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."promociones"
    ADD CONSTRAINT "promociones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_cliente_contactos"
    ADD CONSTRAINT "purificadora_cliente_contactos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_cliente_documentos"
    ADD CONSTRAINT "purificadora_cliente_documentos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_cliente_notas"
    ADD CONSTRAINT "purificadora_cliente_notas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_clientes"
    ADD CONSTRAINT "purificadora_clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_cortes"
    ADD CONSTRAINT "purificadora_cortes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_entregas"
    ADD CONSTRAINT "purificadora_entregas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_garrafones_historial"
    ADD CONSTRAINT "purificadora_garrafones_historial_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_gastos"
    ADD CONSTRAINT "purificadora_gastos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_inventario_garrafones"
    ADD CONSTRAINT "purificadora_inventario_garrafones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_pagos"
    ADD CONSTRAINT "purificadora_pagos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_precios"
    ADD CONSTRAINT "purificadora_precios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_produccion"
    ADD CONSTRAINT "purificadora_produccion_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_productos"
    ADD CONSTRAINT "purificadora_productos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_repartidores"
    ADD CONSTRAINT "purificadora_repartidores_negocio_id_codigo_key" UNIQUE ("negocio_id", "codigo");



ALTER TABLE ONLY "public"."purificadora_repartidores"
    ADD CONSTRAINT "purificadora_repartidores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."purificadora_rutas"
    ADD CONSTRAINT "purificadora_rutas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."qr_cobros"
    ADD CONSTRAINT "qr_cobros_codigo_qr_key" UNIQUE ("codigo_qr");



ALTER TABLE ONLY "public"."qr_cobros_config"
    ADD CONSTRAINT "qr_cobros_config_negocio_id_key" UNIQUE ("negocio_id");



ALTER TABLE ONLY "public"."qr_cobros_config"
    ADD CONSTRAINT "qr_cobros_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."qr_cobros_escaneos"
    ADD CONSTRAINT "qr_cobros_escaneos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."qr_cobros_estadisticas_diarias"
    ADD CONSTRAINT "qr_cobros_estadisticas_diarias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."qr_cobros"
    ADD CONSTRAINT "qr_cobros_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."qr_cobros_reportes"
    ADD CONSTRAINT "qr_cobros_reportes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."recordatorios"
    ADD CONSTRAINT "recordatorios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."referencias_aval"
    ADD CONSTRAINT "referencias_aval_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."registros_cobro"
    ADD CONSTRAINT "registros_cobro_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."roles_permisos"
    ADD CONSTRAINT "roles_permisos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."roles_permisos"
    ADD CONSTRAINT "roles_permisos_rol_id_permiso_id_key" UNIQUE ("rol_id", "permiso_id");



ALTER TABLE ONLY "public"."roles"
    ADD CONSTRAINT "roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."seguimiento_judicial"
    ADD CONSTRAINT "seguimiento_judicial_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stripe_config"
    ADD CONSTRAINT "stripe_config_negocio_id_key" UNIQUE ("negocio_id");



ALTER TABLE ONLY "public"."stripe_config"
    ADD CONSTRAINT "stripe_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stripe_transactions_log"
    ADD CONSTRAINT "stripe_transactions_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stripe_transactions_log"
    ADD CONSTRAINT "stripe_transactions_log_stripe_event_id_key" UNIQUE ("stripe_event_id");



ALTER TABLE ONLY "public"."sucursales"
    ADD CONSTRAINT "sucursales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tanda_pagos"
    ADD CONSTRAINT "tanda_pagos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tanda_participantes"
    ADD CONSTRAINT "tanda_participantes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tanda_participantes"
    ADD CONSTRAINT "tanda_participantes_tanda_id_numero_turno_key" UNIQUE ("tanda_id", "numero_turno");



ALTER TABLE ONLY "public"."tandas_avales"
    ADD CONSTRAINT "tandas_avales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tandas_avales"
    ADD CONSTRAINT "tandas_avales_tanda_id_aval_id_key" UNIQUE ("tanda_id", "aval_id");



ALTER TABLE ONLY "public"."tandas"
    ADD CONSTRAINT "tandas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_alertas"
    ADD CONSTRAINT "tarjetas_alertas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_config"
    ADD CONSTRAINT "tarjetas_config_negocio_id_key" UNIQUE ("negocio_id");



ALTER TABLE ONLY "public"."tarjetas_config"
    ADD CONSTRAINT "tarjetas_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_digitales"
    ADD CONSTRAINT "tarjetas_digitales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_digitales_recargas"
    ADD CONSTRAINT "tarjetas_digitales_recargas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_digitales_transacciones"
    ADD CONSTRAINT "tarjetas_digitales_transacciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_landing_config"
    ADD CONSTRAINT "tarjetas_landing_config_negocio_id_modulo_key" UNIQUE ("negocio_id", "modulo");



ALTER TABLE ONLY "public"."tarjetas_landing_config"
    ADD CONSTRAINT "tarjetas_landing_config_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_log"
    ADD CONSTRAINT "tarjetas_log_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_recargas"
    ADD CONSTRAINT "tarjetas_recargas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_servicio"
    ADD CONSTRAINT "tarjetas_servicio_codigo_key" UNIQUE ("codigo");



ALTER TABLE ONLY "public"."tarjetas_servicio_escaneos"
    ADD CONSTRAINT "tarjetas_servicio_escaneos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_servicio_exportaciones"
    ADD CONSTRAINT "tarjetas_servicio_exportaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_servicio"
    ADD CONSTRAINT "tarjetas_servicio_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_solicitudes"
    ADD CONSTRAINT "tarjetas_solicitudes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_templates"
    ADD CONSTRAINT "tarjetas_templates_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."tarjetas_templates"
    ADD CONSTRAINT "tarjetas_templates_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_titulares"
    ADD CONSTRAINT "tarjetas_titulares_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_transacciones"
    ADD CONSTRAINT "tarjetas_transacciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tarjetas_virtuales"
    ADD CONSTRAINT "tarjetas_virtuales_numero_tarjeta_key" UNIQUE ("numero_tarjeta");



ALTER TABLE ONLY "public"."tarjetas_virtuales"
    ADD CONSTRAINT "tarjetas_virtuales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."temas_app"
    ADD CONSTRAINT "temas_app_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transacciones_tarjeta"
    ADD CONSTRAINT "transacciones_tarjeta_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usuarios"
    ADD CONSTRAINT "usuarios_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."usuarios_negocios"
    ADD CONSTRAINT "usuarios_negocios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usuarios_negocios"
    ADD CONSTRAINT "usuarios_negocios_usuario_id_negocio_id_key" UNIQUE ("usuario_id", "negocio_id");



ALTER TABLE ONLY "public"."usuarios"
    ADD CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usuarios_roles"
    ADD CONSTRAINT "usuarios_roles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usuarios_roles"
    ADD CONSTRAINT "usuarios_roles_usuario_id_rol_id_key" UNIQUE ("usuario_id", "rol_id");



ALTER TABLE ONLY "public"."usuarios_sucursales"
    ADD CONSTRAINT "usuarios_sucursales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."usuarios_sucursales"
    ADD CONSTRAINT "usuarios_sucursales_usuario_id_sucursal_id_key" UNIQUE ("usuario_id", "sucursal_id");



ALTER TABLE ONLY "public"."validaciones_aval"
    ADD CONSTRAINT "validaciones_aval_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."variantes_arquilado"
    ADD CONSTRAINT "variantes_arquilado_nombre_key" UNIQUE ("nombre");



ALTER TABLE ONLY "public"."variantes_arquilado"
    ADD CONSTRAINT "variantes_arquilado_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_categorias"
    ADD CONSTRAINT "ventas_categorias_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_cliente_contactos"
    ADD CONSTRAINT "ventas_cliente_contactos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_cliente_creditos"
    ADD CONSTRAINT "ventas_cliente_creditos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_cliente_documentos"
    ADD CONSTRAINT "ventas_cliente_documentos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_cliente_notas"
    ADD CONSTRAINT "ventas_cliente_notas_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_clientes"
    ADD CONSTRAINT "ventas_clientes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_cotizaciones"
    ADD CONSTRAINT "ventas_cotizaciones_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_pagos"
    ADD CONSTRAINT "ventas_pagos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_pedidos_detalle"
    ADD CONSTRAINT "ventas_pedidos_detalle_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_pedidos_items"
    ADD CONSTRAINT "ventas_pedidos_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_pedidos"
    ADD CONSTRAINT "ventas_pedidos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_productos"
    ADD CONSTRAINT "ventas_productos_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."ventas_vendedores"
    ADD CONSTRAINT "ventas_vendedores_negocio_id_codigo_key" UNIQUE ("negocio_id", "codigo");



ALTER TABLE ONLY "public"."ventas_vendedores"
    ADD CONSTRAINT "ventas_vendedores_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."verificaciones_identidad"
    ADD CONSTRAINT "verificaciones_identidad_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_activity_log_accion" ON "public"."activity_log" USING "btree" ("accion");



CREATE INDEX "idx_activity_log_entidad" ON "public"."activity_log" USING "btree" ("entidad", "entidad_id");



CREATE INDEX "idx_activity_log_fecha" ON "public"."activity_log" USING "btree" ("created_at");



CREATE INDEX "idx_activity_log_usuario" ON "public"."activity_log" USING "btree" ("usuario_id");



CREATE INDEX "idx_activos_capital_negocio" ON "public"."activos_capital" USING "btree" ("negocio_id");



CREATE INDEX "idx_activos_capital_tipo" ON "public"."activos_capital" USING "btree" ("tipo");



CREATE INDEX "idx_aires_equipos_negocio" ON "public"."aires_equipos" USING "btree" ("negocio_id");



CREATE INDEX "idx_aires_equipos_negocio_id" ON "public"."aires_equipos" USING "btree" ("negocio_id");



CREATE INDEX "idx_aires_ordenes_estado" ON "public"."aires_ordenes_servicio" USING "btree" ("estado");



CREATE INDEX "idx_aires_ordenes_negocio" ON "public"."aires_ordenes_servicio" USING "btree" ("negocio_id");



CREATE INDEX "idx_aires_ordenes_servicio_negocio_id" ON "public"."aires_ordenes_servicio" USING "btree" ("negocio_id");



CREATE INDEX "idx_aires_tecnicos_negocio" ON "public"."aires_tecnicos" USING "btree" ("negocio_id");



CREATE INDEX "idx_aires_tecnicos_negocio_id" ON "public"."aires_tecnicos" USING "btree" ("negocio_id");



CREATE INDEX "idx_amortizaciones_estado" ON "public"."amortizaciones" USING "btree" ("estado");



CREATE INDEX "idx_amortizaciones_pendientes" ON "public"."amortizaciones" USING "btree" ("prestamo_id", "fecha_vencimiento") WHERE ("estado" = 'pendiente'::"text");



CREATE INDEX "idx_amortizaciones_prestamo" ON "public"."amortizaciones" USING "btree" ("prestamo_id");



CREATE INDEX "idx_amortizaciones_prestamo_cuota" ON "public"."amortizaciones" USING "btree" ("prestamo_id", "numero_cuota");



CREATE INDEX "idx_amortizaciones_prestamo_estado" ON "public"."amortizaciones" USING "btree" ("prestamo_id", "estado");



CREATE INDEX "idx_amortizaciones_vencidas" ON "public"."amortizaciones" USING "btree" ("prestamo_id", "fecha_vencimiento") WHERE ("estado" = 'vencido'::"text");



CREATE INDEX "idx_amortizaciones_vencimiento" ON "public"."amortizaciones" USING "btree" ("fecha_vencimiento");



CREATE INDEX "idx_amortizaciones_vencimiento_estado" ON "public"."amortizaciones" USING "btree" ("fecha_vencimiento", "estado");



CREATE INDEX "idx_aportaciones_colaborador" ON "public"."aportaciones" USING "btree" ("colaborador_id");



CREATE INDEX "idx_aportaciones_fecha" ON "public"."aportaciones" USING "btree" ("fecha_aportacion" DESC);



CREATE INDEX "idx_aportaciones_negocio" ON "public"."aportaciones" USING "btree" ("negocio_id");



CREATE INDEX "idx_auditoria_acceso_fecha" ON "public"."auditoria_acceso" USING "btree" ("created_at");



CREATE INDEX "idx_auditoria_acceso_usuario" ON "public"."auditoria_acceso" USING "btree" ("usuario_id");



CREATE INDEX "idx_auditoria_fecha" ON "public"."auditoria" USING "btree" ("fecha");



CREATE INDEX "idx_auditoria_usuario" ON "public"."auditoria" USING "btree" ("usuario_id");



CREATE INDEX "idx_aval_checkins" ON "public"."aval_checkins" USING "btree" ("aval_id");



CREATE INDEX "idx_aval_checkins_aval" ON "public"."aval_checkins" USING "btree" ("aval_id");



CREATE INDEX "idx_aval_checkins_fecha" ON "public"."aval_checkins" USING "btree" ("fecha");



CREATE INDEX "idx_aval_checkins_tipo" ON "public"."aval_checkins" USING "btree" ("tipo");



CREATE INDEX "idx_avales_cliente" ON "public"."avales" USING "btree" ("cliente_id");



CREATE INDEX "idx_avales_negocio_id" ON "public"."avales" USING "btree" ("negocio_id");



CREATE INDEX "idx_avales_prestamo" ON "public"."avales" USING "btree" ("prestamo_id");



CREATE INDEX "idx_avales_verificados" ON "public"."avales" USING "btree" ("negocio_id", "prestamo_id") WHERE ("verificado" = true);



CREATE INDEX "idx_cache_estadisticas_expira" ON "public"."cache_estadisticas" USING "btree" ("expira_at");



CREATE INDEX "idx_cache_estadisticas_negocio" ON "public"."cache_estadisticas" USING "btree" ("negocio_id");



CREATE INDEX "idx_cache_estadisticas_negocio_id" ON "public"."cache_estadisticas" USING "btree" ("negocio_id");



CREATE INDEX "idx_cache_estadisticas_negocio_tipo" ON "public"."cache_estadisticas" USING "btree" ("negocio_id", "tipo");



CREATE INDEX "idx_cache_estadisticas_tipo" ON "public"."cache_estadisticas" USING "btree" ("tipo");



CREATE INDEX "idx_calendario_fecha" ON "public"."calendario" USING "btree" ("fecha");



CREATE INDEX "idx_calendario_usuario" ON "public"."calendario" USING "btree" ("usuario_id");



CREATE INDEX "idx_chat_aval_cobrador_admin" ON "public"."chat_aval_cobrador" USING "btree" ("admin_id");



CREATE INDEX "idx_chat_aval_cobrador_aval" ON "public"."chat_aval_cobrador" USING "btree" ("aval_id");



CREATE INDEX "idx_chat_aval_cobrador_ultimo" ON "public"."chat_aval_cobrador" USING "btree" ("ultimo_mensaje");



CREATE INDEX "idx_chat_conversaciones_cliente" ON "public"."chat_conversaciones" USING "btree" ("cliente_id");



CREATE INDEX "idx_chat_mensajes_conv_fecha" ON "public"."chat_mensajes" USING "btree" ("conversacion_id", "created_at" DESC);



CREATE INDEX "idx_chat_mensajes_conversacion" ON "public"."chat_mensajes" USING "btree" ("conversacion_id");



CREATE INDEX "idx_chat_mensajes_fecha" ON "public"."chat_mensajes" USING "btree" ("created_at");



CREATE INDEX "idx_chat_mensajes_no_leidos" ON "public"."chat_mensajes" USING "btree" ("conversacion_id", "created_at") WHERE ("leido" = false);



CREATE INDEX "idx_clientes_activo" ON "public"."clientes" USING "btree" ("activo");



CREATE INDEX "idx_clientes_bloqueados" ON "public"."clientes_bloqueados_mora" USING "btree" ("cliente_id", "activo");



CREATE INDEX "idx_clientes_email" ON "public"."clientes" USING "btree" ("email");



CREATE INDEX "idx_clientes_modulo_auth" ON "public"."clientes_modulo" USING "btree" ("auth_uid");



CREATE INDEX "idx_clientes_modulo_modulo" ON "public"."clientes_modulo" USING "btree" ("modulo");



CREATE INDEX "idx_clientes_modulo_negocio" ON "public"."clientes_modulo" USING "btree" ("negocio_id");



CREATE INDEX "idx_clientes_modulo_negocio_id" ON "public"."clientes_modulo" USING "btree" ("negocio_id");



CREATE INDEX "idx_clientes_negocio" ON "public"."clientes" USING "btree" ("negocio_id");



CREATE INDEX "idx_clientes_negocio_activo" ON "public"."clientes" USING "btree" ("negocio_id") WHERE ("activo" = true);



CREATE INDEX "idx_clientes_negocio_id" ON "public"."clientes" USING "btree" ("negocio_id");



CREATE INDEX "idx_clientes_nombre" ON "public"."clientes" USING "btree" ("nombre");



CREATE INDEX "idx_clientes_nombre_lower" ON "public"."clientes" USING "btree" ("lower"("nombre"));



CREATE INDEX "idx_clientes_nombre_trgm" ON "public"."clientes" USING "gin" ("nombre" "public"."gin_trgm_ops");



CREATE INDEX "idx_clientes_stripe" ON "public"."clientes" USING "btree" ("stripe_customer_id");



CREATE INDEX "idx_clientes_sucursal" ON "public"."clientes" USING "btree" ("sucursal_id");



CREATE INDEX "idx_clientes_telefono" ON "public"."clientes" USING "btree" ("telefono");



CREATE INDEX "idx_climas_calendario_fecha" ON "public"."climas_calendario" USING "btree" ("fecha");



CREATE INDEX "idx_climas_calendario_tecnico" ON "public"."climas_calendario" USING "btree" ("tecnico_id");



CREATE INDEX "idx_climas_catalogo_activo" ON "public"."climas_catalogo_servicios_publico" USING "btree" ("activo");



CREATE INDEX "idx_climas_catalogo_negocio" ON "public"."climas_catalogo_servicios_publico" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_chat_sol_created" ON "public"."climas_chat_solicitud" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_climas_chat_sol_solicitud" ON "public"."climas_chat_solicitud" USING "btree" ("solicitud_id");



CREATE INDEX "idx_climas_cliente_contactos_cliente" ON "public"."climas_cliente_contactos" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_cliente_documentos_cliente" ON "public"."climas_cliente_documentos" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_cliente_notas_cliente" ON "public"."climas_cliente_notas" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_clientes_auth" ON "public"."climas_clientes" USING "btree" ("auth_uid");



CREATE INDEX "idx_climas_clientes_negocio" ON "public"."climas_clientes" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_clientes_negocio_id" ON "public"."climas_clientes" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_comisiones_tecnico" ON "public"."climas_comisiones" USING "btree" ("tecnico_id");



CREATE INDEX "idx_climas_comprobantes_cliente" ON "public"."climas_comprobantes" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_cotizaciones_cliente" ON "public"."climas_cotizaciones" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_cotizaciones_negocio" ON "public"."climas_cotizaciones" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_cotizaciones_negocio_id" ON "public"."climas_cotizaciones" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_cotizaciones_v2_cliente" ON "public"."climas_cotizaciones_v2" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_equipos_cliente" ON "public"."climas_equipos" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_equipos_cliente_cliente" ON "public"."climas_equipos_cliente" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_equipos_cliente_equipo" ON "public"."climas_equipos_cliente" USING "btree" ("equipo_id");



CREATE INDEX "idx_climas_garantias_cliente" ON "public"."climas_garantias" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_garantias_equipo" ON "public"."climas_garantias" USING "btree" ("equipo_id");



CREATE INDEX "idx_climas_inventario_tecnico" ON "public"."climas_inventario_tecnico" USING "btree" ("tecnico_id");



CREATE INDEX "idx_climas_mensajes_cliente" ON "public"."climas_mensajes" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_mensajes_orden" ON "public"."climas_mensajes" USING "btree" ("orden_id");



CREATE INDEX "idx_climas_metricas_tecnico" ON "public"."climas_metricas_tecnico" USING "btree" ("tecnico_id", "periodo");



CREATE INDEX "idx_climas_movimientos_producto" ON "public"."climas_movimientos_inventario" USING "btree" ("producto_id");



CREATE INDEX "idx_climas_ordenes_cliente" ON "public"."climas_ordenes_servicio" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_ordenes_estado" ON "public"."climas_ordenes_servicio" USING "btree" ("estado");



CREATE INDEX "idx_climas_ordenes_tecnico" ON "public"."climas_ordenes_servicio" USING "btree" ("tecnico_id");



CREATE INDEX "idx_climas_pagos_orden" ON "public"."climas_pagos" USING "btree" ("orden_servicio_id");



CREATE INDEX "idx_climas_productos_categoria" ON "public"."climas_productos" USING "btree" ("categoria");



CREATE INDEX "idx_climas_productos_negocio" ON "public"."climas_productos" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_productos_negocio_id" ON "public"."climas_productos" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_recordatorios_fecha" ON "public"."climas_recordatorios_mantenimiento" USING "btree" ("fecha_programada");



CREATE INDEX "idx_climas_registro_tiempo_orden" ON "public"."climas_registro_tiempo" USING "btree" ("orden_id");



CREATE INDEX "idx_climas_sol_qr_created" ON "public"."climas_solicitudes_qr" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_climas_sol_qr_estado" ON "public"."climas_solicitudes_qr" USING "btree" ("estado");



CREATE INDEX "idx_climas_sol_qr_negocio" ON "public"."climas_solicitudes_qr" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_sol_qr_telefono" ON "public"."climas_solicitudes_qr" USING "btree" ("telefono");



CREATE INDEX "idx_climas_sol_qr_token" ON "public"."climas_solicitudes_qr" USING "btree" ("token_seguimiento");



CREATE INDEX "idx_climas_solicitudes_cliente" ON "public"."climas_solicitudes_cliente" USING "btree" ("cliente_id");



CREATE INDEX "idx_climas_solicitudes_estado" ON "public"."climas_solicitudes_cliente" USING "btree" ("estado");



CREATE INDEX "idx_climas_tecnicos_auth" ON "public"."climas_tecnicos" USING "btree" ("auth_uid");



CREATE INDEX "idx_climas_tecnicos_disponible" ON "public"."climas_tecnicos" USING "btree" ("disponible");



CREATE INDEX "idx_climas_tecnicos_negocio" ON "public"."climas_tecnicos" USING "btree" ("negocio_id");



CREATE INDEX "idx_climas_tecnicos_negocio_id" ON "public"."climas_tecnicos" USING "btree" ("negocio_id");



CREATE INDEX "idx_colab_actividad_colaborador" ON "public"."colaborador_actividad" USING "btree" ("colaborador_id");



CREATE INDEX "idx_colab_comp_colaborador" ON "public"."colaborador_compensaciones" USING "btree" ("colaborador_id");



CREATE INDEX "idx_colab_inversiones_colaborador" ON "public"."colaborador_inversiones" USING "btree" ("colaborador_id");



CREATE INDEX "idx_colab_pagos_colaborador" ON "public"."colaborador_pagos" USING "btree" ("colaborador_id");



CREATE INDEX "idx_colaborador_permisos_colaborador" ON "public"."colaborador_permisos_modulo" USING "btree" ("colaborador_id");



CREATE INDEX "idx_colaborador_rendimientos_colaborador" ON "public"."colaborador_rendimientos" USING "btree" ("colaborador_id");



CREATE INDEX "idx_colaborador_rendimientos_inversion" ON "public"."colaborador_rendimientos" USING "btree" ("inversion_id");



CREATE INDEX "idx_colaboradores_auth_uid" ON "public"."colaboradores" USING "btree" ("auth_uid");



CREATE INDEX "idx_colaboradores_email" ON "public"."colaboradores" USING "btree" ("email");



CREATE INDEX "idx_colaboradores_estado" ON "public"."colaboradores" USING "btree" ("estado");



CREATE INDEX "idx_colaboradores_negocio" ON "public"."colaboradores" USING "btree" ("negocio_id");



CREATE INDEX "idx_colaboradores_negocio_id" ON "public"."colaboradores" USING "btree" ("negocio_id");



CREATE INDEX "idx_colaboradores_tipo" ON "public"."colaboradores" USING "btree" ("tipo_id");



CREATE INDEX "idx_comisiones_empleado" ON "public"."comisiones_empleados" USING "btree" ("empleado_id");



CREATE INDEX "idx_comisiones_estado" ON "public"."comisiones_empleados" USING "btree" ("estado");



CREATE INDEX "idx_comisiones_prestamo" ON "public"."comisiones_empleados" USING "btree" ("prestamo_id");



CREATE INDEX "idx_compensacion_tipos_negocio_id" ON "public"."compensacion_tipos" USING "btree" ("negocio_id");



CREATE INDEX "idx_comprobantes_cliente" ON "public"."comprobantes" USING "btree" ("cliente_id");



CREATE INDEX "idx_comprobantes_negocio" ON "public"."comprobantes" USING "btree" ("negocio_id");



CREATE INDEX "idx_comprobantes_negocio_id" ON "public"."comprobantes" USING "btree" ("negocio_id");



CREATE INDEX "idx_comprobantes_tipo" ON "public"."comprobantes" USING "btree" ("tipo");



CREATE INDEX "idx_config_apis_servicio" ON "public"."configuracion_apis" USING "btree" ("servicio");



CREATE INDEX "idx_contratos_cliente" ON "public"."contratos" USING "btree" ("cliente_id");



CREATE INDEX "idx_contratos_negocio" ON "public"."contratos" USING "btree" ("negocio_id");



CREATE INDEX "idx_contratos_negocio_id" ON "public"."contratos" USING "btree" ("negocio_id");



CREATE INDEX "idx_contratos_prestamo" ON "public"."contratos" USING "btree" ("prestamo_id");



CREATE INDEX "idx_documentos_aval" ON "public"."documentos_aval" USING "btree" ("aval_id");



CREATE INDEX "idx_documentos_cliente_cliente" ON "public"."documentos_cliente" USING "btree" ("cliente_id");



CREATE INDEX "idx_documentos_cliente_tipo" ON "public"."documentos_cliente" USING "btree" ("tipo_documento");



CREATE INDEX "idx_empleados_estado" ON "public"."empleados" USING "btree" ("estado");



CREATE INDEX "idx_empleados_negocio" ON "public"."empleados" USING "btree" ("negocio_id");



CREATE INDEX "idx_empleados_negocio_id" ON "public"."empleados" USING "btree" ("negocio_id");



CREATE INDEX "idx_empleados_negocios_auth" ON "public"."empleados_negocios" USING "btree" ("auth_uid");



CREATE INDEX "idx_empleados_negocios_empleado" ON "public"."empleados_negocios" USING "btree" ("empleado_id");



CREATE INDEX "idx_empleados_negocios_negocio" ON "public"."empleados_negocios" USING "btree" ("negocio_id");



CREATE INDEX "idx_empleados_negocios_negocio_id" ON "public"."empleados_negocios" USING "btree" ("negocio_id");



CREATE INDEX "idx_empleados_negocios_rol" ON "public"."empleados_negocios" USING "btree" ("rol_modulo");



CREATE INDEX "idx_empleados_numero" ON "public"."empleados" USING "btree" ("numero_empleado");



CREATE INDEX "idx_empleados_sucursal" ON "public"."empleados" USING "btree" ("sucursal_id");



CREATE INDEX "idx_empleados_sucursal_activo" ON "public"."empleados" USING "btree" ("sucursal_id") WHERE ("activo" = true);



CREATE INDEX "idx_entregas_cliente" ON "public"."entregas" USING "btree" ("cliente_id");



CREATE INDEX "idx_entregas_estado" ON "public"."entregas" USING "btree" ("estado");



CREATE INDEX "idx_entregas_fecha" ON "public"."entregas" USING "btree" ("fecha_programada");



CREATE INDEX "idx_entregas_negocio" ON "public"."entregas" USING "btree" ("negocio_id");



CREATE INDEX "idx_entregas_negocio_id" ON "public"."entregas" USING "btree" ("negocio_id");



CREATE INDEX "idx_entregas_repartidor" ON "public"."entregas" USING "btree" ("repartidor_id");



CREATE INDEX "idx_envios_capital_empleado" ON "public"."envios_capital" USING "btree" ("empleado_id");



CREATE INDEX "idx_envios_capital_fecha" ON "public"."envios_capital" USING "btree" ("fecha_envio" DESC);



CREATE INDEX "idx_envios_capital_negocio" ON "public"."envios_capital" USING "btree" ("negocio_id");



CREATE INDEX "idx_envios_estado" ON "public"."formularios_qr_envios" USING "btree" ("estado");



CREATE INDEX "idx_envios_fecha" ON "public"."formularios_qr_envios" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_envios_modulo" ON "public"."formularios_qr_envios" USING "btree" ("modulo");



CREATE INDEX "idx_envios_negocio" ON "public"."formularios_qr_envios" USING "btree" ("negocio_id");



CREATE INDEX "idx_envios_telefono" ON "public"."formularios_qr_envios" USING "btree" ("telefono");



CREATE INDEX "idx_escaneos_fecha" ON "public"."tarjetas_servicio_escaneos" USING "btree" ("created_at");



CREATE INDEX "idx_escaneos_tarjeta" ON "public"."tarjetas_servicio_escaneos" USING "btree" ("tarjeta_id");



CREATE INDEX "idx_expedientes_legales_estado" ON "public"."expedientes_legales" USING "btree" ("estado");



CREATE INDEX "idx_expedientes_legales_prestamo" ON "public"."expedientes_legales" USING "btree" ("prestamo_id");



CREATE INDEX "idx_factura_complementos_pago_negocio_id" ON "public"."factura_complementos_pago" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturacion_clientes_negocio" ON "public"."facturacion_clientes" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturacion_clientes_negocio_id" ON "public"."facturacion_clientes" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturacion_clientes_rfc" ON "public"."facturacion_clientes" USING "btree" ("rfc");



CREATE INDEX "idx_facturacion_emisores_negocio_id" ON "public"."facturacion_emisores" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturacion_logs_factura" ON "public"."facturacion_logs" USING "btree" ("factura_id");



CREATE INDEX "idx_facturacion_logs_fecha" ON "public"."facturacion_logs" USING "btree" ("created_at");



CREATE INDEX "idx_facturacion_logs_negocio" ON "public"."facturacion_logs" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturacion_logs_negocio_id" ON "public"."facturacion_logs" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturacion_productos_negocio" ON "public"."facturacion_productos" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturacion_productos_negocio_id" ON "public"."facturacion_productos" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturas_cliente" ON "public"."facturas" USING "btree" ("cliente_fiscal_id");



CREATE INDEX "idx_facturas_estado" ON "public"."facturas" USING "btree" ("estado");



CREATE INDEX "idx_facturas_fecha" ON "public"."facturas" USING "btree" ("fecha_emision");



CREATE INDEX "idx_facturas_negocio" ON "public"."facturas" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturas_negocio_id" ON "public"."facturas" USING "btree" ("negocio_id");



CREATE INDEX "idx_facturas_uuid" ON "public"."facturas" USING "btree" ("uuid_fiscal");



CREATE INDEX "idx_firmas_avales_aval" ON "public"."firmas_avales" USING "btree" ("aval_id");



CREATE INDEX "idx_firmas_avales_prestamo" ON "public"."firmas_avales" USING "btree" ("prestamo_id");



CREATE INDEX "idx_firmas_avales_tipo" ON "public"."firmas_avales" USING "btree" ("tipo_documento");



CREATE INDEX "idx_firmas_digitales_entidad" ON "public"."firmas_digitales" USING "btree" ("entidad_tipo", "entidad_id");



CREATE INDEX "idx_firmas_digitales_firmante" ON "public"."firmas_digitales" USING "btree" ("firmante_tipo", "firmante_id");



CREATE INDEX "idx_formularios_qr_modulo" ON "public"."formularios_qr_config" USING "btree" ("modulo");



CREATE INDEX "idx_formularios_qr_negocio" ON "public"."formularios_qr_config" USING "btree" ("negocio_id");



CREATE INDEX "idx_formularios_qr_tarjeta" ON "public"."formularios_qr_config" USING "btree" ("tarjeta_servicio_id");



CREATE INDEX "idx_intentos_cobro_fecha" ON "public"."intentos_cobro" USING "btree" ("fecha");



CREATE INDEX "idx_intentos_cobro_prestamo" ON "public"."intentos_cobro" USING "btree" ("prestamo_id");



CREATE INDEX "idx_inventario_codigo" ON "public"."inventario" USING "btree" ("codigo");



CREATE INDEX "idx_inventario_movimientos_inventario" ON "public"."inventario_movimientos" USING "btree" ("inventario_id");



CREATE INDEX "idx_inventario_movimientos_tipo" ON "public"."inventario_movimientos" USING "btree" ("tipo");



CREATE INDEX "idx_inventario_negocio" ON "public"."inventario" USING "btree" ("negocio_id");



CREATE INDEX "idx_inventario_negocio_id" ON "public"."inventario" USING "btree" ("negocio_id");



CREATE INDEX "idx_inventario_sucursal" ON "public"."inventario" USING "btree" ("sucursal_id");



CREATE INDEX "idx_links_pago_cliente" ON "public"."links_pago" USING "btree" ("cliente_id");



CREATE INDEX "idx_links_pago_estado" ON "public"."links_pago" USING "btree" ("estado");



CREATE INDEX "idx_log_fraude_entidad" ON "public"."log_fraude" USING "btree" ("tipo_entidad", "entidad_id");



CREATE INDEX "idx_mensajes_aval_chat" ON "public"."mensajes_aval_cobrador" USING "btree" ("chat_id");



CREATE INDEX "idx_mensajes_aval_fecha" ON "public"."mensajes_aval_cobrador" USING "btree" ("created_at");



CREATE INDEX "idx_mensajes_chat" ON "public"."mensajes" USING "btree" ("chat_id");



CREATE INDEX "idx_metodos_pago_activo" ON "public"."metodos_pago" USING "btree" ("activo");



CREATE INDEX "idx_metodos_pago_tipo" ON "public"."metodos_pago" USING "btree" ("tipo");



CREATE INDEX "idx_mis_propiedades_asignado" ON "public"."mis_propiedades" USING "btree" ("asignado_a");



CREATE INDEX "idx_mis_propiedades_estado" ON "public"."mis_propiedades" USING "btree" ("estado");



CREATE INDEX "idx_modulos_activos_negocio_id" ON "public"."modulos_activos" USING "btree" ("negocio_id");



CREATE INDEX "idx_modulos_id" ON "public"."modulos_activos" USING "btree" ("modulo_id");



CREATE INDEX "idx_modulos_negocio" ON "public"."modulos_activos" USING "btree" ("negocio_id");



CREATE INDEX "idx_moras_prestamos_amort" ON "public"."moras_prestamos" USING "btree" ("amortizacion_id");



CREATE INDEX "idx_moras_prestamos_estado" ON "public"."moras_prestamos" USING "btree" ("estado");



CREATE INDEX "idx_moras_prestamos_prestamo" ON "public"."moras_prestamos" USING "btree" ("prestamo_id");



CREATE INDEX "idx_moras_tandas_participante" ON "public"."moras_tandas" USING "btree" ("participante_id");



CREATE INDEX "idx_moras_tandas_tanda" ON "public"."moras_tandas" USING "btree" ("tanda_id");



CREATE INDEX "idx_movimientos_capital_fecha" ON "public"."movimientos_capital" USING "btree" ("fecha" DESC);



CREATE INDEX "idx_movimientos_capital_negocio" ON "public"."movimientos_capital" USING "btree" ("negocio_id");



CREATE INDEX "idx_mv_cobranza_negocio_fecha" ON "public"."mv_cobranza_dia" USING "btree" ("negocio_id", "fecha_vencimiento");



CREATE UNIQUE INDEX "idx_mv_kpis_mes_negocio" ON "public"."mv_kpis_mes" USING "btree" ("negocio_id");



CREATE UNIQUE INDEX "idx_mv_resumen_cartera_negocio" ON "public"."mv_resumen_cartera" USING "btree" ("negocio_id");



CREATE UNIQUE INDEX "idx_mv_resumen_mensual" ON "public"."mv_resumen_mensual_prestamos" USING "btree" ("mes", "negocio_id");



CREATE UNIQUE INDEX "idx_mv_resumen_pagos" ON "public"."mv_resumen_mensual_pagos" USING "btree" ("mes", "negocio_id");



CREATE UNIQUE INDEX "idx_mv_top_clientes_pk" ON "public"."mv_top_clientes" USING "btree" ("negocio_id", "cliente_id");



CREATE INDEX "idx_mv_top_clientes_ranking" ON "public"."mv_top_clientes" USING "btree" ("negocio_id", "monto_total" DESC);



CREATE INDEX "idx_nice_clientes_auth" ON "public"."nice_clientes" USING "btree" ("auth_uid");



CREATE INDEX "idx_nice_clientes_vendedora" ON "public"."nice_clientes" USING "btree" ("vendedora_id");



CREATE INDEX "idx_nice_inv_mov_negocio" ON "public"."nice_inventario_movimientos" USING "btree" ("negocio_id");



CREATE INDEX "idx_nice_inv_mov_producto" ON "public"."nice_inventario_movimientos" USING "btree" ("producto_id");



CREATE INDEX "idx_nice_inv_mov_vendedora" ON "public"."nice_inventario_movimientos" USING "btree" ("vendedora_id");



CREATE INDEX "idx_nice_inv_producto" ON "public"."nice_inventario_vendedora" USING "btree" ("producto_id");



CREATE INDEX "idx_nice_inv_vendedora" ON "public"."nice_inventario_vendedora" USING "btree" ("vendedora_id");



CREATE INDEX "idx_nice_inventario_movimientos_negocio_id" ON "public"."nice_inventario_movimientos" USING "btree" ("negocio_id");



CREATE INDEX "idx_nice_pagos_pedido" ON "public"."nice_pagos" USING "btree" ("pedido_id");



CREATE INDEX "idx_nice_pedidos_cliente" ON "public"."nice_pedidos" USING "btree" ("cliente_id");



CREATE INDEX "idx_nice_pedidos_estado" ON "public"."nice_pedidos" USING "btree" ("estado");



CREATE INDEX "idx_nice_pedidos_vendedora" ON "public"."nice_pedidos" USING "btree" ("vendedora_id");



CREATE INDEX "idx_nice_productos_categoria" ON "public"."nice_productos" USING "btree" ("categoria_id");



CREATE INDEX "idx_nice_vendedoras_auth" ON "public"."nice_vendedoras" USING "btree" ("auth_uid");



CREATE INDEX "idx_nice_vendedoras_negocio" ON "public"."nice_vendedoras" USING "btree" ("negocio_id");



CREATE INDEX "idx_nice_vendedoras_negocio_id" ON "public"."nice_vendedoras" USING "btree" ("negocio_id");



CREATE INDEX "idx_nice_vendedoras_nivel" ON "public"."nice_vendedoras" USING "btree" ("nivel_id");



CREATE INDEX "idx_notif_doc_aval" ON "public"."notificaciones_documento_aval" USING "btree" ("aval_id");



CREATE INDEX "idx_notif_doc_aval_leida" ON "public"."notificaciones_documento_aval" USING "btree" ("aval_id", "leida");



CREATE INDEX "idx_notif_mora_aval" ON "public"."notificaciones_mora_aval" USING "btree" ("aval_id");



CREATE INDEX "idx_notif_mora_cliente" ON "public"."notificaciones_mora_cliente" USING "btree" ("cliente_id");



CREATE INDEX "idx_notif_mora_fecha" ON "public"."notificaciones_mora_aval" USING "btree" ("created_at");



CREATE INDEX "idx_notif_mora_nivel" ON "public"."notificaciones_mora_aval" USING "btree" ("nivel_mora");



CREATE INDEX "idx_notif_mora_prestamo" ON "public"."notificaciones_mora_aval" USING "btree" ("prestamo_id");



CREATE INDEX "idx_notif_mora_tipo" ON "public"."notificaciones_mora_cliente" USING "btree" ("tipo_deuda");



CREATE INDEX "idx_notif_sistema_fecha" ON "public"."notificaciones_sistema" USING "btree" ("fecha");



CREATE INDEX "idx_notif_sistema_tipo" ON "public"."notificaciones_sistema" USING "btree" ("tipo");



CREATE INDEX "idx_notificaciones_leida" ON "public"."notificaciones" USING "btree" ("leida");



CREATE INDEX "idx_notificaciones_masivas_negocio_id" ON "public"."notificaciones_masivas" USING "btree" ("negocio_id");



CREATE INDEX "idx_notificaciones_mora_prestamo" ON "public"."notificaciones_mora" USING "btree" ("prestamo_id");



CREATE INDEX "idx_notificaciones_no_leidas" ON "public"."notificaciones" USING "btree" ("usuario_id") WHERE ("leida" = false);



CREATE INDEX "idx_notificaciones_sistema_negocio_id" ON "public"."notificaciones_sistema" USING "btree" ("negocio_id");



CREATE INDEX "idx_notificaciones_usuario" ON "public"."notificaciones" USING "btree" ("usuario_id");



CREATE INDEX "idx_notificaciones_usuario_leida" ON "public"."notificaciones" USING "btree" ("usuario_id", "leida");



CREATE INDEX "idx_notificaciones_usuario_no_leidas" ON "public"."notificaciones" USING "btree" ("usuario_id", "created_at" DESC) WHERE ("leida" = false);



CREATE INDEX "idx_pagos_cliente" ON "public"."pagos" USING "btree" ("cliente_id");



CREATE INDEX "idx_pagos_cliente_fecha" ON "public"."pagos" USING "btree" ("cliente_id", "fecha_pago");



CREATE INDEX "idx_pagos_fecha" ON "public"."pagos" USING "btree" ("fecha_pago");



CREATE INDEX "idx_pagos_negocio" ON "public"."pagos" USING "btree" ("negocio_id");



CREATE INDEX "idx_pagos_negocio_fecha" ON "public"."pagos" USING "btree" ("negocio_id", "fecha_pago" DESC);



CREATE INDEX "idx_pagos_negocio_id" ON "public"."pagos" USING "btree" ("negocio_id");



CREATE INDEX "idx_pagos_prestamo" ON "public"."pagos" USING "btree" ("prestamo_id");



CREATE INDEX "idx_pagos_propiedades_estado" ON "public"."pagos_propiedades" USING "btree" ("estado");



CREATE INDEX "idx_pagos_propiedades_fecha" ON "public"."pagos_propiedades" USING "btree" ("fecha_programada");



CREATE INDEX "idx_pagos_propiedades_propiedad" ON "public"."pagos_propiedades" USING "btree" ("propiedad_id");



CREATE INDEX "idx_pagos_stripe" ON "public"."pagos" USING "btree" ("stripe_payment_id");



CREATE INDEX "idx_pagos_tanda" ON "public"."pagos" USING "btree" ("tanda_id");



CREATE INDEX "idx_preferencias_usuario" ON "public"."preferencias_usuario" USING "btree" ("usuario_id");



CREATE INDEX "idx_prestamos_activos" ON "public"."prestamos" USING "btree" ("negocio_id", "cliente_id", "fecha_creacion") WHERE ("estado" = ANY (ARRAY['activo'::"text", 'mora'::"text"]));



CREATE INDEX "idx_prestamos_avales_aval" ON "public"."prestamos_avales" USING "btree" ("aval_id");



CREATE INDEX "idx_prestamos_avales_prestamo" ON "public"."prestamos_avales" USING "btree" ("prestamo_id");



CREATE INDEX "idx_prestamos_cliente" ON "public"."prestamos" USING "btree" ("cliente_id");



CREATE INDEX "idx_prestamos_cliente_estado" ON "public"."prestamos" USING "btree" ("cliente_id", "estado");



CREATE INDEX "idx_prestamos_en_mora" ON "public"."prestamos" USING "btree" ("cliente_id") WHERE ("estado" = 'mora'::"text");



CREATE INDEX "idx_prestamos_estado" ON "public"."prestamos" USING "btree" ("estado");



CREATE INDEX "idx_prestamos_fecha" ON "public"."prestamos" USING "btree" ("fecha_creacion");



CREATE INDEX "idx_prestamos_fecha_estado" ON "public"."prestamos" USING "btree" ("fecha_creacion", "estado");



CREATE INDEX "idx_prestamos_mora" ON "public"."prestamos" USING "btree" ("negocio_id", "fecha_creacion") WHERE ("estado" = 'mora'::"text");



CREATE INDEX "idx_prestamos_negocio" ON "public"."prestamos" USING "btree" ("negocio_id");



CREATE INDEX "idx_prestamos_negocio_estado" ON "public"."prestamos" USING "btree" ("negocio_id", "estado");



CREATE INDEX "idx_prestamos_negocio_fecha" ON "public"."prestamos" USING "btree" ("negocio_id", "fecha_creacion" DESC);



CREATE INDEX "idx_prestamos_negocio_id" ON "public"."prestamos" USING "btree" ("negocio_id");



CREATE INDEX "idx_prestamos_stripe_sub" ON "public"."prestamos" USING "btree" ("stripe_subscription_id");



CREATE INDEX "idx_prestamos_sucursal" ON "public"."prestamos" USING "btree" ("sucursal_id");



CREATE INDEX "idx_promesas_cliente" ON "public"."promesas_pago" USING "btree" ("cliente_id");



CREATE INDEX "idx_promesas_pago_fecha" ON "public"."promesas_pago" USING "btree" ("fecha_compromiso");



CREATE INDEX "idx_promesas_prestamo" ON "public"."promesas_pago" USING "btree" ("prestamo_id");



CREATE INDEX "idx_puri_cliente_contactos_cliente" ON "public"."purificadora_cliente_contactos" USING "btree" ("cliente_id");



CREATE INDEX "idx_puri_cliente_documentos_cliente" ON "public"."purificadora_cliente_documentos" USING "btree" ("cliente_id");



CREATE INDEX "idx_puri_cliente_notas_cliente" ON "public"."purificadora_cliente_notas" USING "btree" ("cliente_id");



CREATE INDEX "idx_puri_garrafones_hist_fecha" ON "public"."purificadora_garrafones_historial" USING "btree" ("fecha");



CREATE INDEX "idx_puri_garrafones_hist_negocio" ON "public"."purificadora_garrafones_historial" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_clientes_auth" ON "public"."purificadora_clientes" USING "btree" ("auth_uid");



CREATE INDEX "idx_purificadora_clientes_negocio" ON "public"."purificadora_clientes" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_clientes_negocio_id" ON "public"."purificadora_clientes" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_clientes_repartidor" ON "public"."purificadora_clientes" USING "btree" ("repartidor_id");



CREATE INDEX "idx_purificadora_entregas_cliente" ON "public"."purificadora_entregas" USING "btree" ("cliente_id");



CREATE INDEX "idx_purificadora_entregas_estado" ON "public"."purificadora_entregas" USING "btree" ("estado");



CREATE INDEX "idx_purificadora_entregas_fecha" ON "public"."purificadora_entregas" USING "btree" ("fecha_programada");



CREATE INDEX "idx_purificadora_entregas_repartidor" ON "public"."purificadora_entregas" USING "btree" ("repartidor_id");



CREATE INDEX "idx_purificadora_garrafones_historial_negocio_id" ON "public"."purificadora_garrafones_historial" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_gastos_fecha" ON "public"."purificadora_gastos" USING "btree" ("fecha");



CREATE INDEX "idx_purificadora_gastos_negocio" ON "public"."purificadora_gastos" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_gastos_negocio_id" ON "public"."purificadora_gastos" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_inv_garrafones_negocio" ON "public"."purificadora_inventario_garrafones" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_inventario_garrafones_negocio_id" ON "public"."purificadora_inventario_garrafones" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_pagos_cliente" ON "public"."purificadora_pagos" USING "btree" ("cliente_id");



CREATE INDEX "idx_purificadora_pagos_entrega" ON "public"."purificadora_pagos" USING "btree" ("entrega_id");



CREATE INDEX "idx_purificadora_pagos_negocio_id" ON "public"."purificadora_pagos" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_produccion_fecha" ON "public"."purificadora_produccion" USING "btree" ("fecha");



CREATE INDEX "idx_purificadora_produccion_negocio" ON "public"."purificadora_produccion" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_produccion_negocio_id" ON "public"."purificadora_produccion" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_repartidores_auth" ON "public"."purificadora_repartidores" USING "btree" ("auth_uid");



CREATE INDEX "idx_purificadora_repartidores_disponible" ON "public"."purificadora_repartidores" USING "btree" ("disponible");



CREATE INDEX "idx_purificadora_repartidores_negocio" ON "public"."purificadora_repartidores" USING "btree" ("negocio_id");



CREATE INDEX "idx_purificadora_repartidores_negocio_id" ON "public"."purificadora_repartidores" USING "btree" ("negocio_id");



CREATE INDEX "idx_qr_cobros_cliente" ON "public"."qr_cobros" USING "btree" ("cliente_id");



CREATE INDEX "idx_qr_cobros_cobrador" ON "public"."qr_cobros" USING "btree" ("cobrador_id");



CREATE INDEX "idx_qr_cobros_codigo" ON "public"."qr_cobros" USING "btree" ("codigo_qr");



CREATE INDEX "idx_qr_cobros_config_negocio_id" ON "public"."qr_cobros_config" USING "btree" ("negocio_id");



CREATE INDEX "idx_qr_cobros_estado" ON "public"."qr_cobros" USING "btree" ("estado");



CREATE INDEX "idx_qr_cobros_fecha" ON "public"."qr_cobros" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_qr_cobros_referencia" ON "public"."qr_cobros" USING "btree" ("referencia_id");



CREATE INDEX "idx_qr_cobros_reportes_negocio_id" ON "public"."qr_cobros_reportes" USING "btree" ("negocio_id");



CREATE INDEX "idx_qr_cobros_tipo" ON "public"."qr_cobros" USING "btree" ("tipo_cobro");



CREATE INDEX "idx_qr_escaneos_cobro" ON "public"."qr_cobros_escaneos" USING "btree" ("qr_cobro_id");



CREATE INDEX "idx_qr_escaneos_qr" ON "public"."qr_cobros_escaneos" USING "btree" ("qr_cobro_id");



CREATE INDEX "idx_qr_estadisticas_fecha" ON "public"."qr_cobros_estadisticas_diarias" USING "btree" ("fecha");



CREATE INDEX "idx_qr_estadisticas_negocio" ON "public"."qr_cobros_estadisticas_diarias" USING "btree" ("negocio_id");



CREATE INDEX "idx_recordatorios_fecha" ON "public"."recordatorios" USING "btree" ("fecha_recordatorio");



CREATE INDEX "idx_recordatorios_usuario" ON "public"."recordatorios" USING "btree" ("usuario_id");



CREATE INDEX "idx_referencias_aval" ON "public"."referencias_aval" USING "btree" ("aval_id");



CREATE INDEX "idx_registros_cobro_cliente" ON "public"."registros_cobro" USING "btree" ("cliente_id");



CREATE INDEX "idx_registros_cobro_estado" ON "public"."registros_cobro" USING "btree" ("estado");



CREATE INDEX "idx_registros_cobro_fecha" ON "public"."registros_cobro" USING "btree" ("fecha_registro");



CREATE INDEX "idx_registros_cobro_pendientes" ON "public"."registros_cobro" USING "btree" ("fecha_registro" DESC) WHERE (("estado")::"text" = 'pendiente'::"text");



CREATE INDEX "idx_registros_cobro_prestamo" ON "public"."registros_cobro" USING "btree" ("prestamo_id");



CREATE INDEX "idx_registros_cobro_tanda" ON "public"."registros_cobro" USING "btree" ("tanda_id");



CREATE INDEX "idx_seguimiento_expediente" ON "public"."seguimiento_judicial" USING "btree" ("expediente_id");



CREATE INDEX "idx_stripe_log_cliente" ON "public"."stripe_transactions_log" USING "btree" ("cliente_id");



CREATE INDEX "idx_stripe_log_event_id" ON "public"."stripe_transactions_log" USING "btree" ("stripe_event_id");



CREATE INDEX "idx_stripe_log_evento" ON "public"."stripe_transactions_log" USING "btree" ("tipo_evento");



CREATE INDEX "idx_stripe_log_negocio" ON "public"."stripe_transactions_log" USING "btree" ("negocio_id");



CREATE INDEX "idx_stripe_log_payment_intent" ON "public"."stripe_transactions_log" USING "btree" ("stripe_payment_intent_id");



CREATE INDEX "idx_stripe_transactions_log_negocio_id" ON "public"."stripe_transactions_log" USING "btree" ("negocio_id");



CREATE INDEX "idx_sucursales_negocio" ON "public"."sucursales" USING "btree" ("negocio_id");



CREATE INDEX "idx_sucursales_negocio_id" ON "public"."sucursales" USING "btree" ("negocio_id");



CREATE INDEX "idx_tanda_pagos_estado" ON "public"."tanda_pagos" USING "btree" ("estado");



CREATE INDEX "idx_tanda_pagos_fecha" ON "public"."tanda_pagos" USING "btree" ("fecha_programada");



CREATE INDEX "idx_tanda_pagos_participante" ON "public"."tanda_pagos" USING "btree" ("tanda_participante_id");



CREATE INDEX "idx_tanda_participantes_cliente" ON "public"."tanda_participantes" USING "btree" ("cliente_id");



CREATE INDEX "idx_tanda_participantes_tanda" ON "public"."tanda_participantes" USING "btree" ("tanda_id");



CREATE INDEX "idx_tandas_activas" ON "public"."tandas" USING "btree" ("negocio_id", "fecha_inicio") WHERE ("estado" = 'activa'::"text");



CREATE INDEX "idx_tandas_avales_aval" ON "public"."tandas_avales" USING "btree" ("aval_id");



CREATE INDEX "idx_tandas_avales_tanda" ON "public"."tandas_avales" USING "btree" ("tanda_id");



CREATE INDEX "idx_tandas_estado" ON "public"."tandas" USING "btree" ("estado");



CREATE INDEX "idx_tandas_negocio" ON "public"."tandas" USING "btree" ("negocio_id");



CREATE INDEX "idx_tandas_negocio_estado" ON "public"."tandas" USING "btree" ("negocio_id", "estado");



CREATE INDEX "idx_tandas_negocio_id" ON "public"."tandas" USING "btree" ("negocio_id");



CREATE INDEX "idx_tandas_sucursal" ON "public"."tandas" USING "btree" ("sucursal_id");



CREATE INDEX "idx_tarjetas_alertas_tarjeta" ON "public"."tarjetas_alertas" USING "btree" ("tarjeta_id");



CREATE INDEX "idx_tarjetas_cliente" ON "public"."tarjetas_digitales" USING "btree" ("cliente_id");



CREATE UNIQUE INDEX "idx_tarjetas_codigo_negocio" ON "public"."tarjetas_digitales" USING "btree" ("negocio_id", "codigo_tarjeta") WHERE ("codigo_tarjeta" IS NOT NULL);



CREATE INDEX "idx_tarjetas_config_activo" ON "public"."tarjetas_config" USING "btree" ("activo") WHERE ("activo" = true);



CREATE INDEX "idx_tarjetas_config_negocio" ON "public"."tarjetas_config" USING "btree" ("negocio_id");



CREATE INDEX "idx_tarjetas_config_proveedor" ON "public"."tarjetas_config" USING "btree" ("proveedor");



CREATE INDEX "idx_tarjetas_digitales_negocio_id" ON "public"."tarjetas_digitales" USING "btree" ("negocio_id");



CREATE INDEX "idx_tarjetas_estado" ON "public"."tarjetas_digitales" USING "btree" ("estado");



CREATE INDEX "idx_tarjetas_log_tarjeta" ON "public"."tarjetas_log" USING "btree" ("tarjeta_id");



CREATE INDEX "idx_tarjetas_negocio" ON "public"."tarjetas_digitales" USING "btree" ("negocio_id");



CREATE INDEX "idx_tarjetas_recargas_tarjeta" ON "public"."tarjetas_recargas" USING "btree" ("tarjeta_id");



CREATE INDEX "idx_tarjetas_servicio_activa" ON "public"."tarjetas_servicio" USING "btree" ("activa");



CREATE INDEX "idx_tarjetas_servicio_codigo" ON "public"."tarjetas_servicio" USING "btree" ("codigo");



CREATE INDEX "idx_tarjetas_servicio_modulo" ON "public"."tarjetas_servicio" USING "btree" ("modulo");



CREATE INDEX "idx_tarjetas_servicio_negocio" ON "public"."tarjetas_servicio" USING "btree" ("negocio_id");



CREATE INDEX "idx_tarjetas_titulares_tarjeta" ON "public"."tarjetas_titulares" USING "btree" ("tarjeta_id");



CREATE INDEX "idx_tarjetas_trans_fecha" ON "public"."tarjetas_transacciones" USING "btree" ("created_at");



CREATE INDEX "idx_tarjetas_trans_tarjeta" ON "public"."tarjetas_transacciones" USING "btree" ("tarjeta_id");



CREATE INDEX "idx_tarjetas_trans_tipo" ON "public"."tarjetas_transacciones" USING "btree" ("tipo");



CREATE INDEX "idx_tarjetas_ultimos_cuatro" ON "public"."tarjetas_digitales" USING "btree" ("ultimos_cuatro");



CREATE INDEX "idx_tarjetas_virtuales_cliente" ON "public"."tarjetas_virtuales" USING "btree" ("cliente_id");



CREATE INDEX "idx_tarjetas_virtuales_negocio" ON "public"."tarjetas_virtuales" USING "btree" ("negocio_id");



CREATE INDEX "idx_tarjetas_virtuales_negocio_id" ON "public"."tarjetas_virtuales" USING "btree" ("negocio_id");



CREATE INDEX "idx_transacciones_tarjeta" ON "public"."transacciones_tarjeta" USING "btree" ("tarjeta_id");



CREATE INDEX "idx_usuarios_negocios_negocio" ON "public"."usuarios_negocios" USING "btree" ("negocio_id");



CREATE INDEX "idx_usuarios_negocios_negocio_id" ON "public"."usuarios_negocios" USING "btree" ("negocio_id");



CREATE INDEX "idx_usuarios_negocios_usuario" ON "public"."usuarios_negocios" USING "btree" ("usuario_id");



CREATE INDEX "idx_usuarios_sucursales_sucursal" ON "public"."usuarios_sucursales" USING "btree" ("sucursal_id");



CREATE INDEX "idx_usuarios_sucursales_usuario" ON "public"."usuarios_sucursales" USING "btree" ("usuario_id");



CREATE INDEX "idx_validaciones_aval" ON "public"."validaciones_aval" USING "btree" ("aval_id");



CREATE INDEX "idx_ventas_cliente_contactos_cliente" ON "public"."ventas_cliente_contactos" USING "btree" ("cliente_id");



CREATE INDEX "idx_ventas_cliente_creditos_cliente" ON "public"."ventas_cliente_creditos" USING "btree" ("cliente_id");



CREATE INDEX "idx_ventas_cliente_documentos_cliente" ON "public"."ventas_cliente_documentos" USING "btree" ("cliente_id");



CREATE INDEX "idx_ventas_cliente_notas_cliente" ON "public"."ventas_cliente_notas" USING "btree" ("cliente_id");



CREATE INDEX "idx_ventas_clientes_auth" ON "public"."ventas_clientes" USING "btree" ("auth_uid");



CREATE INDEX "idx_ventas_clientes_vendedor" ON "public"."ventas_clientes" USING "btree" ("vendedor_id");



CREATE INDEX "idx_ventas_cotizaciones_cliente" ON "public"."ventas_cotizaciones" USING "btree" ("cliente_id");



CREATE INDEX "idx_ventas_cotizaciones_negocio" ON "public"."ventas_cotizaciones" USING "btree" ("negocio_id");



CREATE INDEX "idx_ventas_cotizaciones_negocio_id" ON "public"."ventas_cotizaciones" USING "btree" ("negocio_id");



CREATE INDEX "idx_ventas_pagos_pedido" ON "public"."ventas_pagos" USING "btree" ("pedido_id");



CREATE INDEX "idx_ventas_pedidos_cliente" ON "public"."ventas_pedidos" USING "btree" ("cliente_id");



CREATE INDEX "idx_ventas_pedidos_detalle_pedido" ON "public"."ventas_pedidos_detalle" USING "btree" ("pedido_id");



CREATE INDEX "idx_ventas_pedidos_detalle_producto" ON "public"."ventas_pedidos_detalle" USING "btree" ("producto_id");



CREATE INDEX "idx_ventas_pedidos_estado" ON "public"."ventas_pedidos" USING "btree" ("estado");



CREATE INDEX "idx_ventas_pedidos_vendedor" ON "public"."ventas_pedidos" USING "btree" ("vendedor_id");



CREATE INDEX "idx_ventas_productos_categoria" ON "public"."ventas_productos" USING "btree" ("categoria_id");



CREATE INDEX "idx_ventas_vendedores_auth" ON "public"."ventas_vendedores" USING "btree" ("auth_uid");



CREATE INDEX "idx_ventas_vendedores_negocio" ON "public"."ventas_vendedores" USING "btree" ("negocio_id");



CREATE INDEX "idx_ventas_vendedores_negocio_id" ON "public"."ventas_vendedores" USING "btree" ("negocio_id");



CREATE INDEX "idx_verificaciones_aval" ON "public"."verificaciones_identidad" USING "btree" ("aval_id");



CREATE OR REPLACE TRIGGER "set_updated_at_aportaciones" BEFORE UPDATE ON "public"."aportaciones" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "tr_formularios_config_updated" BEFORE UPDATE ON "public"."formularios_qr_config" FOR EACH ROW EXECUTE FUNCTION "public"."update_formulario_config_timestamp"();



CREATE OR REPLACE TRIGGER "tr_generate_deep_link" BEFORE INSERT ON "public"."tarjetas_servicio" FOR EACH ROW EXECUTE FUNCTION "public"."generate_tarjeta_deep_link"();



CREATE OR REPLACE TRIGGER "tr_increment_escaneos" AFTER INSERT ON "public"."tarjetas_servicio_escaneos" FOR EACH ROW EXECUTE FUNCTION "public"."increment_tarjeta_escaneos"();



CREATE OR REPLACE TRIGGER "tr_tarjetas_servicio_updated" BEFORE UPDATE ON "public"."tarjetas_servicio" FOR EACH ROW EXECUTE FUNCTION "public"."update_tarjeta_servicio_timestamp"();



CREATE OR REPLACE TRIGGER "trg_notificar_cobro" BEFORE UPDATE ON "public"."qr_cobros" FOR EACH ROW EXECUTE FUNCTION "public"."notificar_cobro_confirmado"();



CREATE OR REPLACE TRIGGER "trigger_actualizar_leidos" AFTER UPDATE ON "public"."notificaciones" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_contador_leidos"();



CREATE OR REPLACE TRIGGER "trigger_actualizar_ultimo_mensaje" AFTER INSERT ON "public"."chat_mensajes" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_ultimo_mensaje_conversacion"();



CREATE OR REPLACE TRIGGER "trigger_asignar_superadmin" AFTER INSERT ON "public"."usuarios" FOR EACH ROW EXECUTE FUNCTION "public"."asignar_superadmin_si_no_existe"();



CREATE OR REPLACE TRIGGER "trigger_autoconfirmar_efectivo" BEFORE INSERT ON "public"."registros_cobro" FOR EACH ROW EXECUTE FUNCTION "public"."autoconfirmar_cobro_efectivo"();



CREATE OR REPLACE TRIGGER "trigger_climas_sol_qr_updated" BEFORE UPDATE ON "public"."climas_solicitudes_qr" FOR EACH ROW EXECUTE FUNCTION "public"."update_climas_solicitud_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_inicializar_nice" AFTER INSERT ON "public"."negocios" FOR EACH ROW EXECUTE FUNCTION "public"."inicializar_datos_nice"();



CREATE OR REPLACE TRIGGER "trigger_invalidar_cache_pagos" AFTER INSERT OR DELETE OR UPDATE ON "public"."pagos" FOR EACH ROW EXECUTE FUNCTION "public"."invalidar_cache_estadisticas"();



CREATE OR REPLACE TRIGGER "trigger_invalidar_cache_prestamos" AFTER INSERT OR DELETE OR UPDATE ON "public"."prestamos" FOR EACH ROW EXECUTE FUNCTION "public"."invalidar_cache_estadisticas"();



CREATE OR REPLACE TRIGGER "trigger_nice_comision_entrega" BEFORE UPDATE ON "public"."nice_pedidos" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_nice_comision_entrega"();



CREATE OR REPLACE TRIGGER "trigger_nice_pedido_folio" BEFORE INSERT ON "public"."nice_pedidos" FOR EACH ROW EXECUTE FUNCTION "public"."trigger_nice_pedido_folio"();



CREATE OR REPLACE TRIGGER "trigger_notificar_pago_vencido" AFTER UPDATE ON "public"."amortizaciones" FOR EACH ROW EXECUTE FUNCTION "public"."notificar_pago_vencido"();



CREATE OR REPLACE TRIGGER "trigger_tarjetas_config_updated_at" BEFORE UPDATE ON "public"."tarjetas_config" FOR EACH ROW EXECUTE FUNCTION "public"."update_tarjetas_config_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_update_avales_updated_at" BEFORE UPDATE ON "public"."avales" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_chat_conversaciones_updated_at" BEFORE UPDATE ON "public"."chat_conversaciones" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_clientes_updated_at" BEFORE UPDATE ON "public"."clientes" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_colaboradores_updated_at" BEFORE UPDATE ON "public"."colaboradores" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_contratos_updated_at" BEFORE UPDATE ON "public"."contratos" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_documentos_aval_updated_at" BEFORE UPDATE ON "public"."documentos_aval" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_documentos_cliente_updated_at" BEFORE UPDATE ON "public"."documentos_cliente" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_empleados_updated_at" BEFORE UPDATE ON "public"."empleados" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_facturacion_productos_updated_at" BEFORE UPDATE ON "public"."facturacion_productos" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_nice_inventario_vendedora_updated_at" BEFORE UPDATE ON "public"."nice_inventario_vendedora" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_pago_propiedad" BEFORE UPDATE ON "public"."pagos_propiedades" FOR EACH ROW EXECUTE FUNCTION "public"."update_propiedad_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_update_pagos_updated_at" BEFORE UPDATE ON "public"."pagos" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_prestamos_updated_at" BEFORE UPDATE ON "public"."prestamos" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_propiedad" BEFORE UPDATE ON "public"."mis_propiedades" FOR EACH ROW EXECUTE FUNCTION "public"."update_propiedad_timestamp"();



CREATE OR REPLACE TRIGGER "trigger_update_qr_cobros_config_updated_at" BEFORE UPDATE ON "public"."qr_cobros_config" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_registros_cobro_updated_at" BEFORE UPDATE ON "public"."registros_cobro" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_tandas_updated_at" BEFORE UPDATE ON "public"."tandas" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_tarjetas_virtuales_updated_at" BEFORE UPDATE ON "public"."tarjetas_virtuales" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_usuarios_updated_at" BEFORE UPDATE ON "public"."usuarios" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_ventas_cliente_creditos_updated_at" BEFORE UPDATE ON "public"."ventas_cliente_creditos" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_update_ventas_cotizaciones_updated_at" BEFORE UPDATE ON "public"."ventas_cotizaciones" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_avales" BEFORE UPDATE ON "public"."avales" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_chat_conversaciones" BEFORE UPDATE ON "public"."chat_conversaciones" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_clientes" BEFORE UPDATE ON "public"."clientes" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_configuracion_global" BEFORE UPDATE ON "public"."configuracion_global" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_empleados" BEFORE UPDATE ON "public"."empleados" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_metodos_pago" BEFORE UPDATE ON "public"."metodos_pago" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_prestamos" BEFORE UPDATE ON "public"."prestamos" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_promociones" BEFORE UPDATE ON "public"."promociones" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_sucursales" BEFORE UPDATE ON "public"."sucursales" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_tandas" BEFORE UPDATE ON "public"."tandas" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_temas_app" BEFORE UPDATE ON "public"."temas_app" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



CREATE OR REPLACE TRIGGER "trigger_updated_at_usuarios" BEFORE UPDATE ON "public"."usuarios" FOR EACH ROW EXECUTE FUNCTION "public"."actualizar_updated_at"();



ALTER TABLE ONLY "public"."activity_log"
    ADD CONSTRAINT "activity_log_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."activos_capital"
    ADD CONSTRAINT "activos_capital_asignado_a_fkey" FOREIGN KEY ("asignado_a") REFERENCES "public"."empleados"("id");



ALTER TABLE ONLY "public"."activos_capital"
    ADD CONSTRAINT "activos_capital_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."activos_capital"
    ADD CONSTRAINT "activos_capital_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."acuses_recibo"
    ADD CONSTRAINT "acuses_recibo_expediente_id_fkey" FOREIGN KEY ("expediente_id") REFERENCES "public"."expedientes_legales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."acuses_recibo"
    ADD CONSTRAINT "acuses_recibo_notificacion_id_fkey" FOREIGN KEY ("notificacion_id") REFERENCES "public"."notificaciones_mora"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."aires_equipos"
    ADD CONSTRAINT "aires_equipos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."aires_equipos"
    ADD CONSTRAINT "aires_equipos_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."aires_garantias"
    ADD CONSTRAINT "aires_garantias_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."aires_equipos"("id");



ALTER TABLE ONLY "public"."aires_garantias"
    ADD CONSTRAINT "aires_garantias_orden_servicio_id_fkey" FOREIGN KEY ("orden_servicio_id") REFERENCES "public"."aires_ordenes_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."aires_ordenes_servicio"
    ADD CONSTRAINT "aires_ordenes_servicio_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."aires_equipos"("id");



ALTER TABLE ONLY "public"."aires_ordenes_servicio"
    ADD CONSTRAINT "aires_ordenes_servicio_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."aires_ordenes_servicio"
    ADD CONSTRAINT "aires_ordenes_servicio_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."aires_tecnicos"("id");



ALTER TABLE ONLY "public"."aires_tecnicos"
    ADD CONSTRAINT "aires_tecnicos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."aires_tecnicos"
    ADD CONSTRAINT "aires_tecnicos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."alertas_sistema"
    ADD CONSTRAINT "alertas_sistema_usuario_destino_id_fkey" FOREIGN KEY ("usuario_destino_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."amortizaciones"
    ADD CONSTRAINT "amortizaciones_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."aportaciones"
    ADD CONSTRAINT "aportaciones_colaborador_id_fkey" FOREIGN KEY ("colaborador_id") REFERENCES "public"."colaboradores"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."aportaciones"
    ADD CONSTRAINT "aportaciones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id");



ALTER TABLE ONLY "public"."aportaciones"
    ADD CONSTRAINT "aportaciones_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."auditoria_acceso"
    ADD CONSTRAINT "auditoria_acceso_rol_id_fkey" FOREIGN KEY ("rol_id") REFERENCES "public"."roles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."auditoria_acceso"
    ADD CONSTRAINT "auditoria_acceso_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."auditoria_legal"
    ADD CONSTRAINT "auditoria_legal_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."auditoria_legal"
    ADD CONSTRAINT "auditoria_legal_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."auditoria"
    ADD CONSTRAINT "auditoria_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."aval_checkins"
    ADD CONSTRAINT "aval_checkins_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."aval_checkins"
    ADD CONSTRAINT "aval_checkins_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."avales"
    ADD CONSTRAINT "avales_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."avales"
    ADD CONSTRAINT "avales_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."avales"
    ADD CONSTRAINT "avales_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."avales"
    ADD CONSTRAINT "avales_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."avales"
    ADD CONSTRAINT "avales_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."cache_estadisticas"
    ADD CONSTRAINT "cache_estadisticas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."calendario"
    ADD CONSTRAINT "calendario_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."calendario"
    ADD CONSTRAINT "calendario_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."calendario"
    ADD CONSTRAINT "calendario_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_aval_cobrador"
    ADD CONSTRAINT "chat_aval_cobrador_admin_id_fkey" FOREIGN KEY ("admin_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_aval_cobrador"
    ADD CONSTRAINT "chat_aval_cobrador_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_aval_cobrador"
    ADD CONSTRAINT "chat_aval_cobrador_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_conversaciones"
    ADD CONSTRAINT "chat_conversaciones_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_conversaciones"
    ADD CONSTRAINT "chat_conversaciones_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_conversaciones"
    ADD CONSTRAINT "chat_conversaciones_creado_por_usuario_id_fkey" FOREIGN KEY ("creado_por_usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_conversaciones"
    ADD CONSTRAINT "chat_conversaciones_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_conversaciones"
    ADD CONSTRAINT "chat_conversaciones_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_mensajes"
    ADD CONSTRAINT "chat_mensajes_conversacion_id_fkey" FOREIGN KEY ("conversacion_id") REFERENCES "public"."chat_conversaciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_mensajes"
    ADD CONSTRAINT "chat_mensajes_remitente_usuario_id_fkey" FOREIGN KEY ("remitente_usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."chat_participantes"
    ADD CONSTRAINT "chat_participantes_conversacion_id_fkey" FOREIGN KEY ("conversacion_id") REFERENCES "public"."chat_conversaciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_participantes"
    ADD CONSTRAINT "chat_participantes_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chats"
    ADD CONSTRAINT "chats_usuario1_fkey" FOREIGN KEY ("usuario1") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chats"
    ADD CONSTRAINT "chats_usuario2_fkey" FOREIGN KEY ("usuario2") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clientes_bloqueados_mora"
    ADD CONSTRAINT "clientes_bloqueados_mora_bloqueado_por_fkey" FOREIGN KEY ("bloqueado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."clientes_bloqueados_mora"
    ADD CONSTRAINT "clientes_bloqueados_mora_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clientes_bloqueados_mora"
    ADD CONSTRAINT "clientes_bloqueados_mora_desbloqueado_por_fkey" FOREIGN KEY ("desbloqueado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."clientes_modulo"
    ADD CONSTRAINT "clientes_modulo_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clientes_modulo"
    ADD CONSTRAINT "clientes_modulo_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clientes"
    ADD CONSTRAINT "clientes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."clientes"
    ADD CONSTRAINT "clientes_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."clientes"
    ADD CONSTRAINT "clientes_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_calendario"
    ADD CONSTRAINT "climas_calendario_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_calendario"
    ADD CONSTRAINT "climas_calendario_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_calendario"
    ADD CONSTRAINT "climas_calendario_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_catalogo_servicios_publico"
    ADD CONSTRAINT "climas_catalogo_servicios_publico_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_certificaciones_tecnico"
    ADD CONSTRAINT "climas_certificaciones_tecnico_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_chat_solicitud"
    ADD CONSTRAINT "climas_chat_solicitud_remitente_id_fkey" FOREIGN KEY ("remitente_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."climas_chat_solicitud"
    ADD CONSTRAINT "climas_chat_solicitud_solicitud_id_fkey" FOREIGN KEY ("solicitud_id") REFERENCES "public"."climas_solicitudes_qr"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_checklist_respuestas"
    ADD CONSTRAINT "climas_checklist_respuestas_checklist_id_fkey" FOREIGN KEY ("checklist_id") REFERENCES "public"."climas_checklist_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_checklist_respuestas"
    ADD CONSTRAINT "climas_checklist_respuestas_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_checklist_respuestas"
    ADD CONSTRAINT "climas_checklist_respuestas_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_checklist_servicio"
    ADD CONSTRAINT "climas_checklist_servicio_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_cliente_contactos"
    ADD CONSTRAINT "climas_cliente_contactos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_cliente_documentos"
    ADD CONSTRAINT "climas_cliente_documentos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_cliente_documentos"
    ADD CONSTRAINT "climas_cliente_documentos_subido_por_fkey" FOREIGN KEY ("subido_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."climas_cliente_notas"
    ADD CONSTRAINT "climas_cliente_notas_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_cliente_notas"
    ADD CONSTRAINT "climas_cliente_notas_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."climas_clientes"
    ADD CONSTRAINT "climas_clientes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_comisiones"
    ADD CONSTRAINT "climas_comisiones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_comisiones"
    ADD CONSTRAINT "climas_comisiones_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_comisiones"
    ADD CONSTRAINT "climas_comisiones_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_comprobantes"
    ADD CONSTRAINT "climas_comprobantes_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_comprobantes"
    ADD CONSTRAINT "climas_comprobantes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_comprobantes"
    ADD CONSTRAINT "climas_comprobantes_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_config_formulario_qr"
    ADD CONSTRAINT "climas_config_formulario_qr_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_configuracion"
    ADD CONSTRAINT "climas_configuracion_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_cotizaciones"
    ADD CONSTRAINT "climas_cotizaciones_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_cotizaciones"
    ADD CONSTRAINT "climas_cotizaciones_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."climas_cotizaciones"
    ADD CONSTRAINT "climas_cotizaciones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_cotizaciones_v2"
    ADD CONSTRAINT "climas_cotizaciones_v2_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_cotizaciones_v2"
    ADD CONSTRAINT "climas_cotizaciones_v2_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."climas_cotizaciones_v2"
    ADD CONSTRAINT "climas_cotizaciones_v2_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_cotizaciones_v2"
    ADD CONSTRAINT "climas_cotizaciones_v2_orden_generada_id_fkey" FOREIGN KEY ("orden_generada_id") REFERENCES "public"."climas_ordenes_servicio"("id");



ALTER TABLE ONLY "public"."climas_equipos_cliente"
    ADD CONSTRAINT "climas_equipos_cliente_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_equipos_cliente"
    ADD CONSTRAINT "climas_equipos_cliente_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."climas_equipos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_equipos"
    ADD CONSTRAINT "climas_equipos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_garantias"
    ADD CONSTRAINT "climas_garantias_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_garantias"
    ADD CONSTRAINT "climas_garantias_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."climas_equipos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_garantias"
    ADD CONSTRAINT "climas_garantias_orden_instalacion_id_fkey" FOREIGN KEY ("orden_instalacion_id") REFERENCES "public"."climas_ordenes_servicio"("id");



ALTER TABLE ONLY "public"."climas_incidencias"
    ADD CONSTRAINT "climas_incidencias_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id");



ALTER TABLE ONLY "public"."climas_incidencias"
    ADD CONSTRAINT "climas_incidencias_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_incidencias"
    ADD CONSTRAINT "climas_incidencias_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_incidencias"
    ADD CONSTRAINT "climas_incidencias_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id");



ALTER TABLE ONLY "public"."climas_inventario_tecnico"
    ADD CONSTRAINT "climas_inventario_tecnico_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."climas_productos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_inventario_tecnico"
    ADD CONSTRAINT "climas_inventario_tecnico_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_mensajes"
    ADD CONSTRAINT "climas_mensajes_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_mensajes"
    ADD CONSTRAINT "climas_mensajes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_mensajes"
    ADD CONSTRAINT "climas_mensajes_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_metricas_tecnico"
    ADD CONSTRAINT "climas_metricas_tecnico_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_movimientos_inventario"
    ADD CONSTRAINT "climas_movimientos_inventario_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."climas_movimientos_inventario"
    ADD CONSTRAINT "climas_movimientos_inventario_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_movimientos_inventario"
    ADD CONSTRAINT "climas_movimientos_inventario_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id");



ALTER TABLE ONLY "public"."climas_movimientos_inventario"
    ADD CONSTRAINT "climas_movimientos_inventario_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."climas_productos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_movimientos_inventario"
    ADD CONSTRAINT "climas_movimientos_inventario_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id");



ALTER TABLE ONLY "public"."climas_ordenes_servicio"
    ADD CONSTRAINT "climas_ordenes_servicio_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_ordenes_servicio"
    ADD CONSTRAINT "climas_ordenes_servicio_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."climas_equipos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_ordenes_servicio"
    ADD CONSTRAINT "climas_ordenes_servicio_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_ordenes_servicio"
    ADD CONSTRAINT "climas_ordenes_servicio_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_pagos"
    ADD CONSTRAINT "climas_pagos_orden_servicio_id_fkey" FOREIGN KEY ("orden_servicio_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_pagos"
    ADD CONSTRAINT "climas_pagos_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."climas_precios_servicio"
    ADD CONSTRAINT "climas_precios_servicio_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_productos"
    ADD CONSTRAINT "climas_productos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_recordatorios_mantenimiento"
    ADD CONSTRAINT "climas_recordatorios_mantenimiento_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_recordatorios_mantenimiento"
    ADD CONSTRAINT "climas_recordatorios_mantenimiento_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."climas_equipos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_recordatorios_mantenimiento"
    ADD CONSTRAINT "climas_recordatorios_mantenimiento_orden_generada_id_fkey" FOREIGN KEY ("orden_generada_id") REFERENCES "public"."climas_ordenes_servicio"("id");



ALTER TABLE ONLY "public"."climas_registro_tiempo"
    ADD CONSTRAINT "climas_registro_tiempo_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_registro_tiempo"
    ADD CONSTRAINT "climas_registro_tiempo_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_solicitud_historial"
    ADD CONSTRAINT "climas_solicitud_historial_solicitud_id_fkey" FOREIGN KEY ("solicitud_id") REFERENCES "public"."climas_solicitudes_qr"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_solicitud_historial"
    ADD CONSTRAINT "climas_solicitud_historial_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."climas_solicitudes_cliente"
    ADD CONSTRAINT "climas_solicitudes_cliente_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."climas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_solicitudes_cliente"
    ADD CONSTRAINT "climas_solicitudes_cliente_equipo_id_fkey" FOREIGN KEY ("equipo_id") REFERENCES "public"."climas_equipos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_solicitudes_cliente"
    ADD CONSTRAINT "climas_solicitudes_cliente_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_solicitudes_cliente"
    ADD CONSTRAINT "climas_solicitudes_cliente_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_solicitudes_qr"
    ADD CONSTRAINT "climas_solicitudes_qr_cliente_creado_id_fkey" FOREIGN KEY ("cliente_creado_id") REFERENCES "public"."climas_clientes"("id");



ALTER TABLE ONLY "public"."climas_solicitudes_qr"
    ADD CONSTRAINT "climas_solicitudes_qr_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_solicitudes_qr"
    ADD CONSTRAINT "climas_solicitudes_qr_orden_creada_id_fkey" FOREIGN KEY ("orden_creada_id") REFERENCES "public"."climas_ordenes_servicio"("id");



ALTER TABLE ONLY "public"."climas_solicitudes_qr"
    ADD CONSTRAINT "climas_solicitudes_qr_revisado_por_fkey" FOREIGN KEY ("revisado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."climas_solicitudes_refacciones"
    ADD CONSTRAINT "climas_solicitudes_refacciones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_solicitudes_refacciones"
    ADD CONSTRAINT "climas_solicitudes_refacciones_orden_id_fkey" FOREIGN KEY ("orden_id") REFERENCES "public"."climas_ordenes_servicio"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_solicitudes_refacciones"
    ADD CONSTRAINT "climas_solicitudes_refacciones_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_tecnico_zonas"
    ADD CONSTRAINT "climas_tecnico_zonas_tecnico_id_fkey" FOREIGN KEY ("tecnico_id") REFERENCES "public"."climas_tecnicos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_tecnico_zonas"
    ADD CONSTRAINT "climas_tecnico_zonas_zona_id_fkey" FOREIGN KEY ("zona_id") REFERENCES "public"."climas_zonas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_tecnicos"
    ADD CONSTRAINT "climas_tecnicos_empleado_id_fkey" FOREIGN KEY ("empleado_id") REFERENCES "public"."empleados"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."climas_tecnicos"
    ADD CONSTRAINT "climas_tecnicos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."climas_zonas"
    ADD CONSTRAINT "climas_zonas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_actividad"
    ADD CONSTRAINT "colaborador_actividad_colaborador_id_fkey" FOREIGN KEY ("colaborador_id") REFERENCES "public"."colaboradores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_actividad"
    ADD CONSTRAINT "colaborador_actividad_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_compensaciones"
    ADD CONSTRAINT "colaborador_compensaciones_aprobado_por_fkey" FOREIGN KEY ("aprobado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."colaborador_compensaciones"
    ADD CONSTRAINT "colaborador_compensaciones_colaborador_id_fkey" FOREIGN KEY ("colaborador_id") REFERENCES "public"."colaboradores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_compensaciones"
    ADD CONSTRAINT "colaborador_compensaciones_tipo_compensacion_id_fkey" FOREIGN KEY ("tipo_compensacion_id") REFERENCES "public"."compensacion_tipos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."colaborador_inversiones"
    ADD CONSTRAINT "colaborador_inversiones_aprobado_por_fkey" FOREIGN KEY ("aprobado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."colaborador_inversiones"
    ADD CONSTRAINT "colaborador_inversiones_colaborador_id_fkey" FOREIGN KEY ("colaborador_id") REFERENCES "public"."colaboradores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_inversiones"
    ADD CONSTRAINT "colaborador_inversiones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_invitaciones"
    ADD CONSTRAINT "colaborador_invitaciones_colaborador_creado_id_fkey" FOREIGN KEY ("colaborador_creado_id") REFERENCES "public"."colaboradores"("id");



ALTER TABLE ONLY "public"."colaborador_invitaciones"
    ADD CONSTRAINT "colaborador_invitaciones_invitado_por_fkey" FOREIGN KEY ("invitado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."colaborador_invitaciones"
    ADD CONSTRAINT "colaborador_invitaciones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_invitaciones"
    ADD CONSTRAINT "colaborador_invitaciones_tipo_id_fkey" FOREIGN KEY ("tipo_id") REFERENCES "public"."colaborador_tipos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."colaborador_pagos"
    ADD CONSTRAINT "colaborador_pagos_colaborador_id_fkey" FOREIGN KEY ("colaborador_id") REFERENCES "public"."colaboradores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_pagos"
    ADD CONSTRAINT "colaborador_pagos_compensacion_id_fkey" FOREIGN KEY ("compensacion_id") REFERENCES "public"."colaborador_compensaciones"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."colaborador_pagos"
    ADD CONSTRAINT "colaborador_pagos_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."colaborador_permisos_modulo"
    ADD CONSTRAINT "colaborador_permisos_modulo_colaborador_id_fkey" FOREIGN KEY ("colaborador_id") REFERENCES "public"."colaboradores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_rendimientos"
    ADD CONSTRAINT "colaborador_rendimientos_colaborador_id_fkey" FOREIGN KEY ("colaborador_id") REFERENCES "public"."colaboradores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaborador_rendimientos"
    ADD CONSTRAINT "colaborador_rendimientos_inversion_id_fkey" FOREIGN KEY ("inversion_id") REFERENCES "public"."colaborador_inversiones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaboradores"
    ADD CONSTRAINT "colaboradores_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."colaboradores"
    ADD CONSTRAINT "colaboradores_tipo_id_fkey" FOREIGN KEY ("tipo_id") REFERENCES "public"."colaborador_tipos"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."colaboradores"
    ADD CONSTRAINT "colaboradores_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."comisiones_empleados"
    ADD CONSTRAINT "comisiones_empleados_empleado_id_fkey" FOREIGN KEY ("empleado_id") REFERENCES "public"."empleados"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comisiones_empleados"
    ADD CONSTRAINT "comisiones_empleados_pagado_por_fkey" FOREIGN KEY ("pagado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."comisiones_empleados"
    ADD CONSTRAINT "comisiones_empleados_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."compensacion_tipos"
    ADD CONSTRAINT "compensacion_tipos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comprobantes"
    ADD CONSTRAINT "comprobantes_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."comprobantes"
    ADD CONSTRAINT "comprobantes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comprobantes_prestamo"
    ADD CONSTRAINT "comprobantes_prestamo_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."comprobantes_prestamo"
    ADD CONSTRAINT "comprobantes_prestamo_subido_por_fkey" FOREIGN KEY ("subido_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."comprobantes"
    ADD CONSTRAINT "comprobantes_subido_por_fkey" FOREIGN KEY ("subido_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."comprobantes"
    ADD CONSTRAINT "comprobantes_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."configuracion_apis"
    ADD CONSTRAINT "configuracion_apis_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."configuracion_moras"
    ADD CONSTRAINT "configuracion_moras_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contratos"
    ADD CONSTRAINT "contratos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."contratos"
    ADD CONSTRAINT "contratos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."contratos"
    ADD CONSTRAINT "contratos_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."documentos_aval"
    ADD CONSTRAINT "documentos_aval_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documentos_aval"
    ADD CONSTRAINT "documentos_aval_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."documentos_aval"
    ADD CONSTRAINT "documentos_aval_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."documentos_cliente"
    ADD CONSTRAINT "documentos_cliente_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."documentos_cliente"
    ADD CONSTRAINT "documentos_cliente_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."empleados"
    ADD CONSTRAINT "empleados_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."empleados_negocios"
    ADD CONSTRAINT "empleados_negocios_empleado_id_fkey" FOREIGN KEY ("empleado_id") REFERENCES "public"."empleados"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."empleados_negocios"
    ADD CONSTRAINT "empleados_negocios_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."empleados"
    ADD CONSTRAINT "empleados_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."empleados"
    ADD CONSTRAINT "empleados_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."entregas"
    ADD CONSTRAINT "entregas_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."entregas"
    ADD CONSTRAINT "entregas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."entregas"
    ADD CONSTRAINT "entregas_repartidor_id_fkey" FOREIGN KEY ("repartidor_id") REFERENCES "public"."empleados"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."envios_capital"
    ADD CONSTRAINT "envios_capital_confirmado_por_fkey" FOREIGN KEY ("confirmado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."envios_capital"
    ADD CONSTRAINT "envios_capital_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."envios_capital"
    ADD CONSTRAINT "envios_capital_empleado_id_fkey" FOREIGN KEY ("empleado_id") REFERENCES "public"."empleados"("id");



ALTER TABLE ONLY "public"."envios_capital"
    ADD CONSTRAINT "envios_capital_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expediente_clientes"
    ADD CONSTRAINT "expediente_clientes_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expediente_clientes"
    ADD CONSTRAINT "expediente_clientes_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."expedientes_legales"
    ADD CONSTRAINT "expedientes_legales_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expedientes_legales"
    ADD CONSTRAINT "expedientes_legales_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factura_complementos_pago"
    ADD CONSTRAINT "factura_complementos_pago_emisor_id_fkey" FOREIGN KEY ("emisor_id") REFERENCES "public"."facturacion_emisores"("id");



ALTER TABLE ONLY "public"."factura_complementos_pago"
    ADD CONSTRAINT "factura_complementos_pago_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factura_conceptos"
    ADD CONSTRAINT "factura_conceptos_factura_id_fkey" FOREIGN KEY ("factura_id") REFERENCES "public"."facturas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factura_documentos_relacionados"
    ADD CONSTRAINT "factura_documentos_relacionados_complemento_pago_id_fkey" FOREIGN KEY ("complemento_pago_id") REFERENCES "public"."factura_complementos_pago"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."factura_documentos_relacionados"
    ADD CONSTRAINT "factura_documentos_relacionados_factura_id_fkey" FOREIGN KEY ("factura_id") REFERENCES "public"."facturas"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."factura_impuestos"
    ADD CONSTRAINT "factura_impuestos_concepto_id_fkey" FOREIGN KEY ("concepto_id") REFERENCES "public"."factura_conceptos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."facturacion_clientes"
    ADD CONSTRAINT "facturacion_clientes_cliente_climas_id_fkey" FOREIGN KEY ("cliente_climas_id") REFERENCES "public"."climas_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."facturacion_clientes"
    ADD CONSTRAINT "facturacion_clientes_cliente_fintech_id_fkey" FOREIGN KEY ("cliente_fintech_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."facturacion_clientes"
    ADD CONSTRAINT "facturacion_clientes_cliente_nice_id_fkey" FOREIGN KEY ("cliente_nice_id") REFERENCES "public"."nice_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."facturacion_clientes"
    ADD CONSTRAINT "facturacion_clientes_cliente_purificadora_id_fkey" FOREIGN KEY ("cliente_purificadora_id") REFERENCES "public"."purificadora_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."facturacion_clientes"
    ADD CONSTRAINT "facturacion_clientes_cliente_ventas_id_fkey" FOREIGN KEY ("cliente_ventas_id") REFERENCES "public"."ventas_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."facturacion_clientes"
    ADD CONSTRAINT "facturacion_clientes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."facturacion_emisores"
    ADD CONSTRAINT "facturacion_emisores_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."facturacion_logs"
    ADD CONSTRAINT "facturacion_logs_factura_id_fkey" FOREIGN KEY ("factura_id") REFERENCES "public"."facturas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."facturacion_logs"
    ADD CONSTRAINT "facturacion_logs_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."facturacion_logs"
    ADD CONSTRAINT "facturacion_logs_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."facturacion_productos"
    ADD CONSTRAINT "facturacion_productos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."facturas"
    ADD CONSTRAINT "facturas_cliente_fiscal_id_fkey" FOREIGN KEY ("cliente_fiscal_id") REFERENCES "public"."facturacion_clientes"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."facturas"
    ADD CONSTRAINT "facturas_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."facturas"
    ADD CONSTRAINT "facturas_emisor_id_fkey" FOREIGN KEY ("emisor_id") REFERENCES "public"."facturacion_emisores"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."facturas"
    ADD CONSTRAINT "facturas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firmas_avales"
    ADD CONSTRAINT "firmas_avales_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."firmas_avales"
    ADD CONSTRAINT "firmas_avales_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."firmas_avales"
    ADD CONSTRAINT "firmas_avales_validada_por_fkey" FOREIGN KEY ("validada_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."notificaciones"
    ADD CONSTRAINT "fk_notificaciones_masiva" FOREIGN KEY ("notificacion_masiva_id") REFERENCES "public"."notificaciones_masivas"("id");



ALTER TABLE ONLY "public"."purificadora_pagos"
    ADD CONSTRAINT "fk_purificadora_pagos_negocio" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."fondos_pantalla"
    ADD CONSTRAINT "fondos_pantalla_subido_por_fkey" FOREIGN KEY ("subido_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."formularios_qr_config"
    ADD CONSTRAINT "formularios_qr_config_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."formularios_qr_config"
    ADD CONSTRAINT "formularios_qr_config_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."formularios_qr_config"
    ADD CONSTRAINT "formularios_qr_config_tarjeta_servicio_id_fkey" FOREIGN KEY ("tarjeta_servicio_id") REFERENCES "public"."tarjetas_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."formularios_qr_envios"
    ADD CONSTRAINT "formularios_qr_envios_asignado_a_fkey" FOREIGN KEY ("asignado_a") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."formularios_qr_envios"
    ADD CONSTRAINT "formularios_qr_envios_formulario_config_id_fkey" FOREIGN KEY ("formulario_config_id") REFERENCES "public"."formularios_qr_config"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."formularios_qr_envios"
    ADD CONSTRAINT "formularios_qr_envios_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."formularios_qr_envios"
    ADD CONSTRAINT "formularios_qr_envios_tarjeta_servicio_id_fkey" FOREIGN KEY ("tarjeta_servicio_id") REFERENCES "public"."tarjetas_servicio"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."intentos_cobro"
    ADD CONSTRAINT "intentos_cobro_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."intentos_cobro"
    ADD CONSTRAINT "intentos_cobro_cobrador_id_fkey" FOREIGN KEY ("cobrador_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."intentos_cobro"
    ADD CONSTRAINT "intentos_cobro_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventario_movimientos"
    ADD CONSTRAINT "inventario_movimientos_inventario_id_fkey" FOREIGN KEY ("inventario_id") REFERENCES "public"."inventario"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventario_movimientos"
    ADD CONSTRAINT "inventario_movimientos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."inventario"
    ADD CONSTRAINT "inventario_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."inventario"
    ADD CONSTRAINT "inventario_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."links_pago"
    ADD CONSTRAINT "links_pago_amortizacion_id_fkey" FOREIGN KEY ("amortizacion_id") REFERENCES "public"."amortizaciones"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."links_pago"
    ADD CONSTRAINT "links_pago_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."links_pago"
    ADD CONSTRAINT "links_pago_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."links_pago"
    ADD CONSTRAINT "links_pago_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."links_pago"
    ADD CONSTRAINT "links_pago_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."links_pago"
    ADD CONSTRAINT "links_pago_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."log_fraude"
    ADD CONSTRAINT "log_fraude_ejecutado_por_fkey" FOREIGN KEY ("ejecutado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."mensajes_aval_cobrador"
    ADD CONSTRAINT "mensajes_aval_cobrador_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "public"."chat_aval_cobrador"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mensajes_aval_cobrador"
    ADD CONSTRAINT "mensajes_aval_cobrador_emisor_id_fkey" FOREIGN KEY ("emisor_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."mensajes"
    ADD CONSTRAINT "mensajes_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "public"."chats"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mensajes"
    ADD CONSTRAINT "mensajes_emisor_id_fkey" FOREIGN KEY ("emisor_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."mis_propiedades"
    ADD CONSTRAINT "mis_propiedades_asignado_a_fkey" FOREIGN KEY ("asignado_a") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."modulos_activos"
    ADD CONSTRAINT "modulos_activos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moras_prestamos"
    ADD CONSTRAINT "moras_prestamos_amortizacion_id_fkey" FOREIGN KEY ("amortizacion_id") REFERENCES "public"."amortizaciones"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moras_prestamos"
    ADD CONSTRAINT "moras_prestamos_condonado_por_fkey" FOREIGN KEY ("condonado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."moras_prestamos"
    ADD CONSTRAINT "moras_prestamos_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moras_tandas"
    ADD CONSTRAINT "moras_tandas_condonado_por_fkey" FOREIGN KEY ("condonado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."moras_tandas"
    ADD CONSTRAINT "moras_tandas_participante_id_fkey" FOREIGN KEY ("participante_id") REFERENCES "public"."tanda_participantes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."moras_tandas"
    ADD CONSTRAINT "moras_tandas_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."movimientos_capital"
    ADD CONSTRAINT "movimientos_capital_activo_id_fkey" FOREIGN KEY ("activo_id") REFERENCES "public"."activos_capital"("id");



ALTER TABLE ONLY "public"."movimientos_capital"
    ADD CONSTRAINT "movimientos_capital_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."movimientos_capital"
    ADD CONSTRAINT "movimientos_capital_envio_id_fkey" FOREIGN KEY ("envio_id") REFERENCES "public"."envios_capital"("id");



ALTER TABLE ONLY "public"."movimientos_capital"
    ADD CONSTRAINT "movimientos_capital_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."negocios"
    ADD CONSTRAINT "negocios_propietario_id_fkey" FOREIGN KEY ("propietario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_catalogos"
    ADD CONSTRAINT "nice_catalogos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_categorias"
    ADD CONSTRAINT "nice_categorias_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_clientes"
    ADD CONSTRAINT "nice_clientes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_clientes"
    ADD CONSTRAINT "nice_clientes_vendedora_id_fkey" FOREIGN KEY ("vendedora_id") REFERENCES "public"."nice_vendedoras"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_comisiones"
    ADD CONSTRAINT "nice_comisiones_pedido_id_fkey" FOREIGN KEY ("pedido_id") REFERENCES "public"."nice_pedidos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_comisiones"
    ADD CONSTRAINT "nice_comisiones_vendedora_id_fkey" FOREIGN KEY ("vendedora_id") REFERENCES "public"."nice_vendedoras"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_inventario_movimientos"
    ADD CONSTRAINT "nice_inventario_movimientos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_inventario_movimientos"
    ADD CONSTRAINT "nice_inventario_movimientos_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."nice_productos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_inventario_movimientos"
    ADD CONSTRAINT "nice_inventario_movimientos_realizado_por_fkey" FOREIGN KEY ("realizado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."nice_inventario_movimientos"
    ADD CONSTRAINT "nice_inventario_movimientos_vendedora_id_fkey" FOREIGN KEY ("vendedora_id") REFERENCES "public"."nice_vendedoras"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_inventario_vendedora"
    ADD CONSTRAINT "nice_inventario_vendedora_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."nice_productos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_inventario_vendedora"
    ADD CONSTRAINT "nice_inventario_vendedora_vendedora_id_fkey" FOREIGN KEY ("vendedora_id") REFERENCES "public"."nice_vendedoras"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_niveles"
    ADD CONSTRAINT "nice_niveles_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_pagos"
    ADD CONSTRAINT "nice_pagos_pedido_id_fkey" FOREIGN KEY ("pedido_id") REFERENCES "public"."nice_pedidos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_pagos"
    ADD CONSTRAINT "nice_pagos_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."nice_pedido_items"
    ADD CONSTRAINT "nice_pedido_items_pedido_id_fkey" FOREIGN KEY ("pedido_id") REFERENCES "public"."nice_pedidos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_pedido_items"
    ADD CONSTRAINT "nice_pedido_items_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."nice_productos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_pedidos"
    ADD CONSTRAINT "nice_pedidos_catalogo_id_fkey" FOREIGN KEY ("catalogo_id") REFERENCES "public"."nice_catalogos"("id");



ALTER TABLE ONLY "public"."nice_pedidos"
    ADD CONSTRAINT "nice_pedidos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."nice_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_pedidos"
    ADD CONSTRAINT "nice_pedidos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_pedidos"
    ADD CONSTRAINT "nice_pedidos_vendedora_id_fkey" FOREIGN KEY ("vendedora_id") REFERENCES "public"."nice_vendedoras"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_productos"
    ADD CONSTRAINT "nice_productos_catalogo_id_fkey" FOREIGN KEY ("catalogo_id") REFERENCES "public"."nice_catalogos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_productos"
    ADD CONSTRAINT "nice_productos_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."nice_categorias"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_productos"
    ADD CONSTRAINT "nice_productos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_vendedoras"
    ADD CONSTRAINT "nice_vendedoras_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nice_vendedoras"
    ADD CONSTRAINT "nice_vendedoras_nivel_id_fkey" FOREIGN KEY ("nivel_id") REFERENCES "public"."nice_niveles"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_vendedoras"
    ADD CONSTRAINT "nice_vendedoras_patrocinadora_id_fkey" FOREIGN KEY ("patrocinadora_id") REFERENCES "public"."nice_vendedoras"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."nice_vendedoras"
    ADD CONSTRAINT "nice_vendedoras_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."notificaciones_documento_aval"
    ADD CONSTRAINT "notificaciones_documento_aval_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_documento_aval"
    ADD CONSTRAINT "notificaciones_documento_aval_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."notificaciones_documento_aval"
    ADD CONSTRAINT "notificaciones_documento_aval_documento_id_fkey" FOREIGN KEY ("documento_id") REFERENCES "public"."documentos_aval"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notificaciones_masivas"
    ADD CONSTRAINT "notificaciones_masivas_enviado_por_fkey" FOREIGN KEY ("enviado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."notificaciones_masivas"
    ADD CONSTRAINT "notificaciones_masivas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora_aval"
    ADD CONSTRAINT "notificaciones_mora_aval_amortizacion_id_fkey" FOREIGN KEY ("amortizacion_id") REFERENCES "public"."amortizaciones"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."notificaciones_mora_aval"
    ADD CONSTRAINT "notificaciones_mora_aval_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora_aval"
    ADD CONSTRAINT "notificaciones_mora_aval_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora_aval"
    ADD CONSTRAINT "notificaciones_mora_aval_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora_cliente"
    ADD CONSTRAINT "notificaciones_mora_cliente_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id");



ALTER TABLE ONLY "public"."notificaciones_mora_cliente"
    ADD CONSTRAINT "notificaciones_mora_cliente_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora"
    ADD CONSTRAINT "notificaciones_mora_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora_cliente"
    ADD CONSTRAINT "notificaciones_mora_cliente_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora_cliente"
    ADD CONSTRAINT "notificaciones_mora_cliente_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora_cliente"
    ADD CONSTRAINT "notificaciones_mora_cliente_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora"
    ADD CONSTRAINT "notificaciones_mora_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_mora"
    ADD CONSTRAINT "notificaciones_mora_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones"
    ADD CONSTRAINT "notificaciones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones_sistema"
    ADD CONSTRAINT "notificaciones_sistema_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."notificaciones"
    ADD CONSTRAINT "notificaciones_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_amortizacion_id_fkey" FOREIGN KEY ("amortizacion_id") REFERENCES "public"."amortizaciones"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pagos_comisiones"
    ADD CONSTRAINT "pagos_comisiones_comision_id_fkey" FOREIGN KEY ("comision_id") REFERENCES "public"."comisiones_empleados"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos_comisiones"
    ADD CONSTRAINT "pagos_comisiones_pagado_por_fkey" FOREIGN KEY ("pagado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos_propiedades"
    ADD CONSTRAINT "pagos_propiedades_pagado_por_fkey" FOREIGN KEY ("pagado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pagos_propiedades"
    ADD CONSTRAINT "pagos_propiedades_propiedad_id_fkey" FOREIGN KEY ("propiedad_id") REFERENCES "public"."mis_propiedades"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."pagos"
    ADD CONSTRAINT "pagos_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."preferencias_usuario"
    ADD CONSTRAINT "preferencias_usuario_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prestamos"
    ADD CONSTRAINT "prestamos_aprobado_por_fkey" FOREIGN KEY ("aprobado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."prestamos_avales"
    ADD CONSTRAINT "prestamos_avales_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prestamos_avales"
    ADD CONSTRAINT "prestamos_avales_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prestamos"
    ADD CONSTRAINT "prestamos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prestamos"
    ADD CONSTRAINT "prestamos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."prestamos"
    ADD CONSTRAINT "prestamos_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."promesas_pago"
    ADD CONSTRAINT "promesas_pago_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."promesas_pago"
    ADD CONSTRAINT "promesas_pago_intento_cobro_id_fkey" FOREIGN KEY ("intento_cobro_id") REFERENCES "public"."intentos_cobro"("id");



ALTER TABLE ONLY "public"."promesas_pago"
    ADD CONSTRAINT "promesas_pago_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."promociones"
    ADD CONSTRAINT "promociones_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."purificadora_cliente_contactos"
    ADD CONSTRAINT "purificadora_cliente_contactos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."purificadora_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_cliente_documentos"
    ADD CONSTRAINT "purificadora_cliente_documentos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."purificadora_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_cliente_notas"
    ADD CONSTRAINT "purificadora_cliente_notas_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."purificadora_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_cliente_notas"
    ADD CONSTRAINT "purificadora_cliente_notas_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."purificadora_clientes"
    ADD CONSTRAINT "purificadora_clientes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_clientes"
    ADD CONSTRAINT "purificadora_clientes_repartidor_id_fkey" FOREIGN KEY ("repartidor_id") REFERENCES "public"."purificadora_repartidores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."purificadora_cortes"
    ADD CONSTRAINT "purificadora_cortes_aprobado_por_fkey" FOREIGN KEY ("aprobado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."purificadora_cortes"
    ADD CONSTRAINT "purificadora_cortes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_cortes"
    ADD CONSTRAINT "purificadora_cortes_repartidor_id_fkey" FOREIGN KEY ("repartidor_id") REFERENCES "public"."purificadora_repartidores"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_cortes"
    ADD CONSTRAINT "purificadora_cortes_ruta_id_fkey" FOREIGN KEY ("ruta_id") REFERENCES "public"."purificadora_rutas"("id");



ALTER TABLE ONLY "public"."purificadora_entregas"
    ADD CONSTRAINT "purificadora_entregas_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."purificadora_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."purificadora_entregas"
    ADD CONSTRAINT "purificadora_entregas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_entregas"
    ADD CONSTRAINT "purificadora_entregas_repartidor_id_fkey" FOREIGN KEY ("repartidor_id") REFERENCES "public"."purificadora_repartidores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."purificadora_entregas"
    ADD CONSTRAINT "purificadora_entregas_ruta_id_fkey" FOREIGN KEY ("ruta_id") REFERENCES "public"."purificadora_rutas"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."purificadora_garrafones_historial"
    ADD CONSTRAINT "purificadora_garrafones_historial_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_garrafones_historial"
    ADD CONSTRAINT "purificadora_garrafones_historial_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."purificadora_gastos"
    ADD CONSTRAINT "purificadora_gastos_aprobado_por_fkey" FOREIGN KEY ("aprobado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."purificadora_gastos"
    ADD CONSTRAINT "purificadora_gastos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_gastos"
    ADD CONSTRAINT "purificadora_gastos_repartidor_id_fkey" FOREIGN KEY ("repartidor_id") REFERENCES "public"."purificadora_repartidores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."purificadora_gastos"
    ADD CONSTRAINT "purificadora_gastos_ruta_id_fkey" FOREIGN KEY ("ruta_id") REFERENCES "public"."purificadora_rutas"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."purificadora_inventario_garrafones"
    ADD CONSTRAINT "purificadora_inventario_garrafones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_inventario_garrafones"
    ADD CONSTRAINT "purificadora_inventario_garrafones_realizado_por_fkey" FOREIGN KEY ("realizado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."purificadora_pagos"
    ADD CONSTRAINT "purificadora_pagos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."purificadora_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."purificadora_pagos"
    ADD CONSTRAINT "purificadora_pagos_entrega_id_fkey" FOREIGN KEY ("entrega_id") REFERENCES "public"."purificadora_entregas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_pagos"
    ADD CONSTRAINT "purificadora_pagos_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."purificadora_precios"
    ADD CONSTRAINT "purificadora_precios_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_precios"
    ADD CONSTRAINT "purificadora_precios_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."purificadora_productos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_produccion"
    ADD CONSTRAINT "purificadora_produccion_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_produccion"
    ADD CONSTRAINT "purificadora_produccion_responsable_id_fkey" FOREIGN KEY ("responsable_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."purificadora_productos"
    ADD CONSTRAINT "purificadora_productos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_repartidores"
    ADD CONSTRAINT "purificadora_repartidores_empleado_id_fkey" FOREIGN KEY ("empleado_id") REFERENCES "public"."empleados"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."purificadora_repartidores"
    ADD CONSTRAINT "purificadora_repartidores_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_rutas"
    ADD CONSTRAINT "purificadora_rutas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."purificadora_rutas"
    ADD CONSTRAINT "purificadora_rutas_repartidor_id_fkey" FOREIGN KEY ("repartidor_id") REFERENCES "public"."purificadora_repartidores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."qr_cobros"
    ADD CONSTRAINT "qr_cobros_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_cobros"
    ADD CONSTRAINT "qr_cobros_cobrador_id_fkey" FOREIGN KEY ("cobrador_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."qr_cobros_config"
    ADD CONSTRAINT "qr_cobros_config_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_cobros_escaneos"
    ADD CONSTRAINT "qr_cobros_escaneos_escaneado_por_fkey" FOREIGN KEY ("escaneado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."qr_cobros_escaneos"
    ADD CONSTRAINT "qr_cobros_escaneos_qr_cobro_id_fkey" FOREIGN KEY ("qr_cobro_id") REFERENCES "public"."qr_cobros"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_cobros_estadisticas_diarias"
    ADD CONSTRAINT "qr_cobros_estadisticas_diarias_cobrador_top_id_fkey" FOREIGN KEY ("cobrador_top_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."qr_cobros_estadisticas_diarias"
    ADD CONSTRAINT "qr_cobros_estadisticas_diarias_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_cobros"
    ADD CONSTRAINT "qr_cobros_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_cobros"
    ADD CONSTRAINT "qr_cobros_pago_id_fkey" FOREIGN KEY ("pago_id") REFERENCES "public"."pagos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."qr_cobros_reportes"
    ADD CONSTRAINT "qr_cobros_reportes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_cobros_reportes"
    ADD CONSTRAINT "qr_cobros_reportes_qr_cobro_id_fkey" FOREIGN KEY ("qr_cobro_id") REFERENCES "public"."qr_cobros"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."qr_cobros_reportes"
    ADD CONSTRAINT "qr_cobros_reportes_reportado_por_fkey" FOREIGN KEY ("reportado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."qr_cobros_reportes"
    ADD CONSTRAINT "qr_cobros_reportes_resuelto_por_fkey" FOREIGN KEY ("resuelto_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."recordatorios"
    ADD CONSTRAINT "recordatorios_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."referencias_aval"
    ADD CONSTRAINT "referencias_aval_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."registros_cobro"
    ADD CONSTRAINT "registros_cobro_amortizacion_id_fkey" FOREIGN KEY ("amortizacion_id") REFERENCES "public"."amortizaciones"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."registros_cobro"
    ADD CONSTRAINT "registros_cobro_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."registros_cobro"
    ADD CONSTRAINT "registros_cobro_confirmado_por_fkey" FOREIGN KEY ("confirmado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."registros_cobro"
    ADD CONSTRAINT "registros_cobro_metodo_pago_id_fkey" FOREIGN KEY ("metodo_pago_id") REFERENCES "public"."metodos_pago"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."registros_cobro"
    ADD CONSTRAINT "registros_cobro_prestamo_id_fkey" FOREIGN KEY ("prestamo_id") REFERENCES "public"."prestamos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."registros_cobro"
    ADD CONSTRAINT "registros_cobro_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."registros_cobro"
    ADD CONSTRAINT "registros_cobro_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."roles_permisos"
    ADD CONSTRAINT "roles_permisos_permiso_id_fkey" FOREIGN KEY ("permiso_id") REFERENCES "public"."permisos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."roles_permisos"
    ADD CONSTRAINT "roles_permisos_rol_id_fkey" FOREIGN KEY ("rol_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."seguimiento_judicial"
    ADD CONSTRAINT "seguimiento_judicial_expediente_id_fkey" FOREIGN KEY ("expediente_id") REFERENCES "public"."expedientes_legales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stripe_config"
    ADD CONSTRAINT "stripe_config_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stripe_transactions_log"
    ADD CONSTRAINT "stripe_transactions_log_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."stripe_transactions_log"
    ADD CONSTRAINT "stripe_transactions_log_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stripe_transactions_log"
    ADD CONSTRAINT "stripe_transactions_log_pago_id_fkey" FOREIGN KEY ("pago_id") REFERENCES "public"."pagos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."sucursales"
    ADD CONSTRAINT "sucursales_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tanda_pagos"
    ADD CONSTRAINT "tanda_pagos_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."tanda_pagos"
    ADD CONSTRAINT "tanda_pagos_tanda_participante_id_fkey" FOREIGN KEY ("tanda_participante_id") REFERENCES "public"."tanda_participantes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tanda_participantes"
    ADD CONSTRAINT "tanda_participantes_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tanda_participantes"
    ADD CONSTRAINT "tanda_participantes_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tandas_avales"
    ADD CONSTRAINT "tandas_avales_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tandas_avales"
    ADD CONSTRAINT "tandas_avales_tanda_id_fkey" FOREIGN KEY ("tanda_id") REFERENCES "public"."tandas"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tandas"
    ADD CONSTRAINT "tandas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tandas"
    ADD CONSTRAINT "tandas_organizador_id_fkey" FOREIGN KEY ("organizador_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tandas"
    ADD CONSTRAINT "tandas_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_alertas"
    ADD CONSTRAINT "tarjetas_alertas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_alertas"
    ADD CONSTRAINT "tarjetas_alertas_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_virtuales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_alertas"
    ADD CONSTRAINT "tarjetas_alertas_titular_id_fkey" FOREIGN KEY ("titular_id") REFERENCES "public"."tarjetas_titulares"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_alertas"
    ADD CONSTRAINT "tarjetas_alertas_transaccion_id_fkey" FOREIGN KEY ("transaccion_id") REFERENCES "public"."tarjetas_transacciones"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_config"
    ADD CONSTRAINT "tarjetas_config_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_config"
    ADD CONSTRAINT "tarjetas_config_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."tarjetas_digitales"
    ADD CONSTRAINT "tarjetas_digitales_bloqueada_por_fkey" FOREIGN KEY ("bloqueada_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."tarjetas_digitales"
    ADD CONSTRAINT "tarjetas_digitales_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_digitales"
    ADD CONSTRAINT "tarjetas_digitales_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_digitales_recargas"
    ADD CONSTRAINT "tarjetas_digitales_recargas_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_digitales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_digitales_recargas"
    ADD CONSTRAINT "tarjetas_digitales_recargas_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."tarjetas_digitales_transacciones"
    ADD CONSTRAINT "tarjetas_digitales_transacciones_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_digitales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_landing_config"
    ADD CONSTRAINT "tarjetas_landing_config_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_log"
    ADD CONSTRAINT "tarjetas_log_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id");



ALTER TABLE ONLY "public"."tarjetas_log"
    ADD CONSTRAINT "tarjetas_log_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_virtuales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_log"
    ADD CONSTRAINT "tarjetas_log_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."tarjetas_recargas"
    ADD CONSTRAINT "tarjetas_recargas_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_recargas"
    ADD CONSTRAINT "tarjetas_recargas_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_virtuales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_recargas"
    ADD CONSTRAINT "tarjetas_recargas_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."tarjetas_servicio"
    ADD CONSTRAINT "tarjetas_servicio_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."tarjetas_servicio_escaneos"
    ADD CONSTRAINT "tarjetas_servicio_escaneos_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_servicio_exportaciones"
    ADD CONSTRAINT "tarjetas_servicio_exportaciones_exportado_por_fkey" FOREIGN KEY ("exportado_por") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."tarjetas_servicio_exportaciones"
    ADD CONSTRAINT "tarjetas_servicio_exportaciones_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_servicio"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_servicio"
    ADD CONSTRAINT "tarjetas_servicio_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_solicitudes"
    ADD CONSTRAINT "tarjetas_solicitudes_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_solicitudes"
    ADD CONSTRAINT "tarjetas_solicitudes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_solicitudes"
    ADD CONSTRAINT "tarjetas_solicitudes_revisado_por_fkey" FOREIGN KEY ("revisado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."tarjetas_solicitudes"
    ADD CONSTRAINT "tarjetas_solicitudes_solicitante_id_fkey" FOREIGN KEY ("solicitante_id") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."tarjetas_solicitudes"
    ADD CONSTRAINT "tarjetas_solicitudes_tarjeta_emitida_id_fkey" FOREIGN KEY ("tarjeta_emitida_id") REFERENCES "public"."tarjetas_digitales"("id");



ALTER TABLE ONLY "public"."tarjetas_titulares"
    ADD CONSTRAINT "tarjetas_titulares_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id");



ALTER TABLE ONLY "public"."tarjetas_titulares"
    ADD CONSTRAINT "tarjetas_titulares_empleado_id_fkey" FOREIGN KEY ("empleado_id") REFERENCES "public"."empleados"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_titulares"
    ADD CONSTRAINT "tarjetas_titulares_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id");



ALTER TABLE ONLY "public"."tarjetas_titulares"
    ADD CONSTRAINT "tarjetas_titulares_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_virtuales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_titulares"
    ADD CONSTRAINT "tarjetas_titulares_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_transacciones"
    ADD CONSTRAINT "tarjetas_transacciones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_transacciones"
    ADD CONSTRAINT "tarjetas_transacciones_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_virtuales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_virtuales"
    ADD CONSTRAINT "tarjetas_virtuales_bloqueado_por_fkey" FOREIGN KEY ("bloqueado_por") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."tarjetas_virtuales"
    ADD CONSTRAINT "tarjetas_virtuales_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_virtuales"
    ADD CONSTRAINT "tarjetas_virtuales_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tarjetas_virtuales"
    ADD CONSTRAINT "tarjetas_virtuales_titular_id_fkey" FOREIGN KEY ("titular_id") REFERENCES "public"."tarjetas_titulares"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."temas_app"
    ADD CONSTRAINT "temas_app_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."transacciones_tarjeta"
    ADD CONSTRAINT "transacciones_tarjeta_tarjeta_id_fkey" FOREIGN KEY ("tarjeta_id") REFERENCES "public"."tarjetas_digitales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."usuarios_negocios"
    ADD CONSTRAINT "usuarios_negocios_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."usuarios_negocios"
    ADD CONSTRAINT "usuarios_negocios_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."usuarios_roles"
    ADD CONSTRAINT "usuarios_roles_rol_id_fkey" FOREIGN KEY ("rol_id") REFERENCES "public"."roles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."usuarios_roles"
    ADD CONSTRAINT "usuarios_roles_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."usuarios_sucursales"
    ADD CONSTRAINT "usuarios_sucursales_sucursal_id_fkey" FOREIGN KEY ("sucursal_id") REFERENCES "public"."sucursales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."usuarios_sucursales"
    ADD CONSTRAINT "usuarios_sucursales_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."validaciones_aval"
    ADD CONSTRAINT "validaciones_aval_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."validaciones_aval"
    ADD CONSTRAINT "validaciones_aval_revisado_por_fkey" FOREIGN KEY ("revisado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."ventas_categorias"
    ADD CONSTRAINT "ventas_categorias_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_cliente_contactos"
    ADD CONSTRAINT "ventas_cliente_contactos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."ventas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_cliente_creditos"
    ADD CONSTRAINT "ventas_cliente_creditos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."ventas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_cliente_documentos"
    ADD CONSTRAINT "ventas_cliente_documentos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."ventas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_cliente_notas"
    ADD CONSTRAINT "ventas_cliente_notas_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."ventas_clientes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_cliente_notas"
    ADD CONSTRAINT "ventas_cliente_notas_creado_por_fkey" FOREIGN KEY ("creado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."ventas_clientes"
    ADD CONSTRAINT "ventas_clientes_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_clientes"
    ADD CONSTRAINT "ventas_clientes_vendedor_id_fkey" FOREIGN KEY ("vendedor_id") REFERENCES "public"."ventas_vendedores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ventas_cotizaciones"
    ADD CONSTRAINT "ventas_cotizaciones_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."ventas_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ventas_cotizaciones"
    ADD CONSTRAINT "ventas_cotizaciones_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_cotizaciones"
    ADD CONSTRAINT "ventas_cotizaciones_vendedor_id_fkey" FOREIGN KEY ("vendedor_id") REFERENCES "public"."ventas_vendedores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ventas_pagos"
    ADD CONSTRAINT "ventas_pagos_pedido_id_fkey" FOREIGN KEY ("pedido_id") REFERENCES "public"."ventas_pedidos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_pagos"
    ADD CONSTRAINT "ventas_pagos_registrado_por_fkey" FOREIGN KEY ("registrado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE ONLY "public"."ventas_pedidos"
    ADD CONSTRAINT "ventas_pedidos_cliente_id_fkey" FOREIGN KEY ("cliente_id") REFERENCES "public"."ventas_clientes"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ventas_pedidos_detalle"
    ADD CONSTRAINT "ventas_pedidos_detalle_pedido_id_fkey" FOREIGN KEY ("pedido_id") REFERENCES "public"."ventas_pedidos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_pedidos_detalle"
    ADD CONSTRAINT "ventas_pedidos_detalle_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."ventas_productos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ventas_pedidos_items"
    ADD CONSTRAINT "ventas_pedidos_items_pedido_id_fkey" FOREIGN KEY ("pedido_id") REFERENCES "public"."ventas_pedidos"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_pedidos_items"
    ADD CONSTRAINT "ventas_pedidos_items_producto_id_fkey" FOREIGN KEY ("producto_id") REFERENCES "public"."ventas_productos"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ventas_pedidos"
    ADD CONSTRAINT "ventas_pedidos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_pedidos"
    ADD CONSTRAINT "ventas_pedidos_vendedor_id_fkey" FOREIGN KEY ("vendedor_id") REFERENCES "public"."ventas_vendedores"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ventas_productos"
    ADD CONSTRAINT "ventas_productos_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "public"."ventas_categorias"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."ventas_productos"
    ADD CONSTRAINT "ventas_productos_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_vendedores"
    ADD CONSTRAINT "ventas_vendedores_negocio_id_fkey" FOREIGN KEY ("negocio_id") REFERENCES "public"."negocios"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."ventas_vendedores"
    ADD CONSTRAINT "ventas_vendedores_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "public"."usuarios"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."verificaciones_identidad"
    ADD CONSTRAINT "verificaciones_identidad_aval_id_fkey" FOREIGN KEY ("aval_id") REFERENCES "public"."avales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."verificaciones_identidad"
    ADD CONSTRAINT "verificaciones_identidad_verificado_por_fkey" FOREIGN KEY ("verificado_por") REFERENCES "public"."usuarios"("id");



ALTER TABLE "public"."activity_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activity_log_admin" ON "public"."activity_log" USING ("public"."es_admin_o_superior"());



ALTER TABLE "public"."activos_capital" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activos_capital_access" ON "public"."activos_capital" USING ((("negocio_id" IN ( SELECT "empleados"."negocio_id"
   FROM "public"."empleados"
  WHERE ("empleados"."usuario_id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"])))))));



CREATE POLICY "activos_capital_delete" ON "public"."activos_capital" FOR DELETE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "activos_capital_insert" ON "public"."activos_capital" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "activos_capital_select" ON "public"."activos_capital" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "activos_capital_update" ON "public"."activos_capital" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."acuses_recibo" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "acuses_recibo_access" ON "public"."acuses_recibo" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."aires_ordenes_servicio" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."alertas_sistema" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."amortizaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "amortizaciones_authenticated" ON "public"."amortizaciones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."aportaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "aportaciones_authenticated" ON "public"."aportaciones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."auditoria" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."auditoria_acceso" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "auditoria_acceso_admin_only" ON "public"."auditoria_acceso" FOR SELECT USING ("public"."es_admin_o_superior"());



CREATE POLICY "auditoria_acceso_insert_all" ON "public"."auditoria_acceso" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "auditoria_admin_insert" ON "public"."auditoria" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "auditoria_admin_only" ON "public"."auditoria" FOR SELECT USING ("public"."es_admin_o_superior"());



CREATE POLICY "auditoria_insert_all" ON "public"."auditoria" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."auditoria_legal" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."aval_checkins" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "aval_checkins_insert" ON "public"."aval_checkins" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."avales"
  WHERE (("avales"."id" = "aval_checkins"."aval_id") AND ("avales"."usuario_id" = "auth"."uid"()) AND ("avales"."ubicacion_consentida" = true)))));



CREATE POLICY "aval_checkins_policy" ON "public"."aval_checkins" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "aval_checkins_select" ON "public"."aval_checkins" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."avales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "avales_authenticated" ON "public"."avales" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."cache_estadisticas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "cache_estadisticas_access" ON "public"."cache_estadisticas" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "cache_estadisticas_auth" ON "public"."cache_estadisticas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."calendario" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "calendario_access" ON "public"."calendario" USING ((("usuario_id" = "auth"."uid"()) OR "public"."es_admin_o_superior"()));



CREATE POLICY "campos_catalogo_select" ON "public"."campos_formulario_catalogo" FOR SELECT USING (("activo" = true));



ALTER TABLE "public"."campos_formulario_catalogo" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."chat_aval_cobrador" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "chat_aval_cobrador_insert" ON "public"."chat_aval_cobrador" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "chat_aval_cobrador_select" ON "public"."chat_aval_cobrador" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND ((EXISTS ( SELECT 1
   FROM "public"."avales"
  WHERE (("avales"."id" = "chat_aval_cobrador"."aval_id") AND ("avales"."usuario_id" = "auth"."uid"())))) OR ("admin_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))))));



CREATE POLICY "chat_aval_cobrador_update" ON "public"."chat_aval_cobrador" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."chat_conversaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "chat_conversaciones_access" ON "public"."chat_conversaciones" USING ((("creado_por_usuario_id" = "auth"."uid"()) OR "public"."es_admin_o_superior"() OR (EXISTS ( SELECT 1
   FROM "public"."chat_participantes"
  WHERE (("chat_participantes"."conversacion_id" = "chat_conversaciones"."id") AND ("chat_participantes"."usuario_id" = "auth"."uid"()))))));



ALTER TABLE "public"."chat_mensajes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "chat_mensajes_access" ON "public"."chat_mensajes" USING ((EXISTS ( SELECT 1
   FROM "public"."chat_conversaciones" "c"
  WHERE (("c"."id" = "chat_mensajes"."conversacion_id") AND (("c"."creado_por_usuario_id" = "auth"."uid"()) OR "public"."es_admin_o_superior"() OR (EXISTS ( SELECT 1
           FROM "public"."chat_participantes"
          WHERE (("chat_participantes"."conversacion_id" = "c"."id") AND ("chat_participantes"."usuario_id" = "auth"."uid"())))))))));



ALTER TABLE "public"."chat_participantes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."chats" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "chats_privacidad" ON "public"."chats" USING ((("auth"."uid"() = "usuario1") OR ("auth"."uid"() = "usuario2")));



ALTER TABLE "public"."clientes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "clientes_bloqueados_auth" ON "public"."clientes_bloqueados_mora" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."clientes_bloqueados_mora" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "clientes_delete_scoped" ON "public"."clientes" FOR DELETE USING (("public"."es_admin_o_superior"() OR ("usuario_id" = "auth"."uid"()) OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



CREATE POLICY "clientes_insert_scoped" ON "public"."clientes" FOR INSERT WITH CHECK (("public"."es_admin_o_superior"() OR ("usuario_id" = "auth"."uid"()) OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



ALTER TABLE "public"."clientes_modulo" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "clientes_modulo_access" ON "public"."clientes_modulo" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "clientes_select_scoped" ON "public"."clientes" FOR SELECT USING (("public"."es_admin_o_superior"() OR ("usuario_id" = "auth"."uid"()) OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



CREATE POLICY "clientes_update_scoped" ON "public"."clientes" FOR UPDATE USING (("public"."es_admin_o_superior"() OR ("usuario_id" = "auth"."uid"()) OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



ALTER TABLE "public"."climas_calendario" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_calendario_access" ON "public"."climas_calendario" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_catalogo_manage_auth" ON "public"."climas_catalogo_servicios_publico" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_catalogo_select_public" ON "public"."climas_catalogo_servicios_publico" FOR SELECT USING (("activo" = true));



ALTER TABLE "public"."climas_catalogo_servicios_publico" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_cert_tecnico_access" ON "public"."climas_certificaciones_tecnico" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_certificaciones_tecnico" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_chat_insert_public" ON "public"."climas_chat_solicitud" FOR INSERT WITH CHECK (true);



CREATE POLICY "climas_chat_select_auth" ON "public"."climas_chat_solicitud" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_chat_solicitud" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_checklist_access" ON "public"."climas_checklist_servicio" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_checklist_resp_access" ON "public"."climas_checklist_respuestas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_checklist_respuestas" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_checklist_servicio" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_cliente_contactos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_cliente_contactos_auth" ON "public"."climas_cliente_contactos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_cliente_documentos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_cliente_documentos_auth" ON "public"."climas_cliente_documentos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_cliente_notas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_cliente_notas_auth" ON "public"."climas_cliente_notas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_clientes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_clientes_admin_all" ON "public"."climas_clientes" USING ((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'admin_climas'::"text"]))))));



CREATE POLICY "climas_clientes_cliente_select" ON "public"."climas_clientes" FOR SELECT USING ((("auth_uid" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'admin_climas'::"text", 'tecnico_climas'::"text"])))))));



ALTER TABLE "public"."climas_comisiones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_comisiones_access" ON "public"."climas_comisiones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_comprobantes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_comprobantes_access" ON "public"."climas_comprobantes" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_config_access" ON "public"."climas_configuracion" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_config_form_auth" ON "public"."climas_config_formulario_qr" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_config_form_select_public" ON "public"."climas_config_formulario_qr" FOR SELECT USING (true);



ALTER TABLE "public"."climas_config_formulario_qr" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_configuracion" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_cotizaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_cotizaciones_auth" ON "public"."climas_cotizaciones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_cotizaciones_v2" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_cotizaciones_v2_access" ON "public"."climas_cotizaciones_v2" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_equipos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_equipos_admin_all" ON "public"."climas_equipos" USING ((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'admin_climas'::"text", 'tecnico_climas'::"text"]))))));



ALTER TABLE "public"."climas_equipos_cliente" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_equipos_cliente_access" ON "public"."climas_equipos_cliente" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_equipos_cliente_select" ON "public"."climas_equipos" FOR SELECT USING ((("cliente_id" IN ( SELECT "climas_clientes"."id"
   FROM "public"."climas_clientes"
  WHERE ("climas_clientes"."auth_uid" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'admin_climas'::"text", 'tecnico_climas'::"text"])))))));



ALTER TABLE "public"."climas_garantias" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_garantias_access" ON "public"."climas_garantias" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_historial_auth" ON "public"."climas_solicitud_historial" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_incidencias" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_incidencias_access" ON "public"."climas_incidencias" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_inv_tecnico_access" ON "public"."climas_inventario_tecnico" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_inventario_tecnico" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_mensajes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_mensajes_access" ON "public"."climas_mensajes" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_metricas_access" ON "public"."climas_metricas_tecnico" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_metricas_tecnico" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_mov_inv_access" ON "public"."climas_movimientos_inventario" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_movimientos_inventario" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_ordenes_admin_all" ON "public"."climas_ordenes_servicio" USING ((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'admin_climas'::"text", 'tecnico_climas'::"text"]))))));



CREATE POLICY "climas_ordenes_cliente_select" ON "public"."climas_ordenes_servicio" FOR SELECT USING ((("cliente_id" IN ( SELECT "climas_clientes"."id"
   FROM "public"."climas_clientes"
  WHERE ("climas_clientes"."auth_uid" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'admin_climas'::"text", 'tecnico_climas'::"text"])))))));



ALTER TABLE "public"."climas_ordenes_servicio" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_pagos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_pagos_access" ON "public"."climas_pagos" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_precios_access" ON "public"."climas_precios_servicio" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_precios_servicio" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_productos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_productos_access" ON "public"."climas_productos" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_productos_auth" ON "public"."climas_productos" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_recordatorios_access" ON "public"."climas_recordatorios_mantenimiento" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_recordatorios_mantenimiento" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_registro_tiempo" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_registro_tiempo_access" ON "public"."climas_registro_tiempo" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_sol_qr_insert_public" ON "public"."climas_solicitudes_qr" FOR INSERT WITH CHECK (true);



CREATE POLICY "climas_sol_qr_select_auth" ON "public"."climas_solicitudes_qr" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_sol_qr_update_auth" ON "public"."climas_solicitudes_qr" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "climas_sol_refacciones_access" ON "public"."climas_solicitudes_refacciones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_solicitud_historial" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_solicitudes_access" ON "public"."climas_solicitudes_cliente" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_solicitudes_cliente" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_solicitudes_qr" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_solicitudes_refacciones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."climas_tecnico_zonas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_tecnico_zonas_access" ON "public"."climas_tecnico_zonas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_tecnicos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_tecnicos_access" ON "public"."climas_tecnicos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."climas_zonas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "climas_zonas_access" ON "public"."climas_zonas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaborador_actividad" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaborador_actividad_access" ON "public"."colaborador_actividad" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaborador_compensaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaborador_compensaciones_access" ON "public"."colaborador_compensaciones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaborador_inversiones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaborador_inversiones_access_v10" ON "public"."colaborador_inversiones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaborador_invitaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaborador_invitaciones_access" ON "public"."colaborador_invitaciones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaborador_pagos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaborador_pagos_access" ON "public"."colaborador_pagos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaborador_permisos_modulo" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaborador_permisos_modulo_auth" ON "public"."colaborador_permisos_modulo" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaborador_rendimientos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaborador_rendimientos_auth" ON "public"."colaborador_rendimientos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaborador_tipos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaborador_tipos_access" ON "public"."colaborador_tipos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."colaboradores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "colaboradores_access" ON "public"."colaboradores" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."comisiones_empleados" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."compensacion_tipos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "compensacion_tipos_access" ON "public"."compensacion_tipos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."comprobantes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "comprobantes_auth" ON "public"."comprobantes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."comprobantes_prestamo" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "config_moras_auth" ON "public"."configuracion_moras" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."configuracion" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."configuracion_apis" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."configuracion_global" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "configuracion_global_modify" ON "public"."configuracion_global" USING ("public"."usuario_tiene_rol"('superadmin'::"text"));



CREATE POLICY "configuracion_global_select" ON "public"."configuracion_global" FOR SELECT USING (true);



CREATE POLICY "configuracion_modify_superadmin" ON "public"."configuracion" USING ("public"."usuario_tiene_rol"('superadmin'::"text"));



ALTER TABLE "public"."configuracion_moras" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "configuracion_select_all" ON "public"."configuracion" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."contratos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "contratos_access" ON "public"."contratos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."documentos_aval" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "documentos_aval_select" ON "public"."documentos_aval" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND ((EXISTS ( SELECT 1
   FROM "public"."avales"
  WHERE (("avales"."id" = "documentos_aval"."aval_id") AND ("avales"."usuario_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'operador'::"text"]))))))));



ALTER TABLE "public"."documentos_cliente" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "documentos_cliente_access" ON "public"."documentos_cliente" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."empleados" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "empleados_all_authenticated" ON "public"."empleados" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."empleados_negocios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "empleados_negocios_access" ON "public"."empleados_negocios" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."entregas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "entregas_auth" ON "public"."entregas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."envios_capital" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "envios_capital_access" ON "public"."envios_capital" USING ((("negocio_id" IN ( SELECT "empleados"."negocio_id"
   FROM "public"."empleados"
  WHERE ("empleados"."usuario_id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"])))))));



CREATE POLICY "envios_capital_delete" ON "public"."envios_capital" FOR DELETE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "envios_capital_insert" ON "public"."envios_capital" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "envios_capital_select" ON "public"."envios_capital" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "envios_capital_update" ON "public"."envios_capital" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "envios_insert_public" ON "public"."formularios_qr_envios" FOR INSERT WITH CHECK (true);



CREATE POLICY "envios_select" ON "public"."formularios_qr_envios" FOR SELECT USING ((("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE ("usuarios_negocios"."usuario_id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text"))))));



CREATE POLICY "envios_update" ON "public"."formularios_qr_envios" FOR UPDATE USING ((("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE ("usuarios_negocios"."usuario_id" = "auth"."uid"()))) OR ("asignado_a" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text"))))));



CREATE POLICY "escaneos_insert_public" ON "public"."tarjetas_servicio_escaneos" FOR INSERT WITH CHECK (true);



CREATE POLICY "escaneos_select" ON "public"."tarjetas_servicio_escaneos" FOR SELECT USING ((("tarjeta_id" IN ( SELECT "tarjetas_servicio"."id"
   FROM "public"."tarjetas_servicio"
  WHERE (("tarjetas_servicio"."created_by" = "auth"."uid"()) OR ("tarjetas_servicio"."negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
           FROM "public"."usuarios_negocios"
          WHERE ("usuarios_negocios"."usuario_id" = "auth"."uid"())))))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text"))))));



CREATE POLICY "expediente_authenticated" ON "public"."expediente_clientes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."expediente_clientes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expedientes_legales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "exportaciones_all" ON "public"."tarjetas_servicio_exportaciones" USING ((("exportado_por" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text"))))));



ALTER TABLE "public"."factura_complementos_pago" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "factura_complementos_pago_access" ON "public"."factura_complementos_pago" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "factura_complementos_pago_auth" ON "public"."factura_complementos_pago" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."factura_conceptos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "factura_conceptos_auth" ON "public"."factura_conceptos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."factura_documentos_relacionados" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "factura_documentos_relacionados_access" ON "public"."factura_documentos_relacionados" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "factura_documentos_relacionados_auth" ON "public"."factura_documentos_relacionados" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."factura_impuestos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "factura_impuestos_access" ON "public"."factura_impuestos" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "factura_impuestos_auth" ON "public"."factura_impuestos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."facturacion_clientes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "facturacion_clientes_auth" ON "public"."facturacion_clientes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."facturacion_emisores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "facturacion_emisores_auth" ON "public"."facturacion_emisores" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."facturacion_logs" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "facturacion_logs_access" ON "public"."facturacion_logs" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "facturacion_logs_auth" ON "public"."facturacion_logs" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."facturacion_productos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "facturacion_productos_access" ON "public"."facturacion_productos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."facturas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "facturas_auth" ON "public"."facturas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."firmas_avales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "firmas_avales_insert" ON "public"."firmas_avales" FOR INSERT WITH CHECK ((("auth"."role"() = 'authenticated'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."avales"
  WHERE (("avales"."id" = "firmas_avales"."aval_id") AND ("avales"."usuario_id" = "auth"."uid"()))))));



CREATE POLICY "firmas_avales_select" ON "public"."firmas_avales" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND ((EXISTS ( SELECT 1
   FROM "public"."avales"
  WHERE (("avales"."id" = "firmas_avales"."aval_id") AND ("avales"."usuario_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'operador'::"text"]))))))));



ALTER TABLE "public"."firmas_digitales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "firmas_digitales_access" ON "public"."firmas_digitales" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."fondos_pantalla" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "fondos_pantalla_modify" ON "public"."fondos_pantalla" USING ("public"."usuario_tiene_rol"('superadmin'::"text"));



CREATE POLICY "fondos_pantalla_select" ON "public"."fondos_pantalla" FOR SELECT USING (true);



CREATE POLICY "formularios_config_manage" ON "public"."formularios_qr_config" USING ((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))));



CREATE POLICY "formularios_config_select" ON "public"."formularios_qr_config" FOR SELECT USING ((("activo" = true) OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE ("usuarios_negocios"."usuario_id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text"))))));



ALTER TABLE "public"."formularios_qr_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."formularios_qr_envios" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."intentos_cobro" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."inventario" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "inventario_auth" ON "public"."inventario" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."inventario_movimientos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "inventario_movimientos_auth" ON "public"."inventario_movimientos" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "landing_config_manage" ON "public"."tarjetas_landing_config" USING ((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))));



CREATE POLICY "landing_config_select" ON "public"."tarjetas_landing_config" FOR SELECT USING ((("activa" = true) OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE ("usuarios_negocios"."usuario_id" = "auth"."uid"()))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text"))))));



ALTER TABLE "public"."links_pago" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "links_pago_access" ON "public"."links_pago" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."mensajes" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."mensajes_aval_cobrador" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "mensajes_aval_cobrador_insert" ON "public"."mensajes_aval_cobrador" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "mensajes_aval_cobrador_select" ON "public"."mensajes_aval_cobrador" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND (EXISTS ( SELECT 1
   FROM "public"."chat_aval_cobrador" "c"
  WHERE (("c"."id" = "mensajes_aval_cobrador"."chat_id") AND ((EXISTS ( SELECT 1
           FROM "public"."avales"
          WHERE (("avales"."id" = "c"."aval_id") AND ("avales"."usuario_id" = "auth"."uid"())))) OR ("c"."admin_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
           FROM ("public"."usuarios_roles" "ur"
             JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
          WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"])))))))))));



CREATE POLICY "mensajes_privacidad" ON "public"."mensajes" USING ((EXISTS ( SELECT 1
   FROM "public"."chats"
  WHERE (("chats"."id" = "mensajes"."chat_id") AND (("chats"."usuario1" = "auth"."uid"()) OR ("chats"."usuario2" = "auth"."uid"()))))));



ALTER TABLE "public"."metodos_pago" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "metodos_pago_modify" ON "public"."metodos_pago" USING ("public"."es_admin_o_superior"());



CREATE POLICY "metodos_pago_select" ON "public"."metodos_pago" FOR SELECT USING (true);



ALTER TABLE "public"."mis_propiedades" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."modulos_activos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."moras_prestamos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "moras_prestamos_auth" ON "public"."moras_prestamos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."moras_tandas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "moras_tandas_auth" ON "public"."moras_tandas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."movimientos_capital" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "movimientos_capital_insert" ON "public"."movimientos_capital" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "movimientos_capital_select" ON "public"."movimientos_capital" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."negocios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "negocios_modify" ON "public"."negocios" USING ((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))));



CREATE POLICY "negocios_select" ON "public"."negocios" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_catalogos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_catalogos_access" ON "public"."nice_catalogos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_categorias" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_categorias_access" ON "public"."nice_categorias" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_clientes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_clientes_access" ON "public"."nice_clientes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_comisiones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_comisiones_access" ON "public"."nice_comisiones" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "nice_inventario_access" ON "public"."nice_inventario_vendedora" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_inventario_movimientos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_inventario_movimientos_access" ON "public"."nice_inventario_movimientos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_inventario_vendedora" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_inventario_vendedora_access" ON "public"."nice_inventario_vendedora" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_niveles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_niveles_access" ON "public"."nice_niveles" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_pagos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_pagos_access" ON "public"."nice_pagos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_pedido_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_pedido_items_access" ON "public"."nice_pedido_items" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_pedidos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_pedidos_access" ON "public"."nice_pedidos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_productos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_productos_access" ON "public"."nice_productos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."nice_vendedoras" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "nice_vendedoras_access" ON "public"."nice_vendedoras" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "notif_doc_aval_policy" ON "public"."notificaciones_documento_aval" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "notif_mora_aval_insert" ON "public"."notificaciones_mora_aval" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "notif_mora_aval_select" ON "public"."notificaciones_mora_aval" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND ((EXISTS ( SELECT 1
   FROM "public"."avales"
  WHERE (("avales"."id" = "notificaciones_mora_aval"."aval_id") AND ("avales"."usuario_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text", 'operador'::"text"]))))))));



CREATE POLICY "notif_mora_aval_update" ON "public"."notificaciones_mora_aval" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "notif_mora_cliente_auth" ON "public"."notificaciones_mora_cliente" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."notificaciones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notificaciones_documento_aval" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notificaciones_insert" ON "public"."notificaciones" FOR INSERT WITH CHECK (true);



ALTER TABLE "public"."notificaciones_masivas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notificaciones_masivas_access" ON "public"."notificaciones_masivas" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "notificaciones_masivas_insert" ON "public"."notificaciones_masivas" FOR INSERT WITH CHECK ("public"."es_admin_o_superior"());



CREATE POLICY "notificaciones_masivas_select" ON "public"."notificaciones_masivas" FOR SELECT USING ("public"."es_admin_o_superior"());



ALTER TABLE "public"."notificaciones_mora" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notificaciones_mora_aval" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notificaciones_mora_cliente" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notificaciones_mora_cliente_access" ON "public"."notificaciones_mora_cliente" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "notificaciones_propias" ON "public"."notificaciones" FOR SELECT USING (("usuario_id" = "auth"."uid"()));



ALTER TABLE "public"."notificaciones_sistema" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "notificaciones_sistema_access" ON "public"."notificaciones_sistema" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "notificaciones_update" ON "public"."notificaciones" FOR UPDATE USING (("usuario_id" = "auth"."uid"()));



ALTER TABLE "public"."pagos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pagos_authenticated" ON "public"."pagos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."pagos_comisiones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."pagos_propiedades" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "pagos_propiedades_authenticated" ON "public"."pagos_propiedades" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."permisos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "permisos_select_public" ON "public"."permisos" FOR SELECT USING (true);



ALTER TABLE "public"."preferencias_usuario" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "preferencias_usuario_own" ON "public"."preferencias_usuario" USING (("auth"."uid"() = "usuario_id"));



ALTER TABLE "public"."prestamos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."prestamos_avales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "prestamos_avales_access" ON "public"."prestamos_avales" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "prestamos_delete_scoped" ON "public"."prestamos" FOR DELETE USING (("public"."es_admin_o_superior"() OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



CREATE POLICY "prestamos_insert_scoped" ON "public"."prestamos" FOR INSERT WITH CHECK (("public"."es_admin_o_superior"() OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



CREATE POLICY "prestamos_select_scoped" ON "public"."prestamos" FOR SELECT USING (("public"."es_admin_o_superior"() OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true)))) OR (EXISTS ( SELECT 1
   FROM "public"."clientes" "c"
  WHERE (("c"."id" = "prestamos"."cliente_id") AND ("c"."usuario_id" = "auth"."uid"()))))));



CREATE POLICY "prestamos_update_scoped" ON "public"."prestamos" FOR UPDATE USING (("public"."es_admin_o_superior"() OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



ALTER TABLE "public"."promesas_pago" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "promesas_pago_access" ON "public"."promesas_pago" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."promociones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "promociones_modify" ON "public"."promociones" USING ("public"."es_admin_o_superior"());



CREATE POLICY "promociones_select" ON "public"."promociones" FOR SELECT USING ((("activa" = true) OR "public"."es_admin_o_superior"()));



CREATE POLICY "propiedades_authenticated" ON "public"."mis_propiedades" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_cliente_contactos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_cliente_contactos_access" ON "public"."purificadora_cliente_contactos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_cliente_documentos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_cliente_documentos_access" ON "public"."purificadora_cliente_documentos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_cliente_notas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_cliente_notas_access" ON "public"."purificadora_cliente_notas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_clientes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_clientes_access" ON "public"."purificadora_clientes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_cortes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_cortes_access" ON "public"."purificadora_cortes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_entregas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_entregas_access" ON "public"."purificadora_entregas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_garrafones_historial" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_garrafones_historial_access" ON "public"."purificadora_garrafones_historial" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_gastos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_gastos_access" ON "public"."purificadora_gastos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_inventario_garrafones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_inventario_garrafones_access" ON "public"."purificadora_inventario_garrafones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_pagos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_pagos_access" ON "public"."purificadora_pagos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_precios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_precios_access" ON "public"."purificadora_precios" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_produccion" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_produccion_access" ON "public"."purificadora_produccion" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_productos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_productos_access" ON "public"."purificadora_productos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_repartidores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_repartidores_access" ON "public"."purificadora_repartidores" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."purificadora_rutas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "purificadora_rutas_access" ON "public"."purificadora_rutas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."qr_cobros" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "qr_cobros_access" ON "public"."qr_cobros" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."qr_cobros_config" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "qr_cobros_config_access" ON "public"."qr_cobros_config" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."qr_cobros_escaneos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "qr_cobros_escaneos_access" ON "public"."qr_cobros_escaneos" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "qr_cobros_estadisticas_access" ON "public"."qr_cobros_estadisticas_diarias" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."qr_cobros_estadisticas_diarias" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."qr_cobros_reportes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "qr_config_access" ON "public"."qr_cobros_config" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "qr_escaneos_access" ON "public"."qr_cobros_escaneos" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "qr_reportes_access" ON "public"."qr_cobros_reportes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."recordatorios" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."registros_cobro" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "registros_cobro_access" ON "public"."registros_cobro" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "roles_delete_admin" ON "public"."roles" FOR DELETE USING ("public"."es_admin_o_superior"());



CREATE POLICY "roles_insert_admin" ON "public"."roles" FOR INSERT WITH CHECK ("public"."es_admin_o_superior"());



ALTER TABLE "public"."roles_permisos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "roles_permisos_delete_admin" ON "public"."roles_permisos" FOR DELETE USING ("public"."es_admin_o_superior"());



CREATE POLICY "roles_permisos_insert_admin" ON "public"."roles_permisos" FOR INSERT WITH CHECK ("public"."es_admin_o_superior"());



CREATE POLICY "roles_permisos_select_admin" ON "public"."roles_permisos" FOR SELECT USING ("public"."es_admin_o_superior"());



CREATE POLICY "roles_permisos_update_admin" ON "public"."roles_permisos" FOR UPDATE USING ("public"."es_admin_o_superior"());



CREATE POLICY "roles_select_authenticated" ON "public"."roles" FOR SELECT USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "roles_update_admin" ON "public"."roles" FOR UPDATE USING ("public"."es_admin_o_superior"());



ALTER TABLE "public"."seguimiento_judicial" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "seguimiento_judicial_access" ON "public"."seguimiento_judicial" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."stripe_config" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stripe_config_access" ON "public"."stripe_config" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "stripe_log_access" ON "public"."stripe_transactions_log" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."stripe_transactions_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stripe_transactions_log_access" ON "public"."stripe_transactions_log" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."sucursales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sucursales_delete_scoped" ON "public"."sucursales" FOR DELETE USING (("public"."es_admin_o_superior"() OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



CREATE POLICY "sucursales_insert_scoped" ON "public"."sucursales" FOR INSERT WITH CHECK (("public"."es_admin_o_superior"() OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



CREATE POLICY "sucursales_select_scoped" ON "public"."sucursales" FOR SELECT USING (("public"."es_admin_o_superior"() OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



CREATE POLICY "sucursales_update_scoped" ON "public"."sucursales" FOR UPDATE USING (("public"."es_admin_o_superior"() OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE (("usuarios_negocios"."usuario_id" = "auth"."uid"()) AND ("usuarios_negocios"."activo" = true))))));



ALTER TABLE "public"."tanda_pagos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tanda_pagos_access" ON "public"."tanda_pagos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."tanda_participantes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tanda_participantes_authenticated" ON "public"."tanda_participantes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."tandas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tandas_authenticated" ON "public"."tandas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."tandas_avales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tandas_avales_access" ON "public"."tandas_avales" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."tarjetas_alertas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_alertas_access" ON "public"."tarjetas_alertas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."tarjetas_config" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_config_admin" ON "public"."tarjetas_config" USING ((("auth"."role"() = 'authenticated'::"text") AND ("negocio_id" IN ( SELECT "un"."negocio_id"
   FROM "public"."usuarios_negocios" "un"
  WHERE (("un"."usuario_id" = "auth"."uid"()) AND ("un"."rol_negocio" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"])))))));



CREATE POLICY "tarjetas_config_select" ON "public"."tarjetas_config" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND (("negocio_id" IN ( SELECT "tarjetas_config"."negocio_id"
   FROM "public"."usuarios"
  WHERE ("usuarios"."id" = "auth"."uid"()))) OR ("negocio_id" IN ( SELECT "empleados"."negocio_id"
   FROM "public"."empleados"
  WHERE ("empleados"."usuario_id" = "auth"."uid"()))))));



ALTER TABLE "public"."tarjetas_digitales" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tarjetas_digitales_recargas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_digitales_superadmin_full" ON "public"."tarjetas_digitales" USING (((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))) OR (EXISTS ( SELECT 1
   FROM "public"."clientes" "c"
  WHERE (("c"."id" = "tarjetas_digitales"."cliente_id") AND ("c"."usuario_id" = "auth"."uid"()))))));



ALTER TABLE "public"."tarjetas_digitales_transacciones" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tarjetas_landing_config" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tarjetas_log" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_log_access" ON "public"."tarjetas_log" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."tarjetas_recargas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_recargas_access" ON "public"."tarjetas_recargas" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "tarjetas_recargas_policy" ON "public"."tarjetas_digitales_recargas" USING (((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))) OR (EXISTS ( SELECT 1
   FROM ("public"."tarjetas_digitales" "td"
     JOIN "public"."clientes" "c" ON (("td"."cliente_id" = "c"."id")))
  WHERE (("td"."id" = "tarjetas_digitales_recargas"."tarjeta_id") AND ("c"."usuario_id" = "auth"."uid"()))))));



CREATE POLICY "tarjetas_select" ON "public"."tarjetas_digitales" FOR SELECT USING ((("auth"."role"() = 'authenticated'::"text") AND ((EXISTS ( SELECT 1
   FROM "public"."clientes"
  WHERE (("clientes"."id" = "tarjetas_digitales"."cliente_id") AND ("clientes"."usuario_id" IS NOT NULL) AND ("clientes"."usuario_id" = "auth"."uid"())))) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))))));



ALTER TABLE "public"."tarjetas_servicio" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_servicio_delete" ON "public"."tarjetas_servicio" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text")))));



ALTER TABLE "public"."tarjetas_servicio_escaneos" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tarjetas_servicio_exportaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_servicio_insert" ON "public"."tarjetas_servicio" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))));



CREATE POLICY "tarjetas_servicio_select" ON "public"."tarjetas_servicio" FOR SELECT USING (((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text")))) OR ("negocio_id" IN ( SELECT "usuarios_negocios"."negocio_id"
   FROM "public"."usuarios_negocios"
  WHERE ("usuarios_negocios"."usuario_id" = "auth"."uid"()))) OR ("activa" = true)));



CREATE POLICY "tarjetas_servicio_update" ON "public"."tarjetas_servicio" FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))) OR ("created_by" = "auth"."uid"())));



ALTER TABLE "public"."tarjetas_solicitudes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_solicitudes_policy" ON "public"."tarjetas_solicitudes" USING (((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))) OR ("solicitante_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM "public"."clientes" "c"
  WHERE (("c"."id" = "tarjetas_solicitudes"."cliente_id") AND ("c"."usuario_id" = "auth"."uid"()))))));



ALTER TABLE "public"."tarjetas_templates" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tarjetas_titulares" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_titulares_access" ON "public"."tarjetas_titulares" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."tarjetas_transacciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_transacciones_access" ON "public"."tarjetas_transacciones" USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "tarjetas_transacciones_policy" ON "public"."tarjetas_digitales_transacciones" USING (((EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = ANY (ARRAY['superadmin'::"text", 'admin'::"text"]))))) OR (EXISTS ( SELECT 1
   FROM ("public"."tarjetas_digitales" "td"
     JOIN "public"."clientes" "c" ON (("td"."cliente_id" = "c"."id")))
  WHERE (("td"."id" = "tarjetas_digitales_transacciones"."tarjeta_id") AND ("c"."usuario_id" = "auth"."uid"()))))));



ALTER TABLE "public"."tarjetas_virtuales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tarjetas_virtuales_access" ON "public"."tarjetas_virtuales" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."temas_app" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "temas_app_modify" ON "public"."temas_app" USING ("public"."usuario_tiene_rol"('superadmin'::"text"));



CREATE POLICY "temas_app_select" ON "public"."temas_app" FOR SELECT USING (true);



CREATE POLICY "templates_select_public" ON "public"."tarjetas_templates" FOR SELECT USING (("activo" = true));



ALTER TABLE "public"."usuarios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usuarios_insert_admin" ON "public"."usuarios" FOR INSERT WITH CHECK ("public"."es_admin_o_superior"());



ALTER TABLE "public"."usuarios_negocios" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usuarios_negocios_access" ON "public"."usuarios_negocios" USING ((("usuario_id" = "auth"."uid"()) OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_roles" "ur"
     JOIN "public"."roles" "r" ON (("ur"."rol_id" = "r"."id")))
  WHERE (("ur"."usuario_id" = "auth"."uid"()) AND ("r"."nombre" = 'superadmin'::"text"))))));



ALTER TABLE "public"."usuarios_roles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usuarios_roles_delete_admin" ON "public"."usuarios_roles" FOR DELETE USING ("public"."es_admin_o_superior"());



CREATE POLICY "usuarios_roles_insert_admin" ON "public"."usuarios_roles" FOR INSERT WITH CHECK ("public"."es_admin_o_superior"());



CREATE POLICY "usuarios_roles_select_self_or_admin" ON "public"."usuarios_roles" FOR SELECT USING ((("usuario_id" = "auth"."uid"()) OR "public"."es_admin_o_superior"()));



CREATE POLICY "usuarios_roles_update_admin" ON "public"."usuarios_roles" FOR UPDATE USING ("public"."es_admin_o_superior"());



CREATE POLICY "usuarios_select_scoped" ON "public"."usuarios" FOR SELECT USING ((("id" = "auth"."uid"()) OR "public"."es_admin_o_superior"() OR (EXISTS ( SELECT 1
   FROM ("public"."usuarios_negocios" "un"
     JOIN "public"."usuarios_negocios" "un2" ON (("un2"."negocio_id" = "un"."negocio_id")))
  WHERE (("un"."usuario_id" = "auth"."uid"()) AND ("un"."activo" = true) AND ("un2"."usuario_id" = "usuarios"."id") AND ("un2"."activo" = true))))));



ALTER TABLE "public"."usuarios_sucursales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "usuarios_update_self_or_admin" ON "public"."usuarios" FOR UPDATE USING ((("auth"."uid"() = "id") OR "public"."es_admin_o_superior"()));



ALTER TABLE "public"."variantes_arquilado" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "variantes_arquilado_auth" ON "public"."variantes_arquilado" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_categorias" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_categorias_access" ON "public"."ventas_categorias" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_cliente_contactos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_cliente_contactos_access" ON "public"."ventas_cliente_contactos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_cliente_creditos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_cliente_creditos_access" ON "public"."ventas_cliente_creditos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_cliente_documentos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_cliente_documentos_access" ON "public"."ventas_cliente_documentos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_cliente_notas" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_cliente_notas_access" ON "public"."ventas_cliente_notas" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_clientes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_clientes_access" ON "public"."ventas_clientes" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_cotizaciones" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_cotizaciones_access" ON "public"."ventas_cotizaciones" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_pagos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_pagos_access" ON "public"."ventas_pagos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_pedidos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_pedidos_access" ON "public"."ventas_pedidos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_pedidos_detalle" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_pedidos_detalle_auth" ON "public"."ventas_pedidos_detalle" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_pedidos_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_pedidos_items_access" ON "public"."ventas_pedidos_items" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_productos" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_productos_access" ON "public"."ventas_productos" USING (("auth"."role"() = 'authenticated'::"text"));



ALTER TABLE "public"."ventas_vendedores" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "ventas_vendedores_access" ON "public"."ventas_vendedores" USING (("auth"."role"() = 'authenticated'::"text"));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_contador_leidos"() TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_contador_leidos"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_contador_leidos"() TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_nivel_vendedora"("p_vendedora_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_nivel_vendedora"("p_vendedora_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_nivel_vendedora"("p_vendedora_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_ultimo_mensaje_conversacion"() TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_ultimo_mensaje_conversacion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_ultimo_mensaje_conversacion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."actualizar_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."actualizar_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."actualizar_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."aplicar_mora_automatica"() TO "anon";
GRANT ALL ON FUNCTION "public"."aplicar_mora_automatica"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."aplicar_mora_automatica"() TO "service_role";



GRANT ALL ON FUNCTION "public"."asignar_superadmin_si_no_existe"() TO "anon";
GRANT ALL ON FUNCTION "public"."asignar_superadmin_si_no_existe"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."asignar_superadmin_si_no_existe"() TO "service_role";



GRANT ALL ON FUNCTION "public"."autoconfirmar_cobro_efectivo"() TO "anon";
GRANT ALL ON FUNCTION "public"."autoconfirmar_cobro_efectivo"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."autoconfirmar_cobro_efectivo"() TO "service_role";



GRANT ALL ON FUNCTION "public"."calcular_capital_total"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calcular_capital_total"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calcular_capital_total"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calcular_comision_nice"("p_vendedora_id" "uuid", "p_monto_venta" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."calcular_comision_nice"("p_vendedora_id" "uuid", "p_monto_venta" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calcular_comision_nice"("p_vendedora_id" "uuid", "p_monto_venta" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."calcular_mora_prestamo"("p_prestamo_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calcular_mora_prestamo"("p_prestamo_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calcular_mora_prestamo"("p_prestamo_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calcular_mora_prestamo"("p_amortizacion_id" "uuid", "p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."calcular_mora_prestamo"("p_amortizacion_id" "uuid", "p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."calcular_mora_prestamo"("p_amortizacion_id" "uuid", "p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."calcular_rendimiento_inversionista"("p_colaborador_id" "uuid", "p_mes" integer, "p_anio" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."calcular_rendimiento_inversionista"("p_colaborador_id" "uuid", "p_mes" integer, "p_anio" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."calcular_rendimiento_inversionista"("p_colaborador_id" "uuid", "p_mes" integer, "p_anio" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."cliente_tiene_prestamo_activo"("p_cliente_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."cliente_tiene_prestamo_activo"("p_cliente_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."cliente_tiene_prestamo_activo"("p_cliente_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."clientes_con_stripe"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."clientes_con_stripe"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."clientes_con_stripe"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."clientes_solo_efectivo"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."clientes_solo_efectivo"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."clientes_solo_efectivo"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."climas_aprobar_solicitud_qr"("p_solicitud_id" "uuid", "p_crear_cliente" boolean, "p_crear_orden" boolean, "p_notas" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."climas_aprobar_solicitud_qr"("p_solicitud_id" "uuid", "p_crear_cliente" boolean, "p_crear_orden" boolean, "p_notas" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."climas_aprobar_solicitud_qr"("p_solicitud_id" "uuid", "p_crear_cliente" boolean, "p_crear_orden" boolean, "p_notas" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."climas_obtener_solicitud_por_token"("p_token" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."climas_obtener_solicitud_por_token"("p_token" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."climas_obtener_solicitud_por_token"("p_token" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."confirmar_cobro_cliente"("p_codigo_qr" "text", "p_latitud" numeric, "p_longitud" numeric, "p_dispositivo" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."confirmar_cobro_cliente"("p_codigo_qr" "text", "p_latitud" numeric, "p_longitud" numeric, "p_dispositivo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."confirmar_cobro_cliente"("p_codigo_qr" "text", "p_latitud" numeric, "p_longitud" numeric, "p_dispositivo" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."confirmar_cobro_cobrador"("p_qr_id" "uuid", "p_latitud" numeric, "p_longitud" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."confirmar_cobro_cobrador"("p_qr_id" "uuid", "p_latitud" numeric, "p_longitud" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."confirmar_cobro_cobrador"("p_qr_id" "uuid", "p_latitud" numeric, "p_longitud" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_backup_completo"("p_notas" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."crear_backup_completo"("p_notas" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_backup_completo"("p_notas" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_empleado_completo"("p_auth_user_id" "uuid", "p_email" "text", "p_nombre_completo" "text", "p_telefono" "text", "p_puesto" "text", "p_salario" numeric, "p_sucursal_id" "uuid", "p_rol_id" "uuid", "p_comision_porcentaje" numeric, "p_comision_tipo" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."crear_empleado_completo"("p_auth_user_id" "uuid", "p_email" "text", "p_nombre_completo" "text", "p_telefono" "text", "p_puesto" "text", "p_salario" numeric, "p_sucursal_id" "uuid", "p_rol_id" "uuid", "p_comision_porcentaje" numeric, "p_comision_tipo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_empleado_completo"("p_auth_user_id" "uuid", "p_email" "text", "p_nombre_completo" "text", "p_telefono" "text", "p_puesto" "text", "p_salario" numeric, "p_sucursal_id" "uuid", "p_rol_id" "uuid", "p_comision_porcentaje" numeric, "p_comision_tipo" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."crear_qr_cobro"("p_negocio_id" "uuid", "p_cobrador_id" "uuid", "p_cliente_id" "uuid", "p_tipo_cobro" "text", "p_referencia_id" "uuid", "p_monto" numeric, "p_concepto" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."crear_qr_cobro"("p_negocio_id" "uuid", "p_cobrador_id" "uuid", "p_cliente_id" "uuid", "p_tipo_cobro" "text", "p_referencia_id" "uuid", "p_monto" numeric, "p_concepto" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."crear_qr_cobro"("p_negocio_id" "uuid", "p_cobrador_id" "uuid", "p_cliente_id" "uuid", "p_tipo_cobro" "text", "p_referencia_id" "uuid", "p_monto" numeric, "p_concepto" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."efectivo_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."efectivo_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."efectivo_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."ejecutar_mantenimiento_db"() TO "anon";
GRANT ALL ON FUNCTION "public"."ejecutar_mantenimiento_db"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."ejecutar_mantenimiento_db"() TO "service_role";



GRANT ALL ON FUNCTION "public"."es_admin_o_superior"() TO "anon";
GRANT ALL ON FUNCTION "public"."es_admin_o_superior"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."es_admin_o_superior"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generar_codigo_qr"() TO "anon";
GRANT ALL ON FUNCTION "public"."generar_codigo_qr"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generar_codigo_qr"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generar_codigo_vendedora"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generar_codigo_vendedora"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generar_codigo_vendedora"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generar_codigo_verificacion"() TO "anon";
GRANT ALL ON FUNCTION "public"."generar_codigo_verificacion"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generar_codigo_verificacion"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generar_folio_nice_pedido"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."generar_folio_nice_pedido"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."generar_folio_nice_pedido"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_tarjeta_deep_link"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_tarjeta_deep_link"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_tarjeta_deep_link"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_cuotas_proximas"("p_negocio_id" "uuid", "p_dias" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_cuotas_proximas"("p_negocio_id" "uuid", "p_dias" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cuotas_proximas"("p_negocio_id" "uuid", "p_dias" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_cuotas_vencidas"("p_negocio_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_cuotas_vencidas"("p_negocio_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_cuotas_vencidas"("p_negocio_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_dashboard_stats"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_dashboard_stats"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dashboard_stats"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_estadisticas_formularios"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_estadisticas_formularios"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_estadisticas_formularios"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_estado_cuenta_prestamo"("p_prestamo_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_estado_cuenta_prestamo"("p_prestamo_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_estado_cuenta_prestamo"("p_prestamo_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_formulario_config"("p_tarjeta_id" "uuid", "p_negocio_id" "uuid", "p_modulo" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."get_formulario_config"("p_tarjeta_id" "uuid", "p_negocio_id" "uuid", "p_modulo" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_formulario_config"("p_tarjeta_id" "uuid", "p_negocio_id" "uuid", "p_modulo" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_historial_pagos_cliente"("p_cliente_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_historial_pagos_cliente"("p_cliente_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_historial_pagos_cliente"("p_cliente_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_nice_dashboard_vendedora"("p_vendedora_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_nice_dashboard_vendedora"("p_vendedora_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_nice_dashboard_vendedora"("p_vendedora_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_nice_ranking_mes"("p_negocio_id" "uuid", "p_limit" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."get_nice_ranking_mes"("p_negocio_id" "uuid", "p_limit" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_nice_ranking_mes"("p_negocio_id" "uuid", "p_limit" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."get_resumen_cartera"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_resumen_cartera"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_resumen_cartera"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_sucursal_principal"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_sucursal_principal"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_sucursal_principal"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_tarjeta_stats"("p_tarjeta_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_tarjeta_stats"("p_tarjeta_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tarjeta_stats"("p_tarjeta_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_tarjetas_negocio"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."get_tarjetas_negocio"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_tarjetas_negocio"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."increment_tarjeta_escaneos"() TO "anon";
GRANT ALL ON FUNCTION "public"."increment_tarjeta_escaneos"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."increment_tarjeta_escaneos"() TO "service_role";



GRANT ALL ON FUNCTION "public"."inicializar_datos_nice"() TO "anon";
GRANT ALL ON FUNCTION "public"."inicializar_datos_nice"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."inicializar_datos_nice"() TO "service_role";



GRANT ALL ON FUNCTION "public"."invalidar_cache_estadisticas"() TO "anon";
GRANT ALL ON FUNCTION "public"."invalidar_cache_estadisticas"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."invalidar_cache_estadisticas"() TO "service_role";



GRANT ALL ON FUNCTION "public"."limpiar_auditoria_antigua"() TO "anon";
GRANT ALL ON FUNCTION "public"."limpiar_auditoria_antigua"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."limpiar_auditoria_antigua"() TO "service_role";



GRANT ALL ON FUNCTION "public"."limpiar_cache_expirado"() TO "anon";
GRANT ALL ON FUNCTION "public"."limpiar_cache_expirado"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."limpiar_cache_expirado"() TO "service_role";



GRANT ALL ON FUNCTION "public"."limpiar_datos_antiguos"() TO "anon";
GRANT ALL ON FUNCTION "public"."limpiar_datos_antiguos"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."limpiar_datos_antiguos"() TO "service_role";



GRANT ALL ON FUNCTION "public"."limpiar_notificaciones_antiguas"() TO "anon";
GRANT ALL ON FUNCTION "public"."limpiar_notificaciones_antiguas"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."limpiar_notificaciones_antiguas"() TO "service_role";



GRANT ALL ON FUNCTION "public"."log_activity"("p_accion" "text", "p_entidad" "text", "p_entidad_id" "uuid", "p_metadata" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."log_activity"("p_accion" "text", "p_entidad" "text", "p_entidad_id" "uuid", "p_metadata" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."log_activity"("p_accion" "text", "p_entidad" "text", "p_entidad_id" "uuid", "p_metadata" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."notificar_cobro_confirmado"() TO "anon";
GRANT ALL ON FUNCTION "public"."notificar_cobro_confirmado"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notificar_cobro_confirmado"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notificar_pago_vencido"() TO "anon";
GRANT ALL ON FUNCTION "public"."notificar_pago_vencido"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notificar_pago_vencido"() TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_estadisticas_cached"("p_negocio_id" "uuid", "p_tipo" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_estadisticas_cached"("p_negocio_id" "uuid", "p_tipo" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_estadisticas_cached"("p_negocio_id" "uuid", "p_tipo" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_estadisticas_facturacion"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_estadisticas_facturacion"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_estadisticas_facturacion"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_saldo_prestamo"("p_prestamo_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_saldo_prestamo"("p_prestamo_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_saldo_prestamo"("p_prestamo_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_siguiente_cuota"("p_prestamo_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_siguiente_cuota"("p_prestamo_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_siguiente_cuota"("p_prestamo_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."obtener_siguiente_folio"("p_emisor_id" "uuid", "p_tipo" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."obtener_siguiente_folio"("p_emisor_id" "uuid", "p_tipo" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."obtener_siguiente_folio"("p_emisor_id" "uuid", "p_tipo" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."refrescar_vistas_materializadas"() TO "anon";
GRANT ALL ON FUNCTION "public"."refrescar_vistas_materializadas"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refrescar_vistas_materializadas"() TO "service_role";



GRANT ALL ON FUNCTION "public"."refresh_vistas_materializadas"() TO "anon";
GRANT ALL ON FUNCTION "public"."refresh_vistas_materializadas"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."refresh_vistas_materializadas"() TO "service_role";



GRANT ALL ON FUNCTION "public"."registrar_actividad_colaborador"("p_colaborador_id" "uuid", "p_accion" "text", "p_descripcion" "text", "p_ip" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."registrar_actividad_colaborador"("p_colaborador_id" "uuid", "p_accion" "text", "p_descripcion" "text", "p_ip" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."registrar_actividad_colaborador"("p_colaborador_id" "uuid", "p_accion" "text", "p_descripcion" "text", "p_ip" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."resumen_cartera_negocio"("p_negocio_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."resumen_cartera_negocio"("p_negocio_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."resumen_cartera_negocio"("p_negocio_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_default_sucursal"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_default_sucursal"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_default_sucursal"() TO "service_role";



GRANT ALL ON FUNCTION "public"."stripe_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."stripe_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."stripe_total_cobrado"("p_negocio_id" "uuid", "p_fecha_inicio" "date", "p_fecha_fin" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_nice_comision_entrega"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_nice_comision_entrega"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_nice_comision_entrega"() TO "service_role";



GRANT ALL ON FUNCTION "public"."trigger_nice_pedido_folio"() TO "anon";
GRANT ALL ON FUNCTION "public"."trigger_nice_pedido_folio"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."trigger_nice_pedido_folio"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_climas_solicitud_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_climas_solicitud_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_climas_solicitud_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_formulario_config_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_formulario_config_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_formulario_config_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_propiedad_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_propiedad_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_propiedad_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_tarjeta_servicio_timestamp"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_tarjeta_servicio_timestamp"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_tarjeta_servicio_timestamp"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_tarjetas_config_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_tarjetas_config_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_tarjetas_config_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."usuario_tiene_rol"("rol_nombre" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."usuario_tiene_rol"("rol_nombre" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."usuario_tiene_rol"("rol_nombre" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."verificar_cobro_completo"("p_qr_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."verificar_cobro_completo"("p_qr_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."verificar_cobro_completo"("p_qr_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."verificar_integridad_datos"() TO "anon";
GRANT ALL ON FUNCTION "public"."verificar_integridad_datos"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."verificar_integridad_datos"() TO "service_role";



GRANT ALL ON TABLE "public"."activity_log" TO "anon";
GRANT ALL ON TABLE "public"."activity_log" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_log" TO "service_role";



GRANT ALL ON TABLE "public"."activos_capital" TO "anon";
GRANT ALL ON TABLE "public"."activos_capital" TO "authenticated";
GRANT ALL ON TABLE "public"."activos_capital" TO "service_role";



GRANT ALL ON TABLE "public"."acuses_recibo" TO "anon";
GRANT ALL ON TABLE "public"."acuses_recibo" TO "authenticated";
GRANT ALL ON TABLE "public"."acuses_recibo" TO "service_role";



GRANT ALL ON TABLE "public"."aires_equipos" TO "anon";
GRANT ALL ON TABLE "public"."aires_equipos" TO "authenticated";
GRANT ALL ON TABLE "public"."aires_equipos" TO "service_role";



GRANT ALL ON TABLE "public"."aires_garantias" TO "anon";
GRANT ALL ON TABLE "public"."aires_garantias" TO "authenticated";
GRANT ALL ON TABLE "public"."aires_garantias" TO "service_role";



GRANT ALL ON TABLE "public"."aires_ordenes_servicio" TO "anon";
GRANT ALL ON TABLE "public"."aires_ordenes_servicio" TO "authenticated";
GRANT ALL ON TABLE "public"."aires_ordenes_servicio" TO "service_role";



GRANT ALL ON TABLE "public"."aires_tecnicos" TO "anon";
GRANT ALL ON TABLE "public"."aires_tecnicos" TO "authenticated";
GRANT ALL ON TABLE "public"."aires_tecnicos" TO "service_role";



GRANT ALL ON TABLE "public"."alertas_sistema" TO "anon";
GRANT ALL ON TABLE "public"."alertas_sistema" TO "authenticated";
GRANT ALL ON TABLE "public"."alertas_sistema" TO "service_role";



GRANT ALL ON TABLE "public"."amortizaciones" TO "anon";
GRANT ALL ON TABLE "public"."amortizaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."amortizaciones" TO "service_role";



GRANT ALL ON TABLE "public"."aportaciones" TO "anon";
GRANT ALL ON TABLE "public"."aportaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."aportaciones" TO "service_role";



GRANT ALL ON TABLE "public"."auditoria" TO "anon";
GRANT ALL ON TABLE "public"."auditoria" TO "authenticated";
GRANT ALL ON TABLE "public"."auditoria" TO "service_role";



GRANT ALL ON TABLE "public"."auditoria_acceso" TO "anon";
GRANT ALL ON TABLE "public"."auditoria_acceso" TO "authenticated";
GRANT ALL ON TABLE "public"."auditoria_acceso" TO "service_role";



GRANT ALL ON TABLE "public"."auditoria_accesos" TO "anon";
GRANT ALL ON TABLE "public"."auditoria_accesos" TO "authenticated";
GRANT ALL ON TABLE "public"."auditoria_accesos" TO "service_role";



GRANT ALL ON TABLE "public"."auditoria_legal" TO "anon";
GRANT ALL ON TABLE "public"."auditoria_legal" TO "authenticated";
GRANT ALL ON TABLE "public"."auditoria_legal" TO "service_role";



GRANT ALL ON TABLE "public"."aval_checkins" TO "anon";
GRANT ALL ON TABLE "public"."aval_checkins" TO "authenticated";
GRANT ALL ON TABLE "public"."aval_checkins" TO "service_role";



GRANT ALL ON TABLE "public"."avales" TO "anon";
GRANT ALL ON TABLE "public"."avales" TO "authenticated";
GRANT ALL ON TABLE "public"."avales" TO "service_role";



GRANT ALL ON TABLE "public"."cache_estadisticas" TO "anon";
GRANT ALL ON TABLE "public"."cache_estadisticas" TO "authenticated";
GRANT ALL ON TABLE "public"."cache_estadisticas" TO "service_role";



GRANT ALL ON TABLE "public"."calendario" TO "anon";
GRANT ALL ON TABLE "public"."calendario" TO "authenticated";
GRANT ALL ON TABLE "public"."calendario" TO "service_role";



GRANT ALL ON TABLE "public"."campos_formulario_catalogo" TO "anon";
GRANT ALL ON TABLE "public"."campos_formulario_catalogo" TO "authenticated";
GRANT ALL ON TABLE "public"."campos_formulario_catalogo" TO "service_role";



GRANT ALL ON TABLE "public"."cat_forma_pago" TO "anon";
GRANT ALL ON TABLE "public"."cat_forma_pago" TO "authenticated";
GRANT ALL ON TABLE "public"."cat_forma_pago" TO "service_role";



GRANT ALL ON TABLE "public"."cat_regimen_fiscal" TO "anon";
GRANT ALL ON TABLE "public"."cat_regimen_fiscal" TO "authenticated";
GRANT ALL ON TABLE "public"."cat_regimen_fiscal" TO "service_role";



GRANT ALL ON TABLE "public"."cat_uso_cfdi" TO "anon";
GRANT ALL ON TABLE "public"."cat_uso_cfdi" TO "authenticated";
GRANT ALL ON TABLE "public"."cat_uso_cfdi" TO "service_role";



GRANT ALL ON TABLE "public"."catalogo_forma_pago" TO "anon";
GRANT ALL ON TABLE "public"."catalogo_forma_pago" TO "authenticated";
GRANT ALL ON TABLE "public"."catalogo_forma_pago" TO "service_role";



GRANT ALL ON TABLE "public"."catalogo_regimen_fiscal" TO "anon";
GRANT ALL ON TABLE "public"."catalogo_regimen_fiscal" TO "authenticated";
GRANT ALL ON TABLE "public"."catalogo_regimen_fiscal" TO "service_role";



GRANT ALL ON TABLE "public"."catalogo_uso_cfdi" TO "anon";
GRANT ALL ON TABLE "public"."catalogo_uso_cfdi" TO "authenticated";
GRANT ALL ON TABLE "public"."catalogo_uso_cfdi" TO "service_role";



GRANT ALL ON TABLE "public"."chat_aval_cobrador" TO "anon";
GRANT ALL ON TABLE "public"."chat_aval_cobrador" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_aval_cobrador" TO "service_role";



GRANT ALL ON TABLE "public"."chat_conversaciones" TO "anon";
GRANT ALL ON TABLE "public"."chat_conversaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_conversaciones" TO "service_role";



GRANT ALL ON TABLE "public"."chat_mensajes" TO "anon";
GRANT ALL ON TABLE "public"."chat_mensajes" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_mensajes" TO "service_role";



GRANT ALL ON TABLE "public"."chat_participantes" TO "anon";
GRANT ALL ON TABLE "public"."chat_participantes" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_participantes" TO "service_role";



GRANT ALL ON TABLE "public"."chats" TO "anon";
GRANT ALL ON TABLE "public"."chats" TO "authenticated";
GRANT ALL ON TABLE "public"."chats" TO "service_role";



GRANT ALL ON TABLE "public"."clientes" TO "anon";
GRANT ALL ON TABLE "public"."clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."clientes" TO "service_role";



GRANT ALL ON TABLE "public"."clientes_bloqueados_mora" TO "anon";
GRANT ALL ON TABLE "public"."clientes_bloqueados_mora" TO "authenticated";
GRANT ALL ON TABLE "public"."clientes_bloqueados_mora" TO "service_role";



GRANT ALL ON TABLE "public"."clientes_modulo" TO "anon";
GRANT ALL ON TABLE "public"."clientes_modulo" TO "authenticated";
GRANT ALL ON TABLE "public"."clientes_modulo" TO "service_role";



GRANT ALL ON TABLE "public"."climas_calendario" TO "anon";
GRANT ALL ON TABLE "public"."climas_calendario" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_calendario" TO "service_role";



GRANT ALL ON TABLE "public"."climas_catalogo_servicios_publico" TO "anon";
GRANT ALL ON TABLE "public"."climas_catalogo_servicios_publico" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_catalogo_servicios_publico" TO "service_role";



GRANT ALL ON TABLE "public"."climas_certificaciones_tecnico" TO "anon";
GRANT ALL ON TABLE "public"."climas_certificaciones_tecnico" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_certificaciones_tecnico" TO "service_role";



GRANT ALL ON TABLE "public"."climas_chat_solicitud" TO "anon";
GRANT ALL ON TABLE "public"."climas_chat_solicitud" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_chat_solicitud" TO "service_role";



GRANT ALL ON TABLE "public"."climas_checklist_respuestas" TO "anon";
GRANT ALL ON TABLE "public"."climas_checklist_respuestas" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_checklist_respuestas" TO "service_role";



GRANT ALL ON TABLE "public"."climas_checklist_servicio" TO "anon";
GRANT ALL ON TABLE "public"."climas_checklist_servicio" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_checklist_servicio" TO "service_role";



GRANT ALL ON TABLE "public"."climas_cliente_contactos" TO "anon";
GRANT ALL ON TABLE "public"."climas_cliente_contactos" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_cliente_contactos" TO "service_role";



GRANT ALL ON TABLE "public"."climas_cliente_documentos" TO "anon";
GRANT ALL ON TABLE "public"."climas_cliente_documentos" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_cliente_documentos" TO "service_role";



GRANT ALL ON TABLE "public"."climas_cliente_notas" TO "anon";
GRANT ALL ON TABLE "public"."climas_cliente_notas" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_cliente_notas" TO "service_role";



GRANT ALL ON TABLE "public"."climas_clientes" TO "anon";
GRANT ALL ON TABLE "public"."climas_clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_clientes" TO "service_role";



GRANT ALL ON TABLE "public"."climas_comisiones" TO "anon";
GRANT ALL ON TABLE "public"."climas_comisiones" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_comisiones" TO "service_role";



GRANT ALL ON TABLE "public"."climas_comprobantes" TO "anon";
GRANT ALL ON TABLE "public"."climas_comprobantes" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_comprobantes" TO "service_role";



GRANT ALL ON TABLE "public"."climas_config_formulario_qr" TO "anon";
GRANT ALL ON TABLE "public"."climas_config_formulario_qr" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_config_formulario_qr" TO "service_role";



GRANT ALL ON TABLE "public"."climas_configuracion" TO "anon";
GRANT ALL ON TABLE "public"."climas_configuracion" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_configuracion" TO "service_role";



GRANT ALL ON TABLE "public"."climas_cotizaciones" TO "anon";
GRANT ALL ON TABLE "public"."climas_cotizaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_cotizaciones" TO "service_role";



GRANT ALL ON TABLE "public"."climas_cotizaciones_v2" TO "anon";
GRANT ALL ON TABLE "public"."climas_cotizaciones_v2" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_cotizaciones_v2" TO "service_role";



GRANT ALL ON TABLE "public"."climas_equipos" TO "anon";
GRANT ALL ON TABLE "public"."climas_equipos" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_equipos" TO "service_role";



GRANT ALL ON TABLE "public"."climas_equipos_cliente" TO "anon";
GRANT ALL ON TABLE "public"."climas_equipos_cliente" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_equipos_cliente" TO "service_role";



GRANT ALL ON TABLE "public"."climas_garantias" TO "anon";
GRANT ALL ON TABLE "public"."climas_garantias" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_garantias" TO "service_role";



GRANT ALL ON TABLE "public"."climas_incidencias" TO "anon";
GRANT ALL ON TABLE "public"."climas_incidencias" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_incidencias" TO "service_role";



GRANT ALL ON TABLE "public"."climas_inventario_tecnico" TO "anon";
GRANT ALL ON TABLE "public"."climas_inventario_tecnico" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_inventario_tecnico" TO "service_role";



GRANT ALL ON TABLE "public"."climas_mensajes" TO "anon";
GRANT ALL ON TABLE "public"."climas_mensajes" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_mensajes" TO "service_role";



GRANT ALL ON TABLE "public"."climas_metricas_tecnico" TO "anon";
GRANT ALL ON TABLE "public"."climas_metricas_tecnico" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_metricas_tecnico" TO "service_role";



GRANT ALL ON TABLE "public"."climas_movimientos_inventario" TO "anon";
GRANT ALL ON TABLE "public"."climas_movimientos_inventario" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_movimientos_inventario" TO "service_role";



GRANT ALL ON TABLE "public"."climas_ordenes_servicio" TO "anon";
GRANT ALL ON TABLE "public"."climas_ordenes_servicio" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_ordenes_servicio" TO "service_role";



GRANT ALL ON TABLE "public"."climas_pagos" TO "anon";
GRANT ALL ON TABLE "public"."climas_pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_pagos" TO "service_role";



GRANT ALL ON TABLE "public"."climas_precios_servicio" TO "anon";
GRANT ALL ON TABLE "public"."climas_precios_servicio" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_precios_servicio" TO "service_role";



GRANT ALL ON TABLE "public"."climas_productos" TO "anon";
GRANT ALL ON TABLE "public"."climas_productos" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_productos" TO "service_role";



GRANT ALL ON TABLE "public"."climas_recordatorios_mantenimiento" TO "anon";
GRANT ALL ON TABLE "public"."climas_recordatorios_mantenimiento" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_recordatorios_mantenimiento" TO "service_role";



GRANT ALL ON TABLE "public"."climas_registro_tiempo" TO "anon";
GRANT ALL ON TABLE "public"."climas_registro_tiempo" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_registro_tiempo" TO "service_role";



GRANT ALL ON TABLE "public"."climas_solicitud_historial" TO "anon";
GRANT ALL ON TABLE "public"."climas_solicitud_historial" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_solicitud_historial" TO "service_role";



GRANT ALL ON TABLE "public"."climas_solicitudes_cliente" TO "anon";
GRANT ALL ON TABLE "public"."climas_solicitudes_cliente" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_solicitudes_cliente" TO "service_role";



GRANT ALL ON TABLE "public"."climas_solicitudes_qr" TO "anon";
GRANT ALL ON TABLE "public"."climas_solicitudes_qr" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_solicitudes_qr" TO "service_role";



GRANT ALL ON TABLE "public"."climas_solicitudes_refacciones" TO "anon";
GRANT ALL ON TABLE "public"."climas_solicitudes_refacciones" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_solicitudes_refacciones" TO "service_role";



GRANT ALL ON TABLE "public"."climas_tecnico_zonas" TO "anon";
GRANT ALL ON TABLE "public"."climas_tecnico_zonas" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_tecnico_zonas" TO "service_role";



GRANT ALL ON TABLE "public"."climas_tecnicos" TO "anon";
GRANT ALL ON TABLE "public"."climas_tecnicos" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_tecnicos" TO "service_role";



GRANT ALL ON TABLE "public"."climas_zonas" TO "anon";
GRANT ALL ON TABLE "public"."climas_zonas" TO "authenticated";
GRANT ALL ON TABLE "public"."climas_zonas" TO "service_role";



GRANT ALL ON TABLE "public"."colaborador_actividad" TO "anon";
GRANT ALL ON TABLE "public"."colaborador_actividad" TO "authenticated";
GRANT ALL ON TABLE "public"."colaborador_actividad" TO "service_role";



GRANT ALL ON TABLE "public"."colaborador_compensaciones" TO "anon";
GRANT ALL ON TABLE "public"."colaborador_compensaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."colaborador_compensaciones" TO "service_role";



GRANT ALL ON TABLE "public"."colaborador_inversiones" TO "anon";
GRANT ALL ON TABLE "public"."colaborador_inversiones" TO "authenticated";
GRANT ALL ON TABLE "public"."colaborador_inversiones" TO "service_role";



GRANT ALL ON TABLE "public"."colaborador_invitaciones" TO "anon";
GRANT ALL ON TABLE "public"."colaborador_invitaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."colaborador_invitaciones" TO "service_role";



GRANT ALL ON TABLE "public"."colaborador_pagos" TO "anon";
GRANT ALL ON TABLE "public"."colaborador_pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."colaborador_pagos" TO "service_role";



GRANT ALL ON TABLE "public"."colaborador_permisos_modulo" TO "anon";
GRANT ALL ON TABLE "public"."colaborador_permisos_modulo" TO "authenticated";
GRANT ALL ON TABLE "public"."colaborador_permisos_modulo" TO "service_role";



GRANT ALL ON TABLE "public"."colaborador_rendimientos" TO "anon";
GRANT ALL ON TABLE "public"."colaborador_rendimientos" TO "authenticated";
GRANT ALL ON TABLE "public"."colaborador_rendimientos" TO "service_role";



GRANT ALL ON TABLE "public"."colaborador_tipos" TO "anon";
GRANT ALL ON TABLE "public"."colaborador_tipos" TO "authenticated";
GRANT ALL ON TABLE "public"."colaborador_tipos" TO "service_role";



GRANT ALL ON TABLE "public"."colaboradores" TO "anon";
GRANT ALL ON TABLE "public"."colaboradores" TO "authenticated";
GRANT ALL ON TABLE "public"."colaboradores" TO "service_role";



GRANT ALL ON TABLE "public"."comisiones_empleados" TO "anon";
GRANT ALL ON TABLE "public"."comisiones_empleados" TO "authenticated";
GRANT ALL ON TABLE "public"."comisiones_empleados" TO "service_role";



GRANT ALL ON TABLE "public"."compensacion_tipos" TO "anon";
GRANT ALL ON TABLE "public"."compensacion_tipos" TO "authenticated";
GRANT ALL ON TABLE "public"."compensacion_tipos" TO "service_role";



GRANT ALL ON TABLE "public"."comprobantes" TO "anon";
GRANT ALL ON TABLE "public"."comprobantes" TO "authenticated";
GRANT ALL ON TABLE "public"."comprobantes" TO "service_role";



GRANT ALL ON TABLE "public"."comprobantes_prestamo" TO "anon";
GRANT ALL ON TABLE "public"."comprobantes_prestamo" TO "authenticated";
GRANT ALL ON TABLE "public"."comprobantes_prestamo" TO "service_role";



GRANT ALL ON TABLE "public"."configuracion" TO "anon";
GRANT ALL ON TABLE "public"."configuracion" TO "authenticated";
GRANT ALL ON TABLE "public"."configuracion" TO "service_role";



GRANT ALL ON TABLE "public"."configuracion_apis" TO "anon";
GRANT ALL ON TABLE "public"."configuracion_apis" TO "authenticated";
GRANT ALL ON TABLE "public"."configuracion_apis" TO "service_role";



GRANT ALL ON TABLE "public"."configuracion_global" TO "anon";
GRANT ALL ON TABLE "public"."configuracion_global" TO "authenticated";
GRANT ALL ON TABLE "public"."configuracion_global" TO "service_role";



GRANT ALL ON TABLE "public"."configuracion_moras" TO "anon";
GRANT ALL ON TABLE "public"."configuracion_moras" TO "authenticated";
GRANT ALL ON TABLE "public"."configuracion_moras" TO "service_role";



GRANT ALL ON TABLE "public"."contratos" TO "anon";
GRANT ALL ON TABLE "public"."contratos" TO "authenticated";
GRANT ALL ON TABLE "public"."contratos" TO "service_role";



GRANT ALL ON TABLE "public"."conversaciones" TO "anon";
GRANT ALL ON TABLE "public"."conversaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."conversaciones" TO "service_role";



GRANT ALL ON TABLE "public"."documentos_aval" TO "anon";
GRANT ALL ON TABLE "public"."documentos_aval" TO "authenticated";
GRANT ALL ON TABLE "public"."documentos_aval" TO "service_role";



GRANT ALL ON TABLE "public"."documentos_cliente" TO "anon";
GRANT ALL ON TABLE "public"."documentos_cliente" TO "authenticated";
GRANT ALL ON TABLE "public"."documentos_cliente" TO "service_role";



GRANT ALL ON TABLE "public"."empleados" TO "anon";
GRANT ALL ON TABLE "public"."empleados" TO "authenticated";
GRANT ALL ON TABLE "public"."empleados" TO "service_role";



GRANT ALL ON TABLE "public"."empleados_negocios" TO "anon";
GRANT ALL ON TABLE "public"."empleados_negocios" TO "authenticated";
GRANT ALL ON TABLE "public"."empleados_negocios" TO "service_role";



GRANT ALL ON TABLE "public"."entregas" TO "anon";
GRANT ALL ON TABLE "public"."entregas" TO "authenticated";
GRANT ALL ON TABLE "public"."entregas" TO "service_role";



GRANT ALL ON TABLE "public"."envios_capital" TO "anon";
GRANT ALL ON TABLE "public"."envios_capital" TO "authenticated";
GRANT ALL ON TABLE "public"."envios_capital" TO "service_role";



GRANT ALL ON TABLE "public"."expediente_clientes" TO "anon";
GRANT ALL ON TABLE "public"."expediente_clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."expediente_clientes" TO "service_role";



GRANT ALL ON TABLE "public"."expedientes_legales" TO "anon";
GRANT ALL ON TABLE "public"."expedientes_legales" TO "authenticated";
GRANT ALL ON TABLE "public"."expedientes_legales" TO "service_role";



GRANT ALL ON TABLE "public"."factura_complementos_pago" TO "anon";
GRANT ALL ON TABLE "public"."factura_complementos_pago" TO "authenticated";
GRANT ALL ON TABLE "public"."factura_complementos_pago" TO "service_role";



GRANT ALL ON TABLE "public"."factura_conceptos" TO "anon";
GRANT ALL ON TABLE "public"."factura_conceptos" TO "authenticated";
GRANT ALL ON TABLE "public"."factura_conceptos" TO "service_role";



GRANT ALL ON TABLE "public"."factura_documentos_relacionados" TO "anon";
GRANT ALL ON TABLE "public"."factura_documentos_relacionados" TO "authenticated";
GRANT ALL ON TABLE "public"."factura_documentos_relacionados" TO "service_role";



GRANT ALL ON TABLE "public"."factura_impuestos" TO "anon";
GRANT ALL ON TABLE "public"."factura_impuestos" TO "authenticated";
GRANT ALL ON TABLE "public"."factura_impuestos" TO "service_role";



GRANT ALL ON TABLE "public"."facturacion_clientes" TO "anon";
GRANT ALL ON TABLE "public"."facturacion_clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."facturacion_clientes" TO "service_role";



GRANT ALL ON TABLE "public"."facturacion_emisores" TO "anon";
GRANT ALL ON TABLE "public"."facturacion_emisores" TO "authenticated";
GRANT ALL ON TABLE "public"."facturacion_emisores" TO "service_role";



GRANT ALL ON TABLE "public"."facturacion_logs" TO "anon";
GRANT ALL ON TABLE "public"."facturacion_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."facturacion_logs" TO "service_role";



GRANT ALL ON TABLE "public"."facturacion_productos" TO "anon";
GRANT ALL ON TABLE "public"."facturacion_productos" TO "authenticated";
GRANT ALL ON TABLE "public"."facturacion_productos" TO "service_role";



GRANT ALL ON TABLE "public"."facturas" TO "anon";
GRANT ALL ON TABLE "public"."facturas" TO "authenticated";
GRANT ALL ON TABLE "public"."facturas" TO "service_role";



GRANT ALL ON TABLE "public"."firmas_avales" TO "anon";
GRANT ALL ON TABLE "public"."firmas_avales" TO "authenticated";
GRANT ALL ON TABLE "public"."firmas_avales" TO "service_role";



GRANT ALL ON TABLE "public"."firmas" TO "anon";
GRANT ALL ON TABLE "public"."firmas" TO "authenticated";
GRANT ALL ON TABLE "public"."firmas" TO "service_role";



GRANT ALL ON TABLE "public"."firmas_digitales" TO "anon";
GRANT ALL ON TABLE "public"."firmas_digitales" TO "authenticated";
GRANT ALL ON TABLE "public"."firmas_digitales" TO "service_role";



GRANT ALL ON TABLE "public"."fondos_pantalla" TO "anon";
GRANT ALL ON TABLE "public"."fondos_pantalla" TO "authenticated";
GRANT ALL ON TABLE "public"."fondos_pantalla" TO "service_role";



GRANT ALL ON TABLE "public"."fondos" TO "anon";
GRANT ALL ON TABLE "public"."fondos" TO "authenticated";
GRANT ALL ON TABLE "public"."fondos" TO "service_role";



GRANT ALL ON TABLE "public"."formularios_qr_config" TO "anon";
GRANT ALL ON TABLE "public"."formularios_qr_config" TO "authenticated";
GRANT ALL ON TABLE "public"."formularios_qr_config" TO "service_role";



GRANT ALL ON TABLE "public"."formularios_qr_envios" TO "anon";
GRANT ALL ON TABLE "public"."formularios_qr_envios" TO "authenticated";
GRANT ALL ON TABLE "public"."formularios_qr_envios" TO "service_role";



GRANT ALL ON TABLE "public"."intentos_cobro" TO "anon";
GRANT ALL ON TABLE "public"."intentos_cobro" TO "authenticated";
GRANT ALL ON TABLE "public"."intentos_cobro" TO "service_role";



GRANT ALL ON TABLE "public"."inventario" TO "anon";
GRANT ALL ON TABLE "public"."inventario" TO "authenticated";
GRANT ALL ON TABLE "public"."inventario" TO "service_role";



GRANT ALL ON TABLE "public"."inventario_movimientos" TO "anon";
GRANT ALL ON TABLE "public"."inventario_movimientos" TO "authenticated";
GRANT ALL ON TABLE "public"."inventario_movimientos" TO "service_role";



GRANT ALL ON TABLE "public"."links_pago" TO "anon";
GRANT ALL ON TABLE "public"."links_pago" TO "authenticated";
GRANT ALL ON TABLE "public"."links_pago" TO "service_role";



GRANT ALL ON TABLE "public"."log_fraude" TO "anon";
GRANT ALL ON TABLE "public"."log_fraude" TO "authenticated";
GRANT ALL ON TABLE "public"."log_fraude" TO "service_role";



GRANT ALL ON TABLE "public"."mensajes" TO "anon";
GRANT ALL ON TABLE "public"."mensajes" TO "authenticated";
GRANT ALL ON TABLE "public"."mensajes" TO "service_role";



GRANT ALL ON TABLE "public"."mensajes_aval_cobrador" TO "anon";
GRANT ALL ON TABLE "public"."mensajes_aval_cobrador" TO "authenticated";
GRANT ALL ON TABLE "public"."mensajes_aval_cobrador" TO "service_role";



GRANT ALL ON TABLE "public"."metodos_pago" TO "anon";
GRANT ALL ON TABLE "public"."metodos_pago" TO "authenticated";
GRANT ALL ON TABLE "public"."metodos_pago" TO "service_role";



GRANT ALL ON TABLE "public"."mis_propiedades" TO "anon";
GRANT ALL ON TABLE "public"."mis_propiedades" TO "authenticated";
GRANT ALL ON TABLE "public"."mis_propiedades" TO "service_role";



GRANT ALL ON TABLE "public"."modulos_activos" TO "anon";
GRANT ALL ON TABLE "public"."modulos_activos" TO "authenticated";
GRANT ALL ON TABLE "public"."modulos_activos" TO "service_role";



GRANT ALL ON TABLE "public"."moras_prestamos" TO "anon";
GRANT ALL ON TABLE "public"."moras_prestamos" TO "authenticated";
GRANT ALL ON TABLE "public"."moras_prestamos" TO "service_role";



GRANT ALL ON TABLE "public"."moras_tandas" TO "anon";
GRANT ALL ON TABLE "public"."moras_tandas" TO "authenticated";
GRANT ALL ON TABLE "public"."moras_tandas" TO "service_role";



GRANT ALL ON TABLE "public"."movimientos_capital" TO "anon";
GRANT ALL ON TABLE "public"."movimientos_capital" TO "authenticated";
GRANT ALL ON TABLE "public"."movimientos_capital" TO "service_role";



GRANT ALL ON TABLE "public"."prestamos" TO "anon";
GRANT ALL ON TABLE "public"."prestamos" TO "authenticated";
GRANT ALL ON TABLE "public"."prestamos" TO "service_role";



GRANT ALL ON TABLE "public"."mv_cobranza_dia" TO "anon";
GRANT ALL ON TABLE "public"."mv_cobranza_dia" TO "authenticated";
GRANT ALL ON TABLE "public"."mv_cobranza_dia" TO "service_role";



GRANT ALL ON TABLE "public"."pagos" TO "anon";
GRANT ALL ON TABLE "public"."pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."pagos" TO "service_role";



GRANT ALL ON TABLE "public"."mv_kpis_mes" TO "anon";
GRANT ALL ON TABLE "public"."mv_kpis_mes" TO "authenticated";
GRANT ALL ON TABLE "public"."mv_kpis_mes" TO "service_role";



GRANT ALL ON TABLE "public"."mv_resumen_cartera" TO "anon";
GRANT ALL ON TABLE "public"."mv_resumen_cartera" TO "authenticated";
GRANT ALL ON TABLE "public"."mv_resumen_cartera" TO "service_role";



GRANT ALL ON TABLE "public"."mv_resumen_mensual_pagos" TO "anon";
GRANT ALL ON TABLE "public"."mv_resumen_mensual_pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."mv_resumen_mensual_pagos" TO "service_role";



GRANT ALL ON TABLE "public"."mv_resumen_mensual_prestamos" TO "anon";
GRANT ALL ON TABLE "public"."mv_resumen_mensual_prestamos" TO "authenticated";
GRANT ALL ON TABLE "public"."mv_resumen_mensual_prestamos" TO "service_role";



GRANT ALL ON TABLE "public"."mv_top_clientes" TO "anon";
GRANT ALL ON TABLE "public"."mv_top_clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."mv_top_clientes" TO "service_role";



GRANT ALL ON TABLE "public"."negocios" TO "anon";
GRANT ALL ON TABLE "public"."negocios" TO "authenticated";
GRANT ALL ON TABLE "public"."negocios" TO "service_role";



GRANT ALL ON TABLE "public"."nice_catalogos" TO "anon";
GRANT ALL ON TABLE "public"."nice_catalogos" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_catalogos" TO "service_role";



GRANT ALL ON TABLE "public"."nice_categorias" TO "anon";
GRANT ALL ON TABLE "public"."nice_categorias" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_categorias" TO "service_role";



GRANT ALL ON TABLE "public"."nice_clientes" TO "anon";
GRANT ALL ON TABLE "public"."nice_clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_clientes" TO "service_role";



GRANT ALL ON TABLE "public"."nice_comisiones" TO "anon";
GRANT ALL ON TABLE "public"."nice_comisiones" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_comisiones" TO "service_role";



GRANT ALL ON TABLE "public"."nice_inventario_movimientos" TO "anon";
GRANT ALL ON TABLE "public"."nice_inventario_movimientos" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_inventario_movimientos" TO "service_role";



GRANT ALL ON TABLE "public"."nice_inventario_vendedora" TO "anon";
GRANT ALL ON TABLE "public"."nice_inventario_vendedora" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_inventario_vendedora" TO "service_role";



GRANT ALL ON TABLE "public"."nice_niveles" TO "anon";
GRANT ALL ON TABLE "public"."nice_niveles" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_niveles" TO "service_role";



GRANT ALL ON TABLE "public"."nice_pagos" TO "anon";
GRANT ALL ON TABLE "public"."nice_pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_pagos" TO "service_role";



GRANT ALL ON TABLE "public"."nice_pedido_items" TO "anon";
GRANT ALL ON TABLE "public"."nice_pedido_items" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_pedido_items" TO "service_role";



GRANT ALL ON TABLE "public"."nice_pedidos" TO "anon";
GRANT ALL ON TABLE "public"."nice_pedidos" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_pedidos" TO "service_role";



GRANT ALL ON TABLE "public"."nice_productos" TO "anon";
GRANT ALL ON TABLE "public"."nice_productos" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_productos" TO "service_role";



GRANT ALL ON TABLE "public"."nice_vendedoras" TO "anon";
GRANT ALL ON TABLE "public"."nice_vendedoras" TO "authenticated";
GRANT ALL ON TABLE "public"."nice_vendedoras" TO "service_role";



GRANT ALL ON TABLE "public"."notificaciones" TO "anon";
GRANT ALL ON TABLE "public"."notificaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."notificaciones" TO "service_role";



GRANT ALL ON TABLE "public"."notificaciones_documento_aval" TO "anon";
GRANT ALL ON TABLE "public"."notificaciones_documento_aval" TO "authenticated";
GRANT ALL ON TABLE "public"."notificaciones_documento_aval" TO "service_role";



GRANT ALL ON TABLE "public"."notificaciones_masivas" TO "anon";
GRANT ALL ON TABLE "public"."notificaciones_masivas" TO "authenticated";
GRANT ALL ON TABLE "public"."notificaciones_masivas" TO "service_role";



GRANT ALL ON TABLE "public"."notificaciones_mora" TO "anon";
GRANT ALL ON TABLE "public"."notificaciones_mora" TO "authenticated";
GRANT ALL ON TABLE "public"."notificaciones_mora" TO "service_role";



GRANT ALL ON TABLE "public"."notificaciones_mora_aval" TO "anon";
GRANT ALL ON TABLE "public"."notificaciones_mora_aval" TO "authenticated";
GRANT ALL ON TABLE "public"."notificaciones_mora_aval" TO "service_role";



GRANT ALL ON TABLE "public"."notificaciones_mora_cliente" TO "anon";
GRANT ALL ON TABLE "public"."notificaciones_mora_cliente" TO "authenticated";
GRANT ALL ON TABLE "public"."notificaciones_mora_cliente" TO "service_role";



GRANT ALL ON TABLE "public"."notificaciones_sistema" TO "anon";
GRANT ALL ON TABLE "public"."notificaciones_sistema" TO "authenticated";
GRANT ALL ON TABLE "public"."notificaciones_sistema" TO "service_role";



GRANT ALL ON TABLE "public"."pagos_comisiones" TO "anon";
GRANT ALL ON TABLE "public"."pagos_comisiones" TO "authenticated";
GRANT ALL ON TABLE "public"."pagos_comisiones" TO "service_role";



GRANT ALL ON TABLE "public"."pagos_propiedades" TO "anon";
GRANT ALL ON TABLE "public"."pagos_propiedades" TO "authenticated";
GRANT ALL ON TABLE "public"."pagos_propiedades" TO "service_role";



GRANT ALL ON TABLE "public"."permisos" TO "anon";
GRANT ALL ON TABLE "public"."permisos" TO "authenticated";
GRANT ALL ON TABLE "public"."permisos" TO "service_role";



GRANT ALL ON TABLE "public"."preferencias_usuario" TO "anon";
GRANT ALL ON TABLE "public"."preferencias_usuario" TO "authenticated";
GRANT ALL ON TABLE "public"."preferencias_usuario" TO "service_role";



GRANT ALL ON TABLE "public"."prestamos_avales" TO "anon";
GRANT ALL ON TABLE "public"."prestamos_avales" TO "authenticated";
GRANT ALL ON TABLE "public"."prestamos_avales" TO "service_role";



GRANT ALL ON TABLE "public"."promesas_pago" TO "anon";
GRANT ALL ON TABLE "public"."promesas_pago" TO "authenticated";
GRANT ALL ON TABLE "public"."promesas_pago" TO "service_role";



GRANT ALL ON TABLE "public"."promociones" TO "anon";
GRANT ALL ON TABLE "public"."promociones" TO "authenticated";
GRANT ALL ON TABLE "public"."promociones" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_pagos" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_pagos" TO "service_role";



GRANT ALL ON TABLE "public"."puri_pagos" TO "anon";
GRANT ALL ON TABLE "public"."puri_pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."puri_pagos" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_cliente_contactos" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_cliente_contactos" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_cliente_contactos" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_cliente_documentos" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_cliente_documentos" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_cliente_documentos" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_cliente_notas" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_cliente_notas" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_cliente_notas" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_clientes" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_clientes" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_cortes" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_cortes" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_cortes" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_entregas" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_entregas" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_entregas" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_garrafones_historial" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_garrafones_historial" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_garrafones_historial" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_gastos" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_gastos" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_gastos" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_inventario_garrafones" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_inventario_garrafones" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_inventario_garrafones" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_precios" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_precios" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_precios" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_produccion" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_produccion" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_produccion" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_productos" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_productos" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_productos" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_repartidores" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_repartidores" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_repartidores" TO "service_role";



GRANT ALL ON TABLE "public"."purificadora_rutas" TO "anon";
GRANT ALL ON TABLE "public"."purificadora_rutas" TO "authenticated";
GRANT ALL ON TABLE "public"."purificadora_rutas" TO "service_role";



GRANT ALL ON TABLE "public"."qr_cobros" TO "anon";
GRANT ALL ON TABLE "public"."qr_cobros" TO "authenticated";
GRANT ALL ON TABLE "public"."qr_cobros" TO "service_role";



GRANT ALL ON TABLE "public"."qr_cobros_config" TO "anon";
GRANT ALL ON TABLE "public"."qr_cobros_config" TO "authenticated";
GRANT ALL ON TABLE "public"."qr_cobros_config" TO "service_role";



GRANT ALL ON TABLE "public"."qr_cobros_escaneos" TO "anon";
GRANT ALL ON TABLE "public"."qr_cobros_escaneos" TO "authenticated";
GRANT ALL ON TABLE "public"."qr_cobros_escaneos" TO "service_role";



GRANT ALL ON TABLE "public"."qr_cobros_estadisticas_diarias" TO "anon";
GRANT ALL ON TABLE "public"."qr_cobros_estadisticas_diarias" TO "authenticated";
GRANT ALL ON TABLE "public"."qr_cobros_estadisticas_diarias" TO "service_role";



GRANT ALL ON TABLE "public"."qr_cobros_reportes" TO "anon";
GRANT ALL ON TABLE "public"."qr_cobros_reportes" TO "authenticated";
GRANT ALL ON TABLE "public"."qr_cobros_reportes" TO "service_role";



GRANT ALL ON TABLE "public"."recordatorios" TO "anon";
GRANT ALL ON TABLE "public"."recordatorios" TO "authenticated";
GRANT ALL ON TABLE "public"."recordatorios" TO "service_role";



GRANT ALL ON TABLE "public"."referencias_aval" TO "anon";
GRANT ALL ON TABLE "public"."referencias_aval" TO "authenticated";
GRANT ALL ON TABLE "public"."referencias_aval" TO "service_role";



GRANT ALL ON TABLE "public"."registros_cobro" TO "anon";
GRANT ALL ON TABLE "public"."registros_cobro" TO "authenticated";
GRANT ALL ON TABLE "public"."registros_cobro" TO "service_role";



GRANT ALL ON TABLE "public"."roles" TO "anon";
GRANT ALL ON TABLE "public"."roles" TO "authenticated";
GRANT ALL ON TABLE "public"."roles" TO "service_role";



GRANT ALL ON TABLE "public"."roles_permisos" TO "anon";
GRANT ALL ON TABLE "public"."roles_permisos" TO "authenticated";
GRANT ALL ON TABLE "public"."roles_permisos" TO "service_role";



GRANT ALL ON TABLE "public"."seguimiento_judicial" TO "anon";
GRANT ALL ON TABLE "public"."seguimiento_judicial" TO "authenticated";
GRANT ALL ON TABLE "public"."seguimiento_judicial" TO "service_role";



GRANT ALL ON TABLE "public"."stripe_config" TO "anon";
GRANT ALL ON TABLE "public"."stripe_config" TO "authenticated";
GRANT ALL ON TABLE "public"."stripe_config" TO "service_role";



GRANT ALL ON TABLE "public"."stripe_transactions_log" TO "anon";
GRANT ALL ON TABLE "public"."stripe_transactions_log" TO "authenticated";
GRANT ALL ON TABLE "public"."stripe_transactions_log" TO "service_role";



GRANT ALL ON TABLE "public"."sucursales" TO "anon";
GRANT ALL ON TABLE "public"."sucursales" TO "authenticated";
GRANT ALL ON TABLE "public"."sucursales" TO "service_role";



GRANT ALL ON TABLE "public"."tanda_pagos" TO "anon";
GRANT ALL ON TABLE "public"."tanda_pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."tanda_pagos" TO "service_role";



GRANT ALL ON TABLE "public"."tanda_participantes" TO "anon";
GRANT ALL ON TABLE "public"."tanda_participantes" TO "authenticated";
GRANT ALL ON TABLE "public"."tanda_participantes" TO "service_role";



GRANT ALL ON TABLE "public"."tandas" TO "anon";
GRANT ALL ON TABLE "public"."tandas" TO "authenticated";
GRANT ALL ON TABLE "public"."tandas" TO "service_role";



GRANT ALL ON TABLE "public"."tandas_avales" TO "anon";
GRANT ALL ON TABLE "public"."tandas_avales" TO "authenticated";
GRANT ALL ON TABLE "public"."tandas_avales" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_alertas" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_alertas" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_alertas" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_config" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_config" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_config" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_digitales" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_digitales" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_digitales" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_digitales_recargas" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_digitales_recargas" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_digitales_recargas" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_digitales_transacciones" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_digitales_transacciones" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_digitales_transacciones" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_landing_config" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_landing_config" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_landing_config" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_log" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_log" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_log" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_recargas" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_recargas" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_recargas" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_servicio" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_servicio" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_servicio" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_servicio_escaneos" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_servicio_escaneos" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_servicio_escaneos" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_servicio_exportaciones" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_servicio_exportaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_servicio_exportaciones" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_solicitudes" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_solicitudes" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_solicitudes" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_templates" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_templates" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_templates" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_titulares" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_titulares" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_titulares" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_transacciones" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_transacciones" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_transacciones" TO "service_role";



GRANT ALL ON TABLE "public"."tarjetas_virtuales" TO "anon";
GRANT ALL ON TABLE "public"."tarjetas_virtuales" TO "authenticated";
GRANT ALL ON TABLE "public"."tarjetas_virtuales" TO "service_role";



GRANT ALL ON TABLE "public"."temas_app" TO "anon";
GRANT ALL ON TABLE "public"."temas_app" TO "authenticated";
GRANT ALL ON TABLE "public"."temas_app" TO "service_role";



GRANT ALL ON TABLE "public"."transacciones_tarjeta" TO "anon";
GRANT ALL ON TABLE "public"."transacciones_tarjeta" TO "authenticated";
GRANT ALL ON TABLE "public"."transacciones_tarjeta" TO "service_role";



GRANT ALL ON TABLE "public"."usuarios" TO "anon";
GRANT ALL ON TABLE "public"."usuarios" TO "authenticated";
GRANT ALL ON TABLE "public"."usuarios" TO "service_role";



GRANT ALL ON TABLE "public"."usuarios_negocios" TO "anon";
GRANT ALL ON TABLE "public"."usuarios_negocios" TO "authenticated";
GRANT ALL ON TABLE "public"."usuarios_negocios" TO "service_role";



GRANT ALL ON TABLE "public"."usuarios_roles" TO "anon";
GRANT ALL ON TABLE "public"."usuarios_roles" TO "authenticated";
GRANT ALL ON TABLE "public"."usuarios_roles" TO "service_role";



GRANT ALL ON TABLE "public"."usuarios_sucursales" TO "anon";
GRANT ALL ON TABLE "public"."usuarios_sucursales" TO "authenticated";
GRANT ALL ON TABLE "public"."usuarios_sucursales" TO "service_role";



GRANT ALL ON TABLE "public"."v_colaboradores_completos" TO "anon";
GRANT ALL ON TABLE "public"."v_colaboradores_completos" TO "authenticated";
GRANT ALL ON TABLE "public"."v_colaboradores_completos" TO "service_role";



GRANT ALL ON TABLE "public"."v_facturas_completas" TO "anon";
GRANT ALL ON TABLE "public"."v_facturas_completas" TO "authenticated";
GRANT ALL ON TABLE "public"."v_facturas_completas" TO "service_role";



GRANT ALL ON TABLE "public"."v_nice_arbol_equipo" TO "anon";
GRANT ALL ON TABLE "public"."v_nice_arbol_equipo" TO "authenticated";
GRANT ALL ON TABLE "public"."v_nice_arbol_equipo" TO "service_role";



GRANT ALL ON TABLE "public"."v_nice_clientes_completo" TO "anon";
GRANT ALL ON TABLE "public"."v_nice_clientes_completo" TO "authenticated";
GRANT ALL ON TABLE "public"."v_nice_clientes_completo" TO "service_role";



GRANT ALL ON TABLE "public"."v_nice_comisiones_completo" TO "anon";
GRANT ALL ON TABLE "public"."v_nice_comisiones_completo" TO "authenticated";
GRANT ALL ON TABLE "public"."v_nice_comisiones_completo" TO "service_role";



GRANT ALL ON TABLE "public"."v_nice_inventario_vendedora" TO "anon";
GRANT ALL ON TABLE "public"."v_nice_inventario_vendedora" TO "authenticated";
GRANT ALL ON TABLE "public"."v_nice_inventario_vendedora" TO "service_role";



GRANT ALL ON TABLE "public"."v_nice_pedidos_completo" TO "anon";
GRANT ALL ON TABLE "public"."v_nice_pedidos_completo" TO "authenticated";
GRANT ALL ON TABLE "public"."v_nice_pedidos_completo" TO "service_role";



GRANT ALL ON TABLE "public"."v_nice_productos_completo" TO "anon";
GRANT ALL ON TABLE "public"."v_nice_productos_completo" TO "authenticated";
GRANT ALL ON TABLE "public"."v_nice_productos_completo" TO "service_role";



GRANT ALL ON TABLE "public"."v_nice_vendedoras_completo" TO "anon";
GRANT ALL ON TABLE "public"."v_nice_vendedoras_completo" TO "authenticated";
GRANT ALL ON TABLE "public"."v_nice_vendedoras_completo" TO "service_role";



GRANT ALL ON TABLE "public"."v_nice_vendedoras_stats" TO "anon";
GRANT ALL ON TABLE "public"."v_nice_vendedoras_stats" TO "authenticated";
GRANT ALL ON TABLE "public"."v_nice_vendedoras_stats" TO "service_role";



GRANT ALL ON TABLE "public"."v_qr_cobros_hoy" TO "anon";
GRANT ALL ON TABLE "public"."v_qr_cobros_hoy" TO "authenticated";
GRANT ALL ON TABLE "public"."v_qr_cobros_hoy" TO "service_role";



GRANT ALL ON TABLE "public"."v_qr_cobros_pendientes" TO "anon";
GRANT ALL ON TABLE "public"."v_qr_cobros_pendientes" TO "authenticated";
GRANT ALL ON TABLE "public"."v_qr_cobros_pendientes" TO "service_role";



GRANT ALL ON TABLE "public"."v_resumen_cobros_metodo" TO "anon";
GRANT ALL ON TABLE "public"."v_resumen_cobros_metodo" TO "authenticated";
GRANT ALL ON TABLE "public"."v_resumen_cobros_metodo" TO "service_role";



GRANT ALL ON TABLE "public"."v_tarjetas_cliente" TO "anon";
GRANT ALL ON TABLE "public"."v_tarjetas_cliente" TO "authenticated";
GRANT ALL ON TABLE "public"."v_tarjetas_cliente" TO "service_role";



GRANT ALL ON TABLE "public"."v_tarjetas_completas" TO "anon";
GRANT ALL ON TABLE "public"."v_tarjetas_completas" TO "authenticated";
GRANT ALL ON TABLE "public"."v_tarjetas_completas" TO "service_role";



GRANT ALL ON TABLE "public"."v_transacciones_completas" TO "anon";
GRANT ALL ON TABLE "public"."v_transacciones_completas" TO "authenticated";
GRANT ALL ON TABLE "public"."v_transacciones_completas" TO "service_role";



GRANT ALL ON TABLE "public"."validaciones_aval" TO "anon";
GRANT ALL ON TABLE "public"."validaciones_aval" TO "authenticated";
GRANT ALL ON TABLE "public"."validaciones_aval" TO "service_role";



GRANT ALL ON TABLE "public"."variantes_arquilado" TO "anon";
GRANT ALL ON TABLE "public"."variantes_arquilado" TO "authenticated";
GRANT ALL ON TABLE "public"."variantes_arquilado" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_categorias" TO "anon";
GRANT ALL ON TABLE "public"."ventas_categorias" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_categorias" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_cliente_contactos" TO "anon";
GRANT ALL ON TABLE "public"."ventas_cliente_contactos" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_cliente_contactos" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_cliente_creditos" TO "anon";
GRANT ALL ON TABLE "public"."ventas_cliente_creditos" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_cliente_creditos" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_cliente_documentos" TO "anon";
GRANT ALL ON TABLE "public"."ventas_cliente_documentos" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_cliente_documentos" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_cliente_notas" TO "anon";
GRANT ALL ON TABLE "public"."ventas_cliente_notas" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_cliente_notas" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_clientes" TO "anon";
GRANT ALL ON TABLE "public"."ventas_clientes" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_clientes" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_cotizaciones" TO "anon";
GRANT ALL ON TABLE "public"."ventas_cotizaciones" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_cotizaciones" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_pagos" TO "anon";
GRANT ALL ON TABLE "public"."ventas_pagos" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_pagos" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_pedidos_items" TO "anon";
GRANT ALL ON TABLE "public"."ventas_pedidos_items" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_pedidos_items" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_pedido_lineas" TO "anon";
GRANT ALL ON TABLE "public"."ventas_pedido_lineas" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_pedido_lineas" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_pedidos" TO "anon";
GRANT ALL ON TABLE "public"."ventas_pedidos" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_pedidos" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_pedidos_detalle" TO "anon";
GRANT ALL ON TABLE "public"."ventas_pedidos_detalle" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_pedidos_detalle" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_productos" TO "anon";
GRANT ALL ON TABLE "public"."ventas_productos" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_productos" TO "service_role";



GRANT ALL ON TABLE "public"."ventas_vendedores" TO "anon";
GRANT ALL ON TABLE "public"."ventas_vendedores" TO "authenticated";
GRANT ALL ON TABLE "public"."ventas_vendedores" TO "service_role";



GRANT ALL ON TABLE "public"."verificaciones_identidad" TO "anon";
GRANT ALL ON TABLE "public"."verificaciones_identidad" TO "authenticated";
GRANT ALL ON TABLE "public"."verificaciones_identidad" TO "service_role";



GRANT ALL ON TABLE "public"."vista_resumen_sucursal" TO "anon";
GRANT ALL ON TABLE "public"."vista_resumen_sucursal" TO "authenticated";
GRANT ALL ON TABLE "public"."vista_resumen_sucursal" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







