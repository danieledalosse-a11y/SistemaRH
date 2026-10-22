---
name: parametros
description: Especialista no módulo Parâmetros Gerais do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/parametros/index.html — especialmente gestão de usuários, perfis de acesso, credenciais e integração com Supabase Auth.
---

# Skill: Módulo Parâmetros — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).
Arquivo principal: `C:\Users\reves\SistemaRH\modulos\parametros\index.html` (tudo inline).

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo inline no index.html.
2. **Nunca usar a chave secreta (service role) no browser** — chave publicável apenas.
3. **Nunca hardcodar perfil, user_id, e-mail ou string de papel** — tudo parametrizado via tabela `perfis`.
4. **Senhas nunca armazenadas na tabela** — apenas no Supabase Auth (criptografadas).
5. **Sempre apresentar proposta antes de implementar** — aguardar aprovação.

## Arquitetura de credenciais (migração 060/061 — set/2026)

### Fonte única de verdade: Supabase Auth

O e-mail de acesso vem de `auth.users`, não da tabela `usuarios_perfil`.
A senha existe **somente** no Supabase Auth — a coluna `senha_acesso` foi removida (migration 061).

### Controle de acesso parametrizado

Quem pode listar/gerir usuários é determinado por `perfis.modulos @> '["parametros"]'::jsonb`.
Não existe nenhuma string de papel fixo no código ou no banco. Hoje apenas o perfil Admin tem
`"parametros"` nos módulos, mas isso é configurável em Parâmetros → Perfis.

### Componentes do backend

| Componente | Arquivo | Função |
|---|---|---|
| `auth_pode_gerir_usuarios()` | migration 060 | Helper SECURITY DEFINER — retorna true se o chamador tem `"parametros"` nos módulos do perfil |
| RLS `up_select/insert/update` | migration 060 | Gestor/colaborador vê apenas o próprio registro; admin vê todos |
| `fn_get_usuarios_perfil()` | migration 060 | SECURITY DEFINER — lista usuários com `COALESCE(auth.users.email, up.email)` |
| `criar-usuario-auth` | Edge Function | Cria ou atualiza credenciais no Auth; suporta `modo: 'update'` com `user_id` |
| migration 061 | SQL | `DROP COLUMN senha_acesso` da tabela `usuarios_perfil` |

### Como o frontend chama o backend

```js
// Listar usuários (via RPC — não via REST direto em v_usuarios_perfil)
async function sbRpc(fn, params) {
  const r = await fetch(`${SB_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST', headers: SB_HEADERS, body: JSON.stringify(params || {})
  });
  if (!r.ok) throw new Error(await r.text());
  return r.json();
}
// carregarUsers() chama sbRpc('fn_get_usuarios_perfil')

