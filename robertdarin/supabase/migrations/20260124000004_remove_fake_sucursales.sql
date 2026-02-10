-- Remove seeded sucursales and disable automatic defaults

-- 1) Remove automatic defaults and allow null (no fictitious sucursal)
ALTER TABLE "public"."clientes"
  ALTER COLUMN "sucursal_id" DROP DEFAULT,
  ALTER COLUMN "sucursal_id" DROP NOT NULL;

ALTER TABLE "public"."empleados"
  ALTER COLUMN "sucursal_id" DROP DEFAULT,
  ALTER COLUMN "sucursal_id" DROP NOT NULL;

ALTER TABLE "public"."prestamos"
  ALTER COLUMN "sucursal_id" DROP DEFAULT,
  ALTER COLUMN "sucursal_id" DROP NOT NULL;

ALTER TABLE "public"."tandas"
  ALTER COLUMN "sucursal_id" DROP DEFAULT,
  ALTER COLUMN "sucursal_id" DROP NOT NULL;

-- 2) Drop triggers that auto-assign sucursal
DROP TRIGGER IF EXISTS "trg_clientes_default_sucursal" ON "public"."clientes";
DROP TRIGGER IF EXISTS "trg_empleados_default_sucursal" ON "public"."empleados";
DROP TRIGGER IF EXISTS "trg_prestamos_default_sucursal" ON "public"."prestamos";
DROP TRIGGER IF EXISTS "trg_tandas_default_sucursal" ON "public"."tandas";

-- 3) Clean seeded sucursales and detach any references
WITH sucursales_seed AS (
  SELECT id
  FROM "public"."sucursales"
  WHERE (
    "nombre" IN ('Sucursal Principal', 'Sucursal Norte', 'Sucursal Sur')
    AND (
      "negocio_id" IS NULL
      OR "email" ILIKE '%@robertdarin.com'
      OR "codigo" = 'SUC-001'
      OR "direccion" IN ('Dirección Principal', 'Av. Norte #100', 'Av. Sur #200', 'Oficina Central')
      OR "telefono" IN ('555-0001', '555-0002', '555-0003', '5512345678')
    )
  )
)
UPDATE "public"."clientes"
  SET "sucursal_id" = NULL
  WHERE "sucursal_id" IN (SELECT id FROM sucursales_seed);

WITH sucursales_seed AS (
  SELECT id
  FROM "public"."sucursales"
  WHERE (
    "nombre" IN ('Sucursal Principal', 'Sucursal Norte', 'Sucursal Sur')
    AND (
      "negocio_id" IS NULL
      OR "email" ILIKE '%@robertdarin.com'
      OR "codigo" = 'SUC-001'
      OR "direccion" IN ('Dirección Principal', 'Av. Norte #100', 'Av. Sur #200', 'Oficina Central')
      OR "telefono" IN ('555-0001', '555-0002', '555-0003', '5512345678')
    )
  )
)
UPDATE "public"."empleados"
  SET "sucursal_id" = NULL
  WHERE "sucursal_id" IN (SELECT id FROM sucursales_seed);

WITH sucursales_seed AS (
  SELECT id
  FROM "public"."sucursales"
  WHERE (
    "nombre" IN ('Sucursal Principal', 'Sucursal Norte', 'Sucursal Sur')
    AND (
      "negocio_id" IS NULL
      OR "email" ILIKE '%@robertdarin.com'
      OR "codigo" = 'SUC-001'
      OR "direccion" IN ('Dirección Principal', 'Av. Norte #100', 'Av. Sur #200', 'Oficina Central')
      OR "telefono" IN ('555-0001', '555-0002', '555-0003', '5512345678')
    )
  )
)
UPDATE "public"."prestamos"
  SET "sucursal_id" = NULL
  WHERE "sucursal_id" IN (SELECT id FROM sucursales_seed);

WITH sucursales_seed AS (
  SELECT id
  FROM "public"."sucursales"
  WHERE (
    "nombre" IN ('Sucursal Principal', 'Sucursal Norte', 'Sucursal Sur')
    AND (
      "negocio_id" IS NULL
      OR "email" ILIKE '%@robertdarin.com'
      OR "codigo" = 'SUC-001'
      OR "direccion" IN ('Dirección Principal', 'Av. Norte #100', 'Av. Sur #200', 'Oficina Central')
      OR "telefono" IN ('555-0001', '555-0002', '555-0003', '5512345678')
    )
  )
)
UPDATE "public"."tandas"
  SET "sucursal_id" = NULL
  WHERE "sucursal_id" IN (SELECT id FROM sucursales_seed);

WITH sucursales_seed AS (
  SELECT id
  FROM "public"."sucursales"
  WHERE (
    "nombre" IN ('Sucursal Principal', 'Sucursal Norte', 'Sucursal Sur')
    AND (
      "negocio_id" IS NULL
      OR "email" ILIKE '%@robertdarin.com'
      OR "codigo" = 'SUC-001'
      OR "direccion" IN ('Dirección Principal', 'Av. Norte #100', 'Av. Sur #200', 'Oficina Central')
      OR "telefono" IN ('555-0001', '555-0002', '555-0003', '5512345678')
    )
  )
)
DELETE FROM "public"."usuarios_sucursales"
  WHERE "sucursal_id" IN (SELECT id FROM sucursales_seed);

WITH sucursales_seed AS (
  SELECT id
  FROM "public"."sucursales"
  WHERE (
    "nombre" IN ('Sucursal Principal', 'Sucursal Norte', 'Sucursal Sur')
    AND (
      "negocio_id" IS NULL
      OR "email" ILIKE '%@robertdarin.com'
      OR "codigo" = 'SUC-001'
      OR "direccion" IN ('Dirección Principal', 'Av. Norte #100', 'Av. Sur #200', 'Oficina Central')
      OR "telefono" IN ('555-0001', '555-0002', '555-0003', '5512345678')
    )
  )
)
DELETE FROM "public"."sucursales"
  WHERE "id" IN (SELECT id FROM sucursales_seed);

-- 4) Restrict RLS for sucursales to negocio membership
DROP POLICY IF EXISTS "sucursales_select_public" ON "public"."sucursales";
DROP POLICY IF EXISTS "sucursales_select" ON "public"."sucursales";
DROP POLICY IF EXISTS "sucursales_all_simple" ON "public"."sucursales";
DROP POLICY IF EXISTS "sucursales_read_authenticated" ON "public"."sucursales";
DROP POLICY IF EXISTS "sucursales_modify_authenticated" ON "public"."sucursales";
DROP POLICY IF EXISTS "sucursales_modify" ON "public"."sucursales";
DROP POLICY IF EXISTS "sucursales_modify_admin" ON "public"."sucursales";

CREATE POLICY "sucursales_select_scoped" ON "public"."sucursales"
  FOR SELECT
  USING (
    "public"."es_admin_o_superior"()
    OR "negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    )
  );

CREATE POLICY "sucursales_insert_scoped" ON "public"."sucursales"
  FOR INSERT
  WITH CHECK (
    "public"."es_admin_o_superior"()
    OR "negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    )
  );

CREATE POLICY "sucursales_update_scoped" ON "public"."sucursales"
  FOR UPDATE
  USING (
    "public"."es_admin_o_superior"()
    OR "negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    )
  );

CREATE POLICY "sucursales_delete_scoped" ON "public"."sucursales"
  FOR DELETE
  USING (
    "public"."es_admin_o_superior"()
    OR "negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    )
  );

