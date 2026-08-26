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

## Integração com módulo Admissão

Processos do tipo `admissao` e `vt_alteracao` são criados automaticamente ao **Aprovar Ficha** no módulo admissão:

- Criados com `colaborador_id=null` e `dados_extras.convite_id=<id>`
- Após efetivação, o módulo admissão faz PATCH `colaborador_id` em todos os processos do mesmo `convite_id`

Ver skill `admissao` para o fluxo completo.

## Deploy

GitHub Pages — branch `main`:
`https://danieledalosse-a11y.github.io/SistemaRH`

Deploy automático após push (2–3 min).