// Criar/atualizar credenciais (via Edge Function)
const EDGE_FN = `${SB_URL}/functions/v1/criar-usuario-auth`;
const EDGE_HEADERS = { 'Content-Type': 'application/json', 'Authorization': `Bearer ${SB_KEY}` };
// Criar: body sem campo `modo`
// Atualizar: body com `modo: 'update'` e `user_id` obrigatório; password opcional
```

### Regras do formulário de usuário

- Campo e-mail: sempre exibido (vem do Auth via `fn_get_usuarios_perfil`)
- Campo senha: **obrigatório apenas para criação**; em edição, deixar em branco = manter senha atual
- Hint de senha em edição: "Deixe em branco para manter a senha atual"
- `senha_acesso` **nunca** vai para o body do PATCH em `usuarios_perfil`

## Fluxo salvarUser()

**Criação:**
1. Chama Edge Function `criar-usuario-auth` com `{ email, password, nome }` (sem `modo`)
2. Edge Function retorna `{ user_id }`
3. PATCH em `usuarios_perfil` com `user_id`, perfil, cargo, colaborador_id, ativo

**Edição:**
1. Busca `user_id` do usuário atual em `allUsers`
2. Se `user_id` ausente → erro "Usuário sem vínculo com conta de acesso. Recrie o usuário."
3. Chama Edge Function com `{ user_id, email, nome, modo: 'update' }` + `password` somente se preenchido
4. PATCH em `usuarios_perfil` com dados não-credenciais

## Edge Function `criar-usuario-auth`

Arquivo: `C:\Users\reves\SistemaRH\supabase\functions\criar-usuario-auth\index.ts`
Deploy: `supabase functions deploy criar-usuario-auth --project-ref rujtbxwssiofiialnbbg`

- **`modo` ausente** → cria usuário no Auth; se e-mail já existir, retorna `user_id` existente (idempotente)
- **`modo: 'update'`** → `admin.auth.admin.updateUserById(user_id, updates)` — atualiza e-mail e/ou senha
- Usa `SUPABASE_SERVICE_ROLE_KEY` do ambiente Deno (nunca exposta ao browser)

## Migrations aplicadas

| Nº | Arquivo | Conteúdo |
|---|---|---|
| 060 | `migrations/060_v_usuarios_perfil_email_auth.sql` | Helper, RLS e função SECURITY DEFINER |
| 061 | `migrations/061_drop_senha_acesso.sql` | Remove coluna `senha_acesso` |

## Armadilhas conhecidas e correções aplicadas

### SyntaxError: `as Error` no catch (corrigido em set/2026)
O `(e as Error).message` é TypeScript — inválido em JS puro no browser. Causava crash total do script,
impedindo o `renderSidebar()` de rodar (sidebar vazia). Correto: `(e?.message || e)`.

### Usuário com `perfil_id = null` na `usuarios_perfil`
Registros antigos criados antes da migração 060 podem ter `perfil_id = null` mesmo tendo `perfil = 'admin'`
(campo texto legado). A função `auth_pode_gerir_usuarios()` faz JOIN com `perfis` pelo `perfil_id` — se
NULL, o JOIN falha e a função retorna false, deixando o usuário sem ver nada na listagem.

**Diagnóstico:**
```sql
SELECT au.id AS auth_id, au.email, up.nome, up.perfil_id
FROM auth.users au
LEFT JOIN usuarios_perfil up ON up.user_id = au.id
ORDER BY au.email;
```

**Correção:** preencher o `perfil_id` correto:
```sql
UPDATE usuarios_perfil SET perfil_id = 1 WHERE id = <id_do_usuario>;
-- perfil_id=1 = Admin (verificar em SELECT * FROM perfis)
```

### Usuário sem `user_id` na `usuarios_perfil`
Usuários criados manualmente (antes da Edge Function) podem existir no Auth mas sem vínculo na tabela.
O JOIN da função usa `up.user_id = auth.uid()` — sem vínculo, o usuário não consegue nem ver a própria
linha. Fix: editar o registro no Supabase Dashboard e preencher o `user_id` com o UUID do auth.users.

## O que NÃO fazer

- **Nunca** usar `GRANT SELECT ON public.v_usuarios_perfil TO authenticated` — qualquer autenticado veria todos os usuários via API direta. Usar sempre `fn_get_usuarios_perfil()` via RPC.
- **Nunca** criar view com `LEFT JOIN auth.users` sem `SECURITY DEFINER` — `authenticated` não acessa `auth.users`.
- **Nunca** chamar `/functions/v1/swift-processor` para credenciais — função errada e inexistente para esse fim.
- **Nunca** hardcodar `perfil = 'admin'` em verificação de acesso — usar `perfis.modulos @> '["parametros"]'`.

## Supabase CLI (para deploy de Edge Functions)

CLI instalado via npm no Windows da usuária em set/2026:
```powershell
# Instalar (já feito)
npm install -g supabase

