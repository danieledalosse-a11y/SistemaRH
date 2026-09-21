---
name: uniformes
description: Especialista no módulo de Uniformes & EPI do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/uniformes/index.html ou modulos/uniformes/configuracoes.html.
---

# Skill: Módulo Uniformes & EPI — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).
Arquivos principais:
- `C:\Users\reves\SistemaRH\modulos\uniformes\index.html` — painel principal
- `C:\Users\reves\SistemaRH\modulos\uniformes\configuracoes.html` — configurações de itens/almoxarifados

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo inline no index.html.
2. **Nunca usar a chave secreta do Supabase no browser** — chave publicável apenas no index.html.
3. **Sempre apresentar proposta antes de implementar** — aguardar aprovação.
4. **`guardModulo('uniformes')` obrigatório** — primeira linha do bloco de auth; ver [[permissoes]].

## Tabelas Supabase (módulo uniformes)

### `unif_estoque`
Estoque por item + tamanho + almoxarifado.

Campos relevantes: `id, item_id, almoxarifado_id, tamanho, quantidade, estoque_minimo`

### `unif_movimentacoes`
Registro de entregas e devoluções vinculadas a colaboradores.

**Campos NOT NULL obrigatórios:**
`colaborador_id, item_id, almoxarifado_id, tamanho, tipo, motivo, quantidade, data_movimentacao, confirmado, registrado_por`

**CRÍTICO — ajuste de estoque NÃO usa `unif_movimentacoes`** (corrigido 2026-09-16):
A tabela exige `colaborador_id NOT NULL`, campo que não existe em ajustes manuais de balanço. O ajuste deve fazer apenas `sbPatch('unif_estoque', ...)` sem nenhum insert em `unif_movimentacoes`. Tentar inserir nessa tabela sem `colaborador_id` causa erro 400 (código Postgres `23502`).

```js
// CORRETO — ajuste de estoque:
await sbPatch('unif_estoque', `id=eq.${_ajusteEstoqueId}`, { quantidade: novaQtd });
// Sem sbPost em unif_movimentacoes — não aplicável para ajustes

// CORRETO — entrega/devolução (sempre tem colaborador):
await sbPost('unif_movimentacoes', {
  colaborador_id, item_id, almoxarifado_id, tamanho,
  tipo, motivo, quantidade, data_movimentacao, confirmado, registrado_por, obs
});
```

### `unif_itens`
Catálogo de itens de uniforme/EPI.

Campos relevantes: `id, nome, genero, variante, logo, categoria`

### `unif_almoxarifados`
Almoxarifados/locais de estoque.

## Ajuste de Estoque — arquitetura atual

`abrirAjusteEstoque(estoqueId, itemNome, tamanho, qtdAtual, itemId, almoxId)` — abre modal com os dados do item. Armazena em variáveis globais:

```js
let _ajusteEstoqueId  = null;  // id da row em unif_estoque
let _ajusteItemId     = null;  // item_id (para uso futuro)
let _ajusteAlmoxId    = null;  // almoxarifado_id (para uso futuro)
let _ajusteTamanho    = null;  // tamanho (para uso futuro)
```

`confirmarAjusteEstoque()` — valida quantidade ≥ 0, faz PATCH em `unif_estoque` e recarrega estoque. Sem insert em `unif_movimentacoes`.

## `_erroApi(e)` — códigos Postgres

| Código | Mensagem exibida |
|---|---|
| `23502` | "Preencha todos os campos obrigatórios antes de salvar." (NOT NULL violation) |
| `23503` | "Referência inválida — verifique os dados selecionados." (FK violation) |
| `23505` | "Registro duplicado — este item já existe." (unique violation) |
| `42501` | "Sem permissão para esta operação." |

Quando o erro não bate em nenhum código, retorna: `"Erro ao salvar. Verifique os campos e tente novamente."`

## Exclusão de entrada com motivo (`excluirEntrada`) — 2026-09-16

Botão 🗑️ ao lado do ✏️ na lista de movimentações (aba Movimentações > Posição). Aparece apenas para linhas do tipo `'entrada'` com `id` preenchido.

