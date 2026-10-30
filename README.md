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

## Lista de espera

La pantalla de ingreso tiene un campo para dejar el mail de Gmail (solo se aceptan cuentas `@gmail.com`). Los mails se guardan en la tabla `waitlist` de Supabase; se crea una sola vez con `supabase/002_lista_de_espera.sql` (SQL Editor). La web solo puede insertar: la lista se mira desde Supabase > Table Editor > waitlist.

Para habilitar a alguien que ya pagó, se agrega su mail a `allowed_emails` (el SQL de ejemplo está al final de `002_lista_de_espera.sql`).

El formulario tiene un casillero opcional "Soy profesional de la psicopedagogía o la educación…". Si lo tildan, se guarda `es_profesional = true` en `waitlist` (se agrega con `supabase/003_lista_de_espera_profesionales.sql`). Si no lo tildan, el valor queda en `false`. La landing sigue pensada para familias.

## Audios

Las grabaciones de Jose son archivos sueltos en `audio/` (mp3 mono), no van dentro del `index.html`. El nombre lleva una huella del contenido (`pal_camion.a1b2c3d4.mp3`): al regrabar un audio sale un archivo nuevo y el navegador no usa el viejo (cache de un año). En `index.html` los diccionarios (`SAUD` sílabas, `WAUD`/`PALAUD` palabras, números, días y frases, `CAUD` sonidos, `LNAUD` nombres de letras, etc.) apuntan a esas rutas. `warmAudio()` los precarga en segundo plano.

Para sumar una tanda nueva: convertir los WAV a mp3, guardarlos en `audio/` con huella y agregar la clave (el texto en minúsculas, tal como lo dice la app) al diccionario que corresponda. Si hay dos tomas de lo mismo, vale la más nueva.