# Liberar execução de scripts (já feito)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Deploy
cd C:\Users\reves\SistemaRH
supabase login
supabase functions deploy criar-usuario-auth --project-ref rujtbxwssiofiialnbbg
```

## CATS — flag `noAuditCols` (set/2026)

O módulo Parâmetros usa um objeto `CATS` para configurar cada categoria de cadastro (tabela, label, campos, etc.). A lógica genérica de `salvar()` e `toggleAtivo()` injeta automaticamente colunas de auditoria (`alterado_por`, `updated_at`, `criado_por`) em todo PATCH/POST.

**Problema:** tabelas que não possuem essas colunas (ex: `param_escopo_ferias`) causavam erro `Could not find the 'alterado_por' column`.

**Solução:** flag `noAuditCols: true` na entrada do CATS:

```js
// Em CATS, para a categoria escopo_ferias:
escopo_ferias: {
  table: 'param_escopo_ferias',
  noAuditCols: true,   // ← tabela não tem alterado_por / updated_at / criado_por
  noAtivo: false,
  // ...demais campos
}
```

**Como a lógica respeita a flag:**

```js
// Em salvar():
const _noAudit = CATS[currentCat].noAuditCols;
if (editingId) {
  if (!_noAudit) { body.alterado_por = _nome; body.updated_at = new Date().toISOString(); }
} else {
  if (!CATS[currentCat].noAtivo) body.ativo = true;
  if (!_noAudit) body.criado_por = _nome;
}

// Em toggleAtivo():
const _patch = cat.noAuditCols
  ? { ativo: !atual }
  : { ativo: !atual, alterado_por: _nome, updated_at: new Date().toISOString() };
