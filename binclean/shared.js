// Delade hjälpfunktioner för index.html och admin.html.
const PRICE = 125, PAIR = 240; // två tunnor kostar 240 kr
const MAX_DAYS_AHEAD = 90;
const MONTHS = ["januari","februari","mars","april","maj","juni","juli","augusti","september","oktober","november","december"];

const $ = id => document.getElementById(id);
const fmt = n => Math.round(n).toLocaleString("sv-SE") + " kr";
const iso = d => d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
const nice = s => new Date(s + "T12:00").toLocaleDateString("sv-SE", { weekday: "long", day: "numeric", month: "long" });
const short = s => new Date(s + "T12:00").toLocaleDateString("sv-SE", { weekday: "short", day: "numeric", month: "short" });
const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));

// Samma prisregel som i databasen (supabase.sql).
function priceFor(antal, typ) {
  let t = Math.floor(antal / 2) * PAIR + (antal % 2) * PRICE;
  if (typ === "abo") t = Math.round(t * 0.85);
  return t;
}

let _client;
function client() {
  if (_client !== undefined) return _client;
  const c = window.BINCLEAN_CONFIG || {};
  const ok = window.supabase && c.supabaseUrl && !c.supabaseUrl.includes("DITT-PROJEKT") && c.supabaseAnonKey && !c.supabaseAnonKey.includes("DIN-ANON");
  _client = ok ? window.supabase.createClient(c.supabaseUrl, c.supabaseAnonKey) : null;
  return _client;
}
