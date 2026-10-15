// docs/demo/app.js — the claude-kit status line demo.
//
// The rule this file is built around: no intermediate state is invented. Every frame of the bar
// is a line that the real statusline.sh printed (docs/demo/grid.json, tools/render-grid.sh).
// Animation happens only BETWEEN two real cells: a sector fades from the old text to the new one,
// a halo marks it, and a wire runs from the control that caused it. No number is interpolated.
import { createTutorial, hasSeen } from "./tutorial/tutorial.js";
import { CONTENT } from "./content.js";

const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
const narrow = () => innerWidth < 768;
const GH = "https://github.com/IchiSieben/claude-kit/blob/main/";

// control -> the sectors it governs (#18, the hint, can follow any of them)
const CTL_SECS = { 0: ["1", "2"], 1: ["3", "4", "5", "18"], 2: ["10", "11", "12", "18"], 3: ["8", "9", "18"], 4: ["14", "18"], 5: ["15", "18"] };
const SEC_CTLS = {};
for (const [c, ss] of Object.entries(CTL_SECS)) for (const s of ss) (SEC_CTLS[s] ||= []).push(+c);
const ORDER = ["1", "2", "node", "3", "4", "5", "6", "7", "10", "8", "9", "11", "12", "13", "14", "15", "16", "17", "18"];
const CTX_K = [60, 180, 320, 385];

