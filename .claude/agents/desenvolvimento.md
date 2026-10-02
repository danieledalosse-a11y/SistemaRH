---
name: desenvolvimento
description: Especialista no módulo Desenvolvimento & Performance do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/desenvolvimento/index.html ou nas migrations dp_* do Supabase.
---

# Skill: Módulo Desenvolvimento & Performance — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil Acabamentos Ltda (varejo, Lucro Real).
Stack: HTML + CSS + JS puro, sem framework. Backend: Supabase REST API.
Arquivo principal: `C:\Users\reves\SistemaRH\modulos\desenvolvimento\index.html` (~2.700 linhas, tudo inline).

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo permanece inline no index.html.
2. **Nunca usar a chave secreta do Supabase no browser** — chave publicável apenas.
3. **Sempre apresentar proposta antes de implementar** — aguardar aprovação da usuária.
4. **Nunca abreviar valores** (`R$ 12.500,00`, não `12,5k`).
5. **`guardModulo('desenvolvimento')` obrigatório** — chamado na primeira linha de `initAuth()`; ver [[permissoes]].
6. **Não tocar nas abas legadas** (Colaboradores, Ciclos de Avaliação) — usam tabelas dev_* que ainda coexistem com as dp_*. Só alterar com aprovação explícita.
7. **Imutabilidade de versões e escalas publicadas é garantia do banco** — o front deve verificar `em_uso` e desabilitar campos, mas o trigger do banco é a proteção real. Tratar erros HTTP 4xx com mensagem clara ao usuário.
8. **Não misturar dados financeiros com valor_numerico da escala** — `valor_numerico` serve para cálculo/comparação; valores financeiros ficam em `dp_regras_financeiras`.
9. **verde/laranja/amarelo (melhorou/piorou/manteve/sem_comparacao) são calculados na camada de apresentação** — nunca armazenar no banco.
10. **Legibilidade mínima 11px** para qualquer texto informativo; usar tokens `--text-sec/#4B5565` e `--text-ter/#6C7589`.
11. **Biblioteca de Critérios usa `dp_criterios` exclusivamente** — `dev_competencias` é legado preservado para referência histórica, nunca exibida na UI.

---

## Diretriz arquitetural permanente — Motor genérico

**Antes de implementar qualquer etapa, responder internamente:**
> "Estou criando uma solução parametrizável e reutilizável para diferentes modelos, ou estou criando uma regra para fazer o caso atual funcionar?"

Se for a segunda opção, parar e ajustar a abordagem.

### Requisitos inegociáveis

- RH cria e configura modelos de avaliação **sem alterar código** — tudo via tabelas dp_* e param_*
- Motor suporta: Sim/Não, escalas numéricas, pesos, conceitos, texto — com ou sem conversão financeira
- Nenhuma string de negócio (nome de setor, cargo, modelo) como condição no código
- Conversão financeira é **opcional por modelo** — motor funciona sem ela
- Gestores vinculados às equipes via `colaboradores.gestor` — reutilizar, não duplicar
- Visões RH / Gestor / Diretoria usam a mesma estrutura dp_*, mudam apenas escopo e permissão
- Relatórios nascem da estrutura genérica — não de lógica avulsa
- **Complexidade no motor; simplicidade para o RH operar**

### Parametrizações canônicas — sempre reutilizar

| O que | Fonte oficial | Nunca |
|---|---|---|
| Setores | `param_setor.descricao` (remove prefixo `"2148 - "` para exibição e busca) | Hardcodar nome de setor |
| Cargos | `param_cargo` | Hardcodar cargo |
| Gestores/equipes | `colaboradores.gestor` | Criar escopo paralelo ao de Férias |
| Tipos de avaliador | `dp_tipos_avaliador` | ENUM no código |
| Tipos de cálculo | `dp_tipos_calculo_config` | `if tipo === 'soma'` espalhado |

### Quando surgir lacuna

- **Lacuna arquitetural real:** sinalizar com impacto + proposta objetiva, aguardar aprovação
- **Questão de parametrização/cadastro:** resolver com estrutura existente, sem interromper

---

## Arquitetura: Motor D&P V1

### Visão geral do fluxo

