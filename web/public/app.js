import { firebaseConfig } from "./config.js";
import { initializeApp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-app.js";
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut,
  GoogleAuthProvider, signInWithPopup, sendPasswordResetEmail, sendEmailVerification, linkWithPopup, linkWithCredential,
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-auth.js";
import {
  initializeFirestore, persistentLocalCache, persistentMultipleTabManager, collection, onSnapshot, doc,
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-firestore.js";

import { initEdit, addBtn, rowActions, fab, openForm } from "./edit.js";

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = initializeFirestore(app, { localCache: persistentLocalCache({ tabManager: persistentMultipleTabManager() }) });
const root = document.getElementById("app");
document.body.insertAdjacentHTML("afterbegin", `<div class="bgfx"><i></i><i></i><i></i><div class="grid"></div></div>`);

// ================================================================ tema
const ACCENTS = [["#ff3c84", "#8c50f1", "#ff8a4c"], ["#4fd69c", "#4d9eff", "#2bd3c4"], ["#33b3ff", "#5c5cf2", "#5ee0ea"],
  ["#ff8c4d", "#f24d8c", "#f5b83d"], ["#a885ff", "#f280d9", "#5ec8f5"], ["#f5b83d", "#ff8a4c", "#ff3c84"],
  ["#ff4d1a", "#ffb300", "#ff3c84"], ["#8c99ad", "#59667a", "#b3c0d1"]];
function applyTheme() {
  const t = localStorage.getItem("theme") || "dark";
  const dark = t === "dark" || (t === "system" && matchMedia("(prefers-color-scheme: dark)").matches);
  document.documentElement.dataset.theme = dark ? "dark" : "light";
  const [a, b, c] = ACCENTS[+(localStorage.getItem("accent") || 0)] || ACCENTS[0];
  const s = document.documentElement.style;
  s.setProperty("--brand", a); s.setProperty("--brand2", b); s.setProperty("--brand3", c);
}
applyTheme();
const editCtx = { db, auth, store: null, summary: () => summary, esc: (s) => esc(s), nf: (v, d) => nf(v, d) };
initEdit(editCtx);
matchMedia("(prefers-color-scheme: dark)").addEventListener("change", applyTheme);

// ================================================================ utilidades
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const nf = (v, d = 1) => (Number(v) || 0).toLocaleString("pt-BR", { minimumFractionDigits: d, maximumFractionDigits: d });
const DAY = 86400000;
const day = (ms) => { const d = new Date(ms); d.setHours(0, 0, 0, 0); return d.getTime(); };
const fmtDate = (ms, o = { day: "2-digit", month: "short" }) => new Date(ms).toLocaleDateString("pt-BR", o);
const fmtTime = (ms) => new Date(ms).toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
const rel = (ms) => {
  const s = (Date.now() - ms) / 1000;
  if (s < 60) return "agora";
  if (s < 3600) return `há ${Math.round(s / 60)} min`;
  if (s < 86400) return `há ${Math.round(s / 3600)} h`;
  return `há ${Math.round(s / 86400)} d`;
};
const sum = (a, f = (x) => x) => a.reduce((s, x) => s + (Number(f(x)) || 0), 0);
const avg = (a, f) => (a.length ? sum(a, f) / a.length : 0);
const clamp01 = (v) => Math.max(0, Math.min(1, Number.isFinite(v) ? v : 0));
const MEAL_ICON = { breakfast: "☕", morningSnack: "🍎", lunch: "🍛", afternoonSnack: "🥪", dinner: "🍝", supper: "🌙" };
const MEALS_DEFAULT = [["breakfast", "Café da manhã", .25], ["morningSnack", "Lanche da manhã", .1], ["lunch", "Almoço", .3],
  ["afternoonSnack", "Lanche da tarde", .1], ["dinner", "Jantar", .2], ["supper", "Ceia", .05]];
const CARDIO = { run: ["Corrida", "🏃"], walk: ["Caminhada", "🚶"], bike: ["Pedalada", "🚴"] };
const PRACTICE = { breathing: "Respiração", relaxation: "Relaxamento", meditation: "Meditação", focus: "Foco", outdoor: "Ar livre" };
let EXFILE = {};
fetch("data/exercises.json").then((r) => r.json()).then((j) => { EXFILE = j; scheduleRender(); }).catch(() => {});
const exName = (id) => summary?.exercises?.[id]?.n || EXFILE[id] || id;

// ================================================================ dados
const COLS = ["profile", "weights", "measurements", "foods", "water", "savedFoods", "workouts", "routines", "cardio",
  "moods", "sleep", "fasting", "practices", "gratitude", "habits", "habitLogs"];
const store = Object.fromEntries(COLS.map((c) => [c, new Map()]));
setTimeout(() => initEditStore(), 0);
function initEditStore() { editCtx.store = store; }
let summary = null;
let unsubs = [];
let lastServer = 0;
const pendingWrites = {};
const pendingTotal = () => Object.values(pendingWrites).reduce((a, b) => a + b, 0);
let loaded = new Set();

function listen(uid) {
  unsubs.forEach((u) => u());
  loaded = new Set();
  unsubs = COLS.map((c) => onSnapshot(collection(db, "users", uid, c), { includeMetadataChanges: true }, (snap) => {
    loaded.add(c);
    pendingWrites[c] = snap.docs.filter((d) => d.metadata.hasPendingWrites).length;
    snap.docChanges().forEach((ch) => {
      const v = ch.doc.data();
      if (ch.type === "removed" || v.deleted) { store[c].delete(ch.doc.id); return; }
      let data = {};
      try { data = JSON.parse(v.data || "{}"); } catch { /* registro inválido */ }
      store[c].set(ch.doc.id, { id: ch.doc.id, updated: v.updated, ...data });
      const s = v.server?.toMillis?.() || 0;
      if (s > lastServer) lastServer = s;
    });
    scheduleRender();
  }, (err) => showError(err)));
  unsubs.push(onSnapshot(doc(db, "users", uid, "meta", "summary"), (d) => {
    loaded.add("summary");
    if (d.exists()) { try { summary = { ...JSON.parse(d.data().data || "{}"), updated: d.data().updated }; } catch { summary = null; } }
    scheduleRender();
  }, (err) => showError(err)));
}
const all = (c) => [...store[c].values()];
const sorted = (c, key) => all(c).sort((a, b) => (a[key] || 0) - (b[key] || 0));

let queued = false;
function scheduleRender() {
  if (queued) return;
  queued = true;
  requestAnimationFrame(() => { queued = false; render(); });
}
let lastError = "";
function showError(e) {
  lastError = e.code === "permission-denied" ? "Sem permissão para ler os dados: confira as regras do Firestore." : (e.message || String(e));
  scheduleRender();
}

// ================================================================ cálculos (iguais aos do iPhone)
/** Metas vêm sempre do iPhone. Sem resumo, nada é inventado. */
function targets() { return summary?.targets || null; }
function meals() {
  return summary?.meals?.length ? summary.meals.map((m) => [m.id, m.label, m.share]) : MEALS_DEFAULT;
}
const foodsOn = (ms) => all("foods").filter((f) => day(f.date) === day(ms));
const workoutsOn = (ms) => all("workouts").filter((s) => s.end && day(s.start) === day(ms));
/** Valor de um nutriente num registro (mesmos nomes do app: nutrients, micros e extras). */
const nv = (f, id) => (id === "kcal" ? f.nutrients?.kcal : (f.nutrients?.[id] ?? f.micros?.[id] ?? f.extras?.[id])) || 0;
const total = (list, id) => sum(list, (f) => nv(f, id));
/** Meta de calorias do dia, somando os treinos se essa opção estiver ligada no iPhone. */
function kcalGoal(ms) {
  const t = targets(); if (!t) return null;
  return t.kcal + (summary?.addWorkoutKcal ? sum(workoutsOn(ms), (s) => s.kcal) : 0);
}
const waterOn = (ms) => sum(all("water").filter((w) => day(w.date) === day(ms)), (w) => w.ml);
function sessionStats(s) {
  const ex = Array.isArray(s.exercises) ? s.exercises : [];
  const work = ex.flatMap((e) => (e.sets || []).filter((x) => x.done && x.kind !== "warmup"));
  return {
    sets: s.sets ?? work.length, volume: s.volume ?? sum(work, (x) => (x.kg || 0) * (x.reps || 0)), kcal: s.kcal || 0,
    minutes: s.end ? (s.end - s.start) / 60000 : 0, exercises: ex.filter((e) => (e.sets || []).some((x) => x.done)).length,
  };
}
const movingAvg = (pts, n = 7) => pts.map((p, i) => { const w = pts.slice(Math.max(0, i - n + 1), i + 1); return { x: p.x, y: avg(w, (q) => q.y) }; });
const sleepHours = (s) => (s.wake - s.bedtime) / 3600000;

// ================================================================ gráficos
function lineChart(points, { h = 200, avgLine = null, yFmt = (v) => nf(v, 1), goal = null } = {}) {
  if (points.length < 2) return `<div class="empty">Poucos dados para o gráfico.</div>`;
  const W = 640, pad = { l: 44, r: 12, t: 12, b: 24 };
  const ys = points.map((p) => p.y).concat(avgLine ? avgLine.map((p) => p.y) : [], goal != null ? [goal] : []);
  let y0 = Math.min(...ys), y1 = Math.max(...ys);
  if (y1 - y0 < 1e-6) { y0 -= 1; y1 += 1; }
  const m = (y1 - y0) * 0.14; y0 -= m; y1 += m;
  const xs = points.map((p) => p.x), x0 = Math.min(...xs), x1 = Math.max(...xs);
  const X = (x) => pad.l + ((x - x0) / Math.max(x1 - x0, 1)) * (W - pad.l - pad.r);
  const Y = (y) => pad.t + (1 - (y - y0) / (y1 - y0)) * (h - pad.t - pad.b);
  const path = (ps) => ps.map((p, i) => `${i ? "L" : "M"}${X(p.x).toFixed(1)},${Y(p.y).toFixed(1)}`).join("");
  const area = `${path(points)}L${X(points.at(-1).x)},${h - pad.b}L${X(points[0].x)},${h - pad.b}Z`;
  const id = "g" + Math.random().toString(36).slice(2, 8);
  const last = points.at(-1);
  return `<svg class="chart" viewBox="0 0 ${W} ${h}">
    <defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="var(--brand)" stop-opacity=".32"/><stop offset="1" stop-color="var(--brand)" stop-opacity="0"/></linearGradient>
    <linearGradient id="${id}s" x1="0" x2="1"><stop offset="0" stop-color="var(--brand)"/><stop offset="1" stop-color="var(--brand2)"/></linearGradient></defs>
    <g class="gridl">${[0, .5, 1].map((t) => y0 + (y1 - y0) * t).map((t) => `<line x1="${pad.l}" x2="${W - pad.r}" y1="${Y(t)}" y2="${Y(t)}"/><text x="${pad.l - 8}" y="${Y(t) + 4}" text-anchor="end">${yFmt(t)}</text>`).join("")}</g>
    ${goal != null ? `<line x1="${pad.l}" x2="${W - pad.r}" y1="${Y(goal)}" y2="${Y(goal)}" stroke="var(--good)" stroke-dasharray="5 5"/>` : ""}
    <path d="${area}" fill="url(#${id})"/>
    <path class="line" d="${path(points)}" fill="none" stroke="url(#${id}s)" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round"/>
    ${avgLine && avgLine.length > 1 ? `<path d="${path(avgLine)}" fill="none" stroke="var(--subtle)" stroke-width="1.5" stroke-dasharray="4 4"/>` : ""}
    <circle cx="${X(last.x)}" cy="${Y(last.y)}" r="5" fill="var(--brand)" stroke="var(--bg)" stroke-width="2"/>
    <text x="${pad.l}" y="${h - 4}">${fmtDate(x0)}</text><text x="${W - pad.r}" y="${h - 4}" text-anchor="end">${fmtDate(x1)}</text>
  </svg>`;
}

function barChart(items, { h = 170, goal = null, fmt = (v) => nf(v, 0) } = {}) {
  if (!items.length) return `<div class="empty">Sem dados.</div>`;
  const W = 640, pad = { l: 6, r: 6, t: 14, b: 24 };
  const max = Math.max(...items.map((i) => i.y), goal || 0, 1) * 1.12;
  const bw = (W - pad.l - pad.r) / items.length;
  const Y = (v) => pad.t + (1 - v / max) * (h - pad.t - pad.b);
  return `<svg class="chart" viewBox="0 0 ${W} ${h}">
    <defs><linearGradient id="bg1" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="var(--brand)"/><stop offset="1" stop-color="var(--brand2)"/></linearGradient></defs>
    ${goal ? `<line x1="${pad.l}" x2="${W - pad.r}" y1="${Y(goal)}" y2="${Y(goal)}" stroke="var(--good)" stroke-dasharray="5 5"/>` : ""}
    ${items.map((it, i) => {
      const x = pad.l + i * bw + bw * .2, w = bw * .6, y = Y(it.y);
      return `<rect class="b" style="animation-delay:${i * 25}ms" x="${x}" y="${y}" width="${w}" height="${Math.max(0, h - pad.b - y)}" rx="6" fill="${it.color || "url(#bg1)"}" opacity="${it.y ? 1 : .2}"><title>${esc(it.label)}: ${fmt(it.y)}</title></rect>
        <text x="${x + w / 2}" y="${h - 7}" text-anchor="middle">${esc(it.short ?? "")}</text>`;
    }).join("")}
  </svg>`;
}

function ring(p, label, sub, size = 132) {
  const r = 46, c = 2 * Math.PI * r, v = clamp01(p);
  const id = "r" + Math.random().toString(36).slice(2, 7);
  return `<div class="ring" style="width:${size}px;height:${size}px">
    <svg viewBox="0 0 110 110" width="${size}" height="${size}"><defs><linearGradient id="${id}"><stop offset="0" stop-color="var(--brand)"/><stop offset="1" stop-color="var(--brand2)"/></linearGradient></defs>
      <circle cx="55" cy="55" r="${r}" fill="none" stroke="var(--surface-2)" stroke-width="10"/>
      <circle class="fg" cx="55" cy="55" r="${r}" fill="none" stroke="url(#${id})" stroke-width="10" stroke-linecap="round" stroke-dasharray="${c * v} ${c}" transform="rotate(-90 55 55)"/></svg>
    <div class="center"><b>${label}</b><span class="tiny muted">${sub}</span></div></div>`;
}
const bar = (p, tone = "") => `<div class="bar ${tone}"><i style="width:${(clamp01(p) * 100).toFixed(1)}%"></i></div>`;
const head = (title, right = "") => `<div class="card-head"><span class="eyebrow">${title}</span>${right ? `<span class="right">${right}</span>` : ""}</div>`;
const kpi = (icon, label, value, unit, delta = "", extra = "") => `<div class="card kpi hover">
  <div class="label"><span class="icon-bubble">${icon}</span>${label}</div><div class="value">${value}${unit ? `<small>${unit}</small>` : ""}</div>
  ${delta ? `<div class="delta">${delta}</div>` : ""}${extra}</div>`;
const section = (t) => `<div class="section"><span class="eyebrow">${t}</span><span class="line"></span></div>`;
const noTargets = `<div class="msg info">As metas vêm do iPhone. Abra o app com a sincronização ligada para elas aparecerem aqui.</div>`;

// ================================================================ telas
const ROUTES = [["painel", "Painel", "◉"], ["corpo", "Corpo", "⚖︎"], ["alimentacao", "Alimentação", "🍽"],
  ["treinos", "Treinos", "🏋"], ["mente", "Mente", "☾"], ["conta", "Conta", "⚙︎"]];
const ACTIONS = {
  painel: [["weight", "Pesagem"], ["food", "Alimento"], ["water", "Água"], ["workout", "Treino"], ["mood", "Humor"]].map(([k, l]) => addBtn(k, l)).join(""),
  corpo: [["weight", "Pesagem"], ["measure", "Medidas"], ["profile", "Perfil e metas"]].map(([k, l]) => addBtn(k, l)).join(""),
  alimentacao: [["food", "Alimento"], ["water", "Água"]].map(([k, l]) => addBtn(k, l)).join("")
    + [250, 500].map((m) => `<button class="btn sm" data-act="water" data-ml="${m}">💧 +${m} ml</button>`).join(""),
  treinos: [["workout", "Treino"], ["cardio", "Cardio"]].map(([k, l]) => addBtn(k, l)).join(""),
  mente: [["mood", "Humor"], ["sleep", "Sono"], ["gratitude", "Gratidão"]].map(([k, l]) => addBtn(k, l)).join(""),
};
let foodDay = day(Date.now());
let weightRange = 90;
let microGroup = "Vitaminas";
const page = () => { const h = location.hash.replace("#/", ""); return ROUTES.some((r) => r[0] === h) ? h : "painel"; };

function shell(content, title, sub = "") {
  const p = page();
  const nav = (cls) => ROUTES.map(([id, label, ic]) => `<a href="#/${id}" class="${p === id ? "on" : ""}"><span class="ic">${ic}</span>${label}</a>`).join("");
  return `<div class="shell">
    <aside class="side"><div class="panel glass">
      <div class="brand"><div class="logo">${esc(summary?.emoji || "🏋️")}</div>Gym</div>
      <nav class="nav">${nav()}</nav>
      <div class="foot">${esc(auth.currentUser?.email || "")}<br>${lastServer ? "Último dado " + rel(lastServer) : "Sem dados ainda"}</div>
    </div></aside>
    <main class="main">
      <div class="top reveal"><div><span class="eyebrow">${esc(summary?.profileName || "Gym")}</span><h1 class="display" style="margin-top:12px">${title}</h1>${sub ? `<div class="sub">${sub}</div>` : ""}</div>
        <span style="display:flex;gap:8px;flex-wrap:wrap">${!navigator.onLine ? `<span class="badge warn">Offline${pendingTotal() ? ` · ${pendingTotal()} para enviar` : ""}</span>` : pendingTotal() ? `<span class="badge warn">Enviando ${pendingTotal()}…</span>` : ""}
        <span class="badge">${summary?.updated ? `<span class="live"></span>iPhone ${rel(summary.updated)}` : "Aguardando o iPhone"}</span></span></div>
      ${lastError ? `<div class="msg err">${esc(lastError)}</div>` : ""}
      ${updateReady ? `<div class="msg info">Nova versão do site disponível. <a href="#" id="upd">Atualizar agora</a></div>` : ""}
      ${ACTIONS[page()] ? `<div class="chips" style="margin:-8px 0 18px">${ACTIONS[page()]}</div>` : ""}
      ${content}
    </main>
    <nav class="mobilebar glass">${nav()}</nav>
    ${fab()}
  </div>`;
}

function viewPainel() {
  const t = targets();
  const now = Date.now(), weekStart = now - 7 * DAY;
  const ws = sorted("weights", "date"), last = ws.at(-1);
  const ref7 = [...ws].reverse().find((w) => w.date <= now - 7 * DAY);
  const d7 = last && ref7 ? last.kg - ref7.kg : null;
  const tf = foodsOn(now), kcal = total(tf, "kcal"), prot = total(tf, "protein"), water = waterOn(now), goal = kcalGoal(now);
  const wk = all("workouts").filter((s) => s.end && s.start >= weekStart);
  const sl = all("sleep").filter((s) => s.wake >= weekStart);
  const md = all("moods").filter((m) => m.date >= weekStart);
  const r = summary?.readiness;
  const greet = (() => { const h = new Date().getHours(); return h < 12 ? "Bom dia" : h < 18 ? "Boa tarde" : "Boa noite"; })();
  const name = (summary?.profileName || "").split(" ")[0];
  const metrics = summary?.metrics || {};
  const highlight = ["bodyFat", "smm", "visceralFat", "waterPercent", "bmr", "metabolicAge", "bmi", "lbm"];
  const recent = [
    ...all("foods").map((f) => ({ t: f.date, ic: MEAL_ICON[f.meal] || "🍽", title: f.name, meta: `${nf(f.grams, 0)} g · ${nf(nv(f, "kcal"), 0)} kcal` })),
    ...all("workouts").filter((s) => s.end).map((s) => ({ t: s.start, ic: "🏋", title: s.name, meta: `${sessionStats(s).sets} séries · ${nf(sessionStats(s).volume, 0)} kg` })),
    ...all("weights").map((w) => ({ t: w.date, ic: "⚖︎", title: `${nf(w.kg, 1)} kg`, meta: "Pesagem" })),
    ...all("cardio").map((c) => ({ t: c.start, ic: CARDIO[c.kind]?.[1] || "🏃", title: `${CARDIO[c.kind]?.[0] || "Cardio"} · ${nf(c.km, 1)} km`, meta: `${Math.round(c.seconds / 60)} min` })),
    ...all("water").map((w) => ({ t: w.date, ic: "💧", title: `${nf(w.ml, 0)} ml de água`, meta: "Água" })),
  ].sort((a, b) => b.t - a.t).slice(0, 9);

  return shell(`
    <div class="grid g3 stagger">
      <div class="card hero span2">
        <div><span class="eyebrow">Prontidão para treinar</span>
          ${r ? `<div class="score grad" style="margin-top:14px">${r.score}</div><div class="h3" style="margin-top:6px">${esc(r.advice)}</div>
            <div class="chips" style="margin-top:14px">${(r.factors || []).map((f) => `<span class="chip">${esc(f.label)}: ${esc(f.value)}</span>`).join("")}</div>`
            : `<div class="h3" style="margin-top:14px">Registre sono ou humor no iPhone para ver sua nota de hoje.</div>`}
        </div>
        <div>${goal ? ring(kcal / goal, nf(kcal, 0), `de ${nf(goal, 0)} kcal`, 170) : ""}</div>
      </div>
      ${kpi("⚖︎", "Peso", last ? nf(last.kg, 1) : "—", "kg",
        `<span class="${d7 == null ? "" : d7 <= 0 ? "good" : "warn"}">${d7 == null ? "Sem referência de 7 dias" : (d7 > 0 ? "+" : "") + nf(d7, 1) + " kg em 7 dias"}</span>`,
        ws.length > 1 ? lineChart(ws.filter((w) => w.date >= now - 30 * DAY).map((w) => ({ x: w.date, y: w.kg })), { h: 90, yFmt: () => "" }) : "")}
    </div>
    ${t ? "" : noTargets}
    <div class="gap"></div>
    <div class="grid g4 stagger">
      ${kpi("🥩", "Proteína hoje", nf(prot, 0), t ? `/ ${nf(t.protein, 0)} g` : "g", t ? (t.protein - prot > 0 ? `Faltam ${nf(t.protein - prot, 0)} g` : "Meta atingida") : "", t ? bar(prot / t.protein) : "")}
      ${kpi("💧", "Água hoje", nf(water / 1000, 2), t ? `/ ${nf(t.water / 1000, 1)} L` : "L", t ? (t.water - water > 0 ? `Faltam ~${Math.ceil((t.water - water) / 250)} copos` : "Meta atingida") : "", t ? bar(water / t.water) : "")}
      ${kpi("🏋", "Treinos · 7 dias", wk.length, "", `${nf(sum(wk, (s) => sessionStats(s).sets), 0)} séries · ${nf(sum(wk, (s) => s.kcal), 0)} kcal`)}
      ${kpi("☾", "Sono médio · 7 dias", sl.length ? nf(avg(sl, sleepHours), 1) : "—", "h", `${sl.length} noites · humor ${md.length ? nf(avg(md, (m) => m.mood), 1) : "—"}/5`)}
    </div>
    ${section("Composição corporal")}
    ${Object.keys(metrics).length ? `<div class="grid g4 stagger">${highlight.filter((k) => metrics[k]).map((k) => {
      const m = metrics[k];
      return kpi("◆", esc(m.title), nf(m.value, Math.min(m.digits ?? 1, 2)), esc(m.unit), m.status ? `<span class="badge brand">${esc(m.status)}</span>` : "");
    }).join("")}</div><div class="tiny subtle" style="margin-top:10px">Calculado no iPhone com a pesagem de ${summary?.metricsDate ? fmtDate(summary.metricsDate, { day: "2-digit", month: "long" }) : "—"}. Todas as métricas em Corpo.</div>`
      : `<div class="card empty">A composição aparece quando o iPhone sincronizar uma pesagem.</div>`}
    <div class="grid g2" style="margin-top:16px">
      <div class="card">${head("Hoje por refeição", goal ? `<span class="tiny muted num">${nf(kcal, 0)} / ${nf(goal, 0)} kcal</span>` : "")}
        ${meals().map(([id, label, share]) => {
          const f = tf.filter((x) => x.meal === id); const k = total(f, "kcal");
          return `<div class="item"><div class="avatar">${MEAL_ICON[id] || "🍽"}</div><div class="grow"><div class="title">${esc(label)}</div>
            <div class="meta">${f.length ? f.map((x) => esc(x.name)).join(", ") : "—"}</div></div>
            <div style="text-align:right"><b class="num">${nf(k, 0)}</b>${goal ? `<div class="tiny subtle num">/${nf(goal * share, 0)}</div>` : ""}</div></div>`;
        }).join("")}</div>
      <div class="card">${head("Atividade recente")}<div class="list">${recent.map((x) => `<div class="item"><div class="avatar">${x.ic}</div><div class="grow"><div class="title">${esc(x.title)}</div><div class="meta">${esc(x.meta)}</div></div><span class="tiny subtle num">${fmtDate(x.t)} ${fmtTime(x.t)}</span></div>`).join("") || `<div class="empty">Sem registros ainda.</div>`}</div></div>
    </div>`, `${greet}${name ? ", " + esc(name) : ""}`, new Date().toLocaleDateString("pt-BR", { weekday: "long", day: "numeric", month: "long" }));
}

function viewCorpo() {
  const ws = sorted("weights", "date");
  const from = weightRange ? Date.now() - weightRange * DAY : 0;
  const pts = ws.filter((w) => w.date >= from).map((w) => ({ x: w.date, y: w.kg }));
  const kgs = pts.map((p) => p.y);
  const ms = sorted("measurements", "date");
  const PARTS = [["neck", "Pescoço"], ["shoulders", "Ombros"], ["chest", "Peitoral"], ["armR", "Braço direito"], ["armL", "Braço esquerdo"],
    ["forearmR", "Antebraço direito"], ["forearmL", "Antebraço esquerdo"], ["wrist", "Punho"], ["waist", "Cintura"], ["abdomen", "Abdômen"],
    ["hip", "Quadril"], ["thighR", "Coxa direita"], ["thighL", "Coxa esquerda"], ["calfR", "Panturrilha direita"], ["calfL", "Panturrilha esquerda"]];
  const metrics = summary?.metrics || {};
  const cats = {};
  for (const [k, m] of Object.entries(metrics)) (cats[m.category || "Outros"] ||= []).push([k, m]);
  const prof = summary?.profile;
  const goalKg = prof?.goalWeightKg;
  const rows = [...ws].reverse().slice(0, 80);
  return shell(`
    <div class="card reveal">${head("Peso", `<span class="seg" id="range">${[[30, "30d"], [90, "90d"], [365, "1 ano"], [0, "Tudo"]].map(([v, l]) => `<button data-r="${v}" class="${weightRange === v ? "on" : ""}">${l}</button>`).join("")}</span>`)}
      ${lineChart(pts, { h: 260, avgLine: movingAvg(pts), goal: goalKg })}
      <div class="grid g4" style="margin-top:14px">
        <div><div class="tiny subtle">Atual</div><b class="num">${kgs.length ? nf(kgs.at(-1), 1) + " kg" : "—"}</b></div>
        <div><div class="tiny subtle">No período</div><b class="num">${kgs.length > 1 ? (kgs.at(-1) - kgs[0] > 0 ? "+" : "") + nf(kgs.at(-1) - kgs[0], 1) + " kg" : "—"}</b></div>
        <div><div class="tiny subtle">Mín / máx</div><b class="num">${kgs.length ? nf(Math.min(...kgs), 1) + " / " + nf(Math.max(...kgs), 1) : "—"}</b></div>
        <div><div class="tiny subtle">Meta</div><b class="num">${goalKg ? nf(goalKg, 1) + " kg" : "—"}</b>${goalKg && kgs.length ? ` <span class="tiny muted">(faltam ${nf(Math.abs(kgs.at(-1) - goalKg), 1)})</span>` : ""}</div>
      </div><div class="tiny subtle" style="margin-top:8px">Tracejado cinza: média de 7 pesagens · verde: peso meta.</div></div>
    ${prof ? `<div class="gap"></div><div class="card">${head("Perfil")}<div class="grid g4">
      ${[["Idade", prof.age + " anos"], ["Sexo", prof.sex], ["Altura", nf(prof.heightCm, 0) + " cm"], ["Objetivo", prof.goal], ["Atividade", prof.activity]]
        .map(([k, v]) => `<div><div class="tiny subtle">${k}</div><b>${esc(v)}</b></div>`).join("")}</div></div>` : ""}
    ${Object.keys(cats).map((c) => `${section(esc(c))}<div class="grid g4 stagger">${cats[c].map(([, m]) =>
      kpi("◆", esc(m.title), nf(m.value, Math.min(m.digits ?? 1, 2)), esc(m.unit), m.status ? `<span class="badge brand">${esc(m.status)}</span>` : "")).join("")}</div>`).join("")
      || `${section("Métricas")}<div class="card empty">As métricas aparecem quando o iPhone sincronizar.</div>`}
    <div class="grid g2" style="margin-top:16px">
      <div class="card">${head("Pesagens", `<span class="tiny muted">${ws.length} no total</span>`)}<div class="scroll"><table><thead><tr><th>Data</th><th>Peso</th><th>Δ</th><th>Obs.</th><th></th></tr></thead><tbody>
        ${rows.map((w, i) => { const prev = rows[i + 1]; const d = prev ? w.kg - prev.kg : null;
          return `<tr><td>${fmtDate(w.date, { day: "2-digit", month: "short", year: "2-digit" })} <span class="subtle tiny">${fmtTime(w.date)}</span></td><td class="num"><b>${nf(w.kg, 2)}</b></td><td class="num ${d == null ? "" : d <= 0 ? "good" : "warn"}">${d == null ? "" : (d > 0 ? "+" : "") + nf(d, 2)}</td><td class="muted small">${esc(w.note || "")}</td><td>${rowActions("weight", "weights", w.id)}</td></tr>`; }).join("") || `<tr><td colspan="5" class="empty">Sem pesagens.</td></tr>`}
      </tbody></table></div></div>
      <div class="card">${head("Medidas (cm)")}${ms.length ? `<div class="scroll"><table><thead><tr><th>Parte</th><th>Última</th><th>Primeira</th><th>Δ</th></tr></thead><tbody>
        ${PARTS.map(([k, l]) => { const v = ms.filter((m) => m[k] != null); if (!v.length) return "";
          const a = v[0][k], b = v.at(-1)[k];
          return `<tr><td>${l}</td><td class="num"><b>${nf(b, 1)}</b></td><td class="num muted">${nf(a, 1)}</td><td class="num">${v.length > 1 ? (b - a > 0 ? "+" : "") + nf(b - a, 1) : ""}</td></tr>`; }).join("")}
      </tbody></table></div><div class="list" style="margin-top:10px">${[...ms].reverse().slice(0, 6).map((m) => `<div class="item"><div class="grow"><div class="title small">${fmtDate(m.date, { day: "2-digit", month: "long", year: "numeric" })}</div><div class="meta">${PARTS.filter(([k]) => m[k] != null).map(([k, l]) => `${l} ${nf(m[k], 1)}`).join(" · ")}</div></div>${rowActions("measure", "measurements", m.id)}</div>`).join("")}</div>` : `<div class="empty">Sem medidas registradas.</div>`}</div>
    </div>`, "Corpo", `${ws.length} pesagens · ${ms.length} medições`);
}

function viewAlimentacao() {
  const t = targets();
  const list = foodsOn(foodDay), goal = kcalGoal(foodDay);
  const kcal = total(list, "kcal"), water = waterOn(foodDay);
  const days = Array.from({ length: 14 }, (_, i) => day(Date.now() - (13 - i) * DAY));
  const isToday = day(foodDay) === day(Date.now());
  const top = Object.entries(all("foods").filter((f) => f.date >= Date.now() - 30 * DAY).reduce((m, f) => { m[f.name] = (m[f.name] || 0) + 1; return m; }, {}))
    .sort((a, b) => b[1] - a[1]).slice(0, 10);
  const macro = (label, id, g) => { const v = total(list, id); return `<div class="macro"><div class="row"><span>${label}</span><span class="num"><b>${nf(v, 0)}</b>${g ? ` / ${nf(g, 0)}` : ""} g</span></div>${g ? bar(v / g, v > g * 1.15 ? "warn" : "") : ""}</div>`; };
  const nutrients = summary?.nutrients || [];
  const groups = [...new Set(nutrients.map((n) => n.group))];
  const wt = sum(workoutsOn(foodDay), (s) => s.kcal);
  const waterDay = all("water").filter((w) => day(w.date) === day(foodDay)).sort((a, b) => a.date - b.date);
  const fasts = sorted("fasting", "start").reverse().slice(0, 6);
  return shell(`
    <div class="card reveal" style="display:flex;align-items:center;gap:12px;flex-wrap:wrap">
      <button class="btn sm" data-day="-1">‹</button>
      <b class="h3" style="min-width:220px;text-align:center">${isToday ? "Hoje" : fmtDate(foodDay, { weekday: "long", day: "2-digit", month: "long" })}</b>
      <button class="btn sm" data-day="1" ${isToday ? "disabled" : ""}>›</button>
      ${isToday ? "" : `<button class="btn sm" data-day="0">Hoje</button>`}
      <span class="right tiny muted" style="margin-left:auto">${list.length} alimentos</span>
    </div>
    ${t ? "" : noTargets}
    <div class="grid g3" style="margin-top:16px">
      <div class="card" style="display:flex;gap:20px;align-items:center">${goal ? ring(kcal / goal, nf(kcal, 0), `de ${nf(goal, 0)} kcal`) : ring(0, nf(kcal, 0), "kcal")}
        <div class="small"><div class="subtle">${goal ? (goal - kcal >= 0 ? "Restam" : "Passou") : ""}</div><b class="h3 num">${goal ? nf(Math.abs(goal - kcal), 0) + " kcal" : ""}</b>
        ${summary?.addWorkoutKcal && wt ? `<div class="tiny muted" style="margin-top:6px">Inclui +${nf(wt, 0)} kcal dos treinos</div>` : ""}
        ${summary?.calorieAdjust ? `<div class="tiny muted">Ajuste automático: ${summary.calorieAdjust > 0 ? "+" : ""}${nf(summary.calorieAdjust, 0)} kcal</div>` : ""}
        <div class="muted" style="margin-top:10px">💧 <b class="num">${nf(water, 0)}</b>${t ? ` / ${nf(t.water, 0)}` : ""} ml</div>${t ? bar(water / t.water) : ""}</div></div>
      <div class="card span2">${head("Macronutrientes")}
        ${macro("Proteína", "protein", t?.protein)}${macro("Carboidratos", "carbs", t?.carbs)}${macro("Gorduras", "fat", t?.fat)}${macro("Fibras", "fiber", t?.fiber)}
        <div class="chips">${[["Açúcares", "sugar", t?.sugarMax], ["Saturada", "saturated", t?.saturatedMax]].map(([l, id, mx]) => { const v = total(list, id); return `<span class="chip ${mx && v > mx ? "warn" : ""}">${l} ${nf(v, 0)}${mx ? "/" + nf(mx, 0) : ""} g</span>`; }).join("")}
          <span class="chip ${t?.sodiumMax && total(list, "sodium") > t.sodiumMax ? "warn" : ""}">Sódio ${nf(total(list, "sodium"), 0)}${t?.sodiumMax ? "/" + nf(t.sodiumMax, 0) : ""} mg</span></div></div>
    </div>
    <div class="grid g2" style="margin-top:16px">
      <div class="card">${head("Refeições")}${meals().map(([id, label, share]) => {
        const f = list.filter((x) => x.meal === id).sort((a, b) => a.date - b.date);
        const k = total(f, "kcal");
        return `<div style="margin-bottom:6px"><div class="item" style="border:0;padding-bottom:4px"><div class="avatar">${MEAL_ICON[id] || "🍽"}</div><div class="grow"><div class="title">${esc(label)}</div>
          ${goal ? bar(k / (goal * share)) : ""}</div><b class="num">${nf(k, 0)}${goal ? `<span class="tiny subtle"> / ${nf(goal * share, 0)}</span>` : ""}</b></div>
          ${f.map((x) => `<div class="item" style="padding-left:50px"><div class="grow"><div class="title" style="font-weight:500">${esc(x.name)}</div><div class="meta num">${nf(x.grams, 0)} g · P ${nf(nv(x, "protein"), 0)} · C ${nf(nv(x, "carbs"), 0)} · G ${nf(nv(x, "fat"), 0)}</div></div><span class="num">${nf(nv(x, "kcal"), 0)}</span>${rowActions("food", "foods", x.id)}</div>`).join("")}</div>`;
      }).join("")}</div>
      <div class="grid">
        <div class="card">${head("Calorias · 14 dias", goal ? `<span class="tiny muted">verde = meta</span>` : "")}${barChart(days.map((d) => ({ y: total(foodsOn(d), "kcal"), label: fmtDate(d), short: new Date(d).getDate(),
          color: d === day(foodDay) ? "var(--brand3)" : null })), { goal: targets()?.kcal })}</div>
        <div class="card">${head("Água do dia")}${waterDay.length ? `<div class="list">${waterDay.map((w) => `<div class="item"><div class="avatar">💧</div><div class="grow"><b class="num">${nf(w.ml, 0)} ml</b> <span class="muted small">${fmtTime(w.date)}</span></div>${rowActions("water", "water", w.id)}</div>`).join("")}</div>` : `<div class="empty">Sem água registrada.</div>`}</div>
        <div class="card">${head("Mais comidos · 30 dias")}<div class="chips">${top.map(([k, v]) => `<span class="chip">${esc(k)} ×${v}</span>`).join("") || `<span class="muted small">—</span>`}</div></div>
      </div>
    </div>
    ${section("Vitaminas, minerais e outros")}
    <div class="card">${nutrients.length ? `${head("Do dia", `<span class="seg" id="mg">${groups.map((g) => `<button data-g="${esc(g)}" class="${microGroup === g ? "on" : ""}">${esc(g)}</button>`).join("")}</span>`)}
      <div class="scroll"><table><thead><tr><th>Nutriente</th><th>Consumido</th><th>Recomendado</th><th style="width:34%">%</th></tr></thead><tbody>
      ${nutrients.filter((n) => n.group === microGroup).map((n) => { const v = total(list, n.id); const p = n.rec ? v / n.rec : 0;
        const tone = n.limit ? (v > n.rec ? "bad" : p > .8 ? "warn" : "good") : (n.max && v > n.max ? "bad" : p >= .9 ? "good" : n.min && v >= n.min ? "" : "warn");
        return `<tr><td>${esc(n.title)}${n.limit ? ` <span class="badge pixel">limite</span>` : ""}</td><td class="num"><b>${nf(v, v >= 100 ? 0 : 1)}</b> ${esc(n.unit)}</td><td class="num muted">${nf(n.rec, n.rec >= 100 ? 0 : 1)} ${esc(n.unit)}</td>
          <td><div style="display:flex;align-items:center;gap:8px">${bar(p, tone)}<span class="num tiny" style="min-width:40px">${Math.round(p * 100)}%</span></div></td></tr>`; }).join("")}
      </tbody></table></div><div class="tiny subtle" style="margin-top:8px">Referências personalizadas calculadas no iPhone (sexo, idade e metas). Alguns alimentos não têm todos os nutrientes analisados.</div>`
      : `<div class="empty">A tabela aparece quando o iPhone sincronizar o resumo.</div>`}</div>
    ${fasts.length ? `${section("Jejum")}<div class="card"><div class="list">${fasts.map((f) => { const h = ((f.end || Date.now()) - f.start) / 3600000;
      return `<div class="item"><div class="avatar">⏳</div><div class="grow"><div class="title">${nf(h, 1)} h de ${nf(f.goalHours, 0)} h</div><div class="meta">${fmtDate(f.start, { weekday: "short", day: "2-digit", month: "short" })} · ${fmtTime(f.start)}${f.end ? "" : " · em andamento"}</div></div>
        <span class="badge ${h >= f.goalHours ? "good" : ""}">${h >= f.goalHours ? "Completo" : Math.round(h / f.goalHours * 100) + "%"}</span></div>`; }).join("")}</div></div>` : ""}`,
  "Alimentação", isToday ? "Hoje" : fmtDate(foodDay, { day: "2-digit", month: "long" }));
}

function viewTreinos() {
  const ss = all("workouts").filter((s) => s.end).sort((a, b) => b.start - a.start);
  const now = Date.now();
  const weeks = Array.from({ length: 12 }, (_, i) => {
    const end = now - (11 - i) * 7 * DAY, start = end - 7 * DAY;
    return { y: ss.filter((s) => s.start > start && s.start <= end).length, label: fmtDate(start), short: fmtDate(start, { day: "2-digit" }) };
  });
  const cardio = all("cardio").sort((a, b) => b.start - a.start);
  const routines = all("routines").sort((a, b) => (a.order || 0) - (b.order || 0));
  const ms = summary?.muscleSets || [];
  const rec = (summary?.recovery || []).slice().sort((a, b) => a.pct - b.pct);
  const prs = summary?.prs || [];
  const st = summary?.stretch;
  const month = ss.filter((s) => s.start >= now - 30 * DAY);
  const pace = (c) => c.km ? `${Math.floor(c.seconds / c.km / 60)}'${String(Math.round(c.seconds / c.km % 60)).padStart(2, "0")}"/km` : "";
  return shell(`
    <div class="grid g4 stagger">
      ${kpi("🏋", "Treinos · 30 dias", month.length, "", `${ss.length} no total`)}
      ${kpi("📦", "Volume · 30 dias", nf(sum(month, (s) => sessionStats(s).volume) / 1000, 1), "t", `${nf(sum(month, (s) => sessionStats(s).sets), 0)} séries`)}
      ${kpi("🔥", "Calorias · 30 dias", nf(sum(month, (s) => s.kcal) + sum(cardio.filter((c) => c.start >= now - 30 * DAY), (c) => c.kcal), 0), "kcal", "treinos + cardio")}
      ${kpi("🏃", "Cardio · 30 dias", nf(sum(cardio.filter((c) => c.start >= now - 30 * DAY), (c) => c.km), 1), "km", `${cardio.filter((c) => c.start >= now - 30 * DAY).length} sessões`)}
    </div>
    <div class="grid g2" style="margin-top:16px">
      <div class="card">${head("Treinos por semana · 12 semanas")}${barChart(weeks)}</div>
      <div class="card">${head("Séries por músculo · 7 dias", `<span class="tiny muted">faixa ideal 10–20</span>`)}${ms.length ? ms.map((m) => `<div class="macro"><div class="row"><span>${esc(m.muscle)}</span><span class="num"><b>${nf(m.sets, 1)}</b></span></div>${bar(m.sets / 20, m.sets > 20 ? "bad" : m.sets >= 10 ? "good" : "warn")}</div>`).join("") : `<div class="empty">Sem treinos nos últimos 7 dias.</div>`}</div>
    </div>
    <div class="grid g2" style="margin-top:16px">
      <div class="card">${head("Recuperação muscular")}${rec.length ? `<div class="grid g2">${rec.map((r) => `<div class="macro"><div class="row"><span>${esc(r.muscle)}</span><span class="num tiny">${Math.round(r.pct * 100)}%</span></div>${bar(r.pct, r.pct >= .9 ? "good" : r.pct >= .6 ? "warn" : "bad")}</div>`).join("")}</div>` : `<div class="empty">Sem dados de recuperação.</div>`}</div>
      <div class="card">${head("Recordes (1RM estimado)")}${prs.length ? `<div class="list">${prs.map((p, i) => `<div class="item"><div class="avatar">${["🥇", "🥈", "🥉"][i] || "🏅"}</div><div class="grow"><div class="title">${esc(p.name)}</div><div class="meta num">${nf(p.kg, 1)} kg × ${p.reps} · ${fmtDate(p.date)}</div></div><b class="num">${nf(p.e1rm, 1)} kg</b></div>`).join("")}</div>` : `<div class="empty">Sem recordes ainda.</div>`}</div>
    </div>
    ${section("Histórico")}
    <div class="grid g2">
      <div class="card">${head("Treinos", `<span class="tiny muted">toque para ver as séries</span>`)}
        ${ss.slice(0, 50).map((s) => { const x = sessionStats(s);
          return `<details class="session"><summary class="item"><div class="avatar">🏋</div><div class="grow"><div class="title">${esc(s.name)}</div>
            <div class="meta">${fmtDate(s.start, { weekday: "short", day: "2-digit", month: "short" })} · ${Math.round(x.minutes)} min · ${x.sets} séries · ${nf(x.kcal, 0)} kcal</div></div>
            <b class="num">${nf(x.volume, 0)} kg</b>${rowActions("workout", "workouts", s.id)}</summary>
            <div class="sets">${(s.exercises || []).filter((e) => (e.sets || []).some((q) => q.done)).map((e) => `<div><b>${esc(exName(e.exerciseID))}</b>${e.note ? ` <span class="muted small">· ${esc(e.note)}</span>` : ""}
              <div class="chips" style="margin-top:6px">${e.sets.filter((q) => q.done).map((q) => `<span class="chip">${q.kind === "warmup" ? "aq · " : ""}${q.kg ? nf(q.kg, 1) + "kg × " : ""}${esc(q.reps || (q.minutes ? nf(q.minutes, 1) + " min" : ""))}${q.rpe ? " @" + nf(q.rpe, 1) : ""}</span>`).join("")}</div></div>`).join("")}
              ${s.note ? `<div class="muted small">📝 ${esc(s.note)}</div>` : ""}</div></details>`;
        }).join("") || `<div class="empty">Sem treinos sincronizados.</div>`}</div>
      <div class="grid">
        <div class="card">${head("Cardio")}${cardio.slice(0, 12).map((c) => `<div class="item"><div class="avatar">${CARDIO[c.kind]?.[1] || "🏃"}</div><div class="grow"><div class="title">${CARDIO[c.kind]?.[0] || "Cardio"} · ${nf(c.km, 2)} km</div>
          <div class="meta">${fmtDate(c.start, { weekday: "short", day: "2-digit", month: "short" })} · ${Math.round(c.seconds / 60)} min${pace(c) ? " · " + pace(c) : ""}${c.climbM ? " · ↑" + nf(c.climbM, 0) + " m" : ""}</div></div><b class="num">${nf(c.kcal, 0)} kcal</b>${rowActions("cardio", "cardio", c.id)}</div>`).join("") || `<div class="empty">Sem cardio.</div>`}</div>
        <div class="card">${head("Rotinas")}${routines.map((r) => `<div class="item"><div class="grow"><div class="title">${esc(r.name)}</div><div class="meta">${(r.items || []).map((i) => `${esc(exName(i.exerciseID))} ${i.sets}×${i.repsMin}${i.repsMax !== i.repsMin ? "–" + i.repsMax : ""}`).join(" · ")}</div></div><span class="badge">${(r.items || []).length} ex.</span></div>`).join("") || `<div class="empty">Sem rotinas.</div>`}</div>
        ${st ? `<div class="card">${head("Alongamentos")}<div class="grid g2"><div><div class="tiny subtle">Últimos 7 dias</div><b class="h3 num">${st.weekMinutes} min</b></div><div><div class="tiny subtle">Sequência</div><b class="h3 num">${st.streak} dias</b></div></div>
          ${st.conditions?.length ? `<div class="chips" style="margin-top:12px">${st.conditions.map((c) => `<span class="chip">${esc(c)}</span>`).join("")}</div>` : ""}
          ${(st.history || []).slice().reverse().slice(0, 5).map((h) => `<div class="item"><div class="grow"><div class="title">${esc(h.name)}</div><div class="meta">${fmtDate(h.date)} · ${Math.round(h.seconds / 60)} min</div></div></div>`).join("")}</div>` : ""}
      </div>
    </div>`, "Treinos", `${ss.length} treinos · ${cardio.length} sessões de cardio`);
}

function viewMente() {
  const md = sorted("moods", "date").filter((m) => m.date >= Date.now() - 60 * DAY);
  const byDay = {};
  for (const m of md) (byDay[day(m.date)] ||= []).push(m);
  const moodPts = Object.entries(byDay).map(([d, l]) => ({ x: +d, y: avg(l, (m) => m.mood) }));
  const sl = sorted("sleep", "wake").filter((s) => s.wake >= Date.now() - 14 * DAY);
  const face = (v) => ["", "😫", "😕", "😐", "🙂", "😄"][Math.round(v)] || "";
  const pr = sorted("practices", "date").filter((p) => p.date >= Date.now() - 30 * DAY);
  const prBy = {};
  for (const p of pr) prBy[p.kind] = (prBy[p.kind] || 0) + p.seconds / 60;
  const gr = sorted("gratitude", "date").reverse().slice(0, 6);
  const habits = all("habits").filter((h) => !h.archived).sort((a, b) => (a.order || 0) - (b.order || 0));
  const logs = new Set(all("habitLogs").map((l) => `${l.habit}|${day(l.day)}`));
  const days = Array.from({ length: 14 }, (_, i) => day(Date.now() - (13 - i) * DAY));
  const r = summary?.readiness;
  return shell(`
    <div class="grid g4 stagger">
      ${kpi("☺", "Humor médio · 7 dias", nf(avg(md.filter((m) => m.date >= Date.now() - 7 * DAY), (m) => m.mood), 1), "/ 5")}
      ${kpi("⚡", "Energia · 7 dias", nf(avg(md.filter((m) => m.date >= Date.now() - 7 * DAY), (m) => m.energy), 1), "/ 5")}
      ${kpi("☾", "Sono médio · 14 dias", sl.length ? nf(avg(sl, sleepHours), 1) : "—", "h", `qualidade ${sl.length ? nf(avg(sl, (s) => s.quality), 1) : "—"}/5`)}
      ${kpi("🧘", "Práticas · 30 dias", nf(sum(pr, (p) => p.seconds) / 60, 0), "min", `${pr.length} sessões`)}
    </div>
    ${r ? `<div class="gap"></div><div class="card">${head("Prontidão de hoje")}<div style="display:flex;align-items:center;gap:18px;flex-wrap:wrap"><b class="display grad">${r.score}</b><div><div class="h3">${esc(r.advice)}</div><div class="chips" style="margin-top:8px">${(r.factors || []).map((f) => `<span class="chip">${esc(f.label)}: ${esc(f.value)}</span>`).join("")}</div></div></div></div>` : ""}
    <div class="grid g2" style="margin-top:16px">
      <div class="card">${head("Humor · 60 dias")}${lineChart(moodPts, { h: 210 })}</div>
      <div class="card">${head("Sono · 14 dias", `<span class="tiny muted">verde = 7 h</span>`)}${barChart(sl.map((s) => ({ y: sleepHours(s), label: fmtDate(s.wake), short: new Date(s.wake).getDate(),
        color: sleepHours(s) >= 7 ? null : "var(--warn)" })), { goal: 7, fmt: (v) => nf(v, 1) + " h" })}</div>
    </div>
    ${habits.length ? `${section("Hábitos · 14 dias")}<div class="card"><div class="scroll"><div class="hgrid">
      <span></span>${days.map((d, i) => `<span class="tiny subtle num ${i < 7 ? "old" : ""}" style="text-align:center">${new Date(d).getDate()}</span>`).join("")}
      ${habits.map((h) => `<span class="title small">${esc(h.name)}</span>${days.map((d, i) => `<span class="c ${logs.has(`${h.uid}|${d}`) ? "on" : ""} ${i < 7 ? "old" : ""}"></span>`).join("")}`).join("")}
    </div></div></div>` : ""}
    <div class="grid g2" style="margin-top:16px">
      <div class="card">${head("Práticas · 30 dias")}${Object.keys(prBy).length ? Object.entries(prBy).map(([k, v]) => `<div class="macro"><div class="row"><span>${esc(PRACTICE[k] || k)}</span><span class="num">${nf(v, 0)} min</span></div>${bar(v / Math.max(...Object.values(prBy)))}</div>`).join("") : `<div class="empty">Sem práticas.</div>`}</div>
      <div class="card">${head("Gratidão")}${gr.map((g) => `<div class="item"><div class="avatar">🙏</div><div class="grow"><div class="meta">${fmtDate(g.date, { weekday: "short", day: "2-digit", month: "short" })}</div>${(g.items || []).map((i) => `<div>• ${esc(i)}</div>`).join("")}</div>${rowActions("gratitude", "gratitude", g.id)}</div>`).join("") || `<div class="empty">Sem registros.</div>`}</div>
    </div>
    <div class="card" style="margin-top:16px">${head("Sono recente")}<div class="list">${[...sl].reverse().slice(0, 8).map((s) => `<div class="item"><div class="avatar">☾</div><div class="grow"><div class="title num">${nf(sleepHours(s), 1)} h · qualidade ${esc(s.quality)}/5</div><div class="meta">${fmtDate(s.bedtime, { weekday: "short", day: "2-digit", month: "short" })} ${fmtTime(s.bedtime)} → ${fmtTime(s.wake)}${s.awakenings ? " · " + esc(s.awakenings) + " despertares" : ""}</div></div>${rowActions("sleep", "sleep", s.id)}</div>`).join("") || `<div class="empty">Sem registros.</div>`}</div></div>
    <div class="card" style="margin-top:16px">${head("Registros de humor")}<div class="scroll"><table><thead><tr><th>Quando</th><th>Humor</th><th>Energia</th><th>Estresse</th><th>Ansiedade</th><th>Nota</th><th></th></tr></thead><tbody>
      ${[...md].reverse().slice(0, 15).map((m) => `<tr><td>${fmtDate(m.date)} <span class="subtle tiny">${fmtTime(m.date)}</span></td><td>${face(m.mood)} ${esc(m.mood)}</td><td class="num">${esc(m.energy)}</td><td class="num">${esc(m.stress)}</td><td class="num">${esc(m.anxiety)}</td><td class="muted small">${esc(m.note || "")}</td><td>${rowActions("mood", "moods", m.id)}</td></tr>`).join("") || `<tr><td colspan="7" class="empty">Sem registros.</td></tr>`}
    </tbody></table></div></div>`, "Mente", "Humor, sono, práticas e hábitos");
}

function viewConta() {
  const u = auth.currentUser;
  const providers = (u?.providerData || []).map((p) => p.providerId);
  const theme = localStorage.getItem("theme") || "dark";
  const accent = +(localStorage.getItem("accent") || 0);
  return shell(`
    <div class="grid g2 stagger">
      <div class="card">${head("Conta")}
        <div class="item"><div class="grow"><div class="title">${esc(u?.email || "")}</div><div class="meta">${u?.emailVerified ? "E-mail verificado" : "E-mail não verificado"}</div></div>
          ${u?.emailVerified ? `<span class="badge good">✓</span>` : `<button class="btn sm" id="verify">Reenviar verificação</button>`}</div>
        <div class="item"><div class="grow"><div class="title">Google</div><div class="meta">${providers.includes("google.com") ? "Conectado" : "Não conectado"}</div></div>
          ${providers.includes("google.com") ? `<span class="badge good">✓</span>` : `<button class="btn sm" id="linkg">Conectar</button>`}</div>
        <div class="item"><div class="grow"><div class="title">E-mail e senha</div><div class="meta">${providers.includes("password") ? "Ativo" : "Não definido"}</div></div></div>
        <div id="accmsg"></div>
        <button class="btn danger block" id="logout" style="margin-top:14px">Sair</button></div>
      <div class="card">${head("Aparência")}
        <div class="field"><label>Tema</label><div class="seg" id="theme">${[["dark", "Escuro"], ["light", "Claro"], ["system", "Sistema"]].map(([v, l]) => `<button data-t="${v}" class="${theme === v ? "on" : ""}">${l}</button>`).join("")}</div></div>
        <div class="field"><label>Cor</label><div class="swatches">${ACCENTS.map(([a, b], i) => `<div class="swatch ${accent === i ? "on" : ""}" data-a="${i}" style="background:linear-gradient(135deg,${a},${b})"></div>`).join("")}</div></div></div>
      <div class="card spanall">${head("App no celular e no computador")}${installCard()}</div>
      <div class="card spanall">${head("Sincronização")}<div class="small muted">
        O iPhone envia os registros (modo automático ou manual, em Central → Sincronização) e um resumo com metas e cálculos sempre que o app abre.
        Último resumo: <b>${summary?.updated ? rel(summary.updated) : "nunca"}</b>.</div>
        <div class="chips" style="margin-top:12px">${COLS.map((c) => `<span class="chip">${c} ${store[c].size}</span>`).join("")}</div></div>
    </div>`, "Conta");
}

// ================================================================ PWA (instalar + offline)
let installEvt = null;
const standalone = () => matchMedia("(display-mode: standalone)").matches || navigator.standalone;
addEventListener("beforeinstallprompt", (e) => { e.preventDefault(); installEvt = e; scheduleRender(); });
addEventListener("appinstalled", () => { installEvt = null; scheduleRender(); });
addEventListener("online", scheduleRender);
addEventListener("offline", scheduleRender);
if ("serviceWorker" in navigator && location.hostname !== "localhost") {
  navigator.serviceWorker.register("/sw.js").then((reg) => {
    reg.addEventListener("updatefound", () => {
      const w = reg.installing;
      w?.addEventListener("statechange", () => { if (w.state === "installed" && navigator.serviceWorker.controller) { updateReady = w; scheduleRender(); } });
    });
  }).catch(() => {});
  let reloaded = false;
  navigator.serviceWorker.addEventListener("controllerchange", () => { if (!reloaded) { reloaded = true; location.reload(); } });
}
let updateReady = null;
function installCard() {
  const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  if (standalone()) return `<div class="small muted">✓ Você está usando o Gym instalado. Ele abre em tela cheia e funciona sem internet: o que você registrar offline é enviado sozinho quando a conexão voltar.</div>`;
  return `<div class="small muted" style="margin-bottom:12px">Instale o site como app: abre em tela cheia, tem ícone na tela inicial e funciona sem internet (Android, iPhone, iPad, Windows e Mac).</div>
    ${installEvt ? `<button class="btn primary" id="install">Instalar o Gym</button>` : ios
      ? `<div class="small">No iPhone/iPad (Safari): toque em <b>Compartilhar</b> <span class="chip">⬆︎</span> e depois em <b>Adicionar à Tela de Início</b>.</div>`
      : `<div class="small">No Chrome/Edge: menu <span class="chip">⋮</span> → <b>Instalar Gym</b> (ou o ícone de instalar na barra de endereço). No Android: menu → <b>Instalar app</b>.</div>`}`;
}

// ================================================================ login
let loginMode = "in";
let loginMsg = null;
function viewLogin() {
  return `<div class="login">
    <div class="reveal"><span class="eyebrow">Gym · painel web</span>
      <h1 class="display" style="font-size:clamp(44px,7vw,84px);margin-top:16px">Seu treino,<br><span class="grad">sua evolução.</span></h1>
      <p class="lead">Peso, alimentação, treinos e bem-estar sincronizados com o iPhone — num painel limpo, em qualquer tela.</p></div>
    <div class="box glass reveal">
      <h2 class="h2" style="margin-bottom:20px">${loginMode === "in" ? "Entrar" : "Criar conta"}</h2>
      <button class="btn block" id="google"><b>G</b> Continuar com Google</button>
      <div class="or">ou com e-mail</div>
      <div class="field"><label>E-mail</label><input class="input" id="email" type="email" autocomplete="username"></div>
      <div class="field"><label>Senha</label><input class="input" id="pass" type="password" autocomplete="${loginMode === "in" ? "current-password" : "new-password"}"></div>
      <button class="btn primary block" id="submit" style="margin-top:6px">${loginMode === "in" ? "Entrar" : "Criar conta"}</button>
      <div style="display:flex;justify-content:space-between" class="small">
        <a href="#" id="toggle">${loginMode === "in" ? "Criar conta" : "Já tenho conta"}</a>
        ${loginMode === "in" ? `<a href="#" id="forgot">Esqueci a senha</a>` : ""}</div>
      ${loginMsg ? `<div class="msg ${loginMsg.ok ? "ok" : "err"}">${esc(loginMsg.text)}</div>` : ""}
    </div></div>`;
}
function authError(e) {
  const c = e.code || "";
  if (c.includes("invalid-credential") || c.includes("wrong-password") || c.includes("user-not-found")) return "E-mail ou senha incorretos.";
  if (c.includes("email-already-in-use")) return "Esse e-mail já tem conta. Use Entrar.";
  if (c.includes("weak-password")) return "Senha fraca: use pelo menos 6 caracteres.";
  if (c.includes("popup-closed")) return "Login cancelado.";
  if (c.includes("too-many-requests")) return "Muitas tentativas. Espere alguns minutos.";
  if (c.includes("operation-not-allowed")) return "Esse método de login não está ativado no Firebase.";
  if (c.includes("unauthorized-domain")) return "Domínio não autorizado no Firebase (Authentication → Configurações).";
  return e.message || String(e);
}
async function googleSignIn() {
  try { await signInWithPopup(auth, new GoogleAuthProvider()); }
  catch (e) {
    if (e.code !== "auth/account-exists-with-different-credential") throw e;
    const email = e.customData?.email;
    const pass = prompt(`Já existe uma conta com ${email}. Digite a senha dela para ligar o Google à mesma conta:`);
    if (!pass) return;
    const cred = GoogleAuthProvider.credentialFromError(e);
    const r = await signInWithEmailAndPassword(auth, email, pass);
    if (cred) await linkWithCredential(r.user, cred);
  }
}

// ================================================================ render
function render() {
  if (!authReady) return;
  const u = auth.currentUser;
  if (!u) { root.className = ""; root.innerHTML = viewLogin(); bindLogin(); return; }
  if (!loaded.has("summary") && loaded.size < 3) { root.className = "boot"; root.innerHTML = `<div class="spinner"></div>`; return; }
  root.className = "";
  const p = page();
  const y = scrollY;
  root.innerHTML = { painel: viewPainel, corpo: viewCorpo, alimentacao: viewAlimentacao, treinos: viewTreinos, mente: viewMente, conta: viewConta }[p]();
  if (p === lastPage) scrollTo(0, y); else scrollTo(0, 0);
  if (p !== lastPage) root.querySelectorAll(".reveal, .stagger > *").forEach((e) => e.style.animationPlayState = "running");
  else root.querySelectorAll(".reveal, .stagger > *, .bar > i, .line, rect.b").forEach((e) => e.style.animation = "none");
  lastPage = p;
  bindPage(p);
}
let lastPage = "";

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
  const upd = document.getElementById("upd");
  if (upd) upd.onclick = (e) => { e.preventDefault(); updateReady?.postMessage("skip"); };
  const inst = document.getElementById("install");
  if (inst) inst.onclick = async () => { await installEvt?.prompt(); installEvt = null; render(); };
  const add = new URLSearchParams(location.search).get("add");
  if (add) { history.replaceState(null, "", location.pathname + location.hash); setTimeout(() => openForm(add), 300); }
  const rerender = () => { lastPage = ""; render(); };
  if (p === "corpo") q("#range button").forEach((b) => b.onclick = () => { weightRange = +b.dataset.r; rerender(); });
  if (p === "alimentacao") {
    q("[data-day]").forEach((b) => b.onclick = () => {
      const v = +b.dataset.day;
      foodDay = v === 0 ? day(Date.now()) : Math.min(day(Date.now()), foodDay + v * DAY);
      rerender();
    });
    q("#mg button").forEach((b) => b.onclick = () => { microGroup = b.dataset.g; render(); });
  }
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
  summary = null; lastError = ""; lastPage = "";
  if (u) listen(u.uid); else { unsubs.forEach((x) => x()); unsubs = []; }
  render();
});
window.addEventListener("hashchange", render);
