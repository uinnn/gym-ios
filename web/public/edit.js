// Fase 3: adicionar, editar e apagar pelo site.
// Cada registro é gravado no mesmo formato que o iPhone usa (todos os campos que ele espera).
import { doc, setDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/11.0.2/firebase-firestore.js";

let ctx = null; // { db, auth, store, summary(), rerender, esc, nf, fmtDate }
export function initEdit(c) { ctx = c; document.addEventListener("click", onClick); }

const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : ([1e7] + -1e3 + -4e3 + -8e3 + -1e11).replace(/[018]/g, (c) => (c ^ crypto.getRandomValues(new Uint8Array(1))[0] & 15 >> c / 4).toString(16))).toUpperCase();
const N_KEYS = ["kcal", "protein", "carbs", "fat", "fiber", "sugar", "saturated", "sodium", "calcium", "iron", "potassium", "magnesium", "vitaminC", "cholesterol", "zinc"];
const M_KEYS = ["mono", "poly", "trans", "omega3", "omega6", "addedSugar", "phosphorus", "manganese", "copper", "selenium", "vitaminA", "b1", "b2", "b3", "b6", "b12", "folate", "vitaminD", "vitaminE"];
const PARTS = [["neck", "Pescoço"], ["shoulders", "Ombros"], ["chest", "Peitoral"], ["armR", "Braço direito"], ["armL", "Braço esquerdo"],
  ["forearmR", "Antebraço direito"], ["forearmL", "Antebraço esquerdo"], ["wrist", "Punho"], ["waist", "Cintura"], ["abdomen", "Abdômen"],
  ["hip", "Quadril"], ["thighR", "Coxa direita"], ["thighL", "Coxa esquerda"], ["calfR", "Panturrilha direita"], ["calfL", "Panturrilha esquerda"]];
const MEALS = [["breakfast", "Café da manhã"], ["morningSnack", "Lanche da manhã"], ["lunch", "Almoço"], ["afternoonSnack", "Lanche da tarde"], ["dinner", "Jantar"], ["supper", "Ceia"]];
const GOALS = [["lose", "Perder peso"], ["maintain", "Manter"], ["gain", "Ganhar massa"]];
const ACTIVITY = [["sedentary", "Sedentário"], ["light", "Leve (1–3x/sem)"], ["moderate", "Moderado (3–5x/sem)"], ["active", "Ativo (6–7x/sem)"], ["veryActive", "Muito ativo (2x/dia)"]];

// ---------------------------------------------------------------- gravação
async function save(col, id, payload) {
  if (ctx.write) return ctx.write(col, id, payload);   // usado só no teste local
  const uid = ctx.auth.currentUser?.uid;
  if (!uid) throw new Error("Entre na conta.");
  await setDoc(doc(ctx.db, "users", uid, col, id), {
    data: JSON.stringify(payload), updated: Date.now(), deleted: false, device: "web", server: serverTimestamp(),
  });
}
async function remove(col, id) {
  const uid = ctx.auth.currentUser?.uid;
  await setDoc(doc(ctx.db, "users", uid, col, id), { data: "{}", updated: Date.now(), deleted: true, device: "web", server: serverTimestamp() });
}
/** Dados atuais do registro, sem os campos internos do site. */
function current(col, id) {
  const r = ctx.store[col].get(id);
  if (!r) return {};
  const { id: _i, updated: _u, ...rest } = r;
  return rest;
}

// ---------------------------------------------------------------- utilidades de formulário
const toLocal = (ms) => { const d = new Date(ms - new Date(ms).getTimezoneOffset() * 60000); return d.toISOString().slice(0, 16); };
const fromLocal = (s) => new Date(s).getTime();
const num = (id) => { const v = parseFloat(String(val(id)).replace(",", ".")); return Number.isFinite(v) ? v : 0; };
const val = (id) => document.getElementById(id)?.value ?? "";
const field = (label, html) => `<div class="field"><label>${label}</label>${html}</div>`;
const input = (id, type, value = "", extra = "") => `<input class="input" id="${id}" type="${type}" value="${ctx.esc(value)}" ${extra}>`;
const select = (id, opts, value) => `<select class="input" id="${id}">${opts.map(([v, l]) => `<option value="${v}" ${String(v) === String(value) ? "selected" : ""}>${ctx.esc(l)}</option>`).join("")}</select>`;
const when = (ms = Date.now()) => field("Data e hora", input("f-when", "datetime-local", toLocal(ms)));
const lastKg = () => [...ctx.store.weights.values()].sort((a, b) => b.date - a.date)[0]?.kg || 70;

