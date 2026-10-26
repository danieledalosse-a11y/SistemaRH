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
| Gestores/equipes | `param_gestor.apelido → colaboradores.gestor ilike apelido` (mesma cadeia do Férias) | Criar escopo paralelo; usar `colaboradores.gestor` diretamente sem passar por `param_gestor` |
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

**Campos retornados (pós-migration 115):**
`comparavel`, `ciclo_nome`, `ciclo_encerrado_em`, `escala_opcao_label`, `escala_opcao_valor`, `valor_numerico_livre`, `meta`, `realizado`, `conceito_selecionado`, `resposta_texto` *(novo — Sim/Não para binários)*, `nota_final`, `conceito_resultado`

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
nota_min NUMERIC (nullable)  — orientação visual: valor mínimo de referência (migration 114)
nota_max NUMERIC (nullable)  — orientação visual: valor máximo de referência (migration 114)
valor_se_sim NUMERIC (nullable) — bônus monetário quando resposta = "sim" (binário; migration 114)
valor_se_nao NUMERIC DEFAULT 0  — bônus monetário quando resposta = "não" (binário; migration 114)
UNIQUE(versao_id, criterio_id)
CONSTRAINT escala_obrigatoria CHECK (tipo_resposta != 'escala' OR escala_id IS NOT NULL)
```
- `criterio_nome_snapshot` populado pelo trigger `trg_versao_snapshot_criterios` ao publicar
- Bloqueado quando versao.em_uso = true (trigger)
- `escala_obrigatoria` exige `escala_id` apenas para `tipo_resposta='escala'` — binário não precisa (migration 114)
- `nota_min`/`nota_max` são orientação visual (borda laranja + toast não-bloqueante), sem bloquear salvamento
- `valor_se_sim`/`valor_se_nao` + `tipo_resposta='binario'` → critério produz `resultado_bonus`, não `nota_final`

### `dp_ciclos` — ciclos de avaliação
```
id UUID PK
versao_id UUID REFERENCES dp_versoes
nome TEXT NOT NULL
status dp_status_ciclo DEFAULT 'rascunho'
tipo_avaliador_id UUID REFERENCES dp_tipos_avaliador  — migrado de ENUM
tipo_elegibilidade dp_tipo_elegibilidade DEFAULT 'todos'  — movido de dp_versoes
elegibilidade_ids UUID[]   — movido de dp_versoes
avaliador_id UUID REFERENCES auth.users(id)  — migration 116: gestor designado como avaliador responsável
data_inicio DATE, data_fim DATE
prazo_avaliacao DATE nullable  — prazo para os gestores concluírem avaliações (≠ data_fim); opcional
aberto_por UUID, aberto_em, encerrado_em, criado_em
```

**`prazo_avaliacao`** é o prazo que o RH define para gestores concluírem avaliações. Difere de `data_fim` (fim do período avaliado). Campo opcional — ciclos sem prazo não exibem alerta. Migration: `ALTER TABLE dp_ciclos ADD COLUMN IF NOT EXISTS prazo_avaliacao DATE` (executada em produção 2026-10-15).

### `dp_ciclo_participantes`
```
id UUID PK, ciclo_id FK, colaborador_id INTEGER REFERENCES colaboradores(id),
snapshot JSONB NOT NULL  — {nome, matricula, empresa, setor, cargo, unidade, em_experiencia, data_admissao}
adicionado_em, UNIQUE(ciclo_id, colaborador_id)
```
`colaboradores.id` é INTEGER, não UUID — nunca declarar FK como UUID.

`em_experiencia` (boolean) gravado no snapshot desde commit f49e176 — exibe destaque mesmo após recarregar ciclo.
`data_admissao` (string `'YYYY-MM-DD'`) gravado no snapshot desde commit 8b10116 — exibido nos cards como "Admissão: dd/mm/aaaa".

### `dp_avaliacoes`
```
id UUID PK, ciclo_id FK, participante_id FK, tipo_avaliador_id UUID FK,
avaliador_id UUID  — auth.users.id do gestor responsável (propagado de dp_ciclos.avaliador_id ao criar avaliação),
status dp_status_avaliacao DEFAULT 'nao_iniciada',
iniciada_em, concluida_em, publicada_em, publicada_por
UNIQUE(ciclo_id, participante_id, tipo_avaliador_id)
```
**`avaliador_id` propagado em `dpAbrirFormAvaliacao`:** `avaliador_id: _dpCicloAtual.avaliador_id || null`

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
id UUID PK, avaliacao_id UNIQUE FK, nota_final NUMERIC (nullable), conceito TEXT,
calculado_em, calculado_por
```
- Constraint `resultado_tem_valor` **DROPADA** na migration 114 — `nota_final=NULL` é correto para modelos exclusivamente monetários
- `nota_final=NULL + conceito=NULL` só ocorre em modelos puramente monetários (protegido pelo RPC)

### `dp_resultados_bonus` — bônus monetário por critérios binários (migration 114)
```
id UUID PK
resultado_id UUID UNIQUE REFERENCES dp_resultados(id) ON DELETE CASCADE
valor_bonus NUMERIC NOT NULL CHECK (valor_bonus >= 0)
snapshot_criterios JSONB  — [{criterio_id, nome, valor_se_sim, valor_se_nao, resposta, valor_apurado}]
calculado_em TIMESTAMPTZ NOT NULL DEFAULT now()
calculado_por UUID REFERENCES auth.users(id)
```
**RLS (pós-migration 116):** SELECT: rh/admin/diretoria (irrestrito) **OU** gestor com `resultado_id` vinculado a avaliação onde `avaliador_id = auth.uid()`. INSERT/UPDATE: restrito a rh/admin. O gestor vê apenas o bônus das avaliações que ele conduz — para fins de transparência e feedback.

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
| `dp_status_avaliacao` | `nao_iniciada`, `em_andamento`, `respondida`, `concluida`, `publicada` |
| `dp_tipo_elegibilidade` | `todos`, `por_setor`, `por_cargo`, `por_gestor`, `por_colaborador` |
| `dp_tipo_regra_financeira` | `percentual_salario`, `valor_fixo`, `por_criterio` |
| `dp_status_resultado_financeiro` | `calculado`, `ajustado`, `aprovado`, `pago` |
| `dp_evento_historico` | `ciclo_aberto`, `ciclo_fechado`, `avaliacao_publicada`, `resultado_calculado`, `resultado_ajustado`, `resultado_recalculado` |

**Nota:** `dp_tipo_avaliador` ENUM foi DROPADO na migration 067 — substituído pela tabela `dp_tipos_avaliador`.

---

## Funções e triggers do banco

### `dp_validar_versao(p_versao_id UUID)` → JSONB
Valida versão antes de publicar. **Regra 2 (migration 068):** verifica `tabela_conceito_id IS NULL` (não mais `faixas_conceito`).

| Regra | O que verifica |
|---|---|
| 1 | Não-qualitativo precisa de ≥1 critério com `contribui_calculo=true` |
| 2 | `converte_para_conceito=true` exige `tabela_conceito_id` preenchido |
| 3 | Critérios calculáveis com **`tipo_resposta='escala'`** precisam de `valor_numerico` nas opções (migration 114: binário excluído dessa verificação) |
| 4 | `media_ponderada` exige `peso > 0` em todos calculáveis |
| 5a | `percentual_atingimento` exige `tipo_resposta='numerico_com_meta'` em todos calculáveis |
| 5b | `qualitativo` proíbe `contribui_calculo=true` |

### `dp_salvar_resultado(p_avaliacao_id, p_nota_final, p_conceito, p_bonus_total, p_snapshot, p_motivo_recalculo)` → JSONB (migration 114)
RPC `SECURITY DEFINER` — único ponto de entrada para salvar resultados. Garante atomicidade.

