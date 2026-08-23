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

## Visão Gestor — arquitetura de dados

A visão Gestor usa arrays **separados** (não a estrutura `COLABORADORES[].registros[].lancamentos[]` da visão RH):

| Variável global | Conteúdo |
|---|---|
| `GESTOR_COLABS` | colaboradores do gestor logado |
| `GESTOR_PERIODOS` | todos os PAs dos colaboradores |
| `GESTOR_LANCAMENTOS` | todos os lançamentos, campo `inicio`/`fim` (NÃO `data_inicio`/`data_fim`) |

`processGestorFerias(rows)` — constrói GESTOR_PERIODOS e GESTOR_LANCAMENTOS a partir das rows do Supabase. Lançamentos gerados usam `inicio`/`fim` (consistente com as rows da tabela `ferias`).

**Nunca usar `data_inicio` ou `data_fim` em GESTOR_LANCAMENTOS** — esses campos não existem nos objetos gerados por `processGestorFerias`. Qualquer ordenação ou comparação de datas de lançamento usa `l.inicio` e `l.fim`.

## Visão Gestor — funções canônicas

```js
// Retorna o PA mais antigo com saldo > 0 e não expirado
gestorPeriodoAtivo(colaborador_id)

// True se colaborador tem lançamento aprovado/agendado/gozado com fim >= hoje
gestorIsAgendado(colabId)
// Nota: inclui status 'gozado' com fim >= hoje (colaborador em férias agora, gozo já registrado)

// Dias até o prazo de dobra do PA
gestorDpd(pa)

// Saldo restante do PA (dias_direito - dias já lançados)
gestorSaldoPeriodo(pa)
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

**Coluna Agendamentos:** mostra apenas lançamentos do `paEfetivo` (`lancsPa`), não de PAs históricos. Colaborador com PA 2027 e lançamento apenas no PA 2026 encerrado mostra `—` na coluna, não o lançamento antigo.

## Visão Gestor — paEfetivo (padrão crítico)

Quando o filtro `'agendado'` está ativo, o colaborador pode ter `pa = null` (saldo zerado, todos os dias já agendados). Para exibir corretamente o PA e o saldo, usar `paEfetivo`:

```js
const _lancRelev = GESTOR_LANCAMENTOS.find(l =>
  String(l.colaborador_id) === String(c.id) &&
  ['aprovado','agendado','gozado'].includes((l.status||'').toLowerCase()) &&
  (l.fim||'') >= hoje
);
const _paRelev = _lancRelev
  ? GESTOR_PERIODOS.find(p => String(p.id) === String(_lancRelev.periodo_id))
  : null;

// No filtro agendado: prioriza o PA do lançamento futuro (não o gestorPeriodoAtivo)
// Fora do filtro: usa gestorPeriodoAtivo, com fallback para _paRelev
const paEfetivo = _gestorAlertaAtivo === 'agendado'
  ? (_paRelev || pa)
  : (pa || _paRelev);
```

Todos os cálculos de exibição (dpd, saldo, total, pct, cores, badge, paAno) usam `paEfetivo`.
**Botão "Solicitar"** continua usando `pa` (gestorPeriodoAtivo) — é onde novas solicitações são feitas.

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

## Filtro dropdown de gestores (Visão Gestor)

Sempre buscar de `param_gestor` (campo `apelido`, filtro `ativo=eq.true&order=ordem`), **não** de valores distintos da coluna `colaboradores.gestor`. Isso evita duplicatas por variação de capitalização.

```js
// Dentro de renderGestorAtencao (NÃO async) — usar .then(), nunca await
sbGet('param_gestor', 'select=apelido&ativo=eq.true&order=ordem').then(pgRows => {
  const gestores = pgRows.map(r => r.apelido).filter(Boolean);
  gestores.forEach(g => { const o = document.createElement('option'); o.value = g; o.textContent = g; gestorSel.appendChild(o); });
}).catch(() => { /* fallback: distinct de colaboradores */ });
```

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
// Em renderListaAnual, linha ~4223
const _comSaldo = pasDoAno.filter(r => calcSaldo(r) > 0);
const reg = _comSaldo.length > 0
  ? _comSaldo[0]                      // mais antigo com saldo (regra CLT)
  : pasDoAno[pasDoAno.length - 1];    // mais recente (todos concluídos)
```

**Por quê:** `pasDoAno` é ordenado por `paInicio` ascendente. Sem esta lógica, colaboradores com todos os PAs concluídos exibem o PA mais antigo (ex: 2019) em vez do mais recente.

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

## Pendências conhecidas

- Módulo WhatsApp (link wa.me por colaborador) — dados já no Supabase, falta UI
- Aprovação em lote
