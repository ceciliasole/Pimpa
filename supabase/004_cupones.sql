-- Pimpa: cupones de descuento con dígito verificador y atribución a la embajadora.
-- Pegar una sola vez en Supabase > SQL Editor > New query > Run. Se puede correr más de una vez sin problema.
--
-- Cómo funciona:
--  * Cada embajadora (o la propia Pimpa, para promos) tiene un cupón tipo FATI-4: la base (FATI) más un dígito verificador.
--    El dígito sirve para frenar errores de tipeo y adivinanzas al azar; NO vuelve secreto el código.
--  * La familia escribe el cupón en la lista de espera. Queda guardado en waitlist.cupon.
--  * Al habilitarla (función habilitar) el cupón pasa a allowed_emails.cupon, y de ahí sale la comisión de la embajadora.
--  * Los porcentajes de descuento y de comisión viven en la tabla coupons: se cambian con un UPDATE, sin tocar código.

-- 1) Dígito verificador -------------------------------------------------------------------------
-- Letras valen A=10 ... Z=35, números valen lo que son. Pesos 1,3,7,9 repetidos; resultado = suma mod 10.
create or replace function public.cupon_digito(p_base text)
returns int
language plpgsql immutable
as $$
declare
  s text := upper(coalesce(p_base, ''));
  pesos int[] := array[1,3,7,9];
  i int; c text; v int; tot int := 0;
begin
  for i in 1..length(s) loop
    c := substr(s, i, 1);
    v := case when c between '0' and '9' then ascii(c) - 48 else ascii(c) - 55 end;
    tot := tot + v * pesos[((i - 1) % 4) + 1];
  end loop;
  return tot % 10;
end $$;

-- Devuelve el cupón en formato BASE-D si está bien escrito y el dígito coincide; si no, null.
-- Acepta minúsculas, espacios y guiones de más ("fati 4", "FATI-4", "fati4").
create or replace function public.cupon_normalizar(p_codigo text)
returns text
language plpgsql immutable
as $$
declare
  s text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
  base text;
begin
  if length(s) < 4 or length(s) > 13 then return null; end if;
  base := left(s, length(s) - 1);
  if right(s, 1) <> public.cupon_digito(base)::text then return null; end if;
  return base || '-' || right(s, 1);
end $$;

-- 2) Tabla de cupones ---------------------------------------------------------------------------
create table if not exists public.coupons (
  codigo          text primary key check (codigo = upper(codigo) and codigo = public.cupon_normalizar(codigo)),
  tipo            text not null default 'embajadora' check (tipo in ('embajadora', 'promo')),
  titular_nombre  text,
  titular_email   text check (titular_email is null or titular_email = lower(titular_email)),
  descuento_pct   int  not null check (descuento_pct between 1 and 100),
  descuento_meses int  not null default 12 check (descuento_meses > 0),
  comision_pct    numeric(5,2) not null default 0 check (comision_pct between 0 and 100),
  madre_codigo    text references public.coupons (codigo),
  activo          boolean not null default true,
  vence           date,
  nota            text,
  created_at      timestamptz not null default now()
);

alter table public.coupons enable row level security;
revoke all on public.coupons from anon, authenticated;
-- Sin políticas: la web nunca lee la tabla. Solo se consulta por validar_cupon().

-- 3) Dónde queda guardado el cupón de cada persona -------------------------------------------------
alter table public.waitlist       add column if not exists cupon text references public.coupons (codigo);
alter table public.allowed_emails add column if not exists cupon text references public.coupons (codigo);

-- La web ya no puede escribir waitlist.cupon directo: solo por anotarse(), que lo valida.
revoke insert on public.waitlist from anon, authenticated;
grant insert (email, es_profesional) on public.waitlist to anon, authenticated;

-- 4) Crear cupones (solo desde el SQL Editor) ------------------------------------------------------
-- Ejemplo: select public.crear_cupon('MARGA', 'Marga Pérez', 'marga@mail.com', 20, 12, 10, 'FATI-4');
create or replace function public.crear_cupon(
  p_base text, p_titular text, p_email text, p_pct int,
  p_meses int default 12, p_comision numeric default 10, p_madre text default null,
  p_tipo text default 'embajadora'
)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  b text := upper(trim(coalesce(p_base, '')));
  k text;
  m text := null;
begin
  if b !~ '^[A-Z0-9]{3,12}$' then
    raise exception 'La base del cupón debe tener entre 3 y 12 letras o números, sin espacios ni tildes.';
  end if;
  k := b || '-' || public.cupon_digito(b)::text;
  if p_madre is not null then
    m := public.cupon_normalizar(p_madre);
    if m is null or not exists (select 1 from public.coupons where codigo = m) then
      raise exception 'El cupón madre % no existe.', p_madre;
    end if;
  end if;
  insert into public.coupons (codigo, tipo, titular_nombre, titular_email, descuento_pct, descuento_meses, comision_pct, madre_codigo)
  values (k, p_tipo, p_titular, lower(trim(p_email)), p_pct, p_meses, p_comision, m)
  on conflict (codigo) do nothing;
  return k;
