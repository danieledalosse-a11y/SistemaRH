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
5. **`guardModulo('processos')` obrigatório** — primeira linha do bloco de auth; ver [[permissoes]].

## Credenciais

```js
const SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const SB_KEY = 'sb_publishable_V4jUw9qvHjN9LvncGunqNQ_o_dj0RdH';
```

## Tabelas Supabase

### `processos_rh`
`id, tipo, status, colaborador_id, colaborador_nome, dados_extras (JSONB), criado_em`

- `status`: `'aberto'` | `'concluido'` | `'cancelado'`
- `dados_extras`: campo livre JSONB; usado para `operacao`, `convite_id`, dados de VT (`vt_cartao`, `vt_passes`, `vt_linha`, `vt_viacao`), `mes_vigencia`
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
- **Inclusão**: cartão, passes, linha, viação, foto do cartão (opcional) — IDs: `xVtCartao`, `xVtPasses`, `xVtLinha`, `xVtViacao`, `xVtFotoCartao`
- **Alteração**: campos separados — IDs: `xVtCartaoAlt`, `xVtPassesAlt`, `xVtLinhaAlt`, `xVtViacaoAlt`
- **Exclusão**: apenas motivo (`xVtMotivo`)

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

### Query do colaborador (dentro de `_renderFichaVT`)

```js
colaboradores?id=eq.${colabId}&select=nome,setor,matricula,cpf,data_nascimento,empresa_registro,vt_cartao,vt_passes,vt_linha
```

**Não inclui** `cargo` nem `data_admissao` — intencionalmente removidos da ficha VT.

### Seção "Dados do Colaborador" — campos exibidos

| Campo | Origem | Editável? |
|---|---|---|
| Colaborador | `proc.colaborador_nome` | Não |
| Matrícula | `colab.matricula` | Não |
| CPF | `colab.cpf` (formatado `000.000.000-00`) | **Sim** — `_salvarCpfVT` |
| Data de Nascimento | `colab.data_nascimento` | Não |
| Setor | `colab.setor` sem prefixo numérico (`_stripNum`) | Não |
| Empresa / Unidade | `colab.empresa_registro` | Não |
| Mês de Vigência | `dados_extras.mes_vigencia` (default: próximo mês) | **Sim** — `_salvarVigenciaVT` |

### Seção "Dados do Vale Transporte" — campos

| Campo | ID DOM | dados_extras key |
|---|---|---|
| Nº Cartão VT | `fichaVT-cartao-${procId}` | `vt_cartao` |
| Passes / Dia | `fichaVT-passes-${procId}` | `vt_passes` |
| Linha de Ônibus | `fichaVT-linha-${procId}` | `vt_linha` |
| Viação | `fichaVT-viacao-${procId}` | `vt_viacao` |

### Seção "Foto do Cartão" (apenas inclusão/alteração)

Upload opcional de imagem do cartão VT. Fluxo em 2 etapas:
1. Selecionar arquivo → preview imediato com botões de rotação
2. Confirmar → upload para Storage + registro em `colaborador_documentos`

Estado por processo: `_vtFotoState[procId] = { b64, rotation }`

Após upload bem-sucedido, exibe miniatura + botões **Trocar** (re-abre seletor) e **Excluir** (remove do Storage e do banco com confirmação).

**Auth de Storage:** SEMPRE `Authorization: Bearer ${SB_KEY}` — nunca `SB_HEADERS.Authorization` (que usa o access_token do usuário).

### Funções principais

#### `_renderFichaVT(procId, wrap)`
- Async; busca colaborador e renderiza ficha colapsável com badge colorido por operação
- Cor: inclusão=verde, exclusão=vermelho, alteração=roxo

#### `_toggleFichaVT(procId)`
- Alterna visibilidade de `#fichaVT-body-${procId}` + rotaciona chevron

#### `_salvarDadosVT(procId)`
- Debounced 800ms
- Lê `fichaVT-cartao`, `fichaVT-passes`, `fichaVT-linha`, `fichaVT-viacao`
- PATCH em `processos_rh.dados_extras` com todos os campos VT

#### `_salvarVigenciaVT(procId, valor)`
- PATCH em `processos_rh.dados_extras.mes_vigencia` (formato `YYYY-MM`)
- Chamado no `onchange` do `<input type="month">`

