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
6. **`guardModulo('ferias')` obrigatório** — primeira linha do bloco de auth; ver [[permissoes]].
7. **Componentes compartilhados obrigatórios** — ver seção "Padrão arquitetural" abaixo.

## Padrão arquitetural — componentes compartilhados (set/2026 · atualizado set/2026)

**Princípio:** o que muda entre RH, Gestor e Diretoria é **quem pode ver** e **de onde vêm os dados**. O que é apresentado visualmente deve ser **uma única implementação**.

### Regra de ouro

> Antes de escrever qualquer código de renderização, perguntar: isso já existe em outra visão? Se sim, extrair um helper compartilhado em vez de duplicar.

### Como aplicar

```
1. Cada visão prepara seus próprios dados conforme suas regras, fontes e escopos
2. O helper/renderer compartilhado recebe esses dados prontos e renderiza
3. Nunca o helper conhece a origem dos dados (RH vs Gestor vs Diretoria)
```

**Anti-padrões a evitar:**
- Copiar/colar um bloco de HTML de uma visão para outra com pequenas diferenças
- Criar variáveis locais (`_fmtD`, `avColor`, `barBg`) que duplicam funções globais já existentes
- Aplicar uma regra de negócio visual em uma visão e esquecer de replicar nas outras

### Helpers compartilhados existentes

| Helper | Localização | Usado por |
|---|---|---|
| `_ganttPrepararLancs(c, fonte)` | antes de `_ganttRenderContent` | Timeline RH, Gestor, Diretoria |
| `_ganttRenderContent(...)` | linha ~7580 | `renderTimeline`, `renderGestorGantt`, `renderDirTimeline` |
| `_renderAgendCell(lRef, alertaHtml)` | antes de `_ganttPrepararLancs` | `renderListaAnual` (RH), `renderGestorAtencao` (Gestor) |

### Padrão de integração — exemplo Timeline

```js
// 1. Cada visão prepara os dados no seu próprio formato:
// RH:
const filtrados = COLABORADORES
  .map(c => ({ ...c, __ganttLancs: _ganttPrepararLancs(c, 'rh') }))
  .filter(...);

// Gestor:
const colabs = GESTOR_COLABS
  .map(c => ({ ...c, __ganttLancs: _ganttPrepararLancs(c, 'gestor').filter(...) }))
  .filter(...);

// 2. Ambos chamam o mesmo renderer:
_ganttRenderContent(content, dados, diasNoMes, mesInicio, mesFim, mes, ano);
```

### Padrão de integração — exemplo Agendamentos

```js
// 1. Cada visão calcula lRef e alertaHtml com seus dados:
// RH:   const agendHtml = _renderAgendCell(lRef, alertaDobraHtml);
// Gestor: const agendHtml = _renderAgendCell(lRef, alertaDobraGHtml);

// 2. O helper não sabe de onde veio lRef — só renderiza:
function _renderAgendCell(lRef, alertaHtml) { ... }
```

### Onde adicionar novos helpers

Todos os helpers compartilhados ficam **agrupados antes de `_ganttPrepararLancs`**, que é o marco divisório entre a lógica específica de visão e a camada de renderização compartilhada.

## Fluxo de trabalho padrão

1. Ler o arquivo: `Read modulos/ferias/index.html`
2. Localizar a seção relevante com `Grep`
3. Propor a mudança com mockup visual se houver alteração de UI
4. Implementar apenas após aprovação
5. Verificar no browser preview (`preview_start` com nome `"ferias"` do launch.json)

## Tabelas Supabase (módulo férias)

### `colaboradores`
`id, matricula, nome, cargo, setor, gestor, empresa_registro, empresa_registro_nome, empresa_atuacao, empresa_atuacao_nome, data_demissao, foto_url`
- `ativo = !data_demissao`
- Matrículas repetem entre empresas → identificar por matricula + nome
- `gestor` = **fonte de verdade da equipe no módulo Férias** — valor igual a `param_gestor.apelido || param_gestor.nome`. `_carregarEquipeGestor` filtra por `gestor ilike GESTOR_APELIDO`.
- O campo `gestor` **deve estar no `select=`** da query — também usado pelo filtro secundário `gestorFiltroGestor` dentro da lista carregada

### `ferias`
`id, colaborador_id, matricula_colaborador, ano, pa_inicio, pa_fim, status, dias_antecipados, abono_pecuniario` + colunas de lançamentos + `periodos` JSONB

#### Campo `ano` — convenção e integridade

**Convenção obrigatória:** `ano = Number(pa_fim.slice(0, 4))` — sempre o ano em que o PA termina.  
Ambas as funções de criação (`autocriarPasFaltantes` e `gestorSolicitarNovoPa`) já seguem essa regra.

**Divergência RH × Gestor causada por `ano` errado:**
- `supabaseParaModelo` (RH) renderiza cada row separadamente → dois rows com `ano=2026` aparecem como dois "PA 2026"
- `processGestorFerias` (Gestor) deduplica por `colaborador_id|ano` via `_periodoKeys` → mantém só um
- Resultado: RH mostra duplicata, Gestor esconde o PA real

**Anomalias do import histórico — todas corrigidas em 2026-10-26:**

| id | colab | correção aplicada |
|---|---|---|
| 923 | 1605 | PATCH `ano=2019` (pa_fim=2019-04-16) |
| 924 | 1605 | PATCH `ano=2020` (pa_fim=2020-04-16) |
| 939 | 1608 | PATCH `pa_inicio="2024-02-18"`, `pa_fim="2025-02-17"`, `ano=2025` — datas corretas do PA 2025 |
| 1294 | 1751 | DELETADO (3 dias, errado) + criado id=1915 (PA 2027: 2026-05-05 → 2027-05-04) |

Nota: id=1294 não pôde ser recriado por `autocriarPasFaltantes` porque id=1293 (PA 2026) ainda tem saldo > 0 — o guard da linha ~4071 impede autocriação enquanto houver saldo.

**Correção de vinculação — Luciano (2026-10-26):**
Lançamento (27/01/2027→25/02/2027·30d) estava em PA 2027 (id=1339) mas pertence ao PA 2026 (id=1907). Movido via PATCH no banco:
- id=1339 (PA 2027): `periodos=[]`, campos flat null, `status="Ativo"`
- id=1907 (PA 2026): `periodos=[{id:0, inicio:"2027-01-27", fim:"2027-02-25", dias:30, status:"solicitado"}]`, `periodo1_inicio/fim/dias1` sincronizados, `status="Pendente"` — aguarda aprovação RH
Auditoria registrada em `ferias_historico` para ambos os registros com `acao="correcao_vinculacao"`.

#### Coluna `periodos` JSONB (migration 073, 2026-10-09 — executada em produção)

Fonte de verdade para períodos de férias após 2026-10-09.

```sql
ALTER TABLE ferias ADD COLUMN IF NOT EXISTS periodos JSONB NOT NULL DEFAULT '[]'::jsonb;
CREATE INDEX IF NOT EXISTS idx_ferias_periodos ON ferias USING GIN (periodos);
```

**Estrutura de cada item:**
```json
{ "id": 0, "inicio": "YYYY-MM-DD", "fim": "YYYY-MM-DD", "dias": N, "nota": "...", "status": "aprovado" }
```

**Regras obrigatórias — append-only:**
- `periodos[]` nunca tem itens removidos; exclusão = `status: 'excluido'`; cancelamento = `status: 'cancelado'`
- `id` de cada item é sequencial a partir de 0 e **nunca muda** — `lancIdx` dos acordos de gozo depende disso
- Para `id=0` e `id=1`, os campos flat `periodo1_*/periodo2_*` são mantidos em paralelo (backward compat)
- Registros antigos têm `periodos = []`; fallback: reconstruir de `periodo1_*/periodo2_*` em `supabaseParaModelo` e `processGestorFerias`

**Funções que gravam em `periodos[]`:**

| Função | O que faz |
|---|---|
| `supabaseParaModelo` | Lê `periodos[]`; fallback para campos flat; popula `reg._periodos` |
| `processGestorFerias` | Idem — visão Gestor |
| `confirmarDrawerLancamento` | Append com id sequencial; mantém flat compat p0/p1 |
| `salvarEditLanc` | Atualiza `periodos[id]` pelo campo `id` do item |
| `excluirLancamento` | Marca `status:'excluido'`; recalcula campos flat a partir dos períodos ativos restantes |
| `validarDrawerForm` | Check `maxPeriodosPorPA` |
| `renderDrawerHistorico` | Itera `periodos[]` |
| `aprovarPendente` | Todos os 3 ramos gravam em `periodos[]` |
| `gestorEnviarSolicitacao` | Append com `status:'solicitado'` |
| `gestorCancelarSolicitacao` | Marca `status:'cancelado'` |
| `grhEnviarSolicitarGozo` | Lê períodos disponíveis de `periodos[]` |

**Como fazer PATCH em `periodos[]` (Supabase REST não suporta jsonb_set):**
1. Ler array atual: `sbGet('ferias', 'id=eq.{id}&select=periodos')`
2. Modificar o array em JS
3. PATCH com o array inteiro: `{ periodos: [...] }`

**Bug corrigido (commit 2745d68):** `confirmarDrawerLancamento` tinha lógica `length===0 ? p1 : p2` que sobrescrevia o 2º período ao lançar o 3º. Substituído por append-only. Casos de perda confirmados: Victor Hugo (mat.402) e Valdir Felix (mat.439) — períodos não recuperáveis do sistema.

**Ordenação cronológica dos lançamentos — RH e Gestor (commits f3a81e9 / e28c890, 26/10/2026):**

Na **visão RH**, o array `lancamentos` é ordenado por `inicio` crescente logo após ser construído em `supabaseParaModelo` (~linha 2625):
```js
lancamentos.sort((a, b) => (a.inicio || '').localeCompare(b.inicio || ''));
```
Isso garante que a aba "Períodos" do drawer RH exiba os lançamentos de cada PA do mais antigo para o mais recente, independente da ordem em que estão no JSONB ou nos campos flat.

Na **visão Gestor** (drawer `gestorAbrirSolicitacoes`), dois sorts foram adicionados:
- Lançamentos dentro de cada bloco PA: `(a.inicio||'').localeCompare(b.inicio||'')` (ascending)
- Blocos de PA: ordenados por `pa_fim || pa_inicio` ascending (mais antigo primeiro)

**Regra obrigatória:** a ordenação cronológica deve existir **na fonte** (ao construir o array), não na renderização. A visão RH usa `r.lancamentos` diretamente no `.map()` sem sort adicional — qualquer novo ponto de renderização que itere `r.lancamentos` herda a ordem correta.

**Bug corrigido (commit 37174d8):** `processGestorFerias` não filtrava períodos com `status: "excluido"` ao iterar `periodos[]`, diferente da visão RH que os filtra em `supabaseParaModelo`. Lançamentos excluídos chegavam em `GESTOR_LANCAMENTOS` e apareciam no drawer do Gestor com label "Concluído" (pois `passado = true` e status não era `solicitado`/`cancelado`). Correção: uma linha — `if (_stNormP === 'excluido') return` após o normalizador, espelhando a regra do RH. `gestorSaldoPeriodo` já filtrava corretamente (`['aprovado','agendado','gozado']`), então o saldo calculado estava certo; o problema era apenas visual. Regra de ouro: o filtro de excluido deve existir **no ponto de construção do lançamento** em cada visão, não só no cálculo do saldo.

**Bug corrigido (commit 4db6fe5):** `excluirLancamento` mapeava `periodos[].id` diretamente ao slot flat (id=0 → `periodo1_*`, id=1 → `periodo2_*`). Quando o id interno não correspondia ao slot real dos dados (ex: o único lançamento ativo estava em `periodo2_*`), os campos flat errados ficavam preenchidos, causando divergência entre visão RH (lê `periodos[]`) e Gestor (lê flat fields). **Correção:** após marcar o período como `excluido`, recalcular os campos flat filtrando os períodos ainda ativos (`status` não in `['excluido','recusado','cancelado']`) e mapeando posicionalmente: ativo[0] → `periodo1_*`, ativo[1] → `periodo2_*`, restante → null.

### `ferias_historico` (criada 2026-09-14, expandida 2026-10-09)

Tabela de auditoria imutável — nunca editada, só recebe INSERT.

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | bigserial PK | auto |
| `ferias_id` | bigint | FK para `ferias.id` |
| `colaborador_id` | bigint | FK para `colaboradores.id` |
| `acao` | text | ver tabela abaixo |
| `usuario` | text | Nome/email de quem executou a ação |
| `detalhe` | jsonb | Snapshot do evento |
| `criado_em` | timestamptz | Gerado pelo banco (`DEFAULT NOW()`) |

**Ações registradas:**

| `acao` | Origem | Detalhe |
|---|---|---|
| `'solicitado'` | Gestor (autoatendimento) | `{ inicio, fim, dias, slot }` |
| `'aprovado'` | RH (`aprovarPendente` fluxo padrão — commit `177d847`, 26/10/2026) | `{ inicio, fim, dias, aprovado_por }` |
| `'rejeitado'` | RH | `{ status, obs_gestor }` |
| `'gozo_solicitado'` | Gestor | `{ saida, retorno, dias, lancIdx }` |
| `'gozo_aprovado'` | RH | `{ saida, dias, lancIdx }` |
| `'lancado_rh'` | RH drawer (commit ea7c99e) | `{ inicio, fim, dias, id_periodo, nota }` |
| `'editado_rh'` | RH drawer (commit ea7c99e) | `{ id_periodo, inicio_anterior, fim_anterior, inicio_novo, fim_novo, dias_novo }` |
| `'excluido_rh'` | RH drawer (commit ea7c99e) | `{ id_periodo, inicio, fim, dias }` |
| `'alteracao_solicitada'` | Gestor | `{ inicio, fim, dias, slot }` |
| `'cancelamento_solicitado'` | Gestor | `{ inicio, fim, dias }` |
| `'alteracao_aprovada'` | RH | `{ status: 'Alteração aprovada' }` |
| `'alteracao_recusada'` | RH | `{ status: 'Alteração recusada' }` |
| `'cancelamento_aprovado'` | RH | `{ status: 'Cancelamento aprovado' }` |
| `'cancelamento_recusado'` | RH | `{ status: 'Cancelamento recusado' }` |
| `'gestor_ciente'` | Gestor (commit 993c54f) | `{ acao_referencia, inicio, fim, dias }` |

As ações `lancado_rh`, `editado_rh` e `excluido_rh` usam `sbPost('ferias_historico', ...).catch(() => {})` diretamente (não passam por `_logAtiv`) — falha no log nunca bloqueia a operação principal.

Índices: `ferias_id`, `colaborador_id`, `criado_em DESC`.

## Cálculo de saldo

```js
calcSaldo(reg) = reg.totalDias - usado - reg.diasAntecipados - reg.abonoPecuniario
```

`diasAntecipados`: fica no PA **de onde os dias foram retirados** (ano seguinte ao das coletivas).

### `dias_antecipados` — marcador provisório vs. período registrado

`dias_antecipados > 0` é um marcador **provisório** — usado enquanto os dias emprestados ainda não estão registrados como um período concreto no PA. Quando o período é criado corretamente, o campo deve ser zerado para evitar dupla dedução no saldo.

**Regra obrigatória:** ao criar `periodo1` para os dias antecipados, sempre zerar `dias_antecipados = 0` no mesmo registro.

**Padrão correto (coletivas dez/2025–jan/2026, 2d antecipados do PA 2026):**
```python
# Atualizar a row do PA 2026 do colaborador
sb.table('ferias').update({
    'periodo1_inicio': '2026-01-03',
    'periodo1_fim':    '2026-01-05',
    'dias1':           2,
    'nota1':           'usou 2 dias desse saldo para emendar nas coletivas',
    'dias_antecipados': 0,  # ← obrigatório: zerar para não subtrair duas vezes
}).eq('id', ferias_id).execute()
```

**Referência:** VALDIR FELIX DA CRUZ (mat. 439) — PA 2026 id=1699 com `dias_antecipados=0` e `periodo1=2026-01-03`.

**Colaboradores já padronizados (set/2026):** mat. 104, 108, 110, 124, 125, 126, 133, 216, 3, 403 (Alisson), 463, 465, 466 — todos com `periodo1=Jan 3-5 2026, dias1=2, dias_antecipados=0`.

**Casos pendentes de análise manual:**
- Everton Sales (113): `antec=16` usado para registrar dias **perdidos por INSS** — significado diferente, não tocar
- Geovani Barnabe (132): `p1=30d` quando saldo seria 28d — inconsistência a resolver manualmente
- Ana Carla Kojo (132): p1+p2 já totalizam 28d — antecipados implícitos no saldo
- Fabio Segantini (403): dois PAs com `antec=2` em situação complexa
- Gabriela Scoqui (574): nota1 já documenta os 2d ("usou 2 dias desse saldo para emendar nas coletivas")
- Mateus Fossa (577): `dias1=16` sem data (período suspenso por Flavio) — alterar sobrescreveria essa info

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

## Coluna Agendamentos — `_renderAgendCell` (set/2026)

Helper compartilhado por RH, Gestor e Diretoria. Cada visão calcula `lRef` e `alertaHtml` conforme suas próprias regras e fontes de dados — o helper apenas renderiza a célula de forma consistente.

```js
function _renderAgendCell(lRef, alertaHtml) {
  if (!lRef) return `<span style="font-size:11px;color:var(--text-ter);">—</span>`;
  return `<span style="font-size:11px;white-space:nowrap;">${formatDate(lRef.inicio)} → ${formatDate(lRef.fim)} · ${lRef.dias}d</span>
          ${alertaHtml || ''}`;
}
```

**Padrão visual:** `DD/MM/AAAA → DD/MM/AAAA · Nd` + alerta de dobra quando aplicável. **Sem `+N período`** — demais períodos ficam acessíveis no drawer.

**Uso em cada visão:**
- RH (`renderListaAnual`): `_renderAgendCell(lRef, alertaDobraHtml)`
- Gestor (`renderGestorAtencao`): `_renderAgendCell(lRef, alertaDobraGHtml)`

`lRef` tem a mesma estrutura em todas as visões: `{ inicio, fim, dias }` em formato `YYYY-MM-DD`.

**Nunca usar `_fmtD` local** para formatar datas nessa célula — usar sempre `formatDate()` (função global), que é idêntica mas não gera duplicidade.

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
| Concluído | verde (`#027A48`, bg `#ECFDF3`) | Saldo zerado E todos os lançamentos no passado |
| Agendado | **azul** (`#1849A9`, bg `#EFF6FF`) | Período futuro lançado (saldo > 0 ou saldo = 0 com futuro) |
| Sem agendamento | âmbar | PA com saldo sem nenhum lançamento futuro ativo |

**Regra crítica:** Agendado é azul (não verde) para diferenciar de Concluído.

### Prioridade do `paBadge` (visão RH lista)

```js
1. Pendente de aprovação RH → "Aguardando aprovação" (prioridade máxima)
2. Risco de dobra (saldo > 0 + dpd ≤ 180) → badge de risco (Crítico/Atenção/No radar)
3. saldo <= 0 + reg.lancamentos.some(l => l.inicio >= HOJE) → "Agendado"
   // (saldo zerado mas com lançamentos futuros — ainda não gozados)
4. saldo <= 0 sem lançamento futuro → "Concluído"
5. !_temFuturoAtivo(colab) → "Sem agendamento"
6. fallthrough → "Agendado"
```

**Regra 3 — Alessandro case:** quando todos os dias do PA estão programados para o futuro, o saldo é 0 mas as férias não foram gozadas. Checar `reg.lancamentos` (não cross-PA) porque `saldo <= 0` significa que o `reg` é o próprio PA responsável pelos dias.

### `_temFuturoAtivo(colab)` — helper cross-PA

```js
function _temFuturoAtivo(colab) {
  const _excl = new Set(['Cancelado', 'Descartado', 'Rejeitado']);
  return colab.registros.some(r =>
    !_excl.has(r.status) &&
    r.lancamentos.some(l => l.inicio && l.inicio >= HOJE)
  );
}
```

Varre **todos os PAs** do colaborador (não apenas `reg`). Usado em `isSemAgendado` e `paBadge` (condição 5) para detectar agendamentos futuros em PAs que não são o PA de referência da linha.

## Filtro "Em férias hoje"

`pasDoAno = c.registros.filter(reg => reg.lancamentos.some(l => HOJE >= l.inicio && HOJE <= l.fim))`

Não filtra por ano — procura qualquer lançamento cujo período engloba o dia de hoje.
Na linha exibe **somente o lancamento ativo** (não todos os lançamentos do PA).

## Visão Gestor — arquitetura de dados

A visão Gestor usa arrays **separados** (não a estrutura `COLABORADORES[].registros[].lancamentos[]` da visão RH):

| Variável global | Conteúdo |
|---|---|
| `GESTOR_COLABS` | colaboradores do gestor logado |
| `GESTOR_PERIODOS` | todos os PAs dos colaboradores |
| `GESTOR_LANCAMENTOS` | todos os lançamentos, campo `inicio`/`fim` (NÃO `data_inicio`/`data_fim`) |

`processGestorFerias(rows)` — constrói GESTOR_PERIODOS e GESTOR_LANCAMENTOS a partir das rows do Supabase. Lançamentos gerados usam `inicio`/`fim` (consistente com as rows da tabela `ferias`).

**Nunca usar `data_inicio` ou `data_fim` em GESTOR_LANCAMENTOS** — esses campos não existem nos objetos gerados por `processGestorFerias`. Qualquer ordenação ou comparação de datas de lançamento usa `l.inicio` e `l.fim`.

**Campo `ano` em GESTOR_PERIODOS (crítico — corrigido 2026-09-10):**
O objeto `periodo` em `processGestorFerias` inclui explicitamente `ano: row.ano`. **Nunca usar `pa.pa_inicio?.slice(0,4)` para derivar o ano do PA** — colaboradores com aniversário no 2º semestre têm `pa_inicio` no ano anterior ao PA real (ex: PA 2027 começa em set/2026 → slice retorna "2026", errado). Usar sempre `pa.ano` diretamente.

**Busca gestor (`gestorBusca`) — comportamento correto (corrigido 2026-09-10):**
`gestorBuscaSelecionar(colabId)` apenas fecha o dropdown e abre o drawer — **não limpa o input**. O texto digitado permanece no campo após fechar o drawer, permitindo nova seleção sem redigitar. O botão ✕ (`gestorBuscaLimpar`) é o único que deve limpar o campo.

**Situação no export gestor — critério correto (corrigido 2026-09-10):**
Usa `!lRef` (não `!lancs.length`) para determinar "Sem agendamento". `lRef = ativo || futuro` — só há agendamento se existir lançamento ativo hoje ou futuro. Lançamentos concluídos no passado **não** contam como "Agendado".

**Coluna Agendamentos — `lRef` sem fallback para passado (corrigido 2026-09-11):**
Tanto na visão RH quanto no Gestor, `lRef = ativo || futuro` — **sem `|| passado`**. Lançamentos já concluídos (`fim < hoje`) não devem aparecer na coluna Agendamentos mesmo que pertençam ao PA vigente com saldo pendente. A coluna exibe `—` nesses casos. O fallback `|| passado` existia em ambas as funções de render e foi removido das duas.

**Exportação gestor — PDF (8 colunas) e Excel (9 colunas):**
- **PDF:** Nome | Cargo | Ano PA | Período Aquisitivo | Férias Início | Férias Fim | Saldo | Situação
- **Excel:** **Setor** | Nome | Cargo | Ano PA | Período Aquisitivo | Férias Início | Férias Fim | Saldo | Situação

- Separador de setor no PDF usa `colspan="8"` — atualizar se adicionar/remover colunas do PDF
- Período Aquisitivo para `semPA` (sem PA no banco): exibir datas calculadas `_fmtData(data_admissao) → _fmtData(addDays(data_admissao, 364)) (prev.)`. Nunca mostrar apenas "Previsto".
- Ano PA para `semPA`: `fimPrev.slice(0,4)` (ano em que o PA termina). **Nunca** `fimPrev.year - 1`.
- Férias Início/Fim: campos `agendIni` e `agendFim` no objeto `linhas` — `_fmtData(lRef.inicio)` e `_fmtData(lRef.fim)`, ou `'—'` quando sem lançamento.
- **Situação com data da dobra:** níveis de risco exibem texto completo `"Nível · Dobra em DD/MM/AAAA"` (campo `situacao`). Campo `sitKey` guarda apenas o nível ("Crítico"/"Atenção"/"No radar") para lookup de cor em `_sitBadge(sitKey, situacao)` e `_sitXls(sitKey)`.
- **Cores dos níveis de risco (PDF e Excel):**

| Nível | Fundo | Texto |
|---|---|---|
| Crítico | `#FEE2E2` | `#7F1D1D` |
| Atenção | `#FDE68A` | `#78350F` |
| No radar | `#DBEAFE` | `#1E3A8A` |

- **Excel — cor por situação nas colunas Nome e Saldo:** fundo `sit.bg` e texto `sit.text` (da `_sitXls`) aplicados ao Nome (bold) e ao Saldo. Coluna Período Aquisitivo mantém cor do setor (`_corSetor`) para identificar o grupo visual.
- **Excel — AutoFilter + Freeze:** gerado via **ExcelJS 4.4.0** (lazy-load de `cdn.jsdelivr.net/npm/exceljs@4.4.0/dist/exceljs.min.js`). AutoFilter: `ws.autoFilter = { from:{row:3,column:1}, to:{row:3,column:9} }`. Freeze: `ws.views = [{state:'frozen', ySplit:3, topLeftCell:'A4'}]`. Gera `.xlsx` real (não HTML disfarçado).
- **Excel — helper `argb(hex)`:** converte cor hex para formato ARGB do ExcelJS. **Obrigatório expandir shorthand:** `#000` → `FF000000`, `#fff` → `FFFFFFFF`. Fórmula: `const h = hex.replace('#',''); const full = h.length===3 ? h.split('').map(c=>c+c).join('') : h; return 'FF'+full.toUpperCase()`. Sem essa expansão, `#000` vira `FF000` (5 chars, inválido) e o ExcelJS ignora a cor.
- **Excel — identidade visual igual ao PDF:** cabeçalho `#1E3A5F` branco bold; cores de risco por linha (rowBg + borda esquerda `style:'medium'` na col A); nome com cor+peso do risco; setor com cor do `_corSetor`; saldo colorido por valor; situação bold colorida por status.

### Campo `nota` em GESTOR_LANCAMENTOS (crítico — corrigido 2026-08-25)

Cada objeto em `GESTOR_LANCAMENTOS` carrega o campo `nota` mapeado diretamente de `nota1`/`nota2` da tabela `ferias`:

```js
// p1
{ ..., _obsGestor: row.obs_gestor||null, nota: row.nota1||null }
// p2
{ ..., _obsGestor: row.obs_gestor||null, nota: row.nota2||null }
```

**Por quê:** `obs_gestor` e `nota1`/`nota2` são colunas **distintas** no Supabase. A visão RH exibe `l.nota` (vinda de `nota1`); antes da correção, a visão Gestor lia `obs_gestor` (campo diferente), causando divergência. Nunca confundir os dois campos.

## Visão Gestor — funções canônicas

```js
// Retorna o PA mais antigo com saldo > 0 e não expirado
gestorPeriodoAtivo(colaborador_id)

// True se colaborador tem lançamento aprovado/agendado/gozado com fim >= hoje
gestorIsAgendado(colabId)
// Nota: inclui status 'gozado' com fim >= hoje (colaborador em férias agora, gozo já registrado)

// Dias até o prazo de dobra do PA
gestorDpd(pa)

// Saldo restante do PA (dias_direito - usados - abono - dias_antecipados)
// CRÍTICO: deve subtrair dias_antecipados — correto como na visão RH (corrigido 2026-09-11)
// CRÍTICO: excluir realizações do cálculo — só lançamentos p1/p2 afetam saldo (corrigido 2026-09-28)
gestorSaldoPeriodo(pa)
// Implementação correta:
// const direito     = Number(periodo.dias_direito) || 30;
// const abono       = Number(periodo._feriasRow?.abono_pecuniario) || 0;
// const antecipados = Number(periodo._feriasRow?.dias_antecipados) || 0;
// const usados      = GESTOR_LANCAMENTOS
//   .filter(l => String(l.periodo_id) === String(periodo.id)
//             && !l._isRealizacao                              // ← obrigatório
//             && ['aprovado','agendado','gozado'].includes((l.status||'').toLowerCase()))
//   .reduce((s, l) => s + (Number(l.dias) || 0), 0);
// return direito - usados - abono - antecipados;
//
// Por quê: processGestorFerias adiciona realizações em GESTOR_LANCAMENTOS com _isRealizacao:true.
// Somar realizações ao saldo causava saldo negativo — realizações são gozo físico, não dedução
// de direito. A regra espelha calcSaldo() da visão RH, que nunca lê realizacoes no saldo.
```

