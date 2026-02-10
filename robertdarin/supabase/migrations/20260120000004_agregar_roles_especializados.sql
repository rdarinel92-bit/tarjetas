-- ============================================
-- MIGRACIÓN: Agregar roles especializados faltantes
-- Fecha: 2026-01-20
-- Descripción: Agrega roles para módulos especializados (Nice, Climas, Purificadora, Ventas)
-- ============================================

-- Insertar roles faltantes
INSERT INTO public.roles (id, nombre, descripcion, created_at) VALUES
  (gen_random_uuid(), 'vendedora_nice', 'Vendedora NICE Joyería MLM con acceso al módulo de joyería', NOW()),
  (gen_random_uuid(), 'tecnico_climas', 'Técnico de aires acondicionados con acceso a órdenes de servicio', NOW()),
  (gen_random_uuid(), 'repartidor_purificadora', 'Repartidor de agua purificada con acceso a rutas y entregas', NOW()),
  (gen_random_uuid(), 'cliente_climas', 'Cliente del módulo de climas - puede ver sus equipos y servicios', NOW()),
  (gen_random_uuid(), 'cliente_purificadora', 'Cliente del módulo purificadora - puede hacer pedidos', NOW()),
  (gen_random_uuid(), 'vendedor_ventas', 'Vendedor del catálogo de ventas con acceso a clientes y pedidos', NOW())
ON CONFLICT (nombre) DO NOTHING;

-- Verificar inserción
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM public.roles;
  RAISE NOTICE 'Total de roles en el sistema: %', v_count;
END $$;