// ---------------------------------------------------------------- copy (UI only; sectors live in content.js)
const T = {
  es: {
    navBar: "La barra", navMeaning: "Qué significa", navTake: "Qué te llevas",
    eyebrow: "claude-kit · barra de estado", title: "Tu sesión de Claude Code, en dos líneas.",
    lead: n => `Mueve un control y mira qué cambia en la barra, y por qué. Cada estado es la salida real de <code>statusline.sh</code>: <b>${n} renders, ninguno inventado</b>.`,
    captionIdle: "Toca cualquier parte de la barra, o mueve un control.",
    modeExplore: "Explorar", modeSession: "Reproducir una sesión",
    model: "Modelo y esfuerzo", context: "Contexto usado", cache: "Caché de prompt", quota: "Cuota del plan", git: "Git", handoff: "HANDOFF.md",
    tourAgain: "Ver el recorrido otra vez", eyebrowMeaning: "18 sectores · 3 niveles", meaningTitle: "Qué significa cada cosa",
    meaningIntro: "En el orden en que se leen. Cada tarjeta explica su sector tres veces: para un niño, qué mide exactamente y por qué está ahí. La tira oscura repite los estados reales de ese sector.",
    kid: "Para un niño", measures: "Qué mide", whyLabel: "Por qué está ahí", show: "Ver en la barra ↑", glossary: "Glosario de símbolos",
    eyebrowTake: "~/.claude", takeTitle: "Qué te llevas al descargar",
    takeIntro: "Todo es texto que puedes leer: reglas, agentes, skills y hooks que se copian a <code>~/.claude</code>. La barra es solo uno de esos archivos.",
    installTitle: "Instalar en tres comandos", copy: "Copiar", copied: "Copiado",
    notouch: "Después, reinicia Claude Code. <b>No toca</b> tu <code>model</code>, tus plugins ni tu tema: esas claves son de cada máquina, y la copia respalda lo que reemplaza.",
    linkRepo: "Repositorio", linkLesson: "Lección 01 · Lee tu barra", linkCard: "Ficha en el portafolio",
    foot: "Generado por <code>tools/render-grid.sh</code>: cada combinación de controles pasó por el <code>statusline.sh</code> real. Si la barra cambia, <code>verify.sh</code> falla hasta que se regenere. Ningún estado intermedio es inventado: la animación solo ocurre entre dos salidas reales.",
    tline: "Momento de la sesión", meta: (d, h, n) => `${n} renders · ${d} · entradas ${h}`, theme: "Cambiar tema", play: "Reproducir", pause: "Pausa",
    load: "No se pudo cargar grid.json. Abre la página desde un servidor (no file://).",
    barLabel: "Barra de estado", absent: "No aparece en este estado; te muestro uno real donde sí.",
    only16: "Solo aparece cuando falta <code>rules/thresholds.json</code>: este es ese render real. Mueve cualquier control para volver.",
    seeCard: "Ver la tarjeta ↓",
    opts: [["Opus 5.5 · high", "Sonnet 5.5 · medium", "Haiku 5.5 · low"], null, ["caliente · 42 min", "enfriando · 4 min", "fría"],
      ["5h 20% · 7d 30%", "5h 41% · 7d 87%", "5h 93% · 7d 97%"], ["al día", "1 commit sin push", "+ 2 modificados", "+ 1 nuevo"],
      ["hace 10 min", "hace 7 h", "no existe"]],
    hint: h => h ? ` La pista magenta pasó a <q>${esc(h)}</q>.` : " La pista magenta desaparece: nada es urgente.",
    sameHint: "",
    why: {
      0: (s) => `Cambiaste a <b>${["Opus 5.5 con esfuerzo high", "Sonnet 5.5 con esfuerzo medium", "Haiku 5.5 con esfuerzo low"][s[0]]}</b>: solo cambian los sectores 1 y 2. En una sesión real, cambiar de modelo o de esfuerzo invalida la caché.`,
      1: (a, b, th) => {
        const band = k => k >= th("context-red") ? "roja" : k >= th("context-amber") ? "ámbar" : "verde";
        const A = CTX_K[a[1]], B = CTX_K[b[1]];
        if (band(A) === band(B)) return `Pasaste de ${A}k a ${B}k: sigues en la banda ${band(B)}, la barra solo se alarga.`;
        if (B > A) return `Pasaste de ${A}k a ${B}k: cruzaste la banda ${band(B)} (${band(B) === "roja" ? th("context-red") : th("context-amber")}k), por eso la barra se pone ${band(B) === "roja" ? "roja y aparece ⚠" : "ámbar"}.`;
        return `Bajaste de ${A}k a ${B}k: vuelves a la banda ${band(B)}.`;
      },
      2: (a, b, th) => [
        `Caché caliente: le quedan 42 min antes de expirar, así que el próximo turno la reutiliza y sale barato. El hit está en 96 % (≥ ${th("cache-hit-ok")} %), por eso la barra ni lo muestra.`,
        `Quedan 4 min (≤ ${th("cache-cooling")}): la barra pasa a ámbar «enfriando». Como el hit bajó a 79 % (< ${th("cache-hit-ok")} %), aparece <code>hit 79%</code>.`,
        `La caché expiró: el próximo turno reescribe todo el contexto y se paga otra vez. El hit cayó a 41 % (< ${th("cache-cold")} %), en rojo, con 9 fallos.`][b[2]],
      3: (a, b, th) => [
        `Cuota baja: 5h al 20 %, 7d al 30 %. Ningún umbral de cuota se cruza.`,
        `5h al 41 %, 7d al 87 %. La barra solo tiene umbral para las 5 h (${th("quota-5h")} %), así que 87 % en 7 días se muestra pero no dispara nada.`,
        `5h al 93 %: pasó el umbral de ${th("quota-5h")} %. Es el de mayor prioridad, así que su pista gana a cualquier otra.`][b[3]],
      4: (a, b, th) => [
        `Al día con origin: <code>↑0 ↓0 ●0 ?0</code>. Nada por subir, nada modificado.`,
        `Un commit sin push de hace 3 h: <code>↑1</code> se pone ámbar porque pasó el margen de ${Math.round(thp("unpushed") / 3600)} h.`,
        `Además, 2 archivos modificados: <code>●2</code>. HANDOFF.md cuenta los archivos más nuevos que él (<code>·2f</code>).`,
        `Y un archivo nuevo que git todavía no sigue: <code>?1</code>.`][b[4]],
      5: (a, b) => [
        `HANDOFF.md se escribió hace 10 min. Si algo cambió después (commits, archivos), la barra lo cuenta como deriva.`,
        `HANDOFF.md es de hace 7 h: la barra muestra la hora en que se escribió y cuenta lo que cambió desde entonces (<code>·f</code> archivos, <code>·c</code> commits, <code>·s</code> sesiones).`,
        `No hay HANDOFF.md: la barra dice <code>⚠ sin HANDOFF</code>. Nunca lo da por bueno.`][b[5]],
    },
    tour: [
      ["Esta es la barra", "Las dos líneas de abajo son lo que Claude Code imprime al pie de tu terminal en cada respuesta. Todo lo que ves aquí lo escribió el <code>statusline.sh</code> real."],
      ["Modelo y esfuerzo", "Lo primero: con quién hablas y cuánto se esfuerza. Mira cómo cambian solo esos dos sectores."],
      ["Contexto", "Subo el contexto hasta la banda roja. La barra se llena, se pone roja, aparece ⚠ y la pista magenta te dice qué hacer: <code>/handoff</code> primero."],
      ["Caché", "Caliente, enfriando, fría. Cuando se enfría, el próximo turno vuelve a escribir todo el contexto en la caché, y eso se paga. Por eso avisa antes."],
      ["Cuota", "Cuánto llevas del plan en 5 horas y en 7 días. Al pasar el umbral de 5 h, su pista gana a todas las demás."],
      ["Git", "Uno por uno: <code>↑1</code> un commit sin subir, <code>●2</code> dos archivos modificados, <code>?1</code> un archivo nuevo sin seguimiento."],
      ["HANDOFF", "Tu nota de traspaso: fresca, de hace 7 horas, o ausente. La barra mide la deriva: cuánto cambió el repo desde que la escribiste."],
      ["Ahora tú", "Mueve cualquier control. La línea te muestra qué causó qué. También puedes reproducir una sesión de 3 horas desde la pestaña de arriba."],
    ],
    tourLabels: { next: "Siguiente", prev: "Atrás", done: "Empezar", skip: "Saltar", of: "de", read: s => `${s} s de lectura` },
    tree: [
      ["CLAUDE.md", 0, "las reglas de trabajo que se releen en cada sesión; menos de 70 líneas a propósito", "README.es.md#instalación"],
      ["statusline.sh", 0, "esta barra: lee el JSON de Claude Code y escribe dos líneas", "docs/statusline.es.md"],
      ["settings.json", 0, "solo claves portables: la barra, los hooks y el entorno", "README.es.md#instalación"],
      ["MANUAL.md", 0, "el manual en 7 capítulos, con la fuente de cada regla", "docs/manual-and-now.es.md"],
      ["rules/", 0, "", ""],
      ["thresholds.json", 1, "todos los números de la barra, en un solo lugar", "docs/thresholds.es.md"],
      ["models.json · routing.json", 1, "qué modelo y qué esfuerzo para cada tipo de tarea", "docs/routing.es.md"],
      ["context-hygiene.md · learning-mode.md", 1, "reglas que siempre están cargadas", "docs/context.es.md"],
      ["agents/  (6)", 0, "mecanico · operario · redactor · investigador · profundo · reviewer", "docs/reviewer.es.md"],
      ["skills/  (10)", 0, "/ahora /handoff /kickoff /spec /route /manual /visor /xreview /tercerizar /kit-update", "docs/handoff.es.md"],
      ["hooks/  (5)", 0, "avisa la deriva del HANDOFF, guarda un borrador antes de compactar, registra eventos y fallos", "docs/hooks.es.md"],
      ["modules/enjambre/", 0, "opcional: delega trabajo a otra máquina", "README.es.md"],
    ],
    lesson: "docs/leccion-01-lee-tu-barra.md", card: "https://ichisieben.dev/es/projects/claude-kit/",
  },
  en: {
    navBar: "The bar", navMeaning: "What it means", navTake: "What you get",
    eyebrow: "claude-kit · status line", title: "Your Claude Code session, in two lines.",
    lead: n => `Move a control and watch what changes in the bar, and why. Every state is the real output of <code>statusline.sh</code>: <b>${n} renders, none made up</b>. The bar's own words are Spanish; they come from <code>thresholds.json</code>.`,
    captionIdle: "Tap any part of the bar, or move a control.",
    modeExplore: "Explore", modeSession: "Replay a session",
    model: "Model and effort", context: "Context used", cache: "Prompt cache", quota: "Plan quota", git: "Git", handoff: "HANDOFF.md",
    tourAgain: "Show the tour again", eyebrowMeaning: "18 sectors · 3 levels", meaningTitle: "What every part means",
    meaningIntro: "In reading order. Each card explains its sector three times: for a kid, what it measures exactly, and why it is there. The dark strip cycles through that sector's real states.",
    kid: "For a kid", measures: "What it measures", whyLabel: "Why it is there", show: "Show in the bar ↑", glossary: "Symbol glossary",
    eyebrowTake: "~/.claude", takeTitle: "What you get when you download it",
    takeIntro: "All of it is text you can read: rules, agents, skills and hooks copied into <code>~/.claude</code>. The bar is just one of those files.",
    installTitle: "Install in three commands", copy: "Copy", copied: "Copied",
    notouch: "Then restart Claude Code. It <b>does not touch</b> your <code>model</code>, plugins or theme: those keys belong to each machine, and the copy backs up whatever it replaces.",
    linkRepo: "Repository", linkLesson: "Lesson 01 · Read your bar", linkCard: "Portfolio card",
    foot: "Generated by <code>tools/render-grid.sh</code>: every combination of controls went through the real <code>statusline.sh</code>. If the bar changes, <code>verify.sh</code> fails until it is re-rendered. No intermediate state is made up: animation only happens between two real outputs.",
    tline: "Moment of the session", meta: (d, h, n) => `${n} renders · ${d} · inputs ${h}`, theme: "Toggle theme", play: "Play", pause: "Pause",
    load: "Could not load grid.json. Open the page from a server (not file://).",
    barLabel: "Status line", absent: "Not shown in this state; here is a real one where it is.",
    only16: "Only appears when <code>rules/thresholds.json</code> is missing: this is that real render. Move any control to go back.",
    seeCard: "Open its card ↓",
    opts: [["Opus 5.5 · high", "Sonnet 5.5 · medium", "Haiku 5.5 · low"], null, ["warm · 42 min", "cooling · 4 min", "cold"],
      ["5h 20% · 7d 30%", "5h 41% · 7d 87%", "5h 93% · 7d 97%"], ["in sync", "1 unpushed commit", "+ 2 modified", "+ 1 new"],
      ["10 min ago", "7 h ago", "missing"]],
    hint: h => h ? ` The magenta hint is now <q>${esc(h)}</q>.` : " The magenta hint goes away: nothing is urgent.",
    sameHint: "",
    why: {
      0: (s) => `You switched to <b>${["Opus 5.5 at high effort", "Sonnet 5.5 at medium effort", "Haiku 5.5 at low effort"][s[0]]}</b>: only sectors 1 and 2 change. In a real session, switching model or effort invalidates the cache.`,
      1: (a, b, th) => {
        const band = k => k >= th("context-red") ? "red" : k >= th("context-amber") ? "amber" : "green";
        const A = CTX_K[a[1]], B = CTX_K[b[1]];
        if (band(A) === band(B)) return `From ${A}k to ${B}k: still in the ${band(B)} band, the bar only grows.`;
        if (B > A) return `From ${A}k to ${B}k: you crossed into the ${band(B)} band (${band(B) === "red" ? th("context-red") : th("context-amber")}k), so the bar turns ${band(B) === "red" ? "red and ⚠ appears" : "amber"}.`;
        return `Down from ${A}k to ${B}k: back to the ${band(B)} band.`;
      },
      2: (a, b, th) => [
        `Warm cache: 42 min before it expires, so the next turn reuses it cheaply. Hit rate is 96% (≥ ${th("cache-hit-ok")}%), so the bar does not even show it.`,
        `4 min left (≤ ${th("cache-cooling")}): the bar turns amber, «enfriando» (cooling). The hit rate dropped to 79% (< ${th("cache-hit-ok")}%), so <code>hit 79%</code> appears.`,
        `The cache expired: the next turn rewrites the whole context and pays for it again. Hit rate fell to 41% (< ${th("cache-cold")}%), in red, with 9 misses.`][b[2]],
      3: (a, b, th) => [
        `Low quota: 5h at 20%, 7d at 30%. No quota threshold is crossed.`,
        `5h at 41%, 7d at 87%. The bar only has a threshold for the 5 hours (${th("quota-5h")}%), so 87% over 7 days shows but triggers nothing.`,
        `5h at 93%: past the ${th("quota-5h")}% threshold. It has the highest priority, so its hint beats every other one.`][b[3]],
      4: (a, b, th) => [
        `In sync with origin: <code>↑0 ↓0 ●0 ?0</code>. Nothing to push, nothing modified.`,
        `One commit, 3 h old, not pushed: <code>↑1</code> turns amber because it is past the ${Math.round(thp("unpushed") / 3600)} h grace.`,
        `Plus 2 modified files: <code>●2</code>. HANDOFF.md counts the files newer than itself (<code>·2f</code>).`,
        `And one new file git does not track yet: <code>?1</code>.`][b[4]],
      5: (a, b) => [
        `HANDOFF.md was written 10 min ago. Anything that changed after it (commits, files) is counted as drift.`,
        `HANDOFF.md is 7 h old: the bar prints the time it was written and counts what changed since (<code>·f</code> files, <code>·c</code> commits, <code>·s</code> sessions).`,
        `There is no HANDOFF.md: the bar says <code>⚠ sin HANDOFF</code> (no HANDOFF). It never assumes it is fine.`][b[5]],
    },
    tour: [
      ["This is the bar", "The two lines below are what Claude Code prints at the foot of your terminal on every reply. Everything here was written by the real <code>statusline.sh</code>."],
      ["Model and effort", "First: who you are talking to and how hard it thinks. Watch only those two sectors change."],
      ["Context", "Raising the context into the red band. The bar fills, turns red, ⚠ appears and the magenta hint tells you what to do: <code>/handoff</code> first."],
      ["Cache", "Warm, cooling, cold. Once it is cold, the next turn writes the whole context into the cache again, and that is billed. That is why it warns you early."],
      ["Quota", "How much of your plan you used in 5 hours and in 7 days. Past the 5-hour threshold, its hint beats every other."],
      ["Git", "One at a time: <code>↑1</code> a commit not pushed, <code>●2</code> two modified files, <code>?1</code> a new untracked file."],
      ["HANDOFF", "Your hand-over note: fresh, 7 hours old, or missing. The bar measures drift: how much the repo changed since you wrote it."],
      ["Your turn", "Move any control. The wire shows what caused what. You can also replay a 3-hour session from the tab above."],
    ],
    tourLabels: { next: "Next", prev: "Back", done: "Start", skip: "Skip", of: "of", read: s => `${s} s read` },
    tree: [
      ["CLAUDE.md", 0, "the working rules re-read every session; under 70 lines on purpose", "README.md#install"],
      ["statusline.sh", 0, "this bar: reads Claude Code's JSON and writes two lines", "docs/statusline.md"],
      ["settings.json", 0, "portable keys only: the bar, the hooks and the env", "README.md#install"],
      ["MANUAL.md", 0, "the 7-chapter manual, every rule with its source", "docs/manual-and-now.md"],
      ["rules/", 0, "", ""],
      ["thresholds.json", 1, "every number the bar reacts to, in one place", "docs/thresholds.md"],
      ["models.json · routing.json", 1, "which model and effort for each kind of task", "docs/routing.md"],
      ["context-hygiene.md · learning-mode.md", 1, "rules that are always loaded", "docs/context.md"],
      ["agents/  (6)", 0, "mecanico · operario · redactor · investigador · profundo · reviewer", "docs/reviewer.md"],
      ["skills/  (10)", 0, "/ahora /handoff /kickoff /spec /route /manual /visor /xreview /tercerizar /kit-update", "docs/handoff.md"],
      ["hooks/  (5)", 0, "warns on HANDOFF drift, drafts a handoff before compacting, logs events and failures", "docs/hooks.md"],
      ["modules/enjambre/", 0, "optional: hand work to another machine", "README.md"],
    ],
    lesson: "docs/leccion-01-lee-tu-barra.en.md", card: "https://ichisieben.dev/en/projects/claude-kit/",
  },
};

