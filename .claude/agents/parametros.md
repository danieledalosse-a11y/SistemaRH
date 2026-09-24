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
