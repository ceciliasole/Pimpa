-- Pimpa: lista de espera (mails que dejan las familias en la pantalla de ingreso).
-- Pegar una sola vez en Supabase > SQL Editor > New query > Run.

create table if not exists public.waitlist (
  email      text primary key
             check (email = lower(email) and length(email) <= 120 and email ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+[.][a-z]{2,}$'),
  created_at timestamptz not null default now()
);

alter table public.waitlist enable row level security;

-- Cualquiera puede anotarse (insertar), pero nadie puede leer, cambiar ni borrar desde la web.
-- La lista se ve desde Supabase > Table Editor > waitlist.
revoke all on public.waitlist from anon, authenticated;
grant insert on public.waitlist to anon, authenticated;

drop policy if exists "anotarse en la lista" on public.waitlist;
create policy "anotarse en la lista" on public.waitlist
  for insert to anon, authenticated
  with check (true);

-- Para habilitar a quienes ya pagaron (cambiar los mails) y que puedan entrar con Google:
--   insert into public.allowed_emails (email)
--   select email from public.waitlist
--   where email in ('mail1@gmail.com', 'mail2@gmail.com')
--   on conflict (email) do nothing;
