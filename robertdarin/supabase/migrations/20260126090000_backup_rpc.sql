-- Expose backup function via public RPC with superadmin check
create or replace function public.crear_backup_completo(p_notas text default null)
returns table (
  tabla text,
  registros integer,
  estado text
)
language plpgsql
security definer
set search_path = public, backup
as $$
begin
  if not usuario_tiene_rol('superadmin') then
    raise exception 'No autorizado';
  end if;

  return query
  select * from backup.crear_backup_completo(p_notas);
end;
$$;

grant execute on function public.crear_backup_completo(text) to authenticated;
