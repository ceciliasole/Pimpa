-- Pimpa: cupones con código simple (FATI1, JOSE1) y descuentos nuevos (5 nov 2026).
-- Ya corrido en el proyecto `pimpa` (en tres pasos). Este archivo deja constancia de todo.
--
-- Qué cambia respecto de 004_cupones.sql:
--  * Se saca el dígito verificador y el guion: el código es la base + un número de versión (FATI1, JOSE1).
--    El número permite sumar otros descuentos con la misma persona (FATI2, JOSE2) sin tocar los anteriores.
--    Escribir solo "FATI" también sirve: se interpreta como FATI1.
--  * Descuento: 15% los primeros 3 meses del plan mensual, o 20% si elige el plan anual con código.
--    Fati y Jo ofrecen exactamente lo mismo; Fati solo cobra más comisión (8%, sobre lo que la familia efectivamente paga).
--  * validar_cupon también devuelve descuento_anual_pct.

-- 1) Descuento anual y 3 meses por defecto ----------------------------------------------------------
alter table public.coupons add column if not exists descuento_anual_pct integer not null default 20
  check (descuento_anual_pct between 1 and 100);
alter table public.coupons alter column descuento_meses set default 3;

-- 2) Código simple: sacar el check viejo (dependía del dígito verificador) ----------------------------
do $$
declare r record;
begin
  for r in select conname from pg_constraint
           where conrelid = 'public.coupons'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ilike '%cupon_normalizar%'
  loop
    execute format('alter table public.coupons drop constraint %I', r.conname);
  end loop;
end $$;

create or replace function public.cupon_normalizar(p_codigo text)
 returns text language plpgsql immutable set search_path to ''
as $function$
declare
  s text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if length(s) < 3 or length(s) > 13 then return null; end if;
  return s;
end $function$;

-- 3) Renombrar los cupones cargados y fijar descuentos y comisión ---------------------------------------
-- (falla sola si algún mail de waitlist o allowed_emails ya usaba el código viejo)
update public.coupons set codigo = 'FATI1' where codigo = 'FATI-0';
update public.coupons set codigo = 'JOSE1' where codigo = 'JOSE-3';
update public.coupons set descuento_pct = 15, descuento_meses = 3, descuento_anual_pct = 20
 where codigo in ('FATI1', 'JOSE1');
update public.coupons set comision_pct = 8 where codigo = 'FATI1';

alter table public.coupons add constraint coupons_codigo_check
  check (codigo = upper(codigo) and codigo ~ '^[A-Z0-9]{4,13}$');

-- 4) Validar: acepta el código exacto o, si falta el número, la versión 1 ---------------------------------
create or replace function public.validar_cupon(p_codigo text)
 returns jsonb language plpgsql stable security definer set search_path to 'public'
as $function$
declare
  k text := public.cupon_normalizar(p_codigo);
  c public.coupons;
begin
  if k is null then return jsonb_build_object('valido', false); end if;
  select * into c from public.coupons
   where codigo in (k, k || '1') and activo and (vence is null or vence >= current_date)
   order by (codigo = k) desc
   limit 1;
  if not found then return jsonb_build_object('valido', false); end if;
  return jsonb_build_object('valido', true, 'codigo', c.codigo,
                            'descuento_pct', c.descuento_pct, 'descuento_meses', c.descuento_meses,
                            'descuento_anual_pct', c.descuento_anual_pct);
end $function$;

-- 5) Crear cupones: select public.crear_cupon('MARGA', 'Marga Pérez', 'marga@mail.com', 15, 3, 10, 'FATI1');
--    (código con o sin número: 'MARGA' crea MARGA1; 'MARGA2' crea MARGA2)
create or replace function public.crear_cupon(p_base text, p_titular text, p_email text, p_pct integer, p_meses integer default 3, p_comision numeric default 10, p_madre text default null, p_tipo text default 'embajadora')
 returns text language plpgsql security definer set search_path to 'public'
as $function$
declare
  b text := upper(trim(coalesce(p_base, '')));
  k text;
  m text := null;
begin
  if b !~ '^[A-Z0-9]{3,12}$' then
    raise exception 'El código debe tener entre 3 y 12 letras o números, sin espacios, guiones ni tildes.';
  end if;
  k := case when b ~ '[0-9]$' then b else b || '1' end;
  if p_madre is not null then
    m := public.cupon_normalizar(p_madre);
    if m is not null and not exists (select 1 from public.coupons where codigo = m)
       and exists (select 1 from public.coupons where codigo = m || '1') then
      m := m || '1';
    end if;
    if m is null or not exists (select 1 from public.coupons where codigo = m) then
      raise exception 'El cupón madre % no existe.', p_madre;
    end if;
  end if;
  insert into public.coupons (codigo, tipo, titular_nombre, titular_email, descuento_pct, descuento_meses, comision_pct, madre_codigo)
  values (k, p_tipo, p_titular, lower(trim(p_email)), p_pct, p_meses, p_comision, m)
  on conflict (codigo) do nothing;
  return k;
end $function$;
