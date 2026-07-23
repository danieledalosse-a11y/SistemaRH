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

| Nível | Condição | Visual |
|---|---|---|
| critico | diasDobra ≤ 30 | fundo vermelho `#D92D20`, texto branco |
| alto | diasDobra ≤ 90 | fundo `#FEF0E6`, borda laranja, texto `#C4500A` |
| atencao | diasDobra ≤ 180 | fundo `#FFFAEB`, texto âmbar `#B54708` |

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

## Pendências conhecidas

- Módulo WhatsApp (link wa.me por colaborador) — dados já no Supabase, falta UI
- Aprovação em lote
- Alinhamento contagem chip "Risco de dobra" vs. barra de resumo
