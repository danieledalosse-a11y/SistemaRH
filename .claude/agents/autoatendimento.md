---
name: autoatendimento
description: Especialista no módulo Autoatendimento (Meu RH) do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/autoatendimento/index.html, ou quando a tarefa envolver RLS das tabelas colaboradores e ferias, ou as funções auth_perfil() e auth_colaborador_id() no Supabase.
---

# Skill: Módulo Autoatendimento (Meu RH) — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).
Arquivo principal: `C:\Users\reves\SistemaRH\modulos\autoatendimento\index.html`

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo inline no index.html.
2. **Nunca usar a chave secreta do Supabase no browser** — chave publicável apenas.
3. **Nunca duplicar lógica** — renderFerias() e funções de férias reutilizam a mesma lógica do módulo colaborador; não criar versões paralelas.
4. **Somente leitura na Fase 1** — nenhuma operação de escrita (sbPost/sbPatch/sbDelete) neste módulo até liberação explícita de fase posterior.
5. **modulos/colaborador/index.html é intocável** — qualquer mudança no colaborador deve ser feita apenas naquele arquivo, nunca como efeito colateral de alterações no autoatendimento.
6. **Auditar antes de implementar** — apresentar proposta antes de qualquer alteração.

## Propósito e diferenças em relação ao módulo colaborador

| Aspecto | modulos/colaborador/index.html | modulos/autoatendimento/index.html |
|---|---|---|
| Quem usa | RH/Gestor visualizando dados de um colaborador | O próprio colaborador logado |
| Como identifica o colaborador | `?matricula=` na URL | `colaborador_id` do `sb_perfil` no localStorage |
| Abas disponíveis | Resumo, Férias, Desenvolvimento, Histórico | Resumo, Minhas Férias |
| Operações de escrita | Sim (RH pode editar) | Não (somente leitura) |
| Botão Voltar | Sim (volta ao painel RH) | Não |
| Topbar | Link para o sistema RH | Apenas "Revest / Meu RH" |

## Fluxo de autenticação e redirecionamento

```
login.html
  └─ salva sb_perfil no localStorage (nome, perfil, perfil_id, acesso_modulos, colaborador_id)
       └─ index.html (painel principal)
            └─ se perfil === 'colaborador' → redireciona para modulos/autoatendimento/index.html
            └─ outros perfis → painel normal do RH
```

O redirecionamento está em `index.html` (~linha 207):
```js
(function() {
  try {
    const _p = JSON.parse(localStorage.getItem('sb_perfil') || '{}');
    if ((_p.perfil || '').toLowerCase() === 'colaborador') {
      window.location.href = 'modulos/autoatendimento/index.html';
    }
  } catch(_) {}
})();
```

## Inicialização do módulo (init)

```js
async function init() {
  const sess = JSON.parse(localStorage.getItem('sb_perfil') || '{}');
  if (!sess.perfil) { window.location.href = '../../login.html'; return; }
  if ((sess.perfil || '').toLowerCase() !== 'colaborador') {
    window.location.href = '../../index.html'; return;
  }
  const colabId = sess.colaborador_id;
  if (!colabId) { mostrarErro('Nenhum colaborador vinculado a este usuário. Contate o RH.'); return; }
  const [colabs, ferias] = await Promise.all([
    sbGet(`/rest/v1/colaboradores?id=eq.${colabId}&limit=1`),
    sbGet(`/rest/v1/ferias?colaborador_id=eq.${colabId}&order=ano.desc`),
  ]);
  _colab = colabs[0];
  _ferias = ferias;
  renderResumo();
}
```

O `colaborador_id` vem do `sb_perfil` — nunca de parâmetro de URL.

## Variáveis globais

```js
let _colab  = null;   // objeto do colaborador logado
let _ferias = [];     // array de períodos de férias do colaborador
```

Não existem `_avaliacoes`, `_ciclos`, `_pdi`, `_historico` — esses são exclusivos do módulo colaborador.

## Abas disponíveis

| Tab ID | Seção | Função de render |
|---|---|---|
| tab-resumo | sec-resumo | renderResumo() |
| tab-ferias | sec-ferias | renderFerias() |

## renderResumo()

