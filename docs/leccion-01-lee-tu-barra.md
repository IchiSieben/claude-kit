---
lesson:
  route: code-like-me
  order: 1
  level: 0
---

# 01 — Lee tu barra: qué te está diciendo Claude Code en cada turno

## Objetivo

Mirar las dos líneas de la barra de estado y saber, en un vistazo, cuatro cosas: cuánto
contexto te queda antes de que la sesión se degrade, si la caché sigue caliente, si tu trabajo
está a salvo (commit, push, HANDOFF) y qué deberías hacer ahora. Al final de la lección puedes
leer cualquier estado de la barra sin abrir la leyenda.

**Pruébala en vivo:** el [simulador de la barra](https://kit.ichisieben.dev/) mueve contexto, caché,
cuota, git, HANDOFF y modelo, y muestra la salida real de `statusline.sh` para cada combinación.
Toca un sector y abre su fila de la leyenda: es esta lección hecha interactiva.
**Quién lo hace:** tú. La barra la dibuja `home/.claude/statusline.sh` en cada turno; tú solo
la lees.

## Por qué: una barra que no miente

Claude Code le pasa a la barra un JSON en cada turno (modelo, tokens, costo, cuota, caché). Lo
fácil es pintar esos números tal cual. El problema es que un número que no llegó y un número
que vale cero se ven igual, y se actúa distinto sobre cada uno. Por eso la barra tiene una sola
regla de fondo:

> Un campo que falta o no se puede leer se pinta `⚠` en ámbar, nunca `0`.

La segunda regla es que **ningún umbral vive en el script**. Los 150k y 300k del contexto, el
90 % de la cuota, los 5 minutos de la caché: todo está en `rules/thresholds.json`. Si ese
archivo no se puede leer, la barra dice `⚠ umbrales` y deja de colorear. Un umbral que no puedes
leer no es lo mismo que un umbral que no se cruzó.

## Pasos

![Los 18 sectores de la barra, por grupos](img/statusline-sectores.svg)

Los números son los de la leyenda completa, [`statusline.es.md`](statusline.es.md). Aquí van
por grupos, en el orden en que conviene mirarlos.

## Paso 1 — Modelo y contexto (#1–#5, línea 1)

`Opus 5.5 ·high @mac ▓▓▓▓▓▓▓▓▓░░░░░░┋░░░░ 180k/400k · 18% of 1M`

- **#1 y #2**: modelo y nivel de esfuerzo. `@mac` dice en qué máquina corre la sesión; por
  Remote-SSH todas las ventanas se ven iguales.
- **#3, la barra**: va de 0 hasta donde dispara el auto-compact. El `┋` marca la banda roja
  (`context-red`, 300k): ahí deberías haber cortado. Es un medidor de riesgo, no de gasolina.
- **#4**: tokens usados / techo del auto-compact. Verde por debajo de 150k, ámbar entre 150k y
  300k, rojo desde 300k (con `⚠` detrás).
- **#5**: el porcentaje de la ventana real. Está para contexto, no para decidir: la calidad cae
  a un tamaño absoluto, y 60 % de 1M es el doble de la banda roja.

## Paso 2 — Costo y tiempo (#6–#7)

`$7.10 · 90m`. El costo es la cifra que Claude Code calcula para la sesión, no una factura. Los
minutos cuentan desde que abriste la sesión: a partir de 8 h, con el contexto en ámbar, la pista
te propone cortar.

## Paso 3 — Caché (#10–#12): una palabra y un número

La caché de prompt guarda tu contexto una hora. Mientras está caliente, cada turno lee lo
guardado a precio de lectura; cuando expira, el siguiente turno paga escribirlo todo de nuevo.
La barra lo dice en **un solo lugar** de la línea 1:

| Lo que ves | Qué significa |
|---|---|
| `⚡ caliente · 42m` (verde) | Faltan 42 minutos para que expire la última escritura (`expires_at`) |
| `⚡ enfriando · 4m` (ámbar) | Quedan 5 minutos o menos (`cache-cooling`). La pista dice qué hacer |
| `❄ fría · próximo turno reescribe` (cian) | Ya expiró: el próximo mensaje paga reescribir todo el contexto |

El acierto de caché (**#11**, `hit 79%`) pasa a la línea 2 y **solo aparece cuando informa**: por
debajo de 85 % (`cache-hit-ok`). En rojo bajo 60 % (`cache-cold`), y entonces la pista nombra la
causa que trae el JSON (`model_changed`, `effort_changed`…). **#12** son los fallos de caché.

## Paso 4 — Cuota del plan (#8–#9, línea 2)

`5h 41%  7d 87%`: cuánto llevas gastado de la ventana de 5 horas y de la semanal. Si
`rate_limits` todavía no existe (antes de la primera llamada), el sector queda en blanco: eso no
es un error, es "todavía no hay dato".

## Paso 5 — Git (#13–#14)

`+213/-15  ⎇ main ↑1 ↓0 ●2 ?1`: líneas añadidas/quitadas en la sesión, rama, commits sin
pushear (`↑`) y sin traer (`↓`), archivos modificados (`●`) y sin seguimiento (`?`). `⊘` en vez de
`↑↓` quiere decir que la rama no tiene upstream. `↑1` se pone ámbar cuando el commit más viejo
sin pushear lleva más de 2 h.

## Paso 6 — HANDOFF (#15)

`HANDOFF.md` es la memoria de la sesión. `✓HANDOFF` en verde: nada se movió después de
escribirlo. `⚠HANDOFF 14:05 ·2f ·1c ·0s`: lo escribiste a las 14:05 y desde entonces hay 2
archivos más nuevos que él, 1 commit y 0 sesiones nuevas. En rojo con más de 20 archivos o 2
sesiones. Un `?` en un contador quiere decir "no se pudo calcular", nunca cero.

## Paso 7 — La pista (#18) y lo que queda (#16–#17)

El texto magenta al final es **una sola** sugerencia: la del umbral de mayor prioridad que se
cumple ahora. El orden lo da `priority` en `thresholds.json`: cuota → contexto rojo → caché
enfriando → hit bajo → sesión larga → commits sin push. Nunca muestra dos: una barra con dos
consejos ya no se lee de un vistazo. **#17** es el nombre de la sesión; **#16** (`⚠ umbrales`) solo
aparece si `thresholds.json` falta o está roto.

## Qué salió mal de verdad

- **`❄true%/0` y un "sin HANDOFF" falso (2.1.275).** Claude Code quitó `.permission_mode` del
  JSON. El script leía 17 campos separados por tabulador, y con `IFS=$'\t'` un campo vacío
  colapsa: todo se corrió un lugar. `hit` recibió `true`, el directorio recibió un número y git
  falló. Arreglo: separador `\x1f`, centinela por campo y control de cantidad de campos.
- **`❄96% /59m` se contradecía.** Un acierto alto junto a un copo, y un TTL que no respondía
  la pregunta real ("¿cuánto me queda si no mando nada?"). De ahí sale el rediseño del Paso 3
  (2026-10-15): el estado es una palabra, el número son minutos y el hit solo aparece si importa.
- **`$12,00` en vez de `$12.35`.** Con locale `es_ES`, `printf '%.2f'` lee y escribe con coma.
  La barra fija `LC_NUMERIC=C` y conserva tu `LC_CTYPE` para los glifos.
- **"hace 50 min" durante horas.** La barra solo se redibuja con eventos de la sesión, así que
  una edad se congela. El HANDOFF muestra ahora la **hora** a la que se escribió.

## Cómo verificar

```bash
bash tests/statusline_test.sh        # golden files + invariantes: 67 casos
bash home/.claude/statusline.sh < tests/fixtures/cache-cooling.json
```

La segunda línea pinta el estado "enfriando" desde una captura real saneada (2.1.300). Prueba a
cambiar `cache-cooling` a 60 en `rules/thresholds.json` y vuelve a correrla: la misma caché pasa
a "enfriando" sin tocar el script.

## Autoevaluación

1. La barra muestra `⚠m` donde suele ir el tiempo. ¿Es una sesión recién abierta o el JSON
   cambió de forma?
2. Ves `412k/967k` en verde. ¿Puede ser? ¿Qué te dice eso de `thresholds.json`?
3. `⚡ caliente · 3m` no existe: ¿qué ves en su lugar y por qué?
4. Tienes `❄ fría · próximo turno reescribe` con 380k de contexto. ¿Sigues o haces `/handoff` y
   `/clear`? ¿Qué cambia en el costo del primer turno entre una opción y la otra?
5. `⚠HANDOFF 09:12 ·0f ·0c ·?s`: ¿está al día el HANDOFF?

<details><summary>Respuestas</summary>

1. Ninguna de las dos se puede descartar con ese dato solo, pero `⚠` dice "faltó o no se pudo
   leer". En una sesión nueva el tiempo sí llega; si persiste, re-captura el payload
   (`statusline-internals.md`).
2. No con los umbrales del kit: 412k pasa los 300k de `context-red`. Si está verde, alguien movió
   el número con `CC_CTX_RED_K`; un `thresholds.json` ilegible la dejaría sin color y diría
   `⚠ umbrales`.
3. `⚡ enfriando · 3m` en ámbar, porque 3 ≤ `cache-cooling` (5), y la pista te propone un turno
   corto o un `/handoff`.
4. El primer turno reescribe el contexto en los dos casos, pero tras `/clear` se reescribe uno
   mucho más chico. Con 380k (zona roja) lo correcto es `/handoff` y luego `/clear`.
5. No se sabe: `?s` es "no se pudo contar las sesiones", no cero. Por eso no sale `✓HANDOFF`.

</details>
