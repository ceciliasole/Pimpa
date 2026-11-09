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

La pantalla de ingreso tiene un campo para dejar el mail (se acepta cualquier mail válido; para entrar a la app hace falta una cuenta de Google). Los mails se guardan en la tabla `waitlist` de Supabase; se crea una sola vez con `supabase/002_lista_de_espera.sql` (SQL Editor). La web solo puede insertar: la lista se mira desde Supabase > Table Editor > waitlist.

Para habilitar a alguien que ya pagó: `select public.habilitar('mail@gmail.com', 'Nombre');` en el SQL Editor. Es mejor que insertar a mano en `allowed_emails` porque copia el cupón que la persona dejó en la lista de espera (ver Cupones).

El formulario tiene un casillero opcional "Soy profesional de la psicopedagogía o la educación…". Si lo tildan, se guarda `es_profesional = true` en `waitlist` (se agrega con `supabase/003_lista_de_espera_profesionales.sql`). Si no lo tildan, el valor queda en `false`. La landing sigue pensada para familias.

## Audios

Las grabaciones de Jose son archivos sueltos en `audio/` (mp3 mono), no van dentro del `index.html`. El nombre lleva una huella del contenido (`pal_camion.a1b2c3d4.mp3`): al regrabar un audio sale un archivo nuevo y el navegador no usa el viejo (cache de un año). En `index.html` los diccionarios (`SAUD` sílabas, `WAUD`/`PALAUD` palabras, números, días y frases, `CAUD` sonidos, `LNAUD` nombres de letras, etc.) apuntan a esas rutas. `warmAudio()` los precarga en segundo plano.

Para sumar una tanda nueva: convertir los WAV a mp3, guardarlos en `audio/` con huella y agregar la clave (el texto en minúsculas, tal como lo dice la app) al diccionario que corresponda. Si hay dos tomas de lo mismo, vale la más nueva.

Frases enteras de Jose (`FRFULL`): las preguntas de días (`fra_dia_*`, `fra_si_hoy_<día>_ayer|manana`), `¿Está …?` (`fra_esta_*`), `¿Quién se siente igual?` y las 15 situaciones de Emociones (`fra_sit_s01…s15`). Jose grabó "¿Qué día **será** mañana?", así que el texto de la app dice "será" (las piezas viejas de Cecilia con "es mañana" ya no se usan para esa pregunta). Las palabras de emociones sueltas (`emo_*`) están en `PALAUD`.

## Cupones de descuento

Se crearon con `supabase/004_cupones.sql` y se simplificaron con `supabase/005_cupones_simples.sql` (ya corridos en el proyecto `pimpa`). Cada cupón es una base más un número de versión, sin guion ni dígito verificador: `FATI1`, `JOSE1`. El número deja sumar otros descuentos con la misma persona (`FATI2`, `JOSE2`) sin tocar los anteriores. Escribir solo `FATI` también sirve y se toma como `FATI1`. El código no es secreto: es solo un descuento y una forma de atribuir quién trajo a la familia.

- Oferta con código (igual para Fati y para Jo): 15% los primeros 3 meses del plan mensual, o 20% si elige el plan anual. Sin código, el anual tiene 15% y el plan de 3 meses tiene 5% (constante `DESC_TRIMESTRAL` en `api/_mp.js` y `DTO_TRIM` en `index.html`; si cambia una, cambia la otra). En el plan de 3 meses el código se acumula sobre ese 5%: $57.000 sin código y $48.450 con código. Fati solo cobra más comisión (8% sobre lo que la familia efectivamente paga).
- La familia lo escribe en el campo opcional de la lista de espera, o entra por un link con el cupón puesto: `https://pimpa.impactese.com/?cupon=FATI1`. La web lo valida con `validar_cupon` y lo guarda con `anotarse` en `waitlist.cupon`. Si el mail ya estaba anotado, se le suma el cupón solo si todavía no tenía uno.
- `habilitar(mail)` pasa ese cupón a `allowed_emails.cupon`; de ahí sale la comisión de la embajadora.
- Ver cuántas anotó y cuántas se habilitaron por cupón: Supabase > Table Editor > vista `cupones_resumen`.
- Crear un cupón nuevo: `select public.crear_cupon('MARGA', 'Marga Pérez', 'marga@mail.com', 15, 3, 10, 'FATI1');` (código, titular, mail, % descuento mensual, meses de descuento, % comisión, cupón "madre" opcional). `MARGA` crea `MARGA1`.
- Cambiar valores: `update public.coupons set descuento_pct = 15, descuento_anual_pct = 20, comision_pct = 8 where codigo = 'FATI1';`. Apagar uno: `set activo = false`.
- Cupones cargados: `FATI1` (Fatima, embajadora, 15% por 3 meses o 20% anual, 8% de comisión) y `JOSE1` (Jose, promo, mismo descuento, sin comisión). Los códigos viejos `FATI-0` y `JOSE-3` ya no existen.
- Todavía no se cobra ni se calcula comisión en la app: el cobro es manual (links de Mercado Pago) y la comisión se calcula mirando `cupones_resumen`.