- **Acesso:** apenas `rh` e `admin` — retorna erro JSON se outro perfil chamar
- **Upsert `dp_resultados`:** atualiza se já existe para `avaliacao_id`, insere se não
- **Upsert `dp_resultados_bonus`:** só executa quando `p_bonus_total IS NOT NULL`
- **Recálculo:** ao sobrescrever `dp_resultados_bonus` existente, registra snapshot anterior em `dp_historico_eventos` com `tipo='resultado_recalculado'` antes do UPDATE
- **Validação:** rejeita quando `p_nota_final`, `p_conceito` e `p_bonus_total` são todos NULL
- **Frontend:** chamado via `sbRpc('dp_salvar_resultado', { p_avaliacao_id, p_nota_final, p_conceito, p_bonus_total, p_snapshot, p_motivo_recalculo })`

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
async function sbPatch(path,body) { ... }   // herda Prefer: return=representation — use _dpPatchMinimal em saves D&P
async function sbDelete(path)     { ... }   // já usa return=minimal
async function sbRpc(fn, params={}) { ... } // POST /rest/v1/rpc/<fn> — retorna null em erro, popula _sbLastError
async function sbUpsert(path,body){ ... }   // usa return=representation — use _dpUpsertMinimal em saves D&P
```

### ⚠ Regra obrigatória — return=minimal em operações de escrita D&P

`return=representation` (padrão de HDR e sbUpsert) faz o PostgREST executar um SELECT após cada escrita para retornar as linhas salvas. Com RLS complexo (múltiplas subqueries), isso **dobra o custo de cada operação**. Medição real em produção (2026-10-23):

| Operação | Com return=representation | Com return=minimal | Ganho |
|---|---|---|---|
| UPSERT dp_respostas (10 linhas) | ~4.700 ms | ~580 ms | **−88%** |
| PATCH dp_avaliacoes (1 linha) | ~1.850 ms | ~360 ms | **−80%** |
| Total Salvar | ~6.500 ms | **~940 ms** | **−86%** |

**Regra:** toda operação de escrita no D&P que **não precisa do retorno do banco** deve usar as funções locais:

```js
// Declaradas logo após sbUpsert, usadas SOMENTE nas 4 chamadas de save do D&P:
async function _dpUpsertMinimal(path, body) { /* Prefer: resolution=merge-duplicates,return=minimal → true em sucesso, null em erro */ }
async function _dpPatchMinimal(path, body)  { /* Prefer: return=minimal → true em sucesso, null em erro */ }
```

**Quando usar _dpUpsertMinimal / _dpPatchMinimal:**
- `salvarAvaliacao()` — upsert dp_respostas + patch dp_avaliacoes
- `_dpSalvarParaNavegar()` — upsert dp_respostas + patch dp_avaliacoes

**Quando NÃO usar (continuar com sbUpsert/sbPatch):**
- Qualquer chamada que precise do `id` gerado ou de campos computados pelo banco para prosseguir
- Chamadas de outros módulos — não alterar funções globais

**Atualização de `_dpRespostasAtual` sem retorno do banco:**
```js
// Merge cirúrgico via versao_criterio_id (nenhum consumidor usa o campo id)
const novo = [..._dpRespostasAtual];
for (const p of payloads) {
  const idx = novo.findIndex(r => r.versao_criterio_id === p.versao_criterio_id);
  if (idx >= 0) Object.assign(novo[idx], p); else novo.push(p);
}
_dpRespostasAtual = novo;
```

**Campos de `_dpRespostasAtual` usados pelos consumidores:** `versao_criterio_id`, `resposta_texto`, `escala_opcao_id`, `valor_numerico_livre`, `observacao`, `snapshot_opcao_label`, `snapshot_opcao_valor_num` — todos enviados no payload.

**Nota sobre `trg_resposta_snapshot`:** trigger dispara em INSERT e preenche `snapshot_opcao_label`/`snapshot_opcao_valor_num`. O payload já envia esses campos explicitamente (linhas 6686-6688 do index.html) — sem divergência entre enviado e persistido.

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

### Drawers — dois padrões

**Wizards de configuração (right-side):**

| Overlay class | Panel class | Abertura | Fechamento |
|---|---|---|---|
| `.wiz-overlay` | `.wiz-panel` | `abrirWizard()` | `fecharWizard()` |
| `.wizard-overlay` | `.wizard-panel` | `wizardAbrir()` | `wizardFechar()` |

CSS base (right-side):
```css
.wizard-panel {
  position: absolute; top: 0; right: 0; bottom: 0;
  width: 820px; max-width: 96vw;
  transform: translateX(100%);
  transition: transform 0.28s cubic-bezier(0.4,0,0.2,1);
}
.wizard-overlay.open .wizard-panel { transform: translateX(0); }
```

**Drawers de ciclo e avaliação (modal centrado) — `.wiz-overlay--center`:**

O modificador `.wiz-overlay--center` converte qualquer `.wiz-overlay` + `.wiz-container` de right-side para modal centrado:

```css
.wiz-overlay--center { display: flex; align-items: center; justify-content: center; padding: 20px; z-index: 9100; }
.wiz-overlay--center .wiz-container { position: static; width: 900px; max-width: 96vw; max-height: 90vh; border-radius: 16px; transform: scale(0.96) translateY(10px); }
.wiz-overlay--center.open .wiz-container { transform: scale(1) translateY(0); }
```

Elementos que usam modal centrado:

| Elemento | Overlay ID | Classes |
|---|---|---|
| Drawer ciclo RH | `drawerDpCicloOverlay` | `wiz-overlay wiz-overlay--center` |
| Panel ciclo RH | `drawerDpCiclo` | `wiz-container` (filho do overlay) |
| Drawer ciclo Gestor | `gestorDpDrawerOverlay` | `wiz-overlay wiz-overlay--center` |
| Panel ciclo Gestor | `gestorDpDrawerPanel` | `wiz-container` (filho do overlay) |
| Overlay formulário avaliação | `formAvalOverlay` | `wiz-overlay wiz-overlay--center` |
| Panel formulário avaliação | `formAvalPanel` | `wiz-container modal-aval-panel` |

**Regra JS para drawers centrados:** togglear `.open` somente no overlay pai — o painel recebe a animação via CSS (`.wiz-overlay.open .wiz-container`). Não adicionar/remover `.open` no painel separadamente.

```js
// Abrir:
document.getElementById('drawerDpCicloOverlay').classList.add('open');
// Fechar:
document.getElementById('drawerDpCicloOverlay').classList.remove('open');
```

---

## Migrations executadas

| Arquivo | Conteúdo | Status |
|---|---|---|
| `065_desenvolvimento_performance_v1.sql` | Motor D&P completo + migração dev_competencias → dp_criterios | Executado |
| `066_dp_desabilitar_rls.sql` | Desabilitar RLS nas tabelas dp_* | Executado |
| `067_dp_parametrizacao_v1.sql` | dp_tipos_avaliador, dp_tipos_calculo_config, dp_tabelas_conceito, dp_faixas_conceito, criterio_nome_snapshot, elegibilidade → dp_ciclos, DROP ENUM dp_tipo_avaliador | Executado |
| `068_dp_corrigir_validar_versao.sql` | Corrige dp_validar_versao regra 2: tabela_conceito_id IS NULL | Executado |
| `069_dp_criterios_na_biblioteca.sql` | ADD COLUMN na_biblioteca BOOLEAN; UPDATE seed → false | Executado |
| `070_dp_criterios_referencia_meta.sql` | ADD COLUMN referencia, meta_valor, meta_unidade; CREATE dp_meta_unidades | Executado (revertido em 071) |
| `071_dp_criterios_remover_meta.sql` | DROP meta_valor, meta_unidade; DROP TABLE dp_meta_unidades | Executado |
| `112_dp_rls.sql` | Habilita RLS nas 21 tabelas dp_*; políticas por perfil: RH/admin CRUD, diretoria SELECT, gestor sem acesso (fase 2), histórico append-only | Executado |
| `113_dp_rls_gestor.sql` | Fase 2 RLS: função `auth_gestor_equipe_ids()` SECURITY DEFINER + 21 políticas gestor por equipe (SELECT config, CRUD operacional restrito, INSERT histórico) | Executado |
| `114_dp_versao_criterios_range_monetario.sql` | 7 blocos + 5b: ADD colunas range/monetário em `dp_versao_criterios`; corrige `escala_obrigatoria` e `dp_validar_versao`; cria `dp_resultados_bonus` com RLS; DROP `resultado_tem_valor` em `dp_resultados`; ADD ENUM `resultado_recalculado`; cria RPC `dp_salvar_resultado` | **Executado** |
| `115_dp_fn_historico_criterio_resposta_texto.sql` | `CREATE OR REPLACE` em `dp_fn_historico_criterio` — adiciona `'resposta_texto', r.resposta_texto` ao `jsonb_build_object`; mesma assinatura, sem alteração de tabelas | **Executado** |
| `116_dp_trigger_fix_e_rls_gestor.sql` | **Bloco 1:** ADD COLUMN `dp_ciclos.avaliador_id UUID` (nullable, FK auth.users). **Bloco 2:** Corrige `dp_fn_versao_proteger_em_uso` — permite EXCLUSIVAMENTE transição `criterio_nome_snapshot: NULL→valor` sem alterar nenhum campo estrutural (fix do conflito entre triggers `trg_versao_snapshot_criterios` AFTER e `trg_vc_proteger_em_uso` BEFORE). Todos os 14 campos estruturais verificados com `IS NOT DISTINCT FROM`. **Bloco 3:** 9 policies RLS (sufixo `_avaliador_*`) — gestor acessa ciclos/participantes/avaliações/respostas/resultados/bônus onde `avaliador_id = auth.uid()`; coexiste com migration 113 via OR | **Executado** (commit c0c65e8, 2026-10-14) |
| `117_dp_rls_fix_recursao_ciclo_participantes.sql` | Cria `auth_avaliador_ciclo_ids()` SECURITY DEFINER que lê `dp_ciclos` sem RLS; reescreve `dp_ciclo_participantes_avaliador_sel` para usar `ciclo_id = ANY(SELECT auth_avaliador_ciclo_ids())` em vez de subquery direta — quebra a recursão estrutural PostgreSQL entre `dp_ciclos_gestor_sel` (migration 113) e `dp_ciclo_participantes_avaliador_sel` (migration 116) | **Executado** (commit b1e6e82, 2026-10-14) |
| `118_dp_tipo_elegibilidade_atualizar_enum.sql` | DROP + RECREATE do ENUM `dp_tipo_elegibilidade` com valores corretos (`todos`, `por_setor`, `por_cargo`, `por_gestor`, `por_colaborador`); DROP + ADD COLUMN `dp_ciclos.tipo_elegibilidade`. Safe — nenhum ciclo existia. Corrige HTTP 400 "invalid input value for enum" ao salvar ciclo | **Executado** (commit f07750f, 2026-10-14) |
| `119_dp_rls_historico_gestor_sel.sql` | Adiciona SELECT em `dp_historico_eventos` para perfil `gestor` — completa migration 113 (que só criou INSERT). Âncora dupla: `entidade='dp_ciclos' AND entidade_id = ANY(auth_avaliador_ciclo_ids())` OU `entidade='dp_avaliacoes' AND entidade_id IN (SELECT id FROM dp_avaliacoes WHERE avaliador_id=auth.uid())`. Usa `auth_avaliador_ciclo_ids()` (migration 117) para evitar recursão. Idempotente. | **Executado** (commit a78b661, 2026-10-15) |
| `120_dp_param_motivos_nao_participacao.sql` | Cria tabela `dp_param_motivos_nao_participacao` (id UUID PK, descricao TEXT, ativo BOOLEAN, criado_em). RLS: RH/admin CRUD; gestor/diretoria SELECT ativo=TRUE. 4 motivos seed: "Demissão prevista", "Afastamento médico", "Licença", "Outro". | **Executado** (commit de05db4, 2026-10-15) |
| `121_dp_ciclo_participantes_nao_participa.sql` | ADD 6 colunas em `dp_ciclo_participantes`: `nao_participa BOOLEAN NOT NULL DEFAULT FALSE`, `nao_participa_motivo_id UUID FK`, `nao_participa_motivo TEXT` (snapshot), `nao_participa_obs TEXT`, `nao_participa_em TIMESTAMPTZ`, `nao_participa_por UUID FK auth.users`. CHECK: motivo obrigatório quando `nao_participa=TRUE`. | **Executado** (commit de05db4, 2026-10-15) |
| `122_dp_trg_bloqueia_aval_nao_participa.sql` | Trigger `BEFORE INSERT` em `dp_avaliacoes` (`WHEN NEW.participante_id IS NOT NULL`) — função `dp_fn_bloqueia_aval_nao_participa()` bloqueia INSERT para participante com `nao_participa=TRUE`. **Apenas INSERT**: UPDATE de avaliações existentes é livre. | **Executado** (commit de05db4, 2026-10-15) |
| `123_dp_rls_nao_participa_update.sql` | Policy UPDATE em `dp_ciclo_participantes` para o flag `nao_participa`: RH/admin irrestrito; gestor apenas em ciclos onde `ciclo_id = ANY(auth_avaliador_ciclo_ids())`. Idempotente. | **Executado** (commit de05db4, 2026-10-15) |
| `124_dp_fn_marcar_reverter_nao_participa.sql` | Funções `SECURITY DEFINER` atômicas: `dp_fn_marcar_nao_participa(p_participante_id, p_motivo_id, p_motivo_texto, p_obs)` e `dp_fn_reverter_nao_participa(p_participante_id)`. Cada uma: (1) valida permissão (rh/admin ou gestor do ciclo via `auth_avaliador_ciclo_ids()`); (2) UPDATE `dp_ciclo_participantes`; (3) INSERT `dp_historico_eventos` (`nao_participa_marcado` / `nao_participa_revertido`). Atomicidade garante que histórico nunca fica dessincronizado. | **Executado** (commit de05db4, 2026-10-15) |
| `125_dp_enum_nao_participa.sql` | `ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS 'nao_participa_marcado'` e `'nao_participa_revertido'`. Corrige HTTP 400 ao marcar não participante — migration 124 usava esses valores nas RPCs mas nunca os adicionou ao ENUM. | **Executado** (commit 432ae11, 2026-10-16) |
| `126_dp_bloquear_aval_concluida.sql` | Dois triggers: (1) `trg_bloquear_resp_aval_concluida` — BEFORE INSERT/UPDATE em `dp_respostas` verifica se avaliação pai tem `status IN ('concluida','publicada')` e bloqueia com EXCEPTION; (2) `trg_bloquear_reverter_conclusao` — BEFORE UPDATE em `dp_avaliacoes` impede reversão de `concluida`/`publicada` para outro status. | **Executado** (commit 7149edb, 2026-10-16) |
| `127_dp_rls_bonus_gestor.sql` | Policy SELECT em `dp_resultados_bonus` para perfil `gestor`: cadeia `bonus → resultado → avaliacao → participante → equipe` via `auth_gestor_equipe_ids()`. Pré-requisito para o gestor usar o embed PostgREST `dp_resultados?select=*,dp_resultados_bonus(*)`. Segue padrão da migration 113. Idempotente. | **Executado** (2026-10-16) |
| `128_dp_historico_batch.sql` | `dp_fn_historico_criterio_batch(p_versao_id uuid, p_colaborador_id bigint, p_ciclo_atual_id uuid)` — retorna `TABLE(versao_criterio_id uuid, resultado jsonb)`. Itera os critérios da versão server-side e chama `dp_fn_historico_criterio` para cada um; substitui N RPCs paralelas por 1 chamada HTTP. `SECURITY INVOKER`. `GRANT EXECUTE TO authenticated`. | **Executado em produção** (2026-10-23) — Nota: após aplicar no Supabase, o PostgREST no plano gratuito demora até ~15 min para reconhecer a nova função via PGRST202 (schema cache assíncrono). O curl com service key confirma disponibilidade imediata; o browser (JWT usuário) reflete após o cache atualizar. |
| `130_dp_respondida_enum.sql` | `ALTER TYPE dp_status_avaliacao ADD VALUE IF NOT EXISTS 'respondida' BEFORE 'concluida'` — adiciona status intermediário entre `em_andamento` e `concluida`. **Deve ser executado e committed ANTES da migration 131** (restrição PostgreSQL: ADD VALUE não pode estar na mesma transação que código usando o novo valor). | **Executado em produção** (2026-10-16) |
| `131_dp_validar_conclusao.sql` | Função `dp_fn_validar_conclusao()` + trigger `trg_validar_conclusao` BEFORE UPDATE em `dp_avaliacoes`. Bloqueia transição `status → concluida` quando há critérios `obrigatorio=true` sem resposta preenchida. Obtém `versao_id` via `dp_ciclos`. Não interfere em saves `em_andamento` ou `respondida`. `SECURITY DEFINER`. | **Executado em produção** (2026-10-16) |
| `132_dp_corrigir_respondidas.sql` | Correção de dados: UPDATE `dp_avaliacoes SET status='respondida'` para registros com `status='em_andamento'` que já tinham todos os critérios obrigatórios respondidos (criados antes da migration 130). Corrigiu 9 avaliações do ciclo Gratificação CD - Setembro/2026. 1 avaliação permaneceu `em_andamento` (9/10 critérios — incompleta). | **Executado em produção** (2026-10-16) |
| `134_dp_avaliacoes_unique_participante.sql` | `ALTER TABLE dp_avaliacoes ADD CONSTRAINT dp_avaliacoes_participante_id_key UNIQUE (participante_id)` — impede duplicatas por condição de corrida (duplo clique ou requisições paralelas antes do retorno do primeiro POST). Pré-requisito: limpar duplicatas existentes com `SELECT participante_id, COUNT(*) FROM dp_avaliacoes GROUP BY participante_id HAVING COUNT(*) > 1`. | **Executado em produção** (2026-10-26) |

---

## Estado atual — Etapas D&P

| Etapa | O que cobre | Status |
|---|---|---|
| **Etapa 1 — Ciclos D&P** | Criar ciclo, definir elegibilidade, adicionar/remover participantes, mudar status rascunho→aberto | ✅ Implementado (commit f94d3e9) |
| **Etapa 2 — Avaliação do Gestor** | Formulário guiado por critérios da versão; CRUD dp_avaliacoes + dp_respostas | ✅ Implementado (2026-10-03) |
| **Etapa 3 — Cálculo** | Cálculo JS por tipo_calculo → dp_resultados; conversão para conceito | ✅ Implementado (2026-10-03) |
| **Etapa 4 — Regra financeira UI** | Configuração de dp_regras_financeiras no drawer da versão | ⏭ Pulada — baixa prioridade |
| **Etapa 5 — Análise e fechamento RH** | Ajuste inline de resultados, encerramento com confirmação, histórico de eventos | ✅ Implementado (2026-10-03) |
| **Etapa 6 — Relatório/exportação** | Botão Exportar Excel na aba Resultados | ✅ Implementado (2026-10-03) |
| **Gestor D&P — Minha Equipe** | Aba exclusiva do Gestor: lista ciclos ativos, drawer com 3 abas (Participantes/Avaliações/Resultados), formulário de avaliação reutilizando motor RH | ✅ Implementado (commit fbd50bb, 2026-10-14) |

## Drawer `drawerDpCiclo` — abas e funções por aba

| Aba | Visível quando | Função de load | O que faz |
|---|---|---|---|
| Participantes | sempre | `dpLoadParticipantes(cicloId)` | Lista + adicionar/remover participantes |
| Avaliações | aberto ou encerrado | `dpLoadAvaliacoes(cicloId)` | Cards por participante com status; abre `formAvalOverlay` |
| Resultados | aberto ou encerrado | `dpLoadResultados(cicloId)` | Cards com nota/conceito; calcular, ajustar, encerrar, exportar |
| Histórico | sempre | `dpLoadHistorico(cicloId)` | Eventos do ciclo e avaliações em ordem cronológica reversa |
| Informações | sempre | inline em `dpAbrirDrawerCiclo` | Detalhes do ciclo, versão, tipo avaliador |

## Variáveis de estado — motor D&P (completo)

```js
// Biblioteca/escalas
let _dpCriterios, _dpEscalas, _dpEscalaOpcoes, _dpCriteriosEmUso, _dpSetores
let _bibFiltroTipo, _catFiltroTipo

// Modelos/versões
let _dpModelos, _dpVersoes, _dpVersaoAtual, _dpVersaoCrits, _dpVersaoBlocos
let _dpVersaoReadonly, _dpBlocoAlvoId, _escalaOpcoesTemp

// Configuração
let _dpTiposCalculo, _dpTiposAvaliador, _dpTabelasConceito, _dpFaixasConceito

// Ciclos
let _dpCiclos, _dpCicloAtual
let _dpCicloElegSetorTemp, _dpCicloElegCargoTemp
let _dpElegColabSel, _dpPickerColabs

// Participantes
let _dpParticipantes    // [{ id, ciclo_id, colaborador_id, snapshot:{nome,matricula,empresa,setor,cargo,unidade,em_experiencia,data_admissao} }]

// Gestores (param_gestor) — para exibição no drawer de ciclo
let _dpParamGestores    // [{apelido, nome}] — carregado no init() junto com outros dados

// Avaliações (Etapa 2)
let _dpAvaliacoes       // [{ id, ciclo_id, colaborador_id, tipo_avaliador_id, status }]
let _dpAvaliacaoAtual   // avaliação aberta no formulário
let _dpRespostasAtual   // respostas da avaliação aberta
let _dpVersaoCritsParaForm  // critérios da versão para o formulário
let _dpFormNavList = [] // IDs de participantes navegáveis no formAvalOverlay
let _dpFormNavIdx  = -1 // posição atual na lista de navegação

// Resultados (Etapa 3)
let _dpResultados       // [{ id, avaliacao_id, nota_final, conceito, calculado_em }]
let _dpResultadosBonus  // [{ id, resultado_id, valor_bonus, snapshot_criterios, calculado_em }] — rh/admin/diretoria only

// Histórico por critério (Etapa 2 — formulário de avaliação)
let _dpHistoricoCriterios = {}  // { versao_criterio_id: JSONB retornado por dp_fn_historico_criterio }

// Cache de performance (2026-10-16)
let _dpFormCache            = {}    // { [versaoId]: { versaoCrits, modeloId } } — dados estáticos da versão; invalida ao fechar drawer
let _dpResultadosCicloId    = null  // cicloId dos resultados já carregados na aba Resultados
let _dpHistoricoCarregadoCicloId = null // cicloId do histórico já carregado na aba Histórico
let _gdpCiclosCarregados    = []    // ciclos enriquecidos do gestorDpLoadCiclos (cache para gestorDpAbrirDrawer)
```

## Funções novas — Etapas 2, 3, 5, 6

### Etapa 2 — Avaliação do Gestor
| Função | O que faz |
|---|---|
| `dpLoadAvaliacoes(cicloId)` | GET dp_avaliacoes; chama dpRenderAvaliacoes |
| `dpRenderAvaliacoes(opts={})` | Card por participante cruzando _dpAvaliacoes; badge por status. Opts: `containerId` (default `dpAvaliacoesBody`), `onAvaliarFn` (default `dpAbrirFormAvaliacao`), `participants` (default `_dpParticipantes`), `prefixHtml` (HTML antes da lista), `hideAvaliarWhenDone` (boolean — se `true`, oculta botão Avaliar para status `concluida`/`publicada`) |
| `dpAbrirFormAvaliacao(participanteId, navList?)` | Busca/cria dp_avaliacao; carrega critérios via `_dpFormCache` + respostas (`sbGet`) de forma bloqueante; abre o modal imediatamente; dispara `dp_fn_historico_criterio_batch` em background (fire-and-forget) com guard de corrida `_thisAvalId = aval.id` — resultado descartado se `_dpAvaliacaoAtual` mudou antes da resposta; preenche chips via `_dpAtualizarChipsHistorico()` quando retorna. `navList` opcional: se passado, seta a lista; se omitido e lista já existir, mantém; se omitido e lista vazia, auto-constrói de `_dpParticipantes` ativos. |
| `dpRenderFormAvaliacao()` | Linha compacta por critério (num, nome, botão ℹ, Sim/Não, obs, chip histórico); bloco expandível `.aval-info-expand` como irmão do `.aval-card`. Chip histórico renderiza como `<span id="dp-hist-{vc.id}"></span>` (vazio) e é preenchido por `_dpAtualizarChipsHistorico()` após o batch retornar. |
| `_dpAtualizarChipsHistorico()` | Percorre `_dpVersaoCritsParaForm`; para cada critério com `_dpHistoricoCriterios[vc.id]` preenchido, localiza `#dp-hist-{vc.id}` e injeta o HTML do chip. Chamada somente após batch retornar, somente se `_dpAvaliacaoAtual.id === _thisAvalId` (guard de corrida). |
| `salvarAvaliacao(status)` | Coleta resp_*; upsert dp_respostas (`on_conflict=avaliacao_id,versao_criterio_id`); PATCH dp_avaliacoes; **só então** chama `fecharFormAval()` (modal fecha após confirmação de gravação); re-render da lista via `setTimeout(0)` (próximo tick — sem bloquear pintura do fechamento); se `_gdpCicloAtual` estiver ativo, sincroniza `_gdpAvaliacoes = _dpAvaliacoes` e re-renderiza `gdptab-avaliacoes` preservando filtros, também diferido no mesmo `setTimeout(0)`. Registra evento se concluída. |
| `fecharFormAval()` | Fecha overlay; limpa estado (`_dpAvaliacaoAtual`, `_dpRespostasAtual`, `_dpVersaoCritsParaForm`); zera `_dpFormNavList` e `_dpFormNavIdx` |
| `dpNavForm(delta)` | Navega ±1 na `_dpFormNavList`; detecta alterações via `_dpFormTemAlteracoes()`; salva rascunho via `_dpSalvarParaNavegar()` se houver mudanças; bloqueia navegação se save falhar; chama `dpLoadAvaliacoes` + `dpAbrirFormAvaliacao(nextId)` |
| `_dpSalvarParaNavegar()` | Versão silenciosa de save (sem toast de sucesso); retorna `true/false`; apenas para status `em_andamento` — `concluida`/`publicada` retornam `true` sem salvar |
| `_dpFormTemAlteracoes()` | Compara valores atuais do DOM com `_dpRespostasAtual`; detecta alterações em respostas e observações |
| `_dpRenderAvalAvatar(fotoUrl, nome)` | Atualiza `#formAvalAvatar` com `<img>` + onerror fallback para iniciais |
| `_dpAvalIniciais(nome)` | Retorna `<span>XY</span>` com as iniciais do nome |
| `_dpAtualizarNavBtns()` | Atualiza `disabled` e `display` dos botões `#formAvalPrev`/`#formAvalNext` e contador `#formAvalCounter` |

