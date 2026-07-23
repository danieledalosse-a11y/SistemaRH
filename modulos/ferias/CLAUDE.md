# Módulo Férias — Instruções para o Claude

## O que faz

Controle completo de férias: lista anual por colaborador, calendário mensal, lançamento de períodos,
aprovação pelo RH, alertas de risco de dobra e sem agendamento. Suporta múltiplos PAs por colaborador.

## Arquivo principal

`modulos/ferias/index.html` — autocontido (~3.200 linhas, CSS + JS inline).
`modulos/ferias/index.BACKUP.html` — backup anterior ao redesign CSS. Não editar.

## Fonte de dados: Supabase

- **URL:** `https://rujtbxwssiofiialnbbg.supabase.co`
- **Chave browser (publicável):** definida na constante `SUPABASE_KEY` no topo do script
- Helpers internos: `sbGet(tabela, params)` e `sbPatch(tabela, filtro, dados)`

### Tabelas usadas

#### `colaboradores`
Campos lidos: `id, matricula, nome, cargo, setor, empresa_registro, empresa_registro_nome,
empresa_atuacao, empresa_atuacao_nome, data_demissao`

- `ativo` = `!data_demissao`
- Matrículas podem se repetir entre empresas — identificação correta = matrícula + nome

#### `ferias`
Campos lidos: `id, colaborador_id, matricula_colaborador, ano, pa_inicio, pa_fim, status,
dias_antecipados, abono_pecuniario` + lançamentos embutidos (colunas `periodo*`)

- `pa_fim < pa_inicio` → erro de digitação de ano no cadastro
- `dias_antecipados` = dias emprestados do próximo PA para compor coletivas.
  **Importante:** fica registrado no PA de onde os dias foram retirados (o futuro), não no PA
  em que as coletivas aconteceram. Ex: coletivas em 2025 antecipando dias do PA 2026 →
  `dias_antecipados` vai no registro `ano=2026`.

---

## Modelo de dados em memória

### Globals principais

```js
let COLABORADORES   = [];     // Array de objetos colaborador (ver abaixo)
let ANO_REF         = 2026;   // Ano de referência selecionado pelo usuário
const HOJE          = new Date().toISOString().slice(0,10); // YYYY-MM-DD
```

Carregamento: `supabaseParaModelo(feriasRows, colaborRows)` — constrói COLABORADORES a partir
das duas tabelas do Supabase.

### Objeto colaborador

```js
{
  id: 'uuid',
  matricula: '421',
  nome: 'João Silva',
  cargo, setor,
  empresa: 'Revest Matriz',           // empresa_registro_nome
  empresaAtuacao: 'Revest CD',        // empresa_atuacao_nome
  ativo: true,                        // !data_demissao
  registros: [ /* PA[] ordenados ASC por ano */ ]
}
```

### Objeto PA (período aquisitivo)

```js
{
  id: 'uuid',
  ano: 2026,
  pa_inicio: '2025-03-10',
  pa_fim: '2026-03-09',
  totalDias: 30,
  diasAntecipados: 2,         // dias emprestados do próximo PA (reduz saldo)
  abonoPecuniario: 0,         // dias convertidos em abono (reduz saldo)
  status: 'aprovado',
  lancamentos: [ /* Lançamento[] */ ]
}
```

### Objeto lançamento

```js
{
  inicio: '2026-01-13',
  fim: '2026-01-26',
  dias: 14,
  motivo: null,
  nota: null
}
```

---

## Funções de negócio principais

### calcSaldo(reg)

```js
function calcSaldo(reg) {
  const usado = reg.lancamentos.reduce((s, l) => s + l.dias, 0);
  return reg.totalDias - usado - (reg.diasAntecipados || 0) - (reg.abonoPecuniario || 0);
}
```

### nivelRisco(diasDobra) — risco de dobra

| Retorno | Condição |
|---|---|
| `'critico'` | `diasDobra <= 30` |
| `'alto'` | `diasDobra <= 90` |
| `'atencao'` | `diasDobra <= 180` |

`diasDobra = diffDays(HOJE, dataLimiteDobra(reg))` — dias restantes até o limite de dobra.

### isSemAgendadoAno(colab, ano)

Retorna `true` se o colaborador não tem nenhum lançamento com início no ano `ano` e
o PA do ano tem saldo > 0. Usado pelo chip "Sem agendamento" na lista anual.

**Atenção:** filtrar por `Number(reg.ano) === ano` para não exibir PAs de outros anos.

---

## Regras de negócio CLT