// ---------------------------------------------------------------- modal
let onSave = null;
function modal(title, body, saveFn, { wide = false, danger = null } = {}) {
  close();
  onSave = saveFn;
  document.body.insertAdjacentHTML("beforeend", `<div class="overlay" id="ov"><div class="modal glass ${wide ? "wide" : ""}" role="dialog" aria-modal="true">
    <div class="modal-head"><h2 class="h2">${title}</h2><button class="btn sm" data-act="close" aria-label="Fechar">✕</button></div>
    <div class="modal-body">${body}</div><div id="f-msg"></div>
    <div class="modal-foot">${danger ? `<button class="btn danger" data-act="danger">Apagar</button>` : ""}<span style="flex:1"></span>
      <button class="btn" data-act="close">Cancelar</button><button class="btn primary" data-act="save">Salvar</button></div></div></div>`);
  dangerFn = danger;
  setTimeout(() => document.querySelector("#ov input, #ov select")?.focus(), 50);
}
let dangerFn = null;
function close() { document.getElementById("ov")?.remove(); onSave = null; dangerFn = null; }
const fail = (t) => { const m = document.getElementById("f-msg"); if (m) m.innerHTML = `<div class="msg err">${ctx.esc(t)}</div>`; };
document.addEventListener("keydown", (e) => { if (e.key === "Escape") close(); });

async function onClick(e) {
  const el = e.target.closest("[data-act]");
  if (!el) { if (e.target.id === "ov") close(); return; }
  const a = el.dataset.act;
  if (el.closest("summary")) e.preventDefault();
  try {
    if (a === "close") close();
    else if (a === "save" && onSave) { el.disabled = true; await onSave(); close(); toast(navigator.onLine ? "Salvo — o iPhone recebe na próxima vez que abrir." : "Salvo offline — será enviado quando a internet voltar."); }
    else if (a === "danger" && dangerFn) { if (confirm("Apagar este registro no site e no iPhone?")) { await dangerFn(); close(); toast("Apagado."); } }
    else if (a === "add") open(el.dataset.kind);
    else if (a === "quick") quickMenu();
    else if (a === "edit") open(el.dataset.kind, el.dataset.id);
    else if (a === "del") { if (confirm("Apagar este registro no site e no iPhone?")) { await remove(el.dataset.col, el.dataset.id); toast("Apagado."); } }
    else if (a === "water") { await save("water", uuid(), { date: Date.now(), ml: +el.dataset.ml }); toast(`+${el.dataset.ml} ml de água`); }
    else if (a === "pick-food") pickFood(el.dataset.fid);
    else if (a === "add-ex") addExerciseRow();
    else if (a === "add-set") addSetRow(el.closest(".exrow"));
    else if (a === "rm-row") el.closest(el.dataset.row)?.remove();
  } catch (err) {
    el.disabled = false;
    fail(err.code === "permission-denied" ? "Sem permissão (regras do Firestore)." : (err.message || String(err)));
  }
}

function toast(t) {
  const d = document.createElement("div");
  d.className = "toast glass"; d.textContent = t;
  document.body.appendChild(d);
  setTimeout(() => d.classList.add("out"), 2600);
  setTimeout(() => d.remove(), 3100);
}

function quickMenu() {
  const items = [["weight", "⚖︎", "Pesagem"], ["food", "🍽", "Alimento"], ["water", "💧", "Água"], ["workout", "🏋", "Treino"],
    ["cardio", "🏃", "Cardio"], ["measure", "📏", "Medidas"], ["mood", "☺", "Humor"], ["sleep", "☾", "Sono"], ["gratitude", "🙏", "Gratidão"], ["profile", "👤", "Perfil e metas"]];
  modal("Adicionar", `<div class="quick">${items.map(([k, ic, l]) => `<button class="qbtn" data-act="add" data-kind="${k}"><span>${ic}</span>${l}</button>`).join("")}</div>`, null);
  document.querySelector("#ov [data-act=save]").remove();
}

