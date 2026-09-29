---
name: desenvolvimento
description: Especialista no módulo Desenvolvimento & Performance do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/desenvolvimento/index.html ou nas migrations dp_* do Supabase.
---

# Skill: Módulo Desenvolvimento & Performance — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil Acabamentos Ltda (varejo, Lucro Real).
Stack: HTML + CSS + JS puro, sem framework. Backend: Supabase REST API.
Arquivo principal: `C:\Users\reves\SistemaRH\modulos\desenvolvimento\index.html` (~2.070 linhas, tudo inline).
Migration do motor: `migrations/065_desenvolvimento_performance_v1.sql` (executada em 2026-09-29).

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo permanece inline no index.html.
2. **Nunca usar a chave secreta do Supabase no browser** — chave publicável apenas.
3. **Sempre apresentar proposta antes de implementar** — aguardar aprovação da usuária.
4. **Nunca abreviar valores** (`R$ 12.500,00`, não `12,5k`).
5. **`guardModulo('desenvolvimento')` obrigatório** — chamado na primeira linha de `initAuth()`; ver [[permissoes]].
6. **Não tocar nas abas legadas** (Colaboradores, Ciclos de Avaliação, Competências) — usam tabelas dev_* que ainda coexistem com as dp_*. Só alterar com aprovação explícita.
7. **Imutabilidade de versões e escalas publicadas é garantia do banco** — o front deve verificar `em_uso` e desabilitar campos, mas o trigger do banco é a proteção real. Tratar erros HTTP 4xx com mensagem clara ao usuário.
8. **Não misturar dados financeiros com valor_numerico da escala** — `valor_numerico` serve para cálculo/comparação; valores financeiros ficam em `dp_regras_financeiras`.
9. **verde/laranja/amarelo (melhorou/piorou/manteve/sem_comparacao) são calculados na camada de apresentação** — nunca armazenar no banco.
10. **Legibilidade mínima 11px** para qualquer texto informativo; usar tokens `--text-sec/#4B5565` e `--text-ter/#6C7589`.

---

## Arquitetura: Motor D&P V1

### Visão geral do fluxo

