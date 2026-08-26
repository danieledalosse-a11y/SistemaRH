---
name: processos
description: Especialista no módulo de Processos do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/processos/index.html — workflows, checklists, ficha de encaminhamento VT, e integração com colaboradores/cadastro.
---

# Skill: Módulo Processos — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).

Arquivo principal:
- `C:\Users\reves\SistemaRH\modulos\processos\index.html` — painel interno de workflows e checklists

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo permanece inline no HTML.
2. **NUNCA usar a chave secreta do Supabase no browser** — apenas `SB_KEY` (publishable).
3. **Sempre apresentar proposta antes de implementar** — aguardar aprovação da usuária.
4. **Nunca abreviar valores** (`R$ 12.500,00`, não `12,5k`).

## Credenciais

```js
const SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const SB_KEY = 'sb_publishable_V4jUw9qvHjN9LvncGunqNQ_o_dj0RdH';
```

## Tabelas Supabase

### `processos_rh`
`id, tipo, status, colaborador_id, colaborador_nome, dados_extras (JSONB), criado_em`

- `status`: `'aberto'` | `'concluido'` | `'cancelado'`
- `dados_extras`: campo livre JSONB; usado para `operacao`, `convite_id`, dados de VT (`vt_cartao`, `vt_passes`, `vt_linha`)
- `colaborador_id` pode ser `null` quando criado na aprovação de admissão (antes do colaborador existir)

### `processos_checklist`
`id, processo_id, item (TEXT), concluido (BOOL), prazo_dias (INT), ordem (INT)`

## Tipos de processo (TIPO_CONFIG)

| tipo | label | cor | icon |
|---|---|---|---|
| `admissao` | Admissão | blue | 👤 |
| `vt_alteracao` | VT (dinâmico — ver abaixo) | dinâmico | 🚌 |
| outros tipos | conforme TIPO_CONFIG | — | — |

### Tipo `vt_alteracao` — label e cor dinâmicos

O label e a cor do card dependem de `dados_extras.operacao`:

```js
const _exOp = (p.dados_extras || {}).operacao;
cfg = {
  icon: '🚌',
  label: _exOp === 'exclusao' ? 'Exclusão de VT'
       : _exOp === 'alteracao' ? 'Alteração de VT'
       : 'Inclusão de VT',
  cor:   _exOp === 'exclusao' ? 'red'
       : _exOp === 'alteracao' ? 'purple'
       : 'green',
};
```

Isso se aplica em `buildCard`, `buildCardCancelado` e `phistAbrir`.

## CHECKLISTS — estrutura

O objeto `CHECKLISTS` tem tipos como chaves. Para `vt_alteracao`, a estrutura é aninhada por operação:

```js
const CHECKLISTS = {
  admissao: [ /* 17+ itens */ ],

  vt_alteracao: {
    inclusao: [
      { item: 'Solicitação registrada', prazo_dias: 0 },
      { item: 'Encaminhar solicitação ao Financeiro — inclusão de cartão VT', prazo_dias: 1 },
      { item: 'Confirmar carga/ativação do cartão pelo Financeiro', prazo_dias: 5, _acao_vt: true },
      { item: 'Comunicar colaborador que VT está ativo', prazo_dias: 5 },
    ],
    exclusao: [
      { item: 'Solicitação registrada', prazo_dias: 0 },
      { item: 'Encaminhar solicitação ao Financeiro — cancelamento de cartão VT', prazo_dias: 1 },
      { item: 'Confirmar cancelamento pelo Financeiro', prazo_dias: 5, _acao_vt: true },
    ],
    alteracao: [
      { item: 'Solicitação registrada', prazo_dias: 0 },
      { item: 'Encaminhar solicitação ao Financeiro — alteração de dados VT', prazo_dias: 1 },
      { item: 'Confirmar atualização pelo Financeiro', prazo_dias: 5, _acao_vt: true },
    ],
  },
};
```

