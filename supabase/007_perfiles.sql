-- Pimpa: perfil de la persona adulta, que completa la primera vez que entra (6 nov 2026).
-- Sirve para conocer quién usa Pimpa (buyer persona) y para tener un consentimiento de marketing aparte.
-- Ya corrido en el proyecto `pimpa`. Para repetirlo: SQL Editor > New query > Run.
-- Datos de los chicos: solo la edad (número). Nada de nombre, apellido ni diagnóstico.

create table if not exists public.perfiles (
  email             text primary key check (email = lower(email)),
  nombre            text not null check (length(btrim(nombre)) between 1 and 60),
  apellido          text not null check (length(btrim(apellido)) between 1 and 60),
  anio_nacimiento   int  check (anio_nacimiento between 1900 and 2100),
  pais              text not null check (length(btrim(pais)) between 2 and 60),
  ciudad            text not null check (length(btrim(ciudad)) between 1 and 80),
  celular           text check (celular is null or celular ~ '^\+?[0-9]{8,15}$'),
  relacion          text not null check (relacion in ('madre', 'padre', 'abuela_o', 'otro_familiar', 'docente', 'profesional', 'otro')),
  edades_chicos     int[] not null check (cardinality(edades_chicos) between 1 and 6),
  como_nos_conociste text check (como_nos_conociste is null or length(como_nos_conociste) <= 80),
  marketing_ok      boolean not null default false,
  marketing_ok_en   timestamptz,
  creado            timestamptz not null default now(),
  actualizado       timestamptz not null default now()
);

alter table public.perfiles enable row level security;
revoke all on public.perfiles from anon, authenticated;
grant select on public.perfiles to authenticated;

-- Cada persona ve solo su fila. Escribir se hace únicamente con guardar_perfil().
drop policy if exists "ver mi perfil" on public.perfiles;
create policy "ver mi perfil" on public.perfiles
  for select to authenticated
  using (email = lower(auth.jwt() ->> 'email'));

create or replace function public.guardar_perfil(
  p_nombre text, p_apellido text, p_anio_nacimiento int, p_pais text, p_ciudad text,
  p_celular text, p_relacion text, p_edades int[], p_como text, p_marketing boolean
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  e   text := lower(coalesce(auth.jwt() ->> 'email', ''));
  cel text := nullif(regexp_replace(coalesce(p_celular, ''), '[\s().-]', '', 'g'), '');
begin
  if e = '' or not public.is_allowed() then raise exception 'sin permiso'; end if;
  if p_edades is null or cardinality(p_edades) not between 1 and 6
     or exists (select 1 from unnest(p_edades) a where a is null or a not between 0 and 18) then
    return jsonb_build_object('ok', false, 'motivo', 'edades');
  end if;
  if p_anio_nacimiento is not null
     and p_anio_nacimiento not between 1920 and extract(year from now())::int - 16 then
    return jsonb_build_object('ok', false, 'motivo', 'anio');
  end if;
  if cel is not null and cel !~ '^\+?[0-9]{8,15}$' then
    return jsonb_build_object('ok', false, 'motivo', 'celular');
  end if;

  insert into public.perfiles (email, nombre, apellido, anio_nacimiento, pais, ciudad, celular, relacion,
                               edades_chicos, como_nos_conociste, marketing_ok, marketing_ok_en)
  values (e, btrim(p_nombre), btrim(p_apellido), p_anio_nacimiento, btrim(p_pais), btrim(p_ciudad), cel,
          p_relacion, p_edades, nullif(btrim(coalesce(p_como, '')), ''), coalesce(p_marketing, false),
          case when coalesce(p_marketing, false) then now() end)
  on conflict (email) do update set
    nombre = excluded.nombre, apellido = excluded.apellido, anio_nacimiento = excluded.anio_nacimiento,
    pais = excluded.pais, ciudad = excluded.ciudad, celular = excluded.celular, relacion = excluded.relacion,
    edades_chicos = excluded.edades_chicos, como_nos_conociste = excluded.como_nos_conociste,
    marketing_ok = excluded.marketing_ok,
    marketing_ok_en = case when excluded.marketing_ok is distinct from public.perfiles.marketing_ok
                           then now() else public.perfiles.marketing_ok_en end,
    actualizado = now();
  return jsonb_build_object('ok', true);
exception when check_violation then
  return jsonb_build_object('ok', false, 'motivo', 'datos');
end $$;

revoke all on function public.guardar_perfil(text, text, int, text, text, text, text, int[], text, boolean) from public, anon;
grant execute on function public.guardar_perfil(text, text, int, text, text, text, text, int[], text, boolean) to authenticated;