#### `_salvarCpfVT(procId, input)`
- Chamado no `onblur` do campo CPF
- Valida 11 dígitos; PATCH em `colaboradores.cpf` (sem formatação — só dígitos)
- Fundo amarelo quando vazio, borda vermelha se inválido

#### `_usarDadosCadastroVT(procId)`
- GET `colaboradores?select=vt_cartao,vt_passes,vt_linha` (viação não está no cadastro)
- Preenche inputs e chama `_salvarDadosVT` imediatamente

#### `_imprimirFichaVT(procId)` — async
- Busca dados frescos do colaborador (query separada, não reutiliza DOM)
- Lê CPF e mês de vigência dos inputs atuais (para pegar edições não salvas)
- HTML próprio de impressão: grid 2×2 para dados VT (cartão, passes, linha, viação)
- Mês de vigência exibido por extenso: `Outubro / 2026`
- Assinaturas: "Solicitado por (RH)" + "Recebido por (Financeiro)"

#### `_renderSucessoFotoVT(procId, url)`
- Renderiza miniatura + link + botões Trocar e Excluir após upload

#### `_excluirFotoVT(procId, url)`
- Confirm → DELETE Storage (`/storage/v1/object/colaborador-docs` com `{ prefixes: [path] }`) + DELETE `colaborador_documentos?url=eq.${url}`

#### Funções de rotação de foto
- `_rotateImageB64(b64, degrees)` — canvas, retorna Promise\<base64\>
- `_selecionarFotoVT(procId, input)` — lê FileReader, inicia preview
- `_rotarFotoVT(procId, delta)` — aplica rotação acumulada, re-renderiza preview
- `_renderPreviewFotoVT(procId)` — renderiza preview com botões ↺ ↻ + Confirmar + ✕
- `_vtFotoSeletorHtml(procId)` — HTML do botão seletor inicial (reutilizado após cancelar/excluir)
- `_confirmarFotoVT(procId)` — converte base64 para Blob via `fetch(state.b64).blob()`, upload JPEG

### Botão "×" (limpar campos)
Cada campo de VT tem um botão `×` que zera o input e dispara `_salvarDadosVT`.

## Conclusão de processo — `_executarConclusao`

### Tipo `reajuste` — conclusão atômica via RPC

Quando `_proc.tipo === 'reajuste'`, a conclusão **não** faz PATCH direto em `processos_rh`. Em vez disso, chama a função PostgreSQL `fn_concluir_reajuste` que executa tudo atomicamente:

```js
// Salva justificativa se preenchida
if (justificativa) {
  await fetch(`${SB_URL}/rest/v1/processos_rh?id=eq.${processoId}`, {
    method: 'PATCH', headers: SB_HEADERS,
    body: JSON.stringify({ dados_extras: { ...(_proc.dados_extras || {}), justificativa } })
  });
}

// Chama RPC atômico
let rpcRes, rpcOk = false;
const rpcR = await fetch(`${SB_URL}/rest/v1/rpc/fn_concluir_reajuste`, {
  method: 'POST', headers: SB_HEADERS,
  body: JSON.stringify({ p_processo_id: processoId, p_usuario: _usuario })
});
// (JWT retry pattern idêntico ao resto do módulo)
if (rpcR.ok) { rpcRes = await rpcR.json(); rpcOk = rpcRes?.ok; }

// Toast diferenciado por vigência
if (rpcOk) {
  if (rpcRes.aplicado) {
    toast(`Reajuste concluído! Novo salário aplicado a partir de ${rpcRes.data_vigencia}`);
  } else {
    toast(`Reajuste registrado! O novo salário entrará em vigor em ${rpcRes.data_vigencia}`);
  }
  return; // early return — VT/transferência não é tocado
}
```

**Função `fn_concluir_reajuste` (migration 076)** — 7 etapas atômicas em PL/pgSQL:

| Etapa | O que faz |
|---|---|
| 1 | `SELECT ... FOR UPDATE` em `processos_rh` — evita conclusão simultânea |
| 2 | Extrai e valida `data_vigencia`, `salario_novo`, `cargo_novo` de `dados_extras` |
| 3 | `SELECT ... FOR UPDATE` em `colaboradores` — captura `salario_anterior` e `cargo_anterior` AGORA (não no momento da criação) |
| 4 | Verifica idempotência: se já existe em `historico_remuneracao`, pula INSERT |
| 5 | UPDATE `processos_rh` → `status='concluido'`, grava `percentual_real` e `salario_anterior` em `dados_extras` |
| 6 | INSERT em `historico_remuneracao` (`ON CONFLICT DO NOTHING`) |
| 7 | Se `data_vigencia <= CURRENT_DATE`: UPDATE `colaboradores.salario/cargo` + dois eventos JSONB em `colaboradores.historico` |

Retorna `{ ok, aplicado, data_vigencia, salario_novo, percentual }` ou `{ ok: false, erro }`.

**BUG CONHECIDO (corrigido out/2026):** linha original `salario = v_salario_novo::TEXT` causava erro `column "salario" is of type numeric but expression is of type text`. Fix: `salario = v_salario_novo` (sem cast — `v_salario_novo` já é `NUMERIC(12,2)`). A migration 076 no repositório **não reflete este fix** — o SQL correto foi executado manualmente via `CREATE OR REPLACE FUNCTION` no Supabase Dashboard. Se recriar a função, usar `salario = v_salario_novo` (sem `::TEXT`).

**Idempotência:** `UNIQUE (colaborador_id, processo_id)` + `FOR UPDATE` previnem duplicatas mesmo se "Concluir" for clicado duas vezes. Processo já concluído retorna `{ ok: true, aviso: 'Processo já estava concluído' }`.

### Tipo `vt_alteracao` — sincronização com cadastro

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
  // vt_viacao não tem coluna em colaboradores — fica só em dados_extras
  if (Object.keys(_vtPatch).length) {
    await fetch(`${SB_URL}/rest/v1/colaboradores?id=eq.${_proc.colaborador_id}`, {
      method: 'PATCH', headers: SB_HEADERS,
      body: JSON.stringify(_vtPatch)
    });
  }
}
```

**Regra:** só sincroniza em `inclusao` e `alteracao` (não em `exclusao`). Exclusão não altera dados VT no cadastro.

## Checklists — regras de prazo (out/2026)

### Demissão — prazos legais preservados

O checklist `demissao` mantém `prazo_dias` em todos os itens — prazos trabalhistas com validade legal.

### Todos os demais tipos — sem prazo

Tipos `reajuste`, `vt_avulso`, `vt_alteracao` (todos os subtipos), `prorrogacao_experiencia`, `avaliacao_final_experiencia`, `bonus_indicacao`, `atestado`, `transferencia_cnpj`: **`prazo_dias` removido** de todos os itens (out/2026).

**Motivo:** prazos arbitrários causavam alerta "Vencido" constante, gerando fadiga de alertas sem valor real. Somente obrigações legais têm prazo.

**Fix colateral (out/2026):** ao salvar checklist no banco, linha corrigida de `prazo_dias: it.prazo_dias ?? 0` para `prazo_dias: it.prazo_dias ?? null`. O `?? 0` fazia itens sem prazo serem gravados com `prazo_dias=0` (= prazo "hoje"), gerando alertas "Vencido" no próximo acesso.

### Checklist `reajuste` — itens atuais

```js
reajuste: [
  { item: 'Aprovação do gestor' },
  { item: 'Comunicar ao colaborador por escrito' },
  { item: 'Atualizar folha de pagamento' },
]
```

Item "Atualizar salário no sistema" **removido** (out/2026) — o sistema agora atualiza automaticamente via `fn_concluir_reajuste` ao concluir o processo.

## Cache global `_PROC_MAP`

`_PROC_MAP` é um objeto `{ [id]: processoObj }` populado durante o carregamento dos cards.
Usado por `_executarConclusao`, `_renderFichaVT` e demais funções que precisam do objeto processo pelo id.

## Formulário de Reajuste Salarial (out/2026)

Tipo `reajuste` no formulário de novo processo. Campos e IDs:

| ID DOM | Campo | Tipo | Observação |
|---|---|---|---|
| `xSalarioAtual` | Salário atual | `input readonly` | `data-raw` com valor numérico para cálculo |
| `xSalarioNovo` | Novo salário | `input text` | `oninput="_mascaraMonetaria(this);_calcPercentualReajuste()"` |
| `xPercentualReajuste` | Percentual | `input readonly` | Calculado em tempo real; aceita valor negativo (vermelho) |
| `xMotivoReajuste` | Motivo | `select` | Carregado de `param_motivo_reajuste` |
| `xDataVigencia` | Data de vigência | `input date` | — |
| `xNovaFuncao` | Nova função | `select` | Carregado de `param_cargo?ativo=eq.true&order=nome`; opção default "Nenhuma mudança de cargo" |
| `xObservacaoReajuste` | Observação | `textarea` | Opcional |

### Funções auxiliares

```js
// Máscara monetária — formata enquanto digita
function _mascaraMonetaria(el) {
  let raw = el.value.replace(/\D/g, '');
  if (!raw) { el.value = ''; return; }
  const num = parseInt(raw, 10) / 100;
  el.value = num.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
}