### Como `criarProcesso` resolve o checklist

```js
let _chklSrc = CHECKLISTS[tipo];
if (tipo === 'vt_alteracao') {
  const op = dadosExtras?.operacao || 'inclusao';
  _chklSrc = _chklSrc?.[op] || [];
}
let itensBase = [...(_chklSrc || [])];
```

## Formulário de criação manual de VT

Usa radio buttons (não dropdown) para selecionar a operação:

```html
<label><input type="radio" name="xVtOperacao" value="inclusao" checked> Inclusão</label>
<label><input type="radio" name="xVtOperacao" value="exclusao"> Exclusão</label>
<label><input type="radio" name="xVtOperacao" value="alteracao"> Alteração</label>
```

A função `toggleCamposVTAlteracao()` exibe/oculta os campos específicos de cada operação:
- **Inclusão/Alteração**: cartão, quantidade de passes, linha
- **Alteração**: campos separados (`xVtCartaoAlt`, `xVtPassesAlt`, `xVtLinhaAlt`)
- **Exclusão**: sem campos adicionais

```js
function toggleCamposVTAlteracao() {
  const op = document.querySelector('input[name="xVtOperacao"]:checked')?.value;
  // exibe/oculta divs de campo conforme op
}
```

## Ficha de Encaminhamento VT

Exibida dentro do card expandido de processos `vt_alteracao`. Permite que o RH preencha, salve e imprima os dados de VT sem sair do módulo.

### Estrutura no DOM

```html
<div class="ficha-vt-wrap" id="fichaVT-wrap-${p.id}"></div>
```

Inserida na `.processo-row-detalhe` apenas para cards `vt_alteracao`.

### Carregamento lazy

`toggleRow(id)` chama `_renderFichaVT(id, fichaWrap)` apenas na primeira abertura do card, controlado por `fichaWrap._loaded`.

### Funções principais

#### `_renderFichaVT(procId, wrap)`
- Async; busca dados do colaborador via `colaboradores?id=eq.${p.colaborador_id}`
- Renderiza ficha colapsável com seções coloridas:
  - Cabeçalho: nome, cargo, setor, data de admissão
  - Dados do VT: cartão (text), passes (number), linha (text)
  - Botões: "Usar dados do cadastro", "×" limpar, "Imprimir"
- Campos são `<input>` editáveis; `oninput` dispara debounce de 800ms → `_salvarDadosVT`
- Exibe badge colorido da operação (verde/vermelho/roxo)

#### `_toggleFichaVT(procId)`
- Alterna visibilidade de `#fichaVT-body-${procId}`
- Rotaciona ícone chevron

#### `_salvarDadosVT(procId)`
- Debounced 800ms
- Lê valores dos inputs `#vtCartao-${procId}`, `#vtPasses-${procId}`, `#vtLinha-${procId}`
- PATCH em `processos_rh.dados_extras`:
  ```js
  { dados_extras: { ...proc.dados_extras, vt_cartao, vt_passes, vt_linha } }
  ```
- Atualiza `_PROC_MAP[procId].dados_extras` com os novos valores

#### `_usarDadosCadastroVT(procId)`
- GET `colaboradores?id=eq.${colaborador_id}&select=vt_cartao,vt_passes,vt_linha`
- Preenche inputs com os dados encontrados
- Chama `_salvarDadosVT(procId)` imediatamente (sem debounce)

#### `_imprimirFichaVT(procId)`
- Abre `window.open('')` com HTML estilizado para impressão
- Inclui: logo Revest, dados do colaborador, dados de VT, linhas para assinatura (RH + Financeiro)
- `window.print()` + `window.close()` automático

### Botão "×" (limpar campos)
Cada campo de VT tem um botão `×` que zera o input e dispara `_salvarDadosVT`.

## Conclusão de processo — `_executarConclusao`

