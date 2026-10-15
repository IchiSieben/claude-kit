# Diseño de la demo de la barra

La demo vive en https://kit.ichisieben.dev/ y en `docs/demo/`. Este documento explica por qué
tiene la forma que tiene. Sirve para la lección y para quien la mantenga.

## La regla de la que sale todo: ningún estado inventado

Cada fotograma de la barra es una línea que imprimió el `statusline.sh` real.
`tools/render-grid.sh` arma doce repos de prueba (estado de git × estado del HANDOFF) y les pasa
el script a cada combinación de controles: 3 modelos × 4 contextos × 3 cachés × 3 cuotas × 4 git ×
3 HANDOFF, en total 1 296 celdas. Además hay 9 pasos de una sesión de 3 horas, cada uno con su
propio reloj, y un render sin `thresholds.json` para el sector 16. Todo se guarda en
`docs/demo/grid.json`, junto con el hash de `statusline.sh` + `thresholds.json`. Si la barra
cambia y la rejilla no se regenera, `verify.sh` falla.

La animación ocurre **solo entre dos celdas reales**. Un sector pasa del texto viejo al nuevo con
un fundido, nunca recorre números intermedios. Si el contexto pasa de 180k a 320k, la barra no
muestra 250k: el script nunca imprimió ese estado aquí. Si una explicación necesitaba un estado
que la rejilla no tenía, se añadió a la rejilla:

- el 4.º estado de git, con un archivo sin seguimiento (`?1`);
- la pista de sesión;
- el render sin umbrales.

Por eso la demo es una rejilla y no un port del script a JavaScript. Un port sería una segunda
implementación, y dos implementaciones se separan con el tiempo. La rejilla es la primera
implementación, grabada.

## Por qué causa → efecto

La barra traduce estado invisible (tokens, minutos de caché, commits) a una línea de texto. La
demo hace visible esa traducción. Al mover un control:

1. sale una línea del control con un punto que la recorre (el punto de tráfico de ArqViva);
2. llega a cada sector que cambió;
3. ese sector hace un fundido con un halo del acento;
4. el rótulo dice en una frase qué cambió y por qué.

Los sectores que no cambian solo se reacomodan si el texto vecino cambió de largo, sin halo. Así
el ojo va directo a lo que cambió.

El rótulo no escribe umbrales de memoria. Los lee de `grid.json`, que los copia de
`thresholds.json` en cada render. Si mañana la banda roja pasa a 280k, el texto dirá 280k.

La relación funciona en las dos direcciones:

- el foco del teclado en un control ilumina sus sectores;
- el puntero sobre un sector ilumina los controles que lo gobiernan.

En el móvil la línea cruzaría media pantalla sin aportar nada. Ahí la barra y el rótulo quedan
fijos arriba mientras bajas a los controles, y el halo hace el trabajo de la línea.

## Por qué tres niveles por sector

La misma tarjeta tiene que servir a tres lectores:

- **Para un niño:** una metáfora en una frase, para quien nunca vio una barra de estado.
- **Qué mide:** el campo exacto del payload o el comando, y qué significa cada símbolo y cada
  número, para quien quiere confiar en ella.
- **Por qué está ahí:** la decisión de diseño y su umbral, para quien la va a modificar.

Solo el primer nivel viene abierto. La tira oscura de cada tarjeta recorre los estados reales de
ese sector sacados de la rejilla, no ejemplos escritos a mano.

## Sistema visual y movimiento

- **Identidad del Landing:** Space Grotesk y JetBrains Mono, los mismos tokens claro/oscuro, dos
  radios (28 px para tarjetas y marcos, píldora para controles).
- **Un solo acento, el teal, con un solo trabajo:** decir "esto cambió" (línea, halo, foco).
- **La barra va dentro de un marco de terminal**, porque así se ve en la vida real. La
  conversación de arriba es abstracta a propósito: la barra es el único texto real del marco.
- **Los símbolos de la barra no están en los subconjuntos latinos de las fuentes.** Dos
  subconjuntos de DejaVu (4,9 KB, verificados glifo a glifo) los cubren por `unicode-range`, para
  que ninguno caiga en la fuente del sistema. La misma combinación, fusionada en
  `docs/tapes/fonts/KitMono-Regular.ttf`, la usa `freeze` para los PNG.
- **Gramática de movimiento v13:** ease-out al entrar, 450–700 ms para revelar, 180 ms para hover,
  escalonado de 60 ms, solo opacidad y transformaciones. Con `prefers-reduced-motion` quedan los
  fundidos y desaparecen el desplazamiento y el punto viajero. Nada aparece de golpe.

## El recorrido y la sesión

El recorrido reutiliza `../shared/tutorial/` con dos ganchos aditivos (`onStep`, `onClose`), para
que cada paso mueva los controles de verdad mientras explica. Se abre solo en la primera visita y
el botón "Ver el recorrido otra vez" lo repite.

"Reproducir una sesión" recorre 9 renders reales de una sesión de 3 horas: el contexto crece, la
caché se enfría en una pausa y se reescribe al volver, el HANDOFF acumula deriva y, al final,
`/handoff` + push lo deja en verde. Cada paso tiene su propio tiempo transcurrido, costo y diff,
porque así lo imprime el script. No se reutilizan celdas de la rejilla con un reloj falso.

## Medidas

- JS total: unos 31 KB gzip, sin frameworks.
- La rejilla (12 KB gzip) se carga después del primer render. La celda inicial va dentro del HTML,
  escrita por `render-grid.sh`.
- Lighthouse, axe, parpadeo y capturas los corre la Mac (`tools/lane.sh` con la lane `demo`). El
  resultado queda en `evidence/demo-v2/GATES.md`.