Exibe apenas 2 cards:
1. **Tempo de casa** — calculado a partir de `_colab.data_admissao`
2. **Saldo de férias** — calculado a partir dos dados de `_ferias`

Não exibe cards de avaliação, PDI ou histórico (esses pertencem ao módulo colaborador).

## renderFerias()

Idêntica à lógica do módulo colaborador — exibe tabela com períodos de férias, status, datas, saldo. Não há diferença funcional; qualquer correção de bug em férias deve ser aplicada nos dois módulos separadamente (sem criar função compartilhada externa).

## logout()

```js
function logout() {
  localStorage.removeItem('sb_perfil');
  localStorage.removeItem('sb_token');
  window.location.href = '../../login.html';
}
```

Mesma profundidade de path que `modulos/colaborador/index.html`.

## RLS — Segurança no banco

### Tabelas protegidas

| Tabela | RLS habilitado | Policies ativas |
|---|---|---|
| colaboradores | Sim | anon_all, authenticated_select, authenticated_write |
| ferias | Sim | anon_all, authenticated_select, authenticated_write |

### Funções helper (SECURITY DEFINER)

```sql
-- Retorna o perfil do usuário logado (ex: 'colaborador', 'rh', 'admin')
CREATE OR REPLACE FUNCTION auth_perfil()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT LOWER(COALESCE(perfil, ''))
  FROM   usuarios_perfil
  WHERE  user_id = auth.uid()   -- user_id é UUID em usuarios_perfil
  LIMIT  1;
$$;

-- Retorna o colaborador_id vinculado ao usuário logado (NULL para perfis sem vínculo)
CREATE OR REPLACE FUNCTION auth_colaborador_id()
RETURNS INTEGER LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT colaborador_id
  FROM   usuarios_perfil
  WHERE  user_id = auth.uid()
  LIMIT  1;
$$;
```

**CRÍTICO**: `usuarios_perfil.user_id` é do tipo **UUID** (não TEXT). Nunca usar `auth.uid()::text` — causa erro `operator does not exist: uuid = text`.

### Lógica das policies (authenticated_select)

```sql
-- Acesso explícito por perfil (whitelist)
auth_perfil() IN ('admin', 'rh', 'gestor', 'diretoria', 'logistica')
-- OU: colaborador vê apenas o próprio registro
OR (
  auth_perfil() = 'colaborador'
  AND auth_colaborador_id() IS NOT NULL
  AND id = auth_colaborador_id()   -- para colaboradores
  -- AND colaborador_id = auth_colaborador_id()   -- para ferias
)
```

**Princípio da whitelist**: qualquer perfil novo criado no futuro não tem acesso até ser explicitamente adicionado ao `IN (...)`. Nunca usar `NOT LIKE '%colaborador%'` ou condições por exclusão.

### Policy anon_all

Libera acesso total para o role `anon`. Necessário porque o sistema RH usa a chave publicável (sem autenticação) em alguns fluxos. Esta policy não deve ser removida.

### Policy authenticated_write

Apenas perfis admin/rh/gestor/diretoria/logistica podem escrever. Colaborador nunca escreve diretamente nas tabelas colaboradores ou ferias via API.

## Arquivo de migration

`C:\Users\reves\SistemaRH\migrations\048_rls_autoatendimento_fase1.sql`

Contém: criação das funções helper + habilitação de RLS + criação das 6 policies.

## Fases de evolução planejadas

| Fase | Funcionalidade | Status |
|---|---|---|
| 1 | RLS + Meu Perfil (Resumo) + Minhas Férias (leitura) | Concluída |
| 2 | Solicitação de férias pelo colaborador | Pendente — não iniciar sem validação da Fase 1 |
| 3+ | Outros autoatendimentos | Pendente |

**Regra**: não avançar para Fase 2 sem validação completa da Fase 1 pela usuária (incluindo teste via API com JWT real do usuário Colaborador antes da liberação do perfil em produção).

## Validação pendente (Fase 1)

Antes de liberar o perfil Colaborador para usuários reais:
1. Login como ANA → confirmar redirecionamento para autoatendimento
2. Verificar via DevTools (Network) que as respostas de `/rest/v1/colaboradores` e `/rest/v1/ferias` retornam apenas os registros dela
3. Confirmar que o RH não foi afetado (regressão nos módulos existentes)
