---
name: permissoes
description: Documenta o sistema centralizado de controle de acesso do SistemaRH — arquivo permissoes.js, função guardModulo(), RBAC na home, acesso_modulos por perfil. Use este skill quando trabalhar em autenticação, autorização, perfis de acesso, ou quando adicionar um novo módulo que precisa de proteção.
---

# Skill: Controle de Acesso Centralizado — SistemaRH Revest

## Arquivo central

`C:\Users\reves\SistemaRH\permissoes.js` — carregado no `<head>` de cada módulo protegido via:

```html
<script src="../../permissoes.js"></script>
```

Profundidade padrão dos módulos: `modulos/<nome>/index.html` → `../../permissoes.js`.

---

## Funções exportadas

### `podeAba(modulo, aba)`

Verifica se o usuário logado pode ver uma aba dentro de um módulo. Lê `sb_permissoes` do localStorage.

- `_PERM[modulo]` ausente → sem restrição (admin)
- `abas` ausente ou inclui `aba` → permitido

### `podeAcao(modulo, acao)`

Mesma lógica para ações (botões, operações) dentro de um módulo.

### `guardModulo(chave)`

**Função principal de proteção de módulo.** Deve ser chamada como a **primeira linha** do bloco de auth em qualquer módulo restrito.

```js
guardModulo('ferias'); // redireciona se não autorizado
```

**Fluxo de decisão:**

| Condição | Destino |
|---|---|
| Sem `sb_session` no localStorage | `../../login.html` |
| `s.expires_at < Date.now()` | limpa localStorage → `../../login.html` |
| `p.perfil === 'admin'` | **passa** (bypass total) |
| `p.acesso_modulos` inclui `chave` | **passa** |
| Qualquer outro caso | `../../index.html` (home) |

**Regras críticas:**
- `acesso_modulos = []` **não** concede acesso irrestrito — array vazio trata igual a qualquer array sem a chave
- Usuário não-admin com array vazio é **bloqueado** e redirecionado para home
- Admin com qualquer `acesso_modulos` sempre passa

**Implementação atual (permissoes.js):**

```js
function guardModulo(chave) {
  const sessRaw = localStorage.getItem('sb_session');
  if (!sessRaw) { window.location.href = '../../login.html'; return false; }
  try {
    const s = JSON.parse(sessRaw);
    if (s.expires_at < Date.now()) {
      localStorage.clear();
      window.location.href = '../../login.html';
      return false;
    }
    const p = JSON.parse(localStorage.getItem('sb_perfil') || '{}');
    if ((p.perfil || '') === 'admin') return true;
    const acesso = Array.isArray(p.acesso_modulos) ? p.acesso_modulos : [];
    if (acesso.includes(chave)) return true;
    window.location.href = '../../index.html';
    return false;
  } catch(_) {
    window.location.href = '../../login.html';
    return false;
  }
}
```

---

## Módulos protegidos

Todos os 7 módulos com acesso restrito chamam `guardModulo` como primeira instrução do bloco de auth:

| Módulo | Chave | Arquivo |
|---|---|---|
| Férias | `'ferias'` | `modulos/ferias/index.html` |
| Processos | `'processos'` | `modulos/processos/index.html` |
| Cadastro | `'cadastro'` | `modulos/cadastro/index.html` |
| Admissão | `'admissao'` | `modulos/admissao/index.html` |
| Uniformes | `'uniformes'` | `modulos/uniformes/index.html` |
| Desenvolvimento | `'desenvolvimento'` | `modulos/desenvolvimento/index.html` |
| Relatórios | `'relatorios'` | `modulos/relatorios/index.html` |

**Módulos sem guard** (acessíveis a qualquer autenticado):
- `modulos/parametros/index.html` — restrito por perfil (`admin` only) via lógica própria
- `modulos/autoatendimento/index.html` — fluxo de autenticação próprio (RLS Supabase)

---

## RBAC na home (`index.html`)

O `mapa` em `index.html` controla quais cards ficam visíveis para cada perfil:

```js
const mapa = {
  processos:       'card-processos',
  admissao:        'card-admissao',
  cadastro:        'card-cadastro',
  ferias:          'card-ferias',
  uniformes:       'card-uniformes',
  desenvolvimento: 'card-desenvolvimento',
  relatorios:      'card-relatorios',
};
```