```
Biblioteca (dp_criterios, dp_escalas)
        ↓  [adotar: na_biblioteca=true]
Modelo (dp_modelos)
        ↓
Versão (dp_versoes) — define tipo_calculo, critérios, escalas, blocos, tabela_conceito
        ↓   [publicar: em_uso=true → imutável + snapshot de nomes]
Ciclo (dp_ciclos) — referencia versão publicada, define tipo_avaliador e elegibilidade
        ↓
Participantes (dp_ciclo_participantes) — snapshot do colaborador
        ↓
Avaliações (dp_avaliacoes) — por tipo_avaliador_id
        ↓
Respostas (dp_respostas) — por critério
        ↓
Resultado (dp_resultados) — nota final calculada
        ↓   [histórico comparável por mesmo modelo+critério+escala+tipo_resposta]
dp_historico_eventos
```

### Regra de imutabilidade

| O que | Quando | Comportamento |
|---|---|---|
| `dp_versao_criterios` e `dp_versao_blocos` | versao.em_uso = true | INSERT/UPDATE/DELETE bloqueados (trigger) |
| `dp_escala_opcoes` | escala referenciada por versão publicada | INSERT/UPDATE/DELETE bloqueados (trigger) |
| `dp_escalas` | idem | DELETE bloqueado |
| `dp_faixas_conceito` | tabela_conceito referenciada por versão publicada | INSERT/UPDATE/DELETE bloqueados (trigger) |
| `dp_tabelas_conceito` | idem | DELETE bloqueado |

**No front:** verificar `v.em_uso` e aplicar `disabled` nos campos. Tratar erro HTTP 4xx do banco com `toast('Mensagem do banco.', true)`.

### Regra de comparabilidade histórica

`dp_fn_historico_criterio` retorna `{comparavel: false}` quando não encontra avaliação anterior **do mesmo**:
- `modelo_id`, `criterio_id`, `escala_id`, `tipo_resposta`, status `publicada`

---

## Tabelas: Motor D&P (dp_*)

### `dp_criterios` — biblioteca de critérios
```
id                 UUID PK
nome               TEXT NOT NULL
tipo               dp_tipo_criterio ('tecnico'|'comportamental'|'resultado'|'outros')
area               TEXT nullable — área de aplicação (valor texto, ex: "Compras")
descricao          TEXT nullable — "O que será avaliado?"
referencia         TEXT nullable — "Resultado esperado" (referência conceitual para o avaliador)
ativo              BOOLEAN DEFAULT true
na_biblioteca      BOOLEAN DEFAULT false — true = adotado pela Revest; false = sugestão do catálogo
dev_competencias_id BIGINT nullable — FK legada para dev_competencias (não dropar)
criado_em          TIMESTAMPTZ
```

**Estados possíveis de um critério:**
| `dev_competencias_id` | `na_biblioteca` | Estado na UI |
|---|---|---|
| IS NOT NULL | false | Catálogo de sugestões — não adotado |
| IS NOT NULL | true | Sugestão adotada pela Revest |
| IS NULL | true | Critério criado pela Revest |

**Regras de UI:**
- **Minha Biblioteca**: exibe apenas `na_biblioteca = true`
- **Catálogo de Sugestões**: exibe apenas `dev_competencias_id IS NOT NULL`
- **Picker de modelos**: exibe apenas `na_biblioteca = true AND ativo = true`
- "Adicionar à minha biblioteca" = PATCH `{ na_biblioteca: true }` — sem duplicar registro
- Novos critérios criados pelo RH entram com `na_biblioteca: true` no POST
- `descricao` = "O que será avaliado?"; `referencia` = "Resultado esperado" (opcional)

**Proteção de edição (front):**
- Critério em versão publicada (`_dpCriteriosEmUso`): só Duplicar e Ativar/Desativar — sem Editar
- `criterio_nome_snapshot` em `dp_versao_criterios` preserva o nome no momento da publicação

### `dp_escalas` / `dp_escala_opcoes`
```
dp_escalas: id UUID PK, nome TEXT, descricao TEXT, ativo BOOLEAN, criado_em
dp_escala_opcoes: id UUID PK, escala_id FK, rotulo TEXT, valor_numerico NUMERIC, ordem INTEGER
```
- `valor_numerico` é para cálculo/comparação, nunca financeiro
- Imutáveis quando referenciadas por versão publicada (triggers)