```
Biblioteca (dp_criterios, dp_escalas)
        ↓
Modelo (dp_modelos)
        ↓
Versão (dp_versoes) — define tipo_calculo, critérios, escalas, blocos
        ↓   [publicar: em_uso=true → imutável]
Ciclo (dp_ciclos) — referencia uma versão publicada
        ↓
Participantes (dp_ciclo_participantes) — snapshot do colaborador
        ↓
Avaliações (dp_avaliacoes) — por tipo_avaliador
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

**No front:** verificar `v.em_uso` e aplicar `disabled` nos campos. Tratar erro HTTP 4xx do banco com `toast('Mensagem do banco.', true)`.

### Regra de comparabilidade histórica

`dp_fn_historico_criterio` retorna `{comparavel: false}` quando não encontra avaliação anterior **do mesmo**:
- `modelo_id` — impede comparação cruzada entre modelos diferentes
- `criterio_id` — mesmo critério
- `escala_id` — mesma escala
- `tipo_resposta` — mesmo tipo de resposta
- status `publicada`

---

## Tabelas: Motor D&P (dp_*)

### `dp_criterios` — biblioteca de critérios
```
id UUID PK
nome TEXT NOT NULL
tipo dp_tipo_criterio ('tecnico'|'comportamental'|'resultado'|'outros')
area TEXT (nullable)
descricao TEXT
ativo BOOLEAN DEFAULT true
dev_competencias_id BIGINT (legado — referência à dev_competencias original)
criado_em TIMESTAMPTZ
```
- 39 critérios migrados de `dev_competencias` em 2026-09-29
- `tipo` em dev_competencias era 'tecnica' → migrado para 'tecnico'
- Não deletar esta tabela enquanto legado coexistir

### `dp_escalas` — escalas de resposta
```
id UUID PK
nome TEXT NOT NULL
descricao TEXT
ativo BOOLEAN DEFAULT true
criado_em TIMESTAMPTZ
```

### `dp_escala_opcoes` — opções de uma escala
```
id UUID PK
escala_id UUID REFERENCES dp_escalas ON DELETE CASCADE
label TEXT NOT NULL
valor_numerico NUMERIC (nullable — para cálculo/comparação, não financeiro)
ordem INTEGER NOT NULL DEFAULT 1
```
- Imutáveis quando a escala está em uso por versão publicada (trigger trg_eo_proteger_em_uso)

### `dp_modelos` — modelos de avaliação
```
id UUID PK
nome TEXT NOT NULL
descricao TEXT
tipo_avaliador dp_tipo_avaliador DEFAULT 'gestor_direto'
ativo BOOLEAN DEFAULT true
criado_por UUID REFERENCES auth.users
criado_em TIMESTAMPTZ
```

### `dp_versoes` — versões de um modelo
```
id UUID PK
modelo_id UUID REFERENCES dp_modelos
versao TEXT NOT NULL DEFAULT 'v1'     -- 'v1', 'v2', ...
em_uso BOOLEAN NOT NULL DEFAULT false  -- true = publicada, imutável
tipo_calculo dp_tipo_calculo NOT NULL DEFAULT 'soma'
tipo_avaliador dp_tipo_avaliador NOT NULL DEFAULT 'gestor_direto'
nota_maxima NUMERIC
converte_para_conceito BOOLEAN DEFAULT false
faixas_conceito JSONB    -- [{"min":0,"max":59,"conceito":"D"}, ...]
publicado_em TIMESTAMPTZ
publicado_por UUID REFERENCES auth.users
criado_em TIMESTAMPTZ
```

### `dp_versao_blocos` — blocos organizacionais de uma versão (opcional)
```
id UUID PK
versao_id UUID REFERENCES dp_versoes
nome TEXT NOT NULL
descricao TEXT
ordem INTEGER NOT NULL DEFAULT 1
```
- Bloqueado quando versao.em_uso = true (trigger trg_vb_proteger_em_uso)

### `dp_versao_criterios` — critérios configurados em uma versão
```
id UUID PK
versao_id UUID REFERENCES dp_versoes
criterio_id UUID REFERENCES dp_criterios
bloco_id UUID REFERENCES dp_versao_blocos (nullable)
tipo_resposta dp_tipo_resposta NOT NULL
escala_id UUID REFERENCES dp_escalas (nullable)
peso NUMERIC        -- usado quando tipo_calculo = 'media_ponderada'
obrigatorio BOOLEAN DEFAULT true    -- deve ser respondido antes de concluir
contribui_calculo BOOLEAN DEFAULT true  -- valor entra na fórmula
obs_obrigatoria BOOLEAN DEFAULT false
ordem INTEGER NOT NULL DEFAULT 1
UNIQUE(versao_id, criterio_id)
```
- **CHECKs no banco:**
  - `qualitativo_nao_calcula`: tipo_resposta IN ('texto','conceito') → contribui_calculo = false
  - `escala_obrigatoria`: tipo_resposta IN ('binario','escala') → escala_id IS NOT NULL
- Bloqueado quando versao.em_uso = true (trigger trg_vc_proteger_em_uso)

### `dp_ciclos` — ciclos de avaliação
```
id UUID PK
versao_id UUID REFERENCES dp_versoes    -- versão publicada
nome TEXT NOT NULL
status dp_status_ciclo DEFAULT 'rascunho'   -- 'rascunho'|'aberto'|'fechado'
tipo_avaliador dp_tipo_avaliador DEFAULT 'gestor_direto'
data_inicio DATE
data_fim DATE
aberto_por UUID
aberto_em TIMESTAMPTZ
encerrado_em TIMESTAMPTZ
criado_em TIMESTAMPTZ
```

### `dp_ciclo_participantes` — colaboradores num ciclo
```
id UUID PK
ciclo_id UUID REFERENCES dp_ciclos ON DELETE CASCADE
colaborador_id INTEGER REFERENCES colaboradores(id)   -- INTEGER, não UUID
snapshot JSONB NOT NULL    -- {nome, matricula, empresa, setor, cargo, unidade}
adicionado_em TIMESTAMPTZ
UNIQUE(ciclo_id, colaborador_id)
```
- **snapshot obrigatório:** `nome`, `matricula`, `empresa`, `setor`, `cargo`, `unidade`
- Capturado no momento de inclusão — preserva dados históricos mesmo após alterações no cadastro

### `dp_avaliacoes` — avaliação por tipo_avaliador
```
id UUID PK
ciclo_id UUID REFERENCES dp_ciclos
participante_id UUID REFERENCES dp_ciclo_participantes
tipo_avaliador dp_tipo_avaliador NOT NULL
avaliador_id UUID REFERENCES auth.users
status dp_status_avaliacao DEFAULT 'nao_iniciada'
    -- 'nao_iniciada'|'em_andamento'|'concluida'|'publicada'
