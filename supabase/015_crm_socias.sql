-- Pimpa: panel /socias como CRM. (10 nov 2026)
-- Funciones nuevas, todas solo para socias (founder/cofounder). Las socias nunca se pueden deshabilitar ni eliminar.
-- (Aplicada en Supabase como migración "crm_socias".)

-- Ficha de una persona: acceso, lista de espera, perfil, pagos, mails con sus clics e ingresos.
create or replace function public.socias_ficha(p_email text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare e text := lower(trim(p_email));
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  return jsonb_build_object(
    'email', e,
    'waitlist', (select to_jsonb(w) from public.waitlist w where w.email = e),
    'acceso',   (select to_jsonb(a) from public.allowed_emails a where a.email = e),
    'perfil',   (select to_jsonb(f) from public.perfiles f where f.email = e),
    'pagos', coalesce((select jsonb_agg(jsonb_build_object('plan', p.plan, 'monto', p.monto, 'estado', p.estado,
                'cupon', p.cupon, 'creado', p.creado, 'pagado_en', p.pagado_en) order by p.creado desc)
              from public.pagos p where p.email = e), '[]'::jsonb),
    'envios', coalesce((select jsonb_agg(jsonb_build_object('plantilla', v.plantilla, 'estado', v.estado, 'creado', v.creado,
                'error', v.error, 'enviado_por', v.enviado_por,
                'clics', coalesce((select jsonb_agg(jsonb_build_object('destino', c.destino, 'creado', c.creado) order by c.creado)
                                   from public.clics c where c.envio_id = v.id), '[]'::jsonb)) order by v.creado desc)
              from public.envios v where v.email = e), '[]'::jsonb),
    'ingresos', jsonb_build_object('n', (select count(*) from public.ingresos i where i.email = e),
                                   'ultimo', (select max(i.creado) from public.ingresos i where i.email = e)),
    'login', (select max(u.last_sign_in_at) from auth.users u where lower(u.email) = e)
  );
end $$;

-- Habilitar a mano con rol y vencimiento (p_vence null = sin vencimiento). No toca a las socias.
create or replace function public.socias_habilitar2(p_email text, p_vence timestamptz default null, p_rol text default 'familia')
returns text language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(p_email));
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'mail inválido'; end if;
  if p_rol not in ('familia', 'educador') then raise exception 'rol inválido'; end if;
  if exists (select 1 from public.allowed_emails a where a.email = e and a.rol in ('founder', 'cofounder')) then
    raise exception 'es socia: ya tiene acceso completo';
  end if;
  insert into public.allowed_emails (email, rol, cupon, vence)
  values (e, p_rol, (select w.cupon from public.waitlist w where w.email = e), p_vence)
  on conflict (email) do update
    set rol = excluded.rol, vence = excluded.vence,
        cupon = coalesce(public.allowed_emails.cupon, excluded.cupon);
  return e;
end $$;

-- Deshabilitar: quita el acceso (la persona queda en la lista, sin acceso).
create or replace function public.socias_deshabilitar(p_email text)
returns text language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(p_email));
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  if exists (select 1 from public.allowed_emails a where a.email = e and a.rol in ('founder', 'cofounder')) then
    raise exception 'es socia: no se puede deshabilitar';
  end if;
  delete from public.allowed_emails where email = e;
  return e;
end $$;

-- Cambiar el vencimiento de una cuenta habilitada (null = sin vencimiento).
create or replace function public.socias_vencimiento(p_email text, p_vence timestamptz)
returns text language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(p_email)); n int;
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  update public.allowed_emails set vence = p_vence
   where email = e and rol not in ('founder', 'cofounder');
  get diagnostics n = row_count;
  if n = 0 then raise exception 'no está habilitada (o es socia)'; end if;
  return e;
end $$;

-- Eliminar a una persona de todo (cuentas de prueba). No elimina socias ni a quien tenga pagos acreditados.
create or replace function public.socias_eliminar(p_email text)
returns text language plpgsql security definer set search_path = public as $$
declare e text := lower(trim(p_email));
begin
  if not public.es_socia() then raise exception 'sin permiso'; end if;
  if e = lower(coalesce(auth.jwt() ->> 'email', '')) then raise exception 'no podés eliminar tu propia cuenta'; end if;
  if exists (select 1 from public.allowed_emails a where a.email = e and a.rol in ('founder', 'cofounder')) then
    raise exception 'es socia: no se puede eliminar';
  end if;
  if exists (select 1 from public.pagos p where p.email = e and p.estado = 'pagado') then
    raise exception 'tiene pagos acreditados: no se elimina (podés deshabilitarla)';
  end if;
  delete from public.envios   where email = e;   -- los clics se borran en cascada
  delete from public.pagos    where email = e;
  delete from public.ingresos where email = e;
  delete from public.perfiles where email = e;
  delete from public.waitlist where email = e;
  delete from public.allowed_emails where email = e;
  delete from auth.users where lower(email) = e;
  return e;
end $$;

revoke all on function public.socias_ficha(text), public.socias_habilitar2(text, timestamptz, text),
  public.socias_deshabilitar(text), public.socias_vencimiento(text, timestamptz), public.socias_eliminar(text)
  from public, anon;
grant execute on function public.socias_ficha(text), public.socias_habilitar2(text, timestamptz, text),
  public.socias_deshabilitar(text), public.socias_vencimiento(text, timestamptz), public.socias_eliminar(text)
  to authenticated;