**Histórico por critério no formulário (commit 172f23f):**
- Carregado em background após abertura do modal via `dp_fn_historico_criterio_batch` (migration 128) — 1 RPC, não N
- Guard de corrida: `_thisAvalId = aval.id` capturado antes do fire-and-forget; se `_dpAvaliacaoAtual.id !== _thisAvalId` no retorno, resultado descartado (usuário navegou para outro colaborador)
- Chips renderizados como `<span id="dp-hist-{vc.id}"></span>` no `dpRenderFormAvaliacao()` e preenchidos depois por `_dpAtualizarChipsHistorico()`
- `_dpHistoricoCriterios[vc.id]` → JSONB com campos; `null` = sem histórico (chip permanece vazio)
- `comparavel: false` → exibe "Sem avaliação anterior comparável" em itálico
- Critérios **binários**: exibe `resposta_texto` (Sim/Não) quando disponível; fallback `conceito_selecionado`
- Critérios **escala**: `escala_opcao_label (valor)` | **numérico**: `valor_numerico_livre` | **conceito**: `conceito_selecionado`

**Overlay:** `#formAvalOverlay` / `#formAvalPanel` — **modal centralizado** (`.modal-aval-overlay` pattern, `position:fixed; display:flex; align-items:center; justify-content:center; z-index:9100`); **não** usa `.wiz-overlay` (que é right-side drawer z-index 9000).
**IDs dos inputs de resposta:** `resp_${versaoCriterioId}`

### Etapa 3 — Cálculo
| Função | O que faz |
|---|---|
| `dpLoadResultados(cicloId)` | GET `dp_resultados` filtrando pelos ids das avaliações do ciclo; GET `dp_resultados_bonus` filtrando pelos resultado_ids obtidos |
| `dpRenderResultados()` | Toolbar com contador + botões; card por participante com badge + nota (quando `nota_final != null`) + conceito + bônus (de `_dpResultadosBonus`) |
| `dpCalcularTodos()` | Promise.all de dpCalcularAvaliacao para todas concluídas sem resultado |
| `dpCalcularAvaliacao(avaliacaoId)` | Busca versão+critérios+respostas; separa critsNota e critsBonus (Opção B); aplica tipo_calculo nos critsNota; salva via RPC `dp_salvar_resultado` |

**Lógica de tipo_calculo:** soma · media · media_ponderada (usa `peso`) · percentual_atingimento · qualitativo (nota=null)

**Opção B — separação critérios binários monetários:**
- `critsBonus`: `tipo_resposta='binario' AND valor_se_sim IS NOT NULL` → `bonusTotal`, gravado em `dp_resultados_bonus`
- `critsNota`: todos os demais → `nota_final` (null quando só há critsBonus)
- Os dois resultados são independentes — sem soma automática entre nota e bônus

### Etapa 5 — Análise e Fechamento
| Função | O que faz |
|---|---|
| `dpRegistrarEvento(tipo, entidade, entidadeId, detalhe)` | POST dp_historico_eventos; silencioso em caso de falha |
| `dpToggleAjuste(resultadoId, avaliacaoId)` | Alterna modo visualização/edição inline no card de resultado |
| `dpSalvarAjuste(resultadoId, avaliacaoId)` | PATCH dp_resultados com nota/conceito editados |
| `dpEncerrarCiclo()` | Confirmação dois cliques → dpMudarStatus('encerrado') → fecha drawer |
| `dpLoadHistorico(cicloId)` | GET eventos do ciclo + avaliações em paralelo; ordena desc |
| `dpRenderHistorico(eventos)` | Lista label legível + detalhe + data/hora |

**Eventos registrados automaticamente:**
- `ciclo_aberto` / `ciclo_encerrado` — em `dpMudarStatus`
- `avaliacao_iniciada` — em `dpAbrirFormAvaliacao` ao criar avaliação nova
- `avaliacao_concluida` — em `salvarAvaliacao('concluida')`

### Etapa 6 — Exportação
| Função | O que faz |
|---|---|
| `dpExportarResultados()` | Gera .xls (HTML-as-XLS com mso-conditionals) com todos os participantes; colunas: matrícula, nome, cargo, setor, unidade, status avaliação, nota final, conceito |

## Melhorias entregues (2026-10-15) — prazo_avaliacao e edição de ciclos

| Commit | O que foi feito |
|---|---|
| `c0f3a93` | Campo `prazo_avaliacao DATE NULL` em `dp_ciclos`; modal criação/edição com campo "Prazo para avaliações"; `dpSalvarCiclo` envia `prazo_avaliacao: null` quando vazio; `dpLoadCiclos` usa `select=*` (inclui campo automaticamente) |
| `068abb9` | Remove nota âmbar "Período avaliado encerrado" do card sidebar (era baseada em `data_fim < hoje` — substituída pelo sistema de prazo) |
| `ae1a530` | Bloco "Período avaliado" no card sidebar com borda lateral azul e fundo suave para diferenciar das demais informações |
| `56b2480` | Rótulo "Período avaliado" no banner azul do ciclo ativo (antes da data) |
| `aef45cf` | Ajuste de estilo: rótulo em minúsculas, mesma cor da data |
| `737e631` | `dpAbrirModalCiclo(cicloId?)`: modo edição carrega dados do ciclo, título muda para "Editar Ciclo D&P", botão "Salvar alterações"; `dpSalvarCiclo` faz PATCH quando `_dpCicloEditandoId` presente; botão "Editar ciclo" na aba Informações, visível apenas para RH (`_perfil !== 'gestor'`); `_dpCicloEditandoId = null` declarado junto às demais variáveis de ciclo |

### Card sidebar — 4 estados do `prazo_avaliacao`

| Situação | Condição | Apresentação |
|---|---|---|
| **Concluído** | `pendentes === 0` (qualquer) | Verde: "Todas as avaliações concluídas" |
| **Prazo vencido** | `prazo_avaliacao < hoje` + pendentes > 0 | Âmbar: "Prazo de avaliações vencido" |
| **Dentro do prazo** | `prazo_avaliacao >= hoje` + pendentes > 0 | Cinza discreto: "Prazo: DD/MM/AAAA" |
| **Sem prazo** | `prazo_avaliacao` null | Silêncio — sem nota |

### Lista de ciclos — `prazo_avaliacao`
- Com prazo futuro: linha discreta "Prazo: DD/MM/AAAA" em `--text-ter`
- Com prazo vencido (ciclo ativo): âmbar com ícone "Prazo vencido: DD/MM/AAAA"
- Sem prazo: silêncio

### Aba Informações — `prazo_avaliacao`
Linha "Prazo para avaliações": data formatada ou "Não definido" em `--text-ter` quando null.

### Edição de ciclos — `_dpCicloEditandoId`

```js
let _dpCicloEditandoId = null;  // null = modo criação; UUID = modo edição
```

- `dpAbrirModalCiclo()` → modo criação (limpa campos, título "Novo Ciclo D&P")
- `dpAbrirModalCiclo(cicloId)` → modo edição (carrega dados, título "Editar Ciclo D&P")
- `dpFecharModalCiclo()` zera `_dpCicloEditandoId`
- Botão "Editar ciclo" na `dpRenderInfoCiclo()` — oculto quando `_perfil === 'gestor'`

---

## Correções e melhorias entregues (2026-10-15) — primeiro ciclo D&P

| Commit | O que foi feito |
|---|---|
| `3125ee8` | Fix dropdown elegibilidade "Por gestor": usa `param_gestor?ativo=eq.true&select=apelido,nome`; `opt.value = g.apelido` (antes: `usuarios_perfil.nome` → mismatch com `colaboradores.gestor`) |
| `5a48b78` | Fix `dpGerarPreviewParticipantes`: coluna `empresa` → `empresa_atuacao`, removida coluna `unidade` (inexistentes → HTTP 400 → array vazio silencioso) |
| `6791ef1` | Fix `loadColaboradores`: mesma correção de colunas — era fonte de picker vazio |
| `117215b` | Fix adicional de colunas após recarregamento do módulo |
| `57848b4` | Modal inline substituiu `confirm()` nativo do browser — usa CSS vars, fundo overlay, botões Cancelar/Confirmar estilizados |
| `dd10432` | Picker aplica `dpIsElegivel(c)` como filtro rígido para ciclos não-`todos`; badge "Equipe" removido |
| `a38c159` | `dpRenderInfoCiclo`: exibe "Por gestor — ORIEL LEITE RODRIGUES" em vez de `"por_gestor"` raw; usa `_dpParamGestores` |
| `f49e176` | `em_experiencia` adicionado ao select de `loadColaboradores` e `dpGerarPreviewParticipantes`; gravado no snapshot; picker e lista de participantes exibem badge âmbar "⏱ Em período de experiência" / "⏱ Em experiência" |
| `8993586` | Redesign visual do picker: cabeçalho + lupa + colunas alinhadas; `dpFecharPicker()` criado como helper que chama `dpRenderParticipantes()` |
| `690c32c` | UX picker: abre com estado vazio ("Digite um nome ou setor para buscar"); lista só aparece após digitar ≥1 caractere — elimina poluição visual de 88 itens ao abrir |
| `73e8ce8` | Botões "Gerar sugestão automática" e "+ Adicionar manualmente" movidos para `#dpParticipantesBotoes` (container fixo acima de `#dpParticipantesBody`); permanecem visíveis quando picker está aberto; `dpRenderParticipantes` controla `display` desse container via `botoes.style.display = readonly ? 'none' : 'flex'` |
| `8b10116` | `data_admissao` adicionado ao select de `loadColaboradores` e ao snapshot em `dpAdicionarColaboradores`; exibido nos cards como "Admissão: dd/mm/aaaa"; matrícula agora exibida como "Mat. 205" |
| `bd7f700` | Filtro por período do ciclo: `dpIsElegivelPeriodo` criado; aplicado em `dpIsElegivel` (picker) e `dpGerarPreviewParticipantes` (sugestão); `loadColaboradores` inclui `data_demissao`; merge retroativo de inativos em `dpAbrirDrawerCiclo`; sem `data_admissao` + ciclo com `data_fim` → bloqueado |

**Correção de dado no banco (2026-10-15):** `dp_ciclos` id `3462b8f0` — `elegibilidade_ids` atualizado para `["ORIEL"]` via PATCH com secret key (antes estava com nome completo "Oriel Capoia", incompatível com `colaboradores.gestor`).

**SQL executado em produção (2026-10-15):** snapshots dos 88 participantes já cadastrados atualizados com `data_admissao` via:
```sql
UPDATE dp_ciclo_participantes dcp
SET snapshot = dcp.snapshot || jsonb_build_object('data_admissao', c.data_admissao::text)
FROM colaboradores c
WHERE dcp.colaborador_id = c.id
  AND c.data_admissao IS NOT NULL
  AND (dcp.snapshot->>'data_admissao' IS NULL OR dcp.snapshot->>'data_admissao' = '');
```

## Correções e melhorias entregues (2026-10-14)

| Commit | O que foi feito |
|---|---|
| `9137cdc` | Removido `obs_obrigatoria` de todos os INSERTs em `dp_versao_criterios` (campo inexistente → PGRST204) |
| `9137cdc` | Default `tipo_resposta` trocado de `'escala'` para `'numerico'` (constraint `escala_obrigatoria` exige `escala_id` não-nulo quando escala) |
| `9137cdc` | Label "v?" no drawer corrigido: `_dpVersaoAtual.versao` → `_dpVersaoAtual.numero` |
| `9137cdc` | Checkbox `obs_obrigatoria` e header "Obs." removidos da tabela de critérios (campo não existe) |
| `bbc29f4` | Modal "Adicionar Critério" arrastável pelo título; reset ao reabrir |
| `9cfdab0` | UX: reordenação de abas, renome de colunas, fluxo Verificar e publicar unificado, helper texts |
| `274143c` | Aba Ciclos conectada ao motor dp_* — `renderCiclos()` reescrita para dp_ciclos; botão chama `dpAbrirModalCiclo()`; sec-avaliacoes legada restaurada para `renderColabList()` |
| `9da2c52` | UX aba Modelos: faixa de orientação ①②③, barra de status contextual no drawer (`dvStatusBar`), tab renomeada, dica "+ Novo bloco", coluna Escala oculta quando irrelevante, aviso no footer |
| `d9ee5b7` | Fix: `renderModelos()` chamado na inicialização — spinner infinito ao entrar no módulo corrigido |

## Estrutura de abas atual (pós-commits 2026-10-14)

| Aba | Tabelas | Status |
|---|---|---|
| Configurações | dp_tipos_avaliador, dp_tipos_calculo_config, dp_tabelas_conceito | Novo — funcional |
| Critérios | dp_criterios | Novo — funcional |
| **Modelos** | dp_modelos, dp_versoes, dp_versao_blocos, dp_versao_criterios | Novo — **aba padrão ao entrar** |
| **Ciclos** | dp_ciclos, dp_ciclo_participantes | Novo — conectado ao motor dp_* |
| Colaboradores · legado | dev_ciclos, dev_avaliacoes | Legado — preservado |
| Avaliações · legado | dev_ciclos, dev_avaliacoes | Legado — preservado |
| Minha Equipe | dp_ciclos, dp_avaliacoes, dp_respostas | Gestor — funcional |

## Regra de navegação: aba ativa ao inicializar

`sec-modelos` tem `class="sec active"` no HTML e `renderModelos()` é chamada no `init()` RH (última linha após o `Promise.all`). Ao alterar a aba padrão: (1) mudar `active` no HTML; (2) trocar `renderModelos()` pela função da nova aba no `init()`.

## Barra de status contextual — `dvStatusBar`

Div `id="dvStatusBar"` posicionada entre metadados do header e as abas do drawer de versão. Atualizada por `atualizarStatusBarVersao()`, chamada ao abrir o drawer e a cada `renderVersaoCriterios()`.

- Versão sem critérios: fundo vermelho suave, texto "Adicione pelo menos um critério antes de publicar."
- Versão com critérios, rascunho: fundo âmbar, texto "Versão em rascunho. Confirme e clique em Verificar e publicar."
- Versão publicada: fundo verde, texto "Versão publicada. Para alterar, crie uma nova versão a partir desta."

## Avaliação Individual (commit 62efde4, 2026-10-14)

Não há estrutura paralela — um ciclo com 1 participante é uma avaliação individual.

**Botão "Avaliação individual"** (secundário, ao lado de "Novo ciclo"):
- Chama `dpAbrirModalCicloIndividual()` → `dpAbrirModalCiclo()` + pré-define `tipo_elegibilidade='por_colaborador'` + chama `dpAtualizarElegibilidade()` + define placeholder de nome
- O RH seleciona 1 colaborador no picker, nomeia (ex: "Avaliação de Experiência — João Silva"), escolhe versão e segue o fluxo normal
- Histórico comparável garantido: ciclos futuros do mesmo colaborador com mesmo modelo retornam o resultado desse ciclo individual via `dp_fn_historico_criterio`

## Elegibilidade de ciclos (commit d81f2a0, 2026-10-14)

