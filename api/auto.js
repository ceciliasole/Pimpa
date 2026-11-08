// Lo llama la base (pg_net) cuando alguien se anota en la lista de espera: manda "Tu lugar está listo".
// No necesita login: solo puede enviar un envío automático 'pendiente' que creó la base, una única vez,
// y siempre al mail anotado en ese envío.
const { listo } = require('./_plantillas');

const SB_URL = process.env.SB_URL || 'https://fhzqiuvubcytuewwktyf.supabase.co';
const SB_KEY = process.env.SB_KEY || 'sb_publishable__sz2tzDsQH0If8jjuUGqvg_B_n3taZ9';
const FROM = process.env.MAIL_FROM || 'Pimpa <pimpa@impactese.com>';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function rpc(nombre, args) {
  const r = await fetch(SB_URL + '/rest/v1/rpc/' + nombre, {
    method: 'POST',
    headers: { apikey: SB_KEY, Authorization: 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify(args),
  });
  const t = await r.text();
  let d = null; try { d = t ? JSON.parse(t) : null; } catch (e) { d = t; }
  if (!r.ok) throw new Error((d && d.message) || ('Error ' + r.status));
  return d;
}

module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
  const id = String(body.e || '');
  if (!UUID.test(id)) return res.status(400).json({ error: 'Envío inválido' });
  if (!process.env.RESEND_API_KEY) return res.status(503).json({ error: 'Falta RESEND_API_KEY' });

  let email;
  try { email = await rpc('auto_tomar', { p_id: id }); } catch (e) { return res.status(500).json({ error: 'No se pudo tomar el envío' }); }
  if (!email) return res.status(200).json({ ok: true, nada: true });

  try {
    const dat = await rpc('auto_datos', { p_id: id });
    const m = listo(id, dat && dat.cupon);
    const r = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + process.env.RESEND_API_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ from: FROM, to: [email], reply_to: 'pimpa@impactese.com', subject: m.subject, html: m.html, text: m.text }),
    });
    const d = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(d.message || ('Resend ' + r.status));
    await rpc('auto_cerrar', { p_id: id, p_estado: 'enviado', p_resend_id: d.id || null, p_error: null });
    return res.status(200).json({ ok: true });
  } catch (e) {
    try { await rpc('auto_cerrar', { p_id: id, p_estado: 'error', p_resend_id: null, p_error: String(e.message) }); } catch (x) { /* nada */ }
    return res.status(502).json({ error: String(e.message) });
  }
};