// ---------------------------------------------------------------- formulários
export function openForm(kind) { open(kind); }
function open(kind, id) {
  const f = FORMS[kind];
  if (f) f(id);
}

const FORMS = {
  weight(id) {
    const r = id ? current("weights", id) : {};
    modal(id ? "Editar pesagem" : "Nova pesagem", when(r.date) + field("Peso (kg)", input("f-kg", "number", r.kg ?? "", 'step="0.05" min="20" max="350"'))
      + field("Observação", input("f-note", "text", r.note ?? "")), async () => {
      const kg = num("f-kg");
      if (kg < 20 || kg > 350) throw new Error("Peso inválido.");
      await save("weights", id || uuid(), { ...r, date: fromLocal(val("f-when")), kg, source: r.source || "manual", note: val("f-note"), tags: r.tags || "" });
    }, { danger: id ? () => remove("weights", id) : null });
  },

  water(id) {
    const r = id ? current("water", id) : {};
    modal(id ? "Editar água" : "Água", (id ? "" : `<div class="chips" style="margin-bottom:12px">${[200, 250, 300, 500, 750, 1000].map((m) => `<button class="btn sm" data-act="water" data-ml="${m}">+${m} ml</button>`).join("")}</div>`)
      + when(r.date) + field("Quantidade (ml)", input("f-ml", "number", r.ml ?? 250, 'step="50" min="10" max="5000"')), async () => {
      const ml = num("f-ml");
      if (ml <= 0) throw new Error("Quantidade inválida.");
      await save("water", id || uuid(), { date: fromLocal(val("f-when")), ml });
    }, { danger: id ? () => remove("water", id) : null });
  },

  food(id) {
    const r = id ? current("foods", id) : {};
    picked = null;
    const now = new Date().getHours();
    const meal = r.meal || (now < 10 ? "breakfast" : now < 12 ? "morningSnack" : now < 15 ? "lunch" : now < 18 ? "afternoonSnack" : now < 22 ? "dinner" : "supper");
    modal(id ? "Editar alimento" : "Adicionar alimento", (id ? `<div class="msg info">${ctx.esc(r.name)}</div>` : field("Buscar alimento", input("f-q", "search", "", 'placeholder="arroz, frango grelhado, banana…" autocomplete="off"') + `<div id="f-results" class="results"></div>`))
      + `<div class="grid g2">${field("Quantidade (g)", input("f-g", "number", r.grams ?? 100, 'step="5" min="1"'))}${field("Refeição", select("f-meal", MEALS, meal))}</div>`
      + when(r.date) + `<div id="f-preview" class="small muted"></div>`, async () => {
      const grams = num("f-g");
      if (grams <= 0) throw new Error("Quantidade inválida.");
      if (id) {
        // reescala os nutrientes já gravados
        const f = grams / Math.max(r.grams || 1, 0.1);
        const scale = (o) => o && Object.fromEntries(Object.entries(o).map(([k, v]) => [k, (+v || 0) * f]));
        await save("foods", id, { ...r, date: fromLocal(val("f-when")), meal: val("f-meal"), grams, nutrients: scale(r.nutrients), micros: scale(r.micros), extras: scale(r.extras) });
      } else {
        if (!picked) throw new Error("Escolha um alimento na lista.");
        const k = grams / 100;
        const nutrients = Object.fromEntries(N_KEYS.map((x) => [x, (picked.per100[x] || 0) * k]));
        const payload = { date: fromLocal(val("f-when")), meal: val("f-meal"), foodID: picked.id, name: picked.name, grams, nutrients };
        if (picked.micros) payload.micros = Object.fromEntries(M_KEYS.map((x) => [x, (picked.micros[x] || 0) * k]));
        if (picked.extras) payload.extras = Object.fromEntries(Object.entries(picked.extras).map(([x, v]) => [x, v * k]));
        await save("foods", uuid(), payload);
      }
    }, { danger: id ? () => remove("foods", id) : null });
    if (!id) {
      loadFoods();
      const q = document.getElementById("f-q");
      q.addEventListener("input", () => searchFoods(q.value));
      document.getElementById("f-g").addEventListener("input", preview);
      searchFoods("");
    }
  },

  workout(id) {
    const r = id ? current("workouts", id) : {};
    const dur = r.end && r.start ? Math.round((r.end - r.start) / 60000) : 60;
    modal(id ? "Editar treino" : "Registrar treino", `<div class="grid g2">${field("Nome", input("f-name", "text", r.name ?? "Treino"))}${field("Duração (min)", input("f-dur", "number", dur, 'min="1" max="600"'))}</div>`
      + when(r.start ?? Date.now() - dur * 60000) + `<div class="grid g2">${field("Como se sentiu", select("f-rating", [[0, "—"], [1, "😫 1"], [2, "😕 2"], [3, "🙂 3"], [4, "😃 4"], [5, "🔥 5"]], r.rating ?? 0))}${field("Nota", input("f-note", "text", r.note ?? ""))}</div>`
      + `<datalist id="ex-list">${Object.entries(ctx.summary()?.exercises || {}).sort((a, b) => a[1].n.localeCompare(b[1].n)).map(([k, v]) => `<option value="${ctx.esc(v.n)}" data-id="${k}">`).join("")}</datalist>`
      + `<div class="eyebrow" style="margin:6px 0 10px">Exercícios</div><div id="f-ex"></div><button class="btn sm" data-act="add-ex">+ Exercício</button>`,
    async () => {
      const exs = [...document.querySelectorAll("#f-ex .exrow")].map((row) => {
        const name = row.querySelector(".ex-name").value.trim();
        const exID = exIdByName(name) || (name && name === exNameOf(row.dataset.id) ? row.dataset.id : null);
        if (name && !exID) throw new Error(`"${name}" não está na lista de exercícios do app. Escolha uma opção da lista.`);
        const sets = [...row.querySelectorAll(".setrow")].map((s) => ({
          id: s.dataset.sid || uuid(), kg: parseFloat(s.querySelector(".kg").value.replace(",", ".")) || 0, reps: parseInt(s.querySelector(".reps").value) || 0,
          minutes: 0, km: 0, kind: s.querySelector(".warm").checked ? "warmup" : "normal", done: true,
        })).filter((s) => s.reps > 0);
        return { id: row.dataset.eid || uuid(), exerciseID: exID, sets, restSeconds: 90, note: "" };
      }).filter((e) => e.exerciseID && e.sets.length);
      const start = fromLocal(val("f-when"));
      const minutes = Math.max(1, num("f-dur"));
      await save("workouts", id || uuid(), { ...r, start, end: start + minutes * 60000, name: val("f-name") || "Treino", note: val("f-note"),
        bodyKg: r.bodyKg || lastKg(), rating: +val("f-rating") || 0, exercises: exs,
        sets: exs.reduce((s, e) => s + e.sets.filter((x) => x.kind !== "warmup").length, 0),
        volume: exs.reduce((s, e) => s + e.sets.filter((x) => x.kind !== "warmup").reduce((a, x) => a + x.kg * x.reps, 0), 0) });
    }, { wide: true, danger: id ? () => remove("workouts", id) : null });
    const ex = r.exercises || [];
    if (ex.length) ex.forEach((e) => addExerciseRow(e)); else addExerciseRow();
  },

  cardio(id) {
    const r = id ? current("cardio", id) : {};
    modal(id ? "Editar cardio" : "Registrar cardio", field("Tipo", select("f-kind", [["run", "🏃 Corrida"], ["walk", "🚶 Caminhada"], ["bike", "🚴 Pedalada"]], r.kind ?? "run"))
      + `<div class="grid g2">${field("Distância (km)", input("f-km", "number", r.km ?? "", 'step="0.1" min="0"'))}${field("Tempo (min)", input("f-min", "number", r.seconds ? Math.round(r.seconds / 60) : "", 'min="1"'))}</div>`
      + when(r.start), async () => {
      const km = num("f-km"), min = num("f-min"), kind = val("f-kind");
      if (min <= 0) throw new Error("Informe o tempo.");
      await save("cardio", id || uuid(), { ...r, start: fromLocal(val("f-when")), seconds: min * 60, km, kcal: cardioKcal(kind, km, min, lastKg()), climbM: r.climbM || 0, kind, splits: r.splits || [] });
    }, { danger: id ? () => remove("cardio", id) : null });
  },

  measure(id) {
    const r = id ? current("measurements", id) : {};
    modal(id ? "Editar medidas" : "Novas medidas (cm)", when(r.date) + `<div class="grid g3">${PARTS.map(([k, l]) => field(l, input("f-" + k, "number", r[k] ?? "", 'step="0.1" min="0"'))).join("")}</div>`
      + field("Observação", input("f-note", "text", r.note ?? "")), async () => {
      const p = { date: fromLocal(val("f-when")), note: val("f-note") };
      let any = false;
      for (const [k] of PARTS) { const v = num("f-" + k); if (v > 0) { p[k] = v; any = true; } }
      if (!any) throw new Error("Preencha pelo menos uma medida.");
      await save("measurements", id || uuid(), p);
    }, { wide: true, danger: id ? () => remove("measurements", id) : null });
  },

  mood(id) {
    const r = id ? current("moods", id) : {};
    const scale = (fid, label, v) => field(label, `<div class="seg scale" data-for="${fid}">${[1, 2, 3, 4, 5].map((n) => `<button type="button" class="${n === v ? "on" : ""}" data-v="${n}">${n}</button>`).join("")}</div><input type="hidden" id="${fid}" value="${v}">`);
    modal(id ? "Editar humor" : "Como você está?", when(r.date) + scale("f-mood", "Humor (1 péssimo – 5 ótimo)", r.mood ?? 3) + scale("f-energy", "Energia", r.energy ?? 3)
      + scale("f-stress", "Estresse (5 = muito)", r.stress ?? 3) + scale("f-anx", "Ansiedade", r.anxiety ?? 3) + field("Nota", input("f-note", "text", r.note ?? "")), async () => {
      await save("moods", id || uuid(), { ...r, date: fromLocal(val("f-when")), mood: +val("f-mood"), energy: +val("f-energy"), stress: +val("f-stress"),
        anxiety: +val("f-anx"), tags: r.tags || "", note: val("f-note") });
    }, { danger: id ? () => remove("moods", id) : null });
    document.querySelectorAll("#ov .scale button").forEach((b) => b.onclick = () => {
      const seg = b.parentElement; seg.querySelectorAll("button").forEach((x) => x.classList.toggle("on", x === b));
      document.getElementById(seg.dataset.for).value = b.dataset.v;
    });
  },

  sleep(id) {
    const r = id ? current("sleep", id) : {};
    const wake = r.wake ?? new Date().setHours(7, 0, 0, 0);
    modal(id ? "Editar sono" : "Registrar sono", `<div class="grid g2">${field("Deitou", input("f-bed", "datetime-local", toLocal(r.bedtime ?? wake - 8 * 3600000)))}${field("Acordou", input("f-wake", "datetime-local", toLocal(wake)))}</div>`
      + `<div class="grid g2">${field("Qualidade", select("f-q", [[1, "1 · péssima"], [2, "2"], [3, "3 · ok"], [4, "4"], [5, "5 · ótima"]], r.quality ?? 3))}${field("Despertares", input("f-aw", "number", r.awakenings ?? 0, 'min="0"'))}</div>`
      + field("Nota", input("f-note", "text", r.note ?? "")), async () => {
      const bed = fromLocal(val("f-bed")), wk = fromLocal(val("f-wake"));
      if (!(wk > bed) || wk - bed > 20 * 3600000) throw new Error("Horários inválidos.");
      await save("sleep", id || uuid(), { bedtime: bed, wake: wk, quality: +val("f-q"), awakenings: parseInt(val("f-aw")) || 0, note: val("f-note") });
    }, { danger: id ? () => remove("sleep", id) : null });
  },

  gratitude(id) {
    const r = id ? current("gratitude", id) : {};
    const items = r.items || ["", "", ""];
    modal(id ? "Editar gratidão" : "Gratidão", when(r.date) + items.concat(items.length < 3 ? Array(3 - items.length).fill("") : []).map((t, i) => field(`${i + 1}.`, input("f-g" + i, "text", t))).join(""), async () => {
      const list = [0, 1, 2, 3, 4].map((i) => val("f-g" + i).trim()).filter(Boolean);
      if (!list.length) throw new Error("Escreva pelo menos um item.");
      await save("gratitude", id || uuid(), { date: fromLocal(val("f-when")), items: list });
    }, { danger: id ? () => remove("gratitude", id) : null });
  },

  profile() {
    const entry = [...ctx.store.profile.values()][0];
    if (!entry) { modal("Perfil", `<div class="msg info">O perfil aparece aqui depois que o iPhone sincronizar.</div>`, null); document.querySelector("#ov [data-act=save]").remove(); return; }
    const r = current("profile", entry.id);
    modal("Perfil e metas", `<div class="grid g2">${field("Nome", input("f-name", "text", r.name ?? ""))}${field("Altura (cm)", input("f-h", "number", r.heightCm ?? 170, 'min="100" max="230"'))}</div>`
      + `<div class="grid g2">${field("Objetivo", select("f-goal", GOALS, r.goal))}${field("Peso meta (kg)", input("f-gw", "number", r.goalWeightKg ?? 70, 'step="0.5"'))}</div>`
      + field("Atividade física", select("f-act", ACTIVITY, r.activity))
      + `<div class="msg info">As metas de calorias e macros são recalculadas no iPhone e voltam para o site na próxima vez que o app abrir.</div>`, async () => {
      await save("profile", entry.id, { ...r, name: val("f-name"), heightCm: num("f-h"), goal: val("f-goal"), goalWeightKg: num("f-gw"), activity: val("f-act") });
    });
  },
};