Após PATCH `status='concluido'` bem-sucedido, verifica se deve sincronizar dados VT de volta ao cadastro:

```js
const _proc = _PROC_MAP[processoId];
if (
  _proc &&
  _proc.tipo === 'vt_alteracao' &&
  ['inclusao', 'alteracao'].includes(_proc.dados_extras?.operacao) &&
  _proc.colaborador_id
) {
  const _ex = _proc.dados_extras || {};
  const _vtPatch = {};
  if (_ex.vt_cartao != null) _vtPatch.vt_cartao = _ex.vt_cartao;
  if (_ex.vt_passes != null) _vtPatch.vt_passes = parseInt(_ex.vt_passes);
  if (_ex.vt_linha  != null) _vtPatch.vt_linha  = _ex.vt_linha;
  if (Object.keys(_vtPatch).length) {
    await fetch(`${SB_URL}/rest/v1/colaboradores?id=eq.${_proc.colaborador_id}`, {
      method: 'PATCH', headers: SB_HEADERS,
      body: JSON.stringify(_vtPatch)
    });
  }
}
```

**Regra:** só sincroniza em `inclusao` e `alteracao` (não em `exclusao`). Exclusão não altera dados VT no cadastro.

## Cache global `_PROC_MAP`

`_PROC_MAP` é um objeto `{ [id]: processoObj }` populado durante o carregamento dos cards.
Usado por `_executarConclusao`, `_renderFichaVT` e demais funções que precisam do objeto processo pelo id.

## Workflows automáticos disparados pelo módulo Cadastro

Os workflows abaixo são criados automaticamente pelo módulo Cadastro (`modulos/cadastro/index.html`) ao carregar, via funções chamadas em `carregarDoSupabase()`:

```js
verificarBonusIndicacao();
verificarExperienciaWorkflows();
```

### `verificarExperienciaWorkflows()`

Varre `COLABORADORES` em busca de colaboradores com `em_experiencia=true` e cria workflows quando o prazo está a **≤ 12 dias**:

| Workflow | tipo | Condição de disparo | Flag que impede duplicata |
|---|---|---|---|
| Avaliação 45 dias | `prorrogacao_experiencia` | `restantes45 >= 0 && <= 12` | `prorrogacao_45_gerado` |
| Avaliação final 90 dias | `avaliacao_final_experiencia` | `restantes90 >= 0 && <= 12` | `avaliacao_90_gerado` |

- Período do 1º prazo: `periodo_experiencia` (coluna da tabela) ou 45 dias como fallback
- Período do 2º prazo: `data_fim_experiencia` (coluna) ou `data_admissao + 90d` como fallback
- Após criar o processo, faz PATCH `prorrogacao_45_gerado=true` / `avaliacao_90_gerado=true` no colaborador

### `verificarBonusIndicacao()`

Cria workflow `bonus_indicacao` quando colaborador indicado completa **≤ 12 dias** antes dos 90 dias de casa:

- Condição de entrada: `indicado_por_id != null && indicacao_bonus_gerado == false && ativo == true`
- Após criar o processo, faz PATCH `indicacao_bonus_gerado=true`

### Armadilha crítica — escopo de variáveis

**Bug corrigido em 2026-08-26:** `SB_URL_CAD` e `headers` eram variáveis locais de outras funções (`_sincronizarProcessoDemissao`) e não existiam no escopo de `verificarExperienciaWorkflows` nem `verificarBonusIndicacao`. O `try/catch` engolia o `ReferenceError` silenciosamente e nenhum workflow era criado.

**Regra:** sempre que qualquer função de verificação precisar de `SB_URL_CAD` ou `headers`, deve declará-las no seu próprio escopo:

```js
async function verificarXxx() {
  try {
    const SB_URL_CAD = SB_URL;
    const headers = { ...SB_HEADERS, 'Content-Type': 'application/json' };
    // ...
  } catch(e) { console.error('Erro verificarXxx:', e); }
}
```

