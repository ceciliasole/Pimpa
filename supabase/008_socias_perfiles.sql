-- Pimpa: el panel /socias muestra los perfiles de quienes entraron (solo founder y cofounder). (6 nov 2026)
-- Ya corrido en el proyecto `pimpa`.

create or replace function public.socias_perfiles()
returns table (email text, nombre text, apellido text, relacion text, pais text, ciudad text,
               edades_chicos int[], anio_nacimiento int, celular text, como_nos_conociste text,
               marketing_ok boolean, marketing_ok_en timestamptz, creado timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  return query
  select p.email, p.nombre, p.apellido, p.relacion, p.pais, p.ciudad, p.edades_chicos, p.anio_nacimiento,
         p.celular, p.como_nos_conociste, p.marketing_ok, p.marketing_ok_en, p.creado
  from public.perfiles p order by p.creado desc;
end $$;

revoke all on function public.socias_perfiles() from public, anon;
grant execute on function public.socias_perfiles() to authenticated;
