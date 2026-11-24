import { firebaseConfig } from "./config.js";
import { initializeApp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut,
  GoogleAuthProvider, signInWithPopup, sendPasswordResetEmail, sendEmailVerification, linkWithPopup,
  linkWithCredential,
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";
import {
  initializeFirestore, persistentLocalCache, persistentMultipleTabManager, collection, onSnapshot, doc,
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-firestore.js";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = initializeFirestore(app, { localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }) });
const root = document.getElementById("app");

// ---------------------------------------------------------------- tema
const ACCENTS = [["#4fd69c", "#4d9eff"], ["#33b3ff", "#5c5cf2"], ["#ff8c4d", "#f24d8c"], ["#a885ff", "#f280d9"],
  ["#f24066", "#ff8c59"], ["#4db861", "#b3d140"], ["#ff4d1a", "#ffb300"], ["#8c99ad", "#59667a"]];
function applyTheme() {
  const t = localStorage.getItem("theme") || "system";
  const dark = t === "dark" || (t === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.dataset.theme = dark ? "dark" : "light";
  const [a, b] = ACCENTS[+(localStorage.getItem("accent") || 0)] || ACCENTS[0];
  document.documentElement.style.setProperty("--accent", a);
  document.documentElement.style.setProperty("--accent2", b);
}
applyTheme();
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", applyTheme);

// ---------------------------------------------------------------- utilidades
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const nf = (v, d = 1) => (v ?? 0).toLocaleString("pt-BR", { minimumFractionDigits: d, maximumFractionDigits: d });
const day = (ms) => { const d = new Date(ms); d.setHours(0, 0, 0, 0); return d.getTime(); };
const DAY = 86400000;
const fmtDate = (ms, o = { day: "2-digit", month: "short" }) => new Date(ms).toLocaleDateString("pt-BR", o);
const fmtTime = (ms) => new Date(ms).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
const rel = (ms) => {
  const s = (Date.now() - ms) / 1000;
  if (s < 60) return "agora";
  if (s < 3600) return `há ${Math.round(s / 60)} min`;
  if (s < 86400) return `há ${Math.round(s / 3600)} h`;
  return `há ${Math.round(s / 86400)} d`;
};
const sum = (a, f = (x) => x) => a.reduce((s, x) => s + (f(x) || 0), 0);
const MEALS = [["breakfast", "Café da manhã", "☕"], ["morningSnack", "Lanche da manhã", "🍎"], ["lunch", "Almoço", "🍛"],
  ["afternoonSnack", "Lanche da tarde", "🥪"], ["dinner", "Jantar", "🍝"], ["supper", "Ceia", "🌙"]];
const CARDIO = { run: ["Corrida", "🏃"], walk: ["Caminhada", "🚶"], bike: ["Pedalada", "🚴"] };
let EX = {};
fetch("data/exercises.json").then((r) => r.json()).then((j) => { EX = j; render(); }).catch(() => {});

// ---------------------------------------------------------------- dados
const COLS = ["profile", "weights", "measurements", "foods", "water", "savedFoods", "workouts", "routines", "cardio", "moods", "sleep"];
const store = Object.fromEntries(COLS.map((c) => [c, new Map()]));
let summary = null;
let unsubs = [];
let lastServer = 0;

function listen(uid) {
  unsubs.forEach((u) => u());
  unsubs = COLS.map((c) => onSnapshot(collection(db, "users", uid, c), (snap) => {
    snap.docChanges().forEach((ch) => {
      const v = ch.doc.data();
      if (ch.type === "removed" || v.deleted) { store[c].delete(ch.doc.id); return; }
      let data = {};
      try { data = JSON.parse(v.data || "{}"); } catch { /* ignora registro inválido */ }
      store[c].set(ch.doc.id, { id: ch.doc.id, updated: v.updated, ...data });
      const s = v.server?.toMillis?.() || 0;
      if (s > lastServer) lastServer = s;
    });
    scheduleRender();
  }, (err) => { console.error(err); showError(err); }));
  unsubs.push(onSnapshot(doc(db, "users", uid, "meta", "summary"), (d) => {
    if (d.exists()) { try { summary = { ...JSON.parse(d.data().data || "{}"), updated: d.data().updated }; } catch { summary = null; } }
    scheduleRender();
  }));
}
const all = (c) => [...store[c].values()];
const sorted = (c, key) => all(c).sort((a, b) => (a[key] || 0) - (b[key] || 0));

let renderQueued = false;
function scheduleRender() {
  if (renderQueued) return;
  renderQueued = true;
  requestAnimationFrame(() => { renderQueued = false; render(); });
}
let lastError = "";
function showError(e) {
  lastError = e.code === "permission-denied"
    ? "Sem permissão para ler os dados: confira as regras do Firestore."
    : (e.message || String(e));
  render();
}

// ---------------------------------------------------------------- gráficos (SVG)
function lineChart(points, { h = 180, color = "var(--accent)", avg = null, yFmt = (v) => nf(v, 1) } = {}) {
  if (points.length < 2) return `<div class="empty small">Poucos dados para o gráfico.</div>`;
  const W = 600, pad = { l: 40, r: 10, t: 10, b: 22 };
  const xs = points.map((p) => p.x), ys = points.map((p) => p.y).concat(avg ? avg.map((p) => p.y) : []);
  let y0 = Math.min(...ys), y1 = Math.max(...ys);
  if (y1 - y0 < 1e-6) { y0 -= 1; y1 += 1; }
  const m = (y1 - y0) * 0.12; y0 -= m; y1 += m;
  const x0 = Math.min(...xs), x1 = Math.max(...xs) || x0 + 1;
  const X = (x) => pad.l + ((x - x0) / Math.max(x1 - x0, 1)) * (W - pad.l - pad.r);
  const Y = (y) => pad.t + (1 - (y - y0) / (y1 - y0)) * (h - pad.t - pad.b);
  const path = (ps) => ps.map((p, i) => `${i ? "L" : "M"}${X(p.x).toFixed(1)},${Y(p.y).toFixed(1)}`).join("");
  const area = `${path(points)}L${X(points.at(-1).x)},${h - pad.b}L${X(points[0].x)},${h - pad.b}Z`;
  const ticks = [0, 0.5, 1].map((t) => y0 + (y1 - y0) * t);
  const id = "g" + Math.random().toString(36).slice(2, 8);
  return `<svg class="chart" viewBox="0 0 ${W} ${h}">
    <defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${color}" stop-opacity=".28"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient></defs>
    <g class="grid">${ticks.map((t) => `<line x1="${pad.l}" x2="${W - pad.r}" y1="${Y(t)}" y2="${Y(t)}"/><text x="${pad.l - 6}" y="${Y(t) + 4}" text-anchor="end">${yFmt(t)}</text>`).join("")}</g>
    <path d="${area}" fill="url(#${id})"/>
    <path d="${path(points)}" fill="none" stroke="${color}" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round"/>
    ${avg && avg.length > 1 ? `<path d="${path(avg)}" fill="none" stroke="var(--muted)" stroke-width="1.6" stroke-dasharray="4 4"/>` : ""}
    <text x="${pad.l}" y="${h - 4}">${fmtDate(x0)}</text><text x="${W - pad.r}" y="${h - 4}" text-anchor="end">${fmtDate(x1)}</text>
  </svg>`;
}

function barChart(items, { h = 160, goal = null, fmt = (v) => nf(v, 0) } = {}) {
  if (!items.length) return `<div class="empty small">Sem dados.</div>`;
  const W = 600, pad = { l: 8, r: 8, t: 16, b: 22 };
  const max = Math.max(...items.map((i) => i.y), goal || 0, 1) * 1.1;
  const bw = (W - pad.l - pad.r) / items.length;
  const Y = (v) => pad.t + (1 - v / max) * (h - pad.t - pad.b);
  return `<svg class="chart" viewBox="0 0 ${W} ${h}">
    ${goal ? `<line x1="${pad.l}" x2="${W - pad.r}" y1="${Y(goal)}" y2="${Y(goal)}" stroke="var(--muted)" stroke-dasharray="4 4"/>` : ""}
    ${items.map((it, i) => {
      const x = pad.l + i * bw + bw * 0.18, w = bw * 0.64, y = Y(it.y);
      return `<rect x="${x}" y="${y}" width="${w}" height="${Math.max(0, h - pad.b - y)}" rx="5" fill="${it.color || "var(--accent)"}" opacity="${it.y ? 1 : .25}"><title>${esc(it.label)}: ${fmt(it.y)}</title></rect>
        <text x="${x + w / 2}" y="${h - 6}" text-anchor="middle">${esc(it.short ?? it.label)}</text>`;
    }).join("")}
  </svg>`;
}

function ring(p, label, sub, size = 120) {
  const r = 46, c = 2 * Math.PI * r, v = Math.max(0, Math.min(1, p || 0));
  return `<div class="ring" style="width:${size}px;height:${size}px">
    <svg viewBox="0 0 110 110" width="${size}" height="${size}">
      <circle cx="55" cy="55" r="${r}" fill="none" stroke="var(--surface2)" stroke-width="10"/>
      <circle cx="55" cy="55" r="${r}" fill="none" stroke="var(--accent)" stroke-width="10" stroke-linecap="round"
        stroke-dasharray="${c * v} ${c}" transform="rotate(-90 55 55)"/>
    </svg>
    <div class="center"><b class="num">${label}</b><span class="tiny muted">${sub}</span></div>
  </div>`;
}

const bar = (p) => `<div class="bar"><i style="width:${Math.max(0, Math.min(100, (p || 0) * 100)).toFixed(1)}%"></i></div>`;

// ---------------------------------------------------------------- cálculos
function targets() {
  return summary?.targets || { kcal: 2000, protein: 120, carbs: 230, fat: 65, fiber: 28, water: 2500 };
}
function dayFoods(ms) { return all("foods").filter((f) => day(f.date) === day(ms)); }
function nut(list) {
  const n = { kcal: 0, protein: 0, carbs: 0, fat: 0, fiber: 0, sugar: 0, sodium: 0 };
  for (const f of list) for (const k in n) n[k] += f.nutrients?.[k] || 0;
  return n;
}
const waterOn = (ms) => sum(all("water").filter((w) => day(w.date) === day(ms)), (w) => w.ml);
function sessionStats(s) {
  const ex = Array.isArray(s.exercises) ? s.exercises : [];
  const work = ex.flatMap((e) => (e.sets || []).filter((x) => x.done && x.kind !== "warmup"));
  return {
    sets: work.length, volume: sum(work, (x) => (x.kg || 0) * (x.reps || 0)),
    minutes: s.end ? (s.end - s.start) / 60000 : 0, exercises: ex.filter((e) => (e.sets || []).some((x) => x.done)).length,
  };
}
function movingAvg(points, n = 7) {
  return points.map((p, i) => {
    const w = points.slice(Math.max(0, i - n + 1), i + 1);
    return { x: p.x, y: sum(w, (q) => q.y) / w.length };
  });
}

// ---------------------------------------------------------------- telas
const ROUTES = [
  ["painel", "Painel", "◉"], ["corpo", "Corpo", "⚖︎"], ["alimentacao", "Alimentação", "🍽"],
  ["treinos", "Treinos", "🏋"], ["mente", "Mente", "☾"], ["conta", "Conta", "⚙︎"],
];
let foodDay = day(Date.now());
let weightRange = 90;

function page() { const h = location.hash.replace("#/", ""); return ROUTES.some((r) => r[0] === h) ? h : "painel"; }

function shell(content, title, sub) {
  const p = page();
  const name = summary?.profileName || auth.currentUser?.displayName || "";
  const nav = ROUTES.map(([id, label, ic]) => `<a href="#/${id}" class="${p === id ? "on" : ""}"><span class="ic">${ic}</span>${label}</a>`).join("");
  return `<div class="shell">
    <aside class="side">
      <div class="brand"><div class="logo">${esc(summary?.emoji || "G")}</div>Gym</div>
      <nav class="nav">${nav}</nav>
      <div class="foot">${esc(auth.currentUser?.email || "")}<br>${lastServer ? "Atualizado " + rel(lastServer) : "Sem dados ainda"}</div>
    </aside>
    <main class="main">
      <div class="top"><div><h1>${title}</h1><div class="sub">${sub || (name ? "Olá, " + esc(name.split(" ")[0]) : "")}</div></div>
        <span class="pill"><span class="dot"></span>${summary?.updated ? "iPhone sincronizou " + rel(summary.updated) : "Aguardando o iPhone"}</span></div>
      ${lastError ? `<div class="msg err">${esc(lastError)}</div>` : ""}
      ${content}
    </main>
    <nav class="mobilebar">${ROUTES.map(([id, label, ic]) => `<a href="#/${id}" class="${p === id ? "on" : ""}"><span class="ic">${ic}</span>${label}</a>`).join("")}</nav>
  </div>`;
}

function viewPainel() {
  const t = targets();
  const ws = sorted("weights", "date");
  const last = ws.at(-1);
  const ref7 = [...ws].reverse().find((w) => w.date <= Date.now() - 7 * DAY);
  const ref30 = [...ws].reverse().find((w) => w.date <= Date.now() - 30 * DAY);
  const today = Date.now();
  const n = nut(dayFoods(today));
  const water = waterOn(today);
  const weekStart = today - 7 * DAY;
  const wk = all("workouts").filter((s) => s.end && s.start >= weekStart);
  const sl = all("sleep").filter((s) => s.wake >= weekStart);
  const sleepAvg = sl.length ? sum(sl, (s) => (s.wake - s.bedtime) / 3600000) / sl.length : 0;
  const md = all("moods").filter((m) => m.date >= weekStart);
  const moodAvg = md.length ? sum(md, (m) => m.mood) / md.length : 0;
  const d7 = last && ref7 ? last.kg - ref7.kg : null;
  const spark = ws.filter((w) => w.date >= Date.now() - 30 * DAY).map((w) => ({ x: w.date, y: w.kg }));
  const metrics = summary?.metrics || {};
  const metricOrder = ["bodyFat", "smm", "visceralFat", "waterPercent", "bmr", "metabolicAge", "bmi", "lbm", "bone", "proteinPercent"];
  const recent = [
    ...all("foods").map((f) => ({ t: f.date, ic: "🍽", title: f.name, meta: `${nf(f.grams, 0)} g · ${nf(f.nutrients?.kcal, 0)} kcal` })),
    ...all("workouts").filter((s) => s.end).map((s) => ({ t: s.start, ic: "🏋", title: s.name, meta: `${sessionStats(s).sets} séries · ${nf(sessionStats(s).volume, 0)} kg` })),
    ...all("weights").map((w) => ({ t: w.date, ic: "⚖︎", title: `${nf(w.kg, 1)} kg`, meta: "Pesagem" })),
    ...all("cardio").map((c) => ({ t: c.start, ic: CARDIO[c.kind]?.[1] || "🏃", title: `${CARDIO[c.kind]?.[0] || "Cardio"} · ${nf(c.km, 1)} km`, meta: `${Math.round(c.seconds / 60)} min` })),
  ].sort((a, b) => b.t - a.t).slice(0, 8);

  return shell(`
    <div class="grid g4">
      <div class="card kpi"><div class="label">⚖︎ Peso</div>
        <div class="value num">${last ? nf(last.kg, 1) : "—"}<small>kg</small></div>
        <div class="delta ${d7 == null ? "muted" : d7 <= 0 ? "good" : "warn"}">${d7 == null ? "sem referência de 7 dias" : (d7 > 0 ? "+" : "") + nf(d7, 1) + " kg em 7 dias"}</div>
        ${spark.length > 1 ? lineChart(spark, { h: 70, yFmt: () => "" }) : ""}</div>
      <div class="card kpi"><div class="label">🔥 Calorias hoje</div>
        <div class="value num">${nf(n.kcal, 0)}<small>/ ${nf(t.kcal, 0)}</small></div>${bar(n.kcal / t.kcal)}
        <div class="delta muted" style="margin-top:8px">${t.kcal - n.kcal > 0 ? "Faltam " + nf(t.kcal - n.kcal, 0) + " kcal" : "Meta atingida"}</div></div>
      <div class="card kpi"><div class="label">🥩 Proteína hoje</div>
        <div class="value num">${nf(n.protein, 0)}<small>/ ${nf(t.protein, 0)} g</small></div>${bar(n.protein / t.protein)}
        <div class="delta muted" style="margin-top:8px">${t.protein - n.protein > 0 ? "Faltam " + nf(t.protein - n.protein, 0) + " g" : "Meta atingida"}</div></div>
      <div class="card kpi"><div class="label">💧 Água hoje</div>
        <div class="value num">${nf(water / 1000, 1)}<small>/ ${nf(t.water / 1000, 1)} L</small></div>${bar(water / t.water)}
        <div class="delta muted" style="margin-top:8px">${t.water - water > 0 ? "Faltam ~" + Math.ceil((t.water - water) / 250) + " copos" : "Meta atingida"}</div></div>
    </div>
    <div class="grid g4" style="margin-top:16px">
      <div class="card kpi"><div class="label">🏋 Treinos (7 dias)</div><div class="value num">${wk.length}</div>
        <div class="delta muted">${nf(sum(wk, (s) => sessionStats(s).sets), 0)} séries</div></div>
      <div class="card kpi"><div class="label">🏃 Cardio (7 dias)</div><div class="value num">${nf(sum(all("cardio").filter((c) => c.start >= weekStart), (c) => c.km), 1)}<small>km</small></div>
        <div class="delta muted">${all("cardio").filter((c) => c.start >= weekStart).length} sessões</div></div>
      <div class="card kpi"><div class="label">☾ Sono médio</div><div class="value num">${sleepAvg ? nf(sleepAvg, 1) : "—"}<small>h</small></div>
        <div class="delta ${sleepAvg && sleepAvg < 7 ? "warn" : "muted"}">${sl.length} noites registradas</div></div>
      <div class="card kpi"><div class="label">☺ Humor médio</div><div class="value num">${moodAvg ? nf(moodAvg, 1) : "—"}<small>/ 5</small></div>
        <div class="delta muted">${md.length} registros</div></div>
    </div>
    <div class="section-title">Composição corporal</div>
    ${Object.keys(metrics).length ? `<div class="grid g4">${metricOrder.filter((k) => metrics[k]).map((k) => {
      const m = metrics[k];
      return `<div class="card kpi"><div class="label">${esc(m.title)}</div><div class="value num">${nf(m.value, Math.min(m.digits ?? 1, 2))}<small>${esc(m.unit)}</small></div>${m.status ? `<span class="badge">${esc(m.status)}</span>` : ""}</div>`;
    }).join("")}</div><div class="tiny muted" style="margin-top:8px">Calculado no iPhone a partir da pesagem de ${summary?.metricsDate ? fmtDate(summary.metricsDate, { day: "2-digit", month: "long" }) : "—"}.</div>`
      : `<div class="card empty">A composição aparece quando o iPhone sincronizar uma pesagem.</div>`}
    <div class="grid g2" style="margin-top:16px">
      <div class="card"><h3>Hoje por refeição</h3>${MEALS.map(([id, label, ic]) => {
        const f = dayFoods(today).filter((x) => x.meal === id);
        return f.length ? `<div class="item"><div class="avatar">${ic}</div><div class="grow"><div class="title">${label}</div><div class="meta">${f.map((x) => esc(x.name)).join(", ")}</div></div><b class="num">${nf(sum(f, (x) => x.nutrients?.kcal), 0)} kcal</b></div>` : "";
      }).join("") || `<div class="empty small">Nada registrado hoje.</div>`}</div>
      <div class="card"><h3>Atividade recente</h3><div class="list">${recent.map((r) => `<div class="item"><div class="avatar">${r.ic}</div><div class="grow"><div class="title">${esc(r.title)}</div><div class="meta">${esc(r.meta)}</div></div><span class="tiny muted">${fmtDate(r.t)} ${fmtTime(r.t)}</span></div>`).join("") || `<div class="empty small">Sem registros ainda.</div>`}</div></div>
    </div>`, "Painel");
}

function viewCorpo() {
  const ws = sorted("weights", "date");
  const from = weightRange ? Date.now() - weightRange * DAY : 0;
  const pts = ws.filter((w) => w.date >= from).map((w) => ({ x: w.date, y: w.kg }));
  const kgs = pts.map((p) => p.y);
  const ms = sorted("measurements", "date");
  const PARTS = [["waist", "Cintura"], ["abdomen", "Abdômen"], ["hip", "Quadril"], ["chest", "Peitoral"], ["shoulders", "Ombros"],
    ["armR", "Braço D"], ["armL", "Braço E"], ["thighR", "Coxa D"], ["thighL", "Coxa E"], ["calfR", "Panturrilha D"], ["neck", "Pescoço"]];
  const rows = [...ws].reverse().slice(0, 60);
  return shell(`
    <div class="card"><h3>Peso<span class="right"><span class="seg" id="range">${[[30, "30d"], [90, "90d"], [365, "1 ano"], [0, "Tudo"]].map(([v, l]) => `<button data-r="${v}" class="${weightRange === v ? "on" : ""}">${l}</button>`).join("")}</span></span></h3>
      ${lineChart(pts, { h: 240, avg: movingAvg(pts) })}
      <div class="grid g4" style="margin-top:12px">
        <div><div class="tiny muted">Atual</div><b class="num">${kgs.length ? nf(kgs.at(-1), 1) + " kg" : "—"}</b></div>
        <div><div class="tiny muted">Variação no período</div><b class="num">${kgs.length > 1 ? (kgs.at(-1) - kgs[0] > 0 ? "+" : "") + nf(kgs.at(-1) - kgs[0], 1) + " kg" : "—"}</b></div>
        <div><div class="tiny muted">Mínimo / máximo</div><b class="num">${kgs.length ? nf(Math.min(...kgs), 1) + " / " + nf(Math.max(...kgs), 1) : "—"}</b></div>
        <div><div class="tiny muted">Pesagens</div><b class="num">${kgs.length}</b></div>
      </div>
      <div class="tiny muted" style="margin-top:8px">Linha tracejada: média móvel de 7 pesagens.</div></div>
    <div class="grid g2" style="margin-top:16px">
      <div class="card"><h3>Pesagens</h3><div class="scroll"><table><thead><tr><th>Data</th><th>Peso</th><th>Δ</th><th>Obs.</th></tr></thead><tbody>
        ${rows.map((w, i) => { const prev = rows[i + 1]; const d = prev ? w.kg - prev.kg : null;
          return `<tr><td>${fmtDate(w.date, { day: "2-digit", month: "short", year: "2-digit" })} <span class="muted tiny">${fmtTime(w.date)}</span></td><td class="num"><b>${nf(w.kg, 2)}</b></td><td class="num ${d == null ? "" : d <= 0 ? "good" : "warn"}">${d == null ? "" : (d > 0 ? "+" : "") + nf(d, 2)}</td><td class="muted small">${esc(w.note || "")}</td></tr>`; }).join("") || `<tr><td colspan="4" class="empty">Sem pesagens.</td></tr>`}
      </tbody></table></div></div>
      <div class="card"><h3>Medidas (cm)</h3>${ms.length ? `<div class="scroll"><table><thead><tr><th>Parte</th><th>Última</th><th>Primeira</th><th>Δ</th></tr></thead><tbody>
        ${PARTS.map(([k, l]) => { const vals = ms.filter((m) => m[k] != null); if (!vals.length) return "";
          const a = vals[0][k], b = vals.at(-1)[k];
          return `<tr><td>${l}</td><td class="num"><b>${nf(b, 1)}</b></td><td class="num muted">${nf(a, 1)}</td><td class="num">${vals.length > 1 ? (b - a > 0 ? "+" : "") + nf(b - a, 1) : ""}</td></tr>`; }).join("")}
      </tbody></table></div><div class="tiny muted">${ms.length} medição(ões), a última em ${fmtDate(ms.at(-1).date, { day: "2-digit", month: "long" })}.</div>` : `<div class="empty small">Sem medidas registradas.</div>`}</div>
    </div>`, "Corpo", `${ws.length} pesagens no total`);
}

function viewAlimentacao() {
  const t = targets();
  const list = dayFoods(foodDay);
  const n = nut(list);
  const water = waterOn(foodDay);
  const days = Array.from({ length: 14 }, (_, i) => day(Date.now() - (13 - i) * DAY));
  const kcalDays = days.map((d) => ({ y: nut(dayFoods(d)).kcal, label: fmtDate(d), short: new Date(d).getDate(),
    color: d === day(foodDay) ? "var(--accent2)" : "var(--accent)" }));
  const isToday = day(foodDay) === day(Date.now());
  const top = Object.entries(all("foods").filter((f) => f.date >= Date.now() - 30 * DAY).reduce((m, f) => { m[f.name] = (m[f.name] || 0) + 1; return m; }, {}))
    .sort((a, b) => b[1] - a[1]).slice(0, 8);
  const macro = (label, v, goal, unit) => `<div class="macro"><div class="row"><span>${label}</span><span class="num"><b>${nf(v, 0)}</b> / ${nf(goal, 0)} ${unit}</span></div>${bar(v / goal)}</div>`;
  return shell(`
    <div class="card" style="display:flex;align-items:center;gap:12px;flex-wrap:wrap">
      <button class="btn" data-day="-1">‹</button>
      <b style="min-width:200px;text-align:center">${isToday ? "Hoje" : fmtDate(foodDay, { weekday: "long", day: "2-digit", month: "long" })}</b>
      <button class="btn" data-day="1" ${isToday ? "disabled" : ""}>›</button>
      ${isToday ? "" : `<button class="btn" data-day="0">Hoje</button>`}
    </div>
    <div class="grid g3" style="margin-top:16px">
      <div class="card" style="display:flex;gap:18px;align-items:center">${ring(n.kcal / t.kcal, nf(n.kcal, 0), "de " + nf(t.kcal, 0) + " kcal")}
        <div class="grow small"><div class="muted">${t.kcal - n.kcal >= 0 ? "Restam" : "Passou"}</div><b class="num" style="font-size:20px">${nf(Math.abs(t.kcal - n.kcal), 0)} kcal</b>
        <div class="muted" style="margin-top:8px">Água: <b class="num">${nf(water, 0)}</b> / ${nf(t.water, 0)} ml</div></div></div>
      <div class="card span2"><h3>Macronutrientes</h3>
        ${macro("Proteína", n.protein, t.protein, "g")}${macro("Carboidratos", n.carbs, t.carbs, "g")}${macro("Gorduras", n.fat, t.fat, "g")}${macro("Fibras", n.fiber, t.fiber, "g")}</div>
    </div>
    <div class="grid g2" style="margin-top:16px">
      <div class="card"><h3>Refeições</h3>${MEALS.map(([id, label, ic]) => {
        const f = list.filter((x) => x.meal === id).sort((a, b) => a.date - b.date);
        if (!f.length) return "";
        return `<div class="section-title" style="margin-top:8px">${ic} ${label} <span class="muted" style="text-transform:none;letter-spacing:0">· ${nf(sum(f, (x) => x.nutrients?.kcal), 0)} kcal</span></div>
          ${f.map((x) => `<div class="item"><div class="grow"><div class="title">${esc(x.name)}</div><div class="meta num">${nf(x.grams, 0)} g · P ${nf(x.nutrients?.protein, 0)} · C ${nf(x.nutrients?.carbs, 0)} · G ${nf(x.nutrients?.fat, 0)}</div></div><b class="num">${nf(x.nutrients?.kcal, 0)}</b></div>`).join("")}`;
      }).join("") || `<div class="empty small">Nada registrado neste dia.</div>`}</div>
      <div class="grid">
        <div class="card"><h3>Calorias · 14 dias<span class="right tiny muted">tracejado = meta</span></h3>${barChart(kcalDays, { goal: t.kcal })}</div>
        <div class="card"><h3>Mais comidos · 30 dias</h3><div class="chips">${top.map(([k, v]) => `<span class="chip">${esc(k)} ×${v}</span>`).join("") || `<span class="muted small">—</span>`}</div></div>
      </div>
    </div>`, "Alimentação", `${list.length} alimentos neste dia`);
}

function viewTreinos() {
  const ss = all("workouts").filter((s) => s.end).sort((a, b) => b.start - a.start);
  const weeks = Array.from({ length: 12 }, (_, i) => {
    const end = Date.now() - (11 - i) * 7 * DAY, start = end - 7 * DAY;
    return { y: ss.filter((s) => s.start > start && s.start <= end).length, label: fmtDate(start), short: fmtDate(start, { day: "2-digit" }) };
  });
  const cardio = all("cardio").sort((a, b) => b.start - a.start);
  const routines = all("routines").sort((a, b) => (a.order || 0) - (b.order || 0));
  return shell(`
    <div class="grid g3">
      <div class="card kpi"><div class="label">Treinos no total</div><div class="value num">${ss.length}</div></div>
      <div class="card kpi"><div class="label">Volume (30 dias)</div><div class="value num">${nf(sum(ss.filter((s) => s.start >= Date.now() - 30 * DAY), (s) => sessionStats(s).volume) / 1000, 1)}<small>t</small></div></div>
      <div class="card kpi"><div class="label">Cardio (30 dias)</div><div class="value num">${nf(sum(cardio.filter((c) => c.start >= Date.now() - 30 * DAY), (c) => c.km), 1)}<small>km</small></div></div>
    </div>
    <div class="card" style="margin-top:16px"><h3>Treinos por semana · 12 semanas</h3>${barChart(weeks)}</div>
    <div class="grid g2" style="margin-top:16px">
      <div class="card"><h3>Histórico<span class="right tiny muted">toque para ver as séries</span></h3>
        ${ss.slice(0, 40).map((s) => { const st = sessionStats(s);
          return `<details class="session"><summary class="item"><div class="avatar">🏋</div><div class="grow"><div class="title">${esc(s.name)}</div>
            <div class="meta">${fmtDate(s.start, { weekday: "short", day: "2-digit", month: "short" })} · ${Math.round(st.minutes)} min · ${st.sets} séries</div></div>
            <b class="num">${nf(st.volume, 0)} kg</b></summary>
            <div class="sets">${(s.exercises || []).filter((e) => (e.sets || []).some((x) => x.done)).map((e) => `<div><b>${esc(EX[e.exerciseID] || e.exerciseID)}</b>
              <div class="chips" style="margin-top:4px">${e.sets.filter((x) => x.done).map((x) => `<span class="chip">${x.kind === "warmup" ? "aq · " : ""}${x.kg ? nf(x.kg, 1) + "kg × " : ""}${esc(x.reps || (x.minutes ? nf(x.minutes, 1) + " min" : ""))}</span>`).join("")}</div></div>`).join("")}</div></details>`;
        }).join("") || `<div class="empty small">Sem treinos sincronizados.</div>`}</div>
      <div class="grid">
        <div class="card"><h3>Cardio</h3>${cardio.slice(0, 12).map((c) => `<div class="item"><div class="avatar">${CARDIO[c.kind]?.[1] || "🏃"}</div><div class="grow"><div class="title">${CARDIO[c.kind]?.[0] || "Cardio"} · ${nf(c.km, 2)} km</div>
          <div class="meta">${fmtDate(c.start, { weekday: "short", day: "2-digit", month: "short" })} · ${Math.round(c.seconds / 60)} min${c.km ? " · " + Math.floor(c.seconds / c.km / 60) + "'" + String(Math.round(c.seconds / c.km % 60)).padStart(2, "0") + "\"/km" : ""}</div></div><b class="num">${nf(c.kcal, 0)} kcal</b></div>`).join("") || `<div class="empty small">Sem cardio.</div>`}</div>
        <div class="card"><h3>Rotinas</h3>${routines.map((r) => `<div class="item"><div class="grow"><div class="title">${esc(r.name)}</div><div class="meta">${(r.items || []).map((i) => esc(EX[i.exerciseID] || i.exerciseID)).join(" · ")}</div></div><span class="chip">${(r.items || []).length} ex.</span></div>`).join("") || `<div class="empty small">Sem rotinas.</div>`}</div>
      </div>
    </div>`, "Treinos");
}

function viewMente() {
  const md = sorted("moods", "date").filter((m) => m.date >= Date.now() - 60 * DAY);
  const byDay = {};
  for (const m of md) (byDay[day(m.date)] ||= []).push(m);
  const moodPts = Object.entries(byDay).map(([d, l]) => ({ x: +d, y: sum(l, (m) => m.mood) / l.length }));
  const sl = sorted("sleep", "wake").filter((s) => s.wake >= Date.now() - 14 * DAY);
  const sleepBars = sl.map((s) => ({ y: (s.wake - s.bedtime) / 3600000, label: fmtDate(s.wake), short: new Date(s.wake).getDate(),
    color: (s.wake - s.bedtime) / 3600000 >= 7 ? "var(--accent)" : "var(--warn)" }));
  const lastMoods = [...md].reverse().slice(0, 12);
  const face = (v) => ["", "😫", "😕", "😐", "🙂", "😄"][Math.round(v)] || "";
  return shell(`
    <div class="grid g2">
      <div class="card"><h3>Humor · 60 dias</h3>${lineChart(moodPts, { h: 200, yFmt: (v) => nf(v, 1) })}</div>
      <div class="card"><h3>Sono · 14 dias<span class="right tiny muted">tracejado = 7 h</span></h3>${barChart(sleepBars, { goal: 7, fmt: (v) => nf(v, 1) + " h" })}</div>
    </div>
    <div class="card" style="margin-top:16px"><h3>Registros recentes</h3><div class="scroll"><table><thead><tr><th>Quando</th><th>Humor</th><th>Energia</th><th>Estresse</th><th>Ansiedade</th><th>Nota</th></tr></thead><tbody>
      ${lastMoods.map((m) => `<tr><td>${fmtDate(m.date)} <span class="muted tiny">${fmtTime(m.date)}</span></td><td>${face(m.mood)} ${m.mood}</td><td class="num">${m.energy}</td><td class="num">${m.stress}</td><td class="num">${m.anxiety}</td><td class="muted small">${esc(m.note || "")}</td></tr>`).join("") || `<tr><td colspan="6" class="empty">Sem registros.</td></tr>`}
    </tbody></table></div></div>`, "Mente");
}

function viewConta() {
  const u = auth.currentUser;
  const providers = (u?.providerData || []).map((p) => p.providerId);
  const theme = localStorage.getItem("theme") || "system";
  const accent = +(localStorage.getItem("accent") || 0);
  return shell(`
    <div class="grid g2">
      <div class="card"><h3>Conta</h3>
        <div class="item"><div class="grow"><div class="title">${esc(u?.email || "")}</div><div class="meta">${u?.emailVerified ? "E-mail verificado" : "E-mail não verificado"}</div></div>
          ${u?.emailVerified ? "" : `<button class="btn" id="verify">Reenviar verificação</button>`}</div>
        <div class="item"><div class="grow"><div class="title">Google</div><div class="meta">${providers.includes("google.com") ? "Conectado" : "Não conectado"}</div></div>
          ${providers.includes("google.com") ? "" : `<button class="btn" id="linkg">Conectar Google</button>`}</div>
        <div class="item"><div class="grow"><div class="title">E-mail e senha</div><div class="meta">${providers.includes("password") ? "Ativo" : "Não definido"}</div></div></div>
        <div id="accmsg"></div>
        <button class="btn danger block" id="logout" style="margin-top:14px">Sair</button></div>
      <div class="card"><h3>Aparência</h3>
        <div class="field"><label>Tema</label><div class="seg" id="theme">${[["system", "Sistema"], ["light", "Claro"], ["dark", "Escuro"]].map(([v, l]) => `<button data-t="${v}" class="${theme === v ? "on" : ""}">${l}</button>`).join("")}</div></div>
        <div class="field"><label>Cor</label><div class="swatches">${ACCENTS.map(([a, b], i) => `<div class="swatch ${accent === i ? "on" : ""}" data-a="${i}" style="background:linear-gradient(135deg,${a},${b})"></div>`).join("")}</div></div>
      </div>
      <div class="card spanall"><h3>Sincronização</h3><p class="small muted" style="margin:0">
        Este site mostra o que o iPhone sincroniza (modo automático ou manual, em Central → Sincronização). Os dados ficam no Firebase, só na sua conta.
        Em breve: adicionar e editar registros por aqui.<br>Registros carregados: ${COLS.map((c) => `${c} ${store[c].size}`).join(" · ")}.</p></div>
    </div>`, "Conta");
}

// ---------------------------------------------------------------- login
let loginMode = "in";
let loginMsg = null;
function viewLogin() {
  return `<div class="login">
    <div class="hero"><h1>Gym</h1><p>Seu peso, alimentação, treinos e bem-estar — sincronizados com o iPhone, num painel limpo.</p></div>
    <div class="form"><div class="box">
      <h2 style="margin:0 0 18px">${loginMode === "in" ? "Entrar" : "Criar conta"}</h2>
      <button class="btn block" id="google"><b>G</b> Continuar com Google</button>
      <div class="or">ou com e-mail</div>
      <div class="field"><label>E-mail</label><input class="input" id="email" type="email" autocomplete="username"></div>
      <div class="field"><label>Senha</label><input class="input" id="pass" type="password" autocomplete="${loginMode === "in" ? "current-password" : "new-password"}"></div>
      <button class="btn primary block" id="submit">${loginMode === "in" ? "Entrar" : "Criar conta"}</button>
      <div style="display:flex;justify-content:space-between;margin-top:12px" class="small">
        <a href="#" id="toggle">${loginMode === "in" ? "Criar conta" : "Já tenho conta"}</a>
        ${loginMode === "in" ? `<a href="#" id="forgot">Esqueci a senha</a>` : ""}
      </div>
      ${loginMsg ? `<div class="msg ${loginMsg.ok ? "ok" : "err"}">${esc(loginMsg.text)}</div>` : ""}
    </div></div></div>`;
}

function authError(e) {
  const c = e.code || "";
  if (c.includes("invalid-credential") || c.includes("wrong-password") || c.includes("user-not-found")) return "E-mail ou senha incorretos.";
  if (c.includes("email-already-in-use")) return "Esse e-mail já tem conta. Use Entrar.";
  if (c.includes("weak-password")) return "Senha fraca: use pelo menos 6 caracteres.";
  if (c.includes("popup-closed")) return "Login cancelado.";
  if (c.includes("too-many-requests")) return "Muitas tentativas. Espere alguns minutos.";
  if (c.includes("operation-not-allowed")) return "Esse método de login não está ativado no Firebase.";
  if (c.includes("unauthorized-domain")) return "Domínio não autorizado no Firebase (Authentication → Configurações → Domínios autorizados).";
  return e.message || String(e);
}

async function googleSignIn() {
  try {
    await signInWithPopup(auth, new GoogleAuthProvider());
  } catch (e) {
    if (e.code === "auth/account-exists-with-different-credential") {
      // A conta já existe com e-mail e senha: entra com a senha e liga o Google à mesma conta.
      const email = e.customData?.email;
      const pass = prompt(`Já existe uma conta com ${email}. Digite a senha dela para ligar o Google à mesma conta:`);
      if (!pass) return;
      const cred = GoogleAuthProvider.credentialFromError(e);
      const r = await signInWithEmailAndPassword(auth, email, pass);
      if (cred) await linkWithCredential(r.user, cred);
    } else throw e;
  }
}

// ---------------------------------------------------------------- render
function render() {
  if (!authReady) return;
  const u = auth.currentUser;
  if (!u) { root.className = ""; root.innerHTML = viewLogin(); bindLogin(); return; }
  root.className = "";
  const p = page();
  root.innerHTML = { painel: viewPainel, corpo: viewCorpo, alimentacao: viewAlimentacao, treinos: viewTreinos, mente: viewMente, conta: viewConta }[p]();
  bindPage(p);
}

function bindLogin() {
  const $ = (id) => document.getElementById(id);
  $("toggle").onclick = (ev) => { ev.preventDefault(); loginMode = loginMode === "in" ? "up" : "in"; loginMsg = null; render(); };
  $("google").onclick = async () => { try { await googleSignIn(); } catch (e) { loginMsg = { text: authError(e) }; render(); } };
  $("submit").onclick = async () => {
    const email = $("email").value.trim(), pass = $("pass").value;
    try {
      if (loginMode === "in") await signInWithEmailAndPassword(auth, email, pass);
      else { const r = await createUserWithEmailAndPassword(auth, email, pass); await sendEmailVerification(r.user, { url: location.origin }); }
    } catch (e) { loginMsg = { text: authError(e) }; render(); }
  };
  $("pass").onkeydown = (e) => { if (e.key === "Enter") $("submit").click(); };
  const f = $("forgot");
  if (f) f.onclick = async (ev) => {
    ev.preventDefault();
    const email = $("email").value.trim();
    if (!email) { loginMsg = { text: "Digite o e-mail primeiro." }; render(); return; }
    try { await sendPasswordResetEmail(auth, email); loginMsg = { ok: true, text: "Enviamos um e-mail para redefinir a senha." }; }
    catch (e) { loginMsg = { text: authError(e) }; }
    render();
  };
}

function bindPage(p) {
  const q = (s) => document.querySelectorAll(s);
  if (p === "corpo") q("#range button").forEach((b) => b.onclick = () => { weightRange = +b.dataset.r; render(); });
  if (p === "alimentacao") q("[data-day]").forEach((b) => b.onclick = () => {
    const v = +b.dataset.day;
    foodDay = v === 0 ? day(Date.now()) : Math.min(day(Date.now()), foodDay + v * DAY);
    render();
  });
  if (p === "conta") {
    const $ = (id) => document.getElementById(id);
    const msg = (t, ok) => { $("accmsg").innerHTML = `<div class="msg ${ok ? "ok" : "err"}">${esc(t)}</div>`; };
    $("logout").onclick = () => signOut(auth);
    if ($("verify")) $("verify").onclick = async () => { try { await sendEmailVerification(auth.currentUser, { url: location.origin }); msg("E-mail enviado.", true); } catch (e) { msg(authError(e)); } };
    if ($("linkg")) $("linkg").onclick = async () => { try { await linkWithPopup(auth.currentUser, new GoogleAuthProvider()); render(); } catch (e) { msg(authError(e)); } };
    q("#theme button").forEach((b) => b.onclick = () => { localStorage.setItem("theme", b.dataset.t); applyTheme(); render(); });
    q("[data-a]").forEach((s) => s.onclick = () => { localStorage.setItem("accent", s.dataset.a); applyTheme(); render(); });
  }
}

let authReady = false;
onAuthStateChanged(auth, (u) => {
  authReady = true;
  COLS.forEach((c) => store[c].clear());
  summary = null; lastError = "";
  if (u) listen(u.uid); else { unsubs.forEach((x) => x()); unsubs = []; }
  render();
});
window.addEventListener("hashchange", render);
