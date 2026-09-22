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
- `gestor` = texto legado; **não mais usado para identificar equipe** (ver `_carregarEquipeGestor` abaixo)
- O campo `gestor` **deve estar no `select=`** da query — ainda é usado pelo filtro secundário `gestorFiltroGestor` dentro da lista carregada

### `ferias`
`id, colaborador_id, matricula_colaborador, ano, pa_inicio, pa_fim, status, dias_antecipados, abono_pecuniario` + colunas de lançamentos

### `ferias_historico` (criada 2026-09-14)

Tabela de auditoria imutável — nunca editada, só recebe INSERT.

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | bigserial PK | auto |
| `ferias_id` | bigint | FK para `ferias.id` |
| `colaborador_id` | bigint | FK para `colaboradores.id` |
| `acao` | text | `'solicitado'` / `'aprovado'` / `'rejeitado'` |
| `usuario` | text | Nome/email de quem executou a ação |
| `detalhe` | jsonb | Snapshot do evento (`inicio`, `fim`, `dias`, `obs_gestor`, `slot`) |
| `criado_em` | timestamptz | Gerado pelo banco (`DEFAULT NOW()`) |

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

**Campo `ano` em GESTOR_PERIODOS (crítico — corrigido 2026-09-10):**
O objeto `periodo` em `processGestorFerias` inclui explicitamente `ano: row.ano`. **Nunca usar `pa.pa_inicio?.slice(0,4)` para derivar o ano do PA** — colaboradores com aniversário no 2º semestre têm `pa_inicio` no ano anterior ao PA real (ex: PA 2027 começa em set/2026 → slice retorna "2026", errado). Usar sempre `pa.ano` diretamente.

**Busca gestor (`gestorBusca`) — comportamento correto (corrigido 2026-09-10):**
`gestorBuscaSelecionar(colabId)` apenas fecha o dropdown e abre o drawer — **não limpa o input**. O texto digitado permanece no campo após fechar o drawer, permitindo nova seleção sem redigitar. O botão ✕ (`gestorBuscaLimpar`) é o único que deve limpar o campo.

**Situação no export gestor — critério correto (corrigido 2026-09-10):**
Usa `!lRef` (não `!lancs.length`) para determinar "Sem agendamento". `lRef = ativo || futuro` — só há agendamento se existir lançamento ativo hoje ou futuro. Lançamentos concluídos no passado **não** contam como "Agendado".

**Coluna Agendamentos — `lRef` sem fallback para passado (corrigido 2026-09-11):**
Tanto na visão RH quanto no Gestor, `lRef = ativo || futuro` — **sem `|| passado`**. Lançamentos já concluídos (`fim < hoje`) não devem aparecer na coluna Agendamentos mesmo que pertençam ao PA vigente com saldo pendente. A coluna exibe `—` nesses casos. O fallback `|| passado` existia em ambas as funções de render e foi removido das duas.

**Exportação gestor — 8 colunas (PDF e Excel):**
Nome | Cargo | Ano PA | Período Aquisitivo | Férias Início | Férias Fim | Saldo | Situação

- Separador de setor usa `colspan="8"` — atualizar se adicionar/remover colunas
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
- **Excel — AutoFilter + Freeze:** `<x:AutoFilter x:Range="A3:H3"/>` ativa setas de filtro nas 8 colunas. Freeze nas 3 primeiras linhas via `<x:SplitHorizontal>3</x:SplitHorizontal>` + `<x:TopRowBottomPane>3</x:TopRowBottomPane>`. Ajustar range se mudar número de colunas.

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
gestorSaldoPeriodo(pa)
// Implementação correta:
// const direito    = Number(periodo.dias_direito) || 30;
// const abono      = Number(periodo._feriasRow?.abono_pecuniario) || 0;
// const antecipados = Number(periodo._feriasRow?.dias_antecipados) || 0;
// const usados     = GESTOR_LANCAMENTOS.filter(...).reduce(...);
// return direito - usados - abono - antecipados;
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

## Identificação de equipe do gestor — arquitetura parametrizada (set/2026)

**Regra definitiva:** a equipe de um gestor nunca é definida por comparação de texto livre. O fluxo correto é:

```
usuarios_perfil.colaborador_id
  → param_gestor.id (gestor_id)
  → param_gestor_setor.setor_id (setores responsáveis)
  → param_setor.descricao (nomes dos setores)
  → colaboradores.setor IN (descricoes) + data_demissao IS NULL
```

### `_carregarEquipeGestor(gestor_id)`

- **`gestor_id` fornecido** (gestor puro): percorre a cadeia acima em 3 queries
- **`gestor_id = null`** (RH/admin): carrega todos os colaboradores ativos sem restrição