// ---------------------------------------------------------------- state
let lang = document.documentElement.lang === "en" ? "en" : "es";  // decided by the inline script in <head>
const state = [0, 1, 0, 1, 1, 1];
let grid = null, mode = "explore", sIdx = 0, picked = null, shown = null, playing = null, tour = null;
const initial = (() => { try { return JSON.parse($("#initial").textContent); } catch (e) { return {}; } })();
const L = () => T[lang];
const th = id => grid?.thresholds?.[id]?.value ?? "?";
const thp = id => grid?.thresholds?.[id]?.param ?? NaN;
const fill = html => html.replace(/\{th:([\w-]+)\}/g, (_, id) => th(id)).replace(/\{param:([\w-]+)\}/g, (_, id) => thp(id));

// ---------------------------------------------------------------- ANSI + sectors (the numbers are rows of docs/statusline.md)
function parseAnsi(line) {
  const out = []; let bold = false, fg = 0;
  for (let i = 0; i < line.length;) {
    if (line[i] === "\x1b" && line[i + 1] === "[") {
      const j = line.indexOf("m", i);
      for (const c of line.slice(i + 2, j).split(";").map(Number)) { if (c === 0) { bold = false; fg = 0; } else if (c === 1) bold = true; else if (c >= 30 && c <= 37) fg = c; }
      i = j + 1; continue;
    }
    const ch = String.fromCodePoint(line.codePointAt(i));
    out.push({ ch, cls: ((bold ? "b " : "") + (fg ? "c" + fg : "")).trim() }); i += ch.length;
  }
  return out;
}
const RULES = [
  [/^⚠ umbrales/, "16"], [/^·(?:low|medium|high|xhigh|max)\b/, "2"], [/^@\S+/, "node"], [/^[▓░┋]+/, "3"],
  [/^\d+k\/\d+k(?: ⚠)?/, "4"], [/^\d+% of \d+[kM]/, "5"], [/^\$[\d.⚠]+/, "6"], [/^[⚡❄]︎?.*$/, "10"], [/^⚠ caché/, "10"],
  [/^\d+m\b|^⚠m/, "7"], [/^5h \S+/, "8"], [/^7d \S+/, "9"], [/^hit \S+/, "11"], [/^\(\S+ miss\)/, "12"],
  [/^\+\d+\/-\d+|^⚠ diff/, "13"], [/^⎇.*?(?=  |$)/, "14"], [/^(?:✓|⚠ ?)(?:sin )?HANDOFF.*?(?=  |$)/, "15"], [/^\[[^\]]*\]/, "17"],
];
function sectorize(cells, first) {
  const text = cells.map(c => c.ch).join(""), sec = new Array(cells.length).fill(null);
  const off = []; let k = 0; for (const c of cells) { off.push(k); k += c.ch.length; }
  const cellAt = o => { let lo = 0, hi = off.length - 1; while (lo < hi) { const m = (lo + hi + 1) >> 1; if (off[m] <= o) lo = m; else hi = m - 1; } return lo; };
  let o = 0;
  if (first) { const m = text.match(/^.*?(?= ·| @|$)/); if (m && m[0]) { for (let i = cellAt(0); i <= cellAt(m[0].length - 1); i++) sec[i] = "1"; o = m[0].length; } }
  while (o < text.length) {
    // the hint (#18) is the magenta tail of line 2: once it starts, no other rule applies
    if (/c35/.test(cells[cellAt(o)].cls) && text[o].trim()) { for (let i = cellAt(o); i < cells.length; i++) sec[i] = "18"; break; }
    const rest = text.slice(o); let hit = null;
    for (const [re, id] of RULES) { const m = rest.match(re); if (m && m[0]) { hit = [m[0].length, id]; break; } }
    if (hit) { for (let i = cellAt(o), b = cellAt(o + hit[0] - 1); i <= b; i++) sec[i] = hit[1]; o += hit[0]; } else o += 1;
  }
  cells.forEach((c, i) => { if (!sec[i] && /c35/.test(c.cls) && c.ch.trim()) sec[i] = "18"; });
  const h = sec.map((s, i) => s === "18" ? i : -1).filter(i => i >= 0);
  if (h.length) for (let i = h[0]; i <= h[h.length - 1]; i++) if (!sec[i]) sec[i] = "18";
  return sec;
}
// one line -> runs [{k, sec, html, text}]; gaps between sectors are keyed by the sector before them
const runCache = new Map();
function runs(raw, first) {
  const ck = (first ? "1" : "2") + raw;
  if (runCache.has(ck)) return runCache.get(ck);
  const cells = parseAnsi(raw), sec = sectorize(cells, first), out = [];
  let i = 0, prev = "start";
  while (i < cells.length) {
    const s = sec[i]; let j = i, html = "", text = "";
    while (j < cells.length && sec[j] === s) {
      let q = j, t = "";
      while (q < cells.length && sec[q] === s && cells[q].cls === cells[j].cls) { t += cells[q].ch; q++; }
      html += cells[j].cls ? `<span class="${cells[j].cls}">${esc(t)}</span>` : esc(t); text += t; j = q;
    }
    out.push({ k: s ? "s" + s : "g" + prev, sec: s, html, text }); if (s) prev = s; i = j;
  }
  runCache.set(ck, out);
  return out;
}

