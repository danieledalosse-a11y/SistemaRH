---
name: he-eventos-proposta
description: "Eventos e Ocorrências no módulo HE — IMPLEMENTADO e validado (Nov/2026). Migration 147, aba Eventos com acordeão ano→mês, integração Análise/Painel."
metadata:
  node_type: memory
  type: project
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-11-19T14:47:15.403Z
---

## Status: CONCLUÍDO E VALIDADO — Nov/2026

Funcionalidade implementada em produção. Migration 147 executada. Usuária confirmou: "testei, funcionou".

---

## O que foi implementado

### Migration 147 (`migrations/147_he_eventos.sql`)
- Tabela `he_config` (singleton id=1, JSONB `dados.tipos_evento[]`)
- Tabela `he_eventos` com constraints de integridade por abrangência
- 5 políticas RLS: rh/admin vê tudo; diretoria vê ativos; gestor vê ativos globais + empresa/setor da equipe
- SRF `auth_gestor_equipe_ids()` usada como `= ANY(SELECT fn())` — nunca `= ANY(fn())`
- GRANT SELECT,INSERT,UPDATE para `authenticated`
- Soft delete (sem DELETE real); inativação via PATCH `ativo=false`

### Aba Eventos — 4ª aba do módulo
Estrutura: header + formArea + filtros + acordeão + card tipos

**Acordeão ano → mês:**
- Eventos agrupados por `data_inicio` (mês de início), sem duplicidade multi-mês
- Todos recolhidos por padrão; ano atual identificado com badge azul "Ano atual"
- Badge "● Em andamento" nos eventos cujo período cobre hoje
- Eventos inativos integrados (borda tracejada + badge "INATIVADO dd/mm/aaaa")
- Filtros atuam sobre todo o histórico

**Card "Tipos de Evento" — recolhível por padrão**
- Chips com × hover-only; toggle "+ Novo tipo"
- Atualização cirúrgica via `_renderTiposChips()` (sem re-render da aba)
- Persistência em `he_config.dados` via PATCH

### Integração aba Análise
- Chips de eventos ativos do período aparecem acima dos gráficos
- Checkbox "Exibir eventos e ocorrências" com estado em localStorage

### Integração aba Painel
- Linha de contexto no rodapé: "📌 N evento(s) neste período" com badges de títulos

---

## Bugs corrigidos durante implementação

| Bug | Causa | Fix |
|---|---|---|
| Formulário não abria visivelmente | `evFormArea` estava acima do botão no DOM | Movido para após o header |
| Todos os writes falhavam silenciosamente | Usava `_SB_URL`/`_SB_KEY` inexistentes | Corrigido para `SB_URL`/`SB_HEADERS` |
| Módulo todo travado (spinner infinito) | `const _MESES_PT` declarado duas vezes | Renomeado para `_MESES_NOMES` |

---

## Próxima etapa planejada (segunda etapa — não iniciada)
Conforme memória `he_eventos_proposta` original e skill `horasextras.md`:
- Tabela `he_eventos` com coluna colaborador (ligação por RH a um colaborador específico)
- 5ª aba "Ocorrências" ou integração de gráficos com marcadores visuais por competência
- Tipos de ocorrência configuráveis por colaborador (advertência, elogio, afastamento, etc.)

**Why:** o escopo atual cobre eventos contextuais (campanha, balanço, datas) em nível de empresa/setor. A segunda etapa é para ocorrências individuais de colaborador, ainda não priorizada.