| Tipo | Filtro aplicado em `dpGerarPreviewParticipantes` | `elegibilidade_ids` salvo |
|---|---|---|
| `todos` | sem filtro | `null` |
| `por_setor` | `c.setor.includes(eleg0)` | `[nome_setor]` |
| `por_cargo` | `c.cargo.includes(eleg0)` | `[nome_cargo]` |
| `por_gestor` | `(c.gestor\|\|'').toLowerCase() === eleg0.toLowerCase()` (case-insensitive) | `[apelido_gestor]` |
| `por_colaborador` | `ids.has(c.id)` | `[id1, id2, ...]` (strings) |

- `elegIds` computado em `dpSalvarCiclo` antes de enviar ao banco — nunca mais `null` indevidamente
- `dpGerarPreviewParticipantes` lê sempre de `ciclo.elegibilidade_ids`, não de variáveis temporárias
- Select "Por gestor" populado de `param_gestor?ativo=eq.true&select=apelido,nome` (commit 3125ee8). `opt.value = g.apelido` (chave canônica), `opt.textContent = g.nome`. Cadeia completa: `dropdown → apelido salvo em elegibilidade_ids[0] → filtro compara com colaboradores.gestor ilike apelido`.
- `_colaboradores` carregado com `ativo=eq.true` e campos válidos confirmados: `id,matricula,nome,cargo,setor,empresa_atuacao,foto_url,gestor,ativo,em_experiencia,data_admissao,data_demissao`. Colunas **inexistentes** (causam HTTP 400 silenciado → array vazio): `situacao`, `empresa`, `unidade`. (commits ff6b380, 5a48b78, 6791ef1, 117215b, f49e176, 8b10116, bd7f700)
- Para ciclos retroativos (`data_fim < hoje`), `dpAbrirDrawerCiclo` faz GET adicional `ativo=eq.false&data_demissao=gte.data_inicio` e mescla inativos não-duplicados em `_colaboradores`. A sugestão automática (`dpGerarPreviewParticipantes`) usa `_colaboradores` diretamente e inclui esses inativos retroativos automaticamente.
- **`elegibilidade_ids`** é `TEXT[]` (não `UUID[]`) — alterado via SQL inline `ALTER TABLE dp_ciclos ALTER COLUMN elegibilidade_ids TYPE TEXT[] USING elegibilidade_ids::TEXT[]`. Armazena: apelido do gestor, nome do setor/cargo, IDs inteiros de colaboradores como string.
- **Dropdown Avaliador Responsável** usa `sbRpc('fn_get_usuarios_perfil')` (SECURITY DEFINER, JOINa auth.users) + filtro JS `u.perfil === 'gestor'`. `opt.value = u.user_id` (UUID). Não usar `usuarios_perfil.id` (BIGINT serial) nem `select=user_id` direto (pode retornar null para usuários sem auth vinculado). (commit 0c1536b, 2026-10-14)

**Armadilha HTML — valor de `<option>`:** Se `opt.value = null` ou `opt.value = undefined`, o HTML não seta o atributo `value` e o valor do option cai para `textContent` (o nome da pessoa). Sempre garantir que `u.user_id` é UUID válido antes de atribuir.

**Normalização de dados executada (2026-10-14, Fase 1):** 11 registros em `colaboradores.gestor` corrigidos para bater com `param_gestor.apelido` — Evandro (+4), Flávio (+2), Jander (+2), Juninho (+3). `Robson (R)` → CAPOIA: pendente confirmação.

**Bug corrigido (2026-10-14, commit dc9cb2b):** `dpGerarPreviewParticipantes` usava `situacao=eq.ativo` (coluna inexistente → 400 silencioso). Corrigido para `ativo=eq.true`.

## Funções auxiliares — Etapa 1 (ciclos/participantes)

### `dpIsElegivelPeriodo(c, ciclo)` — filtro por período do ciclo (commit bd7f700, 2026-10-15)

```js
function dpIsElegivelPeriodo(c, ciclo) {
  if (!ciclo) return false;
  const inicio = ciclo.data_inicio ? new Date(ciclo.data_inicio) : null;
  const fim    = ciclo.data_fim    ? new Date(ciclo.data_fim)    : null;
  if (!inicio && !fim) return true; // ciclo sem período = sem filtro de data
  const admissao = c.data_admissao ? new Date(c.data_admissao) : null;
  const demissao = c.data_demissao ? new Date(c.data_demissao) : null;
  // Sem data_admissao e ciclo com data_fim definida: não inclui automaticamente
  if (!admissao && fim) return false;
  // Admitido após o término do período
  if (admissao && fim && admissao > fim) return false;
  // Desligado antes do início do período
  if (demissao && inicio && demissao < inicio) return false;
  return true;
}
```

**Regras:**
- Colaborador sem `data_admissao` é **bloqueado** quando o ciclo tem `data_fim` (precisa ser adicionado manualmente com aprovação explícita)
- Limites **inclusivos**: admitido no último dia (`admissao === fim`) e desligado no primeiro dia (`demissao === inicio`) são elegíveis
- Ciclo sem `data_inicio` e sem `data_fim` não aplica filtro temporal

**Onde é chamada:**
- `dpIsElegivel(c)` — primeiro guard antes de qualquer filtro de tipo de elegibilidade (picker manual)
- `dpGerarPreviewParticipantes` — filtro aplicado em `_colaboradores` antes dos filtros de tipo (sugestão automática)
- Tanto picker quanto sugestão automática aplicam **exatamente a mesma regra** — sem divergência

### `dpIsElegivel(c)` — verifica se colaborador é elegível para o ciclo atual
```js
function dpIsElegivel(c) {
  const ciclo = _dpCicloAtual;
  if (!ciclo) return false;
  if (!dpIsElegivelPeriodo(c, ciclo)) return false; // ← filtro de período aplicado primeiro
  const eleg0 = (ciclo.elegibilidade_ids||[])[0] || '';
  if (ciclo.tipo_elegibilidade === 'todos') return true;
  if (ciclo.tipo_elegibilidade === 'por_gestor' && eleg0)
    return (c.gestor||'').toLowerCase() === eleg0.toLowerCase();
  if (ciclo.tipo_elegibilidade === 'por_setor' && eleg0)
    return (c.setor||'').toLowerCase().includes(eleg0.toLowerCase());
  if (ciclo.tipo_elegibilidade === 'por_cargo' && eleg0)
    return (c.cargo||'').toLowerCase().includes(eleg0.toLowerCase());
  if (ciclo.tipo_elegibilidade === 'por_colaborador')
    return (ciclo.elegibilidade_ids||[]).map(Number).includes(c.id);
  return false;
}
```
Aplicado como **filtro rígido** em `dpFiltrarPicker()` para ciclos não-`todos`. Garante que o picker manual só lista colaboradores elegíveis dentro do período — adição por exceção não existe.

### Destaque visual `em_experiencia` (commit f49e176)

- **Picker:** fundo âmbar suave `rgba(245,158,11,0.06)` + texto `#b45309` "⏱ Em período de experiência" abaixo do nome
- **Lista de participantes:** badge compacto `#b45309`/`rgba(245,158,11,0.15)` "⏱ Em experiência" ao lado do nome + fundo âmbar suave na linha
- **Regra:** colaboradores com `em_experiencia=true` são incluídos normalmente — o destaque é visual, não filtrante
- **Na equipe do Oriel:** 20 colaboradores com `em_experiencia=true` (verificado 2026-10-15)

### `_dpParamGestores` e exibição de elegibilidade

```js
let _dpParamGestores = [];  // [{apelido, nome}] — carregado no init()
```
Carregado junto com outros dados no `init()`:
```js
sbGet('/rest/v1/param_gestor?ativo=eq.true&select=apelido,nome&order=apelido.asc')
  .then(r => { _dpParamGestores = r || []; })
```
Usado em `dpRenderInfoCiclo` para exibir "Por gestor — ORIEL LEITE RODRIGUES" em vez de `"por_gestor"`.

## Correções entregues (2026-10-15) — segurança e acesso gestor/diretoria

| Commit | O que foi feito |
|---|---|
| `3b5a0fb` | Correção 1: `init()` — seção `sec-gestor-dp` ativada ANTES de qualquer `await`; gestor nunca vê seções RH mesmo em caso de falha assíncrona |
| `3b5a0fb` | Correção 3: `initDpGestor()` lança erro explícito se `gestor_direto` não encontrado em `dp_tipos_avaliador`; `gestorDpAbrirFormAvaliacao` tem segunda guarda antes de criar avaliações |
| `a78b661` | Migration 119: SELECT em `dp_historico_eventos` para gestor (ciclos + avaliações próprias) |
| `a78b661` | Interface diretoria — `isDiretoria` adicionada ao `init()`; 5 pontos ocultam botões de ação para diretoria |

## Melhoria: "Não participará" direto na aba Participantes (commit c30e31e, 2026-10-16)

### O que foi adicionado

`dpRenderParticipantes` passou a exibir controles de não participação diretamente na aba Participantes do drawer RH, reutilizando toda a infraestrutura existente (modal, RPCs, permissões).

### Regra de exibição

```js
const podeNP = opts.readonly !== true &&
               (s === 'aberto' || s === 'em_andamento') &&
               (_perfil === 'rh' || _perfil === 'admin');
```

- `opts.readonly !== true` → exclui visão do gestor (que passa `readonly: true` explicitamente)
- Ciclos em `rascunho` não exibem os controles (a elegibilidade está sendo montada)
- Gestor não tem acesso pelos Participantes — continua podendo marcar pela aba Avaliações (⊘) quando `_podeMarcarNP` permite

### Visual por estado

| Estado do participante | O que aparece na linha |
|---|---|
| Ativo | Botão ⊘ (28×28px, tooltip "Marcar como não participante") |
| Marcado como NP | Badge cinza "⊘ Não participa" + observação em itálico + botão "Reverter" |

### Contador de cabeçalho

`"X participante(s) ativo(s) · Y não participam"` substituiu o simples `"N participante(s)"`.

### Sincronização entre abas

`dpConfirmarNaoParticipa` e `dpReverterNaoParticipa` agora chamam `dpRenderParticipantes()` após concluir — ambas as abas ficam consistentes sem recarregar o drawer.

### Sem alterações na aba Avaliações

Todo o comportamento existente foi preservado: `_ativos`, `_naoParticipa`, `_avalsAtivas`, seção "Não participam deste ciclo", contagens de pendentes, encerramento — nada foi modificado.

---

## Nome do colaborador clicável na aba Avaliações (commit `2725b25`, out/2026)

O nome do colaborador na lista de avaliações (função `dpRenderAvaliacoes`) agora é clicável, com comportamento dependente do status:

| Status | Clique no nome | Equivalente ao botão |
|---|---|---|
| Não iniciada / Em andamento / Respondida | `dpAbrirFormAvaliacao(p.id)` via `_onAvaliarFn` | Avaliar (clipboard) |
| Concluída | `dpAbrirFormAvaliacaoReadonly(p.id)` | Visualizar (olho) |
| Não participante | Sem ação | — |

**Visual:** `text-decoration: underline` discreto (cor `var(--border)`) + `cursor: pointer`; hover muda a cor do nome para `var(--blue)`. Botões de ação originais (Avaliar, Olho, Concluir, Editar, ⊘) **preservados e inalterados**.

**Escopo:** funciona em RH e Gestor — ambos usam `dpRenderAvaliacoes` com `_onAvaliarFn` como parâmetro, então o comportamento é herdado corretamente em cada visão.

**Implementação:** ternário inline no template literal da linha ~5920 em `dpRenderAvaliacoes`. Sem nova função, sem duplicação de lógica.

---

## Fix: status não atualizava na lista após salvar (commit `ffc789d`, out/2026)

**Causa:** `salvarAvaliacao` atualizava `_dpAvaliacoes` em memória corretamente, mas após `fecharFormAval()` nenhuma função re-renderizava a lista. O HTML da aba Avaliações mostrava o snapshot anterior até a próxima entrada no ciclo.

**Correção:** uma linha adicionada após `fecharFormAval()` em `salvarAvaliacao`:
```js
fecharFormAval();
_dpRenderAvaliacoesComFiltro(); // redesenha a lista com status já em memória
```

**Comportamento:** sem requisição ao banco — usa `_dpAvaliacoes` já atualizado na etapa 5. Filtros ativos são respeitados. Status "Respondida" aparece imediatamente quando todos os critérios estão respondidos; "Em andamento" se incompleto.

---

## Fix: status da avaliação não atualizava na lista do Gestor (commit `ab31288`, out/2026)

**Causa raiz:** Após salvar avaliação, `dpLoadAvaliacoes` recarregava `_dpAvaliacoes` e renderizava via `_dpRenderAvaliacoesComFiltro()` — mas essa função usa o container `dpAvaliacoesBody` (RH). No contexto do Gestor, o container visível é `gdptab-avaliacoes` e o mirror `_gdpAvaliacoes` não era atualizado.

**Correção:** No final de `salvarAvaliacao`, após o reload, verifica `_gdpCicloAtual`; se ativo, sincroniza `_gdpAvaliacoes = _dpAvaliacoes` e re-renderiza `gdptab-avaliacoes` preservando filtros de nome, cargo e status.

**Padrão confirmado:** Existem duas funções `salvarAvaliacao` no arquivo — linha ~2154 (legado, tabela `dev_avaliacoes`) e linha ~6561 (motor `dp_*`, com fix aplicado). O botão do formulário moderno chama sempre a segunda.

---

## KPI "Não participam" clicável na aba Avaliações (commits `ab31288`, `125786f`, `06572e6`, out/2026)

Novo chip KPI interativo ao lado dos status existentes (Não iniciada / Em andamento / Respondida / Concluída), implementado em ambas as visões (RH e Gestor) **sem alterações no banco**.

### Funções envolvidas

| Função | O que faz |
|---|---|
| `_dpStatusCounts(participantes, avaliacoes)` | Retorna `{ nao_iniciada, em_andamento, respondida, concluida, nao_participa }` — o 5º contador soma `participantes.filter(p => p.nao_participa).length`. **Usa Maps internos** (`avalByPartId`, `avalByColabId`) para lookup O(1) e consistência com `dpRenderAvaliacoes` (última vence em chave duplicada) |
| `_dpStatusChipsHtml(counts, filtroAtivo)` | Gera o HTML dos 5 chips em grid `repeat(5,1fr)`; chip "Não participam" tem cor vermelha (`#DC2626`) e `labelSize: '9px'` para caber sem corte |
| `_dpFiltrarPorStatus(lista, status, avaliacoes)` | Quando `status === 'nao_participa'`: retorna `lista.filter(p => p.nao_participa)`. Para qualquer outro status: **constrói Maps** `avalByPartId`/`avalByColabId` antes do loop (idêntico a `dpRenderAvaliacoes`) para garantir que o mesmo registro de avaliação seja usado no filtro e na renderização |
| `_dpRenderAvaliacoesComFiltro()` | Branch triplo: `=== 'nao_participa'` → só NP; `else if (status)` → só ativos com aquele status (sem concat NP); sem filtro → todos ativos + seção NP no rodapé |
| `gestorDpShowTab('avaliacoes')` | Mesma lógica de branch triplo para o container `gdptab-avaliacoes` |

### Comportamento dos filtros de status

| Filtro ativo | Quem aparece |
|---|---|
| Nenhum | Todos os ativos + seção "Não participam" separada no rodapé |
| Em andamento / Respondida / Não iniciada / Concluída | Somente os ativos com aquele status — **sem** seção NP |
| Não participam | Somente a seção NP (com motivo + observação) — sem ativos |

**Regra crítica:** nunca fazer `.concat(naoParticipa)` no branch `else if (filtroStatus)` — isso fazia não-participantes aparecerem junto a resultados de status específicos. A seção NP só é incluída no array quando `filtroStatus` está vazio.

### Visual do chip "Não participam"

- `bgOff: '#FFF5F5'`, `bgOn: '#FEE2E2'`, `numOff: '#DC2626'`, `numOn: '#991B1B'`, `ring: '#EF4444'`, `labelSize: '9px'`
- CSS das linhas de não participantes: `.dp-np-row` com borda esquerda vermelha (`#EF4444`), fundo `#FFF5F5`
- `.dp-np-badge`: texto vermelho (`#DC2626`), fundo `#FEE2E2`, borda `#FECACA`

### ⚠ Regra: Maps em lookup de avaliação por status

`_dpFiltrarPorStatus`, `_dpStatusCounts` e `dpRenderAvaliacoes` devem sempre usar a mesma lógica de lookup: `new Map(avaliacoes.map(a => [a.participante_id, a]))` (e fallback `colaborador_id` se existir na tabela). **Nunca usar `Array.find`** nessas funções — quando há dois registros com a mesma chave, `find` retorna o primeiro e `Map` retorna o último, causando divergência entre filtro e renderização. Contexto: `dp_avaliacoes` não tem coluna `colaborador_id`; o Map por `colaborador_id` é inócuo mas mantido para robustez futura.
- `.dp-np-section-header`: vermelho (`#B91C1C`), uppercase, `border-top:2px solid #FECACA`

