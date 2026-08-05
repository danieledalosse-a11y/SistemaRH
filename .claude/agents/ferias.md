---
name: ferias
description: Especialista no módulo de Férias do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa no arquivo modulos/ferias/index.html ou nos scripts Python de manutenção do Supabase de férias.
---

# Skill: Módulo Férias — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).
Arquivo principal: `C:\Users\reves\SistemaRH\modulos\ferias\index.html` (~3.200 linhas, tudo inline).

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo permanece inline no index.html.
2. **Nunca usar a chave secreta do Supabase no browser** — chave publicável apenas no index.html.
3. **Sempre apresentar proposta antes de implementar** — aguardar aprovação da usuária.
4. **Nunca abreviar valores** (`R$ 12.500,00`, não `12,5k`).
5. **Estilos de risco sempre inline no span** — a classe `.badge-status-r` tem background fixo que sobrepõe; os três níveis usam `style=` direto no elemento.

## Fluxo de trabalho padrão

1. Ler o arquivo: `Read modulos/ferias/index.html`
2. Localizar a seção relevante com `Grep`
3. Propor a mudança com mockup visual se houver alteração de UI
4. Implementar apenas após aprovação
5. Verificar no browser preview (`preview_start` com nome `"ferias"` do launch.json)

## Tabelas Supabase (módulo férias)

### `colaboradores`
`id, matricula, nome, cargo, setor, empresa_registro_nome, empresa_atuacao_nome, data_demissao`
- `ativo = !data_demissao`
- Matrículas repetem entre empresas → identificar por matricula + nome

### `ferias`
`id, colaborador_id, matricula_colaborador, ano, pa_inicio, pa_fim, status, dias_antecipados, abono_pecuniario` + colunas de lançamentos

## Cálculo de saldo

```js
calcSaldo(reg) = reg.totalDias - usado - reg.diasAntecipados - reg.abonoPecuniario
```

`diasAntecipados`: fica no PA **de onde os dias foram retirados** (ano seguinte ao das coletivas).

## Risco de dobra

Função `nivelRisco(dpd)` — `dpd` = dias até o prazo de dobra:

| Nível | Condição | Badge | Visual inline |
|---|---|---|---|
| `critico` | dpd < 60 | "Crítico" | fundo `#D92D20`, texto branco |
| `atencao` | dpd <= 120 | "Atenção" | fundo `#FFFAEB`, texto `#B54708` |
| `noradar` | dpd <= 180 | "No radar" | fundo `#EFF6FF`, texto `#1D4ED8` |
| — | dpd > 180 | não exibe | — |

**Regra de exibição no badge:** na aba Risco de Dobra, o badge mostra apenas o nome do nível ("Crítico" etc.). A data de vencimento fica em coluna separada ("Vencimento da dobra").

**Ordenação:** na aba Risco de Dobra, lista é ordenada por `minDpd` ascendente (mais urgente primeiro).

## Filtros independentes por sub-aba

A Visão RH tem duas sub-abas (**Lista anual** e **Calendário**) com filtros completamente independentes.
Instâncias de MultiSelect registradas em `MS_INSTANCES`: `msEmpresaLista`, `msSetorLista`, `msEmpresaCal`, `msSetorCal`.
`getColabsVisao(contexto)` — lê o conjunto correto conforme o contexto ('lista-anual' ou 'calendario').

## Toggle de navegação (segmented toggle)

```css
/* Aba ativa Lista anual → azul */
.vis-tab#vt-lista.active { background: #1570EF; color: #fff; }
/* Aba ativa Calendário → verde */
.vis-tab#vt-cal.active   { background: #067647; color: #fff; }
```

## Scripts Python de manutenção

Usam a chave **secreta** do Supabase. Sempre escrever em arquivo `.py` no scratchpad e executar via `Bash`, nunca inline com PowerShell (conflito com colchetes no f-string).

Padrão de conexão:
```python
from supabase import create_client
sb = create_client("https://rujtbxwssiofiialnbbg.supabase.co", SUPABASE_SECRET_KEY)
```

Para matrículas duplicadas entre empresas, match por `matricula + nome` (exato, depois parcial).

## Layout da lista — grades dinâmicas

O CSS usa classes de grid **aplicadas via JS** conforme o filtro ativo (`_statusFiltro`):

| Filtro | Classe CSS | Colunas |
|---|---|---|
| `risco` | `proto-grid-5` | Colaborador · Empresa/Setor · Saldo a tirar · Vencimento da dobra · Nível de risco |
| `hoje` | `proto-grid-4` | Colaborador · Empresa/Setor · Período ativo · Retorno |
| demais | padrão 6 colunas | Colaborador · Empresa/Setor · PA/Situação · Agendamento · Saldo · Status |

Classes CSS:
```css
.proto-grid-4 { grid-template-columns:2.5fr 1.2fr 1.8fr 1.4fr !important; }
.proto-grid-5 { grid-template-columns:2.5fr 1.2fr 0.9fr 1.4fr 1.1fr !important; }
```

## Badges de status

| Badge | Cor | Significado |
|---|---|---|
| Concluído | verde (`#027A48`, bg `#ECFDF3`) | Férias gozadas |
| Agendado | **azul** (`#1849A9`, bg `#EFF6FF`) | Período futuro lançado |
| Sem agendamento | âmbar | PA vigente sem lançamento |

**Regra crítica:** Agendado é azul (não verde) para diferenciar de Concluído.

## Filtro "Em férias hoje"

`pasDoAno = c.registros.filter(reg => reg.lancamentos.some(l => HOJE >= l.inicio && HOJE <= l.fim))`

Não filtra por ano — procura qualquer lançamento cujo período engloba o dia de hoje.
Na linha exibe **somente o lancamento ativo** (não todos os lançamentos do PA).

## Pendências conhecidas

- Módulo WhatsApp (link wa.me por colaborador) — dados já no Supabase, falta UI
- Aprovação em lote
