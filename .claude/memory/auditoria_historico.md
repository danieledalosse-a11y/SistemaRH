---
name: auditoria-historico
description: Premissa obrigatória de rastreabilidade — todo módulo do SistemaRH deve registrar histórico de movimentações
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-08-07T12:32:27.622Z
---

Todo módulo do SistemaRH deve registrar histórico de movimentações. Isso é uma premissa do sistema, não opcional.

**Why:** A usuária precisa de rastreabilidade completa de tudo que acontece no sistema — equivalente a uma auditoria. Cada módulo (Cadastro, Férias, Avaliações, Admissão, etc.) deve deixar rastro de quem fez o quê e quando.

**How to apply:**
- Qualquer alteração relevante (criação, edição de campos, mudança de status, aprovação, efetivação, lançamento de férias, avaliação, demissão) gera um registro no array `historico`
- Cada entrada: `{ tipo, detalhe, data (ISO), usuario (nome de quem fez) }`
- Histórico armazenado na coluna `historico JSONB` do registro principal (`colaboradores.historico`)
- Novos módulos sempre gravam no `historico` do colaborador afetado
- Documentado em `CLAUDE.md` na seção "Premissa obrigatória — Rastreabilidade e Auditoria"