### Filtros de nome e cargo

Continuam funcionando normalmente com todos os filtros de status — `_dpFiltrarParticipantes` é aplicado antes de qualquer branch de status.

---

## Fix: filtro de status exibia não participantes indevidamente (commit `6d5bd84`, out/2026)

**Sintoma:** clicar no KPI "Em andamento" mostrava o participante correto (Leandro Loyola) mais os 6 não participantes abaixo — como se o filtro "Não participam" estivesse ativo ao mesmo tempo.

**Causa:** o branch `else if (_dpAvalFiltroStatus)` terminava com `.concat(naoParticipa)` nos três pontos de renderização. Isso anexava sempre todos os não-participantes ao resultado de qualquer filtro de status ativo.

**Correção (3 locais):**

| Local | Linha aprox. | O que mudou |
|---|---|---|
| `_dpRenderAvaliacoesComFiltro` | ~5834 | Removido `.concat(naoParticipa)` do `else if`; variável órfã `const naoParticipa` também removida |
| `salvarAvaliacao` (sync gestor) | ~6669 | Removido `.concat(naoP)`; variável órfã `const naoP` também removida |
| `gestorDpShowTab` (aba avaliacoes) | ~7889 | Removido `.concat(naoParticipa)`; variável órfã também removida |

---

## Fix: 409 Conflict ao salvar avaliação retomada (commit `a68631e`, out/2026)

**Causa:** `sbUpsert` em `dp_respostas` usava `Prefer: resolution=merge-duplicates` sem indicar qual constraint usar. O PostgREST tentava resolver conflitos pela PK (`id`), que não estava no payload → tentativa de INSERT puro → 409 na constraint `UNIQUE (avaliacao_id, versao_criterio_id)`.

**Correção:** adicionado `?on_conflict=avaliacao_id,versao_criterio_id` na URL da chamada (~linha 6620):
```js
// antes
await sbUpsert('/rest/v1/dp_respostas', payloads);
// depois
await sbUpsert('/rest/v1/dp_respostas?on_conflict=avaliacao_id,versao_criterio_id', payloads);
```

**Efeito:** PostgREST usa a constraint correta → INSERT para respostas novas, UPDATE para existentes. Avaliações novas (sem respostas anteriores) não são afetadas. Trigger `trg_resposta_snapshot` só dispara em INSERT — comportamento preservado.

**Armadilha:** ao criar novas tabelas com upsert via `sbUpsert`, sempre incluir `?on_conflict=<colunas_da_unique>` na URL. Sem isso, o `resolution=merge-duplicates` usa a PK implicitamente e falha se o payload não inclui o `id`.

---

## Feature: "Não participa deste ciclo" (commit de05db4, 2026-10-15)

### Visão geral

Permite marcar um participante como não participante em um ciclo D&P (afastamento, demissão prevista etc.), com motivo obrigatório, histórico rastreável e reversível. O participante marcado é **excluído** de todos os cálculos (pendentes, médias, resultados, exportação, encerramento), sem deletar avaliações existentes.

### Regras de negócio

- **Gestor**: só para participantes de ciclos sob sua responsabilidade (`auth_avaliador_ciclo_ids()`)
- **Motivo**: obrigatório; selecionado de `dp_param_motivos_nao_participacao`; snapshot do texto salvo em `nao_participa_motivo` (imutável mesmo se motivo for inativado)
- **Avaliações existentes**: preservadas no banco (trigger só bloqueia INSERT novo)
- **Sem nota zero**: participante não entra em nenhum cálculo, médio ou pendência
- **Reversível**: `dp_fn_reverter_nao_participa` limpa os 6 campos; histórico anterior preservado
- **Rastreabilidade**: todo marcação/reversão registrada em `dp_historico_eventos` (`nao_participa_marcado` / `nao_participa_revertido`) com motivo, observação, quem e quando

### Tabela `dp_param_motivos_nao_participacao`

```sql
id          UUID PK
descricao   TEXT NOT NULL
ativo       BOOLEAN NOT NULL DEFAULT TRUE
criado_em   TIMESTAMPTZ DEFAULT NOW()
```

4 seeds: "Demissão prevista", "Afastamento médico", "Licença", "Outro". Inativação via toggle (nunca DELETE físico).

### Variável de estado

```js
let _dpMotivosNaoParticipa = [];  // carregado em dpAbrirDrawerCiclo e renderConfiguracoes
```

### Funções JS

| Função | O que faz |
|---|---|
| `loadDpMotivosNaoParticipa()` | GET `dp_param_motivos_nao_participacao?order=criado_em.asc&select=*` → `_dpMotivosNaoParticipa` |
| `dpAbrirModalNaoParticipa(participanteId)` | Cria overlay modal com select de motivos (ativos) + textarea observação |
| `dpConfirmarNaoParticipa(participanteId)` | Lê motivo selecionado (id + snapshot de texto); chama `sbRpc('dp_fn_marcar_nao_participa', {...})`; atualiza `_dpParticipantes` em memória; chama `dpRenderAvaliacoes()` |
| `dpReverterNaoParticipa(participanteId)` | Chama `sbRpc('dp_fn_reverter_nao_participa', {...})`; limpa campos no `_dpParticipantes` em memória; chama `dpRenderAvaliacoes()` |
| `renderMotivosNaoParticipa()` | Card CRUD de motivos na aba Configurações (toggle ativo/inativo + adicionar novo) |
| `dpSalvarMotivoNaoParticipa(id, campo, valor)` | sbPatch para atualizar motivo no banco + array local |
| `dpAdicionarMotivoNaoParticipa()` | sbPost para criar novo motivo + push no array + rerender |

### Impacto em funções existentes

| Função | Alteração |
|---|---|
| `dpRenderAvaliacoes(opts)` | Separa `_ativos` e `_naoParticipa`; filtra `_avalsAtivas` excluindo npIds; renderiza seção inferior "Não participam deste ciclo" com botão Reverter; botão ⊘ em cada ativo para marcar |
| `_dpSidebarAvalCounts` (sidebar) | 2 queries paralelas (`dp_avaliacoes` + `dp_ciclo_participantes`) → filtra npIds antes de contar pendentes |
| `dpRenderResultados()` | `_partAtivos` e `_partNP` separados; cálculos usam só `_partAtivos`; seção informativa no final para NP |
| `dpCalcularTodos()` | Filtra `npIds` antes de processar pendentes |
| `dpExportarResultados()` | NP recebem `npRow:true` → linha cinza itálico com "Não participou" + motivo como conceito |
| `dpAbrirFormAvaliacao` | Guard: se `part.nao_participa` → toast + return (não abre formulário) |
| `dpAbrirDrawerCiclo` | Chama `loadDpMotivosNaoParticipa()` se `_dpMotivosNaoParticipa.length === 0` |
| `renderConfiguracoes()` | `loadDpMotivosNaoParticipa()` no `Promise.all`; novo card "Motivos de não participação" |

### CSS adicionado

```css
.dp-np-row { display:flex;align-items:center;gap:10px;padding:10px 12px;border-bottom:1px solid var(--border-light);background:rgba(107,114,128,0.05); }
.dp-np-badge { font-size:10px;font-weight:600;color:#6B7280;background:rgba(107,114,128,0.12);border:1px solid rgba(107,114,128,0.25);border-radius:4px;padding:1px 5px;white-space:nowrap;flex-shrink:0; }
.dp-np-section-header { font-size:11px;font-weight:600;color:var(--text-ter);text-transform:uppercase;letter-spacing:.5px;padding:10px 12px 4px;border-top:1px solid var(--border); }
```

### Novos tipos em `dp_evento_historico` ENUM

`nao_participa_marcado` e `nao_participa_revertido` — adicionados via **migration 125** (`ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS`). A migration 124 usava esses valores nas RPCs mas esqueceu de adicioná-los ao ENUM — causava HTTP 400. Se recriar o ENUM, incluir esses dois valores.

---

## Melhorias no formulário de avaliação (commit bd11018, 2026-10-16)

### 1. Foto do colaborador no header

- Avatar circular 40px (`#formAvalAvatar`, classe `.modal-aval-avatar`) exibido ao lado esquerdo das setas
- `.modal-aval-header-info`: `justify-content:flex-start` + `text-align:left` no container de nome/cargo — explícitos para evitar herança acidental
- Iniciais como fallback imediato; foto carregada async sem bloquear abertura
- Helper `_dpRenderAvalAvatar(fotoUrl, nome)` — se `fotoUrl` presente insere `<img>` com `onerror` fallback; senão, insere `_dpAvalIniciais(nome)`
- **Fonte da foto (commit 85cc945):** busca primeiro em memória (`_colaboradores`, populada na init RH); se vazio (visão Gestor) faz fetch de `/rest/v1/colaboradores?id=eq.${colabId}&select=foto_url`; comparação usa `Number()` em ambos os lados para evitar mismatch int/string
- **Atenção:** `_colaboradores` só é populada no path RH (não em `initDpGestor`); o fallback async REST garante foto no Gestor também

### 2. Setas de navegação entre colaboradores

- `_dpFormNavList` e `_dpFormNavIdx` — estado de navegação limpo em `fecharFormAval()`
- RH: auto-constrói lista respeitando filtros ativos (`_dpFiltrarParticipantes`); fallback para todos os ativos se resultado vazio
- Gestor: `gestorDpAbrirFormAvaliacao` constrói navList filtrada por `_gdpAvalFiltroNome` + `_gdpAvalFiltroCargos`; fallback para todos os ativos se resultado vazio
- Setas `#formAvalPrev` / `#formAvalNext` ocultas quando lista tem ≤1 item; primeira/última desabilitadas
- Contador `#formAvalCounter` mostra `"N / total"` quando navegação ativa
- `dpNavForm(delta)` — antes de navegar: detecta mudanças (`_dpFormTemAlteracoes`); se houver, salva via `_dpSalvarParaNavegar()`; se save falhar, permanece na avaliação atual (toast de erro); só então chama `dpAbrirFormAvaliacao(nextId)` reusando `_dpFormNavList`

### 3. Info ícone — bloco inline (corrige clipping)

**Problema:** `.aval-info { position:absolute }` dentro de `.modal-aval-body { overflow-y:auto }` — o popup era clipado invisível.

**Solução:** bloco `.aval-info-expand` como **irmão** do `.aval-card` no DOM (não filho), fora do contexto `overflow:auto`. `dpToggleInfo(vcId)` agora usa `id="info_exp_${vcId}"` (era `info_${vcId}`).

```css
.aval-info-expand { display:none; padding:8px 16px 10px 50px; background:var(--bg); border-bottom:1px solid var(--border-light); }
.aval-info-expand.open { display:block; }
```

### CSS do header — classes novas

```css
.modal-aval-nav-btn        /* botões < > — 28px, hover accent, disabled opacity 0.3 */
.modal-aval-header-info    /* flex 1, avatar + texto */
.modal-aval-avatar         /* 40px circular, background accent, overflow:hidden */
.modal-aval-nav-counter    /* "N / total", 11px, text-ter */
```

### HTML do header (overlay `#formAvalOverlay`)

```html
<div class="modal-aval-header-row">
  <button id="formAvalPrev" class="modal-aval-nav-btn" onclick="dpNavForm(-1)">‹</button>
  <div class="modal-aval-header-info">
    <div id="formAvalAvatar" class="modal-aval-avatar"></div>
    <div><div id="formAvalTitulo">…</div><div id="formAvalSub">…</div></div>
  </div>
  <span id="formAvalCounter" class="modal-aval-nav-counter"></span>
  <button id="formAvalNext" class="modal-aval-nav-btn" onclick="dpNavForm(1)">›</button>
  <button class="btn btn-secondary btn-sm" onclick="fecharFormAval()">Fechar</button>
</div>
```

---

## Filtros da aba Avaliações (commits 1dc4d94, 191f100, 432ae11 — 2026-10-16)

### Arquitetura

**Princípio:** RH e Gestor compartilham a mesma função de renderização (`dpRenderAvaliacoes`) e o mesmo componente de dropdown. Diferenças controladas por variáveis de estado isoladas por perfil.

### Estado

| Variável | Perfil | Tipo | Descrição |
|---|---|---|---|
| `_dpAvalFiltroNome` | RH | string | Filtro de busca por nome |
| `_dpAvalFiltroCargos` | RH | Set | Cargos selecionados no multi-select |
| `_gdpAvalFiltroNome` | Gestor | string | Filtro de busca por nome |
| `_gdpAvalFiltroCargos` | Gestor | Set | Cargos selecionados no multi-select |

Resetados em `dpFecharDrawerCiclo()` (RH) e `gestorDpFecharDrawer()` (Gestor) via `new Set()`.

### Funções

| Função | Descrição |
|---|---|
| `_dpFiltrarParticipantes(lista, nome, cargos)` | Utilitária compartilhada — filtra por nome (substring) e `Set.has(cargo)` |
| `_dpRenderAvaliacoesComFiltro()` | RH: aplica filtros e chama `dpRenderAvaliacoes` com `prefixHtml + participants + hideAvaliarWhenDone:true` |
| `_dpCargoDropdownHtml(ddId, cargos, selecionados)` | Gera HTML do dropdown multi-select; label dinâmico: "Todos os cargos" / cargo único / "N cargos"; ✕ inline no botão quando há seleção (`stopPropagation` para não abrir menu); "Limpar seleção" no rodapé do menu |
| `_dpCargoToggleDd(ddId)` | Abre/fecha dropdown; fecha ao clicar fora via listener no `document` |
| `_dpCargoToggle(ddId, cargo, checked)` | Toggle checkbox: atualiza Set (RH ou Gestor por `ddId`) e re-renderiza |
| `_dpCargoClear(ddId)` | Limpa Set e re-renderiza |
| `_dpFiltrosHtml()` | RH: input em `.gdp-aval-search-wrap` com ✕ (`.gdp-aval-search-clear`, `id=dpNomeBusca`) + dropdown (ddId `dpCargoDd`) |
| `_gdpFiltrosHtml()` | Gestor: mesma estrutura (input `id=gdpNomeBusca`, ddId `gdpCargoDd`) |

### CSS — classes dos filtros

| Classe | Descrição |
|---|---|
| `.gdp-aval-filtros` | Flex wrapper da barra de filtros; `gap:8px; flex-wrap:wrap` |
| `.gdp-aval-search-wrap` | Wrapper relativo do input; `flex:1; min-width:140px` |
| `.gdp-aval-search` | Input de busca; padding direito para o ✕ |
| `.gdp-aval-search-clear` | ✕ absoluto à direita; `display:none` por padrão; exibido inline quando há texto via `style="display:block"` |
| `.gdp-cargo-dd` | Wrapper relativo; `min-width:190px; flex-shrink:0`; `.open` controla visibilidade do menu |
| `.gdp-cargo-btn` | Botão disparador; `.active` quando há seleção |
| `.gdp-cargo-x` | ✕ inline no botão disparador; visível só quando `nSel > 0` |
| `.gdp-cargo-menu` | `display:none` → `display:block` quando `.open`; `max-height:260px; overflow-y:auto` |
| `.gdp-cargo-item` | `<label>` com checkbox; `hover: background var(--bg)` |
| `.gdp-cargo-clear` | Link "Limpar seleção" no rodapé do menu |

### Foco restaurado no input (commit 432ae11)

`dpRenderAvaliacoes` salva `document.activeElement.id` e `selectionStart` antes de substituir `el.innerHTML`. Após a substituição, localiza o elemento pelo id salvo e chama `focus()` + `setSelectionRange()`. Evita que o cursor suma a cada letra digitada na busca por nome.

### Navegação respeita filtros

`dpAbrirFormAvaliacao` (auto-build RH) e `gestorDpAbrirFormAvaliacao` constroem a navList chamando `_dpFiltrarParticipantes` com os filtros ativos no momento da abertura. Se o resultado for vazio, fallback para todos os participantes ativos (garante que o colaborador clicado sempre esteja na navList).

---

## Arquitetura de Performance (2026-10-16, commits fca3346 / a96bea9 / 4671245)

### Contexto

O módulo D&P apresentava latência perceptível em múltiplas interações (abertura do drawer, abertura do formulário de avaliação, navegação entre colaboradores). Diagnóstico completo e otimizações aplicadas em sessão de 2026-10-16.

### Padrão 1 — Cache de dados estáticos do formulário (`_dpFormCache`)