```js
if (gestor_id) {
  const setorLinks = await sbGet('param_gestor_setor', `gestor_id=eq.${gestor_id}&ativo=eq.true&select=setor_id`);
  const setorIds = setorLinks.map(r => r.setor_id).join(',');
  const setorRows = await sbGet('param_setor', `id=in.(${setorIds})&select=descricao`);
  const descricoes = setorRows.map(r => `"${r.descricao}"`).join(',');
  colabQuery = `setor=in.(${descricoes})&data_demissao=is.null&select=...`;
}
```

### `initGestor()` — fluxo do gestor puro

```js
const pgRows = await sbGet('param_gestor', `colaborador_id=eq.${colaborador_id}&select=id,nome&limit=1`);
GESTOR_APELIDO = pgRows[0].nome || '';   // nome para display e flag de vista restrita
await _carregarEquipeGestor(pgRows[0].id);  // passa gestor_id numérico, não texto
```

### `GESTOR_APELIDO` — papel atual

Variável string. Truthy = gestor puro (filtro `gestorFiltroGestor` fica oculto). Null = RH/admin (filtro visível). Nunca mais é usada para query de colaboradores.

### Filtro dropdown de gestores (`gestorFiltroGestor`)

Filtro **secundário dentro da lista já carregada**. Popula de `param_gestor` (campo `apelido`) para evitar duplicatas por capitalização:

```js
// Dentro de renderGestorAtencao (NÃO async) — usar .then(), nunca await
sbGet('param_gestor', 'select=apelido&ativo=eq.true&order=ordem').then(pgRows => {
  const gestores = pgRows.map(r => r.apelido).filter(Boolean);
  gestores.forEach(g => { const o = document.createElement('option'); o.value = g; o.textContent = g; gestorSel.appendChild(o); });
}).catch(() => { /* fallback: distinct de colaboradores */ });
```

O filtro compara `c.gestor` (campo legado) contra o apelido selecionado — funciona para triagem visual mas **não é a fonte de verdade da equipe**.

### Armadilha: `colaboradores.setor` precisa estar em sincronia com `param_setor.descricao`

A busca por `setor=in.(descricoes)` é case-sensitive e exata. Em set/2026 foram corrigidos 214 colaboradores que tinham formato antigo "código - nome" (ex: "148 - Matriz Vendas"). O formato correto é apenas o nome curto (ex: "Matriz Vendas"), igual a `param_setor.descricao`. Se um colaborador não aparecer na equipe do gestor, verificar:
```sql
SELECT DISTINCT setor FROM colaboradores WHERE data_demissao IS NULL ORDER BY setor;
SELECT descricao FROM param_setor ORDER BY descricao;
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

## Timeline Gantt — regras de renderização de barra

Barras são renderizadas célula a célula. Cada barra é desenhada **na célula do `drawDay`** (primeiro dia visível no mês):
```js
const drawDay = l.inicio >= mesInicio ? l.inicio : mesInicio;
```

**Label da barra:** usa `colsOriginais` (duração total do lançamento, não apenas dias visíveis) para decidir o threshold:
```js
const colsOriginais = Math.max(1, Math.round((new Date(l.fim+'T12:00:00') - new Date(l.inicio+'T12:00:00')) / 86400000) + 1);
let label = '';
if (colsOriginais >= 9) label = `${fmtShort(l.inicio)} → ${fmtShort(l.fim)} · ${l.dias}d`;
else if (colsOriginais >= 4) label = `${l.dias}d`;
```

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

**Foto do colaborador:** visão RH usa `c.fotoUrl` (camelCase), visão Gestor usa `c.foto_url` (snake_case):
```js
// RH:
c.fotoUrl ? `<img class="gantt-av" src="${c.fotoUrl}"...>` : `<div class="gantt-av">...</div>`
// Gestor:
c.foto_url ? `<img class="gantt-av" src="${c.foto_url}"...>` : `<div class="gantt-av">...</div>`
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

### Realizações não aparecem na Timeline

**Regra:** a Timeline mostra apenas períodos registrados/aprovados (`periodo1`, `periodo2`). Realizações (gozo real) são retrospectivas e pertencem ao drawer de detalhes.

Em `processGestorFerias`, todos os lançamentos gerados a partir de `row.realizacoes` recebem `_isRealizacao: true`. Em `renderGestorGantt`, filtrar ao construir `lancColabs`:
```js
const lancColabs = GESTOR_LANCAMENTOS.filter(l => l.colaborador_id === c.id && !l._isRealizacao);
```