### `dp_tipos_avaliador` — substitui ENUM dp_tipo_avaliador (migration 067)
```
id UUID PK, codigo TEXT UNIQUE, label TEXT, descricao TEXT, ativo BOOLEAN, ordem SMALLINT
```
Valores iniciais: `gestor_direto`, `autoavaliacao`, `rh`, `especifico`

### `dp_tipos_calculo_config` — metadados de UI para tipos de cálculo (migration 067)
```
codigo TEXT PK (= valor do ENUM dp_tipo_calculo), label TEXT, descricao TEXT, ativo BOOLEAN, ordem SMALLINT
```
Valores: `media`, `media_ponderada`, `soma`, `percentual_atingimento`, `qualitativo`

### `dp_tabelas_conceito` / `dp_faixas_conceito` — conversão nota→conceito (migration 067)
```
dp_tabelas_conceito: id UUID PK, nome TEXT, descricao TEXT, ativo BOOLEAN, criado_em
dp_faixas_conceito:  id UUID PK, tabela_id FK, nota_min NUMERIC, nota_max NUMERIC,
                     conceito TEXT, descricao TEXT, cor TEXT, ordem SMALLINT
```
- Substituem `faixas_conceito JSONB` que foi removido de `dp_versoes`
- Imutáveis quando tabela referenciada por versão publicada (triggers)

### `dp_modelos` — modelos de avaliação
```
id UUID PK, nome TEXT, descricao TEXT, ativo BOOLEAN, criado_por UUID, criado_em
```

### `dp_versoes` — versões de um modelo
```
id UUID PK
modelo_id UUID REFERENCES dp_modelos
versao TEXT DEFAULT 'v1'
em_uso BOOLEAN DEFAULT false          — true = publicada, imutável
tipo_calculo dp_tipo_calculo NOT NULL DEFAULT 'soma'
tipo_avaliador_id UUID REFERENCES dp_tipos_avaliador  — substituiu coluna ENUM
converte_para_conceito BOOLEAN DEFAULT false
tabela_conceito_id UUID REFERENCES dp_tabelas_conceito — substituiu faixas_conceito JSONB
publicado_em TIMESTAMPTZ, publicado_por UUID, criado_em
```

### `dp_versao_blocos` — blocos organizacionais (opcional)
```
id UUID PK, versao_id FK, nome TEXT, descricao TEXT, ordem INTEGER
```
Bloqueado quando versao.em_uso = true.

### `dp_versao_criterios` — critérios configurados em uma versão
```
id UUID PK
versao_id UUID REFERENCES dp_versoes
criterio_id UUID REFERENCES dp_criterios
bloco_id UUID REFERENCES dp_versao_blocos (nullable)
tipo_resposta dp_tipo_resposta NOT NULL
escala_id UUID REFERENCES dp_escalas (nullable)
criterio_nome_snapshot TEXT   — nome do critério no momento da publicação (snapshot)
peso NUMERIC
obrigatorio BOOLEAN DEFAULT true
contribui_calculo BOOLEAN DEFAULT true
obs_obrigatoria BOOLEAN DEFAULT false
ordem INTEGER DEFAULT 1
UNIQUE(versao_id, criterio_id)
```
- `criterio_nome_snapshot` populado pelo trigger `trg_versao_snapshot_criterios` ao publicar
- Bloqueado quando versao.em_uso = true (trigger)

### `dp_ciclos` — ciclos de avaliação
```
id UUID PK
versao_id UUID REFERENCES dp_versoes
nome TEXT NOT NULL
status dp_status_ciclo DEFAULT 'rascunho'
tipo_avaliador_id UUID REFERENCES dp_tipos_avaliador  — migrado de ENUM
tipo_elegibilidade dp_tipo_elegibilidade DEFAULT 'todos'  — movido de dp_versoes
elegibilidade_ids UUID[]   — movido de dp_versoes
data_inicio DATE, data_fim DATE
aberto_por UUID, aberto_em, encerrado_em, criado_em
```

