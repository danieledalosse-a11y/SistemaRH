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

## Exclusão de entrada (`excluirEntrada`) — 2026-09-16

Botão 🗑️ ao lado do ✏️ na lista de movimentações (aba Movimentações > Posição). Aparece apenas para linhas do tipo `'entrada'` com `id` preenchido.

```js
async function excluirEntrada(id) {
  if (!confirm('Excluir esta entrada permanentemente? Esta ação não pode ser desfeita.')) return;
  await sbDelete('unif_entradas', `id=eq.${id}`);
  await carregarEstoque();
}
```

Captura snapshot de `ENTRADAS` antes de excluir e registra em `unif_log` via `_logUnif`.

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
| `acao` | text NOT NULL | `'entrada_editada'` / `'entrada_excluida'` / `'estoque_ajustado'` |
| `tabela` | text | `'unif_entradas'` / `'unif_estoque'` |
| `registro_id` | text | id do registro afetado |
| `snapshot_antes` | jsonb | estado antes da alteração |
| `snapshot_depois` | jsonb | estado após (null se exclusão) |
| `usuario` | text | `perfil.nome` do localStorage |
| `criado_em` | timestamptz | `DEFAULT NOW()` |

RLS habilitado com policy `anon_all` (leitura e escrita liberadas).

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

### Onde é chamado

| Função | `acao` | `antes` | `depois` |
|---|---|---|---|
| `excluirEntrada` | `'entrada_excluida'` | snapshot de `ENTRADAS` | `null` |
| `salvarEditEntrada` | `'entrada_editada'` | snapshot de `ENTRADAS` | objeto com novos dados |
| `confirmarAjusteEstoque` | `'estoque_ajustado'` | `{ quantidade: qtdAnterior }` | `{ quantidade: novaQtd, obs }` |

**Regra:** sempre capturar o snapshot **antes** do `sbPatch`/`sbDelete`, nunca depois.

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