`dpAbrirFormAvaliacao` buscava `dp_versao_criterios`, `dp_criterios`, `dp_escalas`, `dp_escala_opcoes` e `dp_versoes` a cada colaborador aberto, mesmo sendo dados imutáveis (versão publicada não muda).

**Fix:** na primeira abertura de cada `versaoId`, os dados são armazenados em `_dpFormCache[versaoId]`. Nas aberturas seguintes, o cache é usado sem round-trip. **Invalidação:** `_dpFormCache = {}` em `dpFecharDrawerCiclo()` e `gestorDpFecharDrawer()`.

**Cache miss — queries em paralelo:**
```js
const [vc, respsEarly] = await Promise.all([
  sbGet(`/rest/v1/dp_versao_criterios?versao_id=eq.${versaoId}&order=ordem.asc&select=*`),
  sbGet(`/rest/v1/dp_respostas?avaliacao_id=eq.${aval.id}&select=*`)
]);
_dpRespostasAtual = respsEarly || [];
_respostasJaBuscadas = true; // flag local para não re-buscar respostas adiante
// dp_criterios + dp_escalas + dp_escala_opcoes + dp_versoes em Promise.all
_dpFormCache[versaoId] = { versaoCrits: _dpVersaoCritsParaForm, modeloId };
```

### Padrão 2 — RPC em lote para histórico (`dp_fn_historico_criterio_batch`)

Antes: N chamadas paralelas `sbRpc('dp_fn_historico_criterio', {...})` — 1 round-trip por critério (10 critérios = 10 requisições simultâneas).

**Fix (migration 128):** `dp_fn_historico_criterio_batch` executa o loop server-side e retorna todos os históricos em uma única chamada HTTP. **Fallback automático:** se a RPC retornar `null` (migration não executada), cai nas N chamadas individuais.

```js
const [resps, batch] = await Promise.all([
  _respostasJaBuscadas ? Promise.resolve(_dpRespostasAtual) : sbGet(...dp_respostas...),
  (modeloId && part.colaborador_id)
    ? sbRpc('dp_fn_historico_criterio_batch', {
        p_versao_id: versaoId, p_colaborador_id: part.colaborador_id, p_ciclo_atual_id: _dpCicloAtual.id
      })
    : Promise.resolve(null)
]);
if (batch && Array.isArray(batch)) {
  batch.forEach(row => { _dpHistoricoCriterios[row.versao_criterio_id] = row.resultado; });
} else if (modeloId && part.colaborador_id) {
  // fallback: N chamadas individuais
}
```

### Padrão 3 — Guards para recarregamento de abas

`dpShowDcTab` chamava a função de carregamento a cada troca de aba, mesmo que os dados já estivessem carregados.

**Fix:** guards por `cicloId` — só recarrega se o ciclo mudou:
```js
if (id === 'resultados' && _dpResultadosCicloId !== cicloId) dpLoadResultados(cicloId);
if (id === 'historico'  && _dpHistoricoCarregadoCicloId !== cicloId) dpLoadHistorico(cicloId);
```
`dpLoadResultados` e `dpLoadHistorico` atualizam `_dpResultadosCicloId` e `_dpHistoricoCarregadoCicloId` ao concluir. Invalidados em `dpFecharDrawerCiclo()` e `gestorDpFecharDrawer()`.

### Padrão 4 — Cache de ciclos do Gestor (`_gdpCiclosCarregados`)

`gestorDpAbrirDrawer` buscava ciclo + versão no banco mesmo quando `gestorDpLoadCiclos` já tinha esses dados em memória.

**Fix:** `gestorDpRenderCiclos` salva `_gdpCiclosCarregados = enriquecidos`. Em `gestorDpAbrirDrawer`:
```js
const cicloCache = _gdpCiclosCarregados.find(c => c.id === cicloId);
if (cicloCache) {
  // Normalização: gestorDpLoadCiclos salva como .dp_versoes; motor usa .versao
  _gdpCicloAtual = { ...cicloCache, versao: cicloCache.dp_versoes || cicloCache.versao };
} else {
  // fallback: busca no banco
}
```

### Padrão 5 — PostgREST embedding para resultados + bônus

`dpLoadResultados` / `gestorDpLoadResultados` faziam 2 queries sequenciais (`dp_resultados` → `dp_resultados_bonus`).

**Fix (pré-requisito: migration 127):** query única com embed:
```js
const resultadosRaw = await sbGet(
  `/rest/v1/dp_resultados?avaliacao_id=in.(${ids.join(',')})&select=*,dp_resultados_bonus(*)`
) || [];
_dpResultados      = resultadosRaw.map(r => { const { dp_resultados_bonus: _, ...rest } = r; return rest; });
_dpResultadosBonus = resultadosRaw.flatMap(r => r.dp_resultados_bonus || []);
```

### Padrão 6 — Maps O(1) em `dpRenderAvaliacoes`

O loop de renderização usava `.find()` O(n) para cada participante → O(n²) no total.

**Fix:** Maps construídos uma vez antes do loop:
```js
const _avalByPartId  = new Map(_dpAvaliacoes.map(a => [a.participante_id, a]));
const _avalByColabId = new Map(_dpAvaliacoes.map(a => [a.colaborador_id, a]));
const _resByAvalId   = new Map(_dpResultados.map(r => [r.avaliacao_id, r]));
const _bonusByResId  = new Map(_dpResultadosBonus.map(b => [b.resultado_id, b]));
const aval = _avalByPartId.get(p.id) || _avalByColabId.get(p.colaborador_id);
```

### Padrão 7 — Fire-and-forget para `dpRegistrarEvento`

`dpRegistrarEvento` era chamado com `await` na criação de avaliação, bloqueando a abertura do formulário.

**Fix:** chamada sem `await` para eventos de auditoria que não afetam o estado da tela:
```js
dpRegistrarEvento('avaliacao_iniciada', 'dp_avaliacoes', aval.id, { colaborador: snap.nome }); // fire-and-forget
```

**Limitação:** falhas de log passam silenciosas. Aplicar **apenas** para eventos de auditoria — nunca para operações que afetam estado visível.

### Padrão 8 — `gestorDpLoadCiclos` paralelo

Versões e participantes eram buscados sequencialmente após carregar ciclos.

**Fix:**
```js
const [versoes, participantes] = await Promise.all([
  versaoIds.length ? sbGet(`/rest/v1/dp_versoes?id=in.(${versaoIds.join(',')})&select=...`) || [] : Promise.resolve([]),
  sbGet(`/rest/v1/dp_ciclo_participantes?ciclo_id=in.(${cicloIds.join(',')})&select=id,ciclo_id,colaborador_id`) || []
]);
```

### Tabela resumo de otimizações

| Gargalo identificado | Fix aplicado | Status |
|---|---|---|
| Critérios/escalas/versão re-buscados a cada colaborador | `_dpFormCache` | ✅ |
| N RPCs de histórico (1 por critério) | `dp_fn_historico_criterio_batch` (migration 128) | ✅ |
| `dp_respostas` e batch histórico em sequência | `Promise.all` no cache miss | ✅ |
| Aba Resultados recarrega a cada visita | Guard `_dpResultadosCicloId` | ✅ |
| Aba Histórico recarrega a cada visita | Guard `_dpHistoricoCarregadoCicloId` | ✅ |
| Ciclo + versão re-buscados no drawer Gestor | `_gdpCiclosCarregados` | ✅ |
| 2 queries para resultados + bônus | PostgREST embed `dp_resultados_bonus(*)` | ✅ |
| `.find()` O(n²) no render loop | Maps O(1) | ✅ |
| `dpRegistrarEvento` bloqueando abertura | Fire-and-forget | ✅ |
| `gestorDpLoadCiclos` sequencial | `Promise.all` versoes + participantes | ✅ |

### Diagnóstico restante

Se a lentidão persistir: medir no DevTools (Network tab) o tempo real de `dp_fn_historico_criterio_batch`. A função executa N queries server-side em loop PL/pgSQL — se o banco estiver lento, o overhead de I/O domina e otimizações JS não ajudam. Próximo passo: reescrever a função com JOIN em vez de loop imperativo.

---

## Pendências técnicas

| Item | Prioridade | Detalhe |
|---|---|---|
| **Primeiro ciclo real** | Alta | Ciclo "Gratificação CD - Outubro/2026" criado (`rascunho`), 88 participantes adicionados. Falta: (1) validar interface com Oriel; (2) abrir o ciclo após validação. |
| **Validação funcional** | Alta | Testar com perfis reais: RH (todas as abas), ORIEL (gestor — seção Minha Equipe), Diretoria (somente leitura) |
| Escalas | Média | `dp_escalas` vazia — só bloqueia critérios do tipo `escala`; V1 usa apenas `binario`, então não bloqueia o primeiro ciclo |
| Testes funcionais com dados reais | Alta | Depende do primeiro ciclo real estar aberto com participantes |
| `param_setor` populado | Média | Pré-requisito para elegibilidade por setor |
| **Histórico de avaliações — Caminho 1** | Média | Aba "Histórico por Colaborador" no D&P (entre ciclos) — frontend only, sem migration |
| **Histórico de avaliações — Caminho 2** | Média | Registro em `historico_eventos` do cadastro; exige novo `tipo_evento` + ajuste no RPC; decisões A/B/C pendentes de aprovação |
| `nota_range_obrigatorio` toggle | Baixa | Futura migration para bloqueio obrigatório de range (hoje é apenas orientativo) |
| Camada financeira UI (Etapa 4 / Fase 5) | Baixa | dp_regras_financeiras por faixas — arquitetura planejada, não iniciada |
| PDI V2 vinculado a dp_ciclo_participantes | Baixa | Fase futura |
| DROP tabelas dev_* | Baixa | Pós-migração completa |

## Estado atual do banco — D&P (verificado 2026-10-15)

| Item | Qtd / Estado |
|---|---|
| `dp_escalas` | **0** — nenhuma criada |
| `dp_tabelas_conceito` | **0** |
| `dp_criterios` (biblioteca) | **49** critérios ativos (comportamentais + técnicos) |
| `dp_modelos` | **1** — "Avaliação Mensal Produtividade CD" |
| `dp_versoes` | **1** — V1, `em_uso=true` (publicada 2026-10-14T18:43:02), `converte_para_conceito=false` · 10 critérios binários monetários (`tipo_resposta='binario'`, `valor_se_sim=40`) |
| `dp_ciclos` | **1** — "Gratificação CD - Outubro/2026", `status='rascunho'`, `tipo_elegibilidade='por_gestor'`, `elegibilidade_ids=["ORIEL"]`, `avaliador_id=UUID do Oriel` |
| `dp_ciclo_participantes` | **88** — todos os colaboradores elegíveis da equipe do Oriel adicionados via sugestão automática (2026-10-15); snapshots incluem `data_admissao` |
| `dp_tipos_avaliador` | **4** — Gestor, RH, Auto-avaliação, Avaliador específico |

### V1 — detalhes (publicada)
- **Modelo:** "Avaliação Mensal Produtividade CD"
- **Tipo de cálculo:** `soma` · **Conversão para conceito:** não
- **Critérios:** 10 critérios binários, cada um vale R$40 se Sim / R$0 se Não → máximo R$400
- **Motor verificado:** dp_validar_versao → `{erros: [], valida: true}`
- **Trigger de imutabilidade corrigido** (migration 116) — V1 não pode mais ser alterada acidentalmente

## Decisões abertas — Histórico de avaliações na Ficha do Colaborador

Antes de implementar o Caminho 2 (integração com `historico_eventos`), confirmar:

| # | Questão | Impacto |
|---|---|---|
| **A** | A ficha deve mostrar apenas "avaliação concluída" (evento simples) ou também nota/conceito? | Define `titulo`/`resumo` gravados em `historico_eventos` |
| **B** | Gestor consegue ver o evento de avaliação na ficha do colaborador (Cadastro)? | Define RLS de SELECT em `historico_eventos` para esse tipo |
| **C** | Recálculo gera novo evento na ficha ("Avaliação D&P recalculada") ou só o evento original permanece? | Define se o RPC grava segundo evento em recálculos |

---

---

## Visão Gestor D&P — "Minha Equipe" (commit fbd50bb, 2026-10-14)

### Modelo de negócio

- RH cria modelos / versões / ciclos — Gestor **só preenche avaliações**
- Gestor não vê abas de RH; RH não vê aba do Gestor
- `auth_gestor_equipe_ids()` (migration 113) determina quem pertence à equipe via `colaboradores.gestor ILIKE param_gestor.apelido`

### Separação de perfis no `init()`

```js
const isGestor    = _perfil === 'gestor';
const isDiretoria = _perfil === 'diretoria';

document.querySelectorAll('[data-rh-only]').forEach(el => {
  el.style.display = (isGestor || isDiretoria) ? 'none' : '';
});
const tabGestor = document.getElementById('tabGestorDP');
if (tabGestor) tabGestor.style.display = isGestor ? '' : 'none';
if (isGestor) {
  await initDpGestor();
  // ativa sec-gestor-dp e tabGestorDP; retorna sem chamar init RH
  return;
}
```

Todas as 6 abas de RH têm `data-rh-only` no HTML — ocultam também para `diretoria`. O `init()` RH continua após o `return` para gestor.

**Botões de ação — diretoria vê somente leitura (commit a78b661, 2026-10-15):**
- `data-rh-only` adicionado nos botões "Novo ciclo" e "Avaliação individual" do header
- Condição `&& _perfil !== 'diretoria'` adicionada nos botões Abrir/Encerrar da lista de ciclos
- Condição `&& _perfil !== 'diretoria'` adicionada nos botões Editar/Abrir ciclo/Encerrar ciclo do drawer
- Condição `&& _perfil !== 'diretoria'` adicionada no botão "Encerrar ciclo" da aba Resultados
- Escrita via API continua bloqueada pela RLS (migration 112) — UI é proteção extra

### IDs HTML da visão Gestor

| Elemento | ID / classe |
|---|---|
| Tab nav | `tabGestorDP` |
| Seção principal | `sec-gestor-dp` |
| Corpo da lista de ciclos | `gestorDpBody` |
| Overlay do drawer | `gestorDpDrawerOverlay` |
| Botão aba Participantes | `gdptab-btn-participantes` |
| Botão aba Avaliações | `gdptab-btn-avaliacoes` |
| Botão aba Resultados | `gdptab-btn-resultados` |
| Conteúdo aba Participantes | `gdptab-participantes` |
| Conteúdo aba Avaliações | `gdptab-avaliacoes` |
| Conteúdo aba Resultados | `gdptab-resultados` |

### Variáveis de estado (Gestor)

```js
let _gdpCicloAtual    = null;   // ciclo selecionado no drawer (objeto completo)
let _gdpParticipantes = [];     // participantes da equipe no ciclo
let _gdpAvaliacoes    = [];     // avaliações do gestor no ciclo
let _gdpResultados    = [];     // resultados para aba Resultados
let _gdpTipoGestorId  = null;   // UUID de dp_tipos_avaliador WHERE codigo='gestor_direto'
```

**Atenção — variáveis compartilhadas com o motor RH:** `_dpCicloAtual`, `_dpParticipantes`, `_dpAvaliacoes` são reaproveitadas para chamar `dpAbrirFormAvaliacao`. Devem ser limpas ao fechar o drawer.

### Funções JS

| Função | O que faz |
|---|---|
| `initDpGestor()` | Resolve `_gdpTipoGestorId` (fallback GET se `_dpTiposAvaliador` vazio) |
| `gestorDpLoadCiclos()` | **3 queries separadas** (dp_ciclos → dp_versoes → dp_ciclo_participantes) — sem INNER JOIN implícito; monta objeto enriquecido em JS; renderiza cards |
| `gestorDpRenderCiclos(ciclos)` | Renderiza lista de ciclos; card exibe nome + "Período avaliado DD/MM a DD/MM" + "N participantes"; clique → `gestorDpAbrirDrawer` |
| `gestorDpAbrirDrawer(cicloId)` | **2 queries separadas** (dp_ciclos → dp_versoes por versao_id) — sem INNER JOIN implícito; pre-carrega participantes + avaliações; abre overlay |
| `gestorDpFecharDrawer()` | Fecha overlay; limpa `_gdpCicloAtual` e as 3 variáveis compartilhadas |
| `gestorDpShowTab(id, btn)` | Troca aba ativa no drawer |
| `gestorDpAbrirFormAvaliacao(participanteId)` | **Usa spread** para não mutar cache: `_dpCicloAtual = { ..._gdpCicloAtual, tipo_avaliador_id: _gdpTipoGestorId }` ; chama `dpAbrirFormAvaliacao` do motor RH |
| `gestorDpLoadResultados()` | Filtra resultados por `tipo_avaliador_id === _gdpTipoGestorId`; chama `dpRenderResultados({containerId:'gdptab-resultados', readonly:true})` |
| `gestorDpShowTab(id, btn)` | Troca aba ativa; chama funções **compartilhadas** do motor RH com `opts` — ver seção abaixo |

