// Envía los mails de Pimpa por Resend. Solo lo puede usar una socia logueada (founder o cofounder):
// el permiso lo chequea la base (es_socia) con el token de quien llama, sin claves de administrador.
// Variables de Vercel: RESEND_API_KEY (obligatoria), MAIL_FROM (opcional).
const { listo, confirmado } = require('./_plantillas');

const SB_URL = process.env.SB_URL || 'https://fhzqiuvubcytuewwktyf.supabase.co';
const SB_KEY = process.env.SB_KEY || 'sb_publishable__sz2tzDsQH0If8jjuUGqvg_B_n3taZ9';
const FROM = process.env.MAIL_FROM || 'Pimpa <pimpa@impactese.com>';
const REPLY_TO = 'pimpa@impactese.com';
const PLANTILLAS = { listo, confirmado };

async function rpc(nombre, args, jwt) {
  const r = await fetch(SB_URL + '/rest/v1/rpc/' + nombre, {
    method: 'POST',
    headers: { apikey: SB_KEY, Authorization: 'Bearer ' + jwt, 'Content-Type': 'application/json' },
    body: JSON.stringify(args),
  });
  const txt = await r.text();
  let data = null;
  try { data = txt ? JSON.parse(txt) : null; } catch (e) { data = txt; }
  if (!r.ok) throw new Error((data && data.message) || ('Error ' + r.status));
  return data;
}

module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  const jwt = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  if (!jwt) return res.status(401).json({ error: 'Falta iniciar sesión' });
  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
  if (!process.env.RESEND_API_KEY && body.modo !== 'vista') {
    return res.status(503).json({ error: 'Falta cargar RESEND_API_KEY en Vercel' });
  }
  const plantilla = body.plantilla;
  const emails = Array.isArray(body.emails) ? body.emails.map(e => String(e).trim().toLowerCase()) : [];
  if (!PLANTILLAS[plantilla]) return res.status(400).json({ error: 'Plantilla desconocida' });

  // Vista previa y prueba: no tocan a nadie más que a quien está logueada.
  if (body.modo === 'vista' || body.modo === 'prueba') {
    try {
      const ok = await rpc('es_socia', {}, jwt);
      if (ok !== true) return res.status(403).json({ error: 'Sin permiso' });
    } catch (e) { return res.status(403).json({ error: 'Sin permiso' }); }
    const m = PLANTILLAS[plantilla]('prueba');
    if (body.modo === 'vista') return res.status(200).json({ subject: m.subject, html: m.html });
    const u = await fetch(SB_URL + '/auth/v1/user', { headers: { apikey: SB_KEY, Authorization: 'Bearer ' + jwt } });
    const yo = u.ok ? (await u.json()).email : null;
    if (!yo) return res.status(401).json({ error: 'No pude identificar tu mail' });
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + process.env.RESEND_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: FROM, to: [yo], reply_to: REPLY_TO, subject: '[PRUEBA] ' + m.subject, html: m.html, text: m.text }),
    });
    const d = await r.json().catch(() => ({}));
    if (!r.ok) return res.status(502).json({ error: d.message || ('Resend ' + r.status) });
    return res.status(200).json({ enviadoA: yo });
  }

  if (!emails.length || emails.length > 50) return res.status(400).json({ error: 'Entre 1 y 50 mails' });

  const resultados = [];
  for (const email of emails) {
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { resultados.push({ email, ok: false, error: 'Mail inválido' }); continue; }
    let id;
    try {
      id = await rpc('registrar_envio', { p_email: email, p_plantilla: plantilla }, jwt);
    } catch (e) {
      resultados.push({ email, ok: false, error: 'Sin permiso' });
      if (String(e.message).includes('permiso')) break;
      continue;
    }
    try {
      const m = PLANTILLAS[plantilla](id);
      const r = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + process.env.RESEND_API_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from: FROM, to: [email], reply_to: REPLY_TO, subject: m.subject, html: m.html, text: m.text }),
      });
      const d = await r.json().catch(() => ({}));
      if (!r.ok) throw new Error(d.message || ('Resend ' + r.status));
      await rpc('cerrar_envio', { p_id: id, p_estado: 'enviado', p_resend_id: d.id || null, p_error: null }, jwt);
      resultados.push({ email, ok: true });
    } catch (e) {
      try { await rpc('cerrar_envio', { p_id: id, p_estado: 'error', p_resend_id: null, p_error: String(e.message) }, jwt); } catch (x) { /* ya falló el envío */ }
      resultados.push({ email, ok: false, error: String(e.message) });
    }
  }
  return res.status(200).json({ resultados });
};