await sbPatch(cat.table, id, _patch);
```

**Regra:** usar `noAuditCols: true` em toda nova categoria cujo `CREATE TABLE` não inclua `alterado_por`, `updated_at` e `criado_por`. Tabelas padrão do sistema (criadas antes de set/2026) têm essas colunas e não precisam da flag.

## `param_motivo_desligamento` — deduplicação e proteção (migration 073, out/2026)

### Contexto

A tabela acumulou 23 registros (deveria ter 12) porque o seed foi executado duas vezes. Corrigido em migration 073.

### Estado atual após correção

12 registros com `codigo` únicos, `ordem` 1–12 sem gaps. Constraint UNIQUE pendente de execução manual (ver abaixo).

### Migration 073 executada

Passos executados via curl (service_role):
1. `UPDATE colaboradores SET motivo_demissao = 'Demitido s/ Justa Causa' WHERE motivo_demissao = 'Demitido s/ justa causa'` — 1 registro corrigido (Rennan, id=1812)
2. `DELETE FROM param_motivo_desligamento WHERE id IN (2,3,4,5,6,10,13,19,20,22,23)` — 11 duplicatas removidas
3. `UPDATE param_motivo_desligamento SET ordem = 10 WHERE id = 21` — Transferência corrigida de ordem=9 para ordem=10

### UNIQUE constraint — pendente de execução manual

SQL salvo em `migrations/073_unique_motivo_desligamento_codigo.sql`. Executar uma vez no **Supabase Dashboard → SQL Editor**:
```sql
ALTER TABLE param_motivo_desligamento
ADD CONSTRAINT uq_pmd_codigo UNIQUE (codigo);
```

### Proteção no frontend — mecanismo genérico `uniqueFields` no CATS

A categoria `motivo_desligamento` no objeto `CATS` recebeu:
```js
motivo_desligamento: {
  // ...campos existentes...
  uniqueFields: [{ key: 'codigo', label: 'Código' }]
}
```

A função `salvar()` itera sobre `cat.uniqueFields` antes do POST/PATCH:
- Faz GET no Supabase filtrando pelo valor informado
- Em edição: exclui o próprio registro via `id=neq.${editingId}`
- Se encontrar conflito → aborta com toast de erro "Já existe um registro com este Código"
- Fallback: erro HTTP 409 do Supabase (constraint violation) exibe toast amigável

**Para proteger outro parâmetro:** basta adicionar `uniqueFields` na entrada correspondente do CATS — sem alterar a lógica central.

### Regra para futuras migrações

Nunca executar seeds de `param_motivo_desligamento` (ou qualquer tabela param_*) mais de uma vez. O `ON CONFLICT DO NOTHING` sem target de coluna não protege contra re-inserção se a constraint UNIQUE ainda não existir.

---

## Categoria `escopo_ferias` — Escopo de Gestão de Férias

Cadastro de escopos adicionais que expandem a equipe visível de um gestor no módulo Férias.

### Entrada no CATS

```js
escopo_ferias: {
  table:       'param_escopo_ferias',
  noAuditCols: true,   // tabela não tem alterado_por/updated_at/criado_por
  noAtivo:     false,
  // campos: gestor_id, tipo, valor, gestor_ref_id
}
```

### `_escopoPopularValor(tipo, valorAtual)` — dropdown dinâmico

Função chamada ao mudar o campo `tipo` no formulário de escopo. Popula o `<select id="field_valor">` com as opções corretas para cada tipo:

| `tipo` | Label | Opções do select |
|---|---|---|
| `'empresa_atuacao'` | "Empresa de atuação" | Distinct de `colaboradores.empresa_atuacao` (stripNum) |
| `'setor'` | "Setor" | Distinct de `colaboradores.setor` (stripNum) |
| `'todos'` | — | Campo oculto (sem select) |
| `'gestor'` | "Gestor incluído" | Todos os gestores de `gestoresMap`, excluindo o gestor atual (`field_gestor_id`) |

**Lógica para tipo `'gestor'`:**
```js
} else if (tipo === 'gestor') {
  if (label) label.textContent = 'Gestor incluído';
  const gestorAtualId = String(document.getElementById('field_gestor_id')?.value || '');
  opts += Object.entries(gestoresMap)
    .filter(([id]) => String(id) !== gestorAtualId)   // não mostra o próprio gestor
    .sort(([, a], [, b]) => a.localeCompare(b, 'pt-BR'))
    .map(([id, nome]) => `<option value="${id}"${valorAtual === String(id) ? ' selected' : ''}>${nome}</option>`)
    .join('');
}
```

**Crítico:** para tipo `'gestor'`, o `<select id="field_valor">` recebe o `id` numérico do gestor referenciado, que é salvo na coluna `gestor_ref_id` (não em `valor`). O save deve mapear o valor selecionado para o campo correto.

### Campos no formulário

- `gestor_id` — FK para `param_gestor` (qual gestor tem esse escopo)
- `tipo` — select: empresa_atuacao / setor / todos / gestor
- `valor` — texto (empresa ou setor); NULL quando tipo = 'todos' ou 'gestor'
- `gestor_ref_id` — integer FK para `param_gestor`; preenchido quando tipo = 'gestor'; NULL nos demais

### Exclusão de escopos

Escopos devem ser **excluídos fisicamente** (DELETE), não apenas inativados. Um escopo que não faz mais sentido (ex: gestor Juninho não precisa mais ver equipe do Jander) deve sair da tabela — não há histórico a preservar.

### Migrations relacionadas

| Nº | Arquivo | Conteúdo |
|---|---|---|
| 062 | `migrations/062_param_escopo_ferias.sql` | Cria tabela com tipos empresa_atuacao/setor/todos |
| 063 | `migrations/063_escopo_ferias_gestor_ref.sql` | Adiciona `gestor_ref_id` FK + tipo `'gestor'` |
| 064 | `migrations/064_escopo_ferias_unique.sql` | Índices únicos parciais por tipo |

---

## Categoria `escopo_home` — Escopo de Visualização da Home (commits `1e83e0b`/`e3c718c`/`d46ddb4`, out/2026)

Seção **"Home"** no CATS (renomeada de "Home do Gestor" em out/2026). Tabela: `param_escopo_home`.

### Renderização — dois níveis de agrupamento

`renderTabela` é interceptado para `escopo_home` e chama `renderEscopoHomeAgrupado(rows)`. `allRows` permanece o array flat original.

**Nível 1 — card por gestor** (`.eh-gestor-card`): header com nome + contador de escopos ativos/inativos (conta grupos únicos `modulo+tipo`, não linhas). Body colapsável com `.eh-table`.

**Nível 2 — linha por grupo `modulo+tipo`**: dentro de cada card, registros com a mesma funcionalidade+tipo são condensados em uma única linha. Coluna "Valores" exibe chips: ativos em azul (`var(--blue-bg)`), inativos riscados em cinza. Um único botão de lápis por linha abre o modal com todos os chips do grupo.

### Modal — seleção múltipla (commit `e3c718c`)

O modal opera por grupo (`gestor_id + modulo + tipo`):

- **Criação:** chip selector — busca + chips removíveis por tipo. Salvar → INSERT de N linhas (uma por chip); duplicatas ignoradas. Tipo `todos` → 1 linha sem valor.
- **Edição:** gestor/funcionalidade/tipo fixos (read-only). Chips pré-carregados com todos os ativos do grupo. Ao salvar: INSERT para chips novos, DELETE físico para chips removidos, chips inalterados sem ação. Registros inativos existentes não são reativados nem duplicados.

**Tipos com multi-select:** gestor, colaborador, setor, empresa_atuacao, tipo_vinculo, cargo. Tipo `todos`: sem campo de valor.

### Helpers

```js
const _TIPO_L_EH  = { empresa_atuacao: 'Empresa de atuação', setor: 'Setor', todos: 'Todos os CLT', gestor: 'Equipe de gestor', colaborador: 'Colaborador específico', tipo_vinculo: 'Tipo de vínculo', cargo: 'Cargo' };
const _MOD_L_EH   = { aniversarios: 'Aniversariantes / Tempo de casa' };
function _ehValorDisplay(row)              // gestor → gestoresMap, colaborador → colaboradoresEscopoMap, tipo_vinculo → tiposVinculoList
function _ehRowToChip(r)                   // row DB → {valor, label, gestor_ref_id}
function _ehMontarBody(gid, mod, tipo, chip)   // monta body para INSERT
function _ehVerificarDuplicata(gid, mod, tipo, chip)  // GET no banco — retorna true se já existe (qualquer status)
function _ehInicializarChipSelector(tipo)  // substitui select field_valor pelo chip UI
function _ehRenderChips()                  // re-renderiza área de chips
function _ehAdicionarChip(valor, label, gestorRefId)
function _ehRemoverChip(idx)
function _ehBuscar()                       // filtra opções e exibe dropdown
function _ehToggle(gid)                    // expande/colapsa card
function _ehAdicionarParaGestor(gid)       // abre modal pré-selecionando gestor
```

**State:** `_ehChips []`, `_ehGrupoLinhas []`, `_ehTipoAtual`.

### Comportamento após salvar

`carregar()` re-renderiza — cards voltam colapsados (esperado, não é bug).

---

## Categoria `aviso_home` — Comunicados da Home (migrations 117/118, out/2026)

Seção **"Home"** no CATS (mesma renomeação aplicada). Tabela: `param_aviso_home`.

### Formulário — campos

`titulo`, `corpo` (rich text — ver abaixo), `tipo` (info/lembrete/urgente), `data_inicio`, `data_fim` (nullable), `ativo`, **Destinatários** (checkboxes de perfil + busca de colaboradores específicos).

### Editor rich text — campo `corpo` (commit `4eb027e`, out/2026)

Campo `corpo` é `type: 'richtext'` no CATS. O renderer injeta um `<div contenteditable id="field_corpo_editor">` com barra de ferramentas compacta acima (`.rte-wrap > .rte-toolbar`).

**Barra:** botões N/I via `execCommand('bold'/'italic')` + 6 bolinhas de cor (`.rte-color-dot`) via `execCommand('foreColor', false, hex)`. Todos os handlers usam `onmousedown + preventDefault` para não tirar o foco do editor.

**Paleta:** `#1a1a2e` (preto) · `#4B5565` (cinza) · `#2563eb` (azul) · `#dc2626` (vermelho) · `#16a34a` (verde) · `#ea580c` (laranja).

