// Personal trainer: convites, alunos, painel do aluno, recados e treinos enviados.
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, collection, onSnapshot, query, where, orderBy, serverTimestamp, writeBatch,
} from "https://www.gstatic.com/firebasejs/11.0.2/firebase-firestore.js";

let C = null; // contexto vindo do app.js
export const T = {
  isTrainer: false, profile: null,
  students: [],            // [{id, name, since, scopes}]
  studentSummaries: {},    // sid → resumo
  myTrainers: [],          // vínculos na minha conta: [{id, name, email, scopes, since}]
  inbox: [],               // recebidos (minha conta)
  sent: [],                // enviados ao aluno que estou vendo
  invite: null,            // último convite criado nesta sessão
};
let unsubs = [], sentUnsub = null;

export const SCOPES = [["body", "Corpo", "Peso, medidas, composição e perfil"], ["food", "Alimentação", "Refeições, água, jejum e nutrientes"],
  ["training", "Treinos", "Treinos, rotinas e cardio"], ["mind", "Mente e sono", "Humor, sono, práticas, gratidão e hábitos"]];
export const DEFAULT_SCOPES = { body: true, food: true, training: true, mind: false };
const uuid = () => crypto.randomUUID().toUpperCase();
const ALPHA = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const newCode = () => Array.from(crypto.getRandomValues(new Uint8Array(8)), (b) => ALPHA[b % ALPHA.length]).join("");

export function initTrainer(ctx) {
  C = ctx;
  document.addEventListener("click", onClick);
}

/** Liga as escutas do usuário logado (perfil de personal, alunos, meus personais e caixa de entrada). */
export function startTrainer(uid) {
  stopTrainer();
  const { db } = C;
  unsubs.push(onSnapshot(doc(db, "trainers", uid), (d) => {
    T.isTrainer = d.exists(); T.profile = d.exists() ? d.data() : null;
    if (T.isTrainer && !studentsUnsub) {
      studentsUnsub = onSnapshot(collection(db, "trainers", uid, "students"), (s) => {
        T.students = s.docs.map((x) => ({ id: x.id, ...x.data() })).sort((a, b) => (a.name || "").localeCompare(b.name || ""));
        T.students.forEach((st) => loadSummary(st.id));
        C.rerender();
      }, () => {});
    }
    C.rerender();
  }, () => {}));
  unsubs.push(onSnapshot(collection(db, "users", uid, "trainers"), (s) => {
    T.myTrainers = s.docs.map((x) => ({ id: x.id, ...x.data() }));
    C.rerender();
  }, () => {}));
  unsubs.push(onSnapshot(query(collection(db, "users", uid, "inbox"), orderBy("createdAt", "desc")), (s) => {
    T.inbox = s.docs.map((x) => ({ id: x.id, ...x.data() }));
    C.rerender();
  }, () => {}));
}
let studentsUnsub = null;
export function stopTrainer() {
  unsubs.forEach((u) => u()); unsubs = [];
  studentsUnsub?.(); studentsUnsub = null;
  sentUnsub?.(); sentUnsub = null;
  Object.assign(T, { isTrainer: false, profile: null, students: [], studentSummaries: {}, myTrainers: [], inbox: [], sent: [], invite: null });
}

async function loadSummary(sid) {
  try {
    const d = await getDoc(doc(C.db, "users", sid, "meta", "summary"));
    T.studentSummaries[sid] = d.exists() ? { ...JSON.parse(d.data().data || "{}"), updated: d.data().updated } : null;
  } catch { T.studentSummaries[sid] = null; }
  C.rerender();
}

/** Ao abrir um aluno: escuta os recados que eu já mandei para ele. */
export function watchSent(sid) {
  sentUnsub?.();
  T.sent = [];
  if (!sid) { sentUnsub = null; return; }
  const me = C.auth.currentUser.uid;
  sentUnsub = onSnapshot(query(collection(C.db, "users", sid, "inbox"), where("from", "==", me)), (s) => {
    T.sent = s.docs.map((x) => ({ id: x.id, ...x.data() })).sort((a, b) => (b.createdAt?.toMillis?.() || 0) - (a.createdAt?.toMillis?.() || 0));
    C.rerender();
  }, () => {});
}