### `dp_ciclo_participantes`
```
id UUID PK, ciclo_id FK, colaborador_id INTEGER REFERENCES colaboradores(id),
snapshot JSONB NOT NULL  — {nome, matricula, empresa, setor, cargo, unidade}
adicionado_em, UNIQUE(ciclo_id, colaborador_id)
```
`colaboradores.id` é INTEGER, não UUID — nunca declarar FK como UUID.

### `dp_avaliacoes`
```
id UUID PK, ciclo_id FK, participante_id FK, tipo_avaliador_id UUID FK,
avaliador_id UUID, status dp_status_avaliacao DEFAULT 'nao_iniciada',
iniciada_em, concluida_em, publicada_em, publicada_por
UNIQUE(ciclo_id, participante_id, tipo_avaliador_id)
```

### `dp_respostas`
```
id UUID PK, avaliacao_id FK, versao_criterio_id FK,
escala_opcao_id FK nullable, valor_numerico_livre NUMERIC,
meta NUMERIC, realizado NUMERIC, conceito_selecionado TEXT, resposta_texto TEXT,
snapshot_opcao_label TEXT, snapshot_opcao_valor_num NUMERIC,  — trigger
observacao TEXT, respondido_em TIMESTAMPTZ
UNIQUE(avaliacao_id, versao_criterio_id)
```

### `dp_resultados`
```
id UUID PK, avaliacao_id UNIQUE FK, nota_final NUMERIC, conceito TEXT,
calculado_em, calculado_por
CHECK(nota_final IS NOT NULL OR conceito IS NOT NULL)
```

### Camada financeira (criada, sem UI)
```
dp_regras_financeiras, dp_regra_financeira_opcoes,
dp_regra_financeira_faixas, dp_resultados_financeiros
```

### `dp_historico_eventos`
```
id UUID PK, tipo dp_evento_historico, entidade TEXT, entidade_id UUID,
detalhe JSONB, usuario_id UUID, criado_em
```

---

## ENUMs dp_*

| ENUM | Valores |
|---|---|
| `dp_tipo_criterio` | `tecnico`, `comportamental`, `resultado`, `outros` |
| `dp_tipo_resposta` | `binario`, `escala`, `numerico`, `numerico_com_meta`, `conceito`, `texto` |
| `dp_tipo_calculo` | `soma`, `media`, `media_ponderada`, `percentual_atingimento`, `qualitativo` |
| `dp_status_ciclo` | `rascunho`, `aberto`, `em_andamento`, `encerrado`, `cancelado` |
| `dp_status_avaliacao` | `nao_iniciada`, `em_andamento`, `concluida`, `publicada` |
| `dp_tipo_elegibilidade` | `todos`, `por_setor`, `por_cargo`, `por_colaborador` |
| `dp_tipo_regra_financeira` | `percentual_salario`, `valor_fixo`, `por_criterio` |
| `dp_status_resultado_financeiro` | `calculado`, `ajustado`, `aprovado`, `pago` |
| `dp_evento_historico` | `ciclo_aberto`, `ciclo_fechado`, `avaliacao_publicada`, `resultado_calculado`, `resultado_ajustado` |

**Nota:** `dp_tipo_avaliador` ENUM foi DROPADO na migration 067 — substituído pela tabela `dp_tipos_avaliador`.

---

## Funções e triggers do banco

### `dp_validar_versao(p_versao_id UUID)` → JSONB
Valida versão antes de publicar. **Regra 2 (migration 068):** verifica `tabela_conceito_id IS NULL` (não mais `faixas_conceito`).

| Regra | O que verifica |
|---|---|
| 1 | Não-qualitativo precisa de ≥1 critério com `contribui_calculo=true` |
| 2 | `converte_para_conceito=true` exige `tabela_conceito_id` preenchido |
| 3 | Critérios calculáveis com escala precisam de `valor_numerico` nas opções |
| 4 | `media_ponderada` exige `peso > 0` em todos calculáveis |
| 5a | `percentual_atingimento` exige `tipo_resposta='numerico_com_meta'` em todos calculáveis |
| 5b | `qualitativo` proíbe `contribui_calculo=true` |