// ---------------------------------------------------------------- cardio (mesmas fórmulas do iPhone)
function cardioKcal(kind, km, minutes, kg) {
  if (minutes <= 0) return 0;
  const mPerMin = km * 1000 / minutes;
  if (kind === "run") return (0.2 * mPerMin + 3.5) * kg / 1000 * 5 * minutes;
  if (kind === "walk") return (0.1 * mPerMin + 3.5) * kg / 1000 * 5 * minutes;
  const kmh = km / (minutes / 60);
  const met = kmh < 16 ? 4 : kmh < 19 ? 6.8 : kmh < 22 ? 8 : kmh < 25.5 ? 10 : 12;
  return met * kg * minutes / 60;
}

// ---------------------------------------------------------------- treino: linhas dinâmicas
function exIdByName(name) {
  const ex = ctx.summary()?.exercises || {};
  const n = name.toLowerCase();
  return Object.entries(ex).find(([, v]) => v.n.toLowerCase() === n)?.[0];
}
const exNameOf = (id) => ctx.summary()?.exercises?.[id]?.n || id;
function addExerciseRow(e = null) {
  const box = document.getElementById("f-ex");
  const name = e ? (ctx.summary()?.exercises?.[e.exerciseID]?.n || e.exerciseID) : "";
  box.insertAdjacentHTML("beforeend", `<div class="exrow card" data-eid="${e?.id || ""}" data-id="${ctx.esc(e?.exerciseID || "")}">
    <div style="display:flex;gap:8px;margin-bottom:8px"><input class="input ex-name" list="ex-list" placeholder="Exercício (ex.: Supino reto com barra)" value="${ctx.esc(name)}">
      <button class="btn sm" data-act="rm-row" data-row=".exrow" aria-label="Remover exercício">✕</button></div>
    <div class="sets-box"></div><button class="btn sm" data-act="add-set">+ Série</button></div>`);
  const row = box.lastElementChild;
  const sets = e?.sets?.length ? e.sets : [null, null, null];
  sets.forEach((s) => addSetRow(row, s));
}
function addSetRow(row, s = null) {
  const prev = row.querySelector(".setrow:last-child");
  const kg = s?.kg ?? prev?.querySelector(".kg").value ?? "";
  const reps = s?.reps ?? prev?.querySelector(".reps").value ?? "";
  row.querySelector(".sets-box").insertAdjacentHTML("beforeend", `<div class="setrow" data-sid="${s?.id || ""}">
    <input class="input kg" type="number" step="0.5" min="0" placeholder="kg" value="${ctx.esc(kg)}">
    <span class="muted">×</span><input class="input reps" type="number" min="0" placeholder="reps" value="${ctx.esc(reps)}">
    <label class="tiny muted"><input type="checkbox" class="warm" ${s?.kind === "warmup" ? "checked" : ""}> aquec.</label>
    <button class="btn sm" data-act="rm-row" data-row=".setrow" aria-label="Remover série">✕</button></div>`);
}