// ================================================================ ações
const me = () => C.auth.currentUser;
const myName = () => T.profile?.name || me()?.displayName || me()?.email?.split("@")[0] || "Personal";

async function becomeTrainer(name, cref) {
  await setDoc(doc(C.db, "trainers", me().uid), { name: name || myName(), email: me().email || "", cref: cref || "", createdAt: serverTimestamp() }, { merge: true });
}

/** Aluno: cria um convite de uso único, válido por 24 h, com as categorias escolhidas. */
async function createInvite(scopes) {
  const code = newCode();
  const studentName = C.summary()?.profileName || me().displayName || me().email?.split("@")[0] || "Aluno";
  await setDoc(doc(C.db, "invites", code), { student: me().uid, studentName, scopes, expires: Date.now() + 24 * 3600e3, createdAt: serverTimestamp() });
  T.invite = { code, expires: Date.now() + 24 * 3600e3, scopes };
  return code;
}

/** Personal: usa o código do aluno. */
async function useInvite(raw) {
  const code = raw.toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (code.length < 6) throw new Error("Código inválido.");
  const snap = await getDoc(doc(C.db, "invites", code)).catch(() => null);
  if (!snap?.exists()) throw new Error("Código não encontrado. Confira com o aluno.");
  const inv = snap.data();
  if (inv.student === me().uid) throw new Error("Esse código é seu. Ele deve ser usado pelo personal.");
  if (inv.usedBy) throw new Error("Esse código já foi usado. Peça um novo ao aluno.");
  if (inv.expires < Date.now()) throw new Error("Código vencido (vale 24 h). Peça um novo ao aluno.");
  if (!T.isTrainer) await becomeTrainer();
  // 1) vínculo na conta do aluno (as regras conferem o convite) → 2) marca o convite → 3) minha lista
  await setDoc(doc(C.db, "users", inv.student, "trainers", me().uid), {
    code, scopes: inv.scopes, name: myName(), email: me().email || "", since: serverTimestamp(),
  });
  await updateDoc(doc(C.db, "invites", code), { usedBy: me().uid });
  await setDoc(doc(C.db, "trainers", me().uid, "students", inv.student), { name: inv.studentName || "Aluno", since: serverTimestamp(), scopes: inv.scopes });
  return inv.studentName;
}

async function updateScopes(tid, scopes) {
  await updateDoc(doc(C.db, "users", me().uid, "trainers", tid), { scopes });
}

/** Aluno remove o personal (some dos dois lados). */
async function removeTrainer(tid) {
  const b = writeBatch(C.db);
  b.delete(doc(C.db, "users", me().uid, "trainers", tid));
  b.delete(doc(C.db, "trainers", tid, "students", me().uid));
  await b.commit();
}

/** Personal deixa de acompanhar o aluno. */
async function removeStudent(sid) {
  await deleteDoc(doc(C.db, "users", sid, "trainers", me().uid)).catch(() => {});
  await deleteDoc(doc(C.db, "trainers", me().uid, "students", sid));
}

async function sendNote(sid, text, about) {
  await setDoc(doc(C.db, "users", sid, "inbox", uuid()), {
    type: "note", from: me().uid, fromName: myName(), text, about: about || "", createdAt: serverTimestamp(), read: false,
  });
}

async function sendRoutine(sid, routine) {
  await setDoc(doc(C.db, "users", sid, "inbox", uuid()), {
    type: "routine", from: me().uid, fromName: myName(), name: routine.name, note: routine.note || "",
    items: routine.items, createdAt: serverTimestamp(), read: false,
  });
}

/** Aluno: copia um treino recebido para as próprias rotinas (o iPhone recebe pela sincronização). */
async function importRoutine(msg) {
  const id = uuid();
  const payload = { name: msg.name, icon: "dumbbell.fill", order: 999, createdAt: Date.now(), weekday: 0, items: msg.items };
  await setDoc(doc(C.db, "users", me().uid, "routines", id), {
    data: JSON.stringify(payload), updated: Date.now(), deleted: false, device: "web", server: serverTimestamp(),
  });
  await updateDoc(doc(C.db, "users", me().uid, "inbox", msg.id), { read: true, imported: true });
}