### Funções de renderização compartilhadas RH × Gestor (commit 0a36c67)

**Premissa:** RH e Gestor reutilizam **as mesmas três funções** de renderização — diferenças controladas por `opts`:

| Função | Chamada pelo RH | Chamada pelo Gestor (via `gestorDpShowTab`) |
|---|---|---|
| `dpRenderParticipantes(opts)` | `dpRenderParticipantes()` — botões visíveis, editável em rascunho | `dpRenderParticipantes({containerId:'gdptab-participantes', readonly:true})` |
| `dpRenderAvaliacoes(opts)` | `_dpRenderAvaliacoesComFiltro()` — aplica `_dpAvalFiltroNome` + `_dpAvalFiltroCargos`, passa `prefixHtml:_dpFiltrosHtml()` | `gestorDpShowTab('avaliacoes')` — aplica `_gdpAvalFiltroNome` + `_gdpAvalFiltroCargos`, passa `prefixHtml:_gdpFiltrosHtml()` |
| `dpRenderResultados(opts)` | `dpRenderResultados()` — toolbar + botões recalcular/ajustar/encerrar visíveis | `dpRenderResultados({containerId:'gdptab-resultados', readonly:true})` — toolbar e botões omitidos |

**`opts` disponíveis por função:**

`dpRenderParticipantes(opts)`:
- `containerId` — ID do container (default: `dpParticipantesBody`)
- `readonly` — boolean; se `true`, oculta botões de edição e container `#dpParticipantesBotoes` (default: baseado em `ciclo.status !== 'rascunho'`)

`dpRenderAvaliacoes(opts)`:
- `containerId` — ID do container (default: `dpAvaliacoesBody`)
- `onAvaliarFn` — nome da função JS chamada pelo botão Avaliar (default: `dpAbrirFormAvaliacao`)
- `participants` — array de participantes a renderizar (default: `_dpParticipantes`)
- `prefixHtml` — HTML inserido antes da lista (ex: filtros do gestor)
- `hideAvaliarWhenDone` — se `true`, oculta botão Avaliar para `status=concluida` ou `publicada`

`dpRenderResultados(opts)`:
- `containerId` — ID do container (default: `dpResultadosBody`)
- `readonly` — se `true`, omite toolbar (Calcular todos/Exportar/Encerrar) e botões por card (Recalcular/Ajustar)

**Estado compartilhado:** `gestorDpAbrirDrawer` (linha 6449 do index.html) seta `_dpAvaliacoes = _gdpAvaliacoes` antes de chamar `gestorDpShowTab` — garante que o lookup de status na `dpRenderAvaliacoes` funciona corretamente para o gestor.

### Regra crítica: spread no `gestorDpAbrirFormAvaliacao`

```js
async function gestorDpAbrirFormAvaliacao(participanteId) {
  // SPREAD obrigatório — sem isso, mutaria _gdpCicloAtual (mesmo objeto)
  _dpCicloAtual = { ..._gdpCicloAtual, tipo_avaliador_id: _gdpTipoGestorId || _gdpCicloAtual?.tipo_avaliador_id };
  _dpParticipantes = _gdpParticipantes;
  _dpAvaliacoes    = _gdpAvaliacoes;
  await dpAbrirFormAvaliacao(participanteId);
}
```

### Limpeza ao fechar drawer

```js
function gestorDpFecharDrawer() {
  document.getElementById('gestorDpDrawerOverlay').classList.remove('open');
  _gdpCicloAtual   = null;
  _dpCicloAtual    = null;   // compartilhada — limpar para não vazar para motor RH
  _dpParticipantes = [];
  _dpAvaliacoes    = [];
}
```

### RLS — dois mecanismos que coexistem via OR

**Migration 112 — base RLS (21 tabelas):**
- Config (11): SELECT para rh/admin/diretoria; INSERT/UPDATE/DELETE para rh/admin
- Operacional (5 — dp_ciclos, dp_ciclo_participantes, dp_avaliacoes, dp_respostas, dp_resultados): SELECT para rh/admin/diretoria; escrita só rh/admin
- Histórico: SELECT para rh/admin/diretoria; INSERT para rh/admin; UPDATE/DELETE bloqueados
- Financeiro (4 — dp_regras_financeiras, dp_regra_financeira_opcoes, dp_regra_financeira_faixas, dp_resultados_financeiros): somente rh/admin — diretoria e gestor sem acesso
- Sem `anon_all`: todas as queries D&P usam `access_token`; role anon bloqueado por padrão

**Migration 113 — equipe-based (via `auth_gestor_equipe_ids()`):**
- **Grupo 1 — config (11 tabelas):** SELECT para `auth_perfil()='gestor'` (irrestrito — qualquer gestor lê config)
- **Grupo 2 — operacional:** SELECT por equipe (`colaboradores.gestor ILIKE param_gestor.apelido`); INSERT/UPDATE com guarda `gestor_direto` + ciclo `aberto/em_andamento` + status `NOT IN ('concluida','publicada')`
- **Grupo 3 — histórico:** INSERT restrito a `avaliacao_iniciada/concluida` de `entidade='dp_avaliacoes'` vinculadas à equipe; **SELECT ausente nesta migration** (adicionado na 119)
- Total: 21 políticas aditivas (não altera policies de RH da migration 112)
- Idempotente via consulta a `pg_policies` (PostgreSQL não tem `CREATE POLICY IF NOT EXISTS`)

**Migration 116 — avaliador_id-based (`dp_ciclos.avaliador_id = auth.uid()`):**
- 9 policies com sufixo `_avaliador_*` — sem conflito com `_gestor_*` da migration 113
- Âncora: `avaliador_id = auth.uid()` em dp_ciclos → propaga para participantes, avaliações, respostas, resultados, bônus
- `dp_ciclos_avaliador_sel`, `dp_ciclo_participantes_avaliador_sel`, `dp_avaliacoes_avaliador_sel/ins/upd`, `dp_respostas_avaliador_sel/ins/upd`, `dp_resultados_avaliador_sel`, `dp_resultados_bonus_sel` (substituída — OR com admin/rh/diretoria)
- Gestor de outro ciclo não vê dados: âncora é o UUID do auth.uid(), não o nome

**Migration 119 — SELECT histórico para gestor:**
- Complementa migration 113 que só criou INSERT para gestor
- Policy `dp_historico_gestor_sel`: `entidade='dp_ciclos' AND entidade_id = ANY(auth_avaliador_ciclo_ids())` OR `entidade='dp_avaliacoes' AND entidade_id IN (dp_avaliacoes WHERE avaliador_id=auth.uid())`
- Usa `auth_avaliador_ciclo_ids()` (migration 117) para evitar recursão entre dp_ciclos e dp_ciclo_participantes
- `dp_fn_historico_criterio` é SECURITY INVOKER: RLS do gestor filtra automaticamente avaliações acessíveis

---

## Modal "Adicionar Critério" — arrastável (commit bbc29f4, 2026-10-14)

**Elemento:** `#modalSelecionarCriterio` (`.modal-overlay`) / `#modalSelecionarCriterioPanel` (`.modal` interno).

**Handle:** `#modalSelecionarCriterioHandle` (o `.modal-title`) — `cursor:move; user-select:none`.

**Mecanismo CSS:**
```css
.modal-overlay.dragging { align-items: flex-start; justify-content: flex-start; }
.modal-overlay.dragging > .modal { position: absolute; }
```
Na primeira drag, a overlay recebe `.dragging` e o painel recebe `left`/`top` fixos em pixels, convertendo de flex-centrado para posição absoluta.

**Mecanismo JS — IIFE `initCriterioModalDrag()`:**
- `mousedown` no handle: se não tem `.dragging`, captura o `getBoundingClientRect()` do painel antes de adicionar a classe; depois registra `startX/Y` e `origLeft/Top`
- `mousemove` no `document`: aplica `left/top` clampados entre 0 e os limites da viewport
- `mouseup` no `document`: para o drag
- Não afeta outros modais

**Reset:** `abrirModalCriterio` remove `.dragging` e limpa `left/top` antes de abrir — modal sempre reabre centrado.

---

## Compatibilidade: tipos de dados

- **`colaboradores.id` é INTEGER** — FKs para colaboradores usam `INTEGER`, nunca UUID
- **`dev_competencias.id` é BIGINT** — não confundir com UUID de dp_criterios
- **`dev_competencias.tipo`** usa `'tecnica'` (feminino); `dp_tipo_criterio` usa `'tecnico'`

---

## INNER JOIN implícito no PostgREST — armadilha crítica RLS

### O problema

PostgREST usa **INNER JOIN** automaticamente quando uma FK é `NOT NULL` e o recurso relacionado é embutido via `select=*,tabela_relacionada(*)`. Com RLS ativa, se a policy da tabela relacionada não retornar linhas para o perfil do usuário autenticado no contexto do embed, o INNER JOIN **zera toda a query pai** — sem erro, sem aviso, resultado vazio silencioso.

### Onde ocorre no D&P

| Query | FK NOT NULL | Impacto |
|---|---|---|
| `gestorDpLoadCiclos`: `dp_ciclos?select=*,dp_versoes(*)` | `versao_id NOT NULL` | Lista de ciclos vazia para gestor |
| `gestorDpAbrirDrawer`: `dp_ciclos?select=*,dp_versoes(*)` | `versao_id NOT NULL` | Drawer abre sem dados de versão; `_gdpCicloAtual.dp_versoes` null |
| `dpAbrirFormAvaliacao`: `dp_versao_criterios?select=*,dp_criterios(...),dp_escalas(...)` | `criterio_id NOT NULL` | Formulário abre sem critérios ("Nenhum critério configurado") |

### Fix padrão — separar queries e montar em JS

```js
// NUNCA (para perfil gestor):
const ciclos = await sbGet('/rest/v1/dp_ciclos?select=*,dp_versoes(*)');

// SEMPRE:
const ciclos = await sbGet('/rest/v1/dp_ciclos?select=*');
const versaoIds = [...new Set(ciclos.map(c => c.versao_id).filter(Boolean))];
const versoes = versaoIds.length ? await sbGet(`/rest/v1/dp_versoes?id=in.(${versaoIds.join(',')})&select=...`) : [];
const versaoMap = Object.fromEntries(versoes.map(v => [v.id, v]));
const enriquecidos = ciclos.map(c => ({ ...c, dp_versoes: versaoMap[c.versao_id] || null }));
```

**Regra:** sempre que uma tabela relacionada tem RLS ativa com policies diferentes do perfil atual, usar queries separadas + montagem manual em JS.

### Correções aplicadas

| Função | Commit | Fix |
|---|---|---|
| `gestorDpLoadCiclos` | `89effd2` | 3 queries: dp_ciclos → dp_versoes → dp_ciclo_participantes |
| `gestorDpAbrirDrawer` | `f3de5d9` | 2 queries: dp_ciclos → dp_versoes |
| `dpAbrirFormAvaliacao` (critérios) | `5bf1b9f` | Promise.all: dp_versao_criterios → dp_criterios + dp_escalas + dp_escala_opcoes |

---

## Correções entregues (2026-10-15) — visão Gestor funcional

### Bugs corrigidos

| Commit | Problema | Causa raiz | Fix |
|---|---|---|---|
| `e3bd216` | `ReferenceError: initDpGestor is not defined` ao inicializar com perfil gestor | `init()` chamado no primeiro `<script>` antes do segundo `<script>` (que define `initDpGestor`) ser parseado | Removida chamada `init()` do primeiro script; adicionada ao final do segundo script |
| `89effd2` | Token de sessão sempre avaliado como "não expirado" | `sess.expires_at` é em UNIX **segundos**; `Date.now()` é em **milissegundos** → comparação direta sempre falsa | Corrigido para `sess.expires_at * 1000 < Date.now()` |
| `89effd2` | Requisições com token expirado retornam 401 silencioso → array vazio | `sbGet` retornava `[]` em qualquer erro HTTP | `sbGet` detecta `r.status === 401` → chama `logout()` |
| `89effd2` | Gestor não via nenhum ciclo ("Nenhum ciclo aberto") | `versao_id NOT NULL` → PostgREST INNER JOIN → RLS zerando resultado | `gestorDpLoadCiclos` separado em 3 queries |
| `f3de5d9` | `dp_versoes` nulo no drawer (exibia "—" onde deveria ser versão) | Mesmo INNER JOIN em `gestorDpAbrirDrawer` | Separado em 2 queries |
| `5bf1b9f` | Botão "Avaliar" não fazia nada (formulário abria vazio) | `criterio_id NOT NULL` em `dp_versao_criterios` → INNER JOIN zerando critérios para gestor | `dpAbrirFormAvaliacao` separado em Promise.all de 3 queries |

### UX gestor — melhorias entregues (commit `f3de5d9`)

| Melhoria | Detalhe |
|---|---|
| **Modal centralizado** | `formAvalOverlay` migrado de `.wiz-overlay` (right-side, z-index 9000) para `.modal-aval-overlay` (centered, z-index 9100). CSS: `position:fixed; inset:0; display:flex; align-items:center; justify-content:center`. Painel com `border-radius:12px; max-width:900px; max-height:90vh` |
| **Indicador de progresso** | Header do modal exibe barra azul + label "X de Y critérios respondidos"; atualizado ao abrir e ao salvar rascunho via `dpAtualizarProgressoAval()` |
| **Filtros na aba Avaliações** | Input busca por nome (tempo real) + select cargo (populado dos participantes). Estados: `_gdpAvalFiltroNome` / `_gdpAvalFiltroCargo`; resetados ao abrir/fechar drawer |

### Paridade visual RH × Gestor — card de ciclo (commits b062ba1, f1e3395)

Card do gestor (`gestorDpRenderCiclos`) alinhado ao padrão do RH:
- Período exibido em linha própria abaixo do nome: `"Período avaliado DD/MM/AAAA a DD/MM/AAAA"` (separador `" a "`, não `" → "`)
- Meta-info em `12px`, cor `var(--text-sec)`, `justify-content:flex-start` (`.row-meta` tem `flex-end` global)
- Participantes na mesma linha secundária: `"Período avaliado DD/MM a DD/MM · N participantes"`
- **Causa da regressão anterior:** `.row-meta` tem `justify-content:flex-end` no CSS global → todo conteúdo ia para a direita. Fix: `style="justify-content:flex-start"` inline.

---

## Melhorias entregues (2026-10-15) — unificação visual RH × Gestor

| Commit | O que foi feito |
|---|---|
| `0a36c67` | Refatoração arquitetural: 3 funções de render duplicadas do Gestor (`gestorDpRenderParticipantes`, `gestorDpRenderAvaliacoes`, `gestorDpRenderResultados`) eliminadas. Substituídas por chamadas às funções compartilhadas do motor RH com `opts` parametrizados. Sem alteração de lógica ou comportamento — apenas fonte única de código. |
| `cfb4846` | Drawer de ciclo do RH (`#drawerDpCicloOverlay` + `#drawerDpCiclo`) convertido de right-side para modal centrado. Classes `drawer-overlay`/`drawer-versao` substituídas por `wiz-overlay wiz-overlay--center`/`wiz-container` (mesmo padrão do drawer gestor). Painel agora é filho do overlay. JS simplificado: `dpAbrirDrawerCiclo` e `dpFecharDrawerCiclo` toggleiam apenas o overlay. |
| `63c3a60` | Parâmetro `hideAvaliarWhenDone: true` adicionado a `dpRenderAvaliacoes`. Gestor passa `true` → botão Avaliar oculto para avaliações `concluida`/`publicada`. RH não passa (default `false`) → comportamento inalterado. Interface reflete corretamente as permissões sem duplicar lógica de renderização. |

## Redesign formulário de avaliação — layout compacto (commit 3d88bc0, 2026-10-15)

### Antes × depois

| Aspecto | Antes | Depois |
|---|---|---|
| Estrutura por critério | Card com borda, sombra, ícone decorativo, histórico como bloco separado | Linha compacta: num \| nome \| [i] \| [Sim][Não] \| obs \| chip histórico |
| Espaço vertical (10 critérios) | ~700px de conteúdo | ~440px — cabe na viewport sem scroll |
| Ícone decorativo | `.aval-card-icon` (30×30px, SVG) | Removido |
| Info block | Bloco abaixo do cabeçalho do card | Popup absoluto (`.aval-info-wrap { position:relative }`) |
| Histórico anterior | `<div class="aval-hist">` block com borda esquerda | Chip inline `border-radius:20px` à direita da obs |