### Triggers de imutabilidade
- `trg_eo_proteger_em_uso` — dp_escala_opcoes
- `trg_e_proteger_delete` — dp_escalas
- `trg_vc_proteger_em_uso` — dp_versao_criterios
- `trg_vb_proteger_em_uso` — dp_versao_blocos
- `trg_fc_proteger_em_uso` — dp_faixas_conceito
- `trg_tc_proteger_delete` — dp_tabelas_conceito
- `trg_resposta_snapshot` — dp_respostas (popula snapshot_opcao_*)
- `trg_versao_snapshot_criterios` — dp_versoes (popula criterio_nome_snapshot ao publicar)

---

## Tabelas legadas (dev_*) — coexistem com dp_*

| Tabela | Status |
|---|---|
| `dev_competencias` | Mantida — origem dos 39 critérios seed em dp_criterios. NUNCA dropar. |
| `dev_ciclos` | Ativa nas abas legadas |
| `dev_avaliacoes` | Ativa nas abas legadas |
| `dev_pdi` | Mantida para V2 PDI |
| `dev_historico` | Ativa nas abas legadas |

---

## Estrutura do módulo (abas atuais)

| Aba | Tabelas principais | Status |
|---|---|---|
| Colaboradores | dev_ciclos, dev_avaliacoes, colaboradores | Legado — funcional |
| Ciclos de Avaliação | dev_ciclos | Legado — funcional |
| **Competências** | dp_criterios | Novo — Biblioteca de Critérios |
| **Modelos** | dp_modelos, dp_versoes, dp_versao_blocos, dp_versao_criterios | Novo — V1 |
| **Escalas** | dp_escalas, dp_escala_opcoes | Novo — V1 |
| **Configurações D&P** | dp_tipos_avaliador, dp_tipos_calculo_config, dp_tabelas_conceito, dp_faixas_conceito | Novo — V1 |

---

## Aba Competências — Biblioteca de Critérios

### Duas abas internas
- **Minha Biblioteca** (`bibSecBiblioteca`): critérios com `na_biblioteca=true`; empty state com CTA "Novo critério" e "Explorar catálogo"
- **Catálogo de Sugestões** (`bibSecCatalogo`): critérios com `dev_competencias_id IS NOT NULL`; botão "Adicionar" → PATCH `na_biblioteca=true`; badge "Já adicionado" quando `na_biblioteca=true`

### Variáveis de estado (Competências)
```js
let _dpCriterios       = [];      // dp_criterios (todos)
let _dpCriteriosEmUso  = new Set(); // ids em dp_versao_criterios de versão publicada
let _dpSetores         = [];      // param_setor como fonte das áreas
let _bibFiltroTipo     = '';      // filtro ativo na aba Minha Biblioteca
let _catFiltroTipo     = '';      // filtro ativo na aba Catálogo
```

### Status visual nos cards (Minha Biblioteca)
- `● Disponível` (verde): `ativo=true` e não em versão publicada
- `● Em uso` (âmbar): `ativo=true` e `id ∈ _dpCriteriosEmUso`
- `● Inativa` (cinza): `ativo=false`

### Modal de competência (`modalCompetencia`)
Campos:
1. **Nome da competência** * — `compNome`
2. **Tipo** * — `compTipo` (`comportamental`|`tecnico`); ao mudar para comportamental, área reseta para "Todas as áreas"
3. **Área de aplicação** — `compArea` (select populado de `_dpSetores`; opção padrão "Todas as áreas" = `value=""` → salva `area=null`)
4. **O que será avaliado?** * — `compDescricao`
5. **Resultado esperado** (opcional) — `compReferencia`

`salvarCompetencia()` envia: `{ nome, tipo, area, descricao, referencia, ativo: true, na_biblioteca: true }` no POST.
Edição (`emUso=true`): todos os campos desabilitados, botão Salvar oculto, aviso exibido.

---

## Aba Configurações D&P

4 blocos renderizados em `renderConfiguracoes()`:
1. **Tipos de Avaliador** — tabela `dp_tipos_avaliador`; labels editáveis inline
2. **Escalas de Resposta** — tabela `dp_escalas`; atalho para aba Escalas
3. **Tabelas de Conceito** — cards com faixas; modal para nova tabela; drawer para editar faixas
4. **Tipos de Cálculo** — tabela `dp_tipos_calculo_config`; toggle ativo/inativo