Ao clicar, abre o `modalExcluirEntrada` (modal próprio, NÃO usa `confirm()`). O campo "Motivo da exclusão" é obrigatório — sem ele o botão de confirmar exibe erro e não prossegue.

O motivo é salvo em `snapshot_antes.motivo_exclusao` no registro do `unif_log`.

```js
// Abre modal — NÃO excluir diretamente
function excluirEntrada(id) { ... }

// Chamado pelo botão "Confirmar exclusão" no modal
async function confirmarExcluirEntrada() {
  const motivo = document.getElementById('excluirEntradaMotivo').value.trim();
  if (!motivo) { toast('Informe o motivo.', 'erro'); return; }
  await sbDelete('unif_entradas', `id=eq.${id}`);
  await _logUnif('entrada_excluida', 'unif_entradas', id, { ...snapshot, motivo_exclusao: motivo }, null);
}
```

`fecharModalExcluir()` fecha e limpa `_excluirEntradaId`.

## Modal "Editar entrada" — arrastável (2026-09-16)

O modal é arrastável pelo cabeçalho (`cursor:move`). Implementado com IIFE que adiciona listeners `mousedown`/`mousemove`/`mouseup` no `DOMContentLoaded`.

- Na primeira vez que arrasta, converte `transform:translateX(-50%)` para coordenadas absolutas `left/top`
- `fecharEditEntrada()` reseta para `left:50%; top:80px; transform:translateX(-50%)` a cada fechamento
- IDs relevantes: `modalEditEntrada` (overlay), `modalEditEntradaBox` (caixa), `modalEditEntradaHdr` (cabeçalho drag)
- `modal-overlay` usa `align-items:flex-start; justify-content:flex-start` para não conflitar com o posicionamento absoluto

## Auditoria — `unif_log` (implementada 2026-09-16)

### Tabela `unif_log` (criada no Supabase)

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | bigserial PK | auto |
| `acao` | text NOT NULL | ver tabela de ações abaixo |
| `tabela` | text | `'unif_entradas'` / `'unif_estoque'` |
| `registro_id` | text | id do registro afetado |
| `snapshot_antes` | jsonb | estado antes da alteração |
| `snapshot_depois` | jsonb | estado após (null se exclusão) |
| `usuario` | text | `perfil.nome` do localStorage |
| `criado_em` | timestamptz | `DEFAULT NOW()` |

RLS habilitado com policy `anon_all` (leitura e escrita liberadas).

### Valores válidos para `acao`

| `acao` | Área | Disparado em |
|---|---|---|
| `entrada_excluida` | Estoque | `confirmarExcluirEntrada` — motivo em `snapshot_antes.motivo_exclusao` |
| `entrada_editada` | Estoque | `salvarEditEntrada` |
| `estoque_ajustado` | Estoque | `confirmarAjusteEstoque` |
| `entrega_registrada` | Entregas | `salvarEntrega` |
| `devolucao_registrada` | Entregas | `salvarDevolucao` (modal devolução) e `salvarEntrega` quando motivo = `demissao` |
| `movimentacao_estornada` | Entregas | `executarEstorno` |
| `item_criado` | Catálogo | `salvarItem` (novo) |
| `item_editado` | Catálogo | `salvarItem` (edição) |
| `item_excluido` | Catálogo | `confirmarExcluirItem` |
| `almoxarifado_criado` | Configurações | `salvarAlmox` (novo) |
| `almoxarifado_editado` | Configurações | `salvarAlmox` (edição) |
| `fornecedor_criado` | Configurações | `salvarFornecedor` (novo) |
| `fornecedor_editado` | Configurações | `salvarFornecedor` (edição) |

Ao adicionar novas ações, seguir o padrão `<objeto>_<verbo_passado>` (ex: `kit_excluido`).

### Helper `_logUnif(acao, tabelaRef, registroId, antes, depois)`

```js
async function _logUnif(acao, tabelaRef, registroId, antes, depois) {
  const perfil = JSON.parse(localStorage.getItem('sb_perfil') || '{}');
  await sbPost('unif_log', {
    acao, tabela: tabelaRef, registro_id: String(registroId),
    snapshot_antes: antes || null, snapshot_depois: depois || null,
    usuario: perfil.nome || 'RH',
  }).catch(() => {}); // falha silenciosa — não bloqueia a operação principal
}
```