- Mínimo 14 dias corridos por parcela principal
- Pode fracionar em até 3 parcelas (mínimo 5 dias cada parcela extra)
- Férias não podem começar nos 2 dias antes de feriado ou domingo
- **Risco de dobra:** PA vence (paFim) sem férias agendadas → empresa paga em dobro
- Limite de dobra = 12 meses após início do PA (`dataLimiteDobra`)

---

## Interface — navegação

### Abas principais (topbar)

| Aba | ID | Função |
|---|---|---|
| Visão RH | `sec-visao-rh` | `renderAll()` |
| Lançar | `sec-lancar` | `filtrarLancar()` |
| Minha Equipe | `sec-minha-equipe` | `renderMinhaEquipe()` |
| Histórico | `sec-historico` | `filtrarHistorico()` |

### Sub-abas de Visão RH (segmented toggle)

Implementadas como toggle colorido (não underline). Controladas por `_visTab`.

```js
let _visTab = 'lista-anual'; // ou 'calendario'
function setVisTab(nome) { ... }
```

- **Lista anual** (`#vt-lista`) → ativa em azul `#1570EF`
- **Calendário** (`#vt-cal`) → ativa em verde `#067647`

### Filtros independentes por sub-aba

Cada sub-aba tem seu próprio conjunto de filtros — mudanças em um não afetam o outro.

| Elemento | Lista anual | Calendário |
|---|---|---|
| Ativo/Inativo | `filtroAtivoLista` | `filtroAtivoCal` |
| Modo empresa | `filtroModoEmpresaLista` | `filtroModoEmpresaCal` |
| MultiSelect empresa | `msEmpresaLista` | `msEmpresaCal` |
| MultiSelect setor | `msSetorLista` | `msSetorCal` |

`getColabsVisao(contexto)` — lê os filtros corretos conforme `contexto` = `'lista-anual'` ou `'calendario'`.

### MultiSelect widget

Instâncias registradas em `MS_INSTANCES` (objeto global). Exemplo: `MS_INSTANCES['msEmpresaLista']`.
- `ms.getValues()` → array de valores selecionados
- `ms.setOptions(lista)` → redefine opções disponíveis

`atualizarOpcoesEmpresaMS(suffix)` — atualiza as opções de empresa do MS correto.
Se `suffix` omitido, atualiza Lista e Cal.

---

## Chips de status na lista anual

| Chip | ID | Critério |
|---|---|---|
| Todos | `sc-todos` | sem filtro |
| Em férias hoje | `sc-hoje` | `deFeriasNoPeriodo(c, HOJE)` |
| Sem agendamento | `sc-sem` | `isSemAgendadoAno(c, ANO_REF)` — filtra por `reg.ano === ANO_REF` |
| Risco de dobra | `sc-risco` | qualquer PA com `isRiscoDobra` |
| Aguard. aprovação | `sc-ok` | `status === 'pendente'` |

### Badges de risco (paBadge)

```
critico  → fundo sólido vermelho #D92D20, texto branco
alto     → fundo #FEF0E6, borda laranja, texto #C4500A
atencao  → fundo #FFFAEB, texto âmbar #B54708
```

Os estilos são **inline** no span — não dependem de classe CSS (que tinha background fixo sobrepondo).

---

## Drawer do colaborador

Painel lateral fixo à direita. Abre ao clicar em qualquer colaborador.
- `abrirDrawer(key)` / `fecharDrawer()`
- Abas internas: Resumo | Histórico | Lançar
- `imprimirHistoricoDrawer()` → preenche `#printArea` e chama `window.print()`

---

## Scripts de manutenção (Python + Supabase)

Localizados em `C:\Users\reves\AppData\Local\Temp\...scratchpad\` (temporários por sessão).
Usam a **chave secreta** do Supabase (nunca colocar no browser).

Scripts criados em sessões anteriores:
- `verificar_datas_pa.py` — varre ferias onde `pa_fim < pa_inicio` e corrige o ano
- `aplicar_antecipados_v3.py` — aplica `dias_antecipados` da planilha para o Supabase
  (match por matrícula + nome para evitar ambiguidade de matrículas duplicadas)

---

## Pendências conhecidas

- Módulo WhatsApp: envio de holerite/histórico via link `wa.me` (colunas whatsapp e valeGas já mapeadas no Supabase mas não exibidas)
- Aprovação em lote pelo RH
- Notificação automática de risco de dobra
- Alinhamento do critério de contagem do chip "Risco de dobra" vs. barra de resumo
  (chip conta colaboradores com qualquer PA em risco; barra conta PAs de ANO_REF específico)
