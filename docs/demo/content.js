// docs/demo/content.js — explanatory copy for the demo. Thresholds are placeholders filled from grid.json.
// {th:<id>} = value of that threshold in rules/thresholds.json; {param:unpushed} = its grace in seconds.
export const CONTENT = {
  es: {
    sectors: {
      "1": {
        name: "Modelo",
        kid: `Es el nombre del ayudante con el que estás hablando, como la etiqueta de un uniforme.`,
        measures: `Lee <code>.model.display_name</code> del JSON que Claude Code manda a la barra. Si el campo falta o no se puede leer, imprime <code>⚠ modelo</code> en ámbar, nunca un nombre inventado.`,
        why: `Cada modelo cuesta y rinde distinto, y cambiarlo a mitad de sesión invalida la caché. Verlo siempre a la vista evita que ese cambio pase sin que lo notes.`
      },
      "2": {
        name: "Esfuerzo",
        kid: `Es cuánto se concentra el ayudante antes de contestar: poco para algo fácil, mucho para algo difícil.`,
        measures: `Lee <code>.effort.level</code> y lo imprime como <code>·high</code>, <code>·medium</code>, etc., pegado al modelo. Si el campo es null o no existe, el sector se omite; aquí la ausencia es un estado normal, no un error.`,
        why: `Cambiar el esfuerzo a mitad de sesión también rompe la caché (el JSON lo reporta como <code>effort_changed</code>). Por eso queda junto al modelo y no tiene umbral propio.`
      },
      "3": {
        name: "Barra de contexto",
        kid: `Es el vaso donde cabe todo lo que Claude recuerda de la conversación: mientras más se llena, peor trabaja.`,
        measures: `20 caracteres: <code>▓</code> es lo usado y <code>░</code> lo libre. La suma sale de <code>.context_window.current_usage</code> (input + cache_creation_input + cache_read_input); si no está, usa <code>used_percentage × context_window_size</code>. La barra va de 0 hasta donde dispara el auto-compact, y <code>┋</code> marca dónde empieza la banda roja ({th:context-red}k). Verde por debajo de {th:context-amber}k, ámbar desde {th:context-amber}k, rojo desde {th:context-red}k.`,
        why: `Los umbrales son tokens absolutos y no porcentajes: la calidad cae a un tamaño absoluto, y {th:context-red}k es mucho contexto lo mismo en una ventana de 200k que en una de 1M. Por eso es un medidor de riesgo y no de gasolina: termina donde conviene cortar, y el <code>┋</code> deja ver a la vez ese límite y el del auto-compact. Los colores solo se pintan si <code>thresholds.json</code> se pudo leer.`
      },
      "4": {
        name: "Tokens usados / techo",
        kid: `Es la cuenta exacta de cuánto del vaso llevas lleno y hasta dónde llega el vaso.`,
        measures: `<code>180k/400k</code>: tokens usados (los mismos de #3) sobre el techo del auto-compact. El techo sale de <code>CLAUDE_CODE_AUTO_COMPACT_WINDOW</code> (acepta <code>400000</code>, <code>400k</code> o <code>1M</code>); si no existe, es cerca del 97 % de <code>.context_window.context_window_size</code>. Aparece un <code>⚠</code> detrás cuando los tokens llegan a {th:context-red}k.`,
        why: `El número exacto responde lo que la barra dibujada no puede: cuánto falta de verdad. El <code>⚠</code> repite en texto lo que el color rojo dice, para que se lea también sin color. Si los tokens o la ventana no se pueden leer por separado, sale <code>⚠ contexto</code> en vez de un cero.`
      },
      "5": {
        name: "Porcentaje de la ventana",
        kid: `Es el mismo vaso, pero medido contra el vaso más grande que tu plan permitiría llenar.`,
        measures: `<code>18% of 1M</code>: tokens usados como porcentaje de la ventana completa, y el tamaño de esa ventana (<code>k</code> o <code>M</code>), tomado de <code>.context_window.context_window_size</code>.`,
        why: `Está solo como referencia y no tiene umbral. Decidir por porcentaje engaña: 60 % de una ventana de 1M son 600k, el doble de la banda roja. La decisión la toman #3 y #4, que miden en tokens.`
      },
      "6": {
        name: "Costo",
        kid: `Es el contador del taxi: muestra cuánto va gastando esta conversación.`,
        measures: `Imprime <code>.cost.total_cost_usd</code> tal cual con dos decimales, por ejemplo <code>$3.80</code>. Es la cifra que Claude Code calcula para la sesión, no una factura. Si el campo falta sale <code>$⚠</code>; un <code>$0.00</code> real se imprime como <code>$0.00</code>.`,
        why: `Sirve para comparar sesiones y notar cuándo una acción cuesta más de lo esperado, sobre todo una caché fría (#10). No tiene umbral: es información, no una orden.`
      },
      "7": {
        name: "Tiempo de sesión",
        kid: `Es el reloj que cuenta cuánto rato llevas trabajando con Claude en esta conversación.`,
        measures: `<code>.cost.total_duration_ms</code> dividido entre 60 000, en minutos: <code>45m</code>. Si el campo falta, sale <code>⚠m</code>.`,
        why: `Una sesión larga acumula cambios y contexto. Desde {th:session-long} minutos, y solo si el contexto también está en ámbar (#3), la pista (#18) propone guardar el estado antes de limpiar.`
      },
      "8": {
        name: "Cuota de 5 horas",
        kid: `Es cuánta de tu ración de cinco horas ya te comiste.`,
        measures: `<code>5h 41%</code>: porcentaje usado de la ventana de 5 horas del plan, de <code>.rate_limits.five_hour.used_percentage</code>. Queda en blanco, sin <code>⚠</code>, cuando <code>.rate_limits</code> es null: eso es "todavía no se mide", un estado real. Si el objeto existe pero falta <code>five_hour</code>, sí sale <code>5h ⚠</code>.`,
        why: `Es la señal de mayor prioridad: con la cuota al {th:quota-5h}% o más, la pista (#18) pasa por delante de todas las demás y propone parar o bajar a sonnet. No colorea nada por sí misma; solo manda sobre la pista.`
      },
      "9": {
        name: "Cuota de 7 días",
        kid: `Es lo mismo que la ración de cinco horas, pero para toda la semana.`,
        measures: `<code>7d 87%</code>: porcentaje usado de la ventana semanal, de <code>.rate_limits.seven_day.used_percentage</code>. Misma regla que #8: en blanco si <code>.rate_limits</code> es null, <code>⚠</code> si el dato falta dentro de un objeto que existe.`,
        why: `Da el cuadro grande: puedes estar bien en 5 horas y aun así gastar la semana demasiado rápido. El kit no define umbral para esta cuota en <code>thresholds.json</code>, así que no pinta ni sugiere nada.`
      },
      "10": {
        name: "Estado de la caché",
        kid: `Es una nevera donde se guarda lo que ya le contaste a Claude: mientras está encendida sale barato, si se apaga hay que volver a cocinar todo.`,
        measures: `Va en la línea 1, después del tiempo. Lee <code>.prompt_cache.warm</code> y <code>.prompt_cache.expires_at</code>. <code>⚡ caliente · 42m</code> (verde): caché viva, faltan 42 minutos para <code>expires_at</code>. <code>⚡ enfriando · 4m</code> (ámbar): caliente pero con {th:cache-cooling} minutos o menos. <code>❄ fría · próximo turno reescribe</code> (cian): expiró o <code>warm</code> es false. <code>⚠ caché</code>: el objeto tiene una forma desconocida. En blanco si <code>.prompt_cache</code> es null (antes de la primera llamada).`,
        why: `Una palabra y un número, en un solo lugar. Importa por plata: con la caché fría, el siguiente turno vuelve a escribir todo el contexto en la caché y eso se cobra de nuevo. Cuando quedan {th:cache-cooling} minutos o menos, la pista (#18) propone un turno corto para recalentar. Las palabras vienen de <code>labels</code> en <code>thresholds.json</code>; sin ese bloque solo se imprimen <code>⚡</code>/<code>❄</code> y el número.`
      },
      "11": {
        name: "Acierto de caché (hit)",
        kid: `Es cuántas veces Claude encontró lo que buscaba en la nevera en vez de cocinarlo otra vez.`,
        measures: `<code>hit 79%</code>, en la línea 2: <code>.prompt_cache.hit_ratio</code> por 100, redondeado hacia abajo. Aparece solo por debajo de {th:cache-hit-ok}%. Ámbar por debajo de ese valor y rojo por debajo de {th:cache-cold}%. Si no se puede leer, sale <code>hit ⚠</code>.`,
        why: `Un acierto alto no informa: el estado de #10 ya lo dice todo. Por eso se oculta desde {th:cache-hit-ok}% y solo aparece cuando algo anda mal. Por debajo de {th:cache-cold}% además manda la pista, que nombra la causa que trae el JSON (por ejemplo <code>model_changed</code>) y pide no cambiar modelo ni esfuerzo. Si <code>thresholds.json</code> no se pudo leer, se muestra siempre y sin color.`
      },
      "12": {
        name: "Fallos de caché (miss)",
        kid: `Son las veces que fuiste a la nevera y estaba vacía.`,
        measures: `<code>(4 miss)</code>: cuenta de <code>.prompt_cache.misses</code>. Se imprime junto a #11, solo cuando #11 se muestra y la cuenta es mayor que cero. Si no se puede leer, <code>(⚠ miss)</code>, siempre.`,
        why: `El porcentaje dice cuánto falló; la cuenta dice cuántas veces. Un 79 % con 4 fallos tras un cambio de modelo cuenta una historia distinta que el mismo 79 % repartido en muchos turnos.`
      },
      "13": {
        name: "Líneas cambiadas",
        kid: `Es cuántas líneas escribiste nuevas y cuántas borraste desde que abriste la conversación.`,
        measures: `<code>+213/-15</code>: líneas añadidas y quitadas en la sesión, de <code>.cost.total_lines_added</code> y <code>.cost.total_lines_removed</code>. Solo se muestra si alguna de las dos es mayor que cero. Si no se pueden leer, <code>⚠ diff</code>.`,
        why: `Es una medida de cuánto trabajo hay en juego si algo se pierde. Junto con #15 ayuda a decidir si vale la pena guardar un HANDOFF ahora. No tiene umbral.`
      },
      "14": {
        name: "Git",
        kid: `↑1 es una carta que escribiste y todavía no mandaste.`,
        measures: `Corre <code>git status --porcelain=v2 --branch</code> contra <code>.workspace.current_dir</code>. <code>⎇</code> es la rama; <code>↑N</code> son commits por delante de origin; <code>↓N</code>, por detrás; <code>●N</code>, archivos modificados con seguimiento; <code>?N</code>, archivos sin seguimiento; <code>⊘</code> reemplaza el par ↑↓ cuando la rama no tiene upstream. Ejemplo: <code>↑1 ↓0 ●2 ?1</code> = 1 commit por delante, ninguno por detrás, 2 archivos modificados y 1 sin seguimiento.`,
        why: `Un commit sin push solo existe en tu máquina. <code>↑N</code> se pone ámbar cuando el commit sin push más viejo lleva {param:unpushed} segundos (el plazo de gracia) o más, y mientras haya algo por empujar la pista (#18) propone <code>git push</code>. Tiene la prioridad más baja de las pistas: es la que cede ante todas las demás.`
      },
      "15": {
        name: "HANDOFF",
        kid: `Es la nota que le dejas a tu yo de mañana; la barra te avisa si ya quedó vieja.`,
        measures: `<code>✓HANDOFF</code> (verde): nada se movió desde que escribiste <code>HANDOFF.md</code>. <code>⚠HANDOFF 02:22 ·2f ·1c ·0s</code>: la hora en que se escribió (con <code>dd/mm</code> si es de otro día), archivos modificados más nuevos que él (<code>f</code>), commits desde entonces (<code>c</code>; un commit que solo toca <code>HANDOFF.md</code> no cuenta) y sesiones iniciadas desde entonces (<code>s</code>, del log de eventos). Un <code>?</code> en un contador significa "no se pudo calcular". <code>⚠ sin HANDOFF</code> (ámbar): el archivo no existe. Rojo cuando hay más de {th:handoff-drift-files} archivos o {th:handoff-drift-sessions} sesiones o más; ámbar en los demás casos.`,
        why: `Muestra una hora de reloj y no una edad ("hace 50 min") porque la barra solo se redibuja con eventos de la sesión: una edad se queda congelada, una hora no. Un contador que no se puede calcular muestra <code>?</code> y nunca baja a "sin HANDOFF", que significa que el archivo de verdad no está. Antes de limpiar el contexto, este sector dice si el estado está a salvo.`
      },
      "16": {
        name: "Umbrales ilegibles",
        kid: `Es la luz roja que dice: perdí la hoja con las reglas, así que no te voy a dar consejos.`,
        measures: `<code>⚠ umbrales</code> aparece solo cuando <code>rules/thresholds.json</code> falta, no se puede leer o no se pudo interpretar en este redibujado. Mientras dure, la barra no pinta bandas de color ni muestra pistas.`,
        why: `Es la regla central del kit: un umbral que no puedes leer no es lo mismo que un umbral que no se cruzó. La barra no se apoya en un valor recordado, porque ese valor podría estar desactualizado y daría una falsa calma. Es mejor un aviso claro que un consejo con un número viejo.`
      },
      "17": {
        name: "Nombre de sesión",
        kid: `Es el apodo que le pusiste a esta conversación para reconocerla entre otras.`,
        measures: `<code>[demo]</code>: el valor de <code>.session_name</code> entre corchetes. Si el campo no existe, el sector se omite.`,
        why: `Cuando tienes varias ventanas abiertas, el nombre te dice cuál es cuál sin abrir la leyenda. No tiene umbral ni cambia ninguna pista.`
      },
      "18": {
        name: "La pista",
        kid: `Es el único consejo que te susurra la barra: el más urgente, nunca una lista.`,
        measures: `Texto magenta al final de la línea 2, con la forma <code>→ acción</code> o <code>↑1 sin push → git push</code>. Es UNA sola frase: la del umbral de menor número de prioridad que se cumple ahora. El orden es: cuota 5h ({th:quota-5h}%) → contexto rojo ({th:context-red}k) → caché enfriando ({th:cache-cooling} min) → hit bajo (menos de {th:cache-cold}%) → sesión larga ({th:session-long} min, solo con contexto en ámbar) → commits sin push. El texto sale de <code>actions</code> en <code>thresholds.json</code>; la variante "fresh" se usa cuando el HANDOFF está al día.`,
        why: `Una barra con dos consejos ya no se lee de un vistazo, así que gana siempre la prioridad más alta. El orden no está en el script sino en <code>priority</code> dentro de <code>thresholds.json</code>. El color es siempre magenta, el mismo para cualquier pista.`
      },
      "node": {
        name: "Máquina",
        kid: `Es la etiqueta que dice en qué computadora está corriendo esta conversación.`,
        measures: `<code>@mac</code>, <code>@win</code> o <code>@linux</code>, leído de <code>$OSTYPE</code>. La variable de entorno <code>CC_NODE</code> lo reemplaza con un nombre propio. No tiene número en la leyenda.`,
        why: `Por Remote-SSH todas las ventanas se ven iguales, y con dos máquinas trabajando en paralelo conviene saber en cuál estás antes de correr un comando. Va pegado al modelo porque es lo primero que se mira.`
      }
    },
    glossary: [
      ["▓", "parte usada de la barra de contexto (20 caracteres en total)"],
      ["░", "parte libre de la barra de contexto"],
      ["┋", "dónde empieza la banda roja ({th:context-red}k) dentro del tramo hasta el auto-compact"],
      ["⚠", "dato faltante o ilegible, en ámbar; nunca se pinta como 0. Detrás de los tokens (#4) significa contexto en banda roja"],
      ["⚡", "caché viva: caliente o enfriando, con los minutos que le quedan"],
      ["❄", "caché fría: el próximo turno paga reescribir el contexto"],
      ["⎇", "rama de git"],
      ["↑", "commits por delante de origin, aún sin push"],
      ["↓", "commits por detrás de origin, aún sin traer"],
      ["●", "archivos modificados con seguimiento"],
      ["?", "en git, archivos sin seguimiento; en HANDOFF, un contador que no se pudo calcular"],
      ["⊘", "la rama no tiene upstream, así que no hay ↑↓ que mostrar"],
      ["✓", "HANDOFF al día: nada se movió desde que se escribió"],
      ["·", "separador entre sectores; pegado a un nivel (·high) es el esfuerzo, y delante de f, c, s son los contadores del HANDOFF"],
      ["@", "máquina donde corre la sesión (@mac, @win, @linux)"],
      ["$", "costo estimado de la sesión según Claude Code, no una factura"],
      ["[ ]", "nombre de la sesión, entre corchetes"],
      ["→", "empieza la pista: la acción que la barra te propone ahora"],
      ["verde", "estado sano: dentro de lo normal"],
      ["ámbar", "atención: banda intermedia, caché enfriando, dato faltante (⚠) o HANDOFF desactualizado"],
      ["rojo", "acción pendiente: contexto desde {th:context-red}k, hit bajo {th:cache-cold}%, deriva grande del HANDOFF"],
      ["cian", "caché fría; no es una alarma, es un hecho"],
      ["magenta", "siempre el color de la pista (#18)"]
    ],
    session: {
      "0": `Abres con 38k de contexto, la caché recién calentada (60 minutos por delante), cuota 5h en 6 %, repo limpio y <code>✓HANDOFF</code>. El costo va en $0.14: no hay pista porque nada cruza un umbral.`,
      "20": `Con 96k de contexto, editaste 2 archivos después de escribir el HANDOFF. El sector pasa a <code>⚠HANDOFF</code> con <code>·2f</code> y el diff muestra <code>+124/-9</code>: el estado guardado ya no refleja el trabajo.`,
      "45": `Con 152k cruzas {th:context-amber}k y la barra entra en banda ámbar. Hiciste un commit a los 40 minutos (<code>↑1</code>), todavía sin ámbar porque está dentro del plazo de gracia; quedó un archivo sin seguimiento (<code>?1</code>) y la pista dice <code>↑1 sin push → git push</code>.`,
      "70": `Te alejaste: la caché sigue caliente pero con 4 minutos, así que ves <code>⚡ enfriando · 4m</code> en ámbar. La pista cambia a recalentar, porque cache-cooling tiene más prioridad que unpushed.`,
      "90": `Seguiste fuera y la caché expiró: <code>❄ fría · próximo turno reescribe</code>. Tu siguiente mensaje tiene que reescribir unos 161k tokens de contexto, y eso se cobra de nuevo.`,
      "100": `Volviste y ese turno reescribió la caché, que vuelve a estar caliente. El acierto cayó a 79 % con 4 fallos por <code>model_changed</code>: como está por debajo de {th:cache-hit-ok}%, ahora <code>hit 79% (4 miss)</code> aparece en la línea 2. El contexto va en 214k.`,
      "130": `Con 281k, hiciste un segundo commit (<code>↑2</code>) y la cuota 5h llegó a 55 %. Sigues en ámbar, a un paso de la banda roja de {th:context-red}k.`,
      "160": `Con 322k cruzas {th:context-red}k: la barra se pone roja, aparece <code>⚠</code> detrás de los tokens y la pista dice <code>→ /handoff PRIMERO, luego /clear</code>. Contexto rojo le gana a commits sin push, y tienes 2 archivos modificados sin guardar.`,
      "175": `Corriste <code>/handoff</code>, hiciste commit de <code>HANDOFF.md</code> y push: vuelve <code>✓HANDOFF</code> y <code>↑0</code>. La pista de contexto rojo cambia a su versión "fresh", <code>estado guardado → /clear seguro</code>.`
    }
  },
  en: {
    sectors: {
      "1": {
        name: "Model",
        kid: `It is the name of the helper you are talking to, like the name tag on a uniform.`,
        measures: `Reads <code>.model.display_name</code> from the JSON Claude Code pipes to the bar. If the field is missing or unreadable it prints <code>⚠ modelo</code> in amber, never an invented name.`,
        why: `Each model costs and performs differently, and switching it mid-session invalidates the cache. Keeping it in view stops that change from slipping by unnoticed.`
      },
      "2": {
        name: "Effort",
        kid: `It is how hard the helper thinks before answering: a little for an easy question, a lot for a hard one.`,
        measures: `Reads <code>.effort.level</code> and prints it as <code>·high</code>, <code>·medium</code>, and so on, next to the model. If the field is null or absent the sector is left out; here absence is a normal state, not an error.`,
        why: `Changing effort mid-session also breaks the cache (the JSON reports it as <code>effort_changed</code>). That is why it sits beside the model and has no threshold of its own.`
      },
      "3": {
        name: "Context bar",
        kid: `It is the glass that holds everything Claude remembers from the conversation: the fuller it gets, the worse Claude works.`,
        measures: `20 characters: <code>▓</code> is used, <code>░</code> is free. The total comes from <code>.context_window.current_usage</code> (input + cache_creation_input + cache_read_input); if that is absent it falls back to <code>used_percentage × context_window_size</code>. The bar runs from 0 to the point where auto-compact fires, and <code>┋</code> marks where the red band starts ({th:context-red}k). Green below {th:context-amber}k, amber from {th:context-amber}k, red from {th:context-red}k.`,
        why: `Thresholds are absolute tokens, not percentages: quality degrades at an absolute size, and {th:context-red}k is a lot of context whether the window is 200k or 1M. So it is a risk gauge, not a fuel gauge: it ends where you should cut, and the <code>┋</code> shows that limit and the auto-compact limit together. Colours are only painted if <code>thresholds.json</code> could be read.`
      },
      "4": {
        name: "Tokens used / ceiling",
        kid: `It is the exact count of how full the glass is and how big the glass is.`,
        measures: `<code>180k/400k</code>: tokens used (same as #3) over the auto-compact ceiling. The ceiling comes from <code>CLAUDE_CODE_AUTO_COMPACT_WINDOW</code> (accepts <code>400000</code>, <code>400k</code> or <code>1M</code>); without it, about 97% of <code>.context_window.context_window_size</code>. A trailing <code>⚠</code> appears when tokens reach {th:context-red}k.`,
        why: `The exact number answers what the drawn bar cannot: how much room is really left. The <code>⚠</code> repeats the red colour in text, so it reads without colour too. If tokens or window size cannot be read individually you get <code>⚠ contexto</code> instead of a zero.`
      },
      "5": {
        name: "Window percentage",
        kid: `It is the same glass measured against the biggest glass your plan could ever fill.`,
        measures: `<code>18% of 1M</code>: tokens used as a percentage of the full window, plus the window size (<code>k</code> or <code>M</code>), taken from <code>.context_window.context_window_size</code>.`,
        why: `It is there for reference only and has no threshold. Deciding by percentage misleads: 60% of a 1M window is 600k, twice the red band. The decision belongs to #3 and #4, which measure in tokens.`
      },
      "6": {
        name: "Cost",
        kid: `It is the taxi meter: it shows how much this conversation has spent so far.`,
        measures: `Prints <code>.cost.total_cost_usd</code> verbatim with two decimals, for example <code>$3.80</code>. It is the figure Claude Code computes for the session, not a bill. If the field is missing it prints <code>$⚠</code>; a real <code>$0.00</code> prints as <code>$0.00</code>.`,
        why: `It lets you compare sessions and notice when an action costs more than expected, above all a cold cache (#10). It has no threshold: it is information, not an order.`
      },
      "7": {
        name: "Session time",
        kid: `It is the clock that counts how long you have been working with Claude in this conversation.`,
        measures: `<code>.cost.total_duration_ms</code> divided by 60,000, in minutes: <code>45m</code>. If the field is missing it prints <code>⚠m</code>.`,
        why: `A long session piles up changes and context. From {th:session-long} minutes, and only if the context is also amber (#3), the hint (#18) suggests saving state before clearing.`
      },
      "8": {
        name: "5-hour quota",
        kid: `It is how much of your five-hour ration you have already eaten.`,
        measures: `<code>5h 41%</code>: percentage used of the plan's 5-hour window, from <code>.rate_limits.five_hour.used_percentage</code>. It stays blank, without <code>⚠</code>, when <code>.rate_limits</code> is null: that means "not tracked yet", a real state. If the object exists but <code>five_hour</code> is missing, you do get <code>5h ⚠</code>.`,
        why: `It is the highest-priority signal: with the quota at {th:quota-5h}% or more, the hint (#18) jumps ahead of every other and suggests stopping or dropping to sonnet. It paints nothing on its own; it only takes over the hint.`
      },
      "9": {
        name: "7-day quota",
        kid: `It is the same ration as the five-hour one, but for the whole week.`,
        measures: `<code>7d 87%</code>: percentage used of the weekly window, from <code>.rate_limits.seven_day.used_percentage</code>. Same rule as #8: blank if <code>.rate_limits</code> is null, <code>⚠</code> if the value is missing inside an object that exists.`,
        why: `It gives the big picture: you can be fine over 5 hours and still burn the week too fast. The kit defines no threshold for this quota in <code>thresholds.json</code>, so it neither colours nor hints.`
      },
      "10": {
        name: "Cache state",
        kid: `It is a fridge holding what you already told Claude: while it is on, meals are cheap; if it switches off, everything has to be cooked again.`,
        measures: `On line 1, after the time. Reads <code>.prompt_cache.warm</code> and <code>.prompt_cache.expires_at</code>. <code>⚡ caliente · 42m</code> (warm, green): cache alive, 42 minutes until <code>expires_at</code>. <code>⚡ enfriando · 4m</code> (cooling, amber): warm but with {th:cache-cooling} minutes or fewer left. <code>❄ fría · próximo turno reescribe</code> (cold, the next turn rewrites; cyan): expired or <code>warm</code> is false. <code>⚠ caché</code>: the object has an unknown shape. Blank when <code>.prompt_cache</code> is null (before the first call).`,
        why: `One word and one number, in one place. It matters for money: with a cold cache, the next turn writes the whole context to the cache again, and that is billed again. When {th:cache-cooling} minutes or fewer remain, the hint (#18) suggests a short turn to re-warm. The words come from <code>labels</code> in <code>thresholds.json</code>; without that block only <code>⚡</code>/<code>❄</code> and the number print.`
      },
      "11": {
        name: "Cache hit ratio",
        kid: `It is how often Claude found what it needed in the fridge instead of cooking it again.`,
        measures: `<code>hit 79%</code>, on line 2: <code>.prompt_cache.hit_ratio</code> times 100, rounded down. It appears only below {th:cache-hit-ok}%. Amber below that, red below {th:cache-cold}%. If unreadable it prints <code>hit ⚠</code>.`,
        why: `A high ratio tells you nothing: the state in #10 already says it all. So it hides from {th:cache-hit-ok}% up and shows only when something is wrong. Below {th:cache-cold}% it also drives the hint, which names the cause the JSON carries (for example <code>model_changed</code>) and asks you not to change model or effort. If <code>thresholds.json</code> could not be read, it is always shown and uncoloured.`
      },
      "12": {
        name: "Cache misses",
        kid: `They are the times you went to the fridge and it was empty.`,
        measures: `<code>(4 miss)</code>: the count in <code>.prompt_cache.misses</code>. Printed next to #11, only when #11 is shown and the count is above zero. If unreadable, <code>(⚠ miss)</code>, always.`,
        why: `The percentage says how much failed; the count says how many times. 79% with 4 misses after a model change tells a different story than the same 79% spread over many turns.`
      },
      "13": {
        name: "Changed lines",
        kid: `It is how many new lines you wrote and how many you erased since you opened the conversation.`,
        measures: `<code>+213/-15</code>: lines added and removed this session, from <code>.cost.total_lines_added</code> and <code>.cost.total_lines_removed</code>. Shown only when either is above zero. If unreadable, <code>⚠ diff</code>.`,
        why: `It gauges how much work is at stake if something is lost. Together with #15 it helps you decide whether a HANDOFF is worth saving now. It has no threshold.`
      },
      "14": {
        name: "Git",
        kid: `↑1 is a letter you wrote and have not mailed yet.`,
        measures: `Runs <code>git status --porcelain=v2 --branch</code> against <code>.workspace.current_dir</code>. <code>⎇</code> is the branch; <code>↑N</code> is commits ahead of origin; <code>↓N</code>, behind; <code>●N</code>, modified tracked files; <code>?N</code>, untracked files; <code>⊘</code> replaces the ↑↓ pair when the branch has no upstream. Example: <code>↑1 ↓0 ●2 ?1</code> = 1 commit ahead, none behind, 2 modified files and 1 untracked.`,
        why: `A commit without a push exists only on your machine. <code>↑N</code> turns amber once the oldest unpushed commit is {param:unpushed} seconds old or more (the grace period), and while anything is waiting to be pushed the hint (#18) suggests <code>git push</code>. It has the lowest priority of the hints: it yields to all the others.`
      },
      "15": {
        name: "HANDOFF",
        kid: `It is the note you leave for tomorrow's you; the bar tells you when the note has gone stale.`,
        measures: `<code>✓HANDOFF</code> (green): nothing moved since you wrote <code>HANDOFF.md</code>. <code>⚠HANDOFF 02:22 ·2f ·1c ·0s</code>: the clock time it was written (with <code>dd/mm</code> if from another day), modified files newer than it (<code>f</code>), commits since (<code>c</code>; a commit that only touches <code>HANDOFF.md</code> does not count) and sessions started since (<code>s</code>, from the event log). A <code>?</code> in a counter means "could not be computed". <code>⚠ sin HANDOFF</code> (amber): the file does not exist. Red above {th:handoff-drift-files} files or at {th:handoff-drift-sessions} sessions or more; amber otherwise.`,
        why: `It shows a clock time rather than an age ("50 min ago") because the bar only redraws on session events: an age freezes, a clock time does not. A counter that cannot be computed shows <code>?</code> and never falls back to "sin HANDOFF", which means the file really is absent. Before clearing context, this sector tells you whether your state is safe.`
      },
      "16": {
        name: "Unreadable thresholds",
        kid: `It is the warning light that says: I lost the sheet with the rules, so I will not give you advice.`,
        measures: `<code>⚠ umbrales</code> (thresholds) appears only when <code>rules/thresholds.json</code> is missing, unreadable or failed to parse on this render. While it lasts, the bar paints no colour bands and shows no hints.`,
        why: `It is the kit's core rule: a threshold you cannot read is not the same as a threshold that was not crossed. The bar never leans on a remembered value, because it could be out of date and give false calm. A clear warning beats advice built on an old number.`
      },
      "17": {
        name: "Session name",
        kid: `It is the nickname you gave this conversation so you can tell it apart from the others.`,
        measures: `<code>[demo]</code>: the value of <code>.session_name</code> in brackets. If the field does not exist the sector is left out.`,
        why: `With several windows open, the name tells you which is which without opening the legend. It has no threshold and changes no hint.`
      },
      "18": {
        name: "The hint",
        kid: `It is the one piece of advice the bar whispers: the most urgent one, never a list.`,
        measures: `Magenta text at the end of line 2, shaped like <code>→ action</code> or <code>↑1 sin push → git push</code> (unpushed). It is ONE sentence: the one from the threshold with the lowest priority number that holds right now. The order is: 5h quota ({th:quota-5h}%) → red context ({th:context-red}k) → cache cooling ({th:cache-cooling} min) → low hit (below {th:cache-cold}%) → long session ({th:session-long} min, only with context in amber) → unpushed commits. The text comes from <code>actions</code> in <code>thresholds.json</code>; the "fresh" variant is used when the HANDOFF is up to date.`,
        why: `A bar with two pieces of advice can no longer be read at a glance, so the highest priority always wins. The order lives not in the script but in <code>priority</code> inside <code>thresholds.json</code>. The colour is always magenta, whichever hint wins.`
      },
      "node": {
        name: "Machine",
        kid: `It is the label that says which computer this conversation is running on.`,
        measures: `<code>@mac</code>, <code>@win</code> or <code>@linux</code>, read from <code>$OSTYPE</code>. The <code>CC_NODE</code> environment variable replaces it with a name of your own. It has no number in the legend.`,
        why: `Over Remote-SSH every window looks the same, and with two machines working in parallel you want to know which one you are on before you run a command. It sits next to the model because that is the first thing you look at.`
      }
    },
    glossary: [
      ["▓", "used part of the context bar (20 characters in total)"],
      ["░", "free part of the context bar"],
      ["┋", "where the red band starts ({th:context-red}k) inside the span up to auto-compact"],
      ["⚠", "missing or unreadable data, in amber; it is never painted as 0. After the tokens (#4) it means context in the red band"],
      ["⚡", "cache alive: caliente (warm) or enfriando (cooling), with the minutes left"],
      ["❄", "fría (cold) cache: the next turn pays to rewrite the context"],
      ["⎇", "git branch"],
      ["↑", "commits ahead of origin, not pushed yet"],
      ["↓", "commits behind origin, not pulled yet"],
      ["●", "modified tracked files"],
      ["?", "in git, untracked files; in HANDOFF, a counter that could not be computed"],
      ["⊘", "the branch has no upstream, so there is no ↑↓ to show"],
      ["✓", "HANDOFF up to date: nothing moved since it was written"],
      ["·", "separator between sectors; stuck to a level (·high) it is the effort, and before f, c, s it is the HANDOFF counters"],
      ["@", "machine the session runs on (@mac, @win, @linux)"],
      ["$", "estimated session cost according to Claude Code, not a bill"],
      ["[ ]", "session name, in brackets"],
      ["→", "starts the hint: the action the bar suggests right now"],
      ["green", "healthy: inside the normal range"],
      ["amber", "attention: middle band, cache cooling, missing data (⚠) or a stale HANDOFF"],
      ["red", "action pending: context from {th:context-red}k, hit below {th:cache-cold}%, large HANDOFF drift"],
      ["cyan", "cold cache; not an alarm, a fact"],
      ["magenta", "always the colour of the hint (#18)"]
    ],
    session: {
      "0": `You open with 38k of context, the cache just warmed (60 minutes ahead), 5h quota at 6%, a clean repo and <code>✓HANDOFF</code>. Cost is $0.14. There is no hint because nothing crosses a threshold.`,
      "20": `At 96k of context you edited 2 files after writing the HANDOFF. The sector turns to <code>⚠HANDOFF</code> with <code>·2f</code> and the diff reads <code>+124/-9</code>: the saved state no longer matches the work.`,
      "45": `At 152k you cross {th:context-amber}k and the bar enters the amber band. You made a commit at minute 40 (<code>↑1</code>), not amber yet because it is inside the grace period; one untracked file remains (<code>?1</code>) and the hint reads <code>↑1 sin push → git push</code>.`,
      "70": `You step away: the cache is still warm but has 4 minutes left, so you see <code>⚡ enfriando · 4m</code> in amber. The hint changes to re-warming, because cache-cooling outranks unpushed.`,
      "90": `You stay away and the cache expires: <code>❄ fría · próximo turno reescribe</code>. Your next message has to rewrite about 161k tokens of context, and that is billed again.`,
      "100": `You are back and that turn rewrote the cache, which is warm again. The hit ratio fell to 79% with 4 misses from <code>model_changed</code>: since it is below {th:cache-hit-ok}%, <code>hit 79% (4 miss)</code> now appears on line 2. Context is at 214k.`,
      "130": `At 281k you made a second commit (<code>↑2</code>) and the 5h quota reached 55%. You are still amber, one step from the {th:context-red}k red band.`,
      "160": `At 322k you cross {th:context-red}k: the bar turns red, a <code>⚠</code> follows the tokens and the hint reads <code>→ /handoff PRIMERO, luego /clear</code>. Red context outranks unpushed commits, and you have 2 modified files unsaved.`,
      "175": `You ran <code>/handoff</code>, committed <code>HANDOFF.md</code> and pushed: <code>✓HANDOFF</code> and <code>↑0</code> are back. The red-context hint switches to its "fresh" wording, <code>estado guardado → /clear seguro</code>.`
    }
  }
};