**`abrirModal`:** `editorEl.innerHTML = row?.corpo || ''` + listener `keydown Enter` → `execCommand('insertLineBreak')` (evita `<div>` gerado pelo Chrome).

**`salvar`:** lê `field_corpo_editor.innerHTML` e chama `_avSanitizarCorpo(html)` antes de gravar.

**`_avSanitizarCorpo(html)`:** usa DOMParser; primeiro converte todos os `<div>` em `<br>` (compatibilidade com registros salvos antes do fix); tags permitidas: `B`, `STRONG`, `I`, `EM`, `SPAN` (apenas `style.color`), `P`, `BR`. Demais tags: unwrap. Atributos removidos exceto `style.color` em SPAN.

**Home (`index.html`):** `_avisosTextoPlano(html)` extrai `textContent` para a prévia do card. Float card usa `innerHTML` + `white-space:pre-wrap` no `.hd-aviso-float-corpo` (exibe formatação e quebras de linha). Comunicados existentes em texto puro: compatíveis sem alteração.

### Abas do modal (ao editar — commits `a4e9b97`, `7bbd099`)

Ao **editar** um comunicado existente, o modal exibe duas abas:

- **Formulário** (padrão): campos de edição limpos, sem informações de auditoria
- **Histórico**: "Criado em / Última alteração" + accordion "Histórico de alterações"

