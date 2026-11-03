---
name: project-state
description: Estado atual do PainelRH local (folha de pagamento) — atualizado 2026-10-02
metadata:
  node_type: memory
  type: project
  modified: 2026-10-02T17:11:07.963Z
  originSessionId: 32ffb793-7e1c-481e-b441-84ffa52b6b17
---

## PainelRH (folha de pagamento local)

Arquivo de distribuição: `Painel-Salarial-RH.html` (autocontido, ~1,1 MB).
Fontes: `index.html`, `styles.css`, `app.js` (~2.460 linhas).
Regra: regenerar `Painel-Salarial-RH.html` após qualquer edição nas fontes (ver CLAUDE.md).
Último commit: `ddff065` — feat: exibe salário de Gerente de Vendas na coluna Salário Base.

## Navegação (sidebar)

### Análises Fixas (sempre visíveis)
- Comparação por Função
- Comparação por Setor
- Evolução Temporal
- Lista de Colaboradores

### Indicadores (Tarefa 1) — colapsado por padrão
- Individual vs. Média ← movido aqui (em validação, antes estava em Análises Fixas)
- Massa Salarial
- Equidade Salarial
- Custo por Área/Cargo
- Evolução (Indicadores)
- Alertas de Anomalias

O toggle é implementado via JS IIFE em `app.js` (último bloco antes de `render()`), usando `max-height` CSS transition.

## Lista de Colaboradores — colunas disponíveis (LISTA_COLAB_COLUMNS)

Ordem das pílulas/colunas:
1. Código (visível por padrão)
2. Nome (visível)
3. Cargo (visível)
4. Unidade (visível)
5. Setor (visível)
6. **Salário Base** — tipo `brl-fixo`: mostra valor para salário fixo, `—` para comissionados (oculta por padrão)
7. Total Bruto c/ Bonif. (visível)
8. Total Líquido c/ VA (visível)
9. Holerite Bruto (oculta)
10. Holerite Líquido (oculta)
11. Bonificação (oculta)
12. Markup (oculta)
13. Vale | Unimed | Santa Casa (oculta)
14. VA (oculta)
15. Comissão / Prêmio (oculta)

## Regra de comissionados

`isCommissionedRole(cargo)` identifica: Vendedor(a), Vendedor(a) Junior/Pleno/Sênior, Gerente de Vendas.

### Coluna "Salário Base" na Lista de Colaboradores (tipo `brl-fixo`)
| Cargo | Valor exibido | Fonte |
|---|---|---|
| Gerente de Vendas | salário fixo + 40% gratificação | col G (`comissaoPremio`) |
| Vendedor(a) | `—` | — |
| Demais (salário fixo) | salário base | col F (`salarioBase`) |

**Por quê:** Gerente de Vendas tem salário fixo + 40% gratificação lançados na col G. A identificação usa o mesmo regex de `isCommissionedRole` (`/^gerente\s+de\s+vendas?$/`).

- Em Comparação por Função, o toggle de métrica omite "Salário Base" para todos os comissionados e usa Bruto/Líquido

## Próximas features planejadas

**Seção de Envio WhatsApp** — cards por colaborador com link `wa.me`. Depende de:
1. Atualizar `parseWorkbook` para mapear col V (whatsapp, índice 21) e col W (valeGas, índice 22)
2. Nova seção `sec-envioWhatsApp` no HTML
3. Mensagem com encargos discriminados, sem HE, sem Vale Médico, sem nome da empresa

**Individual vs. Média** (deferido) — atualmente oculto em Indicadores (Tarefa 1).
Possível redesign futuro: gráfico de evolução temporal mostrando colaborador vs. média da função mês a mês.

## SistemaRH — Motor D&P (contexto separado)

Ver memory `sistemarh_state.md` e skill `C:\Users\reves\SistemaRH\.claude\agents\desenvolvimento.md`.
