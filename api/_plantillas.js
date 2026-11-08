// Plantillas de mail de Pimpa. Las imágenes y los links van por dirección propia (pimpa.impactese.com),
// así el mail sale como HTML real y no depende de adjuntos de Gmail.
const BASE = 'https://pimpa.impactese.com';
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

function listo(envioId, sinCodigo) {
  // Con código (JOSE1/FATI1): $17.000 los primeros 3 meses. Sin código: $20.000 (precio de lanzamiento; lista $30.000).
  const pagar = BASE + (sinCodigo ? '/pagar20' : '/pagar') + '?e=' + envioId;
  const precio = sinCodigo ? '$20.000 por mes' : '$17.000 por mes';
  const detalle = sinCodigo
    ? 'Es el precio de lanzamiento (el de lista es $30.000). Este link cobra <strong>un solo mes</strong>: por ahora cada mes te mandamos el link para renovar, y pod\u00e9s dejar de pagar cuando quieras.'
    : 'los primeros 3 meses (15% de descuento). Despu\u00e9s, $20.000 por mes. Este link cobra <strong>un solo mes</strong>: por ahora cada mes te mandamos el link para renovar, y pod\u00e9s dejar de pagar cuando quieras.';
  const detalleTxt = sinCodigo
    ? 'Es el precio de lanzamiento (el de lista es $30.000). Este link cobra un solo mes: por ahora cada mes te mandamos el link para renovar, y pod\u00e9s dejar de pagar cuando quieras.'
    : '$17.000 por mes los primeros 3 meses (15% de descuento). Despu\u00e9s, $20.000 por mes. Este link cobra un solo mes: por ahora cada mes te mandamos el link para renovar, y pod\u00e9s dejar de pagar cuando quieras.';
  const html = marco('Tu lugar en Pimpa est\u00e1 listo \u2728',
    '<p style="margin:0 0 14px">\u00a1Hola!</p>'
    + '<table width="100%" cellpadding="0" cellspacing="0" bgcolor="#FFEDE9" style="border-radius:14px;margin:0 0 18px"><tr><td style="padding:18px 20px;font-size:17px;line-height:1.55;color:#2d3a4a">'
    + '<strong>Gracias por sumarte a las primeras familias</strong> en esta etapa de lanzamiento y prueba, en la que estamos haciendo un <strong>precio especial</strong>. Estamos muy content@s de poder compartir este juego de Pimpa. \ud83d\udc9b</td></tr></table>'
    + '<p style="margin:0 0 18px">Ya estamos habilitando las primeras familias y ten\u00e9s un lugar reservado.</p>'
    + '<table width="100%" cellpadding="0" cellspacing="0" bgcolor="#E8F6EF" style="border-radius:14px;margin:0 0 18px"><tr><td align="center" style="padding:18px">'
    + '<p style="margin:0 0 4px;font-size:13px;color:#2f6f55;text-transform:uppercase;letter-spacing:.5px">Plan mensual, sin compromiso</p>'
    + '<p style="margin:0 0 4px;font-size:24px;font-weight:bold;color:#2d3a4a">' + precio + '</p>'
    + '<p style="margin:0 0 14px;font-size:14px;color:#555555">' + detalle + '</p>'
    + boton(pagar, 'Pagar un mes')
    + '<p style="margin:0;font-size:12px;color:#777777"><a href="' + pagar + '">' + pagar.replace('https://', '').replace(/\?.*$/, '') + '</a></p></td></tr></table>'
    + '<p style="margin:0 0 14px">Cuando pagues, <strong>respond\u00e9 este mail</strong> con el comprobante y el <strong>Gmail</strong> con el que van a entrar. Te habilitamos y te mandamos la bienvenida.</p>'
    + '<p style="margin:0 0 14px;font-size:14px;color:#555555">Pimpa es un complemento y no reemplaza una terapia ni a un profesional.</p>');
  const text = '\u00a1Hola!\n\nGracias por sumarte a las primeras familias en esta etapa de lanzamiento y prueba, en la que estamos haciendo un precio especial. Estamos muy content@s de poder compartir este juego de Pimpa.\n\n'
    + 'Ya estamos habilitando las primeras familias y ten\u00e9s un lugar reservado.\n\n'
    + 'Plan mensual, sin compromiso: ' + (sinCodigo ? '$20.000 por mes. ' : '') + detalleTxt + '\n\n'
    + 'Pagar un mes: ' + pagar + '\n\nCuando pagues, respond\u00e9 este mail con el comprobante y el Gmail con el que van a entrar. Te habilitamos y te mandamos la bienvenida.\n\n'
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

module.exports = { listo, confirmado };