## Visão Gestor — cards do drawer (PA Vigente · Saldo · Vencimento)

Regra obrigatória (corrigida em 2026-10-26, commits `ee8a406` e `bede823`):

> **Os três cards representam o mesmo PA — o mais antigo que ainda precisa de ação.**

### Variáveis em `gestorAbrirSolicitacoes`

```js
const pa    = gestorPeriodoAtivo(c.id);   // PA mais antigo com saldo > 0
const paVig = gestorPeriodoVigente(c.id); // PA vigente por data (pa_inicio ≤ hoje ≤ data_fim_gozo)
const _paBase = pa || paVig;              // fallback: quando saldo=0, usa PA vigente por data

const saldo = _paBase ? gestorSaldoPeriodo(_paBase) : 0;
const total = _paBase ? (Number(_paBase.dias_direito) || 30) : 30;
const venc  = _paBase?.data_fim_gozo ? gestorFmtData(_paBase.data_fim_gozo) : '—';
const paAno = _paBase?.pa_fim ? _paBase.pa_fim.slice(0,4) : (_paBase?.pa_inicio ? _paBase.pa_inicio.slice(0,4) : '—');
```

**Todos os três — `saldo`, `venc`, `paAno` — usam `_paBase`, nunca `pa` ou `paVig` sozinhos.**

### Comportamento esperado

| Situação | `pa` | `_paBase` | Cards |
|---|---|---|---|
| PA 2026 pendente (solicitado, saldo 30d) | PA 2026 | PA 2026 | PA Vigente=2026, Saldo=30d, Venc=dobra do PA 2026 |
| RH aprova PA 2026 → saldo zera | PA 2027 | PA 2027 | PA Vigente=2027, Saldo=30d, Venc=dobra do PA 2027 |
| Saldo zero (ex: Gisele) | null | paVig | Todos os cards mostram PA vigente por data |

### Vencimento = data de dobra

`venc = _paBase.data_fim_gozo` = `_addOneYear(pa_fim)` = pa_fim + 1 ano (prazo legal antes de pagamento em dobro). **Não é a data fim do PA.**

### `gestorPeriodoAtivo` — definição

```js
function gestorPeriodoAtivo(colaborador_id) {
  // Retorna o PA mais antigo com saldo > 0 e não expirado
  // Fallback: expirado mas com saldo (dobra ocorrida)
  // Null: todos os PAs concluídos
}
```

`gestorSaldoPeriodo` conta apenas lançamentos com status `['aprovado','agendado','gozado']` — lançamentos `solicitado` (pendentes) **não** reduzem o saldo.

### Anti-padrão crítico

```js
// ERRADO — venc e paAno usam fontes diferentes, causando incoerência:
const venc  = paVig?.data_fim_gozo ? gestorFmtData(paVig.data_fim_gozo) : '—'; // ← usa paVig
const paAno = pa?.pa_fim ? pa.pa_fim.slice(0,4) : '—';                          // ← usa pa

// CORRETO — mesma fonte para os três:
const venc  = _paBase?.data_fim_gozo ? gestorFmtData(_paBase.data_fim_gozo) : '—';
const paAno = _paBase?.pa_fim ? _paBase.pa_fim.slice(0,4) : (_paBase?.pa_inicio ? _paBase.pa_inicio.slice(0,4) : '—');
```

## Visão Gestor — filtro KPI ativo

`_gestorAlertaAtivo` — variável de módulo: `null` | `'agendado'` | `'dobra'` | `'sem-agendado'` | `'saindo'` | `'aguard'`

`filtrarGestorAlerta(tipo)` — toggle: mesmo tipo limpa o filtro. Cards KPI exibem classe `pa-active` quando ativos. O subtítulo da lista exibe botão "× Limpar filtro" quando há filtro ativo.

**Regra do renderer de linha:** `if (!pa && !semPA && !_gestorAlertaAtivo) return ''` — colaboradores com todos os PAs concluídos só aparecem quando um filtro KPI está ativo.

**Definição de `semPA`:** `!pa && !!c.data_admissao` — qualquer colaborador sem PA ativo com saldo, incluindo quem tem PAs históricos já gozados mas ainda não tem novo PA criado. **Não** usar `!temPeriodos` como condição — isso ocultaria colaboradores que gozaram o último PA mas o novo ainda não foi lançado no banco.

**Coluna PA Vigente:** prioridade de exibição:
1. `paEfetivo` encontrado → mostra o ano real (`paEfetivo.pa_fim.slice(0,4)`)
2. `semPA` sem paEfetivo → mostra "XXXX Previsto" (baseado no `pa_fim` do último PA histórico + 1 dia)
3. Nenhum → `—`

**Coluna Agendamentos:** mostra apenas lançamentos do `paEfetivo` (`lancsPa`), não de PAs históricos. Colaborador com PA 2027 e lançamento apenas no PA 2026 encerrado mostra `—` na coluna, não o lançamento antigo. Além disso, `lRef = ativo || futuro` (sem `|| passado`) — lançamentos passados do próprio PA também não aparecem.

## Visão Gestor — paEfetivo (padrão crítico)

O `paEfetivo` define qual PA é a referência da linha inteira (PA exibido, agendamento, saldo, badge). Regra: **PA com lançamento futuro ativo tem prioridade**; sem ele, usa `gestorPeriodoAtivo`.

```js
const _lancRelev = GESTOR_LANCAMENTOS.find(l =>
  String(l.colaborador_id) === String(c.id) &&
  ['aprovado','agendado','gozado'].includes((l.status||'').toLowerCase()) &&
  (l.fim||'') >= hoje
  // Cancelado/Descartado/Rejeitado excluídos implicitamente — não estão na lista acima
);
const _paRelev = _lancRelev
  ? GESTOR_PERIODOS.find(p => String(p.id) === String(_lancRelev.periodo_id))
  : null;

// Mesma regra da visão RH (_comFuturo): PA com lançamento futuro ativo tem prioridade
const paEfetivo = _paRelev || pa;
```

Todos os cálculos de exibição (dpd, saldo, total, pct, cores, badge, paAno) usam `paEfetivo`.
**Botão "Solicitar"** continua usando `pa` (gestorPeriodoAtivo) — é onde novas solicitações são feitas.

**Regra unificada (set/2026):** a lógica é idêntica nas três funções de render:
- `renderListaAnual` → `_comFuturo` (prioridade 0 no array `pasDoAno`)
- `renderMinhaEquipe` → `_cfR` (filtro nos registros válidos do colaborador)
- `renderGestorAtencao` → `_paRelev || pa` (sobre GESTOR_LANCAMENTOS / GESTOR_PERIODOS)

Lançamentos Cancelado/Descartado/Rejeitado **não** influenciam `paEfetivo` em nenhuma das três visões.

## Visão Gestor — badge de saldo zerado

Quando `saldo <= 0`, verificar se há lançamento futuro aprovado antes de exibir "Concluído":

```js
const _temFutAprov = lancs.some(l =>
  ['aprovado','agendado','gozado'].includes((l.status||'').toLowerCase()) &&
  (l.fim||'') >= hoje
);
badge = _temFutAprov ? 'Agendado' : 'Concluído';
```

## Tabela `ferias` — colunas que NÃO existem

**`dias_direito` não existe** na tabela `ferias` do Supabase. Nunca incluir esse campo em POST/PATCH para essa tabela. O valor padrão 30 é aplicado apenas nos objetos JS locais via `|| 30`.

O objeto `periodo` em `GESTOR_PERIODOS` tem `dias_direito: 30` hardcoded no JS (em `processGestorFerias`), mas esse campo não vai para o banco.

## Renovação automática de JWT (módulo cadastro)

`_sbRefreshSession()` em `modulos/cadastro/index.html` — ao detectar `JWT expired` em `sbPatch` ou `sbGet`, tenta renovar usando `refresh_token` do localStorage e refaz a chamada original. Se o refresh falhar, lança o erro normalmente.

## Múltiplas solicitações por PA — Gestor (commit 16de87c · 2026-10-26)

### Regra atual (após correção)

O Gestor pode fazer mais de uma solicitação dentro do mesmo PA, mesmo que a anterior ainda esteja aguardando aprovação do RH. O sistema bloqueia apenas quando os dias somados ultrapassam o saldo disponível.

### Implementação

**Saldo disponível para o Gestor** = `gestorSaldoPeriodo(periodo)` − dias pendentes (status `solicitado`):

```js
// Modal (gestorAbrirModal) e envio (gestorEnviarSolicitacao) — cálculo independente em cada ponto
const _diasSolPend = GESTOR_LANCAMENTOS
  .filter(l => String(l.periodo_id) === String(periodo.id) && (l.status||'').toLowerCase() === 'solicitado')
  .reduce((s, l) => s + (Number(l.dias) || 0), 0);
const saldoDisp = Math.max(0, saldo - _diasSolPend);
```

**No modal:** exibe `"X dias (Yd aguardando aprovação)"` quando há pendentes; limita `mgDias.max` ao `saldoDisp`.

**No envio:** erro detalhado quando `diasVal > saldoDispEnvio`:
`"Dias ultrapassam o saldo disponível. Saldo: Xd, sendo Yd já solicitados (aguardando aprovação). Disponível: Zd."`

**`gestorSaldoPeriodo`** conta apenas `['aprovado','agendado','gozado']` — `solicitado` nunca entra no saldo base, por isso a subtração de `_diasSolPend` é necessária e não duplica.

### Comportamento pós-aprovação/reprovação RH

- **Aprovação** (`solicitado → aprovado`): dias migram para `gestorSaldoPeriodo`; `_diasSolPend` zera. Saldo correto.
- **Reprovação** (`solicitado → recusado`): nenhuma das duas contagens inclui `recusado`. Saldo integralmente restaurado.
- Ambos dependem de recarregamento de `GESTOR_LANCAMENTOS` (reload da página) — comportamento preexistente.

### O que foi removido

Bloco `jaSolicitado` que impedia qualquer segunda solicitação enquanto havia uma `solicitado` no mesmo PA. Era independente do saldo e bloqueava casos legítimos.

### Validações que permanecem intactas

1. Data de início antes de hoje → bloqueado
2. Consistência `ano` vs. `pa_fim` → bloqueado
3. Data fora do período de concessão (`pa_inicio` … `pa_fim + 366d`) → bloqueado
4. Datas iguais a lançamento já recusado → bloqueado

---

## Validações no fluxo do Gestor (commit 22a1af1 · 2026-10-26)

Aplicadas em `gestorEnviarSolicitacao` e `gestorEnviarAlteracao` (`_modoSolicitado` branch):

### 1. Consistência do campo `ano` vs. `pa_fim`

```js
const _anoEsperado = Number((_fRow.pa_fim || '').slice(0, 4));
const _anoRegistro = Number(_fRow.ano);
if (_anoEsperado && _anoRegistro && _anoEsperado !== _anoRegistro) {
  erroEl.textContent = 'Este registro possui inconsistência de dados (ano ≠ pa_fim). Contate o RH.';
  return;
}
```

Bloqueia solicitação quando `ferias.ano` difere do ano de `pa_fim`. Esse estado indica import incorreto — o RH precisa corrigir antes.

### 2. Data de início dentro do período de concessão

```js
const _fimConcessao = addDays(_fRow.pa_fim, 366); // pa_fim + 366 dias
if (inicio < _fRow.pa_inicio || inicio > _fimConcessao) {
  erroEl.textContent = `A data de início deve estar entre ${formatDate(_fRow.pa_inicio)} e ${formatDate(_fimConcessao)} (período de concessão).`;
  return;
}
```

O período de concessão vai de `pa_inicio` até `pa_fim + 366 dias`. Bloqueia datas fora desse range.

**Ordem das validações em `gestorEnviarSolicitacao`:** (1) data no passado → (2) consistência ano/pa_fim → (3) data fora da concessão. A validação de data passada já existia; as novas vieram depois.

## Cancelamento de lançamento pelo Gestor — regra crítica

`gestorCancelarSolicitacao` deve limpar **apenas o slot** (p1 ou p2), nunca marcar o PA inteiro como 'Cancelado'.

```js
const slot = String(lancId).endsWith('-p2') ? 'p2' : 'p1';
const clearSlot = slot === 'p1'
  ? { periodo1_inicio: null, periodo1_fim: null, dias1: 0, motivo1: null, nota1: null }
  : { periodo2_inicio: null, periodo2_fim: null, dias2: 0, motivo2: null, nota2: null };
// novoStatus = 'Aprovado' (mantém PA aberto para nova solicitação)
await sbPatch('ferias', `id=eq.${feriasId}`, { ...clearSlot, status: 'Aprovado', obs_gestor: motivo });
```

**Por quê:** cancelar o PA inteiro faz o sistema criar nova row com datas erradas (usa `data_admissao` em vez do aniversário correto) no próximo `gestorSolicitarNovoPa`.

## Identificação de equipe do gestor — arquitetura (set/2026)

**Regra definitiva:** a equipe de um gestor é determinada pelo campo `colaboradores.gestor`, que armazena exatamente `param_gestor.apelido || param_gestor.nome`. A query usa `ilike` para match case-insensitive sem wildcards.

```
usuarios_perfil.colaborador_id
  → param_gestor.id + param_gestor.apelido (= GESTOR_APELIDO)
  → colaboradores.gestor ilike GESTOR_APELIDO + data_demissao IS NULL
```

**`param_gestor_setor` NÃO é removida** — continua usada em Parâmetros Gerais para outras finalidades, mas **não é mais usada em `_carregarEquipeGestor`** no módulo Férias.

### `_carregarEquipeGestor(gestor_id)`

```js
async function _carregarEquipeGestor(gestor_id, cfg = {}) {
  const _colSelect = 'select=id,nome,cargo,setor,data_admissao,gestor,empresa_registro_nome,foto_url,tipo_vinculo,empresa_atuacao';
  const _isCLT = c => (c.tipo_vinculo || 'clt').toLowerCase() === 'clt';
  let _baseColabs;
  if (gestor_id) {
    const apelido = encodeURIComponent(GESTOR_APELIDO);
    _baseColabs = (await sbGet('colaboradores', `gestor=ilike.${apelido}&data_demissao=is.null&${_colSelect}&order=nome`))
      .filter(_isCLT);
  } else {
    GESTOR_APELIDO = null;
    _baseColabs = (await sbGet('colaboradores', `ativo=eq.true&${_colSelect}&order=nome`)).filter(_isCLT);
  }
  // Escopo adicional de param_escopo_ferias (ver seção abaixo)
}
```

**Equipe base:** colaboradores CLT onde `colaboradores.gestor ilike GESTOR_APELIDO` + `data_demissao IS NULL`.

**Escopo adicional:** após a equipe base, carrega `param_escopo_ferias` para o `gestor_id` e expande com colaboradores de outros gestores, setores ou empresas (ver seção `param_escopo_ferias`).

### `initGestor()` — fluxo do gestor puro

```js
// Lê apelido || nome — é exatamente o valor armazenado em colaboradores.gestor
const pgRows = await sbGet('param_gestor', `colaborador_id=eq.${colaborador_id}&select=id,nome,apelido&limit=1`);
GESTOR_APELIDO = pgRows[0].apelido || pgRows[0].nome || '';
await _carregarEquipeGestor(pgRows[0].id);
```

Quando o RH seleciona um gestor no dropdown, o mesmo padrão é aplicado:
```js
const pgRow = await sbGet('param_gestor', `id=eq.${gestor_id}&select=nome,apelido&limit=1`);
GESTOR_APELIDO = pgRow[0]?.apelido || pgRow[0]?.nome || '';
```

### `GESTOR_APELIDO` — papel atual

Variável string. Armazena `param_gestor.apelido || param_gestor.nome` — exatamente o valor em `colaboradores.gestor`. Usos:
- **Query de equipe:** `colaboradores.gestor ilike GESTOR_APELIDO` (fonte de verdade da equipe)
- **Flag de vista restrita:** Truthy = gestor puro (filtro `gestorFiltroGestor` fica oculto). Null = RH/admin (filtro visível)

### Filtro dropdown de gestores (`gestorFiltroGestor`)

Filtro **secundário dentro da lista já carregada**. Popula de `param_gestor` (campo `apelido`) para evitar duplicatas por capitalização:

```js
// Dentro de renderGestorAtencao (NÃO async) — usar .then(), nunca await
sbGet('param_gestor', 'select=apelido&ativo=eq.true&order=ordem').then(pgRows => {
  const gestores = pgRows.map(r => r.apelido).filter(Boolean);
  gestores.forEach(g => { const o = document.createElement('option'); o.value = g; o.textContent = g; gestorSel.appendChild(o); });
}).catch(() => { /* fallback: distinct de colaboradores */ });
```

O filtro compara `c.gestor` contra o apelido selecionado — filtro visual auxiliar, a fonte de verdade da equipe é `colaboradores.gestor`.

## `param_escopo_ferias` — escopo adicional de gestão

Tabela que expande a equipe visível de um gestor além da sua equipe direta (`colaboradores.gestor`). Cada linha adiciona um grupo de colaboradores ao escopo de um gestor no módulo Férias.

### Estrutura da tabela

```sql
CREATE TABLE param_escopo_ferias (
  id           uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  gestor_id    integer NOT NULL REFERENCES param_gestor(id) ON DELETE CASCADE,
  tipo         text    NOT NULL CHECK (tipo IN ('empresa_atuacao', 'setor', 'todos', 'gestor')),
  valor        text,             -- nome da empresa ou setor (NULL quando tipo = 'todos' ou 'gestor')
  gestor_ref_id integer REFERENCES param_gestor(id) ON DELETE RESTRICT, -- FK quando tipo = 'gestor'
  ativo        boolean NOT NULL DEFAULT true,
  criado_em    timestamptz NOT NULL DEFAULT now(),
  criado_por   text
);
```

### Tipos de escopo

| `tipo` | `valor` | `gestor_ref_id` | Colaboradores adicionados |
|---|---|---|---|
| `'empresa_atuacao'` | nome da empresa | NULL | Todos os CLT da empresa |
| `'setor'` | nome do setor | NULL | Todos os CLT do setor |
| `'todos'` | NULL | NULL | Todos os CLT ativos |
| `'gestor'` | NULL | id do gestor | Equipe direta do gestor referenciado |

### Migrations aplicadas

| Migration | Conteúdo |
|---|---|
| 062 | Cria a tabela com tipos `empresa_atuacao`, `setor`, `todos` |
| 063 | Adiciona coluna `gestor_ref_id` FK + adiciona `'gestor'` ao CHECK de `tipo` |
| 064 | Índices únicos parciais: evita duplicatas por tipo por gestor |

### Indexes únicos (migration 064)

```sql
-- tipo 'gestor': unique por (gestor_id, gestor_ref_id)
CREATE UNIQUE INDEX uq_escopo_ferias_gestor_ref ON param_escopo_ferias (gestor_id, gestor_ref_id)
  WHERE tipo = 'gestor' AND ativo = true;
-- tipo 'empresa_atuacao' ou 'setor': unique por (gestor_id, tipo, valor)
CREATE UNIQUE INDEX uq_escopo_ferias_valor ON param_escopo_ferias (gestor_id, tipo, valor)
  WHERE tipo IN ('empresa_atuacao', 'setor') AND ativo = true;
-- tipo 'todos': unique por gestor_id (só pode ter um)
CREATE UNIQUE INDEX uq_escopo_ferias_todos ON param_escopo_ferias (gestor_id)
  WHERE tipo = 'todos' AND ativo = true;
```

### Comportamento em `_carregarEquipeGestor`

Após carregar `_baseColabs`, carrega os escopos ativos do gestor e expande com colaboradores extras:
- `tipo = 'gestor'`: busca `param_gestor.apelido||nome` do `gestor_ref_id`, depois `colaboradores.gestor ilike refNome`
- `tipo = 'empresa_atuacao'`: `colaboradores.empresa_atuacao ilike valor`
- `tipo = 'setor'`: `colaboradores.setor ilike valor`
- `tipo = 'todos'`: todos os CLT ativos

Colaboradores duplicados (já na equipe base) são deduplados por `id`.

## Filtro de ano na Visão RH

`ANO_REF = 0` significa "Todos os anos" (sentinel). O select inicia com `<option value="0" selected>Todos os anos</option>`.

Ao filtrar lançamentos por ano, checar **ambos** `inicio` e `fim` do lançamento:
```js
const iniAno = Number((l.inicio || '').slice(0,4));
const fimAno = Number((l.fim   || '').slice(0,4));
return iniAno === ano || fimAno === ano;
```

Isso cobre lançamentos que cruzam a virada do ano (ex: 22/12/2025 → 04/01/2026).

## Seleção de PA na coluna "PA Vigente" da lista

```js
// Em renderListaAnual e renderMinhaEquipe (set/2026 — regra unificada)
// pasDoAno já está ordenado por paInicio ASC; pasDoAno exclui Pendente/Rejeitado/Cancelado/Descartado
const _comFuturo = pasDoAno.filter(r => r.lancamentos.some(l => l.inicio && l.inicio >= HOJE));
const _comSaldo  = pasDoAno.filter(r => calcSaldo(r) > 0);
const reg = _comFuturo.length > 0 ? _comFuturo[0]   // PA mais antigo com lançamento futuro ativo
          : _comSaldo.length  > 0 ? _comSaldo[0]    // PA mais antigo com saldo (regra CLT)
          : pasDoAno[pasDoAno.length - 1];           // fallback: mais recente (todos concluídos)
```

**Prioridade 0 (`_comFuturo`):** quando existe um PA com lançamento futuro (ex: PA 2026 com gozo em jan/2027), esse PA é a referência inteira da linha — PA exibido, coluna Agendamentos, saldo e badge, todos do mesmo PA. Evita a incoerência de mostrar PA 2027 (com saldo) enquanto o agendamento real está no PA 2026.

**Prioridade 1 (`_comSaldo`):** regra CLT original — se nenhum PA tem lançamento futuro, pega o mais antigo com saldo.

**Fallback:** todos os PAs concluídos → mostra o mais recente (não o mais antigo de 2019).

**`_comFuturo` é seguro:** `pasDoAno` já exclui PAs com status Cancelado/Descartado/Rejeitado/Pendente, portanto lançamentos de PAs inválidos não são incluídos.

**Aplicado em:** `renderListaAnual` (visão RH) e `renderMinhaEquipe` (visão Gestor) — ambas usam a mesma lógica desde set/2026.

## Criação automática de PAs — `autocriarPasFaltantes()`

Chamada em `carregarDoSupabase()` após `supabaseParaModelo()`. Cria em **loop** todos os PAs faltantes para cada colaborador até chegar no PA vigente.

**Condição de entrada (por colaborador):**
- Colaborador ativo com `_sbColabId`
- Nenhum PA válido com `pa_fim >= HOJE` (sem PA vigente)
- Último PA válido com `calcSaldo = 0` (totalmente utilizado)

**Loop interno:** cria PAs sequenciais (`pa_inicio = addDays(lastReg.paFim, 1)`, `pa_fim = addDays(paInicio, 364)`) até que o novo PA tenha `pa_fim >= HOJE`. Limite de 10 iterações por colaborador (segurança).

**Datas:**
- `pa_inicio` = dia seguinte ao `pa_fim` do último PA
- `pa_fim` = `pa_inicio + 364 dias`
- `ano` = ano do `pa_fim`
- `status` = `'Aprovado'`, sem lançamentos

**NÃO cria** se:
- Algum PA válido já tem `pa_fim >= HOJE` (vigente existe)
- Último PA tem saldo > 0 (PA aberto, não concluído)

**Campos do POST** (só o que existe na tabela `ferias`):
`colaborador_id, matricula_colaborador, ano, pa_inicio, pa_fim, status`
— nunca incluir `dias_direito` (campo inexistente).

## Dot de lançamento no drawer RH — cor correta

```js
// Cor do dot: cinza se PA cancelado/descartado, cinza se lançamento passado, verde se futuro/ativo
style="background:${excluirPA ? '#CBD5E1' : l.fim < HOJE ? 'var(--text-ter)' : 'var(--green)'}"
```

`excluirPA` é calculado antes do loop de lançamentos: `const excluirPA = excluir.has(r.status)`.

## Scripts Python de manutenção — padrão REST

A biblioteca `supabase-py` pode não estar instalada. Usar `requests` diretamente:
```python
import requests
SB_URL = "https://rujtbxwssiofiialnbbg.supabase.co"
headers = {"apikey": SB_SECRET, "Authorization": f"Bearer {SB_SECRET}", "Content-Type": "application/json", "Accept": "application/json"}
r = requests.get(f"{SB_URL}/rest/v1/ferias?...", headers=headers)
rows = r.json()  # verificar isinstance(rows, list) antes de iterar
```

## Visão Diretoria — regras de acesso e comportamento (set/2026)

### Somente leitura — IS_DIRETORIA

`IS_DIRETORIA = (perfil === 'diretoria')` — setado em `setRole()` e no IIFE de inicialização.

**Regra:** na visão Diretoria, o drawer pode ser aberto para visualizar o histórico completo do colaborador, mas **nenhuma ação operacional deve aparecer ou ser executável**. A guard obrigatória em `renderDrawerHistorico` é `IS_RH && !IS_DIRETORIA && podeAcao(...)`.

Elementos suprimidos por `!IS_DIRETORIA` (set/2026):

| Elemento | Tipo de guard |
|---|---|
| Botão "+ Criar próximo PA" (`novoPaBtn`) | `IS_RH && !IS_DIRETORIA && podeAcao('ferias','inserir')` |
| Banner "PA ativo não é o primeiro" (`bannerPaAtivo`) | `IS_RH && !IS_DIRETORIA && ...` |
| `onclick` do ícone de acordo (expandirGozo) | `!excluirPA && IS_RH && !IS_DIRETORIA` |
| Visibilidade do ícone de acordo sem gozos existentes | `(IS_RH && !IS_DIRETORIA) \|\| temGozos` |
| Seção gozo editável (secaoHtml) | `IS_RH && !IS_DIRETORIA && podeAcao('ferias','inserir')` |
| Botões clock / edit / delete / container de ações | `IS_RH && !IS_DIRETORIA && podeAcao('ferias','alterar')` |
| Formulário de edição de lançamento (`editFormHtml`) | `!excluirPA && IS_RH && !IS_DIRETORIA` |
| Botões Aprovar/Recusar do `_novoLanc` pendente | `IS_RH && !IS_DIRETORIA && podeAcao('ferias','alterar')` |
| Botão "+ Lançar" (`lancarBtnHtml`) | `IS_RH && !IS_DIRETORIA && podeAcao('ferias','inserir')` |
| Execução de `confirmarDrawerLancamento()` | `IS_RH && !IS_DIRETORIA && podeAcao('ferias','inserir')` |
| Botão "Analisar" na aba Auditoria | `IS_RH && !IS_DIRETORIA && _rhEhRecente(h)` |

**Anti-padrão:** usar apenas `IS_RH && podeAcao(...)` sem `!IS_DIRETORIA` — Diretoria tem `IS_RH = true` (não é gestor) então todas as ações apareceriam.

### Drawer genérico (abrirDrawerGenerico) — modais da Diretoria

Os modais da Diretoria (setor, risco de dobra, pico de saídas) usam `abrirDrawerGenerico(titulo, html)`, que reutiliza o elemento `#drawer` ocultando `.drawer-hdr`, `.drawer-tabs`, `.drawer-body` e exibindo `#drawerGenericTitle` + `#drawerGenericBody`.

Clicar em um colaborador dentro desses modais chama `fecharDrawer(); setTimeout(() => abrirDrawer(key), 180)` — abre o drawer normal do colaborador, que por sua vez respeita as guards de `IS_DIRETORIA` acima.

### Drag do drawer — infraestrutura (set/2026)

O `#drawer` (usado tanto no modo perfil quanto no modo genérico) é arrastável pela tela. A lógica fica num IIFE logo após `abrirDrawerGenerico`:

```js
(function() {
  let _dragging = false, _ox = 0, _oy = 0;
  document.addEventListener('DOMContentLoaded', () => {
    const modal = document.getElementById('drawer');
    if (!modal) return;

    const attachDrag = handle => {
      if (!handle) return;
      handle.style.cursor = 'grab';
      handle.addEventListener('mousedown', e => {
        if (e.target.closest('button')) return; // não inicia drag em botões
        const rect = modal.getBoundingClientRect();
        _ox = e.clientX - rect.left;
        _oy = e.clientY - rect.top;
        _dragging = true;
        handle.style.cursor = 'grabbing';
        modal.classList.add('dragging');       // transition: none
        modal.style.transform = 'none';        // cancela translate(-50%,-50%)
        modal.style.left = rect.left + 'px';
        modal.style.top  = rect.top  + 'px';
      });
      handle.addEventListener('mouseup', () => { handle.style.cursor = 'grab'; });
    };

    attachDrag(document.querySelector('#drawer .drawer-hdr'));    // modo perfil
    attachDrag(document.getElementById('drawerGenericTitle'));    // modo genérico (Diretoria)

    // MutationObserver: garante attach no drawerGenericTitle após abrirDrawerGenerico preencher innerHTML
    const observer = new MutationObserver(() => {
      const hg = document.getElementById('drawerGenericTitle');
      if (hg && !hg._dragAttached) { hg._dragAttached = true; attachDrag(hg); }
    });
    observer.observe(modal, { childList: true, subtree: true });

    document.addEventListener('mousemove', e => {
      if (!_dragging) return;
      const x = Math.max(0, Math.min(e.clientX - _ox, window.innerWidth  - modal.offsetWidth));
      const y = Math.max(0, Math.min(e.clientY - _oy, window.innerHeight - modal.offsetHeight));
      modal.style.left = x + 'px';
      modal.style.top  = y + 'px';
    });
    document.addEventListener('mouseup', () => {
      if (!_dragging) return;
      _dragging = false;
      modal.classList.remove('dragging');
    });
  });
})();
```

`fecharDrawer()` reseta `left`, `top` e `transform` — o drawer volta à posição central na próxima abertura.

**Regras:**
- Nunca reescrever o IIFE; estender apenas via `attachDrag` caso seja necessário novo handle
- Nunca alterar regras de conteúdo, permissões ou comportamento do drawer ao implementar drag
- O CSS `.drawer.dragging { transition: none; user-select: none; }` já existe e é obrigatório

---

## Padrão de Gestor — fonte canônica e normalização (set/2026)

### Regra única de Gestor no módulo

> `param_gestor` é a fonte canônica para **listar** gestores. O vínculo colaborador→gestor é `colaboradores.gestor`. A **comparação** sempre usa `normGestor()`.

### Funções globais obrigatórias

```js
// Normalização canônica — lowercase + remove acentos + trim
function normGestor(s) {
  return (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
}

// Lista de gestores ativos — cache, lê param_gestor uma vez por sessão
let _gestoresAtivosCache = null;
async function getGestoresAtivos() {
  if (_gestoresAtivosCache) return _gestoresAtivosCache;
  const rows = await sbGet('param_gestor', 'select=apelido&ativo=eq.true&order=ordem').catch(() => []);
  _gestoresAtivosCache = rows.map(r => r.apelido).filter(Boolean);
  return _gestoresAtivosCache;
}
```

### Onde cada função é usada

| Contexto | Listar opções | Comparar |
|---|---|---|
| RH – Timeline Gantt (linha 7575) | `sbGet param_gestor` direto | `normGestor()` |
| Exportação mensal RH (linha 7765) | — | `normGestor()` |
| Gestor – Atividade (linha 8525) | — | `normGestor()` |
| Gestor – Atenção (linha 10521) | `sbGet param_gestor` direto | `normGestor()` |
| Export PDF (linha 9852) | — | `normGestor()` |
| Export Excel (linha 10059) | — | `normGestor()` |
| Diretoria – Dashboard popular | `getGestoresAtivos()` + `MultiSelect` | `.some(g => normGestor(g) === normGestor(...))` |
| Diretoria – Dashboard filtrar | — | `.some()` com `normGestor` |
| Diretoria – Timeline popular | `getGestoresAtivos()` + `MultiSelect` | `.some()` com `normGestor` |
| Diretoria – Timeline filtrar | — | `.some()` com `normGestor` |

### Anti-padrões a evitar

- `_normG`, `_normGT`, `_normGA` locais para gestor — removidos, usar `normGestor()` global
- Listar gestores a partir de `c.gestor` (campo text de colaboradores) — gera duplicatas por variação ortográfica; sempre usar `param_gestor`
- Comparar `c.gestor === gestorFiltro` diretamente (case-sensitive, sem normalização)

### Diretoria — MultiSelect de Gestor (assíncrono)

`getGestoresAtivos()` é assíncrona. O padrão correto (não usar `await` dentro de função síncrona):

```js
if (!MS_INSTANCES['dirMsGestor']) new MultiSelect('dirMsGestor', 'Gestor', () => renderDiretoria(), 'gestores');
getGestoresAtivos().then(gestores => MS_INSTANCES['dirMsGestor']?.setOptions(gestores));
```

Na primeira abertura da aba há ~100ms de delay antes das opções carregarem — comportamento esperado, igual a outros filtros assíncronos do sistema.

---

## Timeline Gantt — arquitetura centralizada (set/2026)

A Timeline usa **um único renderer** (`_ganttRenderContent`) compartilhado por RH, Gestor e Diretoria. O que varia entre perfis é apenas a fonte dos dados e o escopo de colaboradores visíveis — nunca a regra de cálculo ou desenho.

### `_ganttPrepararLancs(c, fonte)` — regra de gozo efetivo

Prepara os lançamentos a exibir para cada colaborador, aplicando a regra de realizações:

```js
// fonte = 'rh': lê c.registros[].lancamentos[] e c.registros[].realizacoes[]
// fonte = 'gestor': lê GESTOR_LANCAMENTOS por c.id, usa flag _isRealizacao

// Regra para cada PA:
// Se há realizações válidas (não cancelado/descartado/rejeitado) → mostra o gozo efetivo
// Senão → mostra o lançamento oficial

const _GANTT_EXCL = new Set(['cancelado','descartado','rejeitado']);
```

Cada entrada retornada tem: `{ inicio, fim, dias, status, aprovado }`.
- Realizações: `status: 'gozado'`, `aprovado: true`
- Lançamentos oficiais: `status` original; `aprovado: st !== 'solicitado'`

### `_ganttRenderContent(targetEl, filtrados, diasNoMes, mesInicio, mesFim, mes, ano)`

Recebe objetos colaborador com `c.__ganttLancs` pré-computado (via `_ganttPrepararLancs`). **Não lê `c.registros` nem `GESTOR_LANCAMENTOS` diretamente.**

**Foto:** unificada — `c.fotoUrl || c.foto_url` (cobre RH camelCase e Gestor snake_case).

**onclick:** condicional — só emite `abrirDrawer` quando `c.__key` está presente (RH/Diretoria). Gestor não tem `__key`.

### Wrappers de cada perfil

```js
// renderTimeline (RH) e renderDirTimeline (Diretoria):
.map(c => ({ ...c, __ganttLancs: _ganttPrepararLancs(c, 'rh') }))
.filter(c => c.__ganttLancs.some(l => l.inicio <= mesFim && l.fim >= mesInicio))

// renderGestorGantt:
.map(c => ({
  ...c,
  __ganttLancs: _ganttPrepararLancs(c, 'gestor').filter(l => {
    if (statusFiltro && (l.status||'').toLowerCase() !== statusFiltro) return false;
    if (janelaFim && !(l.fim >= hoje && l.inicio <= janelaFim)) return false;
    return true;
  }),
}))
.filter(c => c.__ganttLancs.some(l => l.inicio <= mesFim && l.fim >= mesInicio))
// depois: _ganttRenderContent(content, colabs, ...)
```

### Mapa mensal do Gestor (Dashboard Gestor — detalhamento de mês)

Quando o usuário clica num mês no mapa anual do Dashboard Gestor, `_gdashMapaFiltrarMes(mi)` seta `_gdashMapaMesSel = mi` e chama `_renderGdashMapa()`, que entra no modo de detalhamento (`SEL !== null`). Esse modo renderiza uma Timeline inline dentro do próprio Dashboard usando o mesmo `_ganttRenderContent`.

**Padrão obrigatório:** `colabsAdaptados` deve ter `__ganttLancs` gerado via `_ganttPrepararLancs(colab, 'gestor')`, não construído manualmente com `registros[]`. `lansDoMes` determina **quem entra** (status `aprovado/gozado`, dentro do mês); `_ganttPrepararLancs` determina **o que renderizar** (incluindo regra de gozo efetivo).

```js
// Correto (set/2026):
const ganttLancs = _ganttPrepararLancs(colab, 'gestor')
  .filter(l => l.inicio <= mesFim && l.fim >= mesInicio);
if (!ganttLancs.length) return null;
return { ...colab, fotoUrl: colab.foto_url||null, __key: String(colab.id), __ganttLancs: ganttLancs };

// Anti-padrão (não usar):
// registros: [{ lancamentos: lansDoMes.map(l => ({inicio, fim, dias})) }]
// → _ganttRenderContent espera __ganttLancs, não registros[].lancamentos
```

**`__key`** é setado para que `_ganttRenderContent` emita `onclick="abrirDrawer(...)"` nas linhas — permite abrir o drawer do colaborador diretamente do mapa mensal.

### "Sem programação" no Dashboard Gestor — dois elementos distintos

Existem dois elementos com texto "sem programação" no Dashboard Gestor. **Não confundir:**

| Elemento | Localização no código | Função |
|---|---|---|
| `gdashSemProgWrap` + `_renderGdashSemProg()` | Card separado abaixo do mapa anual | Agrupa colaboradores sem programação por urgência (Crítico / Atenção / Sem urgência), expansível por nível |
| `▾ N sem programação` | Rodapé do mapa anual (`_renderGdashMapa`) | Toggle colapsável que lista colaboradores sem nenhuma barra no mapa do ano corrente; critério visual (não aparece no mapa), diferente do KPI "Sem Agendamento" |

O KPI card "Sem Agendamento" (linha 8891, `filtrarGestorAlerta('sem-agendado')`) conta colaboradores com **saldo aberto e nenhum lançamento futuro** — critério ligeiramente diferente dos dois elementos acima. Os três coexistem intencionalmente.

### Regras de renderização de barra

Barras são renderizadas célula a célula. Cada barra é desenhada **na célula do `drawDay`** (primeiro dia visível no mês):
```js
const drawDay = l.inicio >= mesInicio ? l.inicio : mesInicio;
```

**Label da barra:** usa `colsOriginais` (duração total, não apenas dias visíveis) — escada de três níveis:
```js
const colsOriginais = Math.max(1, Math.round((new Date(l.fim+'T12:00:00') - new Date(l.inicio+'T12:00:00')) / 86400000) + 1);
let label = '';
if (colsOriginais >= 5) {
  label = `${fmtShort(l.inicio)} → ${fmtShort(l.fim)} · ${l.dias}d`;       // 10/08 → 14/08 · 5d
} else if (colsOriginais >= 3) {
  const [,mi,di] = l.inicio.split('-');
  const [,mf,df] = l.fim.split('-');
  label = mi === mf
    ? `${di}-${df}/${mi} · ${l.dias}d`       // 12-14/08 · 3d
    : `${di}/${mi}-${df}/${mf} · ${l.dias}d`; // 28/08-02/09 · 6d (virada de mês curto)
}
// <= 2 dias (56px): sem label — tooltip (title=) preserva as datas no hover
```

| Colunas | Largura | Formato | Exemplo |
|---|---|---|---|
| ≥ 5 dias | ≥ 140px | `DD/MM → DD/MM · Nd` | `10/08 → 14/08 · 5d` |
| 3–4 dias | 84–112px | `DD-DD/MM · Nd` | `12-14/08 · 3d` |
| ≤ 2 dias | ≤ 56px | vazio | — |

**Barras que vêm do mês anterior (`contLeft = true`):** o label pode ser mais largo que a barra visível — usar `overflow:visible` inline para deixar o texto flutuar para a direita:
```js
style="...${contLeft?'overflow:visible;':''}"
// e no span do label:
style="color:${txt};${contLeft?'overflow:visible;text-overflow:clip;':''}"
```

**Tooltip:** usa `c.nome.split(' ')[0]` (primeiro nome apenas) + datas em DD/MM/YYYY via `formatDate()`:
```js
title="${c.nome.split(' ')[0]}: ${formatDate(l.inicio)} → ${formatDate(l.fim)} · ${l.dias}d..."
```

### Largura das barras e alinhamento com colunas (corrigido set/2026)

**Problema:** sem `width` explícito na `<table>`, o browser estica as colunas para preencher o container — colunas ficam maiores que `W_CELL=28px` e as barras (calculadas com 28) terminam antes da data final.

**Solução obrigatória:** definir `width` explícito na tabela ao renderizar:
```js
// No innerHTML de renderTimeline() e renderGestorGantt():
`<table class="gantt-table" style="width:${250 + diasNoMes * 28}px">`
// 250 = largura da coluna de nome (.gantt-name-col)
// 28 = W_CELL (deve bater com CSS `th { width:28px }`)
```

**Largura da barra:** `left:0; width:${colsTotal * W_CELL}px` — preenche exatamente as colunas do período.

**Border-radius:** `.gantt-bar` usa `border-radius: 3px 0 0 3px` (lado esquerdo arredondado, direito reto). Lado direito sempre reto → cor preenche até a borda exata da coluna da data final. Classes CSS complementares:
```css
.gantt-bar.bar-cont-left  { border-top-left-radius: 0; border-bottom-left-radius: 0; }
.gantt-bar.bar-cont-right { border-top-right-radius: 0; border-bottom-right-radius: 0; }
/* contRight: direito já é 0 pelo base; classe mantida por semântica */
```

### Realizações na Timeline — regra de gozo efetivo (set/2026)

A Timeline exibe o **gozo efetivo** quando existem realizações válidas, ou o lançamento oficial quando não existem. A regra é idêntica para os três perfis via `_ganttPrepararLancs`.

**Antes (comportamento antigo, substituído):**
- Visão RH: `todosLancs` vinha de `reg.lancamentos` — nunca mostrava realizações
- Visão Gestor: `lancColabs` excluía `_isRealizacao: true` — nunca mostrava realizações

**Atual:**
- `_isRealizacao: true` sinaliza que a entry em `GESTOR_LANCAMENTOS` veio de `row.realizacoes`
- `_ganttPrepararLancs` usa esse flag para decidir por PA qual dado mostrar:
  - Há realizações válidas → mostra-as (barras do gozo real)
  - Sem realizações → mostra lançamento oficial (`!_isRealizacao`)
- Realizações com status `cancelado`/`descartado`/`rejeitado` são ignoradas em ambos os casos

### Visibilidade das abas Painel / Timeline (corrigido set/2026)

`.pvtab` inativo usa `color: var(--text-sec)` (não `--text-ter`). Hover usa `color: var(--text)` para contraste suficiente. Aba ativa usa `#1849A9` bold.

### KPIs ocultos na aba Timeline do Gestor (corrigido set/2026)

Os elementos `#gestorAlerts` e `#gestorAtividade` ficam acima das abas no DOM (fora de `gsub-painel`), por isso não são ocultados automaticamente pela troca de aba. A solução é controlá-los em `setGestorTab`:

```js
function setGestorTab(tab) {
  ['painel','timeline'].forEach(t => {
    document.getElementById('gsub-' + t).style.display = t === tab ? '' : 'none';
    document.getElementById('gtab-' + t)?.classList.toggle('active', t === tab);
  });
  const isTimeline = tab === 'timeline';
  const alertsEl = document.getElementById('gestorAlerts');
  const atividadeEl = document.getElementById('gestorAtividade');
  if (alertsEl) alertsEl.style.display = isTimeline ? 'none' : '';
  if (atividadeEl) atividadeEl.style.display = isTimeline ? 'none' : '';
  if (isTimeline) renderGestorGantt();
}
```

**Regra:** na aba Timeline o foco é visual/calendário — KPIs e atividade recente não têm contexto ali. No Painel voltam normalmente. `renderGestorAlerts()` pode ser chamado em outros lugares (aprovações, solicitações) sem resetar o `display`, pois só altera `innerHTML`.

## Visão Gestor — filtros de data em lançamentos (regra crítica)

**Solicitações com status `solicitado`** devem ser consideradas **independentemente de `l.fim >= hoje`**. O critério de data se aplica apenas a `recusado`. Aplicar esse padrão em todos os lugares que filtram `GESTOR_LANCAMENTOS`:

```js
// Card Pendentes (renderGestorAlerts) — commit d442144:
const aguardAprov = GESTOR_LANCAMENTOS.filter(l => {
  const st = (l.status||'').toLowerCase();
  if (st === 'solicitado') return true;           // sem filtro de data
  if (st === 'pendente_gestor') return true;
  if (st === 'cancelamento_solicitado') return true;
  return st === 'recusado' && l.fim >= hoje;
});
// Alterações/cancelamentos pendentes cujo status fica no PA (ferias.status),
// não no lancamento — quando o PA usa periodos[] JSONB o lancamento individual
// ainda tem status 'aprovado'. GESTOR_PERIODOS é a fonte correta, igual à
// visão RH que usa reg.status === 'Alteracao_Solicitada' (getPendentes).
const _altPendIds = GESTOR_PERIODOS
  .filter(p => { const st = (p._feriasRow?.status||'').toLowerCase(); return st === 'alteracao_solicitada' || st === 'cancelamento_solicitado'; })
  .map(p => p.colaborador_id);
const colabsComPend = [...new Set([...aguardAprov.map(l => l.colaborador_id), ..._altPendIds])];

// Filtro de lista 'aguard' (renderGestorAtencao):
colabs = colabs.filter(c => GESTOR_LANCAMENTOS.some(l => {
  const st = (l.status||'').toLowerCase();
  if (!['solicitado','recusado'].includes(st)) return false;
  if (String(l.colaborador_id) !== String(c.id)) return false;
  return st === 'solicitado' || (l.fim||'') >= _hj;
}));

// Badge e botão na linha da lista:
const lancsPA = GESTOR_LANCAMENTOS.filter(l => l.colaborador_id === c.id && String(l.periodo_id) === String(pa?.id));
const temSolicitado = lancsPA.some(l => (l.status||'').toLowerCase() === 'solicitado'); // sem filtro de data
```

**Por quê:** solicitações com datas de gozo no passado (ex: gestor solicita férias retroativas para aprovação do RH) devem permanecer visíveis no painel até serem aprovadas/recusadas.

## Visão Gestor — bloqueio de datas retroativas (commit 4db6fe5)

Em `gestorEnviarSolicitacao`, logo após validar `inicio` e `diasVal`, bloquear datas no passado:
```js
const _hoje = new Date().toISOString().slice(0, 10);
if (inicio < _hoje) {
  // exibir erro em #mgErro (com classe .show por 6s) ou toast
  return;
}
```
**Regra:** somente a visão do Gestor tem esse bloqueio. O RH não é afetado — o drawer do RH (lançamento manual) permanece sem restrição de data para correções históricas.

**Motivação:** gestores digitavam o ano atual (ex: 2026) em vez de 2027 ao solicitar férias futuras, gerando lançamentos retroativos inválidos que o sistema não rejeitava.

## Visão Gestor — prevenção de solicitação duplicada

Em `gestorEnviarSolicitacao`, antes de fazer o PATCH, verificar se já existe lançamento `solicitado` no PA:
```js
const jaSolicitado = GESTOR_LANCAMENTOS.some(l =>
  String(l.periodo_id) === String(periodo.id) &&
  (l.status||'').toLowerCase() === 'solicitado'
);
if (jaSolicitado) { /* mostrar erro e return */ }
```

## Sistema de auditoria — `ferias_historico` (2026-09-14)

### Global `FERIAS_HISTORICO`

Array carregado na inicialização de cada visão:
- **RH:** no `Promise.all` de `carregarDoSupabase` — `sbGet('ferias_historico', 'select=*&order=criado_em.desc&limit=500').catch(() => [])`
- **Gestor:** junto com `feriasRows` no load do gestor — filtrado por `colaborador_id=in.(${ids})`

Sempre com `.catch(() => [])` — tabela pode não existir em ambientes antigos sem quebrar o sistema.

### Helper `sbPost(tabela, dados)`

```js
async function sbPost(tabela, dados) {
  const extra = { 'Prefer': 'return=minimal' };
  await _sbFetch(`${SB_URL}/rest/v1/${tabela}`, {
    method: 'POST', headers: { ...SB_HEADERS, ...extra }, body: JSON.stringify(dados),
  });
}
```

### Helper `_logAtiv(feriasId, colabId, acao, usuario, detalhe)`

**CORRIGIDO em commit `3fca0d2`** — versão anterior silenciava falhas de INSERT.

```js
async function _logAtiv(feriasId, colabId, acao, usuario, detalhe) {
  const entry = { ferias_id: Number(feriasId), colaborador_id: Number(colabId), acao, usuario: usuario || null, detalhe: detalhe || null };
  await sbPost('ferias_historico', entry);   // lança em caso de falha — sem try/catch interno
  FERIAS_HISTORICO.unshift({ ...entry, id: Date.now(), criado_em: new Date().toISOString() });
}
```

**Comportamento obrigatório:**
- Se `sbPost` falhar, a função lança — `FERIAS_HISTORICO.unshift` **não** executa.
- Cada caller envolve `_logAtiv` em seu **próprio** `try/catch` local com flag `_histFalhouXxx`.
- Se a operação principal (sbPatch) teve sucesso mas o log falhou: toast com aviso distinto, botão permanece bloqueado (sem risco de submissão duplicada).
- Nunca mostrar "Erro ao [operação]" quando apenas o log falhou.

### Onde `_logAtiv` é chamado — padrão dos callers

Todos os 13 callers seguem este padrão (commit `3fca0d2`):

```js
let _histFalhouXxx = false;
try { await _logAtiv(feriasId, colabId, 'acao', usuario, detalhe); }
catch(e) { _histFalhouXxx = true; console.error('[_logAtiv acao]', e); }
toast(_histFalhouXxx ? '✓ Operação — histórico não registrado, contate o suporte.' : '✓ Operação', _histFalhouXxx ? 'aviso' : '');
```

| Função | `acao` | Flag local | `usuario` |
|---|---|---|---|
| `rhAprovarGozoPendente` | `'gozo_aprovado'` | `_histFalhouGozo` | `perfil.nome \|\| 'RH'` |
| `rhAprovarSolicitado` | `'aprovado'` | `_histFalhouAprov` | `perfil.nome \|\| 'RH'` |
| `rhRecusarSolicitado` | `'rejeitado'` | `_histFalhouRec` | `perfil.nome \|\| 'RH'` |
| `aprovarPendente` (**fluxo padrão** — commit `177d847`) | `'aprovado'` | `_histFalhouAprov` | `perfil.nome \|\| 'RH'` |
| `aprovarPendente` (alteração) | `'alteracao_aprovada'` | `_histFalhouAlt` | `perfil.nome \|\| 'RH'` |
| `aprovarPendente` (cancelamento) | `'cancelamento_aprovado'` | `_histFalhouCancAprov` | `perfil.nome \|\| 'RH'` |
| `rejeitarPendente` (alteração) | `'alteracao_recusada'` | `_histFalhouAltRec` | `perfil.nome \|\| 'RH'` |
| `rejeitarPendente` (cancelamento) | `'cancelamento_recusado'` | `_histFalhouCancRec` | `perfil.nome \|\| 'RH'` |
| `rejeitarPendente` (pad) | `'rejeitado'` | `_histFalhouRejPad` | `perfil.nome \|\| 'RH'` |
| `grhEnviarSolicitarCancelamento` | `'cancelamento_solicitado'` | `_histFalhouCancSol` | `GESTOR_NOME_USUARIO` |
| `grhEnviarSolicitarAlteracao` | `'alteracao_solicitada'` | `_histFalhouAltSol` | `GESTOR_NOME_USUARIO` |
| `gestorEnviarSolicitacao` | `'solicitado'` | `_histFalhouSol` | `GESTOR_NOME_USUARIO` |
| `grhEnviarSolicitarGozo` | `'gozo_solicitado'` | `_histFalhouGozoSol` | `GESTOR_NOME_USUARIO` |
| `gestorMarcarCiente` | `'gestor_ciente'` | — (catch próprio da função) | `GESTOR_NOME_USUARIO` |

`perfil` = `JSON.parse(localStorage.getItem('sb_perfil') || '{}')`.

**Atenção `gestorEnviarSolicitacao`:** a ferias row é criada **antes** de `_logAtiv`. Se `_logAtiv` falhar, a criação já ocorreu — o caller **não** re-habilita o botão para evitar submissão duplicada.

### `gestorMarcarCiente(feriasId, colabId, acaoRef, btnEl)`

Botão "Ciente" exibido ao Gestor quando o RH responde (aprovado, rejeitado, alterações, cancelamentos). **Corrigido em commit `6bbdfad`** (dois try/catch separados).

```js
async function gestorMarcarCiente(feriasId, colabId, acaoRef, btnEl) {
  if (btnEl) { btnEl.disabled = true; btnEl.textContent = '...'; }
  const original = FERIAS_HISTORICO.find(h =>
    String(h.ferias_id) === String(feriasId) &&
    (h.acao || '').toLowerCase() === (acaoRef || '').toLowerCase()
  );
  const det = { acao_referencia: acaoRef };
  if (original?.detalhe?.inicio) det.inicio = original.detalhe.inicio;
  if (original?.detalhe?.fim)    det.fim    = original.detalhe.fim;
  if (original?.detalhe?.dias)   det.dias   = original.detalhe.dias;
  try {
    await _logAtiv(feriasId, colabId, 'gestor_ciente', GESTOR_NOME_USUARIO, det);
  } catch(e) {
    if (btnEl) { btnEl.disabled = false; btnEl.textContent = 'Ciente'; }
    toast('Não foi possível registrar. Tente novamente.', 'erro');
    console.error('[gestorMarcarCiente]', e);
    return;
  }
  try { renderGestorAtividade(); } catch(e) { console.error('[renderGestorAtividade pós-ciente]', e); }
}
```

**Regra obrigatória (commit `6bbdfad`):** INSERT e render em blocos try/catch **separados**. Se o INSERT tiver sucesso mas `renderGestorAtividade` lançar, o erro de render é logado silenciosamente — jamais exibe toast de falha nem reabilita o botão. Isso evita que o Gestor clique "Ciente" duas vezes quando o registro já foi gravado.

**Dedup natural:** após INSERT bem-sucedido, `_gestorAgruparProcessos` elege `gestor_ciente` como evento mais recente → `_gestorProcessoInfo` retorna `ativo: false` → item sai de "Atividade Recente" → botão nunca é renderizado novamente.

**Ações que exibem o botão Ciente** (`_DESFECHOS_RH` + fallback):
```js
const _DESFECHOS_RH = new Set(['aprovado','alteracao_aprovada','rejeitado','alteracao_recusada','cancelamento_aprovado','cancelamento_recusado']);
// ehDesfecho também é true quando _gestorProcessoInfo retorna _ehDesfecho:true (fallback via ferias.status)
const ehDesfecho = _DESFECHOS_RH.has((h.acao || '').toLowerCase()) || !!info._ehDesfecho;
// acaoRef passada ao gestorMarcarCiente usa info._acaoEfetiva (fallback) ou h.acao (normal)
const _acaoParaCiente = info._acaoEfetiva || h.acao || '';
```

### `_normGA(s)` — helper de normalização do Histórico

Definida logo após `normGestor` (~linha 2981). Idêntica a `normGestor`:

```js
function _normGA(s) {
  return (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').trim();
}
```

Usada em `renderGestorAtividade` no branch `else` (aba Histórico) para normalizar a busca:
```js
const busca = _normGA(document.getElementById('gestorHistBusca')?.value || '');
// ...
if (busca) gruposArr = gruposArr.filter(g => g.colab ? _normGA(g.colab.nome).includes(busca) : false);
```

**Bug corrigido (commit `6bbdfad`):** `_normGA` não estava definida, causando `ReferenceError` quando a aba Histórico era clicada. O fluxo de falha era: clicar "Histórico" → `_gestorAba='historico'` atualizado → `renderGestorAtividade()` lança antes de atualizar o DOM → botões "Ciente" da renderização anterior permanecem visíveis → clicar "Ciente" → INSERT bem-sucedido → `renderGestorAtividade()` lança novamente → catch exibe toast "Não foi possível registrar" → botão reabilitado → Gestor clica de novo (registro duplicado). **O INSERT sempre funcionava; o erro era apenas na renderização.**

---

### Atividade Recente + Histórico — arquitetura atual (baseada em `FERIAS_HISTORICO`)

Duas abas dentro da seção de atividade: **Atividade Recente** e **Histórico**. Sem localStorage, sem arquivamento manual.

#### Classificação

A função `_gestorProcessoInfo(h)` recebe o evento mais recente de um processo (`ferias_id`) e retorna `{ estado, cls, ativo, inicio, fim, dias }`.

**Regra obrigatória:** `ativo: true` APENAS para os três estados "aguardando decisão do RH":

```js
// Atividade Recente (ativo: true):
'solicitado'              → estado: 'Aguardando RH',              cls: 'neutro'
'alteracao_solicitada'    → estado: 'Alteração aguardando RH',    cls: 'cancel-sol'
'cancelamento_solicitado' → estado: 'Cancelamento aguardando RH', cls: 'cancel-sol'

// Histórico (ativo: false) — todos os desfechos:
'aprovado' / 'alteracao_aprovada'  → 'Aprovadas',     cls: 'aprov'
'rejeitado'                        → 'Recusadas',     cls: 'recus'
'alteracao_recusada'               → 'Alt. recusada', cls: 'recus'
'cancelamento_aprovado'            → 'Canceladas',    cls: 'cancel-aprov'
'cancelamento_recusado'            → 'Canc. recusado',cls: 'aprov'
'gestor_ciente'                    → 'Ciente',        cls: 'aprov'   // commit 993c54f
```

