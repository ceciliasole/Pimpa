-- Pimpa: mail "Tu lugar está listo" automático al anotarse en la lista de espera. (6 nov 2026)
-- Al insertarse un mail nuevo en waitlist, se crea un envío 'pendiente' y se avisa a /api/auto (por pg_net),
-- que manda el mail por Resend. Freno de emergencia y tope diario en auto_config.

create extension if not exists pg_net with schema extensions;

create table if not exists public.auto_config (
  id          boolean primary key default true check (id),
  activo      boolean not null default true,
  tope_diario int     not null default 30
);
insert into public.auto_config (id) values (true) on conflict do nothing;
alter table public.auto_config enable row level security;
revoke all on public.auto_config from anon, authenticated;

alter table public.envios drop constraint if exists envios_estado_check;
alter table public.envios add constraint envios_estado_check
  check (estado in ('pendiente', 'enviando', 'enviado', 'error'));

create or replace function public.waitlist_auto_listo() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
declare c public.auto_config; i uuid; n int;
begin
  begin
    select * into c from public.auto_config where id;
    if not coalesce(c.activo, false) then return new; end if;
    if exists (select 1 from public.allowed_emails where lower(email) = lower(new.email)) then return new; end if;
    if exists (select 1 from public.envios where email = lower(new.email) and plantilla = 'listo') then return new; end if;
    select count(*) into n from public.envios where enviado_por = 'auto' and creado > now() - interval '24 hours';
    if n >= c.tope_diario then return new; end if;
    insert into public.envios (email, plantilla, enviado_por, estado)
      values (lower(new.email), 'listo', 'auto', 'pendiente') returning id into i;
    perform net.http_post(
      url := 'https://pimpa.impactese.com/api/auto',
      headers := '{"Content-Type":"application/json"}'::jsonb,
      body := jsonb_build_object('e', i));
  exception when others then
    null; -- anotarse en la lista nunca tiene que fallar por esto
  end;
  return new;
end $$;
revoke all on function public.waitlist_auto_listo() from public, anon, authenticated;

drop trigger if exists waitlist_auto_listo on public.waitlist;
create trigger waitlist_auto_listo after insert on public.waitlist
  for each row execute function public.waitlist_auto_listo();

-- Lo usa /api/auto (sin login): toma un envío automático pendiente, una sola vez, y devuelve a quién mandarlo.
create or replace function public.auto_tomar(p_id uuid) returns text
language plpgsql security definer set search_path = public as $$
declare m text;
begin
  update public.envios set estado = 'enviando'
   where id = p_id and enviado_por = 'auto' and plantilla = 'listo' and estado = 'pendiente'
     and creado > now() - interval '2 hours'
  returning email into m;
  return m;
end $$;

create or replace function public.auto_cerrar(p_id uuid, p_estado text, p_resend_id text default null, p_error text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_estado in ('enviado', 'error') then
    update public.envios set estado = p_estado, resend_id = p_resend_id, error = left(p_error, 500)
     where id = p_id and enviado_por = 'auto' and estado = 'enviando';
  end if;
end $$;

revoke all on function public.auto_tomar(uuid), public.auto_cerrar(uuid, text, text, text) from public;
grant execute on function public.auto_tomar(uuid), public.auto_cerrar(uuid, text, text, text) to anon, authenticated;