end $$;
revoke all on function public.crear_cupon(text, text, text, int, int, numeric, text, text) from public, anon, authenticated;

-- 5) Validar un cupón desde la web ----------------------------------------------------------------
-- Devuelve solo si es válido y cuánto descuenta; no revela a quién pertenece.
create or replace function public.validar_cupon(p_codigo text)
returns jsonb
language plpgsql stable security definer
set search_path = public
as $$
declare
  k text := public.cupon_normalizar(p_codigo);
  c public.coupons;
begin
  if k is null then return jsonb_build_object('valido', false); end if;
  select * into c from public.coupons
   where codigo = k and activo and (vence is null or vence >= current_date);
  if not found then return jsonb_build_object('valido', false); end if;
  return jsonb_build_object('valido', true, 'codigo', c.codigo,
                            'descuento_pct', c.descuento_pct, 'descuento_meses', c.descuento_meses);
end $$;
revoke all on function public.validar_cupon(text) from public;
grant execute on function public.validar_cupon(text) to anon, authenticated;

-- 6) Anotarse en la lista de espera, con cupón opcional ------------------------------------------
-- Si el mail ya estaba anotado, le suma el cupón solo si todavía no tenía uno (nadie le pisa uno existente).
create or replace function public.anotarse(p_email text, p_profesional boolean default false, p_cupon text default null)
returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  e text := lower(trim(coalesce(p_email, '')));
  k text := null;
  v jsonb;
begin
  if p_cupon is not null and length(trim(p_cupon)) > 0 then
    v := public.validar_cupon(p_cupon);
    if not coalesce((v ->> 'valido')::boolean, false) then
      return jsonb_build_object('ok', false, 'motivo', 'cupon_invalido');
    end if;
    k := v ->> 'codigo';
  end if;
  insert into public.waitlist (email, es_profesional, cupon)
  values (e, coalesce(p_profesional, false), k)
  on conflict (email) do update
    set cupon = coalesce(public.waitlist.cupon, excluded.cupon),
        es_profesional = public.waitlist.es_profesional or excluded.es_profesional;
  return jsonb_build_object('ok', true, 'cupon', k);
end $$;
revoke all on function public.anotarse(text, boolean, text) from public;
grant execute on function public.anotarse(text, boolean, text) to anon, authenticated;

-- 7) Habilitar a alguien que ya pagó (solo desde el SQL Editor) -------------------------------------
-- Ejemplo: select public.habilitar('familia@gmail.com', 'Familia Pérez');
-- Copia el cupón que dejó en la lista de espera para no perder a quién la trajo.
create or replace function public.habilitar(p_email text, p_nombre text default null)
returns text
language plpgsql security definer
set search_path = public
as $$
declare
  e text := lower(trim(p_email));
  w public.waitlist;
begin
  select * into w from public.waitlist where email = e;
  insert into public.allowed_emails (email, nombre, cupon)
  values (e, p_nombre, w.cupon)
  on conflict (email) do update
    set cupon  = coalesce(public.allowed_emails.cupon, excluded.cupon),
        nombre = coalesce(public.allowed_emails.nombre, excluded.nombre);
  return e || case when w.cupon is not null then ' (cupón ' || w.cupon || ')' else ' (sin cupón)' end;
end $$;
revoke all on function public.habilitar(text, text) from public, anon, authenticated;

-- 8) Resumen por cupón (mirar desde Table Editor > cupones_resumen) ---------------------------------
create or replace view public.cupones_resumen with (security_invoker = true) as
select c.codigo, c.titular_nombre, c.tipo, c.descuento_pct, c.descuento_meses, c.comision_pct, c.madre_codigo, c.activo,
       (select count(*) from public.waitlist w where w.cupon = c.codigo)       as anotadas,
       (select count(*) from public.allowed_emails a where a.cupon = c.codigo) as habilitadas
from public.coupons c
order by habilitadas desc, anotadas desc, c.codigo;
revoke all on public.cupones_resumen from anon, authenticated;

-- 9) Cupones iniciales ------------------------------------------------------------------------------
-- Descuento y comisión son valores provisorios (ver README): se cambian con
--   update public.coupons set descuento_pct = 25, comision_pct = 12 where codigo = 'FATI-4';
select public.crear_cupon('FATI', 'Fatima Ugarte', 'fatyugarte22@gmail.com', 20, 12, 10, null, 'embajadora');
select public.crear_cupon('JOSE', 'Jose', 'ramosjosefin@gmail.com', 20, 12, 0, null, 'promo');