Ao **criar** novo: modal sem abas, apenas formulário.

**CSS das abas:** `.modal-tabs` (oculto por padrão), `.modal-tabs.visible` (exibido), `.modal-tab`, `.modal-tab.active`, `.modal-tab-pane`, `.modal-tab-pane.active`.

**Controle JS:** `avSwitchTab(tab)` — recebe `'formulario'` ou `'historico'`; ativa a aba e o painel correspondente. Chamada em `abrirModal` e `fecharModal`.

**`abrirModal`:** quando `currentCat === 'aviso_home'`:
- Adiciona `.modal--compact` e mostra `.modal-tabs` somente se `row` existir (edição)
- Sempre chama `avSwitchTab('formulario')` ao abrir
- Remove `.modal-tabs` e `.modal--compact` para outras categorias

**`fecharModal`:** remove `.modal--compact`, `.modal-tabs.visible`, limpa `#avAuditBlock`.

**`#avAuditBlock`:** `<div>` vazio na aba Histórico, populado por `_avisoHomeInicializarDestinatarios` com o `field-audit` (criado_em / updated_at) ao editar. Nunca injetado em `#modalFields`.

**`#histSection`:** accordion reaproveitado, agora dentro de `#tabPaneHistorico` em vez de fora do `#modalFields`. Lógica `carregarHistorico`/`renderHistorico` inalterada.

### Destinatários — checkboxes de perfil (commits `a4e9b97`, `496d1c6`, `1fa88c1`)

**Regra "Todos":** exclusivo com perfis específicos. Ao marcar "Todos", os demais ficam `disabled` e a seção de gestores específicos recebe `opacity:0.4; pointer-events:none`.

**Fix de interação (commit `1fa88c1`):** `onchange` inline e event delegation em `insertAdjacentHTML` não eram confiáveis em todos os browsers. Solução definitiva:
- Labels usam atributo `for="avCbTodos"` etc. + estilos inline sobrescrevendo `.field label` (`text-transform:none; letter-spacing:0`)
- Listeners adicionados programaticamente logo após o `insertAdjacentHTML`:
```js
const _cbTodos = document.getElementById('avCbTodos');
if (_cbTodos) _cbTodos.addEventListener('change', function() { avTodasChange(this); });
['avCbGestor','avCbRh','avCbDiretoria'].forEach(cbId => {
  const _cb = document.getElementById(cbId);
  if (_cb) _cb.addEventListener('change', avPerfilChange);
});
```