**Nunca** verificar data (`passou`) ou retomada (`temNovo`, `paVenc`) para decidir `ativo`. A classificação é puramente pelo tipo de ação do último evento.

#### ⚠ Fallback: `ferias.status` como fonte de verdade (commits `263becd`, `4bd7b43`, `7f5dcba` — 26/10/2026)

Quando `ferias_historico` não tem entrada de desfecho (registro aprovado antes do fix, ou falha silenciosa de `_logAtiv`), o sistema usa `ferias.status` para determinar se o processo foi resolvido.

**`_rhEhRecente` (visão RH):** antes de verificar o histórico, checa se o status do banco ainda corresponde ao estado pendente esperado:

```js
const _statusPendente = { solicitado: 'Pendente', cancelamento_solicitado: 'Cancelamento', alteracao_solicitada: 'Alteracao' };
if (_reg.status !== _statusPendente[acao]) return false; // já resolvido no banco
```

**`_gestorProcessoInfo` (visão Gestor):** extrai `_feriasRow.status` de `GESTOR_PERIODOS` e mapeia para o estado visual correto:

```js
const _periodo   = (GESTOR_PERIODOS || []).find(p => String(p.id) === String(h.ferias_id));
const _rowStatus = (_periodo?._feriasRow?.status || '').toLowerCase();
// Se status != pendente esperado, retorna desfecho mapeado com _ehDesfecho:true e _acaoEfetiva
```

O campo `_ehDesfecho: true` no retorno sinaliza para `_itemRow` que deve exibir o botão "Ciente", mesmo que `h.acao` seja `'solicitado'`. O campo `_acaoEfetiva` (`'aprovado'`, `'rejeitado'` etc.) é passado como `acaoRef` para `gestorMarcarCiente`.

**Mapeamento do fallback:**

| `acao` | `_rowStatus` | `estado` retornado | `_acaoEfetiva` |
|---|---|---|---|
| `solicitado` | `aprovado` / `agendado` | `'Aprovadas'` | `'aprovado'` |
| `solicitado` | `rejeitado` | `'Recusadas'` | `'rejeitado'` |
| `cancelamento_solicitado` | `cancelado` | `'Canceladas'` | `'cancelamento_aprovado'` |
| `cancelamento_solicitado` | `aprovado` | `'Canc. recusado'` | `'cancelamento_recusado'` |
| `alteracao_solicitada` | `aprovado` | `'Alt. aprovada'` | `'alteracao_aprovada'` |
| `alteracao_solicitada` | `rejeitado` | `'Alt. recusada'` | `'alteracao_recusada'` |

**Regra:** o fallback só dispara quando `_statusPendG[acao]` existe **E** `_rowStatus` está preenchido **E** difere do status esperado para pendente. Quando `_periodo` não existe (registro fora do escopo do gestor), `_rowStatus` é `''` → fallback não dispara → comportamento original preservado.

#### `_gestorAgruparProcessos(idsPermitidos)`

Agrupa `FERIAS_HISTORICO` por `ferias_id`, mantendo apenas o evento mais recente (maior `criado_em`) por processo. Retorna array de eventos — um por processo.

#### `renderGestorAtividade()` — Gestor

- **Atividade Recente:** processos com `ativo: true` (aguardando RH) — usa `_gestorAgruparProcessos` (1 evento por `ferias_id`, o mais recente)
- **Histórico:** todos os eventos de processos concluídos (`ativo: false`), agrupados por colaborador → subagrupados por `ferias_id` → ordenados cronologicamente dentro de cada bloco (commits `87c3723` e `ea3278e`)
- Datas exibidas: `inicio`/`fim`/`dias` do objeto `info` (vindos de `GESTOR_LANCAMENTOS` via `lanc?.inicio` com fallback para `h.detalhe`)

**Estado global:**
```js
let _gestorExpandido  = false;   // toda a seção aberta/fechada
let _gestorAba        = 'recente'; // 'recente' | 'historico'
let _gestorHistOffset = 0;       // paginação do Histórico
const _gestorHistExpanded = new Set(); // IDs de colaboradores com card expandido no Histórico
```

**Fallback obrigatório (out/2026):** após `_gestorAgruparProcessos`, injeta itens sintéticos para lançamentos em `GESTOR_LANCAMENTOS` com `status='solicitado'` cujo `periodo_id` não existe em `FERIAS_HISTORICO`. Garante que solicitações antigas (anteriores ao `_logAtiv`) ou com falha silenciosa apareçam na Atividade Recente. Itens sintéticos têm `_fallback: true` e `criado_em: null`.

#### KPI "Acordos em Andamento" — removido da visão Gestor (commits `27c2a76` + `5274678`, 2026-10-13)

O KPI era calculado por `_gestorColabsComAcordoAndamento` (função preservada) e exibido em `renderGestorAlerts`. Removido porque não é acionável pelo Gestor — quem registra realizações é o RH.

**O que foi removido:**
- Card KPI em `renderGestorAlerts` (condicional `acordosAndamento.length > 0`)
- Branch `'acordo'` em `filtrarGestorAlerta`

**O que foi mantido:**
- `_gestorColabsComAcordoAndamento` e retorno `acordosAndamento` em `_computeGestorMetricas` (preservados para uso futuro)
- `window._gestorAcordosAndamento` — restaurada para alimentar o chip contextual nos cards
- Chip "↩ Acordo em andamento" nos cards individuais da lista (commit `5274678`) — informação contextual útil por colaborador, sem ser um alerta global

#### Histórico do Gestor — arquitetura (commits `87c3723` + `ea3278e`, 2026-10-10)

**Problema anterior:** `_gestorAgruparProcessos` guardava apenas o evento mais recente por `ferias_id`, fazendo o fluxo `solicitado → aprovado → gestor_ciente` aparecer apenas como "Ciente" — sem contexto da decisão do RH.

**Solução:**

1. **Fonte de dados:** identifica os `ferias_id` cujo evento mais recente tem `ativo:false` (via `historico = processos.filter(h => !_gestorProcessoInfo(h).ativo)`), depois coleta **todos** os eventos de `FERIAS_HISTORICO` para esses processos — garante que processos ainda na Atividade Recente não apareçam no Histórico.

2. **Agrupamento:** por `colaborador_id` → sub-agrupado por `ferias_id` → eventos ordenados por `criado_em` asc dentro de cada bloco de processo.

3. **Cards colapsados por padrão:** header mostra nome + cargo + chip do status mais recente + indicador `+N processos` quando há mais de um. Clicar expande a timeline completa. Estado em `_gestorHistExpanded` (Set de colaborador IDs).

4. **Cada linha de evento exibe:** ícone colorido + chip de estado (`_gestorProcessoInfo`) + timestamp (`fmtDH(h.criado_em)`) + responsável (`h.usuario`) + motivo (se existir em `info.motivo`).

**Regra de não-sobreposição:** um processo aparece integralmente na Atividade Recente OU integralmente no Histórico — nunca nos dois. O critério é o `ativo` do **evento mais recente** do processo.

#### `renderRhAtividade()` — RH

Usa `_rhEhRecente(h)` para classificar eventos individuais (não processos agrupados):
- **Atividade Recente:** evento sem resposta para o mesmo `ferias_id`
- **Histórico:** cards colapsáveis idênticos ao Gestor (commit `875bc6e`)

> ⚠ **`renderRhAtividade()` não faz parte de `renderAll()`** — deve ser chamada explicitamente após qualquer ação que altere o status de uma solicitação. Commit `d73950b` (26/10/2026): adicionada chamada a `renderRhAtividade()` nos 6 pontos de saída de `aprovarPendente()` e `rejeitarPendente()` (fluxos padrão, alteração e cancelamento). A visão do Gestor não tinha esse problema — `renderGestorAtividade()` já era chamada em todas as ações do Gestor.

#### Helper compartilhado do Histórico (commit `875bc6e`, 26/10/2026)

`_renderCardHistoricoShared(g, opts)` — única implementação de card colapsável usada por ambas as visões no Histórico. Parâmetros:

| Campo | RH | Gestor |
|---|---|---|
| `expandedSet` | `_rhHistExpanded` (Set global) | `_gestorHistExpanded` (Set global) |
| `rerenderFn` | `'renderRhAtividade'` | `'renderGestorAtividade'` |
| `processInfoFn` | `_rhProcessoInfo` | `_gestorProcessoInfo` |

`_rhProcessoInfo(h)`: adapta `_acaoInfo(h.acao)` (retorna `{cls, chip, svg}`) para o formato `{cls, estado, inicio, fim, dias, motivo}` extraindo datas e motivo de `h.detalhe`.

**Regras de uso:**
- Nunca reimplementar o card colapsável do Histórico em nenhuma visão — sempre passar opts para o helper
- A aba "Atividade Recente" **não usa** o helper — continua com `_itemRow` flat em ambas as visões
- Estados de expansão são independentes: `_rhHistExpanded` e `_gestorHistExpanded` nunca se confundem
- Toggle inline gerado pelo helper usa `window['_rhHistExpanded']` ou `window['_gestorHistExpanded']` — ambos são `const` no escopo do módulo e acessíveis via `window`

#### Toggle expand/collapse nos títulos das abas (commit `c2cd11e`, 26/10/2026)

Clicar no título de uma aba **já ativa** alterna `_rhExpandido` / `_gestorExpandido` (expande/recolhe). Clicar numa aba **diferente** troca de aba e sempre expande. Comportamento idêntico em RH e Gestor. Chevron continua funcionando como alternativa.

Padrão implementado (ambas as visões, variáveis trocadas conforme perfil):
```js
// aba ativa → toggle; aba diferente → troca + expande
onclick="if(_rhAba==='recente'){_rhExpandido=!_rhExpandido}else{_rhAba='recente';_rhExpandido=true;_rhHistOffset=0};renderRhAtividade()"
```

**Fallback obrigatório (out/2026):** após filtrar recentes do `FERIAS_HISTORICO`, injeta itens sintéticos para cada pendente em `getPendentes()` cujo `reg._sbId` não existe em `FERIAS_HISTORICO`. Garante convergência entre o KPI "Pendentes de aprovação" e a Atividade Recente.

```js
function _rhEhRecente(h) {
  const respostas = {
    solicitado:              ['aprovado', 'rejeitado'],
    cancelamento_solicitado: ['cancelamento_aprovado', 'cancelamento_recusado'],
    alteracao_solicitada:    ['alteracao_aprovada', 'alteracao_recusada'],
  };
  if (!respostas[h.acao]) return false;
  return !respostas[h.acao].some(r =>
    FERIAS_HISTORICO.some(x => x.ferias_id === h.ferias_id && x.acao === r)
  );
}
```

**Problema conhecido — entrada órfã em `ferias_historico` (out/2026):**

Se um registro de férias foi marcado como `Descartado` após uma solicitação pendente ter sido gravada em `ferias_historico`, a entrada fica órfã: `_rhEhRecente` retorna `true` (nenhuma resposta registrada para aquele `ferias_id`), mas `_rhAtivAbrirModal` falha com "Solicitação não encontrada nos pendentes" porque `getPendentes()` nunca inclui registros `Descartado`.

**Correção pendente de aprovação (não implementada):** adicionar guard no início de `_rhEhRecente` para retornar `false` quando o `ferias_id` não existe em nenhum `reg._sbId` ativo de `COLABORADORES`:

```js
// Adicionar ANTES do return final:
const _feriasExiste = COLABORADORES.some(c =>
  c.registros.some(r => String(r._sbId) === String(h.ferias_id))
);
if (!_feriasExiste) return false;
```

Efeito: entradas cujo registro de origem foi Descartado migram automaticamente para a aba "Histórico" (sem botão "Analisar"), preservando o dado original para consulta. Sem inserções nem alterações no banco.

**O que cada item exibe:**
- Nome e cargo do colaborador
- Período de férias (`detalhe.inicio → detalhe.fim · dias`)
- Data/hora exata + nome do usuário (`fmtDH(h.criado_em) · h.usuario`)
- Chip de estado (`info.estado`)

### Card "Pendentes" — fontes: `GESTOR_LANCAMENTOS` + `GESTOR_PERIODOS` (commit d442144)

`GESTOR_LANCAMENTOS` cobre novas solicitações, gozo e cancelamentos cujo status chegou ao lancamento. `GESTOR_PERIODOS._feriasRow.status` é a fonte complementar obrigatória para **alterações e cancelamentos** quando o PA usa `periodos[]` JSONB — nesses casos o lancamento individual mantém `'aprovado'` e o status real fica só no `ferias.status` (= `_feriasRow.status`).

```js
const aguardAprov = GESTOR_LANCAMENTOS.filter(l => {
  const st = (l.status||'').toLowerCase();
  if (st === 'solicitado')              return true;
  if (st === 'pendente_gestor')         return true;
  if (st === 'cancelamento_solicitado') return true;
  return st === 'recusado' && l.fim >= hoje;
});
const _altPendIds = GESTOR_PERIODOS
  .filter(p => { const st = (p._feriasRow?.status||'').toLowerCase(); return st === 'alteracao_solicitada' || st === 'cancelamento_solicitado'; })
  .map(p => p.colaborador_id);
const colabsComPend = [...new Set([...aguardAprov.map(l => l.colaborador_id), ..._altPendIds])];
```

**Regras:**
- Sem filtro de data para `solicitado`/`cancelamento_solicitado`/`alteracao_solicitada`
- `Set` garante sem duplicidade quando o mesmo colaborador aparece nas duas fontes
- Nunca usar só `GESTOR_LANCAMENTOS` para verificar pendências de alteração

### Modal de confirmação genérico (`abrirModalConfirm`)

Substituiu `window.confirm()` (bloqueado pelo GitHub Pages).

```js
abrirModalConfirm({ titulo, texto, labelOk, corOk, cb })
```

- HTML: `#modalConfirm` com `z-index: 1300`, movido para `document.body` via `setTimeout(0)` para escapar stacking context
- `_modalConfirmCb` — callback chamado ao confirmar
- Funções: `_modalConfirmFechar()`, `_modalConfirmExecutar()`

**Regra:** usar `abrirModalConfirm` em toda ação destrutiva irreversível que precisar de confirmação do usuário.

### Drawer RH — abas "Períodos" e "Histórico"

HTML:
```html
<div class="drawer-tabs">
  <button class="drawer-tab active" id="drawerTabPeriodos" onclick="setDrawerTab('periodos')">Períodos</button>
  <button class="drawer-tab" id="drawerTabAuditoria" onclick="setDrawerTab('auditoria')">Histórico</button>
</div>
<div class="drawer-tabs-line"></div>
<div class="drawer-body">
  <div id="drawerHistorico"></div>
  <div id="drawerAuditoria" style="display:none;"></div>
</div>
```

`setDrawerTab(tab)` — troca visibilidade entre os dois divs e atualiza `.active`. Ao mudar para `'auditoria'`, chama `renderDrawerAuditoria(colab)`.

`renderDrawerAuditoria(colab)` — filtra `FERIAS_HISTORICO` pelos `_sbId`s dos registros do colaborador e renderiza linha do tempo vertical com dot colorido por ação.

`_drawerTab` — variável global (`'periodos'` por padrão), resetada para `'periodos'` a cada abertura de drawer em `_abrirDrawerInterno`.

### Drawer Gestor — aba "Histórico"

`gsolDrawer` tem três abas: Solicitações (oculta) | **Férias** | **Histórico**

```html
<button class="gsol-tab" id="gsolTabHist" onclick="gsolMostrarAba('hist')">Histórico</button>
<div id="gsolListaHist" style="display:none;"></div>
```

`gsolMostrarAba('hist')` — exibe `gsolListaHist`, oculta os outros dois, chama `_renderGsolHistoricoAuditoria()`.

`_renderGsolHistoricoAuditoria()` — filtra `FERIAS_HISTORICO` por `colaborador_id === _gsolColabId` e renderiza mesma linha do tempo da visão RH (font-size menor, 12px/10px).

**Variável `_gsolColabId`** — id do colaborador atualmente aberto no gsolDrawer (string). Definida em `gestorAbrirSolicitacoes`.

### Visão Gestor — seção "Atividade recente"

Container `<div id="gestorAtividade">` inserido entre `#gestorAlerts` e o card da lista no HTML.

Função `renderGestorAtividade()` — lê `FERIAS_HISTORICO` filtrando pelos `idsPermitidos` (colaboradores do gestor logado), ordenado por `criado_em DESC`.

Chamada em:
- `renderGestorAtencao()` (após `renderGestorAlerts`)
- `gestorEnviarSolicitacao()` (após enviar)
- Após aprovar/recusar no RH (`if (typeof renderGestorAtividade === 'function') renderGestorAtividade()`)

Estado colapsável: variável `_gestorAtivAberto` (booleana, padrão `true`).

## Histórico RH no drawer Gestor — saldo e chip (`_renderGsolHistoricoRH`)

A função `_renderGsolHistoricoRH` (linha ~8988) renderiza os blocos de PA no drawer do Gestor e tem **seu próprio cálculo local de saldo** — independente de `gestorSaldoPeriodo`. Ambos devem ser mantidos em sincronia.

### Cálculo de saldo (corrigido 2026-09-11)

```js
const abono       = Number(row.abono_pecuniario) || 0;
const antecipados = Number(row.dias_antecipados) || 0;
const usados = lancamentos.reduce((s, l) => s + (Number(l.dias) || 0), 0);
const saldo  = diasDir - usados - abono - antecipados;
```

**Bug original:** `antecipados` não era subtraído → bloco do PA mostrava 30d enquanto o header do drawer (via `gestorSaldoPeriodo`) mostrava 28d.

### Chip "Dias antecipados ao PA anterior"

Quando `antecipados > 0`, exibir chip laranja após `${abonoRhHtml}` no template:

```js
const antecipHtml = antecipados > 0
  ? `<div style="padding:6px 12px 0;"><span style="display:inline-flex;align-items:center;gap:5px;padding:3px 8px;border-radius:5px;background:#FFF7ED;border:1px solid #FED7AA;font-size:11px;color:#C2410C;font-weight:600;">Dias antecipados ao PA anterior · ${antecipados}d</span></div>`
  : '';
```

Analogia: chip roxo para `abono_pecuniario`, chip laranja para `dias_antecipados`.

### Quando PAs sem lançamentos aparecem no drawer

`paMap` é construído a partir de lançamentos — PAs sem lançamentos (`dias1=0`) **não entram** no `paMap`. Porém o PA ainda aparece no drawer quando `mostrarSolicitar=true` (saldo>0, PA já iniciou, sem solicitação pendente), pois `periodos` vem de `GESTOR_PERIODOS` (todos os PAs).

### Prioridade de nota (`_renderGsolHistoricoRH`)

A nota de cada lançamento segue esta cadeia de prioridade (apenas no primeiro lançamento do PA, `li === 0`):

```js
const _notaTxt = li === 0
  ? (l.nota || l._obsGestor || _rhObsMap.get(l.inicio) || row.obs_gestor || row.nota_livre || row.nota || null)
  : null;
```

- `l.nota` — campo mapeado de `nota1`/`nota2` (fonte primária, visível também na visão RH)
- `l._obsGestor` — `obs_gestor` da row Supabase (fallback)
- `_rhObsMap` — mapa construído a partir de `COLABORADORES` (fallback quando Gestor abre direto, sem o array RH carregado)
- `row.obs_gestor`, `row.nota_livre`, `row.nota` — fallbacks adicionais

**Regra:** nunca trocar `l.nota` por `l._obsGestor` como fonte primária — são colunas diferentes e só `nota1`/`nota2` refletem o que o RH vê.

## Acordos / Gozo Real (feature ativa)

A coluna `realizacoes` (JSONB) na tabela `ferias` armazena a lista de utilizações reais do período de férias, separada do período oficial homologado.

### Estrutura de cada item

```js
{
  saida:   'YYYY-MM-DD',  // data de saída real
  retorno: 'YYYY-MM-DD',  // data de retorno real
  dias:    14,            // dias efetivamente gozados
  lancIdx: 0,             // índice do lançamento ao qual pertence (0 = p1, 1 = p2; null = p1 por default)
  obs:     'texto livre', // observação opcional
}
```

### Cálculo de saldo por lançamento

```js
const gozosDoLanc = realizacoes.filter(rx =>
  Number(rx.lancIdx) === lancIdx || (lancIdx === 0 && rx.lancIdx == null)
);
const totalGozado = gozosDoLanc.reduce((s, rx) => s + Number(rx.dias), 0);
const saldoPeriodo = (l.dias || 0) - totalGozado; // saldo restante
```

### Funções de persistência

- `sbPatch('ferias', 'id=eq.'+sbId, { realizacoes: [...] })` — salva a lista completa substituindo o JSONB
- Persistência ocorre no Supabase REST; `reg.realizacoes` local é atualizado após cada operação

### UI no drawer RH

- Ícone de "acordo" (calendário) em cada lançamento; muda de estado (neutro / ativo / completo)
- `temGozos` → renderiza seção com barra de progresso + lista colapsável. **Quando `!temGozos`, a seção inteira não é renderizada** (div vazia não aparece)
- `!temGozos` + IS_RH → abre form inline para criar primeiro acordo
- **Ícone de calendário chama `toggleGozoLista`** (não `toggleGozoSecao`) — expande/colapsa apenas os itens, mantendo a barra de progresso visível
- `toggleGozoLista(sbId, lancIdx)` — expande/recolhe lista de itens (`hist-lista-${sbId}-${lancIdx}`) + gira chevron (`hist-chev-${sbId}-${lancIdx}`)
- `toggleGozoSecao(sbId, lancIdx)` — ainda existe mas **não é mais usado pelo ícone**; usado internamente
- `expandirGozoHist(sbId, lancIdx)` — abre form inline para novo acordo; também expande a lista
- `fecharGozoHist(sbId, lancIdx)` — fecha e recolhe se vazio
- `salvarGozoHist(key, sbId, lancIdx)` — valida e adiciona item à lista; PATCH Supabase
- `removerGozoHist(key, sbId, lancIdx, gi)` — remove item pelo índice; PATCH Supabase
- `abrirEditGozo(key, sbId, lancIdx, gi)` — edita item existente inline
- Botão "Adicionar" só aparece quando `saldoPeriodo > 0` (oculto em períodos concluídos)
- Lista de itens colapsada por padrão; `_gozoExpanded` Set controla estado; entradas `pendente_gestor` forçam expansão
- Ponto âmbar no cabeçalho do PA quando há pendência (saldo não zerado com acordo)

### Saldo destacado no cabeçalho do PA (drawer RH e Gestor)

Mesmo padrão nas duas visões — número grande bold com cor semântica:

```js
// saldo <= 0 → verde (#10B981); saldo <= 5 → âmbar (#F59E0B); saldo > 5 → azul (#1570EF)
const _saldoNumColor = saldo <= 0 ? '#10B981' : saldo <= 5 ? '#F59E0B' : '#1570EF';
// HTML:
`<span style="font-size:10px;color:var(--text-ter);font-weight:500;">Saldo</span>
 <span style="font-size:15px;font-weight:800;line-height:1;color:${_saldoNumColor};">${saldo}d</span>
 <span style="font-size:10px;color:var(--text-ter);">de ${totalDias}d</span>`
```

**Estilo do collapse difere entre visões** (comportamento igual, visual distinto):
- RH: chevron integrado na linha de progresso (interface densa/técnica)
- Gestor: pill azul explícito "N gozos registrados" (interface mais guiada)

### Leitura no `processGestorFerias`

`row.realizacoes` também é processado para a visão Gestor — cada item vira lançamento com `status:'gozado'`.

## Modal arrastável (Drawer RH e Drawer Gestor)

Tanto o drawer do RH quanto o modal do gestor são arrastáveis pela barra do cabeçalho.

- Evento `mousedown` no cabeçalho inicia drag; `mousemove` no `document` atualiza `modal.style.left/top`; `mouseup` encerra
- Modal RH: `#drawer` — arrastável + botão de reset de posição no cabeçalho
- Modal Gestor: mesmo padrão (adicionado em 9889a5f)
- Classe `.dragging` aplicada durante o arraste (desativa seleção de texto)
- Posição não é salva — volta ao centro em cada nova abertura

## Deduplicação de PAs em `processGestorFerias`

**Chave de dedup:** `colaborador_id + ano` (usando `row.ano`), com fallback para `pa_inicio` ou `row.id`.

```js
const _pKey = `${row.colaborador_id}|${row.ano || row.pa_inicio || row.id}`;
```

Quando há duplicata:
1. Lançamentos do row duplicado são vinculados ao `periodo_id` do sobrevivente
2. `obs_gestor` do row duplicado prevalece se preenchido (tende a ser mais recente)
3. Status é normalizado antes de criar o lançamento

**Por quê `row.ano` e não `row.pa_inicio`:** dois rows do mesmo PA podem ter datas `pa_inicio` ligeiramente diferentes (ex: ajuste retroativo), mas `ano` é estável — usar `pa_inicio` como chave causava merge incorreto de PAs de anos diferentes.

### Ordenação determinística antes da dedup (commit 3c89065, 2026-10-09)

**Problema:** a query Supabase retorna rows sem garantia de ordem dentro do mesmo `colaborador_id|ano`. O survivor era escolhido pelo first-come-first-served da iteração, o que podia selecionar um registro secundário (ex: `Alteracao_Solicitada` com realizacoes vazias) em vez do registro principal (`Aprovado` com lançamentos e realizacoes).

**Fix:** sort determinístico aplicado ANTES do loop de dedup em `processGestorFerias`:

```js
const _pgStatusPrio = s => ({'aprovado':0,'concluído':0,'concluido':0,'gozado':0,'agendado':0,
  'solicitado':1,'pendente':1,
  'alteracao_solicitada':2,'cancelamento_solicitado':2,
  'rejeitado':3,'cancelado':3,'descartado':3}[(s||'').toLowerCase()] ?? 2);
const _pgHasLancs = r =>
  (r.periodo1_inicio && Number(r.dias1) > 0) ||
  (Array.isArray(r.periodos) && r.periodos.some(p => p.inicio && Number(p.dias) > 0));
const _rows = [...rows].sort((a, b) => {
  const pA = _pgStatusPrio(a.status), pB = _pgStatusPrio(b.status);
  if (pA !== pB) return pA - pB;
  const lA = _pgHasLancs(a) ? 0 : 1, lB = _pgHasLancs(b) ? 0 : 1;
  if (lA !== lB) return lA - lB;
  return a.id - b.id;
});
_rows.forEach(row => { ... }); // era: rows.forEach(row => { ... });
```

**Critérios de prioridade (maior → menor):**
1. Status do PA: Aprovado/Gozado (0) > Solicitado (1) > Alteracao_Solicitada (2) > Descartado (3)
2. Tem lançamentos com datas e dias (0 = tem, 1 = não tem)
3. ID menor (registro mais antigo ganha o desempate)

**Impacto em `_feriasRow`:** o survivor agora é sempre o registro mais completo e válido. O campo `_feriasRow` em `GESTOR_PERIODOS` aponta para esse survivor, garantindo que `_gestorColabsComAcordoAndamento` encontre as `realizacoes` corretas.

### Visão RH — `supabaseParaModelo` não deduplica

`supabaseParaModelo` cria um `registro` por row do Supabase sem dedup. O drawer RH filtra apenas por `r.status !== 'Descartado'`. Portanto, um PA duplicado com outro status (ex: `Alteracao_Solicitada`) apareceria duas vezes no drawer.

**Solução adotada:** manter rows secundárias como `Descartado` no banco — o filtro existente as exclui sem mudança de código. Não tentar dedup em `supabaseParaModelo` sem análise de impacto abrangente.

### Incidente Victor Hugo (mat.402) — out/2026

- Registro 1891: Aprovado, lançamentos reais (p1: 11/06 15d, p2: 12/10 15d), realizacoes com gozo parcial
- Registro 1893: criado como duplicata, status `Alteracao_Solicitada`, sem lançamentos, `obs_gestor` com JSON da solicitação (mudança de 12/10 → 13/10)

**Sequência de eventos:**
1. 1893 virou survivor do dedup (ordem não determinística da query) → `_feriasRow = 1893`
2. `_gestorColabsComAcordoAndamento` lia `realizacoes` de 1893 (vazia) → Victor Hugo não aparecia no card "Acordos em andamento"
3. No drawer RH, ambos (1891 + 1893) passavam pelo filtro `status !== 'Descartado'` → PA 2026 duplicado