iniciada_em TIMESTAMPTZ
concluida_em TIMESTAMPTZ
publicada_em TIMESTAMPTZ
publicada_por UUID
UNIQUE(ciclo_id, participante_id, tipo_avaliador)
```

### `dp_respostas` — resposta por critério
```
id UUID PK
avaliacao_id UUID REFERENCES dp_avaliacoes ON DELETE CASCADE
versao_criterio_id UUID REFERENCES dp_versao_criterios
escala_opcao_id UUID REFERENCES dp_escala_opcoes (nullable)
valor_numerico_livre NUMERIC     -- para tipo 'numerico'
meta NUMERIC                     -- para tipo 'numerico_com_meta'
realizado NUMERIC                -- para tipo 'numerico_com_meta'
conceito_selecionado TEXT        -- para tipo 'conceito'
resposta_texto TEXT              -- para tipo 'texto'
snapshot_opcao_label TEXT        -- populado automaticamente pelo trigger
snapshot_opcao_valor_num NUMERIC -- populado automaticamente pelo trigger
observacao TEXT
respondido_em TIMESTAMPTZ DEFAULT now()
UNIQUE(avaliacao_id, versao_criterio_id)
```
- O trigger `trg_resposta_snapshot` popula `snapshot_opcao_*` automaticamente no INSERT

### `dp_resultados` — resultado calculado de uma avaliação
```
id UUID PK
avaliacao_id UUID UNIQUE REFERENCES dp_avaliacoes
nota_final NUMERIC
conceito TEXT
calculado_em TIMESTAMPTZ
calculado_por UUID
CHECK(nota_final IS NOT NULL OR conceito IS NOT NULL)
```

### Camada financeira (criada mas não vinculada à UI ainda)
```
dp_regras_financeiras       -- tipo: 'percentual_salario'|'valor_fixo'|'por_criterio'
dp_regra_financeira_opcoes  -- escala_opcao → valor_financeiro
dp_regra_financeira_faixas  -- faixas de nota → valor/percentual
dp_resultados_financeiros   -- resultado calculado por regra
```

### `dp_historico_eventos` — auditoria
```
id UUID PK
tipo dp_evento_historico
entidade TEXT
entidade_id UUID
detalhe JSONB
usuario_id UUID
criado_em TIMESTAMPTZ
```

---

## ENUMs dp_*

| ENUM | Valores |
|---|---|
| `dp_tipo_criterio` | `tecnico`, `comportamental`, `resultado`, `outros` |
| `dp_tipo_resposta` | `binario`, `escala`, `numerico`, `numerico_com_meta`, `conceito`, `texto` |
| `dp_tipo_calculo` | `soma`, `media`, `media_ponderada`, `percentual_atingimento`, `qualitativo` |
| `dp_tipo_avaliador` | `gestor_direto`, `auto`, `gestor_e_auto`, `multiplo` |
| `dp_status_ciclo` | `rascunho`, `aberto`, `fechado` |
| `dp_status_avaliacao` | `nao_iniciada`, `em_andamento`, `concluida`, `publicada` |
| `dp_tipo_regra_financeira` | `percentual_salario`, `valor_fixo`, `por_criterio` |
| `dp_status_resultado_financeiro` | `calculado`, `ajustado`, `aprovado`, `pago` |
| `dp_evento_historico` | `ciclo_aberto`, `ciclo_fechado`, `avaliacao_publicada`, `resultado_calculado`, `resultado_ajustado` |

---

## Funções e triggers do banco

### `dp_validar_versao(p_versao_id UUID)` → JSONB
Valida uma versão antes da publicação. Chamar via RPC:
```js
const r = await fetch(SB_URL + '/rest/v1/rpc/dp_validar_versao', {
  method: 'POST', headers: HDR,
  body: JSON.stringify({ p_versao_id: versaoId })
});
const data = await r.json();
// data = { valido: true|false, erros: [{regra: '1', mensagem: '...'}] }
```

**5 regras validadas:**
| Regra | O que verifica |
|---|---|
| 1 | Versão não-qualitativa precisa de ao menos 1 critério com `contribui_calculo=true` |
| 2 | `converte_para_conceito=true` exige `faixas_conceito` preenchidas |
| 3 | Critérios calculáveis com escala precisam de `valor_numerico` nas opções |
| 4 | `media_ponderada` exige `peso > 0` em todos os critérios calculáveis |
| 5a | `percentual_atingimento` exige `tipo_resposta='numerico_com_meta'` em todos calculáveis |
| 5b | `qualitativo` proíbe `contribui_calculo=true` |

### `dp_fn_historico_criterio(...)` → JSONB
Retorna a última avaliação publicada do mesmo colaborador, mesmo modelo, mesmo critério, mesma escala, mesmo tipo_resposta.
```js
// Parâmetros:
// p_colaborador_id INTEGER, p_criterio_id UUID, p_ciclo_atual_id UUID,
// p_modelo_id UUID, p_escala_id UUID, p_tipo_resposta dp_tipo_resposta
// Retorno: { comparavel: true, ciclo_nome, escala_opcao_label, nota_final, ... }
//       ou { comparavel: false }
```

### Triggers de imutabilidade
- `trg_eo_proteger_em_uso` — BEFORE INSERT/UPDATE/DELETE ON dp_escala_opcoes
- `trg_e_proteger_delete` — BEFORE DELETE ON dp_escalas
- `trg_vc_proteger_em_uso` — BEFORE INSERT/UPDATE/DELETE ON dp_versao_criterios
- `trg_vb_proteger_em_uso` — BEFORE INSERT/UPDATE/DELETE ON dp_versao_blocos
- `trg_resposta_snapshot` — BEFORE INSERT ON dp_respostas (popula snapshot_opcao_*)

---

## Tabelas legadas (dev_*) — coexistem com dp_*

| Tabela | Status | Notas |
|---|---|---|
| `dev_competencias` | Mantida — base para dp_criterios | 39 registros, não deletar |
| `dev_ciclos` | Ativa nas abas legadas | Aguarda migração |
| `dev_avaliacoes` | Ativa nas abas legadas | notas_auto/gestor/rh em JSONB |
| `dev_pdi` | **Mantida para V2 PDI** | Não deletar |
| `dev_historico` | Ativa nas abas legadas | Timeline unificada |

**Não fazer DROP** de nenhuma tabela dev_* sem aprovação explícita da usuária.

---

## Estrutura do módulo (abas atuais)

| Aba | Tabelas | Status |
|---|---|---|
| Colaboradores | dev_ciclos, dev_avaliacoes, colaboradores | Legado — funcional |
| Ciclos de Avaliação | dev_ciclos | Legado — funcional |
| Competências | dev_competencias | Legado — funcional |
| **Modelos** | dp_modelos, dp_versoes, dp_versao_blocos, dp_versao_criterios, dp_criterios, dp_escalas | Novo — V1 |
| **Escalas** | dp_escalas, dp_escala_opcoes | Novo — V1 |

---

## Aba Modelos — detalhes de implementação

### Listagem
- Cards por modelo com versões aninhadas
- Badge por versão: Rascunho (cinza) | Publicada (verde, `em_uso=true`)
- Botões por versão:
  - Rascunho: "Configurar" (drawer) + "Publicar" (valida via RPC → PATCH em_uso=true)
  - Publicada: "Ver" (drawer readonly) + "Nova versão" (cria cópia rascunho)

### Drawer de configuração de versão (`drawerVersao`, 900px)
- **Tab Critérios:** accordion por bloco → tabela de critérios
  - Colunas: Nome | Tipo resposta | Escala | Peso | Obrigatório | Contribui cálculo | Obs. obrig. | Ordem | Remover
  - Todos desabilitados quando `em_uso=true` (`_dpVersaoReadonly`)
  - Regras de UI: tipo_resposta conceito/texto → `contribui_calculo` forçado false + escala hidden
- **Tab Configurações:** tipo_calculo, tipo_avaliador, nota_maxima, converte_para_conceito, faixas_conceito
- **Footer:** "Validar versão" (RPC) → resultado inline → "Publicar" só aparece após validação ok

### Variáveis de estado (Modelos)
```js
let _dpModelos      = [];   // dp_modelos
let _dpVersoes      = {};   // { modelo_id: [versao, ...] }
let _dpCriterios    = [];   // dp_criterios (biblioteca)
let _dpVersaoAtual  = null; // versão sendo configurada
let _dpVersaoCrits  = [];   // dp_versao_criterios da versão ativa
let _dpVersaoBlocos = [];   // dp_versao_blocos da versão ativa
let _dpVersaoReadonly = false; // true quando versão publicada
let _dpBlocoAlvoId  = null; // bloco selecionado no picker de critérios
```

---

## Aba Escalas — detalhes de implementação

### Listagem
- Cards com toggle inline de opções (label + valor_numerico)
- Badge "Em uso" (amber) quando referenciada por versão publicada
- Botão "Editar" → modal de criação/edição

### Modal de escala (`modalEscala`)
- Campos: nome, descrição
- Lista de opções editáveis (label + valor_numerico opcional)
- Ao salvar: DELETE bulk das opções antigas → INSERT das novas
- Se DELETE falhar (HTTP 4xx): banco bloqueou por imutabilidade → toast com mensagem clara

### Verificação de "em uso" na listagem
```js
// Carrega versões publicadas → busca escala_ids usadas → Set para lookup O(1)
const versoesPublicadas = Object.values(_dpVersoes).flat().filter(v => v.em_uso);
const escalaEmUso = new Set();
for (const v of versoesPublicadas) {
  const crits = await sbGet(`/rest/v1/dp_versao_criterios?versao_id=eq.${v.id}&select=escala_id`) || [];
  crits.forEach(c => { if (c.escala_id) escalaEmUso.add(c.escala_id); });
}
```

### Variáveis de estado (Escalas)
```js
let _dpEscalas       = [];   // dp_escalas
let _dpEscalaOpcoes  = {};   // { escala_id: [opcao, ...] }
let _escalaOpcoesTemp = [];  // opções em edição no modal
```

---

## Padrão de acesso ao Supabase

```js
const SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const SB_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'; // publishable key
const HDR = {
  apikey: SB_KEY,
  Authorization: `Bearer ${SB_KEY}`,
  'Content-Type': 'application/json',
  Prefer: 'return=representation'
};

