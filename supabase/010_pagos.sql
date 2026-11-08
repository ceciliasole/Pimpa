-- Pimpa: checkout con Mercado Pago (Orders API). (8 nov 2026)
-- Las funciones de /api (checkout y webhook) llaman estas funciones con la clave publicable y un secreto
-- compartido (PAGOS_SECRET en Vercel). La base solo guarda el sha256 del secreto en pagos_config.
-- Sin el secreto, nadie puede crear pagos ni habilitar cuentas.
create table if not exists public.pagos_config (
  id boolean primary key default true check (id),
  secret_hash text not null
);
alter table public.pagos_config enable row level security;

create table if not exists public.pagos (
  id uuid primary key default gen_random_uuid(),
  email text not null check (email = lower(email)),
  cupon text references public.coupons(codigo),
  plan text not null default 'mensual',
  monto numeric(12,2) not null check (monto > 0),
  estado text not null default 'pendiente' check (estado in ('pendiente','pagado','error')),
  order_id text,
  creado timestamptz not null default now(),
  pagado_en timestamptz,
  raw jsonb
);
create unique index if not exists pagos_order_id_uq on public.pagos(order_id) where order_id is not null;
create index if not exists pagos_email_idx on public.pagos(email);
alter table public.pagos enable row level security;
-- Sin políticas: la web nunca lee ni escribe estas tablas directo; solo las funciones de abajo (security definer).

create or replace function public.pagos_secreto_ok(p_secret text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.pagos_config
                  where secret_hash = encode(sha256(convert_to(coalesce(p_secret, ''), 'UTF8')), 'hex'))
$$;

create or replace function public.pago_crear(p_secret text, p_email text, p_cupon text, p_monto numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare i uuid; k text := null;
begin
  if not public.pagos_secreto_ok(p_secret) then raise exception 'sin permiso'; end if;
  if p_cupon is not null and exists (select 1 from public.coupons where codigo = p_cupon) then k := p_cupon; end if;
  insert into public.pagos (email, cupon, monto) values (lower(trim(p_email)), k, p_monto) returning id into i;
  return i;
end $$;

create or replace function public.pago_orden(p_secret text, p_id uuid, p_order_id text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.pagos_secreto_ok(p_secret) then raise exception 'sin permiso'; end if;
  update public.pagos set order_id = p_order_id where id = p_id and estado = 'pendiente';
end $$;

create or replace function public.pago_datos(p_secret text, p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  if not public.pagos_secreto_ok(p_secret) then raise exception 'sin permiso'; end if;
  select jsonb_build_object('email', email, 'monto', monto, 'estado', estado, 'cupon', cupon) into r
    from public.pagos where id = p_id;
  return r;
end $$;

-- Marca el pago como pagado, habilita la cuenta (con el cupón) y devuelve el mail. Idempotente: si ya estaba pagado, nuevo = false.
create or replace function public.pago_aprobado(p_secret text, p_id uuid, p_order_id text, p_monto numeric, p_raw jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare p public.pagos;
begin
  if not public.pagos_secreto_ok(p_secret) then raise exception 'sin permiso'; end if;
  select * into p from public.pagos where id = p_id for update;
  if not found then return null; end if;
  if p.estado = 'pagado' then return jsonb_build_object('email', p.email, 'nuevo', false); end if;
  if p_monto is null or p_monto < p.monto then raise exception 'monto menor al esperado'; end if;
  update public.pagos set estado = 'pagado', pagado_en = now(), order_id = coalesce(p_order_id, order_id), raw = p_raw where id = p_id;
  perform public.habilitar(p.email, null);
  update public.allowed_emails set cupon = p.cupon where email = p.email and cupon is null and p.cupon is not null;
  return jsonb_build_object('email', p.email, 'nuevo', true);
end $$;

-- Registra el envío automático del mail "confirmado" (queda a la vista en /socias) y devuelve su id.
create or replace function public.pago_envio_confirmado(p_secret text, p_email text)
returns uuid language plpgsql security definer set search_path = public as $$
declare i uuid;
begin
  if not public.pagos_secreto_ok(p_secret) then raise exception 'sin permiso'; end if;
  insert into public.envios (email, plantilla, enviado_por, estado) values (lower(trim(p_email)), 'confirmado', 'auto', 'enviando') returning id into i;
  return i;
end $$;

create or replace function public.pago_envio_cerrar(p_secret text, p_id uuid, p_estado text, p_resend_id text, p_error text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.pagos_secreto_ok(p_secret) then raise exception 'sin permiso'; end if;
  if p_estado in ('enviado','error') then
    update public.envios set estado = p_estado, resend_id = p_resend_id, error = left(p_error, 500)
     where id = p_id and enviado_por = 'auto' and plantilla = 'confirmado';
  end if;
end $$;

revoke all on function public.pagos_secreto_ok(text) from public, anon, authenticated;
revoke all on function public.pago_crear(text,text,text,numeric) from public;
revoke all on function public.pago_orden(text,uuid,text) from public;
revoke all on function public.pago_datos(text,uuid) from public;
revoke all on function public.pago_aprobado(text,uuid,text,numeric,jsonb) from public;
revoke all on function public.pago_envio_confirmado(text,text) from public;
revoke all on function public.pago_envio_cerrar(text,uuid,text,text,text) from public;
grant execute on function public.pago_crear(text,text,text,numeric) to anon, authenticated;
grant execute on function public.pago_orden(text,uuid,text) to anon, authenticated;
grant execute on function public.pago_datos(text,uuid) to anon, authenticated;
grant execute on function public.pago_aprobado(text,uuid,text,numeric,jsonb) to anon, authenticated;
grant execute on function public.pago_envio_confirmado(text,text) to anon, authenticated;
grant execute on function public.pago_envio_cerrar(text,uuid,text,text,text) to anon, authenticated;
-- Después de aplicar: insert into public.pagos_config (secret_hash) values ('<sha256 del secreto de Vercel PAGOS_SECRET>');
