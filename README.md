# Pimpa

App de ejercicios de lectoescritura y conciencia fonológica para chicos, pensada para familias y uso en casa. Página estática de una sola pieza (index.html), sin dependencias ni paso de compilación.

## Publicación

Sitio: https://pimpa.impactese.com

Hosting: proyecto `pimpa` en Vercel, conectado a este repo. Cada commit a la rama `claude/jose-silabas-sonidos` se publica solo en producción.

DNS: CNAME `pimpa` en GoDaddy apuntando al destino que muestra Vercel (Project → Settings → Domains).

Para actualizar la app: reemplazar `index.html` y hacer commit.

`vercel.json` pide a los buscadores que no indexen el sitio (X-Robots-Tag: noindex). Borrá ese bloque cuando quieran que aparezca en Google.