// ---------------------------------------------------------------- the bar
const bar = $("#bar");
function idsNow() {
  if (shown) return shown;
  if (!grid) return null;
  return mode === "session" ? grid.session[sIdx].ids : grid.cells[state.join(".")];
}
const linesOf = ids => ids.map(i => grid.lines[i]);
function paint(lines) {
  $$(".ln", bar).forEach((el, n) => {
    el.innerHTML = (lines[n] !== undefined ? runs(lines[n], n === 0) : []).map(r => r.sec
      ? `<button type="button" class="sec${picked === r.sec ? " sel" : ""}" data-sec="${r.sec}" data-k="${r.k}">${r.html}</button>`
      : `<span data-k="${r.k}">${r.html}</span>`).join("");
  });
}
const relTo = (el, box) => { const a = el.getBoundingClientRect(), b = box.getBoundingClientRect(); return { x: a.left - b.left, y: a.top - b.top, w: a.width, h: a.height }; };

// Paint the new cell and animate only the difference. Returns the sectors whose text changed.
function transition(lines, from) {
  const before = new Map();
  $$("[data-k]", bar).forEach(el => before.set(el.parentElement.dataset.n + el.dataset.k, { r: relTo(el, bar), text: el.textContent, html: el.innerHTML, sec: el.dataset.sec, line: el.parentElement }));
  paint(lines);
  const wireOn = from && !narrow();
  const delay = wireOn ? (reduced ? 200 : 380) : 0;
  const changed = [], seen = new Set();
  $$("[data-k]", bar).forEach(el => {
    const id = el.parentElement.dataset.n + el.dataset.k, old = before.get(id); seen.add(id);
    if (old && old.text === el.textContent) {
      if (reduced) return;
      const r = relTo(el, bar), dx = old.r.x - r.x, dy = old.r.y - r.y;
      if (Math.abs(dx) > .5 || Math.abs(dy) > .5)
        el.animate([{ transform: `translate(${dx}px,${dy}px)` }, { transform: "none" }], { duration: 450, delay, easing: "cubic-bezier(.22,1,.36,1)", fill: "backwards" });
      return;
    }
    el.style.animationDelay = delay + "ms";
    el.classList.add("in");
    if (el.dataset.sec) { el.classList.add("halo"); changed.push(el.dataset.sec); }
    el.addEventListener("animationend", e => { if (e.animationName === "halo") el.classList.remove("halo", "in"); }, { once: false });
    if (old) ghost(old, delay);
  });
  for (const [id, old] of before) if (!seen.has(id)) ghost(old, delay);
  if (wireOn && changed.length) wires(from, changed.map(s => bar.querySelector(`[data-sec="${s}"]`)).filter(Boolean));
  return changed;
}
function ghost(old, delay) {
  const g = document.createElement("span");
  g.className = "ghost"; g.innerHTML = old.html; g.setAttribute("aria-hidden", "true");
  g.style.left = old.r.x + "px"; g.style.top = old.r.y + "px"; g.style.animationDelay = delay + "ms";
  bar.appendChild(g); g.addEventListener("animationend", () => g.remove());
}
$$(".ln", bar).forEach((el, n) => { el.dataset.n = n; });
bar.style.position = "relative";