// ================================================================ modais
function modal(title, body, onSave, saveLabel = "Salvar") {
  closeModal();
  document.body.insertAdjacentHTML("beforeend", `<div class="overlay" id="tov"><div class="modal glass wide" role="dialog" aria-modal="true">
    <div class="modal-head"><h2 class="h2">${title}</h2><button class="btn sm" data-tact="close" aria-label="Fechar">✕</button></div>
    <div class="modal-body">${body}</div><div id="t-msg" style="padding:0 22px"></div>
    <div class="modal-foot"><span style="flex:1"></span><button class="btn" data-tact="close">Cancelar</button>${onSave ? `<button class="btn primary" data-tact="save">${saveLabel}</button>` : ""}</div></div></div>`);
  saveFn = onSave;
  setTimeout(() => document.querySelector("#tov input, #tov textarea")?.focus(), 50);
}
let saveFn = null;
function closeModal() { document.getElementById("tov")?.remove(); saveFn = null; }
const tmsg = (t, ok) => { const m = document.getElementById("t-msg"); if (m) m.innerHTML = `<div class="msg ${ok ? "ok" : "err"}">${C.esc(t)}</div>`; };
const scopesForm = (sc) => `<div class="grid g2">${SCOPES.map(([k, l, d]) => `<label class="card" style="padding:12px;display:flex;gap:10px;cursor:pointer">
  <input type="checkbox" data-scope="${k}" ${sc[k] ? "checked" : ""} style="width:20px;height:20px;accent-color:var(--brand)">
  <span><b>${l}</b><br><span class="tiny muted">${d}</span></span></label>`).join("")}</div>`;
const readScopes = (root = document) => Object.fromEntries(SCOPES.map(([k]) => [k, !!root.querySelector(`[data-scope="${k}"]`)?.checked]));

function routineForm(exercises) {
  const opts = Object.entries(exercises || {}).sort((a, b) => a[1].n.localeCompare(b[1].n)).map(([, v]) => `<option value="${C.esc(v.n)}">`).join("");
  return `<div class="field"><label>Nome do treino</label><input class="input" id="r-name" placeholder="Ex.: Treino A — Peito e tríceps"></div>
    <div class="field"><label>Observações para o aluno</label><input class="input" id="r-note" placeholder="Ex.: descanso de 90 s, cadência 2-0-2"></div>
    <datalist id="r-ex">${opts}</datalist>
    <div class="eyebrow" style="margin:6px 0 10px">Exercícios</div><div id="r-rows"></div>
    <button class="btn sm" data-tact="add-row">+ Exercício</button>`;
}
function addRoutineRow() {
  document.getElementById("r-rows").insertAdjacentHTML("beforeend", `<div class="exrow card" style="display:grid;grid-template-columns:2fr repeat(4,1fr) auto;gap:8px;align-items:end">
    <div class="field" style="margin:0"><label>Exercício</label><input class="input r-x" list="r-ex" placeholder="Supino reto com barra"></div>
    <div class="field" style="margin:0"><label>Séries</label><input class="input r-s" type="number" min="1" value="3"></div>
    <div class="field" style="margin:0"><label>Reps mín.</label><input class="input r-a" type="number" min="1" value="8"></div>
    <div class="field" style="margin:0"><label>Reps máx.</label><input class="input r-b" type="number" min="1" value="12"></div>
    <div class="field" style="margin:0"><label>Descanso (s)</label><input class="input r-r" type="number" min="0" step="15" value="90"></div>
    <button class="btn sm" data-tact="rm-row" aria-label="Remover">✕</button></div>`);
}

