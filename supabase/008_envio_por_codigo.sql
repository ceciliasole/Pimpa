-- Pimpa: el mail automático "listo" cambia el precio según tenga código o no, y no se manda a profesionales. (8 nov 2026)
-- auto_datos(): devuelve cupón y si es profesional para un envío automático en curso.
-- waitlist_auto_listo(): ahora saltea a las profesionales (plan propio, se les escribe a mano).
-- Ver el cuerpo completo de ambas funciones en la migración "envio_automatico_precio_por_codigo" aplicada en Supabase.
create or replace function public.auto_datos(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r jsonb;
begin
  select jsonb_build_object('cupon', w.cupon, 'es_profesional', w.es_profesional) into r
    from public.envios e join public.waitlist w on w.email = e.email
   where e.id = p_id and e.enviado_por = 'auto' and e.estado = 'enviando';
  return r;
end $$;
revoke all on function public.auto_datos(uuid) from public;
grant execute on function public.auto_datos(uuid) to anon, authenticated;
-- (waitlist_auto_listo: igual que en 007 pero con "if new.es_profesional then return new; end if;" al principio)
