-- Pimpa: estados claros en /socias + orden fijo. (10 nov 2026)
-- Mismas columnas que antes (CREATE OR REPLACE), cambia cómo se calcula "estado" y el orden.
-- Estados:
--   equipo               socias (founder/cofounder) y Caro, Fati: acceso permanente, no pagan
--   activa               tiene un pago acreditado y su acceso está vigente
--   prueba               acceso vigente SIN pago acreditado (cupón de regalo o habilitada a mano)
--   vencida              tuvo acceso y venció
--   pago_sin_completar   empezó una orden en Mercado Pago y no la completó
--   entro                hizo login pero no tiene acceso ni empezó a pagar
--   prelanzamiento       se anotó antes del aviso "Ahora es directo" (cuando todavía no se podía pagar)
--   anotada              se anotó después de ese aviso (ya podía pagar) y no pagó
-- Orden: por orden de entrada (la más antigua primero); al final, siempre: Caro, Fati, Jose y Cecilia (última).
-- (Aplicada en Supabase como migración "estados_claros".)

create or replace function public.socias_estado()
returns table(email text, es_profesional boolean, cupon text, anotada timestamptz, rol text, habilitada boolean, estado text,
              entradas integer, ultimo_ingreso timestamptz, mails integer, ultimo_mail text, ultimo_mail_en timestamptz,
              mail_error boolean, pago_iniciado timestamptz, celular text, vence timestamptz, plan text)
language plpgsql stable security definer set search_path to 'public' as $$
declare
  fin_pre timestamptz := (select min(v.creado) from public.envios v where v.plantilla = 'aviso');
  fijas text[] := array['carorebora@gmail.com', 'fatyugarte22@gmail.com', 'ramosjosefin@gmail.com', 'cecilia.sole@gmail.com'];
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
      (a.email is not null) as hab, w.celular as cel, a.vence as venc,
      (a.vence is not null and a.vence <= now()) as vencida,
      array_position(fijas, b.e) as pos,
      exists (select 1 from public.pagos p where p.email = b.e and p.estado = 'pagado') as pago_ok,
      (select p.plan from public.pagos p where p.email = b.e and p.estado = 'pagado' order by p.pagado_en desc limit 1) as plan_pag,
      (select max(u.last_sign_in_at) from auth.users u where lower(u.email) = b.e) as ult_login,
      (select count(*)::int from public.ingresos i where i.email = b.e) as nent,
      (select max(i.creado) from public.ingresos i where i.email = b.e) as ult_ing,
      exists (select 1 from auth.users u where lower(u.email) = b.e) as entro,
      (select max(p.creado) from public.pagos p where p.email = b.e and p.estado = 'pendiente' and p.order_id is not null
          and (a.email is null or (a.vence is not null and a.vence <= now()))) as pago_ini,
      (select count(*)::int from public.envios v where v.email = b.e and v.estado in ('enviado','enviando','pendiente')) as nm,
      (select v.plantilla from public.envios v where v.email = b.e order by v.creado desc limit 1) as um,
      (select max(v.creado) from public.envios v where v.email = b.e) as um_en,
      exists (select 1 from public.envios v where v.email = b.e and v.estado = 'error') as merr,
      least(w.created_at, a.created_at, (select min(u.created_at) from auth.users u where lower(u.email) = b.e),
            (select min(p.creado) from public.pagos p where p.email = b.e)) as primera
    from base b
    left join public.waitlist w on w.email = b.e
    left join public.allowed_emails a on a.email = b.e
  )
  select x.e, coalesce(x.prof, false), x.cup, x.anot, x.rl, (x.hab and not x.vencida),
    case when x.rl in ('founder', 'cofounder') or x.pos is not null then 'equipo'
         when x.hab and x.vencida then 'vencida'
         when x.hab and x.pago_ok then 'activa'
         when x.hab then 'prueba'
         when x.pago_ini is not null then 'pago_sin_completar'
         when x.entro then 'entro'
         when x.anot is not null and fin_pre is not null and x.anot < fin_pre then 'prelanzamiento'
         else 'anotada' end,
    x.nent,
    greatest(x.ult_login, x.ult_ing),
    x.nm, x.um, x.um_en, x.merr, x.pago_ini, x.cel, x.venc, x.plan_pag
  from x
  order by (x.pos is not null), x.pos, x.primera asc nulls last, x.e;
end $$;

revoke all on function public.socias_estado() from public, anon;
grant execute on function public.socias_estado() to authenticated;