async function onClick(e) {
  const el = e.target.closest("[data-tact]");
  if (!el) { if (e.target.id === "tov") closeModal(); return; }
  const a = el.dataset.tact;
  try {
    switch (a) {
      case "close": closeModal(); break;
      case "save": if (saveFn) { el.disabled = true; await saveFn(); } break;
      case "add-row": addRoutineRow(); break;
      case "rm-row": el.closest(".exrow")?.remove(); break;
      case "become":
        modal("Ativar o modo personal", `<p class="small muted">Com o modo personal você acompanha seus alunos pelo site: eles geram um código no app ou no site e você digita aqui.</p>
          <div class="field"><label>Seu nome (aparece para os alunos)</label><input class="input" id="b-name" value="${C.esc(myName())}"></div>
          <div class="field"><label>CREF (opcional)</label><input class="input" id="b-cref" placeholder="000000-G/UF"></div>`, async () => {
          await becomeTrainer(document.getElementById("b-name").value.trim(), document.getElementById("b-cref").value.trim());
          closeModal(); location.hash = "#/alunos"; C.toast("Modo personal ativado.");
        }, "Ativar");
        break;
      case "add-student":
        modal("Adicionar aluno", `<p class="small muted">Peça ao aluno para gerar um código em <b>Conta → Personal trainer</b> (no site) ou <b>Central → Personal trainer</b> (no app). O código vale 24 h e só pode ser usado uma vez.</p>
          <div class="field"><label>Código do aluno</label><input class="input" id="s-code" placeholder="Ex.: K7MP2Q9X" autocomplete="off" style="font-family:var(--font-mono);letter-spacing:.2em;text-transform:uppercase"></div>`, async () => {
          const name = await useInvite(document.getElementById("s-code").value);
          closeModal(); C.toast(`${name} adicionado(a)!`);
        }, "Adicionar");
        break;
      case "invite":
        modal("Convidar meu personal", `<p class="small muted">Escolha o que seu personal pode ver. Você pode mudar isso ou remover o acesso a qualquer momento.</p>${scopesForm(DEFAULT_SCOPES)}`, async () => {
          const sc = readScopes(document.getElementById("tov"));
          if (!Object.values(sc).some(Boolean)) throw new Error("Escolha pelo menos uma categoria.");
          const code = await createInvite(sc);
          document.querySelector("#tov .modal-body").innerHTML = `<div style="text-align:center;padding:12px 0">
            <div class="tiny muted">Passe este código para o seu personal</div>
            <div class="display grad" style="font-family:var(--font-mono);letter-spacing:.12em;margin:14px 0">${code}</div>
            <button class="btn sm" data-tact="copy" data-code="${code}">Copiar código</button>
            <p class="small muted" style="margin-top:14px">Vale por 24 horas e só pode ser usado uma vez. O personal digita em <b>Alunos → Adicionar aluno</b>.</p></div>`;
          document.querySelector('#tov [data-tact="save"]')?.remove();
        }, "Gerar código");
        break;
      case "copy": await navigator.clipboard.writeText(el.dataset.code); C.toast("Código copiado."); break;
      case "scopes": {
        const t = T.myTrainers.find((x) => x.id === el.dataset.id);
        modal(`O que ${C.esc(t?.name || "o personal")} pode ver`, scopesForm(t?.scopes || DEFAULT_SCOPES), async () => {
          await updateScopes(el.dataset.id, readScopes(document.getElementById("tov")));
          closeModal(); C.toast("Permissões atualizadas.");
        });
        break;
      }
      case "remove-trainer":
        if (confirm("Remover o acesso deste personal? Ele deixa de ver seus dados na hora.")) { await removeTrainer(el.dataset.id); C.toast("Acesso removido."); }
        break;
      case "remove-student":
        if (confirm("Deixar de acompanhar este aluno? Para voltar, ele precisará gerar um novo código.")) {
          await removeStudent(el.dataset.id); C.exitStudent(); C.toast("Aluno removido.");
        }
        break;
      case "open-student": C.openStudent(el.dataset.id); break;
      case "back": C.exitStudent(); break;
      case "note":
        modal(`Recado para ${C.esc(C.viewing()?.name || "o aluno")}`, `<div class="field"><label>Assunto (opcional)</label><input class="input" id="n-about" placeholder="Ex.: alimentação da semana"></div>
          <div class="field"><label>Mensagem</label><textarea class="input" id="n-text" rows="5" style="height:auto;padding:12px" placeholder="Escreva seu recado…"></textarea></div>`, async () => {
          const text = document.getElementById("n-text").value.trim();
          if (!text) throw new Error("Escreva a mensagem.");
          await sendNote(C.viewing().uid, text, document.getElementById("n-about").value.trim());
          closeModal(); C.toast("Recado enviado — aparece no app do aluno.");
        }, "Enviar");
        break;
      case "routine":
        modal(`Enviar treino para ${C.esc(C.viewing()?.name || "o aluno")}`, routineForm(C.summary()?.exercises), async () => {
          const ex = C.summary()?.exercises || {};
          const byName = Object.fromEntries(Object.entries(ex).map(([k, v]) => [v.n.toLowerCase(), k]));
          const items = [...document.querySelectorAll("#r-rows .exrow")].map((r) => {
            const name = r.querySelector(".r-x").value.trim();
            const id = byName[name.toLowerCase()];
            if (name && !id) throw new Error(`"${name}" não está na lista de exercícios do app. Escolha uma opção da lista.`);
            const a = Math.max(1, parseInt(r.querySelector(".r-a").value) || 8), b = Math.max(a, parseInt(r.querySelector(".r-b").value) || a);
            return id && { id: uuid(), exerciseID: id, sets: Math.max(1, parseInt(r.querySelector(".r-s").value) || 3), repsMin: a, repsMax: b,
              restSeconds: Math.max(0, parseInt(r.querySelector(".r-r").value) || 90) };
          }).filter(Boolean);
          const name = document.getElementById("r-name").value.trim();
          if (!name) throw new Error("Dê um nome ao treino.");
          if (!items.length) throw new Error("Adicione pelo menos um exercício.");
          await sendRoutine(C.viewing().uid, { name, note: document.getElementById("r-note").value.trim(), items });
          closeModal(); C.toast("Treino enviado — o aluno adiciona com um toque no app.");
        }, "Enviar treino");
        addRoutineRow(); addRoutineRow(); addRoutineRow();
        break;
      case "del-sent":
        if (confirm("Apagar este envio? Ele some do app do aluno.")) await deleteDoc(doc(C.db, "users", C.viewing().uid, "inbox", el.dataset.id));
        break;
      case "read": await updateDoc(doc(C.db, "users", me().uid, "inbox", el.dataset.id), { read: true }); break;
      case "import": {
        const m = T.inbox.find((x) => x.id === el.dataset.id);
        if (m) { await importRoutine(m); C.toast(`"${m.name}" adicionado às suas rotinas.`); }
        break;
      }
      case "del-inbox": await deleteDoc(doc(C.db, "users", me().uid, "inbox", el.dataset.id)); break;
    }
  } catch (err) {
    el.disabled = false;
    tmsg(err.code === "permission-denied" ? "Sem permissão (o convite pode ter vencido ou o acesso foi removido)." : (err.message || String(err)));
    if (!document.getElementById("tov")) C.toast(err.message || String(err));
  }
}

