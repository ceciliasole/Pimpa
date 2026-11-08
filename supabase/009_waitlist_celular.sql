-- Celular opcional en la lista de espera (pantalla de gracias).
alter table public.waitlist add column if not exists celular text;
-- guardar_celular_lista(p_email, p_celular): solo dentro de las 2 h posteriores al alta.
-- socias_lista ahora devuelve también celular. (Aplicado directo en Supabase como migración waitlist_celular.)
