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
3. **Somente leitura na Fase 1** — nenhuma operação de escrita (sbPost/sbPatch/sbDelete) neste módulo até liberação explícita de fase posterior.
4. **modulos/colaborador/index.html é intocável** — qualquer mudança no colaborador deve ser feita apenas naquele arquivo, nunca como efeito colateral de alterações no autoatendimento.
5. **Auditar antes de implementar** — apresentar proposta antes de qualquer alteração.

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
  └─ salva sb_session no localStorage (access_token, refresh_token, expires_at)
  └─ salva sb_perfil no localStorage (nome, perfil, perfil_id, acesso_modulos, colaborador_id)
       └─ index.html (painel principal)
            └─ se perfil === 'colaborador' → redireciona para modulos/autoatendimento/index.html
            └─ outros perfis → painel normal do RH
```

O redirecionamento está em `index.html`:
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

## Autenticação no módulo

O módulo usa **dois** itens do localStorage:

- `sb_session` — `{ access_token, refresh_token, expires_at }` — JWT do usuário Supabase
- `sb_perfil` — `{ nome, perfil, colaborador_id, ... }` — dados do perfil carregados no login

```js
const SB_KEY = 'eyJhbGci...'; // chave publicável (anon key)

function getAuthHeaders() {
  const sess = JSON.parse(localStorage.getItem('sb_session') || '{}');
  const token = sess.access_token || SB_KEY;
  return { apikey: SB_KEY, Authorization: `Bearer ${token}` };
}

