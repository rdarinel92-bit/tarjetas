-- Make superadmin assignment safe when the user does not exist yet.
do $$
declare
  v_user_id uuid;
  v_rol_id uuid;
begin
  select id into v_user_id
  from auth.users
  where email = 'rdarinel992@gmail.com';

  if v_user_id is null then
    raise notice 'Usuario superadmin no existe en auth.users, se omite asignacion';
    return;
  end if;

  select id into v_rol_id
  from roles
  where nombre = 'superadmin';

  if v_rol_id is null then
    raise notice 'Rol superadmin no existe, se omite asignacion';
    return;
  end if;

  insert into usuarios (id, email, nombre_completo, activo, created_at, updated_at)
  values (v_user_id, 'rdarinel992@gmail.com', 'Robert Darin (Superadmin)', true, now(), now())
  on conflict (id) do update set
    email = excluded.email,
    nombre_completo = excluded.nombre_completo,
    activo = true,
    updated_at = now();

  delete from usuarios_roles where usuario_id = v_user_id;
  insert into usuarios_roles (usuario_id, rol_id) values (v_user_id, v_rol_id);

  raise notice 'Rol superadmin asignado';
end $$;