// Percentual calculado — lê data-raw do salário atual
function _calcPercentualReajuste() {
  const atual = parseFloat(document.getElementById('xSalarioAtual')?.dataset.raw) || 0;
  const novoRaw = (document.getElementById('xSalarioNovo')?.value || '').replace(/[^\d,]/g, '').replace(',', '.');
  const novo = parseFloat(novoRaw) || 0;
  const pctEl = document.getElementById('xPercentualReajuste');
  // exibe +/-X,XX% e colore conforme sinal
}

// Carrega param_motivo_reajuste (lazy, chamado no setTimeout ao abrir o form)
async function _carregarMotivosReajuste() { ... }

// Carrega param_cargo (lazy, chamado no mesmo setTimeout)
async function _carregarCargosReajuste() { ... }
```

O `setTimeout` que dispara ambas as cargas:
```js
setTimeout(() => { _carregarMotivosReajuste(); _carregarCargosReajuste(); }, 0);
```

### `dados_extras` salvo ao criar processo

```js
{
  salario_novo:      <number>,   // obrigatório
  data_vigencia:     'YYYY-MM-DD',
  percentual:        <number>,   // calculado
  motivo_codigo:     '0.x',
  motivo_descricao:  'Mérito',
  nova_funcao:       'Coordenador Comercial' | null,
  observacao:        'texto' | null,
}
```

### Exibição no card (painel Em andamento)

`Novo salário: R$ X.XXX,XX a partir de DD/MM/AAAA · +X,XX% · Motivo`
Percentual em verde (`#166534`) se positivo, vermelho (`#991b1b`) se negativo.

### Tabela `param_motivo_reajuste` (migration 074, out/2026)

```sql
CREATE TABLE param_motivo_reajuste (
  id SERIAL PRIMARY KEY, codigo TEXT NOT NULL, descricao TEXT NOT NULL,
  ordem INTEGER DEFAULT 0, ativo BOOLEAN DEFAULT true, criado_por TEXT,
  CONSTRAINT uq_pmr_codigo UNIQUE (codigo)
);
```
Registros padrão: Mérito (0.1), Promoção (0.2), Dissídio coletivo (0.3), Equiparação salarial (0.4), Acordo coletivo (0.5), Enquadramento (0.6).

> **Atenção:** o registro `codigo='dissidio_coletivo'` foi incluído na Mig 106 com `label='Reajuste integral'` (erro de cadastro). Deve ser corrigido para **"Dissídio coletivo"** no Parâmetros Gerais.

### Convenção do campo `percentual` em `historico_remuneracao` (definida out/2026)

**Inteiro percentual:** `6.0` representa 6%, **não** `0.06`.

- Ao inserir via script/API: usar o valor direto (ex: `6.0`, `2.5`)
- A tela (`ficha-render.js`) usa `pctNum.toFixed(2)` diretamente — sem multiplicar por 100
- Se a fonte (planilha, sistema externo) armazena como decimal (`0.06`): multiplicar por 100 antes de inserir
- Para piso salarial sem percentual informado: calcular `round((sal_nov/sal_ant - 1) * 100, 4)`

### Migração de massa em `historico_remuneracao` — boas práticas (Mig 106–107, out/2026)