### Mudanças CSS (classes afetadas)

| Classe | Mudança |
|---|---|
| `.aval-card` | `display:flex; align-items:center; gap:10px` — flex row, `padding:8px 16px`, sem border/shadow individual, `border-bottom` entre critérios |
| `.aval-card-header` | `display:none` |
| `.aval-card-icon` | `display:none` |
| `.aval-card-num` | `width:22px; text-align:right; flex-shrink:0` |
| `.aval-nome-info` (nova) | `flex:1; display:flex; align-items:center; gap:5px; overflow:hidden` — contém nome + info-wrap |
| `.aval-card-nome` | `white-space:nowrap; overflow:hidden; text-overflow:ellipsis` |
| `.aval-info-wrap` (nova) | `position:relative; flex-shrink:0` — âncora do popup |
| `.aval-info` | `position:absolute; z-index:200; left:0; top:calc(100%+4px); width:260px; box-shadow:…` — popup dropdown |
| `.aval-info-btn` | Reduzido para 17×17px |
| `.aval-row` | `display:contents` — botões e obs fluem diretamente no flex do `.aval-card` |
| `.aval-btn-bin` | `padding:5px 14px; font-size:12px` (era 7px 22px 13px) |
| `.aval-obs-input` | `height:28px; max-width:240px; font-size:11px` |
| `.aval-hist` | `display:inline-flex; border-radius:20px; padding:2px 8px` — chip inline com ícone SVG de relógio |
| Responsivo | `@media (max-width:600px)` — `flex-wrap:wrap`, obs e hist em `flex-basis:100%` |

### Mudança no template `dpRenderFormAvaliacao`

- Removido `<div class="aval-card-icon">${icon}</div>` e `<div class="aval-card-header">`
- Introduzido `.aval-nome-info` com `.aval-card-nome` + `.aval-info-wrap` (info-btn + popup inline)
- `histHtml` simplificado: ícone relógio SVG + label curto (nome do ciclo sem prefixo "Gratificação CD -") + valor em bold
- `modal-aval-header-info` substituído por `modal-aval-progress-label` com `display:flex; justify-content:space-between` — badge valor e contagem de progresso na mesma linha

### O que não mudou

Toda lógica JS preservada: `dpAvalBinario`, `dpAvalObsFocus/Blur`, `dpAvalRadioChange`, `dpToggleInfo`, `dpAtualizarProgressoAval`, `salvarAvaliacao`. IDs de inputs inalterados (`resp_${vc.id}`, `obs_${vc.id}`, `info_${vc.id}`). RH e Gestor usam o mesmo formulário via `dpRenderFormAvaliacao` — sem impacto.

---

## Estado atual — ciclos em produção (2026-10-15)

| Ciclo | Status | Avaliador | Participantes |
|---|---|---|---|
| Gratificação CD - Setembro/2026 | **aberto** | Oriel | 82 da equipe |
| Gratificação CD - Outubro/2026 | rascunho | Oriel | 88 (elegíveis) |

**Pendência:** validar fluxo completo com Oriel (abrir → Avaliar → salvar rascunho → concluir) sem criar avaliações reais durante os testes; outubro permanece em rascunho até aprovação.

---

## Fluxo de conclusão de avaliações (2026-10-16, commits 65ce27f + 7149edb)

### Separação Salvar × Concluir

| Ação | Onde | O que faz |
|---|---|---|
| **Salvar** | Footer do formulário | `salvarAvaliacao('em_andamento')` — salva respostas, mantém editável |
| **Concluir** (individual) | Botão por linha na lista (visível quando `st === 'em_andamento'`) | `dpConcluirAvaliacaoIndividual(participanteId)` — confirma + PATCH `status→concluida` |
| **Concluir equipe** (Gestor) | Botão no cabeçalho da aba Avaliações (só quando ciclo aberto) | `dpConcluirTodasAvaliacoes('gestor')` — bloqueado se pendentes; confirma; PATCH em lote |
| **Concluir todas** (RH) | Botão no cabeçalho da aba Avaliações (só quando ciclo aberto) | `dpConcluirTodasAvaliacoes('rh')` — mesma lógica, escopo ciclo inteiro |
| **Encerrar ciclo** | Sidebar (já existia via `dpEncerrarCicloSidebar`) | `dpMudarStatus('encerrado')` — ação exclusiva RH |

### Regra de bloqueio em "Concluir equipe/todas"

- **Pendente** = participante `nao_participa=false` E (sem avaliação OU `status='nao_iniciada'`)
- Se houver pendentes: modal informativo com lista de nomes — botão apenas "Entendido"
- Se nenhum pendente: confirmação → conclui todas `em_andamento` em lote
- Participantes com `status='concluida'` ou `nao_participa=true` são ignorados silenciosamente

### Avaliação concluída — modo leitura

- `dpAbrirFormAvaliacao` chama `dpAvalFormSetReadonly(true, concluida_em)` quando `aval.status ∈ ['concluida','publicada']`
- Todos os inputs desabilitados; footer substitui botão Salvar por banner verde "✓ Avaliação concluída em DD/MM/AAAA"
- `salvarAvaliacao()` recusa no topo se `_dpAvaliacaoAtual.status ∈ ['concluida','publicada']`

### Backend (migration 126)

- Trigger `trg_bloquear_resp_aval_concluida` em `dp_respostas` — BEFORE INSERT/UPDATE
- Trigger `trg_bloquear_reverter_conclusao` em `dp_avaliacoes` — BEFORE UPDATE
- Ambos lançam EXCEPTION — o front exibe o erro via `sbErrMsg()`

### Helpers novos

```js
dpConfirmDialog(titulo, corpo, btnLabel, somenteOk) → Promise<boolean>
dpAvalFormSetReadonly(readonly, concluida_em)
dpConcluirAvaliacaoIndividual(participanteId)
dpConcluirTodasAvaliacoes(escopo) // 'rh' | 'gestor'
dpLimparAvaliacao()
```

### Comportamentos do formulário (commit f72308a, 2026-10-16)

| Comportamento | Detalhe |
|---|---|
| **Salvar fecha o formulário** | `salvarAvaliacao('em_andamento')` chama `fecharFormAval()` ao final — retorna à lista após salvar |
| **Auto-save na navegação** | `dpNavForm(delta)` detecta mudanças via `_dpFormTemAlteracoes()`; se houver, chama `_dpSalvarParaNavegar()` antes de navegar; exibe toast "Salvo automaticamente ✓" em caso de sucesso |
| **Footer dinâmico** | `dpAvalFormSetReadonly(false)` injeta dois botões no `#formAvalFooter`: "Limpar avaliação" (vermelho sutil, esquerda) + "Salvar" (direita). `dpAvalFormSetReadonly(true)` substitui por banner verde "✓ Avaliação concluída em DD/MM/AAAA" |

### "Limpar avaliação" (commit f72308a, 2026-10-16)

Botão vermelho sutil no rodapé esquerdo do formulário — visível apenas quando avaliação está editável.

**Fluxo:**
1. `dpLimparAvaliacao()` verifica `_dpAvaliacaoAtual.status` — aborta com toast se concluída/publicada
2. `dpConfirmDialog('Limpar avaliação', …, 'Limpar')` — confirmação obrigatória
3. `sbDelete('/rest/v1/dp_respostas?avaliacao_id=eq.${avalId}')` — apaga todas as respostas
4. `sbPatch('/rest/v1/dp_avaliacoes?id=eq.${avalId}', { status: 'nao_iniciada', concluida_em: null })` — reverte status
5. Atualiza `_dpRespostasAtual = []`, `_dpAvaliacaoAtual.status` e `_dpAvaliacoes` em memória
6. Chama `dpRenderFormAvaliacao()` + `dpAvalFormSetReadonly(false)` — re-renderiza formulário vazio
7. Toast "Avaliação limpa." — formulário **permanece aberto** (não chama `fecharFormAval()`)

**Proteção de backend:** trigger `trg_bloquear_reverter_conclusao` (migration 126) impede que `status` seja revertido de `concluida`/`publicada` para outro valor via API direta. O front adiciona guard anterior, mas o banco é a proteção real.

---

## Status "Respondida" — implementação completa (2026-10-16, commits 6a9cdb6, fe1463d, 618fd69)

### Conceito

`respondida` = todos os critérios obrigatórios preenchidos, aguardando conclusão formal. Fica entre `em_andamento` e `concluida` no ENUM.

| Status | Significado |
|---|---|
| `nao_iniciada` | Avaliação não aberta |
| `em_andamento` | Aberta, ao menos 1 critério respondido, falta completar |
| `respondida` | Todos os critérios obrigatórios preenchidos — aguarda conclusão |
| `concluida` | Formalmente concluída pelo RH/gestor |
| `publicada` | Publicada para o colaborador |

### Auto-detecção em `salvarAvaliacao(status)`

Quando `status='em_andamento'`, antes do PATCH verifica:
```js
const totalCrits   = _dpVersaoCritsParaForm.length;
const respondidos  = _dpRespostasAtual.filter(r =>
  r.resposta_texto != null || r.escala_opcao_id != null || r.valor_numerico_livre != null
).length;
if (totalCrits > 0 && respondidos >= totalCrits) statusEfetivo = 'respondida';
```

### Auto-detecção em `_dpSalvarParaNavegar()`

Usa `payloads` (estado atual do formulário, não `_dpRespostasAtual` que é pré-form):
```js
const _statusNav = (_totalCritsNav > 0 && _respondidosNav >= _totalCritsNav) ? 'respondida' : 'em_andamento';
```

### Guards de conclusão

- **Frontend** (`dpConcluirAvaliacaoIndividual`): bloqueia se `aval.status !== 'respondida'` com toast
- **Backend** (`trg_validar_conclusao`): BEFORE UPDATE, conta critérios obrigatórios vs. respostas e lança EXCEPTION se incompleto
- `dpConcluirTodasAvaliacoes` inclui `respondida` no lote (além de `em_andamento`)

### Variáveis e constantes adicionadas

```js
const STATUS_LABEL = { nao_iniciada: '...', em_andamento: '...', respondida: 'Respondida', concluida: '...', publicada: '...' };
const STATUS_BADGE = { ..., respondida: 'purple', ... };  // sbadge-purple
const _dpAvatarColors = ['#1849A9','#0E7490','#6D28D9','...'];  // cores determinísticas por nome
const _dpAvatarColor  = n => { ... };  // hash do nome → cor
```

CSS: `.sbadge-purple { background: var(--purple-bg); color: var(--purple); }`

### Banner home (visão gestor)

`emAndamento` no banner inclui `respondida`:
```js
const emAndamento = avals.filter(a => a.status === 'em_andamento' || a.status === 'respondida').length;
```

---

## Redesign visual da aba Avaliações (2026-10-16, commits c4f13b0, 0684f76, 5e08f7a, f2698e1, e7d1dfb, 1a5fe90)

### Layout de cada linha

```
[avatar+dot] [flex:1 info] [120px badge] [valor bonus?] [120px botões justify-end]
```

Cada bloco é filho **direto** do flex row com tamanho fixo — garante alinhamento vertical independente do nome ou do número de botões.

### Avatar com foto e bolinha de status

```js
const _colab   = (_colaboradores||[]).find(c => String(c.id) === String(p.colaborador_id));
const _fotoUrl = _colab?.foto_url || null;
// fallback: iniciais com cor determinística via _dpAvatarColor(nome)
// bolinha de status: position:absolute, bottom:0, right:0, 11px, border:2px solid var(--surface)
```

Cores da bolinha por status:
| Status | Cor |
|---|---|
| `nao_iniciada` | `#9CA3AF` |
| `em_andamento` | `#F59E0B` |
| `respondida` | `#7C3AED` |
| `concluida` | `#10B981` |
| `publicada` | `#3B82F6` |

### Badge de status — sempre visível

Badge exibido para **todos** os status (antes só aparecia para `concluida`/`publicada`). Usa `.sbadge-dot` para o ponto colorido inline. Container com `width:120px` garante a coluna alinhada.

### Botões ícone-only (30×30px)

| Ação | SVG | Visível quando | Tooltip |
|---|---|---|---|
| **Avaliar** | Clipboard com linhas | `!concluido` | "Avaliar" |
| **Visualizar** | Olho | `concluido` | "Visualizar avaliação" |
| **Concluir** | Check-circle verde (`#10B981`) | `respondida` + ciclo aberto | "Concluir avaliação" |
| **Editar RH** | Lápis | `concluida` + perfil rh/admin | "Editar avaliação (RH)" |
| **Não participa** | ⊘ | `!concluido` + `_podeMarcarNP` | "Marcar como não participante" |

Estilo base (`_ib`): `display:inline-flex; align-items:center; justify-content:center; width:30px; height:30px; border:1px solid var(--border); border-radius:6px; background:transparent; cursor:pointer; color:var(--text-sec); transition:background .15s`

"Concluir" usa `border-color:#10B981; color:#10B981` para destaque discreto sem ser chamativo.

### KPI cards — fundos preenchidos

4 cards (Não iniciada / Em andamento / Respondida / Concluída) com:
- Fundo sempre colorido (`bgOff` = cor suave quando inativo, `bgOn` = mais saturado quando ativo)
- Borda `ring` colorida + `box-shadow` quando filtro ativo
- Grid `repeat(4, 1fr)` fixo

### Barra de progresso

Conta `respondida + concluida` (não só `concluida`):
```js
const respondidas = (counts.respondida || 0) + counts.concluida;
const pct = total > 0 ? Math.round((respondidas / total) * 100) : 0;
// texto: "X respondidas · Y%"
```

Valor monetário (`valorStr`) aparece à direita da barra quando `valorBonus != null` — calculado via `_dpSomaBonus` sobre `dp_resultados_bonus`.

---

## Unificação da tela de Ciclos RH × Gestor (commits c546268, 079e417, f9e5017 — 2026-10-23)

### `dpRenderCiclosUnificado(ciclosInput, opts)` — função compartilhada

Substitui `gestorDpRenderCiclos` (40+ linhas com estrutura distinta). RH e Gestor chamam a mesma função; diferenças controladas por `opts`:

| opt | RH | Gestor |
|---|---|---|
| `containerId` | `'ciclosList'` | `'gestorDpBody'` |
| `sidebarId` | `'cicloSidebarStats'` | `'gestorDpSidebarStats'` |
| `onClickCiclo` | `dpAbrirDrawerCiclo` | `gestorDpAbrirDrawer` |
| `showRascunhos` | `true` | `false` |
| `showAnteriores` | `true` | `false` |
| `showBtnEncerrar` | `true` | `false` |
| `showBtnAbrir` | `true` | `false` |

### Estrutura da sidebar do Gestor (`sec-gestor-dp`)

Adicionado `<div class="content-area">` com `.list-col` + `.sidebar-col` — mesma estrutura do RH. Sidebar renderiza contadores, progresso e dots via as mesmas queries (`dp_avaliacoes` + `dp_ciclo_participantes`), filtradas pelo RLS do Supabase ao perfil do Gestor.

### Onclick em HTML dinâmico

`window._dpCicloClickFn = onClickCiclo` no início da função; `onclick="_dpCicloClickFn('${id}')"` no HTML gerado. Evita serialização de arrow function como string.

### ID do cbannerFill

`id="cbannerFill_${containerId}"` e `id="cbannerPct_${containerId}"` para evitar colisão se ambas as views existirem no DOM simultaneamente.

### `_dpSidebarAvalCounts` restrito ao RH

Populado apenas quando `containerId === 'ciclosList'`. `dpEncerrarCicloSidebar` (RH-only) lê essa variável — o Gestor não a usa.

### Nome do modelo no Gestor

`loadDpModelos()` chamado dentro de `gestorDpLoadCiclos` via `Promise.all`, mas **somente se `_dpModelos.length === 0`** (sem requisição redundante se RH já carregou). Popula `_dpVersoes` para que `_dpCicloModeloNome` retorne o nome completo ("Avaliação Mensal Produtividade CD — V1").

### Banner de ciclo — visual e percentual (commits 079e417, f9e5017)

- **Visual:** fundo `#f0f5ff` com borda `#c7d9fb`, título `#1a3a6e`, barra `#2563EB`. Dark mode via `prefers-color-scheme`. Substituiu gradiente escuro anterior.
- **Percentual:** `<span class="ciclo-banner-pct" id="cbannerPct_${containerId}">` exibido à direita da barra, atualizado junto com o fill.
- **Base do cálculo:** `respondidas = avals onde status ∈ ['respondida','concluida','publicada']` ÷ total de participantes ativos. Em andamento e não iniciadas ficam fora do numerador — representam o que ainda falta responder.