### Campo `em_experiencia` — manutenção

O campo `em_experiencia` deve ser `false` para colaboradores cujo período já encerrou. Colaboradores migrados vieram com `em_experiencia=true` sem data calculada.

Correção aplicada em 2026-08-26 via script Python (scratchpad): 152 colaboradores corrigidos para `false`, 15 permaneceram `true` (ainda dentro do período). Para futuras correções em massa, usar o script `corrigir_em_experiencia.py` que compara `data_fim_experiencia` (ou `data_admissao + periodo_experiencia`) com a data atual.

## Checklists de experiência — itens padrão

### `prorrogacao_experiencia` (Experiência — 45 dias)
1. `Avaliar colaborador {nome} — 1º período de experiência vence em {data}` *(gerado dinamicamente)*
2. `Obter parecer do gestor: prorrogar por mais 45 dias ou encerrar contrato`
3. `Enviar prorrogação de contrato ao escritório contábil`
4. `Registrar decisão no cadastro do colaborador`

### `avaliacao_final_experiencia` (Experiência — 90 dias)
1. `Avaliação final de {nome} — experiência vence em {data}` *(gerado dinamicamente)*
2. `Obter parecer do gestor: confirmar efetivação ou iniciar desligamento`
3. `Registrar decisão no cadastro do colaborador`

**Regra:** o item 3 dos 45 dias (envio ao escritório) **não existe** nos 90 dias — a continuidade para contrato por prazo indeterminado é automática.

## Cards de processo — informações exibidas no subtítulo

| Tipo | Subtítulo |
|---|---|
| `demissao` | `Prazo homologação: DD/MM/AAAA · N dias restantes` |
| `prorrogacao_experiencia` | `Vence em: DD/MM/AAAA · N dias restantes` |
| `avaliacao_final_experiencia` | `Vence em: DD/MM/AAAA · N dias restantes` |
| `bonus_indicacao` | `Indicado: {nome} · Folha de {mes}` |
| `atestado` | `CID: {cid} · {dias} dia(s)` |
| `vt_alteracao` | badge colorido com operação + dados do cartão |

### Prazo de homologação (demissão)

Função `_prazoHomologacao(dataDemissaoStr)`:
- Data da demissão + 9 dias corridos (= 10 dias contando o dia da demissão)
- Se o resultado cair em sábado, domingo ou feriado nacional fixo → antecipa para o dia útil anterior
- Feriados móveis (Carnaval, Sexta-feira Santa, Corpus Christi) **não são detectados** — verificar manualmente nesses casos

```js
const _FERIADOS_FIXOS = new Set([
  '01-01','04-21','05-01','09-07','10-12','11-02','11-15','11-20','12-25'
]);
function _prazoHomologacao(dataDemissaoStr) {
  const d = new Date(dataDemissaoStr + 'T00:00:00');
  d.setDate(d.getDate() + 9);
  while (d.getDay() === 0 || d.getDay() === 6 || _isFeriado(d)) {
    d.setDate(d.getDate() - 1);
  }
  return d;
}
```

O banner interno do card expandido usa a mesma função — prazo sempre consistente entre card e banner.

## Busca nos painéis

Todos os três painéis (Em andamento, Concluídos, Cancelados) têm campo de busca com botão **×** que aparece ao digitar e limpa o filtro com um clique.

## Integração com módulo Admissão

Processos do tipo `admissao` e `vt_alteracao` são criados automaticamente ao **Aprovar Ficha** no módulo admissão:

- Criados com `colaborador_id=null` e `dados_extras.convite_id=<id>`
- Após efetivação, o módulo admissão faz PATCH `colaborador_id` em todos os processos do mesmo `convite_id`

Ver skill `admissao` para o fluxo completo.

## Deploy

GitHub Pages — branch `main`:
`https://danieledalosse-a11y.github.io/SistemaRH`

Deploy automático após push (2–3 min).
