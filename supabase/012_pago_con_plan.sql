-- Checkout con plan elegido: 1 mes, 3 meses o anual. (Aplicado directo en Supabase como migración pago_crear_con_plan.)
drop function if exists public.pago_crear(text, text, text, numeric);
create or replace function public.pago_crear(p_secret text, p_email text, p_cupon text, p_monto numeric, p_plan text default 'mensual')
returns uuid language plpgsql security definer set search_path = public as $$
declare i uuid; k text := null; pl text := case when p_plan in ('mensual','trimestral','anual') then p_plan else 'mensual' end;
begin
  if not public.pagos_secreto_ok(p_secret) then raise exception 'sin permiso'; end if;
  if p_cupon is not null and exists (select 1 from public.coupons where codigo = p_cupon) then k := p_cupon; end if;
  insert into public.pagos (email, cupon, plan, monto) values (lower(trim(p_email)), k, pl, p_monto) returning id into i;
  return i;
end $$;
