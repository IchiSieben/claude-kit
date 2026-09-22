# Candidatos de referencia — a decidir por el autor

Cinco citas del kit no se pudieron resolver a un paper real y verificable (ver
[`docs/references.md`](references.es.md) → Sin verificar). Al 2026-09-22, las reglas que las
citaban ya se reanclaron a lo que sí está verificado — Panickssery et al. 2024 para la
condición de que el revisor sea al menos tan fuerte como el autor — y los cinco nombres se
sacaron de la prosa del kit. Sobreviven solo aquí, como candidatos, para que el autor pueda
resolver o descartar cada uno sin repetir la búsqueda desde cero.

Para cada uno: hasta 3 candidatos encontrados, con la razón por la que ninguno calza con
confianza.

## Xiang 2026

Citado (hasta este cambio) para "el revisor tiene que ser al menos tan fuerte como el autor" /
la rúbrica de elección forzada.

1. Bandyopadhyay, "Can LLMs Judge Better Than They Generate?" [arXiv:2606.28050](https://arxiv.org/abs/2606.28050) — misma familia de tema (asimetría juez/generador), autor distinto, no se encontró ningún paper 2026 firmado por "Xiang" que calce con la afirmación.

No se encontró ningún paper de un autor llamado Xiang, publicado en 2026, que respalde esta
afirmación. El candidato 1 es el match temático más cercano; se ofrece para que el autor
verifique que no sea un coautor o un nombre mal transcrito de la lista de citas de Panickssery.

## Yang 2026

Citado (hasta este cambio) junto a Xiang 2026 para la misma rúbrica.

1. "Stop Automating Peer Review Without Rigorous Evaluation," acredita a una Diyi Yang — pero el paper trata sobre la política de revisión por pares humana de ICML, no sobre una rúbrica de revisión de código con LLMs. Tema distinto, no es un match.

No se encontró ningún paper 2026 sobre daño causado por un revisor más débil o rúbricas de
revisión cruzada entre modelos firmado por un autor llamado Yang. Recomendación: descartar, o
reemplazar por una descripción de primera mano ("práctica propia, sin paper que la respalde
todavía") si el autor no puede aportar la fuente.

## Lodha 2026

No está citado en ningún lugar del árbol `home/.claude/` del kit (grep 2026-09-22, cero
resultados antes y después de este cambio). Ninguna regla lo referencia, así que no hay nada
que reanclar — solo esta entrada, por si el autor recuerda qué debía respaldar.

No se encontraron candidatos; los términos probados ("Lodha 2026 LLM agent", "Lodha arxiv 2026
agentic") no devolvieron nada plausible.

## Min 2026 ("CAT")

Misma situación que Lodha: no está citado en ningún lugar del árbol del kit. No se encontró
ningún paper que introduzca un método o benchmark llamado "CAT" con primer autor Min, fechado
en 2026.

No se encontraron candidatos.

## Tufano 2026

Citado (hasta este cambio) en `skills/spec/SKILL.md` para "escribir el contrato (pre/post-
condiciones, comportamiento indefinido) antes del código mejora medible la detección de bugs."

Búsqueda nueva corrida el 2026-09-22 (no solo la pasada anterior ya registrada en
`references.md`):

1. "Breaking the Myth: Can Small Models Infer Postconditions Too?" [arXiv:2507.10182](https://arxiv.org/pdf/2507.10182) — tema correcto (inferencia de postcondiciones), sin firma de Tufano, 2025 no 2026.
2. "Beyond Postconditions: Can Large Language Models infer Formal Contracts for..." [arXiv:2510.12702](https://arxiv.org/pdf/2510.12702) — tema correcto, sin firma de Tufano, 2025.
3. El trabajo propio confirmado de Michele Tufano en 2023-2024 ("Predicting Code Coverage without Execution," [arXiv:2307.13383](https://arxiv.org/abs/2307.13383); AutoDev, 2024) — autor correcto, tema equivocado (predicción de cobertura / automatización de agentes de desarrollo, no pre/post-condiciones) y año equivocado.

No existe todavía ningún paper 2026 con Tufano como primer autor sobre contratos-antes-del-
código y detección de bugs. La regla del kit para esta afirmación ahora dice "práctica propia"
hasta que uno de los dos papers de inferencia de contratos de 2025 arriba tenga un sucesor 2026
que sí nombre a Tufano, o el autor aporte otra fuente.
