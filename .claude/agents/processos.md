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

## Cache global `_PROC_MAP`

`_PROC_MAP` é um objeto `{ [id]: processoObj }` populado durante o carregamento dos cards.
Usado por `_executarConclusao`, `_renderFichaVT` e demais funções que precisam do objeto processo pelo id.

## Tipo `transferencia_cnpj`

Processo para registrar transferência de colaborador entre CNPJs do grupo.

### Campos extras (`dados_extras`)

| key | descrição |
|---|---|
| `empresa_origem` | preenchida automaticamente do `colaboradores.empresa_registro` ao selecionar o colaborador |
| `empresa_destino` | selecionada via `<select>` carregado de `param_empresa?ativo=eq.true` (excluindo origem) |
| `data_transferencia` | data da transferência (`<input type="date">`) |

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

Colaboradores transferidos de CNPJ têm `data_ingresso_grupo` preenchida manualmente (a data em que entraram no grupo, não na empresa atual). Esse campo é usado no relatório Tempo de Casa como referência prioritária sobre `data_admissao`.

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
