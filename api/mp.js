// Webhook de Mercado Pago (evento "Order"). No confía en lo que llega: consulta la orden a Mercado Pago con el token,
// busca el pago por external_reference y recién ahí habilita la cuenta. Si MP_WEBHOOK_SECRET está cargada, además valida la firma.
const crypto = require('crypto');
const { rpc, mp } = require('./_mp');
const { confirmado } = require('./_plantillas');

const FROM = process.env.MAIL_FROM || 'Pimpa <pimpa@impactese.com>';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function firmaOk(req, dataId) {
  const secreto = process.env.MP_WEBHOOK_SECRET;
  if (!secreto) return true;
  const h = String(req.headers['x-signature'] || '');
  const partes = {};
  h.split(',').forEach((p) => { const i = p.indexOf('='); if (i > 0) partes[p.slice(0, i).trim()] = p.slice(i + 1).trim(); });
  if (!partes.ts || !partes.v1) return false;
  const rid = req.headers['x-request-id'];
  let m = '';
  if (dataId) m += 'id:' + String(dataId).toLowerCase() + ';';
  if (rid) m += 'request-id:' + rid + ';';
  m += 'ts:' + partes.ts + ';';
  const calc = crypto.createHmac('sha256', secreto).update(m).digest('hex');
  const a = Buffer.from(calc), b = Buffer.from(partes.v1);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

// Una orden está paga cuando Mercado Pago la marca como procesada (acreditada).
function pagada(o) {
  if (!o) return false;
  if (o.status === 'processed') return true;
  const pays = (o.transactions && o.transactions.payments) || [];
  return pays.some((p) => (p.status === 'processed' || p.status === 'approved') && (!p.status_detail || p.status_detail === 'accredited'));
}
function pagado(o) {
  const t = Number(o.total_paid_amount);
  if (Number.isFinite(t) && t > 0) return t;
  const pays = (o.transactions && o.transactions.payments) || [];
  const s = pays.reduce((a, p) => a + (Number(p.paid_amount != null ? p.paid_amount : p.amount) || 0), 0);
  return s || Number(o.total_amount) || 0;
}

module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  if (!process.env.MP_ACCESS_TOKEN || !process.env.PAGOS_SECRET) return res.status(503).json({ error: 'Pagos no configurados' });
  const body = typeof req.body === 'string' ? (() => { try { return JSON.parse(req.body || '{}'); } catch (e) { return {}; } })() : (req.body || {});
  const dataId = String((req.query && (req.query['data.id'] || req.query.id)) || (body.data && body.data.id) || '');
  if (!firmaOk(req, dataId)) return res.status(401).json({ error: 'Firma inválida' });
  if (!/^[A-Za-z0-9_-]{6,80}$/.test(dataId)) return res.status(200).json({ ok: true, ignorado: true });

  try {
    const r = await mp('/v1/orders/' + encodeURIComponent(dataId), { method: 'GET' });
    if (!r.ok || !r.data) return res.status(502).json({ error: 'No pude leer la orden' }); // MP reintenta
    const o = r.data;
    const ref = String(o.external_reference || '');
    if (!UUID.test(ref)) return res.status(200).json({ ok: true, ajeno: true }); // otra orden de la cuenta, no es de Pimpa
    if (!pagada(o)) return res.status(200).json({ ok: true, estado: o.status || null });

    const out = await rpc('pago_aprobado', { p_secret: process.env.PAGOS_SECRET, p_id: ref, p_order_id: String(o.id || dataId), p_monto: pagado(o), p_raw: o });
    if (!out) return res.status(200).json({ ok: true, sin_pago: true });
    if (out.nuevo && process.env.RESEND_API_KEY) {
      let envio = null;
      try {
        envio = await rpc('pago_envio_confirmado', { p_secret: process.env.PAGOS_SECRET, p_email: out.email });
        const m = confirmado(envio);
        const rs = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: { Authorization: 'Bearer ' + process.env.RESEND_API_KEY, 'Content-Type': 'application/json' },
          body: JSON.stringify({ from: FROM, to: [out.email], reply_to: 'pimpa@impactese.com', subject: m.subject, html: m.html, text: m.text }),
        });
        const d = await rs.json().catch(() => ({}));
        if (!rs.ok) throw new Error(d.message || ('Resend ' + rs.status));
        await rpc('pago_envio_cerrar', { p_secret: process.env.PAGOS_SECRET, p_id: envio, p_estado: 'enviado', p_resend_id: d.id || null, p_error: null });
      } catch (e) {
        if (envio) { try { await rpc('pago_envio_cerrar', { p_secret: process.env.PAGOS_SECRET, p_id: envio, p_estado: 'error', p_resend_id: null, p_error: String(e.message) }); } catch (x) { /* nada */ } }
      }
    }
    return res.status(200).json({ ok: true, habilitada: true });
  } catch (e) {
    console.error('webhook MP', String(e.message));
    return res.status(500).json({ error: 'Error procesando el pago' }); // MP reintenta
  }
};