---

## Aba Modelos — detalhes de implementação

### Drawer de versão (`drawerVersao`)
- **Tab Critérios:** accordion por bloco → tabela de critérios (tudo `disabled` se `em_uso`)
- **Tab Configurações:** `tipo_calculo`, `tipo_avaliador_id` (select de `dp_tipos_avaliador`), `converte_para_conceito`, `tabela_conceito_id` (select de `dp_tabelas_conceito`)
- **Footer:** Validar → resultado inline → Publicar (só após validação ok)
- Picker de critérios: filtra `na_biblioteca=true AND ativo=true`

### Variáveis de estado (Modelos)
```js
let _dpModelos        = [];
let _dpVersoes        = {};       // { modelo_id: [versao, ...] }
let _dpVersaoAtual    = null;
let _dpVersaoCrits    = [];
let _dpVersaoBlocos   = [];
let _dpVersaoReadonly = false;
let _dpBlocoAlvoId    = null;
let _dpTiposCalculo   = [];       // dp_tipos_calculo_config
let _dpTiposAvaliador = [];       // dp_tipos_avaliador
let _dpTabelasConceito = [];      // dp_tabelas_conceito
let _dpFaixasConceito  = {};      // { tabela_id: [faixas] }
```

---

## Padrão de acesso ao Supabase

```js
const SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const SB_KEY = '...'; // publishable key
const HDR = { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`,
              'Content-Type': 'application/json', Prefer: 'return=representation' };

async function sbGet(path)        { ... }
async function sbPost(path,body)  { ... }
async function sbPatch(path,body) { ... }
async function sbDelete(path)     { ... }
// RPC: POST /rest/v1/rpc/<nome>
```

---

## Padrão de design — tokens CSS

```css
--text-sec: #4B5565  --text-ter: #6C7589
--border: #E4E7EC    --border-light: #F2F4F7
--surface: #ffffff   --bg: #F8FAFC   --accent: #101828
--green: #12B76A     --amber: #F79009  --red: #F04438
--blue: #2E90FA      --radius: 12px
```

**Nota:** `--bg` foi alterado de `#E8EDF4` para `#F8FAFC` no redesign visual de 2026-10-02.

**Classes base:** `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-sm`, `.sbadge`, `.sbadge-green/amber/blue/red/gray`, `.modal-overlay`, `.modal`, `.modal-lg`, `.form-group`, `.form-label`, `.form-input`, `.drawer`, `.drawer-versao`, `.loader`, `.spinner`, `.empty-state`, `toast(msg, err=false)`

**Classes da Biblioteca:** `.bib-tabs`, `.bib-tab`, `.bib-sec`, `.comp-card`, `.comp-card.inativo`, `.comp-card-top-row`, `.comp-card-nome`, `.comp-card-desc`, `.comp-card-ref`, `.comp-card-actions`, `.comp-area-header`, `.comp-grid-list`, `.comp-em-uso-aviso`, `.comp-status-row`, `.status-dot.disponivel/em-uso/inativa`, `.cat-card`, `.cat-ja-adicionado`, `.filter-chip`

**Classes de Configurações:** `.conf-bloco`, `.conf-bloco-titulo`, `.conf-bloco-desc`, `.conf-table`, `.tabela-conceito-card`, `.faixas-preview`, `.faixa-chip`

---

## Sistema visual — redesign D&P (2026-10-02)

Redesign **somente visual** implementado em todas as seções do módulo D&P. Nenhuma lógica JS ou chamada ao Supabase foi alterada.

### Layout de duas colunas — `.content-area`

Todas as seções (exceto legadas) usam o padrão:

```html
<div class="content-area">
  <div class="list-col"><!-- lista principal --></div>
  <div class="sidebar-col"><!-- painéis laterais --></div>
</div>
```

```css
.content-area  { display: flex; gap: 20px; align-items: flex-start; }
.list-col      { flex: 1; min-width: 0; }
.sidebar-col   { width: 220px; flex-shrink: 0; display: flex; flex-direction: column; gap: 12px; }
@media (max-width: 900px) { .sidebar-col { display: none; } .content-area { display: block; } }
```