// ================================================================ telas
function when(ts) { const ms = ts?.toMillis?.() || ts || 0; return ms ? C.rel(ms) : ""; }

/** Lista de alunos do personal. */
export function viewAlunos() {
  const { esc, nf, rel } = C;
  if (!T.isTrainer) {
    return C.shell(`<div class="card" style="max-width:640px"><span class="eyebrow">Modo personal</span>
      <h2 class="h2" style="margin:12px 0 8px">Acompanhe seus alunos pelo site</h2>
      <p class="muted">Seus alunos geram um código no app ou no site e você vê o progresso deles: peso, composição, alimentação, treinos e sono — só o que cada um liberar. Você também envia treinos e recados que aparecem no app deles.</p>
      <button class="btn primary" data-tact="become" style="margin-top:12px">Ativar modo personal</button></div>`, "Alunos");
  }
  const alerts = (s) => {
    if (!s) return [];
    const out = [];
    if (s.updated && Date.now() - s.updated > 4 * 86400e3) out.push(`sem sincronizar há ${Math.round((Date.now() - s.updated) / 86400e3)} dias`);
    (s.advanced || []).flatMap((g) => g.items).filter((m) => m.tone === "bad").forEach((m) => out.push(`${m.title}: ${m.status}`));
    return out.slice(0, 3);
  };
  const cards = T.students.map((st) => {
    const s = T.studentSummaries[st.id];
    const m = s?.metrics || {};
    const al = alerts(s);
    const sc = SCOPES.filter(([k]) => st.scopes?.[k]).map(([, l]) => l).join(" · ");
    return `<div class="card hover" data-tact="open-student" data-id="${esc(st.id)}" style="cursor:pointer">
      <div style="display:flex;gap:12px;align-items:center">
        <div class="logo" style="width:44px;height:44px">${esc(s?.emoji || "🙂")}</div>
        <div style="flex:1;min-width:0"><div class="h3">${esc(s?.profileName || st.name)}</div>
          <div class="tiny muted">${s?.updated ? "Atualizado " + rel(s.updated) : "Ainda sem dados sincronizados"} · ${esc(sc)}</div></div>
        <span class="muted">›</span></div>
      <div class="grid g3" style="margin-top:14px">
        <div><div class="tiny subtle">Peso</div><b class="num">${m.weight ? nf(m.weight.value, 1) + " kg" : "—"}</b></div>
        <div><div class="tiny subtle">Gordura</div><b class="num">${m.bodyFat ? nf(m.bodyFat.value, 1) + "%" : "—"}</b></div>
        <div><div class="tiny subtle">Prontidão</div><b class="num">${s?.readiness ? esc(s.readiness.score) : "—"}</b></div>
      </div>
      ${al.length ? `<div class="chips" style="margin-top:12px">${al.map((x) => `<span class="badge warn">⚠︎ ${esc(x)}</span>`).join("")}</div>` : ""}
    </div>`;
  }).join("");
  return C.shell(`<div class="chips" style="margin:-8px 0 18px"><button class="btn sm primary" data-tact="add-student">+ Adicionar aluno</button></div>
    ${T.students.length ? `<div class="grid g3 stagger">${cards}</div>` : `<div class="card empty">Nenhum aluno ainda. Peça para o aluno gerar um código e toque em <b>Adicionar aluno</b>.</div>`}`,
  "Alunos", `${T.students.length} aluno(s)${T.profile?.cref ? " · CREF " + esc(T.profile.cref) : ""}`);
}

