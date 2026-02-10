-- Hardening RLS and defaults for production coherence

-- Roles table: only authenticated can read; only admin/superadmin can modify
DROP POLICY IF EXISTS "roles_select_public" ON "public"."roles";
DROP POLICY IF EXISTS "roles_modify_authenticated" ON "public"."roles";

CREATE POLICY "roles_select_authenticated" ON "public"."roles"
  FOR SELECT
  USING (("auth"."role"() = 'authenticated'::"text"));

CREATE POLICY "roles_insert_admin" ON "public"."roles"
  FOR INSERT
  WITH CHECK ("public"."es_admin_o_superior"());

CREATE POLICY "roles_update_admin" ON "public"."roles"
  FOR UPDATE
  USING ("public"."es_admin_o_superior"());

CREATE POLICY "roles_delete_admin" ON "public"."roles"
  FOR DELETE
  USING ("public"."es_admin_o_superior"());

-- Roles_permisos: restrict to admin/superadmin
DROP POLICY IF EXISTS "roles_permisos_select_public" ON "public"."roles_permisos";
DROP POLICY IF EXISTS "roles_permisos_modify_authenticated" ON "public"."roles_permisos";

CREATE POLICY "roles_permisos_select_admin" ON "public"."roles_permisos"
  FOR SELECT
  USING ("public"."es_admin_o_superior"());

CREATE POLICY "roles_permisos_insert_admin" ON "public"."roles_permisos"
  FOR INSERT
  WITH CHECK ("public"."es_admin_o_superior"());

CREATE POLICY "roles_permisos_update_admin" ON "public"."roles_permisos"
  FOR UPDATE
  USING ("public"."es_admin_o_superior"());

CREATE POLICY "roles_permisos_delete_admin" ON "public"."roles_permisos"
  FOR DELETE
  USING ("public"."es_admin_o_superior"());

-- Usuarios_roles: allow users to read their own roles; only admin/superadmin can modify
DROP POLICY IF EXISTS "usuarios_roles_select_simple" ON "public"."usuarios_roles";
DROP POLICY IF EXISTS "usuarios_roles_insert_simple" ON "public"."usuarios_roles";
DROP POLICY IF EXISTS "usuarios_roles_update_simple" ON "public"."usuarios_roles";
DROP POLICY IF EXISTS "usuarios_roles_delete_simple" ON "public"."usuarios_roles";

CREATE POLICY "usuarios_roles_select_self_or_admin" ON "public"."usuarios_roles"
  FOR SELECT
  USING (("usuario_id" = "auth"."uid"()) OR "public"."es_admin_o_superior"());

CREATE POLICY "usuarios_roles_insert_admin" ON "public"."usuarios_roles"
  FOR INSERT
  WITH CHECK ("public"."es_admin_o_superior"());

CREATE POLICY "usuarios_roles_update_admin" ON "public"."usuarios_roles"
  FOR UPDATE
  USING ("public"."es_admin_o_superior"());

CREATE POLICY "usuarios_roles_delete_admin" ON "public"."usuarios_roles"
  FOR DELETE
  USING ("public"."es_admin_o_superior"());

-- Usuarios: restrict visibility to self, admin/superadmin, or shared negocio
DROP POLICY IF EXISTS "usuarios_select_all" ON "public"."usuarios";

CREATE POLICY "usuarios_select_scoped" ON "public"."usuarios"
  FOR SELECT
  USING (
    ("usuarios"."id" = "auth"."uid"())
    OR "public"."es_admin_o_superior"()
    OR EXISTS (
      SELECT 1
      FROM "public"."usuarios_negocios" un
      JOIN "public"."usuarios_negocios" un2 ON un2."negocio_id" = un."negocio_id"
      WHERE un."usuario_id" = "auth"."uid"()
        AND un."activo" = true
        AND un2."usuario_id" = "usuarios"."id"
        AND un2."activo" = true
    )
  );

-- Clientes: scope by negocio or self
DROP POLICY IF EXISTS "clientes_all_simple" ON "public"."clientes";
DROP POLICY IF EXISTS "clientes_authenticated" ON "public"."clientes";

CREATE POLICY "clientes_select_scoped" ON "public"."clientes"
  FOR SELECT
  USING (
    "public"."es_admin_o_superior"()
    OR ("usuario_id" = "auth"."uid"())
    OR ("negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    ))
  );

CREATE POLICY "clientes_insert_scoped" ON "public"."clientes"
  FOR INSERT
  WITH CHECK (
    "public"."es_admin_o_superior"()
    OR ("usuario_id" = "auth"."uid"())
    OR ("negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    ))
  );

CREATE POLICY "clientes_update_scoped" ON "public"."clientes"
  FOR UPDATE
  USING (
    "public"."es_admin_o_superior"()
    OR ("usuario_id" = "auth"."uid"())
    OR ("negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    ))
  );

CREATE POLICY "clientes_delete_scoped" ON "public"."clientes"
  FOR DELETE
  USING (
    "public"."es_admin_o_superior"()
    OR ("usuario_id" = "auth"."uid"())
    OR ("negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    ))
  );

-- Prestamos: allow read by negocio members/admin or by cliente due�o; restrict writes to admin/negocio members
DROP POLICY IF EXISTS "prestamos_all_simple" ON "public"."prestamos";
DROP POLICY IF EXISTS "prestamos_authenticated" ON "public"."prestamos";

CREATE POLICY "prestamos_select_scoped" ON "public"."prestamos"
  FOR SELECT
  USING (
    "public"."es_admin_o_superior"()
    OR ("negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    ))
    OR EXISTS (
      SELECT 1 FROM "public"."clientes" c
      WHERE c."id" = "cliente_id" AND c."usuario_id" = "auth"."uid"()
    )
  );

CREATE POLICY "prestamos_insert_scoped" ON "public"."prestamos"
  FOR INSERT
  WITH CHECK (
    "public"."es_admin_o_superior"()
    OR ("negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    ))
  );

CREATE POLICY "prestamos_update_scoped" ON "public"."prestamos"
  FOR UPDATE
  USING (
    "public"."es_admin_o_superior"()
    OR ("negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    ))
  );

CREATE POLICY "prestamos_delete_scoped" ON "public"."prestamos"
  FOR DELETE
  USING (
    "public"."es_admin_o_superior"()
    OR ("negocio_id" IN (
      SELECT "negocio_id" FROM "public"."usuarios_negocios"
      WHERE "usuario_id" = "auth"."uid"() AND "activo" = true
    ))
  );

-- Defaults: no test mode by default in production
ALTER TABLE "public"."configuracion_apis"
  ALTER COLUMN "modo_test" SET DEFAULT false;

ALTER TABLE "public"."facturacion_emisores"
  ALTER COLUMN "modo_pruebas" SET DEFAULT false;

ALTER TABLE "public"."tarjetas_config"
  ALTER COLUMN "modo_pruebas" SET DEFAULT false;

-- Deep link generation: avoid demo fallback when negocio_id is null
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