async function sbGet(path)        { const r = await fetch(SB_URL+path,{headers:HDR}); return r.ok ? r.json() : []; }
async function sbPost(path,body)  { const r = await fetch(SB_URL+path,{method:'POST',  headers:HDR,body:JSON.stringify(body)}); return r.ok ? r.json() : null; }
async function sbPatch(path,body) { const r = await fetch(SB_URL+path,{method:'PATCH', headers:HDR,body:JSON.stringify(body)}); return r.ok ? r.json() : null; }
async function sbDelete(path)     { const r = await fetch(SB_URL+path,{method:'DELETE',headers:{...HDR,Prefer:'return=minimal'}}); return r.ok; }

// RPC (funções do banco):
// fetch(SB_URL + '/rest/v1/rpc/<nome>', { method:'POST', headers:HDR, body:JSON.stringify({param: valor}) })
```

---

## Padrão de design — tokens CSS

O módulo usa os mesmos tokens do sistema:

```css
--text:       #101828   /* texto principal */
--text-sec:   #4B5565   /* texto secundário — mínimo 11px */
--text-ter:   #6C7589   /* texto terciário / placeholder */
--border:     #E4E7EC
--border-light: #F2F4F7
--surface:    #ffffff
--bg:         #F0F2F5
--accent:     #101828
--green:      #12B76A  --green-bg:  #ECFDF3
--amber:      #F79009  --amber-bg:  #FFFAEB
--red:        #F04438  --red-bg:    #FEF3F2
--blue:       #2E90FA  --blue-bg:   #EFF8FF
--purple:     #7F56D9  --purple-bg: #F9F5FF
--radius:     12px
--shadow-sm:  0 1px 3px rgba(16,24,40,.08)
--shadow-md:  0 4px 8px rgba(16,24,40,.12)
--shadow-xl:  0 20px 60px rgba(16,24,40,.2)
```

**Classes reutilizáveis existentes no arquivo:**
- Botões: `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-sm`
- Badges: `.sbadge`, `.sbadge-green`, `.sbadge-amber`, `.sbadge-blue`, `.sbadge-red`, `.sbadge-gray`
- Tabela: `.proto-table`, `.proto-header`, `.proto-row`
- Modal: `.modal-overlay`, `.modal`, `.modal-lg`, `.modal-title`, `.form-group`, `.form-label`, `.form-input`, `.form-row`, `.modal-footer`
- Drawer: `.drawer-overlay`, `.drawer`, `.drawer-versao`, `.drawer-head`, `.drawer-tabs`, `.drawer-body`, `.drawer-footer`
- Feedback: `.loader`, `.spinner`, `.empty-state`, `.validacao-result`, `.validacao-ok`, `.validacao-err`
- Toast: `toast(msg, err=false)` — exibe notificação 3,2s

---

## Fluxo operacional planejado (próximas fases)

### Fase 2 — Ciclos com motor dp_* (não implementado)
```
Ciclo (dp_ciclos) referencia versão publicada
  → RH adiciona participantes (dp_ciclo_participantes com snapshot)
  → Sistema cria dp_avaliacoes por tipo_avaliador para cada participante
  → Gestor/avaliador responde (dp_respostas)
  → RH calcula e publica resultados (dp_resultados)
  → Histórico comparável via dp_fn_historico_criterio
