-- Vigencia de los planes (9 nov 2026). (Aplicado directo en Supabase como migración vencimiento_de_planes.)
-- allowed_emails.vence: null = no vence (fundadoras, educadoras, habilitadas a mano). Al pagar se suma 1, 3 o 12 meses
-- (sobre el vencimiento actual si todavía no venció). Vencida = la app no la ve habilitada (is_allowed y la política
-- "ver solo mi fila" filtran por vence) y le muestra "Activá tu cuenta" para renovar. socias_estado suma el estado "vencida", vence y plan.
-- El SQL completo (is_allowed, política, pago_aprobado y socias_estado) está en la migración aplicada en Supabase.
alter table public.allowed_emails add column if not exists vence timestamptz;
