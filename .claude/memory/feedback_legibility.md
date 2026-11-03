---
name: feedback-legibility
description: "Padrão global de legibilidade do SistemaRH — tokens de cor, tamanho mínimo de fonte, quando aplicar"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-09-23T19:12:15.885Z
---

Nunca usar texto informativo abaixo de 11px em nenhum módulo do SistemaRH.

**Why:** A usuária identificou textos em 8px/9px/10px + cinzas claros como problema de legibilidade. Deixou explícito que "uma tela premium não é aquela que usa a fonte mais fina ou o cinza mais suave, e sim aquela que consegue ser elegante sem sacrificar a facilidade de leitura". Aplicado globalmente em set/2026 via replace em todos os módulos.

**How to apply:**
- `--text-sec: #4B5565` (não #667085) — contraste 6.1:1 s/ branco
- `--text-ter: #6C7589` (não #98A2B3) — contraste 4.6:1, passa WCAG AA
- 12px+ para dados operacionais (nome, data, número, status)
- 11px mínimo absoluto para qualquer texto informativo/auxiliar
- < 11px apenas para decorativo/estrutural (ícones, chevrons, separadores visuais)
- Hierarquia visual mantida por tamanho + peso + cor — nunca sacrificar legibilidade por "elegância"