### Painéis laterais — `.sidebar-panel`

```html
<div class="sidebar-panel">
  <div class="panel-title">TÍTULO</div>
  <div class="stat-row">
    <span class="stat-label">Label</span>
    <span class="stat-value accent">42</span>
  </div>
  <div class="progress-bar-wrap">
    <div class="progress-labels"><span>0%</span><span>100%</span></div>
    <div class="progress-track"><div class="progress-fill" style="width:65%"></div></div>
  </div>
</div>
```

`.stat-value.accent` usa `var(--accent)`. `.progress-fill.green` usa `#22C55E`.

**IDs dos elementos populados por JS:**

| Seção | ID | Conteúdo |
|---|---|---|
| Ciclos | `cicloSidebarStats` | Contadores + progresso do ciclo ativo |
| Modelos | `sideModAtivos`, `sideModInativos`, `sideModCiclos`, `sideModAtividade` | Contadores modelos |
| Competências | `sideCriterios`, `sideCriteriosComp`, `sideCriteriosTec` | Totais critérios |
| Escalas | `sideEscalas`, `sideEscalasEmUso` | Total + em uso |
| Configurações | `sideConfAvaliadores` | Total tipos de avaliador |

### Cabeçalhos de grupo — `.section-header`

```html
<div class="section-header">
  <span class="section-title">RASCUNHOS</span>
  <span class="section-count">3</span>
</div>
```

Usado em `renderCiclos()` (rascunhos / ciclos anteriores), `renderModelos()` (ativos / inativos), `renderConfiguracoes()` (cada bloco de config).

### Ciclo banner — `.ciclo-banner`

Exibido no topo da lista de ciclos quando há ciclo com `status === 'aberto'`:

```html
<div class="ciclo-banner">
  <div class="ciclo-banner-title">Nome do ciclo</div>
  <div class="ciclo-banner-sub">X participantes · encerra dd/mm/aaaa</div>
  <div class="ciclo-banner-progress"><div class="ciclo-banner-fill" style="width:65%"></div></div>
</div>
```

### Toggle switches — `.toggle`

Substitui `<input type="checkbox">` raw nas seções Avaliadores e Tipos de Cálculo:

```html
<label class="toggle">
  <input type="checkbox" checked onchange="salvarAvaliador(id, this.checked)">
  <div class="toggle-track"></div>
  <div class="toggle-thumb"></div>
</label>
```

`toggle-track` fica azul (`var(--accent)`) quando checked. `toggle-thumb` desliza 14px.

### Ícones SVG nas row-cards

Substituíram emojis em todas as funções de render. Padrão:

```js
// dentro da string do row-icon
`<div class="row-icon" style="background:${cor}22;color:${cor}">
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8">
    <path .../>
  </svg>
</div>`
```

| Seção | Cor | Ícone |
|---|---|---|
| Ciclos | `#2563EB` (aberto) / `#D97706` (rascunho) / `#64748B` (outros) | calendar |
| Modelos | `#2563EB` (ativo) / `#64748B` (inativo) | clipboard-list |
| Escalas | `#7C3AED` | bar-chart |
| Avaliadores | `#2563EB` (autoavaliacao) / `#7C3AED` (gestor) / `#D97706` (par) | user / users / arrows |
| Tabelas de Conceito | `#16A34A` | tag |
| Tipos de Cálculo | `#16A34A` (ativo) / `#64748B` (inativo) | gear/settings |

### Botões de ação — `.icon-btn`

```html
<div class="row-actions">
  <button class="icon-btn" onclick="..."><!-- SVG 16×16 --></button>
</div>
```

### Busca em lista — `.list-search`

Implementado na seção Modelos (`id="modelosSearchInput"`). Filtra em tempo real via `oninput="renderModelos()"`:

```html
<div class="list-search">
  <svg .../><!-- lupa 16×16 -->
  <input id="modelosSearchInput" type="text" placeholder="Buscar modelo...">
</div>
```

### Drawers — padrão right-side

Ambos os wizards do módulo usam right-side drawer (não modal centrado):

| Overlay class | Panel class | Abertura | Fechamento |
|---|---|---|---|
| `.wiz-overlay` | `.wiz-panel` | `abrirWizard()` | `fecharWizard()` |
| `.wizard-overlay` | `.wizard-panel` | `wizardAbrir()` | `wizardFechar()` |

