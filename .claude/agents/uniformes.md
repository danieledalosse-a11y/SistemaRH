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
