-- Aplicada como migración "envios_plantilla_invitacion".
-- Agrega la plantilla 'invitacion' (invitación de prueba para educadoras) a los mails que registra /socias.
alter table public.envios drop constraint if exists envios_plantilla_check;
alter table public.envios add constraint envios_plantilla_check check (plantilla in ('listo','confirmado','aviso','carrito','invitacion'));