**Correção aplicada (2026-10-09):**
1. Commit 3c89065: ordenação determinística em `processGestorFerias` → 1891 agora é sempre o survivor
2. PATCH no banco: `ferias WHERE id=1893 SET status='Descartado'` — resolveu a duplicidade visual no RH sem alterar código

**Status final:** 1891 = survivor ativo; 1893 = Descartado (dados preservados no banco, incluindo `obs_gestor` com a intenção da solicitação e registros em `ferias_historico`)

### Pendências arquiteturais registradas

- **`_rhEhRecente` — entrada órfã:** quando o `ferias_id` de uma entrada de `ferias_historico` aponta para um registro `Descartado`, o botão "Analisar" aparece mas falha. Correção proposta e aprovada conceitualmente (guard `_feriasExiste`) — aguardando implementação.
- **`lancIdx` heurístico:** `l.id.endsWith('-p2') ? 1 : 0` em `_gestorColabsComAcordoAndamento` — pode causar subdetecção de acordos em edge cases. Correção estrutural pendente (não urgente).
- **Proteção contra criação de PAs duplicados:** `rhCriarNovoPa` e `autocriarPasFaltantes` não verificam PAs existentes antes de criar — avaliação de guard futura, separada.
- **Dedup em `supabaseParaModelo`:** avaliar proteção arquitetural para tornar a visão RH resiliente a duplicatas residuais no banco, sem alterar comportamento atual.

## Normalização de status

Em `processGestorFerias`, o status do row é normalizado antes de virar lançamento:

```js
const _stNorm = (_rowSt === 'pendente' || _rowSt === 'solicitado') ? 'solicitado'
              : (_rowSt === 'rejeitado') ? 'recusado'
              : (_rowSt === 'concluído' || _rowSt === 'concluido') ? 'gozado'
              : _rowSt;
```

**Regra:** `'concluído'` e `'concluido'` (com ou sem acento) são normalizados para `'gozado'`. Nunca usar `'concluído'` em comparações de status — sempre `'gozado'`.

## "Em férias hoje" na Visão Gestor

```js
window._gestorEmFeriasHoje = emFeriasHoje.map(c => String(c.id));
```

Array de IDs de colaboradores em férias hoje, populado durante `renderGestorAtencao`. Usado para destacar linhas e compor o card KPI.

## Filtro setor/empresa na Visão RH

O dropdown de setor/empresa na aba Lista Anual usa `MultiSelect` com instâncias independentes:
- `msEmpresaLista` + `msSetorLista` para a Lista Anual
- `msEmpresaCal` + `msSetorCal` para o Calendário

**Contagem "Todos":** ao contar colaboradores para o filtro, o total inclui colaboradores sem setor/empresa definido — não restringir apenas aos que possuem o campo preenchido.

## Fluxo Gestor → RH: solicitação de gozo (`pendente_gestor`)

O Gestor pode solicitar o registro de dias de gozo real para lançamentos com saldo pendente. A solicitação fica aguardando aprovação do RH.

### Status especial em `realizacoes`

```js
// Entrada salva pelo Gestor ao solicitar gozo
{
  saida:   'YYYY-MM-DD',
  retorno: 'YYYY-MM-DD',
  dias:    8,
  lancIdx: 0,
  obs:     'Solicitado pelo gestor: Nome — obs opcional',
  status:  'pendente_gestor',   // ← diferencia de gozo confirmado
}
```

### Regra crítica: `pendente_gestor` NÃO é lançamento autônomo

Em `_renderGsolHistoricoRH` (Gestor), o filtro de lançamentos **exclui** `pendente_gestor`:

```js
const lancamentos = GESTOR_LANCAMENTOS.filter(l =>
  String(l.colaborador_id) === String(c.id) &&
  String(l.periodo_id) === String(per.id) &&
  l.status !== 'gozado' &&
  l.status !== 'pendente_gestor'   // ← obrigatório: evita bloco duplicado
);
```

Entradas `pendente_gestor` são renderizadas **somente** dentro do `gozoHtml` do lançamento pai (via `row.realizacoes`).

### Funções de aprovação/rejeição (RH)

```js
rhAprovarGozoPendente(colabKey, sbId, lancIdx, saida)
// Remove o campo `status` da entry → gozo efetivado
// Registra 'gozo_aprovado' em ferias_historico via _logAtiv
// Atualiza Atividades recentes do RH e do Gestor

rhRejeitarGozoPendente(colabKey, sbId, lancIdx, saida)
// Remove a entry inteira da lista realizacoes
```

**Padrão de error handling obrigatório** (separar PATCH de re-render):
```js
try {
  await sbPatch('ferias', `id=eq.${sbId}`, { realizacoes: nova });
} catch(e) { toast(_erroApi(e), 'erro'); return; }
reg.realizacoes = nova;
try { renderDrawerHistorico(colab); } catch(_) {}
try { renderMetricas(); } catch(_) {}
const _gozoAprov = nova.find(rx => Number(rx.lancIdx) === Number(lancIdx) && rx.saida === saida);
if (colab?._sbColabId) try { await _logAtiv(sbId, colab._sbColabId, 'gozo_aprovado', perfil.nome || 'RH', { saida, dias: _gozoAprov?.dias ?? null, lancIdx: Number(lancIdx) }); } catch(_) {}
renderRhAtividade();
if (typeof renderGestorAtividade === 'function') renderGestorAtividade();
toast('✓ Gozo aprovado e registrado!');
```
**Por quê (separar PATCH de re-render):** erros na re-renderização (JS, não Supabase) eram capturados pelo mesmo catch e exibiam "Erro ao salvar" mesmo quando o PATCH havia funcionado.

**Por quê (`_logAtiv` em `grhEnviarSolicitarGozo` e `rhAprovarGozoPendente`, corrigido 2026-09-28):** o fluxo "Gestor solicita gozo → RH aprova" não registrava eventos em `ferias_historico`, fazendo Atividades recentes e Histórico ficarem vazios. A correção adicionou `_logAtiv('gozo_solicitado')` após o PATCH do Gestor e `_logAtiv('gozo_aprovado')` após a aprovação do RH, reutilizando a mesma infraestrutura dos outros fluxos.

### Contagem de pendentes

`countGozoPendentes()` — varre `COLABORADORES[].registros[].realizacoes` somando entradas com `status === 'pendente_gestor'`. Somado ao `getPendentes().length` em todas as métricas/KPIs.

### Botão "+ Solicitar gozo" (Gestor)

Aparece no lançamento quando `showPend && !jaSolGozoPend`. Ao clicar, abre form inline via `grhToggleSolicitarGozo(perId, lancIdx)`.

Função de envio: `grhEnviarSolicitarGozo(perId, lancIdx, colabId, realLancIdx)` — faz PATCH em `ferias.realizacoes` com a nova entry `pendente_gestor`.

### isActivePa — regra de exibição do botão Solicitar

```js
const isActivePa = (per.pa_inicio || '') <= hoje;
// PA já iniciou — pode ser vencido (usuário consegue solicitar saldo retroativo)
```
PAs futuros (pa_inicio > hoje) não exibem o botão. PAs vencidos com saldo exibem normalmente.

## Drawer Gestor — aba "Férias" (ex-"Histórico RH")

- Aba renomeada de "Histórico RH" para **"Férias"**
- Aba "Solicitações" está **oculta** (`style="display:none;"`) — não excluída, para testes
- Footer com botões "Nova solicitação" / "Histórico" também oculto
- `gestorAbrirSolicitacoes` abre direto na aba `'rh'` (não `'sol'`)

## Drawer Gestor — gozos colapsados

Os itens de gozo real ficam colapsados por padrão na visão do Gestor. Toggle via pill azul:

```js
function gsolToggleGozoLista(perId, lancIdx) {
  const lista = document.getElementById(`gsol-lista-${perId}-${lancIdx}`);
  const abrindo = lista.style.display === 'none';
  lista.style.display = abrindo ? '' : 'none';
  const chev = document.getElementById(`gsol-chev-${perId}-${lancIdx}`);
  if (chev) chev.style.transform = abrindo ? 'rotate(180deg)' : '';
}
```

IDs: `gsol-lista-${per.id}-${lancIdx}` (div colapsável) e `gsol-chev-${per.id}-${lancIdx}` (ícone chevron).

O chip **"Pendente de gozo · Xd"** sempre visível. Entradas `pendente_gestor` forçam expansão automática.

## Drawer RH — gozos colapsados

Lista de itens de gozo colapsada por padrão com chevron na linha de progresso:

```js
function toggleGozoLista(sbId, lancIdx) {
  const lista = document.getElementById(`hist-lista-${sbId}-${lancIdx}`);
  // toggle display + chevron rotate
}
```

IDs: `hist-lista-${sbId}-${lancIdx}` e `hist-chev-${sbId}-${lancIdx}`.

- Entradas `pendente_gestor` forçam expansão automática (`_temPend`)
- Botão "Adicionar" só aparece quando `saldoPeriodo > 0`
- `expandirGozoHist` também expande a lista ao abrir o form

## Saldo destacado no cabeçalho do PA (Gestor drawer)

O número de saldo usa tipografia maior e cor semântica:

```js
// saldo <= 0 → verde (concluído); saldo <= 5 → âmbar (crítico); saldo > 5 → azul (normal)
`<span style="font-size:15px;font-weight:800;${saldo<=0?'color:#10B981;':saldo<=5?'color:#F59E0B;':'color:#1570EF;'}">${saldo}d</span>`
```

Label "Saldo" e "de 30d" ficam em cinza pequeno (`font-size:10px; color:var(--text-ter)`).

## Lançamento RH — comportamento pós-confirmação (atualizado 2026-09-08)

### Drawer permanece aberto após confirmar lançamento

`confirmarDrawerLancamento` (função principal do botão "Confirmar lançamento"):

```js
// Salvar key ANTES do renderAll — renderAll fecha o drawer
const _keyParaReabrir = _drawerKey;
try { renderAll(); } catch(_) {}
if (_keyParaReabrir) try { _abrirDrawerInterno(_keyParaReabrir); } catch(_) {}
```

**Regra crítica de ordem:** `renderAll()` sempre antes de `_abrirDrawerInterno()`. Inverter a ordem faz o renderAll fechar o drawer recém-aberto.

**Por quê não usar só `renderDrawerHistorico`:** essa função atualiza apenas o conteúdo interno do drawer — não reabre o drawer se ele foi fechado por `renderAll`. É necessário chamar `_abrirDrawerInterno` para recolocar a classe `open`.

### Observação salva no banco

Campo `dMotivo` (textarea "Observação") capturado como `mot`. Incluído no PATCH como `nota1` ou `nota2` conforme o slot:

```js
const campo = reg.lancamentos.length === 0
  ? { periodo1_inicio: ini, periodo1_fim: fim, dias1: dias, nota1: mot || null, status: 'Aprovado' }
  : { periodo2_inicio: ini, periodo2_fim: fim, dias2: dias, nota2: mot || null, status: 'Aprovado' };
```

Objeto em memória também recebe a nota:
```js
reg.lancamentos.push({ inicio: ini, fim, dias, nota: mot || null });
```

Exibição: `l.nota` — aparece como `· texto` na linha do lançamento no drawer e no print/PDF.

## Validação de campos de data — ano máximo 4 dígitos

Listener global (capture phase) intercepta todos os inputs em campos `type="date"` não-readonly e trunca o ano se ultrapassar 4 dígitos:

```js
document.addEventListener('input', function(e) {
  if (e.target.type !== 'date' || e.target.readOnly) return;
  const parts = (e.target.value || '').split('-');
  if (parts[0] && parts[0].length > 4) {
    parts[0] = parts[0].slice(0, 4);
    e.target.value = parts.join('-');
  }
}, true);
```

Cobre todos os formulários do módulo (lançamento, edição, gozo real, filtros) sem precisar adicionar `oninput` campo a campo.

## Colaborador sem PA no módulo Férias

O módulo exibe apenas colaboradores que têm pelo menos um registro na tabela `ferias`. Colaborador ativo em `colaboradores` mas sem row em `ferias` aparece no autocomplete mas mostra "Todos 0" na lista.

**Solução:** criar PAs via script Python direto no Supabase:

```python
import urllib.request, json
SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co'
KEY = '<SB_SECRET_KEY>'  # chave secreta — ver memory supabase_config.md
headers = {'apikey': KEY, 'Authorization': 'Bearer ' + KEY,
           'Content-Type': 'application/json', 'Prefer': 'return=representation'}

# Campos mínimos obrigatórios (nunca incluir dias_direito):
pa = {'colaborador_id': <id>, 'matricula_colaborador': '<mat>',
      'ano': <ano_pa_fim>, 'pa_inicio': 'YYYY-MM-DD', 'pa_fim': 'YYYY-MM-DD', 'status': 'Aprovado'}
req = urllib.request.Request(SB_URL + '/rest/v1/ferias', headers=headers,
                              data=json.dumps(pa).encode(), method='POST')
```

`autocriarPasFaltantes()` (chamado no carregamento) só estende PAs a partir de um registro existente — se não houver nenhum, cria manualmente todos os PAs (do PA inicial até o vigente).

**Caso Cleber Pastorelli (2026-09-08):** dois vínculos distintos:
- mat.229 / id=1966 — Matriz, admissão 2014-03-08 → PAs 2020–2026 já existiam
- mat.208 / id=1796 — Paranavaí, admissão 2023-10-01 → PAs criados manualmente (ids 1877, 1878, 1879)
Ambos aparecem separadamente na lista (vínculos distintos, comportamento correto).

## Banner de PA ativo fora da área visível do drawer (2026-09-09)

**Contexto:** `getRegistroParaLancar` retorna o **PA mais antigo com saldo > 0** (regra CLT — esgota o mais velho primeiro). Quando esse PA é antigo (ex: PA 2022 com 24d de saldo), o botão "+ Lançar" aparece lá embaixo no drawer, fora da área visível. O RH vê apenas PAs recentes sem botão e conclui que "o botão sumiu".

**Diagnóstico:** Se o botão "+ Lançar" parece desaparecer para um colaborador, verificar se há PAs mais antigos na rolagem do drawer com saldo > 0.

**Fix implementado:** Banner âmbar no topo de `#drawerHistorico` quando `regParaLancar` não é o primeiro PA da lista (regs reversed = mais recente primeiro):

```js
const paAtivoNaoEhOPrimeiro = regParaLancar && regs.length > 0
  && String(regs[0]._sbId) !== String(regParaLancar._sbId);
const bannerPaAtivo = (IS_RH && paAtivoNaoEhOPrimeiro) ? `
  <div onclick="document.getElementById('pa-block-${regParaLancar._sbId}')
                  ?.scrollIntoView({behavior:'smooth',block:'center'})"
       style="...cursor:pointer;...background:#FFFBEB;border:1.5px solid #FDE68A;...">
    ⚠️ PA ${regParaLancar.ano} tem ${calcSaldo(regParaLancar)}d de saldo pendente
    — clique para ir ao período ativo
  </div>` : '';
```

Cada bloco de PA tem `id="pa-block-${r._sbId}"` para o scroll funcionar. Banner só aparece na visão RH.

## Relatório Mensal de Férias — funções e regras (2026-09-09)

### Funções

| Função | Responsabilidade |
|---|---|
| `_getDadosRelatorio()` | Lê `COLABORADORES`, filtra pelo mês selecionado, retorna `{ linhas, mesLabel }` |
| `_SETOR_CORES` | Map de setor normalizado → `{ bg, text }`. Chave: `_normKey(setor)` |
| `_corSetor(setor)` | Retorna `{ bg, text }` via `_SETOR_CORES`; fallback `#f8fafc`/`#111` |
| `_fmtData(str)` | Converte `YYYY-MM-DD` → `DD/MM/YYYY` |
| `_buildRelatorioHTML(linhas, mesLabel, opts?)` | Gera HTML para **PDF/visualização**: ícone 📅, cabeçalho azul escuro, separador por empresa, legenda com bolinhas CSS, footer `position:fixed` |
| `_buildExcelHTML(linhas, mesLabel, opts?)` | Gera HTML para **Excel**: sem emoji, sem `position:fixed`, legenda em células coloridas, **todos os estilos inline** (Excel ignora `<style>`) |
| `exportarRelatorioPDF()` | Abre nova aba com `_buildRelatorioHTML` |
| `exportarRelatorioExcel()` | Gera blob `.xls` com `_buildExcelHTML` |

### Campo empresa

`c.empresa` (não `c.empresaRegistro`) é o campo correto na camada de dados do módulo férias. `c.empresaRegistro` nunca é preenchido neste módulo.

### Parâmetro `opts.hideColumns` (adicionado 2026-10-13)

Ambos os builders aceitam um terceiro parâmetro opcional `opts = { hideColumns: [...] }`:

```js
// Keys disponíveis:
// 'empresa' | 'setor' | 'matricula' | 'nome' | 'cargo' | 'dias' | 'inicio' | 'fim'

// Visão RH — sem opts, comportamento intacto:
_buildRelatorioHTML(linhas, mesLabel)
_buildExcelHTML(linhas, mesLabel)

// Visão Gestor (escala por período):
_buildRelatorioHTML(linhas, mesLabel, { hideColumns: ['empresa','setor','matricula'] })
_buildExcelHTML(linhas, mesLabel, { hideColumns: ['empresa','setor','matricula'] })
```

**Comportamento interno:**
- Larguras de colgroup redistribuídas proporcionalmente às colunas visíveis
- Separador `emp-sep` suprimido quando `'empresa'` está oculta
- Legenda de setores no Excel suprimida quando `'setor'` está oculta (evita células deslocadas ao final da planilha)
- `colspan` do separador usa `nCols` (contagem dinâmica)

### Regra crítica — Excel

**Excel ignora completamente a tag `<style>`** — todos os estilos devem ser `style=""` inline nos elementos. Usar `_buildExcelHTML` separada do PDF por esse motivo. Nunca reusar `_buildRelatorioHTML` no Excel.

O arquivo gerado é `.xls` com MIME `application/vnd.ms-excel` — o Excel abre mas exibe aviso de formato. Isso é esperado; o usuário clica "Sim" para continuar.

### Cores por setor (`_SETOR_CORES`)

| Setor(es) | bg | text |
|---|---|---|
| Matriz Vendas / Projetos | `#FFFF00` | `#000` |
| Financ / TI / Marketing | `#FFFACD` | `#000` |
| CD | `#90EE90` | `#000` |
| Compras / E-commerce | `#FFB6C1` | `#000` |
| Porto Rico | `#E6E6FA` | `#000` |
| PVAÍ | `#FFDAB9` | `#000` |
| RED | `#000000` | `#fff` |
| Atelier | `#D3D3D3` | `#000` |
| Aprendiz | `#C0C0C0` | `#000` |
| Sarandi / SDI | `#ADD8E6` | `#000` |

### Layout do relatório RH (PDF)

- Cabeçalho: ícone 📅 + título maiúsculas + subtítulo de contagem/data
- Tabela: `table-layout:fixed`, header `#1e3a5f` branco, colunas com `colgroup` percentuais
- Separador por empresa: `<tr class="emp-sep">` com fundo `#f1f5f9`
- Colunas coloridas: Empresa, Setor, Matrícula, Nome, Início, Fim (cor do setor); Cargo e Dias brancos
- Legenda: `position:fixed;bottom:8mm` com bolinhas CSS + nome do setor
- Footer: `FÉRIAS — MÊS | 1 de 1` alinhado à direita

## Visão Gestor — abas e exportação (2026-09-09)

### Estrutura das abas

- **Abas:** Painel | Timeline — aba "Relatório" removida (padrão de mercado: gestor exporta a lista, não gera relatório separado)
- KPIs (`gestorAlerts`, `gestorAtividade`) ficam **fora** do card de abas — sempre visíveis em qualquer aba ativa
- Abas dentro do card principal usando `.proto-view-tabs` — mesmo padrão da visão RH
- `setGestorTab(tab)` itera apenas `['painel','timeline']`

### Exportação do Gestor

**Botão Exportar** — dropdown com duas opções:
- "Visualizar PDF" → `gestorExportarPDF()` — abre nova aba com relatório visual (A4 landscape)
- "Exportar Excel" → `gestorExportarExcel()` → `_gestorExportarExcelXlsx()` (async) — baixa `.xlsx` via ExcelJS
- `toggleGestorExportMenu()` controla abertura/fechamento (fecha ao clicar fora via `document.addEventListener`)

**PDF (8 colunas):** Nome | Cargo | Ano PA | Período Aquisitivo | Férias Início | Férias Fim | Saldo | Situação
**Excel (9 colunas):** Setor | Nome | Cargo | Ano PA | Período Aquisitivo | Férias Início | Férias Fim | Saldo (d) | Situação

### Escala por período — Gestor (commits 927407a + aa41903 + e0f8818 + b850a82 + a22894e, 2026-10-13)

Exportação específica do Gestor para gerar escala de férias de um mês selecionado (quem vai estar de férias em outubro, por exemplo), para enviar ao grupo.

**Modal:** `#modalEscalaGestor` — input mês (`escalaGestorMes`) + botões PDF/Excel.
**Botão de acesso:** botão "Escala por período" no header da visão Gestor (aciona `abrirModalEscalaGestor()`).

**Funções:**

| Função | Descrição |
|---|---|
| `_getDadosEscalaGestor()` | Filtra `GESTOR_LANCAMENTOS` pelo mês selecionado (status `aprovado`/`agendado`, `!_isRealizacao`). Retorna `{ linhas, mesLabel }` |
| `gestorEscalaPDF()` | Chama `_buildRelatorioHTML(linhas, mesLabel, { hideColumns: ['empresa','setor','matricula'] })` |
| `gestorEscalaExcel()` | Chama `_buildExcelHTML(linhas, mesLabel, { hideColumns: ['empresa','setor','matricula'] })` |

**Shape de cada item em `linhas` (compatível com os builders RH):**
```js
{ nome, cargo, setor, empresa: c.empresa||c.unidade||'', matricula: c.matricula||'',
  inicio: l.inicio, fim: l.fim, dias: l.dias||'',
  status: l.status capitalizado }
```

**Colunas visíveis no relatório do Gestor:** Nome do Colaborador | Cargo | Dias | Início | Fim (5 colunas — empresa, setor e matrícula ocultos via `opts.hideColumns`).

**Regra da legenda Excel:** quando `setor` está em `hideColumns`, a linha de legenda colorida de setores é suprimida do Excel (evita células "CD", "Logística" etc. aparecendo deslocadas após a última linha de dados).

**Colunas do RH intactas** — `_buildRelatorioHTML` e `_buildExcelHTML` chamados sem `opts` pela visão RH continuam com as 8 colunas originais.

### PDF — regras visuais

- **Título:** `"FÉRIAS DA EQUIPE"` quando múltiplos setores; `"FÉRIAS DA EQUIPE · [SETOR]"` quando apenas 1 setor nas linhas exportadas (usar `[...new Set(linhas.map(l => l.setor))].length`)
- **Separador de setor** (apenas quando múltiplos setores): fundo `#f8fafc`, texto `#64748b`, `font-size:10px`, sem a cor do setor — separadores são discretos, não coloridos
- **Hierarquia de risco por linha** — helper `_riscoPDF(sitKey)`:

| Nível | rowBg | border-left | nomeCor | nomePeso |
|---|---|---|---|---|
| Crítico | `#FFF5F5` | `3px solid #EF4444` | `#7F1D1D` | `800` |
| Atenção | `#FFFBEB` | `3px solid #F59E0B` | `#78350F` | `700` |
| No radar | `#F0F6FF` | `3px solid #93C5FD` | `#1E3A8A` | `600` |
| — | `#fff` | `transparent` | `#1a1a2e` | `500` |

- **Situação:** badge pill colorido via `_sitBadge(sitKey, situacao)` — `<span>` com background/color/border-radius inline
- **Saldo:** cor semântica via `_saldoCor(saldo)` — verde ≤0d, âmbar ≤5d, azul >5d
- **Footer fixo** (`position:fixed;bottom:8mm`): legenda de risco com quadradinhos coloridos (Crítico / Atenção / No radar)
- **Cabeçalho** (`#1e3a5f`, texto branco, bold uppercase): `table-layout:fixed` com `colgroup` percentual; 8 colunas; `border-radius:6px` na tabela
- **Filtros respeitados:** cargo e gestor ativos. Busca (`gestorBusca`) **ignorada** — filtro de navegação, não exportação

### Excel — regras visuais

- **Setor (col A):** colorido com `bg`+`text` do `_corSetor` — identifica o grupo visualmente e é filtrável
- **Hierarquia de risco** — helper `_riscoEx(sitKey)`: mesmas cores do PDF (`rowBg`, `borderCol`, `nomeCor`, `nomeBold`); borda esquerda `style:'medium'` na col A via ExcelJS
- **Nome (col B):** cor e bold do risco (`risco.nomeCor`, `risco.nomeBold`)
- **Saldo (col H):** texto colorido via `_saldoCor(saldo)` + sufixo `d` (string, não número)
- **Situação (col I):** texto bold colorido via `_sitCor(sitKey)`
- **Zebra sutil:** linhas sem risco alternam branco / `#F8FAFC`
- **Cabeçalho (linha 3):** `#1E3A5F` branco bold, AutoFilter `A3:I3`, freeze 3 linhas
- **Linha 1:** título "FÉRIAS DA EQUIPE" fundo `#1E3A5F`, altura 30
- **Linha 2:** subtítulo contagem + data gerado, fundo `#F8FAFC`, texto `#64748B`
- **ExcelJS lazy-load:** `cdn.jsdelivr.net/npm/exceljs@4.4.0/dist/exceljs.min.js` — carregado apenas na primeira exportação
- **`argb(hex)`:** expande shorthand antes de prefixar `FF` — `#000` → `FF000000`, `#fff` → `FFFFFFFF`. Sem expansão, ExcelJS ignora a cor

### Campos comuns (PDF e Excel)

- **Ano PA:** usa `pa.ano` (fonte correta). Fallback `pa.pa_inicio?.slice(0,4)` só se nulo. `semPA`: `fimPrev.slice(0,4)`
- **Período Aquisitivo:** `DD/MM/AAAA → DD/MM/AAAA`. `semPA`: `... (prev.)`
- **Férias Início/Fim:** `_fmtData(lRef.inicio)` / `_fmtData(lRef.fim)`, ou `'—'`
- **Situação com dobra:** `"Crítico · Dobra em DD/MM/AAAA"` — campo `situacao`. `sitKey` = só o nível, para lookup de cor
- **PA do relatório:** lógica isolada em `_stRel` / `_stRelXls` (não altera `gestorPeriodoAtivo`). Prioriza PA com gozo pendente (`paComGozo`); fallback para `gestorPeriodoAtivo`
- **Guards:** `GESTOR_COLABS.length === 0` → toast + return; `linhas.length === 0` → toast + return
- **`_normG`** definida localmente em cada função de exportação — não é global

**Cores de situação** (`_sitBadge` no PDF / `_sitCor` no Excel):

| Situação | text (PDF badge bg / Excel text) |
|---|---|
| Crítico | `#7F1D1D` (bg `#FEE2E2`) |
| Atenção | `#78350F` (bg `#FDE68A`) |
| No radar | `#1E3A8A` (bg `#DBEAFE`) |
| Agendado / Concluído | `#027A48` (bg `#ECFDF3`) |
| Sem agendamento | `#92400E` (bg `#FFFAEB`) |
| Período futuro | `#1849A9` (bg `#EFF6FF`) |

**Nunca usar `gestorExportarCSV`** para o botão principal — função pode existir mas não é chamada pela UI.

## Componente MultiSelect — regras e comportamentos (2026-09-14)

O `MultiSelect` é um dropdown de múltipla seleção com checkboxes, busca interna e botões "Aplicar" / "Limpar". Registrado em `MS_INSTANCES[containerId]`.

### HTML gerado pelo construtor

```html
<div class="ms-wrap" style="display:flex;align-items:center;gap:4px;">
  <button class="ms-btn" id="{id}-btn">
    <span class="ms-btn-label" id="{id}-label">{placeholder}</span>
    <span class="ms-btn-arrow">▼</span>
  </button>
  <button id="{id}-x" style="display:none;">✕</button>   <!-- X externo, aparece com seleção -->
  <div class="ms-dropdown" id="{id}-dd">
    <div class="ms-search"><input id="{id}-search" ...></div>
    <div class="ms-list" id="{id}-list"></div>
    <div class="ms-footer" style="display:flex;gap:6px;justify-content:space-between;">
      <button class="ms-clear">✕ Limpar</button>
      <button class="ms-clear" style="background:var(--blue);color:#fff;">Aplicar</button>
    </div>
  </div>
</div>
```

### Regras críticas de propagação de eventos

- O botão principal (`{id}-btn`) chama `e.stopPropagation()` antes de `msToggle`
- O dropdown (`{id}-dd`) tem `addEventListener('click', e => e.stopPropagation())` — impede que cliques nos checkboxes fechem o dropdown via handler global
- O X externo (`{id}-x`) também tem `stopPropagation` no click