// ---------------------------------------------------------------- wires: control -> sector
const svg = $("#wires"), stage = $("#stage"), NS = "http://www.w3.org/2000/svg";
function wires(from, targets) {
  const s = stage.getBoundingClientRect();
  const f = from.getBoundingClientRect ? from.getBoundingClientRect() : from;
  const ax = (f.x ?? f.left) + (f.w ?? f.width) / 2 - s.left, ay = (f.y ?? f.top) - s.top;
  for (const t of targets.slice(0, 4)) {
    const r = t.getBoundingClientRect(), bx = r.left + r.width / 2 - s.left, by = r.bottom - s.top + 4;
    const my = (ay + by) / 2;
    const p = document.createElementNS(NS, "path");
    p.setAttribute("d", `M${ax},${ay} C${ax},${my} ${bx},${my} ${bx},${by}`);
    svg.appendChild(p);
    const len = p.getTotalLength();
    p.style.strokeDasharray = len; p.style.strokeDashoffset = reduced ? 0 : len;
    if (reduced) p.animate([{ opacity: 0 }, { opacity: .9 }], { duration: 200, fill: "forwards" });
    else p.animate([{ strokeDashoffset: len }, { strokeDashoffset: 0 }], { duration: 500, easing: "cubic-bezier(.22,1,.36,1)", fill: "forwards" });
    if (!reduced) {  // the traffic dot of ArqViva: travels the wire once, then rests on the sector
      const c = document.createElementNS(NS, "circle"); c.setAttribute("r", "4"); svg.appendChild(c);
      const t0 = performance.now();
      const step = now => {
        const k = Math.min(1, (now - t0) / 500), e = 1 - Math.pow(1 - k, 3), pt = p.getPointAtLength(e * len);
        c.setAttribute("transform", `translate(${pt.x},${pt.y})`);
        if (k < 1) requestAnimationFrame(step); else c.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 300, delay: 250, fill: "forwards" }).onfinish = () => c.remove();
      };
      requestAnimationFrame(step);
    }
    p.animate([{ opacity: 1 }, { opacity: 0 }], { duration: 320, delay: 900, fill: "forwards", easing: "cubic-bezier(.4,0,1,1)" }).onfinish = () => p.remove();
  }
}