## Datos de la persona adulta (primer ingreso)

La primera vez que alguien entra (después de aceptar las condiciones) se le pide un perfil: nombre y apellido (vienen precargados de Google), vínculo (mamá, papá, docente, profesional…), edad de cada chico o chica (solo la edad), país y ciudad (se escriben, no se pide ubicación del dispositivo), y de forma opcional año de nacimiento, celular y cómo conoció Pimpa. Aparte hay un casillero de consentimiento de marketing, sin tildar de entrada.

Se guarda en la tabla `perfiles` (`supabase/007_perfiles.sql`, ya corrido). La web solo escribe con `guardar_perfil()`, que valida y toma el mail de la sesión; cada persona solo puede leer su propia fila. Para ver los datos: Supabase > Table Editor > perfiles. `marketing_ok` y `marketing_ok_en` registran el consentimiento y cuándo se dio o se retiró.

Si la base no responde al comprobar el perfil, la persona entra igual y se lo pedimos la próxima vez. Quienes ya tenían cuenta también ven el formulario una vez. Para pedir la pantalla de nuevo en un navegador: borrar la clave `pimpa-perfil-<mail>` del almacenamiento local.

El panel /socias muestra los perfiles (con resumen por vínculo, país, edad de los chicos y marketing) mediante `socias_perfiles()` (`supabase/008_socias_perfiles.sql`), que solo responde a founder y cofounder.

## Checkout con Mercado Pago (Orders API)

Quien entra con Google y no está en `allowed_emails` ve "Activá tu cuenta" (en vez del bloqueo): campo de código, botón "Pagar con Mercado Pago". El botón llama a `/api/checkout` con la sesión de Supabase; la función verifica el mail con Supabase Auth, valida el cupón (`validar_cupon`), calcula el precio (mensual de lanzamiento $20.000, con cupón se descuenta `descuento_pct`), registra el pago pendiente (`pago_crear`) y crea una orden de Checkout Pro con `external_reference` = id del pago. Mercado Pago devuelve a `/?pago=ok`, donde la app consulta cada 4 s (hasta ~2 min) si ya fue habilitada.

El aviso de pago llega a `/api/mp` (webhook, evento "Order"). No confía en el cuerpo: consulta la orden a Mercado Pago con el token, exige que sea de Pimpa (`external_reference` UUID de `pagos`), que esté procesada y que el monto cobrado sea al menos el esperado; recién ahí llama `pago_aprobado`, que habilita (`habilitar`), copia el cupón y devuelve el mail para mandar "confirmado" por Resend (queda registrado en `envios`, visible en /socias). Es idempotente. Si `MP_WEBHOOK_SECRET` está cargada, además valida la firma `x-signature`.

Variables de Vercel: `MP_ACCESS_TOKEN` (token de producción de la aplicación "Pimpa" de Mercado Pago), `PAGOS_SECRET` (secreto compartido con la base; `pagos_config.secret_hash` guarda su sha256), `MP_WEBHOOK_SECRET` (opcional), `RESEND_API_KEY` (ya está). Migración: `supabase/010_pagos.sql` (más `insert into pagos_config` con el hash). Las tablas `pagos` y `pagos_config` no tienen políticas: solo se tocan con las funciones `pago_*` (security definer), que exigen el secreto.

Límites actuales: es un pago único por mes, no una suscripción: habilita la cuenta, pero no vence ni renueva (la renovación sigue siendo manual). La forma exacta de las URLs de retorno de la API de Orders aparece de dos maneras en la documentación de Mercado Pago; `api/checkout.js` prueba una y, si Mercado Pago responde 400, la otra.