- `motivo_descricao` deve ser preenchido com o label do `param_motivo_reajuste` correspondente ao `motivo_codigo` (a tela usa esse campo para exibição, com fallback para "Reajuste salarial")
- `observacao`: usar texto informativo da fonte quando existir; `NULL` quando vazio ou genérico (ex.: "Reajuste integral" é rótulo sem valor — descartar)
- Para demitidos **após** a data de vigência: inserir histórico normalmente, mas **não** atualizar `colaboradores.salario`
- Para colaboradores com múltiplos vínculos (inativo+ativo): usar o vínculo **ativo** para reajuste salarial
- **Idempotência obrigatória:** verificar existência de cada registro antes de inserir (por `colaborador_id + data_vigencia + motivo_codigo`). PATCH em `colaboradores` só executa se houve inserção nessa execução — nunca sobrescrever alteração posterior de outro processo
- **`historico_eventos` em migrações:** constraint `origem` aceita apenas `'sistema'` — nunca usar `'migracao'`
- **Mudança de setor causada por promoção:** incluir `setor_anterior`/`setor_novo` nos `dados` do evento `promocao`, sem criar `alteracao_setor` separado. `alteracao_setor` é para mudança sem promoção de cargo
- **Motivos carregados do banco:** não hardcodar labels de `param_motivo_reajuste` — carregar via query e usar snapshot no momento do registro (Mig 107: labels carregados de `param_motivo_reajuste?select=codigo,descricao,ativo`)

---

## Tipo `transferencia_cnpj`

Processo para registrar transferência de colaborador entre CNPJs do grupo.

### `tipo_transferencia` — parametrizado (Mig 102–103, out/2026)

O campo `tipo_transferencia` em `dados_extras` é carregado dinamicamente de `param_tipo_transferencia`:
- `'unidade'` → Transferência de unidade (altera só `empresa_atuacao`)
- `'cnpj'` → Alteração de CNPJ/contrato (altera `empresa_registro` + `empresa_atuacao`)

**Radios no formulário:** renderizados via fetch de `param_tipo_transferencia?ativo=eq.true&order=ordem`. A hint de descrição (`xTipoTransferenciaHint`) é atualizada a cada mudança de seleção.

**Validação obrigatória:** se nenhum radio selecionado, exibe toast de erro e bloqueia conclusão. Sem fallback hardcoded.

**Fallback somente para processos legados** (linha 2497 do HTML): `|| 'unidade'` aplicado apenas ao ler `dados_extras` de processos criados antes da parametrização — preserva comportamento retrocompatível, nunca afeta novos processos.

**Snapshot em `historico_eventos.dados`:** `fn_concluir_transferencia_cnpj` (Mig 103) busca o label de `param_tipo_transferencia` e grava `tipo_transferencia_label` no JSONB do evento. Histórico imune a renomeações futuras.

### Campos extras (`dados_extras`)

| key | descrição |
|---|---|
| `empresa_origem` | preenchida automaticamente do `colaboradores.empresa_registro` ao selecionar o colaborador |
| `empresa_destino` | selecionada via `<select>` carregado de `param_empresa?ativo=eq.true` (excluindo origem) |
| `data_transferencia` | data da transferência (`<input type="date">`) |
| `tipo_transferencia` | código do tipo: `'unidade'` ou `'cnpj'` — carregado de `param_tipo_transferencia` |

### Checklist padrão

```js
transferencia_cnpj: [
  { item: 'Registrar empresa de origem e empresa de destino', prazo_dias: 0 },
  { item: 'Atualizar empresa_registro e empresa_atuacao no Cadastro', prazo_dias: 1 },
  { item: 'Confirmar que data_ingresso_grupo está preservada (não sobrescrever)', prazo_dias: 1 },
  { item: 'Verificar histórico do colaborador — evento registrado', prazo_dias: 1 },
]
```

### Empresa de origem — auto-fill

Na busca de colaborador, a query inclui `empresa_registro`:
```
colaboradores?nome=ilike.*q*&ativo=eq.true&select=id,nome,cargo,salario,empresa_registro&limit=10
```

O valor é armazenado em `<input type="hidden" id="fColabEmpresa">` e usado em `atualizarCamposExtras()` para pré-preencher empresa de origem como campo readonly.

### Conclusão — `_executarConclusao`

Ao concluir, faz PATCH em `colaboradores`:
```js
{ empresa_registro: destino, empresa_atuacao: destino }
```
**Nunca altera `data_ingresso_grupo`** — esse campo é preenchido manualmente pelo RH no Cadastro e preservado em transferências.

### Relação com `data_ingresso_grupo`

