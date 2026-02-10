drop trigger if exists "trg_procesar_recarga" on "public"."tarjetas_digitales_recargas";

drop trigger if exists "trg_actualizar_saldo_tarjeta" on "public"."tarjetas_digitales_transacciones";

drop policy "tarjetas_digitales_recargas_access" on "public"."tarjetas_digitales_recargas";

drop policy "tarjetas_digitales_trans_access" on "public"."tarjetas_digitales_transacciones";

drop policy "tarjetas_solicitudes_access" on "public"."tarjetas_solicitudes";

drop function if exists "public"."fn_actualizar_saldo_tarjeta"();

drop function if exists "public"."fn_procesar_recarga_tarjeta"();

drop view if exists "public"."v_tarjetas_cliente";

drop index if exists "public"."idx_tarjetas_solicitudes_cliente";

drop index if exists "public"."idx_tarjetas_solicitudes_estado";

drop index if exists "public"."idx_tarjetas_solicitudes_negocio";

drop index if exists "public"."idx_td_recargas_tarjeta";

drop index if exists "public"."idx_td_trans_fecha";

drop index if exists "public"."idx_td_trans_tarjeta";

drop index if exists "public"."idx_td_trans_tipo";

alter table "public"."tarjetas_digitales" drop column "cvv_hash";

alter table "public"."tarjetas_digitales" drop column "intentos_fallidos";

alter table "public"."tarjetas_digitales" drop column "pin_hash";

alter table "public"."tarjetas_digitales" drop column "ultimo_uso";

create or replace view "public"."v_tarjetas_cliente" as  SELECT t.id,
    t.cliente_id,
    t.negocio_id,
    t.codigo_tarjeta,
    t.ultimos_4,
    t.marca,
    t.tipo,
    t.estado,
    t.saldo_disponible,
    t.limite_diario,
    t.limite_mensual,
    t.fecha_vencimiento,
    t.activa,
    t.created_at,
    c.nombre AS cliente_nombre,
    c.telefono AS cliente_telefono,
    c.usuario_id AS cliente_usuario_id
   FROM (public.tarjetas_digitales t
     LEFT JOIN public.clientes c ON ((t.cliente_id = c.id)))
  WHERE (t.activa = true);



