---
name: horasextras
description: Especialista no módulo Horas Extras do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/horasextras/index.html, nas migrations he_* do Supabase, ou no parser de PDF Senior CADCALC.
tools:
  - Glob
  - Grep
  - Read
  - Edit
  - Write
  - Bash
  - PowerShell
---

# Módulo Horas Extras — SistemaRH

## Arquivo principal
`modulos/horasextras/index.html` — ~1950 linhas, tudo inline (sem módulos externos além de pdfjs-dist CDN).

## Stack
- **PDF.js (pdfjs-dist 3.11.174)** via CDN: `https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js`
- **Supabase** via fetch direto (chave publicável + JWT do usuário em `SB_HEADERS`)
- **SheetJS** não utilizado neste módulo

## Variáveis globais de autenticação
```javascript
const SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const SB_KEY = 'sb_publishable_...';          // chave publicável — NUNCA usar como Bearer
let SB_HEADERS = { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}` }; // sobrescrito após login
```
Após login: `SB_HEADERS.Authorization = 'Bearer <JWT do usuário>'`. **Todo PATCH/POST deve usar `SB_HEADERS`**, nunca `SB_KEY` como Bearer isolado — isso faz `auth_perfil()` retornar null e o RLS bloqueia silenciosamente.

---

## Banco de dados (migrations 145–147)

### Tabelas
| Tabela | Descrição |
|---|---|
| `he_importacoes` | Cabeçalho de cada importação: competência, empresa, versão, arquivo, totais |
| `he_registros` | Um registro por colaborador por importação: percentuais JSONB, dsr, total, status_vinculo |
| `he_config` | Singleton (id=1), JSONB `dados` com `tipos_evento[]` configuráveis pelo RH |
| `he_eventos` | Eventos e ocorrências com abrangência global/empresa/setor, soft delete |

### Campo `percentuais` JSONB (he_registros)
```json
{
  "50": {"quant": 7.57, "valor": 95.66},
  "60": {"quant": 2.00, "valor": 38.24},
  "80": {"quant": 0,    "valor": 0},
  "85": {"quant": 0,    "valor": 0},
  "100": {"quant": 0,   "valor": 0}
}
```
As chaves são o percentual como string. Nunca fixas — lidas do próprio PDF. Grupo Revest usa 50/70/80/85/100%; Paranavaí e Porto Rico usam 50/60/80/85/100% (convenção sindical diferente).

### RPC `he_fn_importar` (migration 146)
Importação transacional: advisory lock por empresa+competência, versão sequencial, desativa importação anterior da mesma empresa+competência, insere registros em lote, atualiza `colaboradores.historico` em lote.

**Chave:** a desativação (`ativo=false`) é por `(competencia, param_empresa_id)` — empresas diferentes COEXISTEM na mesma competência. Reimportar a mesma empresa substitui apenas ela.

### Versionamento
- `he_importacoes.versao`: sequência por empresa+competência; v1 = primeira importação, v2 = reimportação
- `he_importacoes.ativo`: apenas a última versão é `ativo=true`

---

## Estado — variáveis globais
```javascript
let _paramEmpresas    = [];   // param_empresa ativas
let _allImportacoes   = [];   // he_importacoes ativo=true + empresa relacionada
let _allRegistros     = [];   // he_registros das importações ativas
let _colabsMap        = {};   // colaborador_id → { nome, cargo, matricula, empresa_registro }
let _dataLoaded       = false;
let _colabsForImport  = null;
let _importPreviewData = [];  // blocos parseados aguardando confirmação (somente 1 PDF por vez)
let _userName         = '';
let _userPerfil       = '';
let _allEventos       = [];   // he_eventos — RLS filtra por perfil automaticamente
let _heConfig         = null; // he_config.dados — carregado em loadData()
```

**Atenção:** `_MESES_PT` já está declarado na linha ~490 como objeto para o parser (mapa nome→número). Não redeclarar. Para nomes de meses por extenso usar `_MESES_NOMES` (array, linha ~1075).

---

## Abas do módulo
```
[ Painel ] [ Colaboradores ] [ Análise ] [ Eventos ] [ Importação ]
```
`showTab()` chama: `renderPainel()`, `renderColabs()`, `renderAnalise()`, `renderEventos()`, `initImportacao()`.

---

## Aba Eventos — Arquitetura completa (migration 147, Nov/2026)

### Tabela `he_eventos`
```sql
he_eventos (
  id uuid PK, titulo text, tipo text, data_inicio date, data_fim date,
  descricao text, abrangencia text CHECK IN ('global','empresa','setor'),
  empresa_id integer → param_empresa, setor text,
  criado_por text, criado_em timestamptz, inativado_em timestamptz,
  inativado_por text, ativo boolean DEFAULT true
)
```
Constraints: `data_fim >= data_inicio`; empresa_id obrigatório para empresa/setor; setor obrigatório para setor.

### RLS (migration 147)
| Perfil | Vê | Cria/Edita |
|---|---|---|
| rh / admin | todos (ativos + inativos) | ✓ |
| diretoria | todos os ativos | — |
| gestor | ativos globais + ativos de empresa/setor da sua equipe | — |

SRF `auth_gestor_equipe_ids()` deve ser usado como `= ANY(SELECT auth_gestor_equipe_ids())`, nunca `= ANY(auth_gestor_equipe_ids())` — SRF em WHERE de RLS gera `ERROR: 0A000`.

### he_config (singleton)
```sql
he_config (id=1, dados jsonb)
-- dados: { "tipos_evento": ["Campanha de vendas", "Balanço / inventário", ...] }
```
RLS: SELECT para todos autenticados; UPDATE apenas rh/admin. GRANT SELECT,INSERT,UPDATE para `authenticated`.

### loadData() — 4 itens em Promise.all
```javascript
const [emps, importacoes, eventos, cfg] = await Promise.all([
  sbGet('/rest/v1/param_empresa?...'),
  sbGet('/rest/v1/he_importacoes?...'),
  sbGet('/rest/v1/he_eventos?select=*,empresa:param_empresa(nome_simplificado)&order=data_inicio.desc'),
  sbGet('/rest/v1/he_config?id=eq.1&select=dados&limit=1')
]);
_allEventos = eventos || [];
_heConfig = cfg?.[0]?.dados || { tipos_evento: ['Campanha de vendas', ...] };
```

### Estrutura da aba Eventos
```
[ Header: título + "+ Novo Evento" ]
[ <div id="evFormArea"> ]           ← formulário abre aqui (posição: após header, antes filtros)
[ Filtros: tipo · abrangência ]
[ <div id="evListaAcordeon"> ]      ← acordeão ano → mês → cards
[ Card "Tipos de Evento" (recolhível) ]
```

### Acordeão ano → mês (renderEventosList)
- Eventos agrupados por `data_inicio` (mês de início) — sem duplicidade para multi-mês
- Todos os anos e meses recolhidos por padrão
- Ano atual recebe badge "Ano atual" (identificação visual, não expansão automática)
- Filtros (tipo, abrangência) atuam sobre todo o histórico — ativos e inativos
- Eventos inativos integrados no mesmo acordeão: borda tracejada + badge discreto de data de inativação
- Badge verde "● Em andamento" nos cards cujo período cobre a data de hoje
- IDs de accordion: `evano_${ano}_btn/chev/body`, `evmes_${ano}_${mes}_btn/chev/body`
- Funções: `toggleEvAno(key)`, `toggleEvMes(key)`

### Tipos de Evento (card recolhível)
- Card `ev-config-card` recolhido por padrão; cabeçalho clicável via `toggleEvTiposCard()`
- Ao expandir: chips com `×` hover-only + campo "+ Novo tipo" toggle via `toggleEvTiposInput()`
- `_renderTiposChips()` — atualização cirúrgica sem re-render da aba
- `adicionarTipoEvento()` — validação case-insensitive de duplicidade, rollback em caso de erro
- `removerTipoEvento(idx)` — rollback em caso de erro
- `_salvarHeConfig()` — retorna bool; usa `SB_HEADERS` + `Prefer: return=minimal`

### Integração com aba Análise
Chips de eventos aparecem acima dos gráficos para o período selecionado:
```javascript
const evsComp = _allEventos.filter(e => e.ativo && _eventoCobreComp(e, comp));
// _eventoCobreComp: data_inicio <= last_day_of_comp AND data_fim >= first_day_of_comp
```
Checkbox "Exibir eventos e ocorrências" com estado em localStorage(`he_exibir_eventos`).

### Integração com aba Painel
Linha de contexto no rodapé do período:
```javascript
const evsPainel = _allEventos.filter(e => e.ativo && _eventoCobreComp(e, comp));
// Exibe badges com títulos dos eventos se evsPainel.length > 0
```

### Funções principais
| Função | Descrição |
|---|---|
| `renderEventos()` | Render completo da aba; chama `renderEventosList()` |
| `renderEventosList()` | Constrói acordeão ano→mês com `_allEventos` filtrado |
| `abrirFormEvento(id)` | Abre formulário no `evFormArea`; `id=null` → novo, `id=uuid` → editar |
| `fecharFormEvento()` | Limpa `evFormArea` |
| `salvarEvento()` | POST (novo) ou PATCH (editar); atualiza `_allEventos` em memória |
| `inativarEvento(id)` | PATCH `ativo=false` + `inativado_em/por` |
| `reativarEvento(id)` | PATCH `ativo=true` + `inativado_em/por=null` |
| `toggleEvAno(key)` | Expande/recolhe bloco de ano |
| `toggleEvMes(key)` | Expande/recolhe bloco de mês |
| `toggleEvTiposCard()` | Expande/recolhe card de Tipos de Evento |
| `_evCardHtml(ev,canEdit,hoje)` | HTML de um card de evento; recebe `hoje` para badge "Em andamento" |
| `_eventoCobreComp(ev,comp)` | Retorna true se evento cobre a competência YYYY-MM |
| `_evAbrangBadge(ev)` | Badge de abrangência (Global/Empresa/Setor) |
| `_fmtDateRange(ini,fim)` | Formata dd/mm/aaaa ou dd/mm/aaaa até dd/mm/aaaa |

---

## Parser PDF — `_parsePDFPages`

### Formato do PDF Senior CADCALC (PIVOT)
- **Colaboradores = COLUNAS** (eixo x), tipos HE = LINHAS (eixo y)
- Linha "Trabalhador" é o **cabeçalho de colunas** (primeira linha da tabela)
- Dados processados linha a linha, ordenados por y crescente
- `LABEL_X_MAX = 90`, `EMP_X_MIN = 90`
- `VALUE_X_MIN_DYN = min(90, cols[0].x − ceil(colSpacing×1.5))` — captura valores numericamente largos
- `colIdxForX`: zona por ponto médio entre colunas adjacentes

### Estrutura Grupo Revest (formato A)
Label e valores de quant na mesma linha; "Valor" chega depois:
```
"HExt"       → pendingLabelParts
"50%"  [q…]  → TYPE_RESOLVE: detecta tipo, aplica bufferedQuant, expectQuant=true
"Valor" [v…] → expectQuant=false, aplica como valor
```

### Estrutura Paranavaí / Porto Rico (formato B — 50% e 60%)
Quant chega **antes** do label do tipo:
```
[q…] "Quant"   → bufferedQuant (Fix C: bufferiza, não aplica — tipo ainda desconhecido)
"HExt"         → pendingLabelParts
"50%"          → TYPE_RESOLVE: detecta tipo, descarrega bufferedQuant como quant
[v…] "Valor"   → aplica como valor
```
Para 80%, 85%, 100% em Paranavaí: mesmo formato A.

### TOTAL EXTRA em Paranavaí
Label inclui CNPJ antes do texto: `"07.666.823/0004-42 TOTAL EXTRA Quant"`
- **Fix D**: regex `/\btotal\b/i` (não `/^\s*total/i`) detecta "TOTAL" em qualquer posição do label

---

## State machine — variáveis
```javascript
let pendingLabelParts = [];    // partes do label do tipo ainda não resolvidas
let currentType  = null;       // tipo atual: '50', '60', '70', '80', '85', '100', 'dsr', 'pdf_total'
let expectQuant  = false;      // próximos valores são quant (não valor)
let bufferedQuant = [];        // valores de quant bufferizados enquanto tipo desconhecido
let bufferedLabelValor = [];   // valores de valor bufferizados junto com label parcial
```

## Regras do state machine

### Fix C — Quant antes do label
Só aplica imediatamente se o tipo foi resolvido AGORA via `pendingLabelParts`. Se `currentType` já vinha de bloco anterior sem pending recém-resolvido: **sempre bufferiza**.
```javascript
const hadPending = pendingLabelParts.length > 0;
if (hadPending) { currentType = detectType(...); pendingLabelParts = []; }
if (currentType && hadPending) { expectQuant = true; }
else { bufferedQuant = [...valueItems]; bufferedLabelValor = []; skipApply = true; }
```

### Fix D — TOTAL EXTRA com CNPJ
Ambos os handlers de Quant (nV≥3 e nV<3) usam `/\btotal\b/i`:
```javascript
} else if (/quant/i.test(labelStr) && !/\btotal\b/i.test(labelStr)) {
```

---

## Fluxo de importação
1. Usuário arrasta PDF na aba Importação
2. `parsePDFSource(file)` → `_parsePDFPages()` → retorna array de blocos por empresa
3. Preview exibido em `_importPreviewData` (sobrescreve o anterior — 1 PDF por vez)
4. Usuário confirma → `confirmarImportacao()` → `he_fn_importar` RPC por empresa
5. Empresas diferentes do mesmo PDF confirmadas juntas; reimportação substitui apenas empresa+competência

## Vinculação colaborador
- Matching: `empresa_registro === pe.nome_simplificado && matricula === String(parseInt(mat, 10))`
- Status: `vinculado` (ativo), `inativo` (desligado), `nao_encontrado`, `ambiguo`

---

## Resultados de validação
| Relatório | Empresa | Resultado |
|---|---|---|
| Grupo Revest | 0148 | 147/147 ✓ |
| Paranavaí + Porto Rico | 4148 + 5148 | 24/24 ✓ (Fix C + Fix D) |

Percentuais Grupo Revest: 50/70/80/85/100%
Percentuais Paranavaí/Porto Rico: 50/60/80/85/100% (convenção sindical diferente — 60% em vez de 70%)

---

## CSS — classes de Eventos
```
.ev-card, .ev-card:hover, .ev-card.inativo (borda tracejada, opacity 0.75)
.ev-badge-inativo, .ev-badge-hoje (badges discretos de status)
.ev-ano-group, .ev-ano-btn, .ev-ano-chevron, .ev-ano-label, .ev-ano-count, .ev-ano-badge-atual
.ev-mes-group, .ev-mes-btn, .ev-mes-chevron, .ev-mes-label, .ev-mes-count
.ev-config-card (recolhível), .ev-config-header (clicável), .ev-config-body, .ev-config-actions
.ev-tipos-chips, .ev-tipo-chip (× hover-only)
.ev-form-panel, .ev-form-row, .ev-form-group
.ev-abrang-badge, .ev-abrang-global, .ev-abrang-empresa, .ev-abrang-setor
.ev-chip, .ev-chip-tipo, .ev-chip-titulo (chips na aba Análise)
```

## Pitfalls conhecidos
- `_MESES_PT` já existe como objeto na linha ~490 (parser). Para nomes de meses usar `_MESES_NOMES` (array).
- Writes sempre via `SB_HEADERS` (contém JWT); usar `SB_KEY` como Bearer faz RLS bloquear silenciosamente.
- SRF `auth_gestor_equipe_ids()` em RLS: `= ANY(SELECT fn())`, nunca `= ANY(fn())`.