// ---------------------------------------------------------------- caption
const cap = $("#caption");
function say(html, anchor) {
  cap.innerHTML = `<span class="msg in">${html}</span>`;
  if (anchor) {
    const c = cap.getBoundingClientRect(), a = anchor.getBoundingClientRect();
    cap.style.setProperty("--nx", Math.max(18, Math.min(c.width - 30, a.left + a.width / 2 - c.left - 6)) + "px");
  }
}
const hintOf = lines => (runs(lines[1] || "", false).find(r => r.sec === "18") || {}).text || "";

// ---------------------------------------------------------------- controls
function buildControls() {
  $$(".ctl").forEach(f => {
    const c = +f.dataset.c, seg = $(".seg", f);
    if (seg) seg.innerHTML = L().opts[c].map((t, i) => `<label><input type="radio" name="c${c}" value="${i}"${state[c] === i ? " checked" : ""}><span>${esc(t)}</span></label>`).join("");
  });
  syncCtx();
}
function syncCtx() {
  $("#ctx").value = state[1];
  $("#ctxv").textContent = CTX_K[state[1]] + "k";
  $$("#ctxt span").forEach((s, i) => s.classList.toggle("on", i === state[1]));
  $("#ctx").setAttribute("aria-valuetext", CTX_K[state[1]] + "k");
}
function setCtl(c, v, user = true) {
  if (!grid || (state[c] === v && !shown && mode === "explore")) return;
  if (mode !== "explore") setMode("explore", false);
  const a = state.slice(), oldLines = linesOf(idsNow());
  state[c] = v; shown = null;
  if (c === 1) syncCtx(); else { const r = $(`input[name="c${c}"][value="${v}"]`); if (r) r.checked = true; }
  const lines = linesOf(idsNow());
  const changed = transition(lines, $(`.ctl[data-c="${c}"]`));
  const oh = hintOf(oldLines), nh = hintOf(lines);
  const W = L().why[c];
  say(W(a, state, th) + (oh !== nh ? L().hint(nh) : ""), bar.querySelector(`[data-sec="${changed.find(s => s !== "18") || CTL_SECS[c][0]}"]`));
}
$("#controls").addEventListener("change", e => {
  const t = e.target;
  if (t.id === "ctx") setCtl(1, +t.value); else if (t.name) setCtl(+t.name.slice(1), +t.value);
});
$("#ctx").addEventListener("input", e => setCtl(1, +e.target.value));
// keyboard focus on a control pre-lights its sectors; pointer on a sector lights its controls
const preSecs = (c, on) => CTL_SECS[c]?.forEach(s => bar.querySelector(`[data-sec="${s}"]`)?.classList.toggle("pre", on));
$("#controls").addEventListener("focusin", e => { const f = e.target.closest(".ctl"); if (f) preSecs(f.dataset.c, true); });
$("#controls").addEventListener("focusout", e => { const f = e.target.closest(".ctl"); if (f) preSecs(f.dataset.c, false); });
$$(".ctl").forEach(f => { f.addEventListener("pointerenter", () => preSecs(f.dataset.c, true)); f.addEventListener("pointerleave", () => preSecs(f.dataset.c, false)); });
const preCtls = (s, on) => (SEC_CTLS[s] || []).forEach(c => $(`.ctl[data-c="${c}"]`)?.classList.toggle("pre", on));
bar.addEventListener("pointerover", e => { const b = e.target.closest(".sec"); if (b) preCtls(b.dataset.sec, true); });
bar.addEventListener("pointerout", e => { const b = e.target.closest(".sec"); if (b) preCtls(b.dataset.sec, false); });
bar.addEventListener("focusin", e => { const b = e.target.closest(".sec"); if (b) preCtls(b.dataset.sec, true); });
bar.addEventListener("focusout", e => { const b = e.target.closest(".sec"); if (b) preCtls(b.dataset.sec, false); });
bar.addEventListener("click", e => { const b = e.target.closest(".sec"); if (b) pick(b.dataset.sec, b); });

function pick(sec, el) {
  picked = sec;
  $$(".sec", bar).forEach(b => b.classList.toggle("sel", b.dataset.sec === sec));
  $$(".card").forEach(c => c.classList.toggle("sel", c.dataset.sec === sec));
  const C = CONTENT[lang].sectors[sec];
  if (!C) return;
  say(`<span class="k">${sec === "node" ? "@" : "#" + sec}</span><b>${C.name}</b> — ${fill(C.kid)} <a class="more" href="#card-${sec}">${L().seeCard}</a>`, el);
}

// ---------------------------------------------------------------- session replay
const tline = $("#tline");
const fmt = t => `${Math.floor(t / 60)}:${String(t % 60).padStart(2, "0")}`;
function setMode(m, focus = true) {
  mode = m; shown = null; stopPlay();
  $("#tab-explore").setAttribute("aria-selected", m === "explore");
  $("#tab-session").setAttribute("aria-selected", m === "session");
  $("#controls").hidden = m !== "explore"; $("#session").hidden = m !== "session";
  if (!grid) return;
  const lines = linesOf(idsNow());
  transition(lines, null);
  if (m === "session") sayStep(); else say(esc(L().captionIdle));
  if (focus) (m === "session" ? tline : $("#controls input")).focus({ preventScroll: true });
}
$("#tab-explore").addEventListener("click", () => setMode("explore"));
$("#tab-session").addEventListener("click", () => setMode("session"));
$(".modes").addEventListener("keydown", e => {
  if (e.key === "ArrowRight" || e.key === "ArrowLeft") { const n = mode === "explore" ? "session" : "explore"; setMode(n, false); $(`#tab-${n}`).focus(); }
});
function sayStep() {
  const t = grid.session[sIdx].t;
  $("#clock").textContent = fmt(t);
  tline.setAttribute("aria-valuetext", fmt(t));
  say(`<span class="k">${fmt(t)}</span>${fill(CONTENT[lang].session[String(t)] || "")}`, null);
}
function thumb() {
  const r = tline.getBoundingClientRect(), k = sIdx / (grid.session.length - 1);
  return { x: r.left + 10 + k * (r.width - 20) - 6, y: r.top, w: 12, h: r.height };
}
function setStep(i) {
  if (!grid) return;
  sIdx = Math.max(0, Math.min(grid.session.length - 1, i)); tline.value = sIdx; shown = null;
  transition(linesOf(idsNow()), thumb());
  sayStep();
}
tline.addEventListener("input", () => setStep(+tline.value));
function stopPlay() { if (playing) { clearInterval(playing); playing = null; } $("#play").textContent = "▶"; $("#play").setAttribute("aria-label", L().play); }
$("#play").addEventListener("click", () => {
  if (playing) return stopPlay();
  if (sIdx >= grid.session.length - 1) setStep(0);
  $("#play").textContent = "❚❚"; $("#play").setAttribute("aria-label", L().pause);
  playing = setInterval(() => { if (sIdx >= grid.session.length - 1) return stopPlay(); setStep(sIdx + 1); }, 3200);
});