CSS base (mesmo padrão nos dois):
```css
.wizard-panel {
  position: absolute; top: 0; right: 0; bottom: 0;
  width: 820px; max-width: 96vw;
  transform: translateX(100%);
  transition: transform 0.28s cubic-bezier(0.4,0,0.2,1);
}
.wizard-overlay.open .wizard-panel { transform: translateX(0); }
```

---

## Migrations executadas

| Arquivo | Conteúdo | Status |
|---|---|---|
| `065_desenvolvimento_performance_v1.sql` | Motor D&P completo + migração dev_competencias → dp_criterios | Executado |
| `066_dp_desabilitar_rls.sql` | Desabilitar RLS nas tabelas dp_* | Executado |
| `067_dp_parametrizacao_v1.sql` | dp_tipos_avaliador, dp_tipos_calculo_config, dp_tabelas_conceito, dp_faixas_conceito, criterio_nome_snapshot, elegibilidade → dp_ciclos, DROP ENUM dp_tipo_avaliador | Executado |
| `068_dp_corrigir_validar_versao.sql` | Corrige dp_validar_versao regra 2: tabela_conceito_id IS NULL | **PENDENTE** |
| `069_dp_criterios_na_biblioteca.sql` | ADD COLUMN na_biblioteca BOOLEAN; UPDATE seed → false | Executado |
| `070_dp_criterios_referencia_meta.sql` | ADD COLUMN referencia, meta_valor, meta_unidade; CREATE dp_meta_unidades | Executado (revertido em 071) |
| `071_dp_criterios_remover_meta.sql` | DROP meta_valor, meta_unidade; DROP TABLE dp_meta_unidades | Executado |

**Próxima migration:** `072_dp_...`

**Migration 068 pendente:** SQL pronto em `migrations/068_dp_corrigir_validar_versao.sql`. Executar antes de usar `converte_para_conceito` na UI.

---

## Estado atual — Etapas D&P

| Etapa | O que cobre | Status |
|---|---|---|
| **Etapa 1 — Ciclos D&P** | Criar ciclo, definir elegibilidade, adicionar/remover participantes, mudar status rascunho→aberto | ✅ Implementado (commit f94d3e9) — aguardando teste com `param_setor` populado |
| **Etapa 2 — Avaliação do Gestor** | Formulário guiado por critérios da versão | Pendente |
| **Etapa 3 — Cálculo** | RPC no banco → dp_resultados | Pendente |
| **Etapa 4 — Regra financeira UI** | Configuração de dp_regras_financeiras no drawer da versão | Pendente |
| **Etapa 5 — Análise e fechamento RH** | Revisão de resultados, aprovação, encerramento do ciclo | Pendente |
| **Etapa 6 — Relatório/exportação** | Exportar resultados para Excel/PDF | Pendente |

## Pendências técnicas

| Item | Prioridade | Detalhe |
|---|---|---|
| **Executar migration 068** | Alta | Corrige `dp_validar_versao` regra 2 — necessário antes de usar `converte_para_conceito` |
| **`param_setor` populado** | Alta | Pré-requisito para testar elegibilidade por setor no ciclo |
| RLS nas tabelas dp_* | Alta | Obrigatório antes de abrir visão do gestor |
| Visão do gestor — "meu ciclo" | Alta | Etapa 3 |
| Cálculo de resultados (dp_resultados) | Alta | Etapa 3 |
| Camada financeira UI | Baixa | Etapa 4 |
| Camada de Análises / dashboard | Média | Etapa 5 |
| PDI V2 vinculado a dp_ciclo_participantes | Baixa | Fase futura |
| DROP tabelas dev_* | Baixa | Pós-migração completa |

---

## Compatibilidade: tipos de dados

- **`colaboradores.id` é INTEGER** — FKs para colaboradores usam `INTEGER`, nunca UUID
- **`dev_competencias.id` é BIGINT** — não confundir com UUID de dp_criterios
- **`dev_competencias.tipo`** usa `'tecnica'` (feminino); `dp_tipo_criterio` usa `'tecnico'`
