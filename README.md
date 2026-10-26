# Pimpa

App de ejercicios de lectoescritura y conciencia fonológica para chicos, pensada para familias y uso en casa. Página estática de una sola pieza (index.html), sin dependencias ni paso de compilación.

## Publicación

Sitio: https://pimpa.impactese.com

Hosting: proyecto `pimpa` en Vercel, conectado a este repo. Cada commit a la rama `claude/jose-silabas-sonidos` se publica solo en producción.

DNS: CNAME `pimpa` en GoDaddy apuntando al destino que muestra Vercel (Project → Settings → Domains).

Para actualizar la app: reemplazar `index.html` y hacer commit.

`vercel.json` pide a los buscadores que no indexen el sitio (X-Robots-Tag: noindex). Borrá ese bloque cuando quieran que aparezca en Google.

## Ingreso con Google

La app pide ingresar con Google (Supabase Auth, proyecto `pimpa` de la cuenta impactese). Entra solo quien figure en la tabla `allowed_emails`; para sumar a alguien se agrega una fila desde Supabase > SQL Editor (ver `supabase/001_login.sql`) y, mientras la pantalla de consentimiento de Google esté en modo Prueba, también como usuario de prueba en Google Cloud > Google Auth Platform > Público.

- La librería supabase-js está fija en `vendor/` (versión 2.45.4), sin CDN.
- Los perfiles de los chicos se guardan en el navegador, separados por cuenta (clave `silabas-y-sonidos-v2:<mail>`). Todavía no se sincronizan entre dispositivos.
- Hay que entrar por `pimpa.impactese.com`; otras direcciones no están en la lista de redirecciones de Supabase.
