---
name: visor
description: Dashboard resumido de tus sesiones de Claude Code en la terminal — esta sesión (modelos, tokens, skills, agentes), las sesiones vivas en paralelo, y el consumo de las últimas 5h y 7 días con el reparto real del gasto. Úsalo cuando quieras saber dónde se están yendo los tokens sin leer /usage entero.
disable-model-invocation: true
argument-hint: [minutos para considerar "viva" una sesión, por defecto 15]
allowed-tools: Bash(python *)
---

# Visor

<!-- No `--session "${CLAUDE_SESSION_ID}"`: a skill does not receive that variable (the `!`
     block runs in a shell where it is not exported — measured), so passing it sent an empty
     string and visor.py always printed "sin --session; pásale ${CLAUDE_SESSION_ID}", which
     is advice nobody can follow. visor.py now deduces the session from the directory, the
     same way `/ahora` does. -->
```!
python "${CLAUDE_PROJECT_DIR}/visor.py" ${ARGUMENTS:+--live-min $ARGUMENTS} 2>/dev/null || python "$HOME/claude-archive/visor.py" ${ARGUMENTS:+--live-min $ARGUMENTS}
```

Lee la salida de arriba y dime, en tres líneas como máximo:
1. Si el carril barato está por debajo del 35% del gasto, qué tarea concreta de esta sesión debió ir a Sonnet.
2. Si las lecturas de caché pasan del 60% del gasto, cuánto contexto arrastras y si toca `/handoff`.
3. Nada más. No repitas los números; ya los estoy viendo.
