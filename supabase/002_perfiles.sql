-- Pimpa: perfiles de los chicos (apodo + progreso), uno por fila, separados por cuenta.
-- Pegar una sola vez en Supabase > SQL Editor > New query > Run.
-- Requiere haber corrido antes 001_login.sql (usa public.is_allowed()).

create table if not exists public.perfiles (
  owner      uuid        not null default auth.uid() references auth.users(id) on delete cascade,
  id         text        not null,
  alias      text        not null default '',
  data       jsonb       not null default '{}'::jsonb,
  deleted    boolean     not null default false,   -- borrado lógico: así el borrado llega a los otros dispositivos
  updated_at timestamptz not null default now(),
  primary key (owner, id)
);

alter table public.perfiles enable row level security;

-- Cada cuenta autorizada ve y modifica solo sus filas. No hay política de delete.
drop policy if exists "perfiles: ver los mios" on public.perfiles;
create policy "perfiles: ver los mios" on public.perfiles
  for select to authenticated
  using (owner = auth.uid() and public.is_allowed());

drop policy if exists "perfiles: crear los mios" on public.perfiles;
create policy "perfiles: crear los mios" on public.perfiles
  for insert to authenticated
  with check (owner = auth.uid() and public.is_allowed());

drop policy if exists "perfiles: editar los mios" on public.perfiles;
create policy "perfiles: editar los mios" on public.perfiles
  for update to authenticated
  using (owner = auth.uid() and public.is_allowed())
  with check (owner = auth.uid() and public.is_allowed());

revoke all on public.perfiles from anon;
grant select, insert, update on public.perfiles to authenticated;