**Funções de callback (ainda existem no arquivo — não remover):**
```js
function avTodasChange(cb)   // desabilita/habilita perfis; chama _avAtualizarColabSection()
function avPerfilChange()     // desmarca avCbTodos; chama _avAtualizarColabSection()
function avToggleTodos(e)    // legado — não chamado; não remover (pode ser reutilizado)
function avTogglePerfil(p,e) // legado — não chamado; não remover
```

### Dropdown de gestores específicos — posicionamento (commit `1fa88c1`)

O elemento `avColabDropdown` (`position:fixed; z-index:9999`) ficava preso no stacking context do modal — o footer do modal aparecia acima do dropdown mesmo com z-index alto.

**Fix:** após `insertAdjacentHTML`, o dropdown é movido para `document.body`:
```js
const _avDd = document.getElementById('avColabDropdown');
if (_avDd) document.body.appendChild(_avDd);
```

Em `fecharModal`, o dropdown é removido do body:
```js
const _avDdBody = document.getElementById('avColabDropdown');
if (_avDdBody) _avDdBody.remove();
```

O `avBuscarGestor` usa `getBoundingClientRect()` para posicionamento — funciona corretamente com o elemento no body.

### Busca de gestores específicos — `avBuscarGestor` (commit `496d1c6`)

Substitui `avBuscarColab` (que buscava em `colaboradores`). Fonte oficial: `param_gestor`.

```js
async function avBuscarGestor() {
  // query: param_gestor?ativo=eq.true&nome=ilike.*q*&select=id,nome,apelido,colaborador_id
  // usa SB_HEADERS (JWT autenticado) — param_gestor tem RLS que bloqueia publishable key
  // filtra: validos = list.filter(g => g.colaborador_id)
  // armazena: _avGestorCache[g.colaborador_id] = { colaborador_id, nome: g.apelido || g.nome }
}
function avSelecionarGestor(colaboradorId) {
  // push { id: colaboradorId, nome } em _avColabSelecionados
}
```

**Importante:** `param_gestor.colaborador_id` deve estar preenchido para o gestor aparecer na busca. Gestores sem `colaborador_id` são filtrados por `validos = list.filter(g => g.colaborador_id)`.

### Layout do formulário aviso_home (commit `7153908`)

```
[ Título                              ]  ← width 4
[ Mensagem (opcional)                 ]  ← width 4
[ Tipo                                ]  ← width 4 (era 2 — mudado para deixar datas lado a lado)
[ Data de início   ][ Data de fim     ]  ← width 2 + 2
[ Destinatários...                    ]  ← width 4 (injetado via _avisoHomeInicializarDestinatarios)
```

### Modal compacto `.modal--compact` (piloto visual)

CSS no final do `<style>` com `!important` para garantir precedência. Aplica apenas quando `currentCat === 'aviso_home'`. Reduz padding, font-size e espaçamentos. Ver bloco CSS "Modal compacto — piloto do padrão visual".

### `salvar()` — bloco aviso_home

```js
if (currentCat === 'aviso_home') {
  if (!body.data_fim) body.data_fim = null;
  const checkedPerfis = [...document.querySelectorAll('.av-perfil-cb:checked')].map(el => el.value);
  body.publico = checkedPerfis.length ? checkedPerfis : ['todos'];
  body.colaboradores_ids = _avColabSelecionados.length ? _avColabSelecionados.map(c => c.id) : null;
}
```

### Título clicável na lista

Coluna `titulo` renderizada com `cursor:pointer; color:var(--blue)` e `onclick="editarItem('${row.id}')"` — clicar abre o modal direto, sem precisar do botão editar.

### Migrations

| Nº | Conteúdo | Status |
|---|---|---|
| 117 | Cria `param_aviso_home` + RLS base | ✅ executada |
| 118 | `publico TEXT[]`, `colaboradores_ids INTEGER[]`, recria policies com lógica array | ✅ executada |