async function sbGet(path) {
  const r = await fetch(SB_URL + path, { headers: getAuthHeaders() });
  return r.ok ? r.json() : [];
}
```

Quando `access_token` existe, o Supabase avalia as RLS policies com o JWT do colaborador. Quando não existe (anon), avalia com role `anon`.

## getSession()

Mescla `sb_session` e `sb_perfil` em um único objeto, com validação de expiração:

```js
function getSession() {
  try {
    const sess = JSON.parse(localStorage.getItem('sb_session') || 'null');
    const perf = JSON.parse(localStorage.getItem('sb_perfil') || 'null');
    if (!sess) return null;
    if (sess.expires_at < Date.now()) { localStorage.clear(); return null; }
    return { ...sess, ...(perf || {}) };
  } catch { return null; }
}
```

`expires_at` é em milissegundos (timestamp JS, não Unix seconds).

## Inicialização (init)

```js
async function init() {
  initAuth();              // preenche topbar com nome/avatar
  const sess = getSession();
  if (!sess) return;       // initAuth já redirecionou para login

  const colabId = sess.colaborador_id;
  if (!colabId) {
    mostrarErro('Nenhum colaborador vinculado a este usuário. Contate o RH.');
    return;
  }

  const [colabs, ferias] = await Promise.all([
    sbGet(`/rest/v1/colaboradores?id=eq.${colabId}&limit=1`),
    sbGet(`/rest/v1/ferias?colaborador_id=eq.${colabId}&order=ano.desc`),
  ]);

  if (!colabs || !colabs.length) {
    mostrarErro('Colaborador não encontrado. Contate o RH.');
    return;
  }

  _colab  = colabs[0];
  _ferias = ferias || [];

  renderHero();
  renderResumo();

  // esconde spinner e exibe conteúdo
  document.getElementById('mainContainer').style.display = 'none';
  document.getElementById('heroArea').style.display = '';
  document.getElementById('tabsArea').style.display = '';
  document.getElementById('tabContent').style.display = '';
}
```

O `colaborador_id` vem do `sb_perfil` — nunca de parâmetro de URL.

## Variáveis globais

```js
let _colab  = null;   // objeto do colaborador logado
let _ferias = [];     // array de períodos de férias do colaborador
```

## Layout da página

```
Topbar (navy #101828 = var(--accent))
├── "Revest / Meu RH" (esquerda)
└── nome do usuário + avatar + botão logout (direita)

Hero (#heroArea) — visível após carregamento
├── foto circular (foto_url ou iniciais)
├── nome completo + cargo · setor
└── chips: Ativo/Inativo | empresa_registro | empresa_atuacao | Mat. N | Admitido em DD/MM/AAAA

Tabs (#tabsArea)
├── Resumo → #sec-resumo
└── Minhas Férias → #sec-ferias

Spinner (#mainContainer) — visível durante carregamento, escondido depois
```

## Abas disponíveis

| Tab | ID da seção | Função de render |
|---|---|---|
| Resumo | `sec-resumo` | `renderResumo()` |
| Minhas Férias | `sec-ferias` | `renderFerias()` (lazy — só chama ao clicar) |

## renderHero()

Preenche o bloco hero com dados do `_colab`:

```js
function renderHero() {
  const c = _colab;
  const ini = (c.nome||'?').split(' ').map(w=>w[0]).join('').slice(0,2).toUpperCase();
  const ph  = document.getElementById('heroPhoto');
  if (c.foto_url) {
    ph.innerHTML = `<img src="${c.foto_url}" style="..." alt="${c.nome}">`;
  } else {
    ph.textContent = ini;
  }
  document.getElementById('heroNome').textContent = c.nome || '—';
  document.getElementById('heroSub').textContent  = [c.cargo, c.setor].filter(Boolean).join(' · ');
  // chips: status ativo/inativo, empresa_registro_nome, empresa_atuacao_nome, matricula, data_admissao
  document.getElementById('heroChips').innerHTML = chips;
}
```

Campos usados: `c.nome`, `c.cargo`, `c.setor`, `c.foto_url`, `c.data_demissao`, `c.empresa_registro_nome`, `c.empresa_atuacao_nome`, `c.matricula`, `c.data_admissao`.

## renderResumo()

Dois blocos:

**Cards superiores (`#resumoCards`):**
- `c-blue` — Tempo de casa: `tempoStr(c.data_admissao)` + data desde
- `c-amber` — Saldo de férias: soma de `saldo > 0` de todos os PAs não cancelados

Cálculo de saldo por PA:
```js
const saldo = totalDias - usado - (pa.dias_antecipados||0) - (pa.abono_pecuniario||0);
if (saldo > 0 && pa.status !== 'cancelado') saldoPendente += saldo;
```

**Info-grids (`#resumoInfo`):**
- **Dados Pessoais:** CPF, RG, data_nascimento, naturalidade, estado_civil, escolaridade
- **Dados Profissionais:** matricula, cargo, setor, tipo_contrato, regime_horas, data_admissao, data_demissao (só se existir)

`infoRow(label, val)` — omite a linha se val for falsy ou `'—'`.

## renderFerias()

Renderiza os períodos aquisitivos de `_ferias` em ordem decrescente de ano (já ordenado pela query `order=ano.desc`). Lazy — só é chamada ao clicar na aba.

Para cada PA exibe:
- Header: "Período YYYY" + datas `pa_inicio → pa_fim` + badge de saldo
- Lista de lançamentos com dot colorido: verde (passado), azul (futuro), laranja (em andamento)
- Se sem lançamentos: texto "Sem lançamentos"

Cores do badge de saldo:
```
saldo > 15  → saldo-ok   (verde)
saldo > 0   → saldo-warn (âmbar)
saldo ≤ 0   → saldo-crit (vermelho)
```

Dot de lançamento:
```js
const dot = l.fim && l.fim < HOJE ? '' : (l.inicio && l.inicio > HOJE ? 'fut' : 'pen');
// '' = passado (verde)  'fut' = futuro (azul)  'pen' = em andamento (laranja)
```

## logout()

```js
function logout() {
  localStorage.removeItem('sb_session');
  localStorage.removeItem('sb_perfil');
  window.location.href = '../../login.html';
}
```

Remove ambos os itens — `sb_session` e `sb_perfil`. Profundidade do path: `modulos/autoatendimento/` → `../../login.html`.

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
  AND id = auth_colaborador_id()           -- para tabela colaboradores
  -- AND colaborador_id = auth_colaborador_id()  -- para tabela ferias
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
| 1 | RLS + Hero + Meu Perfil (Resumo) + Minhas Férias (leitura) | Concluída |
| 2 | Solicitação de férias pelo colaborador | Pendente — não iniciar sem validação da Fase 1 |
| 3+ | Outros autoatendimentos | Pendente |

**Regra**: não avançar para Fase 2 sem validação completa da Fase 1 pela usuária (incluindo teste via API com JWT real do usuário Colaborador antes da liberação do perfil em produção).

## Validação pendente (Fase 1)

Antes de liberar o perfil Colaborador para usuários reais:
1. Login como ANA → confirmar redirecionamento para autoatendimento
2. Verificar via DevTools (Network) que as respostas de `/rest/v1/colaboradores` e `/rest/v1/ferias` retornam apenas os registros dela
3. Confirmar que o RH não foi afetado (regressão nos módulos existentes)