/** Faixa no topo quando o personal está vendo um aluno. */
export function studentBanner() {
  const v = C.viewing();
  if (!v) return "";
  const { esc } = C;
  const sc = SCOPES.map(([k, l]) => `<span class="badge ${v.scopes?.[k] ? "good" : ""}">${v.scopes?.[k] ? "✓" : "✕"} ${l}</span>`).join("");
  return `<div class="card" style="margin-bottom:18px;display:flex;gap:12px;align-items:center;flex-wrap:wrap">
    <button class="btn sm" data-tact="back">‹ Alunos</button>
    <div style="flex:1;min-width:200px"><span class="eyebrow">Acompanhando</span><div class="h3">${esc(v.name)}</div><div class="chips" style="margin-top:6px">${sc}</div></div>
    <button class="btn sm primary" data-tact="routine">🏋 Enviar treino</button>
    <button class="btn sm" data-tact="note">✉︎ Enviar recado</button>
    <button class="btn sm danger" data-tact="remove-student" data-id="${esc(v.uid)}">Deixar de acompanhar</button>
  </div>`;
}

/** Envios do personal para o aluno aberto (no painel do aluno). */
export function sentCard() {
  if (!C.viewing()) return "";
  const { esc } = C;
  return `<div class="card" style="margin-top:16px"><div class="card-head"><span class="eyebrow">Seus envios para ${esc(C.viewing().name)}</span></div>
    ${T.sent.length ? T.sent.map((m) => `<div class="item"><div class="avatar">${m.type === "routine" ? "🏋" : "✉︎"}</div><div class="grow">
      <div class="title">${esc(m.type === "routine" ? m.name : (m.about || "Recado"))}</div>
      <div class="meta">${m.type === "routine" ? `${(m.items || []).length} exercício(s)` : esc(m.text).slice(0, 120)} · ${when(m.createdAt)} · ${m.imported ? "adicionado pelo aluno ✓" : m.read ? "lido ✓" : "não lido"}</div></div>
      <button class="icon-btn" data-tact="del-sent" data-id="${esc(m.id)}" title="Apagar" aria-label="Apagar">🗑</button></div>`).join("")
      : `<div class="empty small">Nada enviado ainda. Use <b>Enviar treino</b> ou <b>Enviar recado</b>.</div>`}</div>`;
}

