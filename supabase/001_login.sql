-- Pimpa: lista de mails autorizados para entrar con Google.
-- Pegar una sola vez en Supabase > SQL Editor > New query > Run.

create table if not exists public.allowed_emails (
  email      text primary key check (email = lower(email)),
  nombre     text,
  created_at timestamptz not null default now()
);

alter table public.allowed_emails enable row level security;

-- Cada persona logueada solo puede ver su propia fila (para saber si está autorizada).
-- No hay políticas de insert/update/delete: la lista solo se cambia desde el SQL Editor.
drop policy if exists "ver solo mi fila" on public.allowed_emails;
create policy "ver solo mi fila" on public.allowed_emails
  for select to authenticated
  using (email = lower(auth.jwt() ->> 'email'));

-- Para usar más adelante en las reglas de las tablas con datos (progreso, chicos, etc.).
create or replace function public.is_allowed()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.allowed_emails
    where email = lower(auth.jwt() ->> 'email')
  );
$$;
revoke all on function public.is_allowed() from public, anon;
grant execute on function public.is_allowed() to authenticated;

insert into public.allowed_emails (email, nombre) values
  ('cecilia.sole@gmail.com',  'Cecilia'),
  ('ramosjosefin@gmail.com',  'Jose'),
  ('fatyugarte22@gmail.com',  'Fati')
on conflict (email) do nothing;
