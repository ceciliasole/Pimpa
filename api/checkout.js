// POST /api/checkout  (Authorization: Bearer <sesión de Supabase>, body {cupon?})
// Crea una orden de Checkout Pro con el mail verificado de la persona como dueña del pago y devuelve la URL de pago.
// Variables de Vercel: MP_ACCESS_TOKEN y PAGOS_SECRET (el sha256 de PAGOS_SECRET está en la tabla pagos_config).
const crypto = require('crypto');
const { BASE, PLANES, precioPlan, rpc, mailDe, fmt, mp } = require('./_mp');

function variantes(ref, email, total, backUrl, notifUrl, titulo) {
  const base = {
    type: 'online',
    processing_mode: 'manual',
    total_amount: total,
    external_reference: ref,
    payer: { email },
    items: [{ title: 'Pimpa - ' + titulo, unit_price: total, quantity: 1 }],
  };
  // El webhook está configurado en el panel de Mercado Pago (config.notification_url no es aceptado en el pedido).
  const a = Object.assign({}, base, { config: { online: { success_url: backUrl, auto_return: 'approved' } } });
  const b = Object.assign({}, base);
  return [a, b];
}

module.exports = async (req, res) => {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') return res.status(405).json({ error: 'Método no permitido' });
  if (!process.env.MP_ACCESS_TOKEN || !process.env.PAGOS_SECRET) return res.status(503).json({ error: 'Pagos no configurados' });
  const jwt = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  let email;
  try { email = await mailDe(jwt); } catch (e) { return res.status(502).json({ error: 'No pudimos verificar tu cuenta' }); }
  if (!email) return res.status(401).json({ error: 'Entrá con tu cuenta de Google para pagar' });

  const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : (req.body || {});
  const plan = body.plan ? String(body.plan) : 'mensual';
  if (!PLANES[plan]) return res.status(400).json({ error: 'plan_invalido' });
  let cupon = null, datosCupon = null;
  try {
    if (body.cupon && String(body.cupon).trim()) {
      const v = await rpc('validar_cupon', { p_codigo: String(body.cupon) });
      if (!v || !v.valido) return res.status(400).json({ error: 'cupon_invalido' });
      cupon = v.codigo; datosCupon = v;
    }
  } catch (e) { return res.status(502).json({ error: 'No pudimos validar el código' }); }

  const total = fmt(precioPlan(plan, datosCupon));
  let pagoId;
  try { pagoId = await rpc('pago_crear', { p_secret: process.env.PAGOS_SECRET, p_email: email, p_cupon: cupon, p_monto: Number(total), p_plan: plan }); }
  catch (e) { return res.status(502).json({ error: 'No pudimos preparar el pago' }); }

  let ultimo = null;
  for (const cuerpo of variantes(pagoId, email, total, BASE + '/?pago=ok', BASE + '/api/mp', PLANES[plan].titulo)) {
    try {
      const r = await mp('/v1/orders', { method: 'POST', headers: { 'X-Idempotency-Key': crypto.randomUUID() }, body: JSON.stringify(cuerpo) });
      ultimo = r;
      if (!r.ok) console.error('MP create order intento', r.status, JSON.stringify(r.data).slice(0, 500));
      const url = r.ok && r.data && (r.data.checkout_url || r.data.init_point || (r.data.checkout_pro && r.data.checkout_pro.init_point));
      if (url) {
        try { await rpc('pago_orden', { p_secret: process.env.PAGOS_SECRET, p_id: pagoId, p_order_id: String(r.data.id || '') }); } catch (e) { /* el webhook igual lo encuentra por external_reference */ }
        return res.status(200).json({ url, monto: Number(total), plan });
      }
      if (r.status !== 400 && r.status !== 422) break; // solo se reintenta si Mercado Pago rechaza la forma del pedido
    } catch (e) { ultimo = { status: 0, data: { message: String(e.message) } }; break; }
  }
  console.error('MP create order falló', ultimo && ultimo.status, JSON.stringify(ultimo && ultimo.data).slice(0, 600));
  return res.status(502).json({ error: 'No pudimos abrir Mercado Pago. Probá de nuevo en un rato.' });
};