// ---------------------------------------------------------------- the tour (shared/tutorial, steps that move real controls)
let timers = [];
const clearTimers = () => { timers.forEach(clearTimeout); timers = []; };
const seq = (steps, gap = 1500) => steps.forEach(([c, v], i) => timers.push(setTimeout(() => setCtl(c, v), 450 + i * gap)));
const RUNS = [
  () => {}, () => seq([[0, 1], [0, 2], [0, 0]]), () => seq([[1, 0], [1, 1], [1, 2]], 1700), () => seq([[2, 0], [2, 1], [2, 2]], 1900),
  () => seq([[3, 0], [3, 2]], 2200), () => seq([[4, 0], [4, 1], [4, 2], [4, 3]], 1600), () => seq([[5, 0], [5, 1], [5, 2]], 1900), () => {},
];
function makeTour() {
  tour?.destroy();
  const words = s => s.replace(/<[^>]+>/g, "").split(/\s+/).length;
  tour = createTutorial({
    id: "claude-kit-demo-v2", auto: false,
    steps: L().tour.map(([title, body], i) => ({ title, body, target: i === 7 ? ".modes" : "#screen", placement: "bottom", read: Math.max(6, Math.round(words(body) / 3.3) + 3) })),
    labels: L().tourLabels,
    onStep: (step, i) => {
      clearTimers();
      if (mode !== "explore") setMode("explore", false);
      if (i === 0) { state.splice(0, 6, 0, 0, 0, 0, 0, 0); shown = null; transition(linesOf(idsNow()), null); buildControls(); }
      RUNS[i]?.();
    },
    onClose: clearTimers,
  });
}
$("#tour").addEventListener("click", () => { makeTour(); tour.open(); });

// ---------------------------------------------------------------- cards: 18 sectors x 3 levels, each with its real states
const states = {};  // sector -> [html of each distinct real rendering]
// ~1 300 lines to parse: done in slices that yield to the main thread (one long task = TBT)
async function collectStates() {
  const firstIds = new Set();
  const all = [...Object.values(grid.cells), ...grid.session.map(s => s.ids), ...Object.values(grid.extras || {})];
  for (const ids of all) firstIds.add(ids[0]);
  const order = [...Object.values(grid.extras || {}).flat(), ...grid.session.flatMap(s => s.ids), ...Object.values(grid.cells).flat()];
  const done = new Set();
  let n = 0;
  for (const id of order) {
    if (done.has(id)) continue; done.add(id);
    if (++n % 80 === 0) await new Promise(r => setTimeout(r));
    for (const r of runs(grid.lines[id], firstIds.has(id))) if (r.sec) {
      const a = (states[r.sec] ||= []);
      if (a.length < 6 && !a.includes(r.html)) a.push(r.html);
    }
  }
}
function buildCards() {
  const C = CONTENT[lang], box = $("#cards");
  box.innerHTML = ORDER.filter(s => C.sectors[s]).map((s, i) => {
    const x = C.sectors[s];
    return `<article class="card" id="card-${s}" data-sec="${s}" style="--i:${i % 3}">
      <div class="card-h"><span class="num">${s === "node" ? "@" : String(s).padStart(2, "0")}</span><h3>${esc(x.name)}</h3></div>
      <div class="mini" aria-hidden="true"><span class="st">${(states[s] || [""])[0]}</span></div>
      <details open><summary>${L().kid}</summary><p>${fill(x.kid)}</p></details>
      <details><summary>${L().measures}</summary><p>${fill(x.measures)}</p></details>
      <details><summary>${L().whyLabel}</summary><p>${fill(x.why)}</p></details>
      <button class="show" type="button" data-show="${s}">${L().show}</button></article>`;
  }).join("");
  $("#glossary").innerHTML = `<h3>${L().glossary}</h3><dl>${C.glossary.map(([k, v]) => `<div><dt>${esc(k)}</dt><dd>${fill(v)}</dd></div>`).join("")}</dl>`;
  if (picked) $(`.card[data-sec="${picked}"]`)?.classList.add("sel");
  minisObs();
}
// mini-bars cycle through their sector's real states, only while on screen
let tick = 0, visible = new Set(), io2 = null;
function minisObs() {
  io2?.disconnect(); visible = new Set();
  io2 = new IntersectionObserver(es => es.forEach(e => e.isIntersecting ? visible.add(e.target) : visible.delete(e.target)));
  $$(".card .mini").forEach(m => io2.observe(m));
}
setInterval(() => {
  if (!grid || document.hidden) return; tick++;
  for (const m of visible) {
    const s = m.closest(".card").dataset.sec, a = states[s];
    if (!a || a.length < 2) continue;
    m.innerHTML = `<span class="st in">${a[tick % a.length]}</span>`;
  }
}, 2000);
$("#cards").addEventListener("click", e => {
  const b = e.target.closest("[data-show]"); if (!b) return;
  const s = b.dataset.show;
  $("#screen").scrollIntoView({ behavior: reduced ? "auto" : "smooth", block: "center" });
  setTimeout(() => showSector(s), reduced ? 0 : 450);
});
function showSector(s) {
  if (shown && s !== "16") { shown = null; transition(linesOf(idsNow()), null); }  // leave the no-thresholds render
  let el = bar.querySelector(`[data-sec="${s}"]`);
  let note = "";
  if (!el) {
    if (s === "16" && grid.extras?.noth) { shown = grid.extras.noth; note = L().only16; }
    else {
      // the real cell closest to the current controls (fewest controls changed) that shows it
      const dist = k => k.split(".").reduce((n, v, i) => n + (+v !== state[i]), 0);
      const key = Object.keys(grid.cells).filter(k => grid.cells[k].some(id => runs(grid.lines[id], id === grid.cells[k][0]).some(r => r.sec === s)))
        .sort((a, b) => dist(a) - dist(b))[0];
      if (!key) return;
      if (mode !== "explore") setMode("explore", false);
      key.split(".").forEach((v, i) => { state[i] = +v; }); shown = null; buildControls(); note = L().absent;
    }
    transition(linesOf(idsNow()), null);
    el = bar.querySelector(`[data-sec="${s}"]`);
  }
  if (!el) return;
  el.classList.remove("halo"); void el.offsetWidth; el.classList.add("halo");
  pick(s, el);
  if (note) cap.insertAdjacentHTML("beforeend", `<span class="msg in label" style="margin-top:6px">${note}</span>`);
}