**Por quê:** o `document` tem um listener global que fecha todos `.ms-dropdown.open` em qualquer clique. Sem `stopPropagation` no dropdown, clicar nos checkboxes fecha o combo imediatamente.

### Labels do botão (`_updateBtn`)

| Estado | Label | X externo |
|---|---|---|
| 0 selecionados ou todos | `placeholder` (ex: "Todos os cargos") | oculto |
| 1 selecionado | nome do item | visível |
| 2+ selecionados | `"Cargos: N"` | visível |

O atributo `title` do botão exibe os itens selecionados separados por vírgula (tooltip ao passar o mouse).

### API pública

```js
MS_INSTANCES['id'].getValues()   // [] quando nenhum ou todos selecionados; [...selecionados] nos demais
MS_INSTANCES['id'].setOptions(arr) // atualiza opções (reseta busca, mantém seleção compatível)
MS_INSTANCES['id'].selected      // Set<string> dos valores selecionados
```

### Filtro de cargo na Visão Gestor (`gestorFiltroCargo2`)

Substituiu o `<select>` simples. Declarado como `<div id="gestorFiltroCargo2" style="min-width:160px;position:relative;">`.

Inicialização (dentro de `renderGestorAtencao` / `carregarGestorData`):
```js
if (!MS_INSTANCES['gestorFiltroCargo2']) {
  new MultiSelect('gestorFiltroCargo2', 'Todos os cargos', () => renderGestorAtencao());
}
MS_INSTANCES['gestorFiltroCargo2'].setOptions(cargos);
```

Leitura do filtro:
```js
const filtroCargos = MS_INSTANCES['gestorFiltroCargo2']?.getValues() || [];
if (filtroCargos.length) colabs = colabs.filter(c => filtroCargos.includes(c.cargo));
```

Filtro respeitado também em `gestorExportarPDF` e `gestorExportarExcel` (variável local `cargofs`).

Reset ao carregar novos dados:
```js
if (MS_INSTANCES['gestorFiltroCargo2']) {
  MS_INSTANCES['gestorFiltroCargo2'].selected.clear();
  MS_INSTANCES['gestorFiltroCargo2']._updateBtn();
}
```

---

## Modal "Relatório do mês" — filtros de Setor e Gestor (2026-09-14)

O modal da visão RH (`#modalRelatorio`) ganhou dois novos campos além de Empresa:

```html
<div class="rel-field">
  <label>Setor</label>
  <select id="relSetor"><option value="">Todos os setores</option></select>
</div>
<div class="rel-field">
  <label>Gestor</label>
  <select id="relGestor"><option value="">Todos os gestores</option></select>
</div>
```

Populados em `popularSidebarFiltros()` junto com os demais selects.

- **Setor**: derivado de `COLABORADORES.map(c => c.setor)` (valores únicos, ordem alfabética)
- **Gestor**: busca assíncrona em `param_gestor` (mesma fonte da visão Gestor) — **não** usa `c.gestor` dos colaboradores, para garantir mesma lista e ordem:

```js
sbGet('param_gestor', 'select=apelido&ativo=eq.true&order=ordem').then(pgRows => {
  const gestores = pgRows.map(r => r.apelido).filter(Boolean);
  gestores.forEach(g => { const o = document.createElement('option'); o.value = g; o.textContent = g; relGest.appendChild(o); });
});
```

O filtro em `_getDadosRelatorio()` compara `c.gestor === gestVal` (string exata), por isso é importante que `param_gestor.apelido` e `colaboradores.gestor` usem exatamente o mesmo valor.

`_getDadosRelatorio()` lê os três filtros e combina:
```js
if (empVal  && (c.empresaRegistro||c.unidade||'') !== empVal) return;
if (setVal  && (c.setor||'') !== setVal) return;
if (gestVal && (c.gestor||'') !== gestVal) return;
```

`empLabel` do retorno inclui os filtros ativos combinados (`"Matriz · Matriz Vendas · Gestor: Juninho"` etc.).

---

## `.proto-status-tabs` — scrollbar oculta (2026-09-14)

```css
.proto-status-tabs { overflow-x: auto; scrollbar-width: none; }
.proto-status-tabs::-webkit-scrollbar { display: none; }
```

Suprime as setas ▲▼ nativas que apareciam à direita dos chips de filtro de status sem remover o scroll horizontal em telas estreitas.

---

## Filtros da aba Timeline (visão RH) (2026-09-14)

A Timeline tem dois filtros no canto superior direito do cabeçalho (`div.gantt-nav-filters`):

| ID | Fonte | Comportamento |
|---|---|---|
| `ganttFiltroSetor` | valores únicos de `COLABORADORES[].setor` | repopulado a cada `renderTimeline()`, preserva seleção |
| `ganttFiltroGestor` | `param_gestor` via `sbGet` assíncrono | populado uma vez (`options.length <= 1`), preserva seleção |

Ambos chamam `renderTimeline()` no `onchange` e usam `syncFilterClear` para exibir o botão ✕.

Lógica de filtro em `renderTimeline()` (aplicada antes de montar as linhas):
```js
const ganttGestorFiltro = document.getElementById('ganttFiltroGestor')?.value || '';
const _normGT = s => (s||'').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g,'');
// ...
if (ganttGestorFiltro && _normGT(c.gestor) !== _normGT(ganttGestorFiltro)) return false;
```

Normalização sem acento para tolerância a grafias (`JUNINHO` == `Juninho`).

---

## Dashboard — Design Visual (atualizado 2026-09-15)

### Layout geral do Dashboard

A aba Dashboard (`renderDash()`) gera HTML com esta estrutura:

```
KPI row (4 cards)
Card: Comparativo de férias por ano (renderDashAnoChart)
[flex row gap:16px align-items:stretch]
  Card: Calendário de férias (flex: 0 0 calc(50% - 8px))
  Card: Ausentes por setor   (flex: 0 0 calc(50% - 8px))
Card: Risco de dobra
```

Os dois cards do calendário e de setores têm **largura fixa `calc(50% - 8px)`** e `align-items: stretch` no container para ficarem com a mesma altura.

### Calendário de férias — células com fundo por intensidade + bolinhas por setor

`renderDashCalendar()` — lógica de cada célula:

**Fundo de intensidade** (proporcional ao número de ausentes `n`):
```js
if      (n >= 10) cellBg = '#DBEAFE';  // azul muito suave
else if (n >= 6)  cellBg = '#EFF6FF';
else if (n >= 3)  cellBg = '#F5FAFF';
else if (n >= 1)  cellBg = '#FAFCFF';  // quase branco
else              cellBg = 'transparent';
// numColor sempre '#1e40af' para n > 0
```

**Bolinhas por setor** (abaixo do número da data):
- Uma bolinha por setor único presente naquele dia
- Cor: `corDoSetor(s).borda` — usa `SETOR_COR_FIXA` / `SETOR_CORES_CICLO`
- Máximo 4 bolinhas; excedente exibido como `+N` via `.an-cal-dot-extra`
- Sem legenda de categorias (removida — não há como identificar coletivas vs normais pelo status)

```js
const setoresDoDia = [];
ativos.forEach(c => {
  const ausente = c.registros.some(r => !excluir.has(r.status) &&
    r.lancamentos.some(l => l.inicio <= ds && l.fim >= ds));
  if (ausente) {
    const s = normSetor(c.setor) || c.setor || 'Outros';
    if (!setoresDoDia.includes(s)) setoresDoDia.push(s);
  }
});
```

**Dia de hoje:** `outline: 2px solid #3B82F6; outline-offset: -2px` (não usa background — preserva a cor de intensidade).

**Hover:** `filter: brightness(.93)` — escurece a célula sem alterar a cor.

### `SETOR_COR_FIXA` — tabela completa

```js
const SETOR_COR_FIXA = {
  'Administrativo':  { borda: '#1A3A8F', bg: '#EEF2FF', texto: '#1A3A8F' },
  'Financeiro':      { borda: '#1A3A8F', bg: '#EEF2FF', texto: '#1A3A8F' },
  'RH':              { borda: '#5925DC', bg: '#F4F3FF', texto: '#5925DC' },
  'Logística':       { borda: '#0F5570', bg: '#E0F2F8', texto: '#0F5570' },
  'Comercial':       { borda: '#027A48', bg: '#ECFDF3', texto: '#027A48' },
  'Vendas':          { borda: '#027A48', bg: '#ECFDF3', texto: '#027A48' },
  'Operacional':     { borda: '#92400E', bg: '#FFFAEB', texto: '#92400E' },
  'Produção':        { borda: '#92400E', bg: '#FFFAEB', texto: '#92400E' },
  'TI':              { borda: '#0F5570', bg: '#E0F2F8', texto: '#0F5570' },
  'Marketing':       { borda: '#C01048', bg: '#FFF1F3', texto: '#C01048' },
  'Compras':         { borda: '#5C3317', bg: '#FDF0E5', texto: '#5C3317' },
  'Estoque':         { borda: '#1D4D3B', bg: '#E4F5EF', texto: '#1D4D3B' },
  'Atendimento':     { borda: '#633806', bg: '#FAEEDA', texto: '#633806' },
  'Expedição':       { borda: '#1D4D3B', bg: '#E4F5EF', texto: '#1D4D3B' },
  'CD':              { borda: '#0F5570', bg: '#E0F2F8', texto: '#0F5570' },
  'Ecommerce':       { borda: '#B42318', bg: '#FEF3F2', texto: '#B42318' },
  'Sarandi':         { borda: '#027A48', bg: '#ECFDF3', texto: '#027A48' },
  'Paranavaí':       { borda: '#5925DC', bg: '#F4F3FF', texto: '#5925DC' },
  'Matriz':          { borda: '#1A3A8F', bg: '#EEF2FF', texto: '#1A3A8F' },
};
```

`corDoSetor(setor)` faz match por `includes()` case-insensitive. Setores não mapeados caem em `SETOR_CORES_CICLO` (7 cores, ciclo automático por índice no Map).

### Ausentes por setor — painel direito

Cada linha renderizada em `renderDashCalendar()`:
```js
const cor = corDoSetor(s);
const initials = s.split(/\s+/).slice(0,2).map(w => w[0]||'').join('').toUpperCase().slice(0,2);
// ícone circular 32×32px com iniciais, borda e fundo da cor do setor
// barra horizontal com cor.borda
// número de colaboradores únicos ausentes no mês
// percentual sobre total de ausentes únicos no mês
```

O total de ausentes únicos (`_totalAus`) é calculado como `Set` de todos os `__key` ausentes no mês — não soma por setor (evita dupla contagem de quem ficou em 2 setores no período).

### Cabeçalho do calendário

```html
<div class="an-cal-card-hdr">
  <span class="an-cal-card-hdr-title">Calendário de férias</span>
  <div style="display:flex;align-items:center;gap:6px">
    <button class="an-cal-nav-btn" onclick="dashCalNav(-1)">‹</button>
    <span class="an-cal-nav-label" id="dashCalNavLabel">—</span>
    <button class="an-cal-nav-btn" onclick="dashCalNav(1)">›</button>
  </div>
</div>
```

`dashCalNav(dir)` incrementa `_dashCalMonth` / `_dashCalYear` e chama `renderDashCalendar()`.
`_dashCalLocked` é resetado a `null` a cada navegação.

### CSS das células do calendário (Dashboard)

```css
.an-cal-cell { border-radius: 8px; padding: 8px 4px 6px; min-height: 56px; cursor: pointer;
               display: flex; flex-direction: column; align-items: center; transition: filter .1s; }
.an-cal-cell:hover { filter: brightness(.93); }
.an-cal-cell.empty { background: transparent !important; cursor: default; filter: none !important; }
.an-cal-cell.today { outline: 2px solid #3B82F6; outline-offset: -2px; }
.an-cal-day-num { font-size: 14px; font-weight: 500; color: var(--text); line-height: 1; }
.an-cal-dots { display: flex; gap: 3px; justify-content: center; align-items: center; margin-top: 4px; flex-wrap: wrap; }
.an-cal-dot  { width: 7px; height: 7px; border-radius: 50%; flex-shrink: 0; }
.an-cal-dot-extra { font-size: 9px; font-weight: 700; color: var(--text-sec); line-height: 7px; align-self: flex-end; }
```

## `normSetor(s)` — preservação de siglas (corrigido 2026-09-16)

```js
return r.replace(/\w\S*/g, w =>
  /^[A-Z]{2,4}$/.test(w) ? w
  : w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()
);
```

**Regra:** palavras de 2–4 letras 100% maiúsculas (CD, RH, TI, etc.) são preservadas como estão. Sem essa guarda, `title-case` convertia "CD" → "Cd", quebrando lookups em `SETOR_COR_FIXA` e exibindo "Cd" no painel "Ausentes por setor" do Dashboard.

**`SETOR_COR_FIXA`:** a chave deve ser `'CD'` (maiúscula), não `'Cd'` — qualquer adição futura de setores sigla deve usar maiúsculas.

---

## Visão Gestor — pré-preenchimento do campo de dias (2026-09-16)

`gestorAbrirModal()` agora pré-preenche o campo "Quantidade de dias" com o saldo disponível e exibe hint "máx. X" no label:

```js
document.getElementById('mgDias').max            = saldo;
document.getElementById('mgDiasHint').textContent = saldo > 0 ? `máx. ${saldo}` : '';
document.getElementById('mgInicio').value         = '';
document.getElementById('mgDias').value           = saldo > 0 ? saldo : '';
document.getElementById('mgRetorno').value        = '';
```

HTML do label:
```html
<label>Quantidade de dias <span id="mgDiasHint" style="font-weight:400;color:var(--text-ter)"></span></label>
```

`saldo` = `gestorSaldoPeriodo(pa)` — saldo real do PA, consistente com o valor exibido no drawer.

---

## Dashboard — Card "Risco de Dobra" (atualizado 2026-09-16)

### Estrutura geral

```
[card .an-card .an-row-bottom]
  [cabeçalho flex: título + badge contador N colaboradores ⚠️/✅]
  [flex row gap:24px]
    [SVG donut 250×250 overflow:visible + padding-left:55px]
    [legenda flex:1 min-width:200px]
  [#dashRiscoLista — drill-down por setor]
```

### Dados e cache

`_riscoDadosCompletos` — array de `{ c, dpd, reg }` por colaborador em risco, ordenado por `dpd` ascendente. Critério de seleção do PA (espelha `isRiscoDobra`):
- `saldo > 0`
- `dpd ≤ 180` (via `diasParaDobra`)
- Sem lançamento futuro (`l.fim >= HOJE`)

Armazenado em `window._dashRiscoDados` para reuso em `dashRiscoFiltrar`.

`_riscoSetores` — `Map` de setor → lista de colaboradores, ordenado por quantidade decrescente.

### SVG Donut

| Parâmetro | Valor |
|---|---|
| Raio externo (`_OR`) | 105 |
| Raio interno (`_IR`) | 63 |
| Centro (`_CX`, `_CY`) | 125, 125 |
| ViewBox | 250×250 |
| Stroke | `#fff` 2px entre fatias |
| Fill das fatias | `corSet.borda` (cor sólida escura) |
| Opacidade | 0.88; hover → 1.0 |

Rótulos externos (aparecem para fatias ≥ 6%): linha da borda da fatia + nome do setor (bold 9px) + "X Colab. · XX%" (8px).

Centro do donut: número total (32px 800) + "COLABORADORES" (8px, letter-spacing .08em).

### Legenda

Cada linha da legenda:
- Ícone colorido escuro (`corSet.borda`) à esquerda (36×38px) com emoji do setor
- Fundo claro (`corSet.bg`) na parte direita
- Nome do setor (bold 11.5px, cor `borda`)
- Barra de progresso `flex:1` (fill `borda`)
- Percentual (11.5px bold, cor `borda`) alinhado à direita

`max-width` removido — legenda ocupa todo o espaço disponível (`flex:1`).

### Ícones por setor (`_SETOR_ICONE`)

```js
const _SETOR_ICONE = s => {
  const sl = (s||'').toLowerCase();
  if (sl.includes('cd') || sl.includes('distribui')) return '📦';
  if (sl.includes('compra')) return '🛒';
  if (sl.includes('venda') || sl.includes('comercial')) return '🏪';
  if (sl.includes('matriz') || sl.includes('adm') || sl.includes('financ')) return '🏢';
  if (sl.includes('logist') || sl.includes('expedi')) return '🚚';
  if (sl.includes('rh') || sl.includes('pessoas')) return '👥';
  if (sl.includes('ti') || sl.includes('tech')) return '💻';
  return '📍';
};
```

### `dashRiscoFiltrar(setor)`

Toggle: clicar no mesmo setor fecha o drill-down. Lê de `window._dashRiscoDados` (nunca recalcula).

Cabeçalho do drill-down: `DETALHAMENTO POR UNIDADE — {setor} ({N} Colaboradores) ✕ fechar`

Cada linha: avatar com iniciais + nome/cargo + badge de prioridade (ALTA PRIORIDADE / ATENÇÃO / NO RADAR) + badge de data "📅 Vence em DD/MM/AAAA". Clique abre `abrirDrawer`.

Badges usam `riscoBadgeHtml(dpd, true, dlim)` — mesma função da aba Lista.

---

## Visão Gestor — `gestorPeriodoVigente` (corrigido 2026-09-21)

Função separada de `gestorPeriodoAtivo` para exibir PA Vigente no drawer mesmo quando saldo = 0.

```js
function gestorPeriodoVigente(colaborador_id) {
  const hoje = new Date().toISOString().slice(0,10);
  const periodos = GESTOR_PERIODOS.filter(p => p.colaborador_id === colaborador_id)
    .slice().sort((a, b) => (b.pa_fim||'').localeCompare(a.pa_fim||''));
  const vigente = periodos.find(p => {
    const inicio = p.pa_inicio || '';
    const fim    = p.data_fim_gozo || p.pa_fim || '';
    return inicio <= hoje && (!fim || fim >= hoje);
  });
  if (vigente) return vigente;
  return periodos.find(p => (p.pa_inicio || '') <= hoje) || null;
}
```

**Regra de uso no drawer (`gestorAbrirSolicitacoes`):**

```js
const pa    = gestorPeriodoAtivo(c.id);    // PA com saldo disponível → botão Solicitar
const paVig = gestorPeriodoVigente(c.id);  // PA vigente por data → exibição PA Vigente/Vencimento
const _paBase = pa || paVig;               // base para cálculo de saldo quando saldo=0
const saldo = _paBase ? gestorSaldoPeriodo(_paBase) : 0;
const total = _paBase ? (Number(_paBase.dias_direito) || 30) : 30;
const venc  = paVig?.data_fim_gozo ? gestorFmtData(paVig.data_fim_gozo) : '—';
const paAno = paVig?.pa_fim ? paVig.pa_fim.slice(0,4) : (paVig?.pa_inicio ? paVig.pa_inicio.slice(0,4) : '—');
```

- **`gestorPeriodoAtivo`** permanece inalterado: retorna PA com saldo > 0 — usado para lógica do botão Solicitar e cálculo de saldo
- **`gestorPeriodoVigente`**: retorna PA que cobre a data de hoje (pa_inicio ≤ hoje ≤ data_fim_gozo), sem verificar saldo — usado apenas para exibição de "PA Vigente" e "Vencimento" no drawer
- Motivo: colaboradores com saldo = 0 (ex: férias 100% agendadas) têm PA vigente válido mas `gestorPeriodoAtivo` retorna null → exibia "—" incorretamente

---

## Visão Gestor — abas e permissões (atualizado 2026-09-21)

`setGestorTab(tab)` itera `['painel','timeline','dashboard']` (3 abas — inclui dashboard-gestor).

**Permissões do perfil Gestor (perfil_id=3):**

```json
{
  "ferias": {
    "abas": ["lista", "timeline", "dashboard-gestor"],
    "acoes": ["visualizar", "inserir", "alterar"]
  }
}
```

Todos os gestores usam o mesmo `perfil_id=3` — permissões idênticas, só a equipe difere (via `param_gestor.apelido` = `colaboradores.gestor`). 5 gestores com login ativo: Oriel, Carlos/Juninho, Rafhael, Prata, Madson.

Migration 059 (`migrations/059_perfis_requer_colaborador.sql`): coluna `requer_colaborador` em `perfis`, trigger que exige `colaborador_id` para perfis Gestor e Colaborador.

---

## Dashboard Gestor — 3 blocos (redesign 2026-09-21)

`renderAnalyticsGestor()` monta 3 blocos com helpers locais:

### Helpers

```js
_gdashInitials(nome)   // 2 letras: primeira e última palavra
_gdashAvatar(colab, size)  // img com foto_url ou div colorido com iniciais
_gdashFmt(ds)          // 'DD mmm' ('15 set') a partir de 'YYYY-MM-DD'
_gdashDiasAte(ds)      // dias até a data (pode ser negativo)
```

### Bloco 1 — Situação agora (`_renderGdashSituacao`)

3 cards lado a lado, cada um com borda esquerda colorida:

| Card | Cor borda | Critério |
|---|---|---|
| De férias | `#E24B4A` (vermelho) | `l.inicio <= hoje && l.fim >= hoje` |
| Próximo a sair | `#185FA5` (azul) | `l.inicio > hoje && dias ≤ 60` |
| Retorna em breve | `#3B7D11` (verde) | lançamentos com fim >= hoje, ordenados por fim |

Cada card exibe nomes, datas e contagem de dias — visível sem hover.

### Bloco 2 — Mapa anual (`_renderGdashMapa`)

Grid colaborador × 12 meses. Cores:

```js
const CORES = {
  aprovado:  '#185FA5',   // azul escuro
  solicitado:'#B5D4F4',  // azul claro
  gozado:    '#D3D1C7'   // cinza
};
```

- Colaboradores com períodos acima do separador; `semPeriodo` abaixo (células com borda tracejada)
- Legenda: Aprovado / Solicitado / Gozado / Sem programação

### Bloco 3 — Planejamento

Layout `grid-template-columns: 1fr 240px`:

- **`_renderGdashProximos()`** — próximos 60 dias: `l.inicio > hoje && l.inicio <= limiteStr`; contador grande por linha
- **`_renderGdashSemProg()`** — sem programação: número grande de colaboradores sem lançamento futuro; lista de nomes; caixa âmbar de alerta

### Funções removidas

`_renderGdashAno`, `_renderGdashCal`, `gdashCalNav` — substituídas pelo redesign de 3 blocos.

---

## Visão Diretoria — Panorama Executivo (implementado 2026-09-22)

### Arquitetura

Perfil `diretoria` recebe uma experiência completamente separada da visão Gestor e da visão RH.

- **Flag:** `IS_DIRETORIA = (sb_perfil.perfil === 'diretoria')`
- **Seção:** `#sec-diretoria` — independente de `#sec-gestor` e das seções RH; nenhuma das duas é alterada
- **Dados:** carregados por `carregarDoSupabase()` (mesma chamada da visão RH) — `COLABORADORES[]` com `registros[].lancamentos[]`

### Funções canônicas (nunca duplicar lógica)

```js
_dirPopularFiltros()    // popula selects #dirFiltroCargo, #dirFiltroSetor, #dirFiltroUnidade
_dirFiltrados()         // retorna COLABORADORES filtrados pelos 3 selects (ativos apenas)
_dirSaldoColab(colab)   // soma calcSaldo(r) de todos os registros — uso interno (não usar no drawer de risco)
_dirUrgSemProg(colab)   // retorna { nivel, dlim } do PA mais urgente sem programação
_dirHtmlRiscoDobra()    // HTML do drawer Risco de Dobra — agrupa por nível, 1 card por colaborador
_dirRenderSetorTable()  // tabela Atenção por Setor — Equipe / Risco / Agendados / Status
_dirHtmlSetorRisco(s)   // HTML do drawer de setor — colaboradores em risco filtrados por setor
renderDiretoria()       // KPIs + Próximas Saídas + Sem Programação + gráfico
_renderDirChart(colabs) // canvas bar chart: concentração por mês, linha de média, anotação de pico
dirMostrarAba(aba)      // toggle 'dashboard' / 'timeline'
```

### Cálculos reutilizados da visão RH (nunca reimplementar)

| Conceito | Função |
|---|---|
| Saldo de dias | `calcSaldo(reg)` |
| Colaborador sem agendamento | `isSemAgendado(colab)` |
| Colaborador com risco de dobra | `isRiscoDobra(colab)` |
| Semáforo de nível | `nivelRisco(dpd)` — critico/atencao/noradar/null |
| Dias até a dobra | `diasParaDobra(reg)` |
| Data limite da dobra | `dataLimiteDobra(reg)` |

### KPIs (4 cards)

| ID raiz | Cor | Métrica |
|---|---|---|
| `dirKpiAg*` | verde | Agendados — lançamento futuro com `fim >= hoje` |
| `dirKpiHj*` | azul | Em férias hoje — lançamento ativo (`inicio <= hoje <= fim`) |
| `dirKpiSp*` | âmbar | Sem programação — `isSemAgendado()` |
| `dirKpiRd*` | vermelho | Risco de dobra — `isRiscoDobra()` |

Cada KPI tem 3 elementos: `*N` (número), `*Ctx` (frase "X de N"), `*Bar` (barra de proporção).

### Drawer "Risco de Dobra" — `_dirHtmlRiscoDobra()` (corrigido 2026-09-25)

Aberto ao clicar no KPI vermelho. Exibe os colaboradores retornados por `isRiscoDobra()` agrupados por nível.

**Seleção do PA exibido:** aplica os **mesmos 3 critérios de `isRiscoDobra()`** para identificar o registro relevante — não usa `_dirSaldoColab` nem busca o PA de menor dpd entre todos os registros:

```js
c.registros.forEach(reg => {
  if (excluir.has(reg.status)) return;
  const saldo = calcSaldo(reg);
  if (saldo <= 0) return;
  const dpd = diasParaDobra(reg);
  if (dpd === null || dpd > REGRAS_FERIAS.diasAlertaDobra) return;
  if (reg.lancamentos.some(l => l.fim && l.fim >= HOJE)) return;
  if (dpd < minDpd) { minDpd = dpd; minReg = reg; }
});
```

Isso garante que o PA exibido é exatamente o mesmo que fundamenta o risco — nunca um PA vencido de anos anteriores.

**Estrutura do card (por colaborador):**

```
[Avatar]  Nome do colaborador          Crítico / Atenção / No Radar
          Cargo                        Dobra em DD/MM/AAAA
          Setor · Gestor               Saldo: Xd
```

- Nível: `labels[nivel]` — exatamente "Crítico", "Atenção" ou "No Radar"
- Data: `dataLimiteDobra(reg)` do PA selecionado
- Saldo: `calcSaldo(reg)` do PA selecionado — **não** `_dirSaldoColab(c)` (que somaria todos os PAs)
- Cargo: `c.cargo`; Setor · Gestor: `c.setor` + `c.gestor`
- Clique no card: `fecharDrawer(); setTimeout(() => abrirDrawer(c.__key), 180)`

**Ordenação:** por `dpd` ascendente dentro de cada grupo (mais urgente primeiro).

**Grupos e cores:**

| Grupo | Critério | Fundo | Borda | Texto |
|---|---|---|---|---|
| `critico` | dpd < 60 | `#FEF3F2` | `#F04438` | `#7F1D1D` |
| `atencao` | 60 ≤ dpd ≤ 120 | `#FFFAEB` | `#F79009` | `#B54708` |
| `noradar` | dpd > 120 | `#EFF6FF` | `#2E90FA` | `#1D4ED8` |

**Princípio:** Diretoria = mesma informação do Gestor/RH, apresentação executiva. Nunca criar nova regra de risco — sempre reutilizar `isRiscoDobra()`, `calcSaldo()`, `diasParaDobra()`, `dataLimiteDobra()`, `nivelRisco()`.

---

### Tabela "Atenção por Setor" — `_dirRenderSetorTable()` (corrigido 2026-09-25)

Renderizada em `#dirSetorTable`. Fonte: `_dirFiltrados()` (COLABORADORES ativos filtrados pelos selects).

| Coluna | Fonte | Regra |
|---|---|---|
| **Setor** | `c.setor \|\| 'Sem setor'` | — |
| **Equipe** | contagem de colaboradores do setor em `_dirFiltrados()` | — |
| **Risco de Dobra** | `isRiscoDobra(c)` | mesma função do RH — nunca reimplementar |
| **Agendados** | `r.lancamentos.some(l => l.fim >= HOJE)` em qualquer PA não-excluído | — |
| **Status** | `nivelRisco(piorDpd)` do setor | veja abaixo |

**Cálculo do `piorDpd` (Status do setor):** para cada colaborador em risco do setor, aplica os **mesmos 3 critérios de `isRiscoDobra()`** ao varrer os registros — `saldo > 0`, `dpd ≤ diasAlertaDobra`, sem lançamento futuro — e pega o menor `dpd` entre os PAs elegíveis. `nivelRisco(piorDpd)` determina o badge do setor:

- `critico` (piorDpd < 60) → fundo `#FEE2E2`, texto `#7F1D1D`
- `atencao` (piorDpd ≤ 120) → fundo `#FDE68A`, texto `#78350F`
- sem risco → `OK`, fundo `#ECFDF3`, texto `#027A48`

**Ordenação:** setores Crítico primeiro, depois Atenção, depois OK; dentro do mesmo nível, por `risco` decrescente.

**onclick da linha:**
```js
onclick="abrirDrawerGenerico('${setor}', _dirHtmlSetorRisco('${setor}'))"
```
Usar **aspas simples** em torno do setor — `JSON.stringify` gera aspas duplas que quebram o atributo HTML.

---

### Drawer de setor — `_dirHtmlSetorRisco(setor)` (corrigido 2026-09-25)

Aberto ao clicar em qualquer linha da tabela "Atenção por Setor".

**Seleção do PA:** idêntica a `_dirHtmlRiscoDobra()` — aplica os mesmos 3 critérios de `isRiscoDobra()` para encontrar o `minReg`. Nunca buscar o PA de menor dpd entre todos os registros sem filtro (isso seleciona PAs de anos anteriores).

**Quando o setor não tem risco:** exibe card verde "Setor sem risco de dobra" com contagem de colaboradores e agendados.

**Estrutura do card (por colaborador):**
```
[Avatar]  Nome do colaborador          Crítico / Atenção / No Radar
          Cargo                        Dobra em DD/MM/AAAA
          Gestor                       Saldo: Xd
```

- Nível, data e saldo: mesmas funções do drawer do KPI (`nivelRisco`, `dataLimiteDobra(reg)`, `calcSaldo(reg)`)
- Clique: `fecharDrawer(); setTimeout(() => abrirDrawer(c.__key), 180)`
- Ordenação: `dpd` ascendente (mais urgente primeiro)

---

### Painel "Sem Programação"

**Definição:** `isSemAgendado(colab)` — PA vigente com saldo aberto, sem lançamento futuro.

**Semáforo (via `_dirUrgSemProg`):**
- `critico` (dpd < 60) → badge vermelho `.dir-sp-critico`
- `atencao` (dpd ≤ 120) → badge âmbar `.dir-sp-atencao`
- `noradar` (dpd ≤ 180) → badge azul `.dir-sp-radar`

Ordenação: nível de risco ascendente, depois saldo descendente.
Nota de rodapé: "Pontos para acompanhamento" (nunca "encaminhamento pelo RH").
Subtítulo do card: "Colaboradores com PA vigente e saldo aberto".

### Filtros executivos

**Posição:** `#dirDashFilters` fica na `dir-nav-row`, na mesma linha das abas Dashboard / Timeline. Oculto automaticamente quando a aba Timeline está ativa (controlado em `dirMostrarAba()`).

Cada select tem um botão ✕ via `filter-wrap` + `filter-clear` + `syncFilterClear`:

```html
<div class="dir-filters" id="dirDashFilters">
  <span class="dir-filter-eye">Filtrar por</span>
  <div class="filter-wrap">
    <select class="dir-sel" id="dirFiltroCargo" onchange="renderDiretoria();syncFilterClear('dirFiltroCargo','')"><option value="">Cargo</option></select>
    <button class="filter-clear" id="clr-dirFiltroCargo" onclick="clearFilter('dirFiltroCargo','',()=>{renderDiretoria()})" tabindex="-1" title="Limpar">✕</button>
  </div>
  <!-- idem dirFiltroSetor, dirFiltroUnidade -->
</div>
```

`_dirPopularFiltros()` popula com `placeholder` descritivo ("Cargo", "Setor", "Unidade") e chama `syncFilterClear` após popular para sincronizar o estado do botão ✕.

### setRole() — 3 ramos

```js
function setRole(role) {
  IS_DIRETORIA = (role === 'diretoria');
  if (role === 'diretoria') {
    // oculta seções RH + sec-gestor, mostra sec-diretoria
    // chama carregarDoSupabase() se COLABORADORES vazio, senão renderDiretoria() direto
  } else if (role === 'gestor') {
    // oculta sec-diretoria, mostra sec-gestor
    // initGestor() ou renderGestorAlerts()
  } else {
    // IS_DIRETORIA = false; oculta sec-diretoria e sec-gestor; mostra seções RH
  }
}
```

### DOMContentLoaded — ramo IS_DIRETORIA

```js
} else if (IS_DIRETORIA) {
  document.getElementById('roleToggle').style.display = 'none';
  carregarDoSupabase().then(() => {
    document.getElementById('visaoContent').style.display = 'none';
    document.querySelector('.mod-tabs').style.display = 'none';
    document.getElementById('sec-diretoria').style.display = 'block';
    _dirPopularFiltros();
    renderDiretoria();
  });
}
```

---

## Visão Diretoria — Timeline (implementado 2026-09-22)

### Princípio arquitetural

A Timeline da Diretoria **nunca move o `#sub-timeline`** da visão RH. Há um container dedicado `#dirTimelineHost` dentro de `#sec-diretoria .dir-page`. A lógica de renderização é compartilhada via helper extraído.

### Helper compartilhado `_ganttRenderContent`

Extraído de `renderTimeline()` para ser reutilizável por qualquer container:

```js
function _ganttRenderContent(targetEl, filtrados, diasNoMes, mesInicio, mesFim, mes, ano)
```

- Recebe o elemento-alvo como primeiro argumento — escreve `targetEl.innerHTML`
- Contém toda a lógica de avatar, diasInfo, thead, tbody e barras de Gantt
- `renderTimeline()` (visão RH) continua funcionando — chama este helper ao final
- `renderDirTimeline()` (Diretoria) também chama este helper com `#dirGanttContent`

### Filtros independentes por aba

Dashboard e Timeline têm **conjuntos de filtro completamente separados**:

| Aba | IDs dos selects | Função de filtro |
|---|---|---|
| Dashboard | `dirFiltroCargo`, `dirFiltroSetor`, `dirFiltroUnidade` | `_dirFiltrados()` |
| Timeline | `dirTlFiltroCargo`, `dirTlFiltroSetor`, `dirTlFiltroGestor` | `_dirTlFiltrados()` |

`renderDiretoria()` **não propaga** nem chama `renderDirTimeline()` — as abas são completamente independentes.

`_dirTlPopularFiltros()` — chamada quando a aba Timeline é ativada; popula os selects a partir de `COLABORADORES` ativos. Usa `normSetor()` ao popular o setor.

### Estado de navegação de mês (independente da visão RH)

```js
let _dirGanttAno = new Date().getFullYear();
let _dirGanttMes = new Date().getMonth();

function _dirGanttNav(delta) {
  _dirGanttMes += delta;
  if (_dirGanttMes > 11) { _dirGanttMes = 0; _dirGanttAno++; }
  if (_dirGanttMes < 0)  { _dirGanttMes = 11; _dirGanttAno--; }
  renderDirTimeline();
}
```

Completamente separado de `_ganttAno`/`_ganttMes` da visão RH.

### `renderDirTimeline()`

```js
function renderDirTimeline() {
  const filtrados = _dirTlFiltrados().filter(c =>
    c.registros.some(reg => {
      const lans = [...reg.lancamentos, ...(reg._novoLanc ? [reg._novoLanc] : [])];
      return lans.some(l => l.inicio <= mesFim && l.fim >= mesInicio);
    })
  ).sort((a, b) => a.nome.localeCompare(b.nome));
  _ganttRenderContent(content, filtrados, diasNoMes, mesInicio, mesFim, mes, ano);
}
```

### `dirMostrarAba(aba)` — controle de visibilidade

```js
function dirMostrarAba(aba) {
  const isDash = aba === 'dashboard';
  // toggle active nos botões de aba
  // #dirDashboard: display '' ou 'none'
  // KPI row + base band: ocultados na aba Timeline
  const host = document.getElementById('dirTimelineHost');
  if (host) host.style.display = isDash ? 'none' : '';
  // filtros do Dashboard ficam ocultos na aba Timeline
  const dashFilters = document.getElementById('dirDashFilters');
  if (dashFilters) dashFilters.style.display = isDash ? '' : 'none';
  if (!isDash) {
    _dirTlPopularFiltros();
    renderDirTimeline();
  }
}
```

### HTML de `#dirTimelineHost`

Filtros fundidos na `gantt-topbar` (única linha), alinhados à direita das setas com `margin-left:auto`. Não há `dir-tl-filter-row` separado.

```html
<div id="dirTimelineHost" style="display:none;">
  <div class="gantt-topbar" style="display:flex;align-items:center;gap:8px;padding:0 0 6px 0;flex-wrap:wrap;">
    <button class="gantt-nav-btn" onclick="_dirGanttNav(-1)">&#8592;</button>
    <span id="dirGanttTitulo" class="gantt-nav-month"></span>
    <button class="gantt-nav-btn" onclick="_dirGanttNav(1)">&#8594;</button>
    <span style="font-size:12px;color:var(--text-ter);margin-left:4px;"><span id="dirGanttCnt">0</span> colaborador(es)</span>
    <div style="margin-left:auto;display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
      <span class="dir-filter-eye">Filtrar por</span>
      <div class="filter-wrap">
        <select class="dir-sel" id="dirTlFiltroCargo" onchange="renderDirTimeline();syncFilterClear('dirTlFiltroCargo','')"><option value="">Cargo</option></select>
        <button class="filter-clear" id="clr-dirTlFiltroCargo" onclick="clearFilter('dirTlFiltroCargo','',()=>{renderDirTimeline()})" tabindex="-1">✕</button>
      </div>
      <!-- idem dirTlFiltroSetor, dirTlFiltroGestor -->
    </div>
  </div>
  <div id="dirGanttContent"></div>
</div>
```

### Pills de anos — ordem cronológica (`_dirRenderYearPills`)

Todos os anos (comparação + atual) são ordenados juntos em `ascending` antes de renderizar. O ano atual nunca fica preso ao final quando há anos futuros disponíveis:

```js
const todosOrdenados = [...anosComp, _DIR_ANO_ATUAL].sort((a,b) => a-b);
todosOrdenados.forEach(a => {
  if (a === _DIR_ANO_ATUAL) {
    // pill .current (não clicável, sempre visível)
  } else {
    const idx = anosComp.indexOf(a); // índice de cor na paleta _DIR_ANO_CORES
    // pill clicável com cor e botão ⚠ parcial se necessário
  }
});
```

**Regra:** nunca hardcode a ordem — o ano atual vive no seu lugar cronológico.

### Escala dinâmica do gráfico de concentração (`_renderDirChart`)

Y-axis calculado proporcionalmente ao pico real, não fixo:

```js
const allVals = todosAnos.flatMap(a => countsPorAno[a].filter(v => v !== null));
const maxV    = Math.max(...allVals, 1);
const rawTop  = maxV * 1.15;                          // 15% de headroom
const mag     = Math.pow(10, Math.floor(Math.log10(rawTop)));
const nice    = [1,2,5,10].map(f => f*mag).find(f => f >= rawTop) || rawTop;
const top     = nice;
```

Meses com baixa concentração não ficam "achatados" mesmo quando Dezembro tem pico alto.

### Framework conceitual da Diretoria

A Diretoria responde 3 perguntas na ordem:
1. **Como estamos?** — KPIs: Agendados / Em férias hoje / Sem programação / Risco de dobra
2. **O que merece atenção?** — Painel Sem Programação + semáforos de urgência
3. **O que vem pela frente?** — Próximas saídas + Timeline (aba dedicada)

Esse framework deve guiar qualquer decisão de hierarquia visual futura na Diretoria.

---

## Visão Gestor — "Alterar data" e "Solicitar cancelamento" (2026-09-23)

### Z-index: stacking context do drawer Gestor

O drawer do Gestor usa uma hierarquia própria, **diferente** do `.drawer` da visão RH:

| Elemento | z-index |
|---|---|
| `.gsol-overlay` | 1100 |
| `.gsol-drawer` | 1101 (relativo ao overlay) |
| modais do Gestor (ex: `#modalGestorAlt`) | **1200** + `document.body.appendChild()` |

**Regra obrigatória:** qualquer modal aberto sobre o gsolDrawer precisa de:
1. `z-index: 1200` no elemento `.modal-overlay`
2. `document.body.appendChild(modal)` para mover o modal para o nível do `<body>`, escapando do contexto de empilhamento do overlay

Sem o `appendChild`, o z-index mais alto não adianta — o modal fica preso dentro do stacking context de `1100`.

### `gestorAbrirModalAlt` — parâmetro refatorado

```js
// Assinatura ATUAL (corrigida):
gestorAbrirModalAlt(colabId, periodoId, lancId)  // lancId = string, ex: "123-p1" ou "456-p2"

// Assinatura ANTIGA (não usar):
gestorAbrirModalAlt(colabId, periodoId, lancIdx)  // lancIdx = número 0 ou 1
```

O botão em `_renderGsolHistoricoRH` deve passar `l.id` (string), não o índice numérico:
```js
onclick="gestorAbrirModalAlt('${c.id}','${per.id}','${l.id}')"
```

### Contexto `_gestorAltCtx` — shape correto

```js
_gestorAltCtx = {
  colabId,
  periodoId,
  lancId,    // string "123-p1" ou "456-p2"
  slot,      // 'p1' ou 'p2' — derivado de lancId.endsWith('-p2')
  inicio,    // data atual do lançamento
  fim,
  dias,
}
```

**Regra:** `_gestorAltCtx.slot` (não `lancIdx`) é o que `gestorEnviarAlteracao` deve usar para montar o payload.

### Modal "Solicitar alteração de data" — melhorias de UI

O modal `#modalGestorAlt` exibe o **período completo atual** antes do formulário:

```html
<!-- Bloco "Período atual" — exibido acima dos campos -->
<div id="mgAltPeriodoAtual" style="background:var(--bg);border:1px solid var(--border);border-radius:8px;padding:10px 14px;margin-bottom:16px;">
  <div style="font-size:10px;font-weight:700;color:var(--text-ter);text-transform:uppercase;letter-spacing:.06em;margin-bottom:5px;">Período atual</div>
  <div style="font-size:14px;font-weight:600;color:var(--text);font-variant-numeric:tabular-nums;" id="mgAltPeriodoTexto">—</div>
  <div style="font-size:12px;color:var(--text-sec);margin-top:3px;" id="mgAltDiasTexto">—</div>
</div>
```

- `mgAltPeriodoTexto` exibe `"DD/MM/AAAA → DD/MM/AAAA"` (formatDate de inicio e fim)
- `mgAltDiasTexto` exibe `"X dias"` da duração original
- `mgAltDuracaoNota` (abaixo do campo "Novo término") exibe `"A duração de X dias é mantida."`
- O campo "Novo término" é readonly, calculado automaticamente por `gestorAltCalcFim()`

### Fluxo "Solicitar cancelamento" — implementação completa

#### Regra de negócio

O Gestor solicita cancelamento de um lançamento específico (p1 ou p2). O RH aprova ou rejeita. Enquanto pendente, os botões ficam desabilitados e um banner de status é exibido.

#### `gestorConfirmarCancelamento(colabId, periodoId, lancId)`

Nova função — usa `confirm()` nativo (sem modal dedicado — mesma abordagem que "Alterar data" antes da refatoração):

```js
async function gestorConfirmarCancelamento(colabId, periodoId, lancId) {
  const lancamento = GESTOR_LANCAMENTOS.find(l => String(l.id) === String(lancId));
  if (!lancamento) { toast('Lançamento não encontrado.'); return; }
  const slot = lancId.endsWith('-p2') ? 'p2' : 'p1';
  // confirm() exibe datas e aviso de que as férias continuam até o RH decidir
  const meta = {
    tipo: 'cancelamento', slot,
    inicio: lancamento.inicio, fim: lancamento.fim, dias: lancamento.dias,
    solicitante: GESTOR_NOME_USUARIO || '—',
    data_solicitacao: new Date().toISOString(),
  };
  await sbPatch('ferias', `id=eq.${periodoId}`, { status: 'Cancelamento_Solicitado', obs_gestor: JSON.stringify(meta) });
  // atualizar COLABORADORES, GESTOR_PERIODOS localmente
  // _logAtiv 'cancelamento_solicitado'
}
```

#### Status e payload no Supabase

```js
// PATCH em ferias:
{ status: 'Cancelamento_Solicitado', obs_gestor: JSON.stringify({
  tipo: 'cancelamento',
  slot: 'p1' | 'p2',
  inicio: 'YYYY-MM-DD',
  fim: 'YYYY-MM-DD',
  dias: N,
  solicitante: 'Nome do Gestor',
  data_solicitacao: 'ISO string',
}) }
```

#### `supabaseParaModelo` — parsing de `_cancelamentoMeta`

```js
let _cancelamentoMeta = null;
if (f.status === 'Cancelamento_Solicitado' && f.obs_gestor) {
  try {
    const _p = JSON.parse(f.obs_gestor);
    if (_p?.tipo === 'cancelamento') _cancelamentoMeta = _p;
  } catch(_) {}
}
// Incluído no objeto registro:
_cancelamentoMeta,
```

#### `getPendentes()` — ramo Cancelamento_Solicitado

```js
if (reg.status === 'Cancelamento_Solicitado') {
  if (!reg._cancelamentoMeta) return;
  const meta = reg._cancelamentoMeta;
  result.push({ colab, reg, ri,
    lancamento: { inicio: meta.inicio, fim: meta.fim, dias: meta.dias },
    _tipo: 'cancelamento', _cancelMeta: meta });
  return;
}
```

#### `abrirModalAprovar` — ramo cancelamento

```js
} else if (_tipo === 'cancelamento') {
  const _cancelMeta = pendItem._cancelMeta;
  document.getElementById('aprovarTitle').textContent = 'Analisar cancelamento de férias';
  // aprovarInfo: aviso amarelo + período + solicitante + data
  document.getElementById('btnAprovar').textContent = '✓ Aprovar cancelamento';
}
```

#### `aprovarPendente` — lógica com slot parcial (regra crítica)

```js
if (_tipo === 'cancelamento') {
  const slotIdx     = _cancelMeta.slot === 'p2' ? 1 : 0;
  const outroIdx    = slotIdx === 0 ? 1 : 0;
  // PA permanece Aprovado se o outro slot ainda for válido
  const outroSlotValido = reg.lancamentos.length > 1 && (reg.lancamentos[outroIdx]?.dias || 0) > 0;
  const novoStatus  = outroSlotValido ? 'Aprovado' : 'Cancelado';
  const patch = _cancelMeta.slot === 'p1'
    ? { status: novoStatus, obs_gestor: null, periodo1_inicio: null, periodo1_fim: null, dias1: 0 }
    : { status: novoStatus, obs_gestor: null, periodo2_inicio: null, periodo2_fim: null, dias2: 0 };
  await sbPatch('ferias', `id=eq.${reg._sbId}`, patch);
  reg.lancamentos.splice(slotIdx, 1);
  reg.status = novoStatus;
  // _logAtiv 'cancelamento_aprovado'
}
```

**Regra:** o PA só recebe status `'Cancelado'` quando **não restar nenhum slot válido**. Se houver p1 e p2, e apenas p1 for cancelado, o PA continua `'Aprovado'` com apenas p2.

#### `rejeitarPendente` — ramo cancelamento

```js
if (_tipo === 'cancelamento') {
  await sbPatch('ferias', `id=eq.${reg._sbId}`, { status: 'Aprovado', obs_gestor: null });
  reg._cancelamentoMeta = null;
  reg.status = 'Aprovado';
  // _logAtiv 'cancelamento_recusado'
}
```

### Banners e botões em `_renderGsolHistoricoRH` (2026-09-23)

#### Filtro de saldo (excluir lançamentos cancelados)

```js
const lancamentos = GESTOR_LANCAMENTOS.filter(l =>
  String(l.colaborador_id) === String(c.id) &&
  String(l.periodo_id) === String(per.id) &&
  l.status !== 'gozado' &&
  l.status !== 'pendente_gestor' &&
  (l.status || '').toLowerCase() !== 'cancelado'  // ← obrigatório: cancelados não entram no saldo
);
```

#### Lógica de banners e botões por lançamento

```js
// Meta do status pendente (alteration or cancellation)
let _altMetaGsol    = null;
let _cancelMetaGsol = null;
if (row.obs_gestor && (row.status === 'Alteracao_Solicitada' || row.status === 'Cancelamento_Solicitado')) {
  try {
    const _p = JSON.parse(row.obs_gestor);
    if (_p?.tipo === 'alteracao')    _altMetaGsol    = _p;
    if (_p?.tipo === 'cancelamento') _cancelMetaGsol = _p;
  } catch(_) {}
}

// Por lançamento (onde lancIdx = posição base 1):
const thisSlot = lancIdx === 1 ? 'p2' : 'p1';
const temAltPendente    = _altMetaGsol    && _altMetaGsol.slot    === thisSlot;
const temCancelPendente = _cancelMetaGsol && _cancelMetaGsol.slot === thisSlot;
const temQualquerPendente = temAltPendente || temCancelPendente;

// Banners visíveis mesmo com pendência:
const bannerAlt    = temAltPendente    ? '<div style="...amarelo...">Alteração de data aguardando aprovação do RH...</div>' : '';
const bannerCancel = temCancelPendente ? '<div style="...vermelho...">Cancelamento aguardando aprovação do RH...</div>' : '';

// Botões: desabilitados (não ocultos) quando há pendência
if (isAprovadoLanc && isFuturoLanc) {
  const btnAlt = temQualquerPendente
    ? `<button disabled ...>Alterar data</button>`
    : `<button onclick="gestorAbrirModalAlt('${c.id}','${per.id}','${l.id}')">Alterar data</button>`;
  const btnCancel = temQualquerPendente
    ? `<button disabled ...>Solicitar cancelamento</button>`
    : `<button onclick="gestorConfirmarCancelamento('${c.id}','${per.id}','${l.id}')">Solicitar cancelamento</button>`;
  botoesAcao = `<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:6px;">${btnAlt}${btnCancel}</div>`;
}
```

**Regra:** botões desabilitados (não ocultos) para dar feedback visual do estado — o Gestor sabe que há algo pendente sem precisar interpretar ausência de botões.

### `acaoLabel` e `acaoCor` — mapeamento completo (commits 36f2e77 + b5e47e4, out/2026)

Duas ocorrências no arquivo: `renderDrawerAuditoria` (RH) e `_renderGsolHistoricoAuditoria` (Gestor). Devem estar sempre sincronizadas. Ao adicionar nova ação, atualizar as duas funções.

**Ações presentes no banco e seus rótulos:**

| Ação | Rótulo | Cor |
|---|---|---|
| `solicitado` | Solicitação enviada | `var(--blue)` |
| `aprovado` | Aprovado pelo RH | `var(--green)` |
| `rejeitado` | Recusado pelo RH | `#D92D20` |
| `alteracao_solicitada` | Alteração solicitada | `#1570EF` |
| `alteracao_aprovada` | Alteração aprovada | `#067647` |
| `alteracao_recusada` | Alteração recusada | `#D92D20` |
| `cancelamento_solicitado` | Cancelamento solicitado | `#B45309` |
| `cancelamento_aprovado` | Cancelamento aprovado | `#D92D20` |
| `cancelamento_recusado` | Cancelamento recusado | `#067647` |
| `solicitacao_retirada` | Solicitação retirada | `#B45309` |
| `solicitacao_datas_alteradas` | Datas da solicitação atualizadas | `#1570EF` |
| `gozo_solicitado` | Gozo solicitado pelo gestor | `#1570EF` |
| `lancado_rh` | Lançado pelo RH | `var(--green)` |
| `editado_rh` | Editado pelo RH | `#B45309` |
| `excluido_rh` | Excluído pelo RH | `#D92D20` |
| `gestor_ciente` | Gestor ciente | `var(--green)` |

**`perStr` — leitura de período unificada:**
```js
const ini  = det.inicio || det.saida || det.inicio_novo || '';
const fim  = det.fim    || det.retorno || det.fim_novo  || '';
const dias = det.dias   || det.dias_novo || '';
```
Cobre todas as estruturas de `detalhe`: solicitação (`inicio/fim`), gozo (`saida/retorno`), edição RH (`inicio_novo/fim_novo`).

**Footer do gsolDrawer (botão "+ Nova solicitação"):** visível somente na aba "Férias" (`isRH`). Nas abas Histórico o footer fica oculto.

---

## Pendências conhecidas

- Módulo WhatsApp (link wa.me por colaborador) — dados já no Supabase, falta UI
- Aprovação em lote
- Eliminar aba "Solicitações" permanentemente (aguardando testes do novo fluxo unificado)
- Visão Diretoria — validar banda base (47 ativos / 31 com PA / 16 sem PA) como elemento de design permanente ou remover
- Testar fluxo completo de cancelamento (gestor solicita → RH aprova/rejeita) — em aberto desde 2026-09-23
- **[PENDÊNCIA ESTRUTURAL] `lancIdx` binário em `realizacoes[]`** (commit af9f1f6, 2026-10-09):
  O campo `lancIdx` nas realizações é gravado como 0 ou 1 (heurística `-p2` → 1, resto → 0).
  Funciona corretamente para flat fields e periodos[] com p.id ∈ {0, 2}.
  Limitação: `p.id=1` colide com `p.id=0` (ambos → lancIdx=0), causando leitura incorreta quando um mesmo row tem realizações para os dois primeiros períodos da nova estrutura `periodos[]`.
  **Deve ser corrigido ANTES** de liberar o fluxo de solicitação de gozo (autoatendimento Gestor) para rows com periodos[] contendo p.id=1.
  Escopo da correção:
  1. `grhEnviarSolicitarGozo` — gravar `p.id` real em vez do valor binário
  2. `_renderGsolHistoricoRH` (linha ~12127) — derivar lancIdx do sufixo numérico real do ID do lançamento (ex: `-p3` → 3), em vez de `endsWith('-p2') ? 1 : 0`
  3. `_gestorColabsComAcordoAndamento` — atualizar filtro de realizacoes para usar p.id real
  4. Manter retrocompatibilidade: realizacoes existentes com lancIdx=0/1 (flat fields) devem continuar funcionando

---

## Dashboard Gestor — arquitetura (set/2026)

Aba `Dashboard` na visão Gestor. Container: `#gdashContent`, renderizado por `renderAnalyticsGestor()`.

**Regras da aba Dashboard:**
- Visão somente leitura — sem botões de ação
- Não criar novas regras de negócio — usar apenas funções canônicas existentes
- "Premium" = informação certa na ordem certa, não mais elementos

### Estado global

| Variável | Padrão | Descrição |
|---|---|---|
| `_gdashMapaMostrarTodos` | `false` | Toggle "sem programação" no Mapa |
| `_gdashMapaMesSel` | `null` | Mês selecionado no Mapa (0-11) |
| `_gdashMapaCargo` | `''` | Filtro de cargo no Mapa |
| `_gdashMapaAno` | `new Date().getFullYear()` | Ano exibido no Mapa |
| `_gdashSemProgAbertos` | `Set(['critico','atencao'])` | Acordeões abertos no Bloco E |

`renderAnalyticsGestor()` reseta todos os estados acima ao ser chamado.

### Cinco blocos de renderização

**Bloco A — `_renderGdashResumo()`**: resumo executivo inline (emFerias, saem30, retornam7, criticosSemAg)

**Bloco B — `_renderGdashAtencao()`**: card borda vermelha, max 5 itens críticos sem agendamento

**Bloco C — `_renderGdashProximos()`**: "Saem nos próximos 30 dias" em largura total. Mostra até 6 itens com avatar, nome, datas e "Faltam X dias". **Sem bloco "Retornam esta semana"** — essa informação já consta no Bloco A.

**Bloco D — `_renderGdashMapa()`**: Mapa Anual com drill-down mensal (ver seção abaixo)

**Bloco E — `_renderGdashSemProg()`**: acordeão por nível de risco (critico/atencao abertos por padrão), colaboradores sem programação

### Bloco C — definição canônica

- Uma única coluna "Saem nos próximos 30 dias" em largura total
- Label de countdown: `"Faltam X dias"` (nunca `"Xd"` ou `"Xd."` — não é intuitivo)
- Máximo 6 itens com avatar, nome, datas formatadas e countdown

### Bloco D — Mapa Anual (modo duplo)

**Filtro de status:** somente `aprovado` e `gozado` (`incluir = new Set(['aprovado','gozado'])`). `solicitado` não aparece no mapa. Cor única `#185FA5` para todos os períodos.

**Deduplicação:** por `(inicio, fim)` — evita duplicidade visual se período transitou de status.

**Navegação de ano:** `_gdashMapaAnoNav(delta)` — incrementa/decrementa `_gdashMapaAno`. Não permite avançar além do ano atual. Ao mudar de ano, reseta `_gdashMapaMesSel = null`.