/** Aluno: recados e treinos recebidos (no Painel). */
export function inboxCard() {
  if (C.viewing() || !T.inbox.length) return "";
  const { esc } = C;
  const unread = T.inbox.filter((m) => !m.read).length;
  return `<div class="card" style="margin-bottom:16px"><div class="card-head"><span class="eyebrow">Do seu personal</span>${unread ? `<span class="right badge brand">${unread} novo(s)</span>` : ""}</div>
    ${T.inbox.slice(0, 6).map((m) => `<div class="item"><div class="avatar">${m.type === "routine" ? "🏋" : "✉︎"}</div><div class="grow">
      <div class="title">${esc(m.type === "routine" ? m.name : (m.about || "Recado"))} ${m.read ? "" : `<span class="badge brand pixel">novo</span>`}</div>
      <div class="meta">${esc(m.fromName || "Personal")} · ${when(m.createdAt)}</div>
      ${m.type === "note" ? `<div class="small" style="margin-top:6px;white-space:pre-wrap">${esc(m.text)}</div>`
        : `<div class="small muted" style="margin-top:6px">${(m.items || []).map((i) => `${esc(C.exName(i.exerciseID))} ${esc(i.sets)}×${esc(i.repsMin)}${i.repsMax !== i.repsMin ? "–" + esc(i.repsMax) : ""}`).join(" · ")}${m.note ? `<br>📝 ${esc(m.note)}` : ""}</div>`}</div>
      <div style="display:flex;flex-direction:column;gap:6px">
        ${m.type === "routine" && !m.imported ? `<button class="btn sm primary" data-tact="import" data-id="${esc(m.id)}">Adicionar</button>` : ""}
        ${!m.read && m.type === "note" ? `<button class="btn sm" data-tact="read" data-id="${esc(m.id)}">Lido</button>` : ""}
        <button class="icon-btn" data-tact="del-inbox" data-id="${esc(m.id)}" aria-label="Apagar">🗑</button></div></div>`).join("")}</div>`;
}

/** Aluno: seção "Personal trainer" na Conta. */
export function studentSection() {
  const { esc } = C;
  const list = T.myTrainers.map((t) => `<div class="item"><div class="avatar">🧑‍🏫</div><div class="grow"><div class="title">${esc(t.name || "Personal")}</div>
    <div class="meta">${esc(t.email || "")} · vê: ${SCOPES.filter(([k]) => t.scopes?.[k]).map(([, l]) => l).join(", ") || "nada"}</div></div>
    <button class="btn sm" data-tact="scopes" data-id="${esc(t.id)}">Permissões</button>
    <button class="btn sm danger" data-tact="remove-trainer" data-id="${esc(t.id)}">Remover</button></div>`).join("");
  return `<div class="small muted" style="margin-bottom:12px">Dê acesso ao seu personal trainer: ele acompanha seu progresso pelo site e pode te enviar treinos e recados. Você escolhe o que ele vê e pode remover quando quiser.</div>
    ${list || `<div class="empty small">Nenhum personal com acesso.</div>`}
    <button class="btn primary" data-tact="invite" style="margin-top:12px">Gerar código para o personal</button>
    ${T.invite && T.invite.expires > Date.now() ? `<div class="msg info">Código ativo: <b class="mono">${T.invite.code}</b> (vale até ${new Date(T.invite.expires).toLocaleString("pt-BR", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "short" })})</div>` : ""}`;
}

/** Personal: seção na Conta. */
export function trainerSection() {
  const { esc } = C;
  if (T.isTrainer) return `<div class="small">Modo personal ativo como <b>${esc(T.profile?.name || "")}</b>${T.profile?.cref ? ` · CREF ${esc(T.profile.cref)}` : ""}. ${T.students.length} aluno(s).</div>
    <a class="btn sm" href="#/alunos" style="margin-top:10px">Abrir meus alunos</a>`;
  return `<div class="small muted">É personal trainer? Ative para acompanhar alunos pelo site.</div><button class="btn sm" data-tact="become" style="margin-top:10px">Ativar modo personal</button>`;
}

export const scopeOf = (col) => ["weights", "measurements", "profile"].includes(col) ? "body"
  : ["foods", "water", "savedFoods", "fasting"].includes(col) ? "food"
  : ["workouts", "routines", "cardio"].includes(col) ? "training"
  : ["moods", "sleep", "practices", "gratitude", "habits", "habitLogs"].includes(col) ? "mind" : "none";