### Onde é chamado — cobertura completa (2026-09-16)

**Regra:** sempre capturar o snapshot **antes** do `sbPatch`/`sbDelete`, nunca depois.

#### Estoque
| Função | `acao` | `antes` | `depois` |
|---|---|---|---|
| `confirmarExcluirEntrada` | `'entrada_excluida'` | snapshot de `ENTRADAS` + `motivo_exclusao` | `null` |
| `salvarEditEntrada` | `'entrada_editada'` | snapshot de `ENTRADAS` | objeto com novos dados |
| `confirmarAjusteEstoque` | `'estoque_ajustado'` | `{ quantidade: qtdAnterior }` | `{ quantidade: novaQtd, obs }` |

#### Entregas / Devoluções
| Função | `acao` | `tabela` | `registro_id` |
|---|---|---|---|
| `salvarEntrega` | `'entrega_registrada'` | `'unif_movimentacoes'` | `_colabAtual.id` |
| `salvarDevolucao` | `'devolucao_registrada'` | `'unif_movimentacoes'` | `_colabAtual.id` |
| `executarEstorno` | `'movimentacao_estornada'` | `'unif_movimentacoes'` | `movId` |

#### Catálogo
| Função | `acao` | `antes` | `depois` |
|---|---|---|---|
| `salvarItem` (novo) | `'item_criado'` | `null` | payload |
| `salvarItem` (edição) | `'item_editado'` | snapshot de `ITENS` | payload |
| `confirmarExcluirItem` | `'item_excluido'` | snapshot de `ITENS` | `null` |

#### Configurações
| Função | `acao` | `antes` | `depois` |
|---|---|---|---|
| `salvarAlmox` (novo) | `'almoxarifado_criado'` | `null` | payload |
| `salvarAlmox` (edição) | `'almoxarifado_editado'` | snapshot de `ALMOXARIFADOS` | payload |
| `salvarFornecedor` (novo) | `'fornecedor_criado'` | `null` | payload |
| `salvarFornecedor` (edição) | `'fornecedor_editado'` | snapshot de `FORNECEDORES` | payload |

## Aba Auditoria — `renderAuditoria()` — 2026-09-16

Quarta aba do Estoque (ao lado de Posição / Movimentações / Alertas). Botão: `estab-auditoria`, seção: `essec-auditoria`.

Busca `unif_log` ordenado por `criado_em DESC` (máx 200 registros). Filtro agrupado por área via `filtroAuditoriaAcao` (grupos: Estoque / Entregas+Devoluções / Catálogo / Configurações).

Colunas: Data/Hora · Usuário · Ação (badge colorido) · Registro (tabela + id) · Antes (JSON truncado) · Depois (JSON truncado).

Cores dos badges por categoria:
- **Vermelho** (`#FEF3F2 / #B42318`): exclusões e estornos
- **Azul** (`#EFF8FF / #1849A9`): edições
- **Verde** (`#F0FDF4 / #027A48`): criações, entregas, ajustes
- **Roxo** (`#FDF4FF / #6941C6`): devoluções

Quando `snapshot_antes.motivo_exclusao` existe, exibe abaixo do badge: "Motivo: …"

Chamada via `setEstoqueSubTab('auditoria')` → `renderAuditoria()`.

## Tipos de movimentação (`tipo` em `unif_movimentacoes`)

| Valor | Descrição |
|---|---|
| `entrega` | Entrega de uniforme a colaborador |
| `devolucao` | Devolução de uniforme |
| `ajuste` | **Não usar em `unif_movimentacoes`** — ver seção acima |

## Labels de motivo (`motivoLabel`)

```js
const motivoLabel = {
  admissao:             'Admissão',
  extra_desconto_folha: '🛒 Extra (desc. folha)',
  troca_programada:     'Troca programada',
  troca_antecipada:     'Troca antecipada',
  demissao:             'Desligamento',
  ajuste:               'Ajuste',
  devolucao:            'Devolução'
};
```