Colaboradores transferidos de CNPJ têm `data_ingresso_grupo` preenchida manualmente (a data em que entraram no grupo, não na empresa atual).

**Regra global de tempo de casa (padronizada 2026-10-07):** `data_ingresso_grupo || data_admissao` é a data de referência para **todo cálculo e exibição de tempo de empresa** em qualquer tela. `data_admissao` é dado contratual do CNPJ atual — exibido separadamente como "Admissão", nunca substitui `data_ingresso_grupo` para tempo de casa.

Telas que aplicam essa regra:
- `modulos/relatorios/index.html` — Relatório Tempo de Casa (já estava correto)
- `modulos/cadastro/index.html` — coluna Admissão na lista e exportação CSV
- `modulos/colaborador/ficha-render.js` — campo "Admissão" e "Tempo de Casa" no cabeçalho da ficha; card Tempo de Casa e texto "desde X" no Resumo

A data contratual (`data_admissao`) permanece visível apenas no formulário de edição do Cadastro — não deve aparecer em nenhum campo de exibição de tempo de empresa.

**Validação de ano (2026-10-07):** `data_admissao` deve ter ano entre 1950 e 2099. Um ano fora desse intervalo causa `NaN anos` no cálculo de tempo de empresa e impede a abertura do drawer no Cadastro. A validação existe nos inputs HTML (`min`/`max`) e na lógica JS de `salvarFicha()` (cadastro) e `confirmarEfetivar()` (admissão).

Ao criar nova tela ou cálculo que envolva tempo de empresa, aplicar o mesmo padrão.

## Tipo `alteracao_setor` (Mig 105-B, out/2026)

Evento de carreira para **mudança de setor sem transferência de empresa nem promoção de cargo**. Distinto de `transferencia_cnpj` (mecanismo de empresa) e `promocao` (mudança de cargo).

- Criado em `tipos_evento` com `categoria='carreira'`, `icone_chave='briefcase'`
- **Quando usar:** colaborador muda de setor dentro da mesma empresa — ex.: "SDI Adm → Matriz Adm" (Ana Claudia, jul/2025)
- **Schema `dados`:** `setor_anterior`, `setor_anterior_label`, `setor_novo`, `setor_novo_label`
- **Snapshot pattern:** gravar `_label` além do código — proteção contra renomeação futura de `param_setor`
- **`resumo_template`:** `{setor_anterior_label} → {setor_novo_label}`

## Padrão snapshot em `historico_eventos.dados`

Sempre que um evento referencia um param table (setor, tipo_transferencia, etc.), gravar tanto o código estável quanto o label no momento do registro:

```json
{ "setor_anterior": "2584 - SDI Adm", "setor_anterior_label": "SDI Adm",
  "setor_novo": "Matriz Adm",         "setor_novo_label": "Matriz Adm" }
```

O histórico exibirá o label original mesmo se o param mudar de nome. Funções SQL como `fn_concluir_transferencia_cnpj` já implementam este padrão para `tipo_transferencia_label`.

---

## Automação central — Edge Function `verificar-workflows` (set/2026)

**Fonte única de verdade para todas as automações periódicas.** Roda via `pg_cron` todo dia às 07h (Brasília) / 10h UTC.

### Arquitetura

```
pg_cron → net.http_post → Edge Function verificar-workflows → Supabase (service_role)
```

- Edge Function: `supabase/functions/verificar-workflows/index.ts`
- Job: `verificar-workflows-diario`, schedule `0 10 * * *`, `active = true`
- A autenticação usa a `service_role_key` embutida diretamente no comando do cron job (armazenada em `cron.job.command`, acessível apenas a superusuários do banco)

### Rotinas da Edge Function

| Função | O que faz |
|---|---|
| `verificarBonusIndicacao()` | Cria `bonus_indicacao` para o **indicador** quando indicado ≥ 75 dias; janela até 30 dias após vencer |
| `verificarExperiencia()` | Cria `prorrogacao_experiencia` (≤ 12 dias para 45 dias) e `avaliacao_final_experiencia` (≤ 12 dias para 90 dias) |
| `limparExperienciaVencida()` | Atualiza `em_experiencia = false` em colaboradores com período já encerrado |

### `verificarBonusIndicacao()` — regra de negócio

