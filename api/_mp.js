// Utilidades compartidas del checkout con Mercado Pago (Orders API).
const SB_URL = process.env.SB_URL || 'https://fhzqiuvubcytuewwktyf.supabase.co';
const SB_KEY = process.env.SB_KEY || 'sb_publishable__sz2tzDsQH0If8jjuUGqvg_B_n3taZ9';
const BASE = process.env.APP_URL || 'https://pimpa.impactese.com';
const MP = 'https://api.mercadopago.com';
const PRECIO_MENSUAL = 20000; // precio de lanzamiento en ARS (el de lista es 30.000)

async function rpc(nombre, args, jwt) {
  const r = await fetch(SB_URL + '/rest/v1/rpc/' + nombre, {
    method: 'POST',
    headers: { apikey: SB_KEY, Authorization: 'Bearer ' + (jwt || SB_KEY), 'Content-Type': 'application/json' },
    body: JSON.stringify(args),
    signal: AbortSignal.timeout(8000),
  });
  const t = await r.text();
  let d = null; try { d = t ? JSON.parse(t) : null; } catch (e) { d = t; }
  if (!r.ok) throw new Error((d && d.message) || ('Supabase ' + r.status));
  return d;
}

// Devuelve el mail verificado de quien llama (token de sesión de Supabase), o null.
async function mailDe(jwt) {
  if (!jwt) return null;
  const r = await fetch(SB_URL + '/auth/v1/user', {
    headers: { apikey: SB_KEY, Authorization: 'Bearer ' + jwt },
    signal: AbortSignal.timeout(8000),
  });
  if (!r.ok) return null;
  const u = await r.json().catch(() => null);
  const e = String((u && u.email) || '').toLowerCase();
  return e || null;
}

function monto(pctDescuento) {
  const p = Math.max(0, Math.min(99, Number(pctDescuento) || 0));
  return Math.round(PRECIO_MENSUAL * (100 - p) / 100);
}
const fmt = (n) => Number(n).toFixed(2);

async function mp(path, opts) {
  const r = await fetch(MP + path, Object.assign({ signal: AbortSignal.timeout(12000) }, opts, {
    headers: Object.assign({ Authorization: 'Bearer ' + process.env.MP_ACCESS_TOKEN, 'Content-Type': 'application/json', accept: 'application/json' }, (opts && opts.headers) || {}),
  }));
  const t = await r.text();
  let d = null; try { d = t ? JSON.parse(t) : null; } catch (e) { d = { raw: t }; }
  return { ok: r.ok, status: r.status, data: d };
}

module.exports = { SB_URL, SB_KEY, BASE, PRECIO_MENSUAL, rpc, mailDe, monto, fmt, mp };
