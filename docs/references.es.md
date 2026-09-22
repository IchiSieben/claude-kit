# Referencias

Se espera que las referencias del kit cambien a medida que cambia la evidencia — un paper se
retracta, aparece un estudio más fuerte, o alguien descubre que el kit está citando un paper para
una afirmación que ese paper no hace. Para proponer, cuestionar o agregar una referencia, abrí un
issue con `.github/ISSUE_TEMPLATE/reference.md`.

Esta página solo lista referencias que se pudieron resolver a una fuente real y verificable, y que
se leyeron. Lo que el kit cita pero no se pudo verificar así está en la última sección, no acá.

## Verificadas

### Revisión

| Referencia | Citada por | Qué encontró realmente |
|---|---|---|
| Panickssery et al., "LLM Evaluators Recognize and Favor Their Own Generations," NeurIPS 2024. [arXiv:2404.13076](https://arxiv.org/abs/2404.13076) | `skills/xreview/SKILL.md` ("same-model self-review is biased toward approval") · `MANUAL.md` §5 ("sesgo de auto-preferencia") | El sesgo de auto-preferencia es real y escala con la capacidad de auto-reconocimiento: cuanto más confiable distingue un modelo su propia salida de la de otro, más la favorece — incluso cuando evaluadores humanos ven ambas como equivalentes. |
| Mathews & Nagappan, "Test-Driven Development and LLM-based Code Generation," ASE 2024. [Preprint relacionado](https://arxiv.org/abs/2402.13521) | `skills/spec/SKILL.md` ("tests-as-spec raise solve rates") | Su enfoque TGen genera código a partir de un conjunto inicial de tests dentro de un ciclo TDD; usar los tests como especificación ejecutable mejoró medible la precisión y confiabilidad del código generado. |

### Aprendizaje

| Referencia | Citada por | Qué encontró realmente |
|---|---|---|
| Shen & Tamkin, "How AI Impacts Skill Formation," feb. 2026. [arXiv:2601.20245](https://arxiv.org/pdf/2601.20245) | `rules/learning-mode.md` ("delegating fully lowers comprehension... explanations alongside code... preserve it") | Ensayo aleatorizado (RCT) con 52 programadores junior aprendiendo una librería de Python que no conocían, la mitad con asistente de IA. El grupo con IA obtuvo menos puntaje en el quiz de comprensión en general (50% vs. 67%), pero el efecto dependía de *cómo* usaban el asistente: quienes delegaban ("escribime este código") sacaron menos de 40%, mientras que quienes lo usaban como tutor ("¿por qué funciona así?") sacaron más de 65% — igualando o superando al grupo sin IA. La regla del kit refleja esto correctamente. |

## Contexto, ruteo y costo, y diseño multiagente — lectura de fondo, no citada directamente

Las reglas del kit sobre presupuesto de contexto (`rules/context-hygiene.md`), ruteo de modelos
(`skills/route/SKILL.md`) y delegación (`MANUAL.md` §5) son consistentes con los siguientes
resultados conocidos, pero un grep del árbol `home/.claude/` del kit no encontró ninguna línea que
nombre a estos cinco papers. Se listan acá porque se dieron como justificaciones candidatas a
quien escribió esta página; el kit en sí mismo no los cita hoy. No leas las filas de abajo como
"el kit dice X por el paper Y" — leelas como "esto es lo que el campo publicó sobre el tema que
aborda esa regla."

| Referencia | Regla relacionada del kit | Qué encontró realmente |
|---|---|---|
| Chen, Zaharia y Zou, "FrugalGPT: How to Use Large Language Models While Reducing Cost and Improving Performance," 2023. [arXiv:2305.05176](https://arxiv.org/abs/2305.05176) | `skills/route/SKILL.md` (cascada barata primero) | Una cascada de LLMs que aprende qué combinación de modelos baratos/caros probar, en orden, por consulta. En sus experimentos iguala la precisión de GPT-4 con hasta 98% menos costo. |
| Ong et al., "RouteLLM: Learning to Route LLMs with Preference Data," ICLR 2025. [arXiv:2406.18665](https://arxiv.org/abs/2406.18665) | `skills/route/SKILL.md` (tabla de reglas de ruteo) | Entrena un clasificador binario sobre ~80k batallas de Chatbot Arena más datos sintéticos para predecir, por consulta, si gana un modelo débil o uno fuerte — un trade-off costo/calidad aprendido, no una tabla de reglas escrita a mano como la del kit. |
| Liu et al., "Lost in the Middle: How Language Models Use Long Contexts," 2023. [arXiv:2307.03172](https://arxiv.org/abs/2307.03172) | `rules/context-hygiene.md` (banda de trabajo, resumir en vez de pegar logs completos) | La precisión de recuperación sobre contextos largos tiene forma de U: los modelos encuentran mejor la información cerca del inicio o el final del contexto, y peor en el medio, incluso cuando todo entra en la ventana. |
| Chroma, "Context Rot: How Increasing Input Tokens Impacts LLM Performance," informe técnico, julio 2025. [research.trychroma.com](https://www.trychroma.com/research/context-rot) | `rules/context-hygiene.md` (banda de trabajo en tokens absolutos, no porcentaje de ventana) | En 18 modelos, el desempeño no es plano al crecer el input — degrada de forma desigual según la similitud aguja-distractor, la estructura del "pajar" y otros factores: que algo "entre" en la ventana no significa que el modelo lo use de forma confiable. |
| Cemri et al., "Why Do Multi-Agent LLM Systems Fail?" 2025 (taxonomía MAST). [arXiv:2503.13657](https://arxiv.org/abs/2503.13657) | `MANUAL.md` §5 (el hilo principal decide, los subagentes ejecutan; coordinación mínima) | El análisis de 1.642 trazas de 7 frameworks multiagente encontró tasas de falla de 41-86,7% y construyó una taxonomía de 14 modos de falla (MAST) en diseño, desalineación entre agentes y verificación — evidencia de que agregar agentes agrega una superficie real de falla por coordinación, no una ganancia gratis. |
| Narayan, Biderman, Eyuboglu et al., "Minions: Cost-efficient Collaboration Between On-device and Cloud Language Models," 2025 (ICML 2025). [arXiv:2502.15964](https://arxiv.org/abs/2502.15964) | `skills/route/SKILL.md` / `MANUAL.md` §5 (lo barato se queda en local/modelo chico) | Un modelo local pequeño lee todo el contexto local y solo manda subtareas cortas y descompuestas a un modelo en la nube; su protocolo ingenuo reduce el costo remoto ~30x conservando ~87% de la precisión del modelo frontera. |
| Belcak, Heinrich, Diao et al. (NVIDIA), "Small Language Models are the Future of Agentic AI," 2025. [arXiv:2506.02153](https://arxiv.org/abs/2506.02153) | `skills/route/SKILL.md` (haiku/sonnet para trabajo mecánico) | Sostiene que la mayoría de los pasos repetitivos y de propósito único dentro de sistemas agénticos no necesitan un modelo de frontera: modelos chicos (menos de ~10B parámetros) pueden servirlos a una fracción del costo, reservando los modelos generalistas grandes para pasos genuinamente abiertos. |

## No verificadas — a confirmar por el owner

`MANUAL.md` §5 del kit cita `Xiang 2026` para "el revisor tiene que ser por lo menos tan fuerte
como el autor," y `skills/xreview/SKILL.md` cita `Panickssery 2024; Xiang 2026, Yang 2026` para la
rúbrica de revisión de elección forzada. Ni `Xiang` ni `Yang` resuelven a un paper específico y
encontrable de 2026:

- **Xiang 2026** — se buscó en arXiv un paper de asimetría revisor/autor o juez-LLM por un autor
  apellidado Xiang publicado en 2026; no se encontró coincidencia. El match temático más cercano,
  "Can LLMs Judge Better Than They Generate?" (arXiv:2606.28050), es de otro autor (Bandyopadhyay)
  y trata la asimetría juez/generador en general, no "revisor ≥ autor."
- **Yang 2026** — se buscó un paper de 2026 sobre revisores LLM más débiles causando ediciones
  dañinas, o sobre rúbricas de revisión de código cross-model; apareció "Stop Automating Peer
  Review Without Rigorous Evaluation," que acredita feedback de una Diyi Yang, pero ese paper trata
  la política de revisión humana de ICML, no una rúbrica de revisión de código por LLM — no coincide
  con la afirmación para la que se lo cita.

El propio `MANUAL.md` no menciona `Lodha 2026` ni `Min 2026` / "CAT" en ningún lugar — un grep de
todo el árbol `home/.claude/` no encontró rastro de ninguno de los dos nombres. Las búsquedas de un
paper de arXiv de 2026 de un "Lodha" sobre agentes LLM, y de un paper de 2026 de "Min" que introduzca
algo llamado "CAT," no devolvieron ninguna coincidencia plausible. Estas dos referencias no se pueden
atar a ninguna regla específica del kit tal como está hoy; el owner debería decir qué querían
respaldar, o sacarlas.

`skills/spec/SKILL.md` también cita a `Tufano et al. 2026` para "escribir el contrato...
mejora medible la detección de bugs." No se encontró ningún paper de 2026 con primer autor Tufano
sobre pre/postcondiciones y detección de bugs; solo apareció trabajo anterior de Tufano (2024 y
antes) sobre temas de revisión de código no relacionados. Se lista acá y no en Verificadas.

---

Las reglas del kit citan estas fuentes con líneas `Fuente:` directamente dentro de `MANUAL.md` —
esta página existe para contrastar esas citas contra los papers reales, no para reemplazarlas.