- **Quem recebe o processo:** o **indicador** (quem fez a indicação), não o indicado
- Condição de entrada: `indicado_por_id IS NOT NULL AND indicacao_bonus_gerado = false AND ativo = true`
- Gatilho: `hoje >= data_admissao + 75 dias`
- Janela de segurança: também processa até 30 dias após os 90 dias
- Verifica que o indicador ainda está `ativo = true` antes de criar
- Verifica duplicata por `colaborador_id + dados_extras.indicado_id`
- Valor: buscado em `param_bonus_indicacao` pela data de admissão do indicado
- Após criar: marca `indicacao_bonus_gerado = true` no indicado
- `criado_por`: `'Sistema (automático)'`

### Histórico de correção (set/2026)

O job existia e estava `active=true`, mas usava `current_setting('app.service_role_key', true)` que nunca foi configurado no banco → cada execução chamava a Edge Function com header vazio → 401 silencioso → nenhum workflow gerado.

**Correção aplicada (28/09/2026):** job recriado com a `service_role_key` embutida diretamente no `net.http_post`. A Edge Function não foi alterada.

**Se o cron parar no futuro:** verificar no SQL Editor:
```sql
SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'verificar-workflows-diario';
```
Se não existir ou `active = false`, recriar com `cron.unschedule` + `cron.schedule` com a chave atual (Settings → API → service_role).

### Rotina duplicada no Cadastro — removida (29/09/2026)

`modulos/cadastro/index.html` tinha `verificarBonusIndicacao()` local (commit d409129). Essa versão criava o processo para o **indicado** em vez do indicador (incorreto) e não verificava duplicata. **Removida após validação do cron** — o cron `verificar-workflows-diario` está ativo e confirmado em execução diária (runid 34, 29/09/2026 10h UTC).

---

## Workflows automáticos disparados pelo módulo Cadastro

O módulo Cadastro (`modulos/cadastro/index.html`) dispara localmente via `carregarDoSupabase()` apenas:

```js
verificarExperienciaWorkflows();
// verificarBonusIndicacao() foi removida em 29/09/2026 (commit d409129)
// — automação de bônus centralizada no cron verificar-workflows-diario
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
4. `Arquivar documento assinado de prorrogação`

### `avaliacao_final_experiencia` (Experiência — 90 dias)
1. `Avaliação final de {nome} — experiência vence em {data}` *(gerado dinamicamente)*
2. `Obter parecer do gestor: confirmar efetivação ou iniciar desligamento`

**Regras:**
- Nos 45 dias, o escritório emite um documento que o gestor e colaborador assinam — por isso os itens 3 e 4.
- Nos 90 dias, a continuidade para contrato por prazo indeterminado é **automática em lei** (se não demitiu, virou indeterminado). Não há ação de sistema nem envio ao escritório — checklist intencional mente curto.

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

## Renovação automática de JWT (2026-09-09)

`_sbRefreshSession()` adicionada ao módulo — mesmo padrão do módulo Cadastro:

```js
async function _sbRefreshSession() {
  try {
    const sess = JSON.parse(localStorage.getItem('sb_session') || '{}');
    if (!sess.refresh_token) return false;
    const r = await fetch(`${SB_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: { apikey: SB_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: sess.refresh_token }),
    });
    if (!r.ok) return false;
    const data = await r.json();
    if (!data.access_token) return false;
    const newSess = { ...sess, access_token: data.access_token,
      refresh_token: data.refresh_token || sess.refresh_token,
      expires_at: Date.now() + (data.expires_in || 3600) * 1000 };
    localStorage.setItem('sb_session', JSON.stringify(newSess));
    SB_HEADERS = { ...SB_HEADERS, Authorization: `Bearer ${data.access_token}` };
    return true;
  } catch { return false; }
}
```

**Onde é usado:** `_executarConclusao` — ao PATCH `processos_rh`, se retornar JWT expired, chama `_sbRefreshSession()` e refaz a requisição. Evita que a usuária veja "Erro ao concluir processo: JWT expired" quando a sessão expira com o módulo aberto.

**Padrão a seguir em novas operações críticas:** qualquer fetch PATCH/POST de ação irreversível deve ter o mesmo padrão de retry — testa o texto da resposta por `JWT expired` ou `PGRST303`, chama `_sbRefreshSession()`, refaz se obteve `true`.