A visão RH não tem esse problema — `todosLancs` é construído de `reg.lancamentos` (só `periodo1`/`periodo2`), sem incluir realizações.

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
// Card Pendentes (renderGestorAlerts):
const aguardAprov = GESTOR_LANCAMENTOS.filter(l => {
  const st = (l.status||'').toLowerCase();
  if (st === 'solicitado') return true;           // sem filtro de data
  return st === 'recusado' && l.fim >= hoje;
});

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

```js
async function _logAtiv(feriasId, colabId, acao, usuario, detalhe) {
  const entry = { ferias_id: Number(feriasId), colaborador_id: Number(colabId), acao, usuario: usuario || null, detalhe: detalhe || null };
  try { await sbPost('ferias_historico', entry); } catch(_) {}
  FERIAS_HISTORICO.unshift({ ...entry, id: Date.now(), criado_em: new Date().toISOString() });
}
```

O `unshift` garante atualização otimista de `FERIAS_HISTORICO` mesmo que o POST falhe silenciosamente.

### Onde `_logAtiv` é chamado

| Função | `acao` | `usuario` | `detalhe` |
|---|---|---|---|
| `gestorEnviarSolicitacao` | `'solicitado'` | `GESTOR_NOME_USUARIO` | `{ inicio, fim, dias, slot }` |
| `rhAprovarSolicitado` | `'aprovado'` | `perfil.nome \|\| 'RH'` | `{ status: 'Aprovado' }` |
| `rhRecusarSolicitado` | `'rejeitado'` | `perfil.nome \|\| 'RH'` | `{ status: 'Rejeitado', obs_gestor: motivo }` |

`perfil` = `JSON.parse(localStorage.getItem('sb_perfil') || '{}')`.

### Atividade Recente — arquitetura atual (baseada em `FERIAS_HISTORICO`)

`renderGestorAtividade()` e `renderRhAtividade()` leem **diretamente de `FERIAS_HISTORICO`** — já ordenado por `criado_em DESC` conforme vem do Supabase.

**Filtros:**
- 90 dias: `h.criado_em >= _cutoff90str` (ISO string comparável diretamente)
- Arquivados: `!_dismissedG.has(String(h.id))` — dismiss key é o `h.id` numérico como string

**Dismiss key:** `String(h.id)` — simples e único. Salvo em localStorage por tipo: `ferias_ativ_dismissed_g` (Gestor) e `ferias_ativ_dismissed_r` (RH).

**Helpers de dismiss/restore:**
- `_ativDismissed(tipo)` → `Set` dos ids arquivados
- `_ativDismiss(tipo, key)` → arquiva um item + re-render
- `_ativDismissAll(tipo, keys)` → arquiva todos visíveis
- `_ativRestore(tipo, key)` → restaura item arquivado
- `_gestorAtivMostrarArq` / `_rhAtivMostrarArq` → bool que controla seção de arquivados

**O que cada item exibe:**
- Nome e cargo do colaborador
- Período de férias (`detalhe.inicio → detalhe.fim · dias`)
- Data/hora exata + nome do usuário (`fmtDH(h.criado_em) · h.usuario`)
- Chip de status (Solicitado / Aprovado / Recusado)
- Botão × para arquivar

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
toast('✓ Gozo aprovado e registrado!');
```
**Por quê:** erros na re-renderização (JS, não Supabase) eram capturados pelo mesmo catch e exibiam "Erro ao salvar" mesmo quando o PATCH havia funcionado.

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
| `_buildRelatorioHTML(linhas, mesLabel)` | Gera HTML para **PDF/visualização**: ícone 📅, cabeçalho azul escuro, separador por empresa, legenda com bolinhas CSS, footer `position:fixed` |
| `_buildExcelHTML(linhas, mesLabel)` | Gera HTML para **Excel**: sem emoji, sem `position:fixed`, legenda em células coloridas, **todos os estilos inline** (Excel ignora `<style>`) |
| `exportarRelatorioPDF()` | Abre nova aba com `_buildRelatorioHTML` |
| `exportarRelatorioExcel()` | Gera blob `.xls` com `_buildExcelHTML` |

### Campo empresa

`c.empresa` (não `c.empresaRegistro`) é o campo correto na camada de dados do módulo férias. `c.empresaRegistro` nunca é preenchido neste módulo.

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
- "Visualizar PDF" → `gestorExportarPDF()` — abre nova aba com relatório visual
- "Exportar Excel" → `gestorExportarExcel()` — baixa `.xls` com inline styles
- `toggleGestorExportMenu()` controla abertura/fechamento (fecha ao clicar fora via `document.addEventListener`)

**8 colunas (PDF e Excel):** Nome | Cargo | Ano PA | Período Aquisitivo | Férias Início | Férias Fim | Saldo | Situação

- **Setor removido** das colunas — separador colorido entre grupos já identifica a área
- **Ano PA:** usa `pa.ano` (campo do banco, fonte correta) — ex.: `2025` ou `2027`. **Não usar `pa.pa_inicio.slice(0,4)`**: colaboradores com aniversário no 2º semestre têm `pa_inicio` no ano anterior ao PA real (PA 2027 inicia em set/2026 → slice retornaria "2026", errado).
  - Fallback: `pa.pa_inicio?.slice(0,4)` só se `pa.ano` for nulo
  - `semPA`: usa `fimPrev.slice(0,4)` (ano em que o PA termina). **Nunca** `fimPrev.year - 1`
- **Período Aquisitivo:** datas completas `DD/MM/AAAA → DD/MM/AAAA`
- **Férias Início / Férias Fim:** duas colunas — `_fmtData(lRef.inicio)` e `_fmtData(lRef.fim)`, ou `'—'` quando sem lançamento
- **Saldo:** cor semântica — azul (`#1570EF`) >5d, âmbar (`#F59E0B`) ≤5d, verde (`#10B981`) zerado — helper `_saldoCor(saldo)`
- **Situação — diferença intencional entre PDF e Excel:**
  - **PDF:** badge pill colorido com borda arredondada — helper `_sitBadge(sitKey, situacao)` — visual mais rico
  - **Excel:** célula com fundo colorido — helper `_sitXls(sitKey)` — Excel ignora HTML de badge
