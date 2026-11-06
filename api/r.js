// /pagar y /entrar: registran el clic (si el link viene de un mail enviado desde /socias) y redirigen.
const SB_URL = process.env.SB_URL || 'https://fhzqiuvubcytuewwktyf.supabase.co';
const SB_KEY = process.env.SB_KEY || 'sb_publishable__sz2tzDsQH0If8jjuUGqvg_B_n3taZ9';
const PAGO_URL = process.env.PAGO_URL || 'https://mpago.la/1yMJ5uy';
const DESTINOS = { pagar: PAGO_URL, entrar: '/' };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

module.exports = async (req, res) => {
  const d = String(req.query.d || '');
  const e = String(req.query.e || '');
  const destino = DESTINOS[d];
  res.setHeader('Cache-Control', 'no-store');
  if (!destino) { res.writeHead(302, { Location: '/' }); return res.end(); }
  if (UUID.test(e)) {
    try {
      await fetch(SB_URL + '/rest/v1/rpc/registrar_clic', {
        method: 'POST',
        headers: { apikey: SB_KEY, Authorization: 'Bearer ' + SB_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_envio: e, p_destino: d }),
        signal: AbortSignal.timeout(2500),
      });
    } catch (x) { /* si falla el registro, igual redirige */ }
  }
  res.writeHead(302, { Location: destino });
  res.end();
};