// ---------------------------------------------------------------- the tree
function buildTree() {
  const t = L().tree;
  $("#tree").innerHTML = `<li style="--i:0"><span class="path"><span class="d">~/.claude/</span></span><span class="what"></span></li>` +
    t.map(([p, d, what, href], i) => {
      const dir = /\/$|\/\s/.test(p) || p.endsWith(")");
      const name = `${"  ".repeat(d + 1)}${dir ? `<span class="d">${esc(p)}</span>` : esc(p)}`;
      return `<li style="--i:${i + 1}"><span class="path">${name}</span><span class="what">${what ? (href ? `<a href="${GH}${href}">${esc(what)}</a>` : esc(what)) : ""}</span></li>`;
    }).join("");
}
$("#copy").addEventListener("click", async () => {
  const txt = $("#cmd span").textContent;
  try { await navigator.clipboard.writeText(txt); $("#copy").textContent = L().copied; setTimeout(() => { $("#copy").textContent = L().copy; }, 1600); }
  catch (e) { const r = document.createRange(); r.selectNodeContents($("#cmd span")); getSelection().removeAllRanges(); getSelection().addRange(r); }
});

// ---------------------------------------------------------------- language, theme, reveal
function renders() { return grid ? Object.keys(grid.cells).length + grid.session.length + Object.keys(grid.extras || {}).length : 1306; }
function applyLang() {
  const X = L(); document.documentElement.lang = lang;
  $$("[data-i18n]").forEach(e => { const v = X[e.dataset.i18n]; if (typeof v === "string") e.textContent = v; });
  $$("[data-i18n-html]").forEach(e => { e.innerHTML = X[e.dataset.i18nHtml]; });
  $$(".nrend").forEach((e, i) => { const t = String(renders()).replace(/\B(?=(\d{3})+$)/g, i === 0 ? " " : ","); if (e.textContent !== t) e.textContent = t; });
  $("#tline").setAttribute("aria-label", X.tline);
  $("#lang").textContent = lang === "es" ? "EN" : "ES";
  $("#lang").setAttribute("aria-label", lang === "es" ? "English" : "Español");
  $("#theme").setAttribute("aria-label", X.theme);
  bar.setAttribute("aria-label", X.barLabel);
  $("#lesson").href = GH + X.lesson; $$(".links a")[2].href = X.card;
  document.title = lang === "es" ? "La barra de claude-kit" : "The claude-kit status line";
  buildControls(); buildTree();
  $("#tticks").innerHTML = grid ? grid.session.map(s => `<span>${fmt(s.t)}</span>`).join("") : "";
  if (grid) {
    const m = X.meta(new Date(grid.renderedAt * 1000).toISOString().slice(0, 10), grid.inputsHash.slice(0, 12), renders());
    $("#meta").textContent = m; $("#meta2").textContent = m;
    buildCards();
    if (mode === "session") sayStep(); else if (picked) pick(picked, bar.querySelector(`[data-sec="${picked}"]`)); else say(esc(X.captionIdle));
  }
  stopPlay();
}
$("#lang").addEventListener("click", () => { lang = lang === "es" ? "en" : "es"; try { localStorage.setItem("kitdemo-lang", lang); } catch (e) {} applyLang(); });
$("#theme").addEventListener("click", () => {
  const r = document.documentElement, dark = r.dataset.theme ? r.dataset.theme === "dark" : !matchMedia("(prefers-color-scheme: light)").matches;
  const go = () => { r.dataset.theme = dark ? "light" : "dark"; try { localStorage.setItem("kitdemo-theme", r.dataset.theme); } catch (e) {} };
  if (document.startViewTransition && !reduced) { r.classList.add("vt-swap"); document.startViewTransition(go).finished.finally(() => r.classList.remove("vt-swap")); } else go();
});
const io = new IntersectionObserver(es => es.forEach(e => { if (e.isIntersecting) { e.target.classList.add("is-in"); io.unobserve(e.target); } }), { rootMargin: "0px 0px -10% 0px" });
$$(".reveal,.reveal-stagger,.tree").forEach(el => io.observe(el));
addEventListener("resize", () => { svg.innerHTML = ""; });

// ---------------------------------------------------------------- boot: inline cell first, grid.json after
if (initial.lines) paint(initial.lines);
applyLang();
fetch("grid.json", { cache: "no-cache" }).then(r => r.json()).then(g => {
  grid = g;
  if (!initial.lines || initial.key !== state.join(".")) paint(linesOf(idsNow()));
  applyLang(); makeTour();
  collectStates().then(() => $$(".card").forEach(c => { $(".mini .st", c).innerHTML = (states[c.dataset.sec] || [""])[0]; }));
  // the tutorial scrolls smoothly to its target and repositions on every scroll frame: on a first
  // visit nobody has touched the page yet, so each frame would count as a layout shift. Put the
  // target in place first (instant), then open.
  if (!hasSeen("claude-kit-demo-v2")) setTimeout(() => { $("#screen").scrollIntoView({ block: "center", behavior: "instant" }); requestAnimationFrame(() => tour.open()); }, 900);
}).catch(() => { $(".ln", bar).innerHTML = `<span class="c31">${esc(L().load)}</span>`; });