```js
function _gdashMapaAnoNav(delta) {
  const anoAtual = new Date().getFullYear();
  const novo = _gdashMapaAno + delta;
  if (novo > anoAtual) return;
  _gdashMapaAno    = novo;
  _gdashMapaMesSel = null;
  _renderGdashMapa();
}
```

**Modo panorâmico (SEL === null):** grade Jan→Dez, cabeçalhos clicáveis, marcadores de mês de início, filtro de cargo. Mês atual destacado só quando exibindo o ano corrente (`mesAtual = (ano === anoAtual) ? new Date().getMonth() : -1`).

**Modo detalhamento mensal (SEL !== null):** ao clicar num mês, exibe visão dia-a-dia via `_ganttRenderContent` usando adapter que mapeia dados GESTOR → formato RH:

```js
// Adapter: GESTOR_COLABS/GESTOR_LANCAMENTOS → formato _ganttRenderContent
return {
  nome: colab.nome, cargo: colab.cargo||'', setor: colab.setor||'',
  unidade: colab.unidade||'', empresaRegistro: '',
  fotoUrl: colab.foto_url||null,   // snake_case → camelCase
  __key: String(colab.id),
  registros: [{
    lancamentos: lansDoMes.map(l => ({ inicio: l.inicio, fim: l.fim, dias: l.dias })),
    _novoLanc: null
  }],
};
```

Após chamar `_ganttRenderContent`, remover onclick das linhas (contexto read-only):
```js
tl.querySelectorAll('.gantt-row').forEach(tr => {
  tr.removeAttribute('onclick');
  tr.style.cursor = 'default';
});
```

Navegação no modo mensal: botão "← Ver ano todo" + botões prev/next mês.

### RH Atividade — botão "Analisar" em pendentes

`_rhAtivAbrirModal(feriasId)` — helper que localiza o item nos pendentes via `getPendentes()` e abre `abrirModalAprovar(idx)`.

Em `_itemRow` de `renderRhAtividade`: se `IS_RH && _rhEhRecente(h)`, exibe botão "Analisar" em vez de chip passivo.

`rhRecusarSolicitado` — não usa `prompt()` (bloqueado no GitHub Pages). Rota para `abrirModalAprovar(i)` + `toggleMotivoRejeicao()`.

---

## Padrão visual global — legibilidade (set/2026)

Aplicado em **todos os módulos** (não apenas Férias).

### Tokens CSS

| Token | Valor | Contraste s/ branco |
|---|---|---|
| `--text` | `#101828` | 19.2:1 |
| `--text-sec` | `#4B5565` | 6.1:1 |
| `--text-ter` | `#6C7589` | 4.6:1 (passa WCAG AA) |

### Escala mínima de fonte

- **12px+**: dados operacionais (nome, data, número, status)
- **11px**: mínimo absoluto para qualquer texto informativo/auxiliar
- **< 11px**: apenas elementos decorativos/estruturais (ícones, chevrons ▾▴, indicadores visuais sem leitura)

**Regra:** nenhum texto que precise ser lido pode estar em 8px, 9px ou 10px. Hierarquia visual mantida pela combinação de tamanho + peso + cor, nunca sacrificando legibilidade.

**Escopo:** tokens definidos no `:root` de `modulos/ferias/index.html`; os valores `#4B5565` e `#6C7589` foram propagados para todos os outros módulos (`modulos/cadastro/`, `modulos/admissao/`, etc.) e o font-size mínimo de 11px foi aplicado via replace global.

---

## Auditoria premium — `colaboradores.historico` JSONB (set/2026)

**Premissa do sistema:** todo módulo deve registrar histórico de movimentações em `colaboradores.historico` (JSONB). No módulo Férias, isso é feito via `_logColabHist`.

### Helper `_logColabHist(colabId, tipo, detalhe, usuario)`

```js
async function _logColabHist(colabId, tipo, detalhe, usuario) {
  if (!colabId) return;
  try {
    const rows = await sbGet('colaboradores', `id=eq.${colabId}&select=historico`);
    const hist = Array.isArray(rows[0]?.historico) ? rows[0].historico : [];
    hist.push({ tipo, detalhe, data: new Date().toISOString(), usuario: usuario || null });
    await sbPatch('colaboradores', `id=eq.${colabId}`, { historico: hist });
  } catch(e) { console.warn('[colaboradores.historico] update falhou:', e?.message || e); }
}
```

### Pontos de chamada no módulo Férias

| Função | tipo | detalhe |
|---|---|---|
| `gestorEnviarSolicitacao` | `'ferias_solicitado'` | `Férias solicitadas: DD/MM → DD/MM (Nd)` |
| `rhAprovarSolicitado` | `'ferias_aprovado'` | `Férias aprovadas: DD/MM → DD/MM (Nd)` |
| `rhRecusarSolicitado` | `'ferias_rejeitado'` | `Férias rejeitadas: DD/MM → DD/MM. Motivo: ...` |
| `gestorSolicitarAlteracao` | `'ferias_alteracao_solicitada'` | `Alteração solicitada: DD/MM → DD/MM (Nd)` |
| `rhAprovarAlteracao` | `'ferias_alteracao_aprovada'` | `Alteração aprovada: DD/MM → DD/MM (Nd)` |
| `rhRecusarAlteracao` | `'ferias_alteracao_recusada'` | `Alteração recusada...` |
| `gestorSolicitarCancelamento` | `'ferias_cancelamento_solicitado'` | `Cancelamento solicitado...` |
| `rhAprovarCancelamento` | `'ferias_cancelamento_aprovado'` | `Cancelamento aprovado...` |
| `rhRecusarCancelamento` | `'ferias_cancelamento_recusado'` | `Cancelamento recusado. Motivo: ...` |
| `grhEnviarSolicitarGozo` | `'ferias_gozo_solicitado'` | `Gozo solicitado: saída DD/MM → retorno DD/MM (Nd)` |
| `rhAprovarGozoPendente` | `'ferias_gozo_aprovado'` | `Gozo aprovado: saída DD/MM, Nd dias` |

---

## Configuração parametrizada — `param_ferias_config` (migration 072, set/2026)

Tabela singleton de configuração do módulo Férias — ajustável pelo RH via Parâmetros Gerais sem alterar código.

### Estrutura

```sql
CREATE TABLE param_ferias_config (
  id                    INTEGER PRIMARY KEY DEFAULT 1,
  dias_resposta_visivel INTEGER NOT NULL DEFAULT 7,
  criado_em             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT param_ferias_config_singleton CHECK (id = 1)
);
```

RLS: `SELECT` e `UPDATE` públicos (mesmo padrão das outras tabelas `param_*`).

### Global `FERIAS_CONFIG`

```js
let FERIAS_CONFIG = { dias_resposta_visivel: 7 }; // default; sobrescrito no load
```

**Carregamento RH** (no `Promise.all` de `carregarDoSupabase`):
```js
sbGet('param_ferias_config', 'select=dias_resposta_visivel&limit=1').catch(() => [])
// após: if (configRows?.[0]) FERIAS_CONFIG = { ...FERIAS_CONFIG, ...configRows[0] };
```

**Carregamento Gestor** (no `Promise.all` do load do gestor — obrigatório também aqui):
```js
sbGet('param_ferias_config', 'select=dias_resposta_visivel&limit=1').catch(() => [])
// após: if (configRowsG?.[0]) FERIAS_CONFIG = { ...FERIAS_CONFIG, ...configRowsG[0] };
```

### Uso em `_gestorProcessoInfo`

`dias_resposta_visivel` define por quantos dias um desfecho (aprovado/rejeitado) permanece em **Atividade Recente** do Gestor antes de migrar para **Histórico**:

```js
const diasAtras = h.criado_em ? (Date.now() - new Date(h.criado_em).getTime()) / 86400000 : 999;
const ativoResolvido = diasAtras <= (FERIAS_CONFIG.dias_resposta_visivel ?? 7);
// desfechos: ativo = ativoResolvido (não hardcoded)
// pendências: ativo = true (sempre na Atividade Recente)
```

**Configurável em:** Parâmetros Gerais → seção "Configurações de Férias" → campo "Dias visível na Atividade Recente". PATCH em `param_ferias_config?id=eq.1`.

**Valor atual em produção (verificado out/2026):** `dias_resposta_visivel = 10`.

### `FERIAS_HISTORICO` — carregamento único por sessão (regra crítica)

`FERIAS_HISTORICO` é populado **uma única vez** em `initGestor` (ou `carregarDoSupabase` para RH). `renderGestorAtividade` **não recarrega** o array do banco — apenas relê o que está em memória.

**Consequência:** se a sessão do Gestor estava aberta *antes* de um evento ser gravado no banco (ex: RH aprovou enquanto o Gestor estava com a página aberta), o evento não aparecerá na Atividade Recente até um **F5 completo**. Isso não é um bug — é comportamento esperado de sessão stale.

**Diagnóstico confirmado (out/2026):** Marcelo Danilo Pazin (1682) e Francisco de Aquino Rodrigues (1710) desapareceram da Atividade Recente do Oriel porque a sessão estava aberta antes das aprovações (ids 16/17, gravadas em 10/10 às 13h11). Após F5, ambos reapareceram corretamente com botão "Ciente".

---

## Visual — itens rejeitados na Atividade Recente (set/2026 · unificado out/2026)

**Regra:** quando `cls === 'recus'`, a linha de período (datas) é renderizada com `color: var(--red)` — sinal semântico padrão de mercado, sem ícone adicional. **Vale para RH e Gestor.**

```js
// Em _itemRow de renderGestorAtividade (info.cls) e renderRhAtividade (cls):
const perLine = (inicio && fim)
  ? `<div class="gstor-ativ-per"${cls === 'recus' ? ' style="color:var(--red)"' : ''}>${fmtD(inicio)} → ${fmtD(fim)}${dias ? ' · ' + dias + 'd' : ''}</div>`
  : '';
```

`var(--red)` = `#B42318` (definido no `:root` do módulo). **Nunca usar `--text-danger`** — essa variável não existe no módulo.

---

## Visual — lista Gestor (Minha Equipe) — padrões visuais (set/2026)

### Grid da tabela

5 colunas: `grid-template-columns: 2.2fr 1.7fr 1.0fr 0.9fr 0.9fr`
(COLABORADOR | PA VIGENTE | AGENDAMENTOS | SALDO | SITUAÇÃO — espaçamentos finais set/2026)

Cabeçalho (`#gestorTableHead`) e cada linha (`gstor-row`) usam o mesmo grid. **Nunca voltar para 6 colunas** — a sexta coluna de ação foi fundida com Situação.

### Coluna Situação + Ação (última coluna)

Badge de situação e botão de ação ficam empilhados em `flex-direction:column;gap:6px` na mesma célula. O botão "Solicitar" azul foi removido — a linha toda é clicável e abre o drawer.

**Botões que permanecem** (contextuais, não redundantes com o drawer):

| Estado | Botão | Classe |
|---|---|---|
| Sem PA no banco | Solicitar | `gstor-btn-indigo` |
| Solicitação pendente | ⏳ Aguardando RH | `gstor-btn-amber` |
| Recusa sem nova solicitação | Ver recusa → | `gstor-btn-red-outline` |
| Demais casos | *(vazio)* | — |

### Coluna PA Vigente — alinhamento

`align-self: flex-start; padding-top: 2px` — âncora o número ao topo da célula para alinhar visualmente com a primeira linha da data de agendamento. Sem esse alinhamento, o número grande fica centralizado e "flutua" quando a célula vizinha tem duas linhas.

### `_renderAgendCell` — visual atualizado (set/2026)

```js
function _renderAgendCell(lRef, alertaHtml) {
  if (!lRef) return `<span style="font-size:11px;color:var(--text-ter);">—</span>`;
  return `<div style="font-size:12px;font-weight:500;color:#4B5565;white-space:nowrap;line-height:1.3;">${formatDate(lRef.inicio)} → ${formatDate(lRef.fim)}</div>
          <span style="display:inline-flex;align-items:center;margin-top:4px;padding:2px 7px;background:#EFF6FF;color:#1849A9;border-radius:10px;font-size:11px;font-weight:600;">${lRef.dias}d</span>
          ${alertaHtml || ''}`;
}
```

**Hierarquia visual:**
- Datas em `#4B5565` (cinza médio legível) com `font-weight:500` — não compete com o pill
- `Nd` em pill azul `#EFF6FF / #1849A9` — destaque principal da célula
- Alerta de dobra (`alertaHtml`) renderizado abaixo do pill, sem alteração

**Regra:** nunca igualar a cor da data à cor do pill — se ambos forem azuis, nenhum se destaca. A data é contexto; os dias são o dado operacional.

### KPI "Pendentes de aprovação"

Nome padronizado em ambas as visões (RH e Gestor). No Gestor, o card tem dois estados renderizados em `renderGestorAlerts`:
- **Âmbar** (`#FFFBEB / #FDE68A`) quando `aguardandoAprov.length > 0`
- **Verde** (`#ECFDF3 / #A7F3D0`) quando zerado

Ambos os estados exibem o label `"Pendentes de aprovação"` (não apenas `"Pendentes"`).

---

## Fluxos do Gestor — Alterar datas da solicitação e Retirar solicitação (commit `85373c9`, out/2026)

Implementa dois novos fluxos para o Gestor operar sobre períodos com status `'solicitado'` no `periodos[]` JSONB — enquanto o RH ainda não aprovou.

### Onde os botões aparecem

**Aba "Férias"** do drawer do colaborador (elemento `gsolListaRHConteudo`), renderizada por `_renderGsolHistoricoRH`. **Não confundir com a aba "Solicitações"** (`gsolLista`).

Regra de renderização dos botões em `_renderGsolHistoricoRH`:

```js
const stNormLanc    = (l.status||'').toLowerCase();
const isAprovadoLanc  = stNormLanc === 'aprovado' || stNormLanc === 'agendado';
const isSolicitadoLanc = stNormLanc === 'solicitado';
const isFuturoLanc = l.inicio > hoje;

// Botões de alteração/retirada — apenas solicitações futuras
if (isSolicitadoLanc && isFuturoLanc) {
  // exibe botões "Alterar datas" (azul outline) e "Retirar solicitação" (vermelho outline)
}
// Botões de acordo/gozo — apenas aprovados futuros
if (isAprovadoLanc && isFuturoLanc) {
  // botões existentes inalterados
}
```

### `_encontrarPeriodoSolicitado(perArr, lancInicio)`

Localiza um período em `periodos[]` pela data `inicio`, excluindo cancelados e excluídos. Bloqueia operação se houver ambiguidade (mais de um período com a mesma data de início).

```js
function _encontrarPeriodoSolicitado(perArr, lancInicio) {
  const candidatos = perArr.filter(p =>
    p.inicio === lancInicio && !['cancelado', 'excluido'].includes(p.status)
  );
  if (candidatos.length === 0) return { ok: false, motivo: 'Período não encontrado ou já cancelado.' };
  if (candidatos.length > 1)  return { ok: false, motivo: 'Mais de um período com a mesma data de início — operação bloqueada.' };
  return { ok: true, periodo: candidatos[0], idx: perArr.indexOf(candidatos[0]) };
}
```

**Por quê:** identifica por `inicio` (não por `p.id` nem por índice) — consistente com `gestorCancelarSolicitacao`.

### `gestorAbrirModalAltSol(colabId, periodoId, lancId)`

Reutiliza `#modalGestorAlt` (o mesmo modal de alteração de datas existente) com um novo título e flag `_modoSolicitado: true`.

```js
function gestorAbrirModalAltSol(colabId, periodoId, lancId) {
  // ...popula campos de data do modal com lancamento.inicio / lancamento.fim...
  _gestorAltCtx = { colabId, periodoId, lancId, slot, inicio, fim, dias, _modoSolicitado: true };
  const titleEl = document.querySelector('#modalGestorAlt .modal-title');
  if (titleEl) titleEl.textContent = 'Alterar datas da solicitação';
  btn.textContent = 'Alterar datas';
}
```

`fecharModalGestorAlt` sempre reseta o título para `'Solicitar alteração de data'`.

### `_gestorAltCtx._modoSolicitado` — switch em `gestorEnviarAlteracao`

`gestorEnviarAlteracao` verifica `ctx._modoSolicitado` no início. Quando `true`, entra no branch "alterar datas da solicitação":

1. Lê `periodos[]` da row atual (`per._feriasRow`) ou reconstrói de `GESTOR_LANCAMENTOS` (fallback registros antigos)
2. Chama `_encontrarPeriodoSolicitado` para localizar o período pelo `ctx.inicio`
3. Atualiza `periodos[idx].inicio` e `periodos[idx].fim` com as novas datas
4. PATCH condicional: filtro `id=eq.{periodoId}&status=eq.Pendente`  
   **Também sincroniza flat fields (commit 1f01f91):** `patchData` inclui `periodo1_*` ou `periodo2_*` conforme `ctx.slot`
5. Se retornar array vazio → conflito de concorrência (toast de erro, sem atualizar memória local)
6. Se sucesso → atualiza memória local SOMENTE a partir do `_rowsAltSol[0]` retornado pelo banco

**Motivo da sincronização:** antes de 1f01f91, alterar datas de uma solicitação pendente atualizava apenas `periodos[]`, deixando os flat fields com os valores da solicitação original. Ao combinar retirada + nova solicitação em fluxos rápidos, essa divergência podia causar inconsistência entre as visões RH e Gestor.

**TextContent do botão no catch:** `ctx?._modoSolicitado ? 'Alterar datas' : 'Enviar para RH aprovar'`

### `gestorConfirmarRetirada(colabId, feriasId, lancId)`

Exibe modal de confirmação antes de retirar a solicitação.

**CRÍTICO:** usa `abrirModalConfirm` com `texto` em **plain text** — NUNCA passar tags HTML. `abrirModalConfirm` usa `textContent` internamente, não `innerHTML`. Tags como `<strong>` serão renderizadas literalmente.

```js
function gestorConfirmarRetirada(colabId, feriasId, lancId) {
  // ...
  abrirModalConfirm({
    titulo: 'Retirar solicitação',
    texto: `Retirar a solicitação de ${formatDate(lancamento.inicio)} → ${formatDate(lancamento.fim)} (${lancamento.dias}d) de ${nomeColab}? O saldo retorna ao PA.`,
    labelOk: 'Retirar solicitação',
    corOk: '#D92D20',
    cb: () => gestorExecutarRetirada(feriasId, colabId, lancId),
  });
}
```

### `gestorExecutarRetirada(feriasId, colabId, lancId)`

Marca o período como `status: 'cancelado'` em `periodos[]` e atualiza o status do PA.

**Lógica de status pós-retirada:**
```js
const _restaSolicit = perArr.some(p => p.status === 'solicitado');
const novoStatus = _restaSolicit
  ? 'Pendente'
  : (_statusProteger.includes(row.status) ? row.status : 'Aprovado');
// _statusProteger = ['Alteracao_Solicitada', 'Cancelamento_Solicitado']
// Se ainda há outros períodos solicitados → permanece Pendente
// Se não há mais solicitados e o PA não está em outro estado protegido → volta a Aprovado
if (!_restaSolicit) patchData.obs_gestor = null;
```

**Sincronização de flat fields (commit 1f01f91):**
Além de atualizar `periodos[]`, o PATCH também limpa os flat fields do slot retirado:
```js
const _slotRetirada = String(lancId).endsWith('-p2') ? 'p2' : 'p1';
if (_slotRetirada === 'p1') { patchData.periodo1_inicio = null; patchData.periodo1_fim = null; patchData.dias1 = 0; }
else { patchData.periodo2_inicio = null; patchData.periodo2_fim = null; patchData.dias2 = 0; }
```
**Motivo:** antes dessa correção, o PATCH atualizava `periodos[]` mas deixava os flat fields com as datas antigas, gerando inconsistência entre os dois mecanismos de leitura.

**PATCH condicional:** filtro `id=eq.{feriasId}&status=eq.Pendente` com `Prefer: return=representation`. Array vazio na resposta = conflito (outra sessão modificou o registro).

**Memória local:** atualiza `GESTOR_LANCAMENTOS` (remove o lancamento retirado) e `per._feriasRow` SOMENTE a partir do `_rowsRetirada[0]` retornado — nunca de dados locais.

### `aprovarPendente` — pre-check + PATCH condicional com `atualizado_em` (commit `85373c9`)

Antes do PATCH de aprovação, `aprovarPendente` agora faz uma leitura do estado atual do registro para detectar concorrência:

```js
// 1. Lê estado atual
const rows = await sbGet('ferias', `id=eq.${reg._sbId}&select=status,periodos,obs_gestor,atualizado_em`);
const registroAtual = rows[0];

// 2. Bloqueia se já não está Pendente
if (registroAtual.status !== 'Pendente') { /* toast + return */ }

// 3. Bloqueia se as datas do período solicitado foram alteradas pelo Gestor após o RH abriu o modal
const solAtualNoDb = (registroAtual.periodos || []).find(p => p.status === 'solicitado');
if (solAtualNoDb && (solAtualNoDb.inicio !== nl.inicio || ...)) { /* toast "datas foram alteradas" */ }

// 4. PATCH condicional com timestamp
const tsLido = registroAtual.atualizado_em;
const _filtroCondicional = `id=eq.${reg._sbId}&status=eq.Pendente&atualizado_em=eq.${encodeURIComponent(tsLido)}`;
// PATCH com Prefer: return=representation
// Array vazio → conflito → toast, re-enable botão, return
```

**Importante:** o pre-check usa `sbGet` padrão; o PATCH usa `_sbFetch` direto com `Prefer: return=representation` para detectar 0 rows affected.

### Novas ações em `ACAO_LABEL`, `ACAO_CLS` e `acaoCor`

Adicionadas em 3 locais no arquivo (`ferias_historico` rendering, Gestor atividade, RH atividade):

| `acao` | Label | Cor | Classe CSS |
|---|---|---|---|
| `solicitacao_retirada` | `'Solicitação retirada'` | `#B45309` | `'cancel-sol'` |
| `solicitacao_datas_alteradas` | `'Datas da solicitação atualizadas'` | `#1570EF` | `'neutro'` |

### Teste de concorrência T4 — implementado, não validado em ambiente real

O PATCH condicional de `gestorExecutarRetirada` e o branch `_modoSolicitado` de `gestorEnviarAlteracao` protegem contra concorrência via `status=eq.Pendente` no filtro. `aprovarPendente` usa adicionalmente `atualizado_em=eq.{tsLido}`.

**T4 não foi executado na aplicação real** — testaria duas sessões simultâneas. A proteção está implementada no código mas não foi validada em prática.

---

## Relatórios RH e Gestor — Regra de filtro por início + Acordos de Gozo (realizações) — out/2026, commit `b7c67dd`

### Regra de filtro por data de início (implementada)

Relatório RH (`_getDadosRelatorio`) e Gestor (`gestorGerarRelatorio`) incluem **apenas períodos cuja data de `inicio` esteja dentro do mês selecionado** — não basta sobreposição com o mês.

- Filtro RH (lançamentos): `l.inicio >= mesInicio && l.inicio <= mesFim`
- Filtro Gestor (já existente via `processGestorFerias`): mesmo critério aplicado em `GESTOR_LANCAMENTOS`
- Gantt, Mapa Anual, drawer, saldos: **inalterados** — continuam usando sobreposição

### Dois tipos de acordo de gozo — distinção crítica

| Tipo | Como é salvo | Como aparece no relatório |
|---|---|---|
| **Madson-type** | Salvo como lançamento regular em `periodos[]` (tem `inicio` no mês) | Aparece naturalmente — código inalterado |
| **Daniele-type** | Salvo em `reg.realizacoes` JSONB separado (lançamento pai tem `inicio` fora do mês) | Requeria código adicional — corrigido |

### `_getDadosRelatorio` — bloco de realizações adicionado (RH)

Após iterar `reg.lancamentos`, a função agora também percorre `reg.realizacoes`:

```js
const _realizSet = new Set(); // dedup por saida, escopo por colaborador
// ...dentro do forEach de registros:
if (reg.status === 'Aprovado' && chkAprov) {
  (reg.realizacoes || []).forEach(rx => {
    if (!rx.saida || !(Number(rx.dias) > 0)) return;
    if (rx.saida < mesInicio || rx.saida > mesFim) return;          // saida no mês
    const lancPai = reg.lancamentos[Number(rx.lancIdx ?? 0)];
    if (lancPai && lancPai.inicio >= mesInicio && lancPai.inicio <= mesFim) return; // pai já no mês
    if (_realizSet.has(rx.saida)) return;                            // dedup cross-PA
    _realizSet.add(rx.saida);
    linhas.push({ ..., inicio: rx.saida, fim: rx.retorno || rx.saida, dias: rx.dias, status: 'Aprovado' });
  });
}
```

**`lancIdx`**: campo de cada `realizacao` que aponta para o índice do lançamento pai em `reg.lancamentos[]`. `rx.lancIdx ?? 0` — fallback para índice 0 quando ausente.

**`_realizSet` por colaborador**: previne que a mesma realização (mesma `saida`) registrada em dois PAs diferentes (Daniele pattern — rows 972 e 973) apareça duplicada.

### `gestorGerarRelatorio` — deduplicação de realizações (Gestor)

`processGestorFerias` já converte realizações em lançamentos com flag `_isRealizacao: true` dentro de `GESTOR_LANCAMENTOS`. O problema era deduplicação insuficiente. Bloco adicionado após o filtro existente:

```js
const _parentLancsPresentes = new Set(
  lancs.filter(l => !l._isRealizacao).map(l => `${l.colaborador_id}|${l.periodo_id}`)
);
const _seenRealizacoes = new Set();
lancs = lancs.filter(l => {
  if (!l._isRealizacao) return true;
  if (_parentLancsPresentes.has(`${l.colaborador_id}|${l.periodo_id}`)) return false; // pai já presente
  const _k = `${l.colaborador_id}|${l.inicio}`;
  if (_seenRealizacoes.has(_k)) return false;                        // dedup cross-PA
  _seenRealizacoes.add(_k);
  return true;
});
```

**RH e Gestor usam a mesma regra de negócio.** A diferença é apenas de escopo: RH vê todos os colaboradores (conforme filtros/permissões); Gestor vê somente sua equipe.

### Padrão de erro de dados — rows com `periodos=[]` e `periodo1_inicio` com data incorreta

Registros históricos (PAs encerrados) com `periodos = []` usam o caminho de fallback em `supabaseParaModelo` e `processGestorFerias`: leem `periodo1_inicio`/`dias1` como fonte do lançamento. Se `periodo1_inicio` contiver uma data de ano errado (ex: `'2026-11-02'` em um PA encerrado em 2022), o fallback gera um lançamento fantasma que passa pelo filtro do mês correspondente.

**Caso Anderson (row 1864):** PA 2022 (`pa_fim='2022-10-31'`) tinha `periodo1_inicio='2026-11-02'` — data incorreta. Gerava 20 dias fantasmas no relatório de novembro/2026. **Corrigido:** `PATCH ferias?id=eq.1864` com `{"periodo1_inicio": null}`. As 3 realizações históricas (gozo real de 2022/2023) foram preservadas intactas.

**Caso Heloisa (row 1016):** PA 2025 com `periodo1_inicio='2026-01-26'`. **Mantido sem alteração** — pode ser agendamento válido de férias vencidas. Confirmar antes de corrigir.

**Como investigar:** buscar `ferias?pa_fim=lt.2025-01-01&periodo1_inicio=not.is.null&periodos=eq.[]` para encontrar outros registros no mesmo padrão.

### Correção adicional — `_getDadosEscalaGestor` (commit `549b8cc`)

A função `_getDadosEscalaGestor` (usada por PDF e Excel do Gestor) usava filtro de **sobreposição**:
```js
// antes (errado):
if ((l.inicio||'') > mesFim || (l.fim||'') < mesInicio) return;
```
Isso incluía colaboradores que saíram em outubro com retorno em novembro. Corrigido para o mesmo critério do RH:
```js
// depois (correto):
if ((l.inicio||'') < mesInicio || (l.inicio||'') > mesFim) return;
```
PDF e Excel do Gestor compartilham `_getDadosEscalaGestor` — ambos corrigidos com uma linha.

### Validação — testado em produção (19/10/2026)

- RH: 12 registros em novembro, todos com `inicio` em novembro — correto
- Gestor (PDF e Excel): Fagner, Francisco e Marcelo (inicio outubro) deixaram de aparecer — correto
- Daniele: realização `saida='2026-11-10'` (10d) aparece uma vez em novembro — confirmado
- Anderson: 20 dias fantasmas não aparecem mais (row 1864 corrigida); 4 dias legítimos (row 1856) permanecem
- Lançamentos normais: inalterados
- Gantt, Mapa Anual, drawer, saldos: sem alterações