**Regra:** cada chave do mapa deve ser idêntica à chave passada para `guardModulo()` no módulo correspondente. Se adicionar um novo módulo, atualizar o mapa E adicionar `guardModulo()` no módulo.

---

## `acesso_modulos` no Supabase (`usuarios_perfil`)

Campo JSONB com as chaves dos módulos que o usuário pode acessar.

### Estado atual dos perfis (confirmado 2026-09-21)

| Usuário/Perfil | `perfil` | `acesso_modulos` |
|---|---|---|
| Daniele Dalosse | admin | `[]` (bypass total) |
| Evelyn Lopes | admin | `["cadastro","ferias","processos","uniformes","admissao","parametros"]` |
| Heloisa Lima | rh | `["cadastro","ferias","processos","uniformes","admissao","relatorios"]` |
| Diretoria | diretoria | `["ferias"]` |
| Oriel / Rafhael / Prata / Carlos | gestor | `["ferias"]` |
| Logistica | logistica | `["uniformes"]` |
| ANA | colaborador | `[]` → redirecionada para autoatendimento |

**Administração via UI:** em `modulos/parametros/index.html` → seção Permissões. O array `MODULOS_SISTEMA` define quais módulos aparecem na UI de configuração:

```js
const MODULOS_SISTEMA = [
  { key: 'cadastro',       label: 'Cadastro',               icon: '👤' },
  { key: 'ferias',         label: 'Férias',                 icon: '🏖️' },
  { key: 'processos',      label: 'Workflow',               icon: '⚙️' },
  { key: 'uniformes',      label: 'Uniformes',              icon: '👔' },
  { key: 'admissao',       label: 'Admissão Online',        icon: '📋' },
  { key: 'relatorios',     label: 'Central de Relatórios',  icon: '📊' },
  { key: 'desenvolvimento',label: 'Desenvolvimento',        icon: '✏️' },
  { key: 'parametros',     label: 'Parâmetros',             icon: '🔧' },
];
```

**Regra:** ao criar um novo módulo com acesso restrito, adicionar a chave tanto no `MODULOS_SISTEMA` quanto no `mapa` do `index.html`.

---

## localStorage — estrutura de sessão

```js
// sb_session
{
  access_token: 'JWT...',
  refresh_token: '...',
  expires_at: 1234567890000  // timestamp em ms (Date.now() format)
}

// sb_perfil
{
  nome: 'Heloisa Lima',
  perfil: 'rh',               // 'admin' | 'rh' | 'gestor' | 'diretoria' | 'logistica' | 'colaborador'
  acesso_modulos: ['ferias', 'cadastro', ...],
  colaborador_id: 1234         // null para perfis não vinculados a colaborador
}

// sb_permissoes
{
  ferias: { abas: ['lista', 'calendario'], acoes: ['lancar', 'aprovar'] },
  // ausência do módulo = sem restrição fina
}
```

**CRÍTICO — `expires_at`:** o campo é salvo em milissegundos (`Date.now()` format). `guardModulo` compara diretamente com `Date.now()`. Nunca salvar em segundos (formato Unix padrão do Supabase) sem converter.

---

## Adicionando um novo módulo protegido

1. Criar `modulos/<nome>/index.html` com `<script src="../../permissoes.js"></script>` no `<head>`
2. Primeira linha do bloco de auth: `guardModulo('<chave>')`
3. Adicionar `<chave>: 'card-<nome>'` no `mapa` de `index.html`
4. Adicionar entrada em `MODULOS_SISTEMA` em `modulos/parametros/index.html`
5. Fazer PATCH em `usuarios_perfil` no Supabase para os perfis que devem ter acesso

---

## Histórico de implementação

- **Commit `239ed84`** (2026-09-21): implementação completa do `guardModulo()` e aplicação nos 7 módulos
- Antes: módulos verificavam apenas `sb_session` (existência/expiração) — acesso pela URL não era bloqueado para usuários autenticados sem permissão
- `acesso_modulos = []` tinha bypass implícito ("RH irrestrito") — **removido**: agora qualquer perfil não-admin precisa de chave explícita
