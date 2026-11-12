// Plantillas de mail de Pimpa. Las imágenes y los links van por dirección propia (pimpa.impactese.com),
// así el mail sale como HTML real y no depende de adjuntos de Gmail.
const { precioPlan } = require('./_mp');
const BASE = 'https://pimpa.impactese.com';
const peso = (n) => '$' + String(Math.round(n)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const LOGO = BASE + '/mail/pimpa-logo.png';
const MASCOTA = BASE + '/mail/pimpa-mascota.png';

function marco(titulo, cuerpo) {
  return '<table width="100%" cellpadding="0" cellspacing="0" bgcolor="#FFF6E5"><tr><td align="center" style="padding:24px 12px">'
    + '<table width="560" cellpadding="0" cellspacing="0" bgcolor="#FFFFFF" style="max-width:560px;width:100%;border-radius:20px;font-family:Arial,Helvetica,sans-serif">'
    + '<tr><td align="center" bgcolor="#FFE9A6" style="padding:18px;border-radius:20px 20px 0 0"><img src="' + LOGO + '" width="180" height="60" alt="Pimpa" style="display:block;margin:0 auto;border:0"></td></tr>'
    + '<tr><td bgcolor="#4A90D9" height="6" style="height:6px;font-size:0;line-height:0">&nbsp;</td></tr>'
    + '<tr><td style="padding:28px 28px 8px;color:#333333;font-size:16px;line-height:1.55">'
    + '<h1 style="font-size:24px;margin:0 0 14px;color:#2d3a4a">' + titulo + '</h1>'
    + cuerpo
    + '<p style="margin:0 0 10px">Con cariño,<br>Equipo Pimpa ✨<br><span style="font-size:13px;color:#777777"><a href="mailto:pimpa@impactese.com">pimpa@impactese.com</a></span></p>'
    + '<p style="margin:0 0 22px;text-align:center"><img src="' + MASCOTA + '" width="110" height="110" alt="Pimpa" style="display:inline-block;border:0"></p>'
    + '</td></tr></table></td></tr></table>';
}

function boton(url, texto) {
  return '<table align="center" cellpadding="0" cellspacing="0" style="margin:0 auto 6px"><tr><td align="center" bgcolor="#FFD54F" style="border:2px solid #1f4e8c;border-radius:999px">'
    + '<a href="' + url + '" style="display:block;padding:15px 34px;font-size:18px;font-weight:bold;color:#1f4e8c;text-decoration:none">' + texto + '</a></td></tr></table>';
}

// desc = datos reales del código (validar_cupon). Sin desc se usan los estándar (15% en 1 y 3 meses, 20% en el anual): solo para vistas previas.
// Si se manda desc === null, el código no es válido: se muestra sin código y sin descuento.
async function datosCupon(rpc, codigo) {
  if (!codigo) return null;
  try { const v = await rpc('validar_cupon', { p_codigo: String(codigo) }); return v && v.valido ? v : null; } catch (e) { return null; }
}

function listo(envioId, codigo, desc) {
  const STD = { descuento_pct: 15, descuento_anual_pct: 20 };
  if (desc === null) codigo = null;
  const dc = desc || STD;
  const plan = (t, k) => ({ t, p: peso(precioPlan(k, codigo ? dc : null)) });
  const planes = [plan('1 mes', 'mensual'), plan('3 meses', 'trimestral'), plan('Plan anual', 'anual')];
  const pagar = BASE + (codigo ? '/?cupon=' + encodeURIComponent(codigo) : '/');
  const nota = 'Es el precio de lanzamiento (el de lista es $30.000 por mes). Cuando termina tu plan, lo renov\u00e1s desde la app.';
  const filas = planes.map(x => '<tr><td style="padding:6px 0;font-size:16px;color:#2d3a4a;text-align:left">' + x.t + '</td><td style="padding:6px 0;font-size:18px;font-weight:bold;color:#2d3a4a;text-align:right">' + x.p + '</td></tr>').join('');
  const html = marco('Tu lugar en Pimpa est\u00e1 listo \u2728',
    '<p style="margin:0 0 14px">\u00a1Hola!</p>'
    + '<table width="100%" cellpadding="0" cellspacing="0" bgcolor="#FFEDE9" style="border-radius:14px;margin:0 0 18px"><tr><td style="padding:18px 20px;font-size:17px;line-height:1.55;color:#2d3a4a">'
    + '<strong>Gracias por sumarte a las primeras familias</strong> en esta etapa de lanzamiento y prueba, en la que estamos haciendo un <strong>precio especial</strong>. Estamos muy content@s de poder compartir este juego de Pimpa. \ud83d\udc9b</td></tr></table>'
    + '<p style="margin:0 0 18px">Ya estamos habilitando las primeras familias y ten\u00e9s un lugar reservado.</p>'
    + '<table width="100%" cellpadding="0" cellspacing="0" bgcolor="#E8F6EF" style="border-radius:14px;margin:0 0 18px"><tr><td align="center" style="padding:18px">'
    + '<p style="margin:0 0 8px;font-size:13px;color:#2f6f55;text-transform:uppercase;letter-spacing:.5px">Eleg\u00ed tu plan</p>'
    + '<table width="100%" cellpadding="0" cellspacing="0" style="max-width:320px;margin:0 auto 8px">' + filas + '</table>'
    + (codigo ? '<p style="margin:0 0 8px;font-size:14px;color:#2d3a4a">Tu c\u00f3digo de descuento: <strong>' + codigo + '</strong> (ya est\u00e1 aplicado en estos precios)</p>' : '')
    + '<p style="margin:0 0 14px;font-size:14px;color:#555555">' + nota + '</p>'
    + boton(pagar, 'Activar mi cuenta')
    + '<p style="margin:0;font-size:12px;color:#777777"><a href="' + pagar + '">' + pagar.replace('https://', '').replace(/\?.*$/, '') + '</a></p></td></tr></table>'
    + '<p style="margin:0 0 14px">Entr\u00e1 con el <strong>Gmail</strong> con el que van a usar Pimpa, eleg\u00ed tu plan y pag\u00e1 con Mercado Pago. <strong>Se habilita sola al instante</strong>, sin esperar ni mandarnos el comprobante.</p>'
    + '<p style="margin:0 0 14px;font-size:14px;color:#555555">Pimpa es un complemento y no reemplaza una terapia ni a un profesional.</p>');
  const text = '\u00a1Hola!\n\nGracias por sumarte a las primeras familias en esta etapa de lanzamiento y prueba, en la que estamos haciendo un precio especial. Estamos muy content@s de poder compartir este juego de Pimpa.\n\n'
    + 'Ya estamos habilitando las primeras familias y ten\u00e9s un lugar reservado.\n\n'
    + 'Eleg\u00ed tu plan:\n' + planes.map(x => '- ' + x.t + ': ' + x.p).join('\n') + '\n'
    + (codigo ? 'Tu c\u00f3digo de descuento: ' + codigo + ' (ya est\u00e1 aplicado en estos precios)\n' : '') + nota + '\n\n'
    + 'Activar mi cuenta: ' + pagar + '\n\nEntr\u00e1 con el Gmail con el que van a usar Pimpa, eleg\u00ed tu plan y pag\u00e1 con Mercado Pago. Se habilita sola al instante, sin esperar ni mandarnos el comprobante.\n\n'
    + 'Pimpa es un complemento y no reemplaza una terapia ni a un profesional.\n\nCon cari\u00f1o,\nEquipo Pimpa\npimpa@impactese.com';
  return { subject: 'Tu lugar en Pimpa est\u00e1 listo \u2728', html, text };
}

function confirmado(envioId) {
  const entrar = BASE + '/entrar?e=' + envioId;
  const html = marco('¡Está confirmado tu acceso! 💛',
    '<p style="margin:0 0 14px">¡Hola!</p>'
    + '<p style="margin:0 0 16px">Ya recibimos tu pago y tu cuenta de Pimpa está habilitada. Para entrar:</p>'
    + '<ol style="margin:0 0 20px;padding-left:20px"><li style="margin-bottom:6px">Abrí <a href="' + entrar + '">pimpa.impactese.com</a>.</li>'
    + '<li style="margin-bottom:6px">Tocá <strong>Entrar con Google</strong> y elegí el Gmail que nos pasaste.</li>'
    + '<li>Elegí con quién trabajamos hoy y empezá a jugar.</li></ol>'
    + '<div style="margin:0 0 22px">' + boton(entrar, 'Entrar a Pimpa') + '</div>'
    + '<table width="100%" cellpadding="0" cellspacing="0" bgcolor="#E8F6EF" style="border-radius:14px;margin:0 0 16px"><tr><td style="padding:14px 16px;font-size:15px;color:#2d3a4a"><strong>Para el primer rato:</strong> lo mejor es hacerlo juntos, sin apuro y sin exigir resultados. Si se cansa, se corta y se sigue otro día.</td></tr></table>'
    + '<p style="margin:0 0 14px">Si algo no funciona o tenés una duda, respondé este mail o escribinos a <a href="mailto:pimpa@impactese.com">pimpa@impactese.com</a>.</p>'
    + '<p style="margin:0 0 14px;font-size:14px;color:#555555">Pimpa es un complemento y no reemplaza una terapia ni a un profesional.</p>');
  const text = '¡Hola!\n\n¡Está confirmado tu acceso a Pimpa! Ya recibimos tu pago y tu cuenta está habilitada.\n\nPara entrar:\n1. Abrí ' + entrar
    + '\n2. Tocá "Entrar con Google" y elegí el Gmail que nos pasaste.\n3. Elegí con quién trabajamos hoy y empezá a jugar.\n\n'
    + 'Para el primer rato: lo mejor es hacerlo juntos, sin apuro y sin exigir resultados. Si se cansa, se corta y se sigue otro día.\n\n'
    + 'Si algo no funciona o tenés una duda, respondé este mail o escribinos a pimpa@impactese.com.\n\n'
    + 'Pimpa es un complemento y no reemplaza una terapia ni a un profesional.\n\nCon cariño,\nEquipo Pimpa';
  return { subject: 'Está confirmado tu acceso a Pimpa ✨', html, text };
}

// Carrito abandonado: BORRADOR. Todavía no se envía a nadie (falta definir el disparador y el texto final).
// Pensado para quien abrió Mercado Pago y no terminó el pago (estado "pago sin completar" del panel).
function carrito(envioId, codigo) {
  const volver = BASE + (codigo ? '/?cupon=' + encodeURIComponent(codigo) : '/');
  const html = marco('Tu lugar en Pimpa te sigue esperando \ud83d\udc9b',
    '<p style="margin:0 0 14px">\u00a1Hola!</p>'
    + '<p style="margin:0 0 16px">Vimos que empezaste a activar tu cuenta de Pimpa y no llegaste a terminar el pago. No pasa nada: <strong>tu lugar sigue reservado</strong>.</p>'
    + '<p style="margin:0 0 18px">Cuando quieras, entr\u00e1 con el mismo Gmail y retom\u00e1 desde donde quedaste. Se habilita sola apenas se acredita el pago.</p>'
    + '<div style="margin:0 0 22px">' + boton(volver, 'Terminar mi activaci\u00f3n') + '</div>'
    + '<p style="margin:0 0 14px">Si algo no funcion\u00f3 con Mercado Pago o ten\u00e9s una duda, escribinos a <a href="mailto:pimpa@impactese.com">pimpa@impactese.com</a> y lo resolvemos.</p>'
    + '<p style="margin:0 0 14px;font-size:14px;color:#555555">Pimpa es un complemento y no reemplaza una terapia ni a un profesional.</p>');
  const text = '\u00a1Hola!\n\nVimos que empezaste a activar tu cuenta de Pimpa y no llegaste a terminar el pago. No pasa nada: tu lugar sigue reservado.\n\n'
    + 'Cuando quieras, entr\u00e1 con el mismo Gmail y retom\u00e1 desde donde quedaste. Se habilita sola apenas se acredita el pago.\n\n'
    + 'Terminar mi activaci\u00f3n: ' + volver + '\n\n'
    + 'Si algo no funcion\u00f3 con Mercado Pago o ten\u00e9s una duda, escribinos a pimpa@impactese.com y lo resolvemos.\n\n'
    + 'Pimpa es un complemento y no reemplaza una terapia ni a un profesional.\n\nCon cari\u00f1o,\nEquipo Pimpa';
  return { subject: 'Tu lugar en Pimpa te sigue esperando \ud83d\udc9b', html, text };
}

// Invitación de prueba para educadoras/profesionales (acceso de un mes, sin descuentos ni promesas).
function invitacion(envioId) {
  const entrar = BASE + '/entrar?e=' + envioId;
  const html = marco('Tu acceso a Pimpa ya está listo 💛',
    '<p style="margin:0 0 14px">¡Hola!</p>'
    + '<p style="margin:0 0 16px">Gracias por querer probar Pimpa. Ya te habilitamos el acceso.</p>'
    + '<table width="100%" cellpadding="0" cellspacing="0" bgcolor="#FFEDE9" style="border-radius:14px;margin:0 0 18px"><tr><td style="padding:16px 18px;font-size:16px;line-height:1.55;color:#2d3a4a">'
    + '<strong>Qué es Pimpa.</strong> Una app de ejercicios de lectoescritura y conciencia fonológica para chicos con síndrome de Down, dislexia o retraso madurativo, pensada para hacer en casa con la familia. La armamos con una psicopedagoga, que define el contenido pedagógico.</td></tr></table>'
    + '<p style="margin:0 0 10px"><strong>Cómo entrar:</strong></p>'
    + '<ol style="margin:0 0 20px;padding-left:20px"><li style="margin-bottom:6px">Abrí <a href="' + entrar + '">pimpa.impactese.com</a>.</li>'
    + '<li style="margin-bottom:6px">Tocá <strong>Entrar con Google</strong> y elegí este mismo Gmail. Con otra cuenta te va a pedir un pago.</li>'
    + '<li>Elegí con quién trabajamos hoy y empezá.</li></ol>'
    + '<div style="margin:0 0 22px">' + boton(entrar, 'Entrar a Pimpa') + '</div>'
    + '<table width="100%" cellpadding="0" cellspacing="0" bgcolor="#E8F6EF" style="border-radius:14px;margin:0 0 18px"><tr><td style="padding:16px 18px;font-size:15px;line-height:1.55;color:#2d3a4a">'
    + '<strong>Cómo funciona:</strong><ul style="margin:8px 0 0;padding-left:18px">'
    + '<li style="margin-bottom:4px">Tenés el <strong>modo educador</strong>, distinto al de las familias: podés crear un perfil por cada chico, ver el progreso de cada uno y saltear etapas del camino.</li>'
    + '<li style="margin-bottom:4px">Los ejercicios van por niveles: letras y sonidos, sílabas, palabras y trazo de letras, entre otros. “Mi camino” ordena el avance, y también podés elegir qué letra o grupo practicar.</li>'
    + '<li>Los chicos juntan estrellas y premios con Pimpa, la mascota.</li></ul></td></tr></table>'
    + '<p style="margin:0 0 14px"><strong>Tu acceso</strong> es de prueba y dura un mes. No tenés que hacer nada para que termine. Si te sirve, después te contamos cómo es el programa de embajadoras.</p>'
    + '<p style="margin:0 0 14px">Si algo no funciona o tenés una duda, respondé este mail o escribinos a <a href="mailto:pimpa@impactese.com">pimpa@impactese.com</a>.</p>'
    + '<p style="margin:0 0 14px;font-size:14px;color:#555555">Pimpa es un complemento y no reemplaza una terapia ni a un profesional.</p>');
  const text = '¡Hola!\n\nGracias por querer probar Pimpa. Ya te habilitamos el acceso.\n\n'
    + 'Qué es Pimpa: una app de ejercicios de lectoescritura y conciencia fonológica para chicos con síndrome de Down, dislexia o retraso madurativo, pensada para hacer en casa con la familia. La armamos con una psicopedagoga, que define el contenido pedagógico.\n\n'
    + 'Cómo entrar:\n1. Abrí ' + entrar + '\n2. Tocá "Entrar con Google" y elegí este mismo Gmail. Con otra cuenta te va a pedir un pago.\n3. Elegí con quién trabajamos hoy y empezá.\n\n'
    + 'Cómo funciona:\n- Tenés el modo educador, distinto al de las familias: podés crear un perfil por cada chico, ver el progreso de cada uno y saltear etapas del camino.\n'
    + '- Los ejercicios van por niveles: letras y sonidos, sílabas, palabras y trazo de letras, entre otros. "Mi camino" ordena el avance, y también podés elegir qué letra o grupo practicar.\n- Los chicos juntan estrellas y premios con Pimpa, la mascota.\n\n'
    + 'Tu acceso es de prueba y dura un mes. No tenés que hacer nada para que termine. Si te sirve, después te contamos cómo es el programa de embajadoras.\n\n'
    + 'Si algo no funciona o tenés una duda, respondé este mail o escribinos a pimpa@impactese.com.\n\nPimpa es un complemento y no reemplaza una terapia ni a un profesional.\n\nCon cariño,\nEquipo Pimpa';
  return { subject: 'Tu acceso a Pimpa ya está listo 💛', html, text };
}

// Aviso a quienes se anotaron cuando había que mandar el comprobante: ahora es directo.
function aviso(envioId) {
  const html = marco('Ahora es mucho más fácil activar Pimpa 💛',
    '<p style="margin:0 0 14px">¡Hola!</p>'
    + '<p style="margin:0 0 16px">Te escribimos porque te anotaste en Pimpa cuando todavía tenías que <strong>mandarnos el comprobante de pago</strong>. Eso ya no hace falta: <strong>ahora es directo</strong>, y te estamos esperando. ✨</p>'
    + '<ol style="margin:0 0 20px;padding-left:20px"><li style="margin-bottom:6px">Entrá a <a href="' + BASE + '/">pimpa.impactese.com</a> con el <strong>Gmail</strong> con el que van a usar Pimpa.</li>'
    + '<li style="margin-bottom:6px">Elegí tu plan (1 mes, 3 meses o anual). Si tenés un código de descuento, lo ponés ahí.</li>'
    + '<li>Pagá con Mercado Pago. <strong>Se habilita sola al instante</strong>, sin esperar ni mandarnos nada.</li></ol>'
    + '<div style="margin:0 0 22px">' + boton(BASE + '/', 'Entrar a Pimpa') + '</div>'
    + '<p style="margin:0 0 14px">Si algo no funciona o tenés una duda, respondé este mail o escribinos a <a href="mailto:pimpa@impactese.com">pimpa@impactese.com</a>.</p>'
    + '<p style="margin:0 0 14px;font-size:14px;color:#555555">Pimpa es un complemento y no reemplaza una terapia ni a un profesional.</p>');
  const text = '¡Hola!\n\nTe escribimos porque te anotaste en Pimpa cuando todavía tenías que mandarnos el comprobante de pago. Eso ya no hace falta: ahora es directo, y te estamos esperando.\n\n'
    + '1. Entrá a ' + BASE + '/ con el Gmail con el que van a usar Pimpa.\n2. Elegí tu plan (1 mes, 3 meses o anual). Si tenés un código de descuento, lo ponés ahí.\n3. Pagá con Mercado Pago. Se habilita sola al instante, sin esperar ni mandarnos nada.\n\n'
    + 'Si algo no funciona o tenés una duda, respondé este mail o escribinos a pimpa@impactese.com.\n\nPimpa es un complemento y no reemplaza una terapia ni a un profesional.\n\nCon cariño,\nEquipo Pimpa';
  return { subject: 'Ahora activar Pimpa es directo: te esperamos 💛', html, text };
}

module.exports = { listo, confirmado, carrito, aviso, invitacion, datosCupon };
