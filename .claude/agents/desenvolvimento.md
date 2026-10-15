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
| `dp_status_avaliacao` | `nao_iniciada`, `em_andamento`, `concluida`, `publicada` |
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
async function sbPatch(path,body) { ... }
async function sbDelete(path)     { ... }
async function sbRpc(fn, params={}) { ... }  // POST /rest/v1/rpc/<fn> — retorna null em erro, popula _sbLastError
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

// Resultados (Etapa 3)
let _dpResultados       // [{ id, avaliacao_id, nota_final, conceito, calculado_em }]
let _dpResultadosBonus  // [{ id, resultado_id, valor_bonus, snapshot_criterios, calculado_em }] — rh/admin/diretoria only

// Histórico por critério (Etapa 2 — formulário de avaliação)
let _dpHistoricoCriterios = {}  // { versao_criterio_id: JSONB retornado por dp_fn_historico_criterio }
```

## Funções novas — Etapas 2, 3, 5, 6

### Etapa 2 — Avaliação do Gestor
| Função | O que faz |
|---|---|
| `dpLoadAvaliacoes(cicloId)` | GET dp_avaliacoes; chama dpRenderAvaliacoes |
| `dpRenderAvaliacoes()` | Card por participante cruzando _dpAvaliacoes; badge por status |
| `dpAbrirFormAvaliacao(participanteId)` | Busca/cria dp_avaliacao; carrega critérios+respostas; busca histórico por critério via `sbRpc('dp_fn_historico_criterio',...)` em paralelo → `_dpHistoricoCriterios`; abre formAvalOverlay |
| `dpRenderFormAvaliacao()` | Bloco por critério com input adaptado ao `tipo_resposta` + bloco read-only de histórico abaixo de cada campo (ciclo anterior, valor/conceito, nota_final) |
| `salvarAvaliacao(status)` | Coleta resp_*; PATCH/POST dp_respostas; PATCH dp_avaliacoes; registra evento |
| `fecharFormAval()` | Fecha overlay; limpa estado |

**Histórico por critério no formulário:**
- Carregado em `dpAbrirFormAvaliacao` via `Promise.all` — uma chamada RPC por critério
- Requer `modelo_id` da versão (GET `dp_versoes?id=eq.${versaoId}&select=modelo_id`)
- `_dpHistoricoCriterios[vc.id]` → JSONB com campos acima; `null` = sem histórico (não exibido)
- `comparavel: false` → exibe "Sem avaliação anterior comparável" em itálico
- Critérios **binários**: exibe `resposta_texto` (Sim/Não) quando disponível; fallback `conceito_selecionado`
- Critérios **escala**: `escala_opcao_label (valor)` | **numérico**: `valor_numerico_livre` | **conceito**: `conceito_selecionado`

**Overlay:** `#formAvalOverlay` / `#formAvalPanel` — right-side drawer (`.wiz-overlay` pattern, largura 680px)
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
| `gestorDpLoadCiclos()` | GET `dp_ciclos?status=in.(aberto,em_andamento)` com joins; renderiza cards |
| `gestorDpRenderCiclos(ciclos)` | Renderiza lista de ciclos; clique → `gestorDpAbrirDrawer` |
| `gestorDpAbrirDrawer(cicloId)` | Busca dados completos do ciclo; pre-carrega participantes + avaliações; abre overlay |
| `gestorDpFecharDrawer()` | Fecha overlay; limpa `_gdpCicloAtual` e as 3 variáveis compartilhadas |
| `gestorDpShowTab(id, btn)` | Troca aba ativa no drawer |
| `gestorDpRenderParticipantes()` | Tabela read-only de `_gdpParticipantes` |
| `gestorDpRenderAvaliacoes()` | Cards por participante; botão Avaliar → `gestorDpAbrirFormAvaliacao` |
| `gestorDpAbrirFormAvaliacao(participanteId)` | **Usa spread** para não mutar cache: `_dpCicloAtual = { ..._gdpCicloAtual, tipo_avaliador_id: _gdpTipoGestorId }` ; chama `dpAbrirFormAvaliacao` do motor RH |
| `gestorDpLoadResultados()` | Filtra resultados por `tipo_avaliador_id === _gdpTipoGestorId` |
| `gestorDpRenderResultados()` | Exibe nota_final + conceito por participante |

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