```

### Fase 3 — Visão do gestor
```
"Meu ciclo" → lista quem precisa avaliar → preenche respostas → conclui
  → histórico anterior visível (última avaliação: Ago/2026)
  → NÃO pré-preenche respostas com dados anteriores
```

### Fase 4 — Camada de Análises (dashboard)
```
Painel por colaborador/equipe/setor/unidade
Matriz de respostas (colaborador × critério)
Evolução histórica com indicadores melhorou/piorou/manteve/sem_comparacao
  (calculados no front, nunca armazenados)
Filtros: setor, cargo, unidade, empresa, período, ciclo
Exportação
Dashboards por perfil (RH / Gestor / Diretoria)
```

### Fase 5 — PDI V2
- `dev_pdi` será migrado para tabela dp_pdi vinculada a dp_ciclo_participantes
- Preservar dados do dev_pdi durante a migração

---

## Compatibilidade: colaboradores.id

**`colaboradores.id` é INTEGER**, não UUID. Qualquer FK para colaboradores deve usar `INTEGER`:
```sql
colaborador_id INTEGER NOT NULL REFERENCES colaboradores(id)
```
Erro comum: declarar como UUID — o banco rejeita com "uuid and integer incompatible".

---

## Compatibilidade: dev_competencias

- `dev_competencias.id` é **BIGINT** (não UUID)
- `dev_competencias.tipo` usa 'tecnica' (feminino), enquanto `dp_tipo_criterio` usa 'tecnico'
- Mapeamento usado na migration: `WHEN 'tecnica' THEN 'tecnico'`, `WHEN 'comportamental' THEN 'comportamental'`
- Supabase UI trunca strings longas (ex: 'comportamental' aparecia como 'comportamenta') — sempre validar via `SELECT tipo, length(tipo)` ao depurar

---

## Migrations relacionadas

| Arquivo | Conteúdo | Status |
|---|---|---|
| `migrations/065_desenvolvimento_performance_v1.sql` | Motor D&P completo — ENUMs, tabelas dp_*, triggers, funções | Executado 2026-09-29 |
| `migrations/065b_dp_continuacao.sql` | Script intermediário (referência histórica do processo de execução) | Não executar novamente |

**Ao criar nova migration dp_*:** usar prefixo `066_dp_` e incrementar sequencialmente.

---

## Pendências abertas

| Item | Prioridade | Fase |
|---|---|---|
| Aba Ciclos com motor dp_* (dp_ciclos, participantes, avaliações) | Alta | 2 |
| Visão do gestor — "meu ciclo" | Alta | 3 |
| Cálculo de resultados (dp_resultados) | Alta | 2 |
| Camada de Análises / dashboard | Média | 4 |
| PDI V2 vinculado a dp_ciclo_participantes | Baixa | 5 |
| DROP das tabelas dev_ciclos, dev_avaliacoes, dev_historico | Baixa | pós-migração |
| Camada financeira (dp_regras_financeiras) — UI | Baixa | futuro |
| RLS (Row Level Security) nas tabelas dp_* | Alta | antes de abrir para gestor |
