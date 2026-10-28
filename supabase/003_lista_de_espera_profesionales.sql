-- Pimpa: marca en la lista de espera si quien se anota es profesional (psicopedagogía / educación).
-- Pegar una sola vez en Supabase > SQL Editor > New query > Run. Se puede correr más de una vez sin problema.

alter table public.waitlist
  add column if not exists es_profesional boolean not null default false;