// ---------------------------------------------------------------- busca de alimentos
let FOODS = null, picked = null, foodsLoading = null;
const norm = (s) => s.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/,/g, " ");
function loadFoods() {
  if (FOODS || foodsLoading) return foodsLoading;
  foodsLoading = fetch("data/foods.json").then((r) => r.json()).then((list) => {
    FOODS = list.map((r) => {
      const v = r.v;
      return { id: r.i, name: r.n, cat: r.c, key: norm(r.n),
        per100: Object.fromEntries(N_KEYS.map((k, i) => [k, v[i] || 0])),
        micros: Object.fromEntries(M_KEYS.map((k, i) => [k, v[15 + i] || 0])) };
    });
    searchFoods(document.getElementById("f-q")?.value || "");
  });
  return foodsLoading;
}
/** Alimentos do usuário (salvos/criados no iPhone), com os mais usados primeiro. */
function savedFoods() {
  return [...ctx.store.savedFoods.values()].filter((s) => s.food?.per100).sort((a, b) => (b.useCount || 0) - (a.useCount || 0))
    .map((s) => ({ id: s.food.id, name: s.food.name, cat: s.isCustom ? "Meu alimento" : "Usado recentemente", key: norm(s.food.name),
      per100: s.food.per100, micros: s.food.micros, extras: s.food.extras, serving: s.food.servingGrams, last: s.lastGrams }));
}
let shown = [];
function searchFoods(q) {
  const box = document.getElementById("f-results");
  if (!box) return;
  const words = norm(q).split(/\s+/).filter(Boolean);
  const mine = savedFoods();
  const match = (f) => words.every((w) => f.key.includes(w));
  let list = words.length ? mine.filter(match) : mine.slice(0, 8);
  if (words.length && FOODS) {
    const hits = FOODS.filter(match).sort((a, b) => (b.key.startsWith(words[0]) - a.key.startsWith(words[0])) || a.key.length - b.key.length);
    const seen = new Set(list.map((f) => f.id));
    list = list.concat(hits.filter((f) => !seen.has(f.id)));
  }
  shown = list.slice(0, 40);
  box.innerHTML = shown.length ? shown.map((f, i) => `<button type="button" class="res ${picked?.id === f.id ? "on" : ""}" data-act="pick-food" data-fid="${i}">
      <span class="grow"><b>${ctx.esc(f.name)}</b><span class="tiny muted"> · ${ctx.esc(f.cat)}</span></span><span class="num tiny">${ctx.nf(f.per100.kcal, 0)} kcal/100g</span></button>`).join("")
    : `<div class="empty small">${FOODS || !words.length ? "Nada encontrado." : "Carregando o banco de alimentos…"}</div>`;
}
function pickFood(i) {
  picked = shown[+i];
  if (!picked) return;
  const g = document.getElementById("f-g");
  if (picked.last) g.value = Math.round(picked.last); else if (picked.serving) g.value = Math.round(picked.serving);
  document.querySelectorAll("#f-results .res").forEach((b) => b.classList.toggle("on", +b.dataset.fid === +i));
  preview();
}
function preview() {
  const p = document.getElementById("f-preview");
  if (!p || !picked) return;
  const k = num("f-g") / 100;
  p.innerHTML = `<b>${ctx.esc(picked.name)}</b> · ${ctx.nf(picked.per100.kcal * k, 0)} kcal · P ${ctx.nf(picked.per100.protein * k, 1)} g · C ${ctx.nf(picked.per100.carbs * k, 1)} g · G ${ctx.nf(picked.per100.fat * k, 1)} g`;
}

// ---------------------------------------------------------------- botões usados pelas telas
export const addBtn = (kind, label) => `<button class="btn sm primary" data-act="add" data-kind="${kind}">+ ${label}</button>`;
export const rowActions = (kind, col, id) => `<span class="acts"><button class="icon-btn" data-act="edit" data-kind="${kind}" data-id="${id}" title="Editar" aria-label="Editar">✎</button><button class="icon-btn" data-act="del" data-col="${col}" data-id="${id}" title="Apagar" aria-label="Apagar">🗑</button></span>`;
export const fab = () => `<button class="fab" data-act="quick" aria-label="Adicionar registro">+</button>`;