- **Situação com data da dobra:** níveis de risco exibem `"Nível · Dobra em DD/MM/AAAA"` (campo `situacao`). Campo `sitKey` = só o nível para lookup de cor
- Separador de setor: `colspan="8"`, fundo da cor do setor
- **Filtros respeitados:** cargo e gestor ativos. **Busca (`gestorBusca`) é ignorada** — é filtro de navegação na tela, não deve restringir exportação
- **Guards de segurança:** se `GESTOR_COLABS.length === 0` → toast aviso + return. Se `linhas.length === 0` → toast aviso + return (nunca gerar arquivo vazio)
- **Download (Excel):** obrigatório `document.body.appendChild(a); a.click(); document.body.removeChild(a); URL.revokeObjectURL(url)` — sem appendChild o click falha silenciosamente em alguns browsers
- **`_normG` deve ser definida localmente** em cada função (`gestorExportarPDF` e `gestorExportarExcel`) — não é global. Usar para comparação do filtro de gestor: `_normG(c.gestor) === _normG(gestorf)`
- **Excel — AutoFilter + Freeze:** `<x:AutoFilter x:Range="A3:H3"/>` + freeze 3 linhas (`SplitHorizontal=3`, `TopRowBottomPane=3`). Atualizar range se mudar colunas.

**Cores de situação** (usadas em `_sitBadge` e `_sitXls`):

| Situação | bg | text |
|---|---|---|
| Crítico | `#FEE2E2` | `#7F1D1D` |
| Atenção | `#FDE68A` | `#78350F` |
| No radar | `#DBEAFE` | `#1E3A8A` |
| Agendado / Concluído | `#ECFDF3` | `#027A48` |
| Sem agendamento | `#FFFAEB` | `#92400E` |
| Período futuro | `#EFF6FF` | `#1849A9` |

**`gestorExportarExcel()`** — estilos 100% inline (Excel ignora `<style>`); separador `colspan="8"`.

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
_dirSaldoColab(colab)   // soma calcSaldo(r) de todos os registros do colaborador
_dirUrgSemProg(colab)   // retorna { nivel, dlim } do PA mais urgente sem programação
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
| Timeline | `dirTlFiltroCargo`, `dirTlFiltroSetor`, `dirTlFiltroUnidade` | `_dirTlFiltrados()` |

`renderDiretoria()` **não propaga** nem chama `renderDirTimeline()` — as abas são completamente independentes.

`_dirTlPopularFiltros()` — chamada quando a aba Timeline é ativada; popula os selects a partir de `COLABORADORES` ativos.

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
      <!-- idem dirTlFiltroSetor, dirTlFiltroUnidade -->
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

## Pendências conhecidas

- Módulo WhatsApp (link wa.me por colaborador) — dados já no Supabase, falta UI
- Aprovação em lote
- Eliminar aba "Solicitações" permanentemente (aguardando testes do novo fluxo unificado)
- Visão Diretoria — validar banda base (47 ativos / 31 com PA / 16 sem PA) como elemento de design permanente ou remover
