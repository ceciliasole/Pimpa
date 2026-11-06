-- Pimpa: panel /socias (solo founder y cofounder) — lista de espera, envíos de mail y clics. (6 nov 2026)
-- Las tablas no tienen políticas: solo se tocan por las funciones de abajo, que chequean es_socia().

create or replace function public.es_socia() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.allowed_emails
                 where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
                   and rol in ('founder', 'cofounder'))
$$;
revoke all on function public.es_socia() from public, anon;
grant execute on function public.es_socia() to authenticated;

create table if not exists public.envios (
  id          uuid primary key default gen_random_uuid(),
  email       text not null,
  plantilla   text not null check (plantilla in ('listo', 'confirmado')),
  enviado_por text,
  creado      timestamptz not null default now(),
  estado      text not null default 'pendiente' check (estado in ('pendiente', 'enviado', 'error')),
  resend_id   text,
  error       text
);
create index if not exists envios_email_idx on public.envios (email);

create table if not exists public.clics (
  id       bigserial primary key,
  envio_id uuid not null references public.envios (id) on delete cascade,
  destino  text not null check (destino in ('pagar', 'entrar')),
  creado   timestamptz not null default now()
);
alter table public.envios enable row level security;
alter table public.clics  enable row level security;
revoke all on public.envios, public.clics from anon, authenticated;

create or replace function public.socias_lista()
returns table (email text, es_profesional boolean, cupon text, anotada timestamptz, habilitada boolean, rol text,
               listo_en timestamptz, listo_estado text, confirmado_en timestamptz, confirmado_estado text,
               clics_pagar int, clics_entrar int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  return query
  select w.email, w.es_profesional, w.cupon, w.created_at,
         (a.email is not null), a.rol,
         (select max(e.creado) from public.envios e where e.email = w.email and e.plantilla = 'listo'),
         (select e.estado from public.envios e where e.email = w.email and e.plantilla = 'listo' order by e.creado desc limit 1),
         (select max(e.creado) from public.envios e where e.email = w.email and e.plantilla = 'confirmado'),
         (select e.estado from public.envios e where e.email = w.email and e.plantilla = 'confirmado' order by e.creado desc limit 1),
         (select count(*)::int from public.clics c join public.envios e on e.id = c.envio_id where e.email = w.email and c.destino = 'pagar'),
         (select count(*)::int from public.clics c join public.envios e on e.id = c.envio_id where e.email = w.email and c.destino = 'entrar')
  from public.waitlist w
  left join public.allowed_emails a on a.email = w.email
  order by w.created_at;
end $$;

create or replace function public.socias_agregar(p_email text, p_es_profesional boolean default false, p_cupon text default null)
returns text language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(p_email)); c text := public.cupon_normalizar(p_cupon);
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'mail inválido'; end if;
  if c is not null and not exists (select 1 from public.coupons where codigo = c) then c := null; end if;
  insert into public.waitlist (email, es_profesional, cupon) values (e, coalesce(p_es_profesional, false), c)
  on conflict (email) do nothing;
  return e;
end $$;

create or replace function public.socias_habilitar(p_email text)
returns text language plpgsql security definer set search_path = public as $$
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  return public.habilitar(p_email, null);
end $$;

create or replace function public.registrar_envio(p_email text, p_plantilla text)
returns uuid language plpgsql security definer set search_path = public as $$
declare i uuid;
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  insert into public.envios (email, plantilla, enviado_por)
  values (lower(trim(p_email)), p_plantilla, lower(auth.jwt() ->> 'email')) returning id into i;
  return i;
end $$;

create or replace function public.cerrar_envio(p_id uuid, p_estado text, p_resend_id text default null, p_error text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  update public.envios set estado = p_estado, resend_id = p_resend_id, error = left(p_error, 500) where id = p_id;
end $$;

-- Lo llama la página /pagar y /entrar (sin login): solo guarda el clic si el envío existe.
create or replace function public.registrar_clic(p_envio uuid, p_destino text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_destino in ('pagar', 'entrar') and exists (select 1 from public.envios where id = p_envio) then
    insert into public.clics (envio_id, destino) values (p_envio, p_destino);
  end if;
end $$;

revoke all on function public.socias_lista(), public.socias_agregar(text, boolean, text), public.socias_habilitar(text),
  public.registrar_envio(text, text), public.cerrar_envio(uuid, text, text, text), public.registrar_clic(uuid, text) from public, anon, authenticated;
grant execute on function public.socias_lista(), public.socias_agregar(text, boolean, text), public.socias_habilitar(text),
  public.registrar_envio(text, text), public.cerrar_envio(uuid, text, text, text) to authenticated;
grant execute on function public.registrar_clic(uuid, text) to anon, authenticated;
