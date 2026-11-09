-- Panel de socias con un solo estado por persona + contador de ingresos.
-- (Aplicado directo en Supabase como migración panel_estados_ingresos.)

create table if not exists public.ingresos (
  id     bigserial primary key,
  email  text not null check (email = lower(email)),
  creado timestamptz not null default now()
);
create index if not exists ingresos_email_idx on public.ingresos (email);
alter table public.ingresos enable row level security;
revoke all on public.ingresos from anon, authenticated;

-- La app lo llama una vez por visita (pestaña) de una persona con sesión. Solo guarda el mail de su propio token.
create or replace function public.registrar_ingreso()
returns void language plpgsql security definer set search_path = public as $$
declare m text := lower(auth.jwt() ->> 'email');
begin
  if m is null or m = '' then return; end if;
  insert into public.ingresos (email) values (m);
end $$;
revoke all on function public.registrar_ingreso() from public, anon;
grant execute on function public.registrar_ingreso() to authenticated;

-- Estados: activa (habilitada) > pago_sin_completar (orden en Mercado Pago pendiente) > entro (hizo login) > anotada.
create or replace function public.socias_estado()
returns table (email text, es_profesional boolean, cupon text, anotada timestamptz, rol text, habilitada boolean,
               estado text, entradas int, ultimo_ingreso timestamptz, mails int, ultimo_mail text, ultimo_mail_en timestamptz,
               mail_error boolean, pago_iniciado timestamptz, celular text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  return query
  with base as (
    select w.email as e from public.waitlist w
    union select a.email from public.allowed_emails a
    union select lower(u.email) from auth.users u where u.email is not null
    union select p.email from public.pagos p
  ), x as (
    select b.e,
      w.es_profesional as prof, coalesce(w.cupon, a.cupon) as cup, w.created_at as anot, a.rol as rl,
      (a.email is not null) as hab, w.celular as cel,
      (select max(u.last_sign_in_at) from auth.users u where lower(u.email) = b.e) as ult_login,
      (select count(*)::int from public.ingresos i where i.email = b.e) as nent,
      (select max(i.creado) from public.ingresos i where i.email = b.e) as ult_ing,
      exists (select 1 from auth.users u where lower(u.email) = b.e) as entro,
      (select max(p.creado) from public.pagos p where p.email = b.e and p.estado = 'pendiente' and p.order_id is not null) as pago_ini,
      (select count(*)::int from public.envios v where v.email = b.e and v.estado in ('enviado','enviando','pendiente')) as nm,
      (select v.plantilla from public.envios v where v.email = b.e order by v.creado desc limit 1) as um,
      (select max(v.creado) from public.envios v where v.email = b.e) as um_en,
      exists (select 1 from public.envios v where v.email = b.e and v.estado = 'error') as merr
    from base b
    left join public.waitlist w on w.email = b.e
    left join public.allowed_emails a on a.email = b.e
  )
  select x.e, coalesce(x.prof, false), x.cup, x.anot, x.rl, x.hab,
    case when x.hab then 'activa'
         when x.pago_ini is not null then 'pago_sin_completar'
         when x.entro then 'entro'
         else 'anotada' end,
    x.nent,
    greatest(x.ult_login, x.ult_ing),
    x.nm, x.um, x.um_en, x.merr, x.pago_ini, x.cel
  from x
  order by case when x.hab then 3 when x.pago_ini is not null then 0 when x.entro then 1 else 2 end,
           coalesce(greatest(x.ult_login, x.ult_ing), x.anot) desc nulls last;
end $$;
revoke all on function public.socias_estado() from public, anon;
grant execute on function public.socias_estado() to authenticated;
