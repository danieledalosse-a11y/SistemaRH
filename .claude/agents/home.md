---
name: home
description: >
  Especialista na Home Dashboard do SistemaRH (index.html) — arquitetura de roteamento por
  perfil, renderização da visão Gestor, regras de TDZ, segurança salarial e view
  v_historico_eventos_home. Use este skill quando for implementar, depurar ou expandir
  qualquer coisa em index.html ou nas queries/views que a Home consome.
tools:
  - Glob
  - Grep
  - Read
  - Edit
  - Write
  - Bash
  - PowerShell
---

# Home Dashboard — SistemaRH

## Arquivo principal

`index.html` — raiz do repositório (`C:\Users\reves\SistemaRH\index.html`)

---

## Arquitetura de roteamento

### Fluxo de carga

```
localStorage → sb_perfil → routeHomePerfil(p) → renderHome<Perfil>(p)
```

O IIFE (bloco de script inline, ~linha 418) lê `sb_perfil` do localStorage e chama
`routeHomePerfil(p)` **sincronamente**. `routeHomePerfil` despacha para a função de render
correta conforme `p.perfil`:

```js
function routeHomePerfil(p) {
  const perfil = (p.perfil || '').toLowerCase();
  if (perfil === 'gestor') {
    document.querySelector('.container').style.display = 'none';
    document.getElementById('container-home-dashboard').style.display = 'block';
    renderHomeGestor(p).catch(e => console.error('[renderHomeGestor]', e));
  }
  // futuro: else if (perfil === 'rh') renderHomeRH(p)
  //         else if (perfil === 'diretoria') renderHomeDiretoria(p)
}
```

### Adição de novo perfil

Adicionar apenas um `else if` em `routeHomePerfil` e criar a função `renderHome<Perfil>(p)`.
Nenhuma outra parte do código precisa mudar.

---

## REGRA CRÍTICA — TDZ (Temporal Dead Zone)

> **Toda `const` usada por `renderHomeGestor` ou qualquer função que ela chame deve ser
> declarada ANTES da IIFE RBAC.**

### Por que existe esse risco

O IIFE chama `renderHomeGestor` **sincronamente**. Constantes `const`/`let` declaradas
**depois** do IIFE estão em TDZ nesse momento e lançam `ReferenceError` ao serem acessadas.

O `_hdGet` tem `try { ... } catch(_) { return []; }` — ele **silencia** o `ReferenceError` e
retorna `[]` em vez de propagar o erro. Resultado: a feature falha sem nenhum log visível.
A sintoma clássica é: **funciona ao chamar manualmente no console; não funciona na carga da página.**

### Constantes protegidas (bloco ~linha 414)

```js
// Constantes declaradas antes da IIFE para evitar TDZ
const _AV_COLORS = ['#1849A9','#027A48','#5925DC','#B45309','#C11574','#026AA2','#2D6A4F'];
const _HD_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const _HD_KEY = 'sb_publishable_V4jUw9qvHjN9LvncGunqNQ_o_dj0RdH';
```

**Nunca mover essas constantes para depois da IIFE.**
**Ao adicionar nova constante usada na Home, colocá-la neste bloco.**

`function` declarations (não `const`/`let`) são hoisted com valor e não têm esse problema.

### Diagnóstico se a feature não funciona na carga

1. Verificar se a constante usada está ANTES da IIFE no arquivo
2. Confirmar com `fetch(location.href).then(r=>r.text()).then(t=>console.log(t.includes('minhaConst')))` que o código deployado tem a constante
3. Testar manualmente no console — se funcionar manualmente mas não na carga → TDZ

---

## Helpers da Home (`index.html`)

Todos definidos como `function` declarations (hoisted) — sem risco de TDZ:

| Helper | Linha aprox. | Função |
|---|---|---|
| `_hdHeaders()` | ~471 | Monta cabeçalhos Supabase com token da sessão |
| `_hdGet(table, params)` | ~475 | GET silencioso — retorna `[]` em caso de erro |
| `_jwtSub(token)` | ~481 | Extrai `sub` (user_id) do JWT |
| `_avColor(name)` | ~487 | Cor determinística de avatar por nome |
| `_initials(name)` | ~492 | Iniciais do nome (máx 2 letras) |
| `_avHtml(nome, fotoUrl, cls)` | ~495 | `<div>` de avatar com foto ou iniciais |

---

## `renderHomeGestor(p)` — fluxo completo

```
p (sb_perfil do localStorage)
  │
  ├─ DOM síncronos:
  │   ├─ saudação + data
  │   ├─ gestorAv: iniciais + cor (avatar temporário)
  │   └─ _renderModules(p)            ← módulos do menu (síncrono)
  │
  ├─ await foto do gestor             ← _hdGet colaboradores?id=eq.${p.colaborador_id}
  │   └─ aplica backgroundImage no gestorAv se foto_url existir
  │
  ├─ await apelido (param_gestor)     ← 400 esperado enquanto tabela não tiver RLS correta
  │
  ├─ await equipe (colaboradores)     ← gestor=ilike.${apelido}
  │   └─ mini-avatares na hd-team-row
  │
  └─ await Promise.all([
        ferias da equipe,
        v_historico_eventos_home (atividades)
     ])
      └─ _renderEventos / _renderFerias / _renderAtividades
```

### Foto do Gestor

- **Fonte do `colaborador_id`:** `sb_perfil.colaborador_id` — gravado em `login.html` via
  `SELECT usuarios_perfil?...&select=nome,perfil,perfil_id,acesso_modulos,colaborador_id`
- **Query:** `_hdGet('colaboradores', 'id=eq.${p.colaborador_id}&select=foto_url')`
- **Aplicação:** `gestorAv.style.backgroundImage = url('...')` + `backgroundSize:cover`
- **Guard:** `if (p.colaborador_id)` — sem `colaborador_id` no `sb_perfil`, bloco ignorado
  (provável causa: login com `sb_perfil` antigo sem esse campo — fazer logout/login)

### Módulos (`_renderModules`)

- Exibe SOMENTE módulos presentes em `p.acesso_modulos`
- Sem fallback "Em breve" — tile só aparece se `acesso_modulos` contiver a chave
- Fonte: dados locais (`sb_perfil`) — **zero fetch**

---

## REGRA DE SEGURANÇA SALARIAL — obrigatória

> **A Home do Gestor nunca deve buscar nem exibir `salario_anterior`, `salario_novo` ou
> qualquer valor nominal de remuneração.**

### View `v_historico_eventos_home` (migration 111)

Arquivo: `migrations/111_v_historico_eventos_home.sql`
Status: executada no Supabase (2026-10-08)

A Home lê atividades **sempre** desta view, nunca de `historico_eventos` diretamente.

**Campos expostos pela view:**
```
id, colaborador_id, tipo, titulo, data_evento, resumo_home
```

**Campos NUNCA expostos:**
- `dados` (JSONB completo)
- `salario_anterior`, `salario_novo`
- `resumo` original de eventos do tipo `reajuste_salarial` ou `promocao`

**`resumo_home` para eventos salariais** substitui valores nominais por:
- Percentual: `+6%` ou `+6,5%`
- Mês/ano: `ago/2026`
- Cargo: `novo cargo: Vendedor(a) Pleno` ou `cargo mantido`

**Exemplo:** `"+8% · set/2026 · cargo mantido"`

**RLS:** SECURITY INVOKER — respeita as políticas de `historico_eventos`.

> **Nunca substituir a view por query direta a `historico_eventos` na Home.**

---

## Queries da Home (somente leitura)

| Dado | Tabela/View | Filtro principal |
|---|---|---|
| Foto do gestor | `colaboradores` | `id=eq.${p.colaborador_id}&select=foto_url` |
| Apelido | `param_gestor` | `gestor_id=eq.${uid}&select=apelido` |
| Equipe | `colaboradores` | `gestor=ilike.${apelido}&data_demissao=is.null` |
| Férias | `ferias` | `colaborador_id=in.(${teamIds})` |
| Atividades | `v_historico_eventos_home` | `colaborador_id=in.(${teamIds})&order=id.desc&limit=5` |

A Home **nunca escreve** no banco. Toda query é GET via `_hdGet`.

---

## Erros esperados / conhecidos

| Endpoint | Código | Motivo |
|---|---|---|
| `param_gestor?gestor_id=...` | 400 | Tabela sem RLS para gestor ou coluna inexistente — não impede funcionamento |
| `ferias?...&select=...dias_corridos` | 400 | Coluna `dias_corridos` não existe na tabela `ferias` — fix pendente |

Ambos são tratados pelo `_hdGet` (retorna `[]`) sem afetar o resto da página.

---

## HTML da Home

```html
<div id="container-home-dashboard" style="display:none">
  <div class="home-dash">

    <!-- 1. Saudação -->
    <div class="hd-greeting">
      <div class="hd-greeting-main">
        <div class="hd-gestor-av" id="hd-gestor-av"></div>   <!-- avatar do gestor -->
        <div class="hd-greeting-body">
          <div id="hd-greeting-title">...</div>
          <div id="hd-greeting-meta"></div>
          <div class="hd-team-row" id="hd-team-row"></div>   <!-- mini-avatares da equipe -->
        </div>
      </div>
      <div class="hd-greeting-date">
        <div id="hd-date-weekday"></div>
        <div id="hd-date-full"></div>
      </div>
    </div>

    <!-- 2. Módulos -->
    <!-- 3. Eventos -->
    <!-- 4. Férias da equipe -->
    <!-- 5. Últimas Atividades -->
  </div>
</div>
```

`hd-gestor-av` e `hd-team-row` são **irmãos** — `innerHTML` de `hd-team-row` nunca afeta `hd-gestor-av`.

---

## CSS do avatar do gestor

```css
.hd-gestor-av {
  width: 52px; height: 52px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 18px; font-weight: 700; color: #fff; flex-shrink: 0;
  background: var(--blue);
  background-size: cover; background-position: center;
}
```

Ao aplicar a foto, o JS define via inline style:
```js
gestorAv.textContent = '';
gestorAv.style.background = '#e5e7eb';
gestorAv.style.backgroundImage = `url('${gc[0].foto_url}')`;
gestorAv.style.backgroundSize = 'cover';
gestorAv.style.backgroundPosition = 'center';
```

Inline style tem especificidade maior que classe — a foto sempre "ganha" da cor padrão.

---

## `usuarios_perfil.colaborador_id` — fonte canônica

O campo `colaborador_id` em `usuarios_perfil` é o vínculo oficial entre usuário Auth e
registro em `colaboradores`. Protegido pelo trigger `trg_check_colaborador_obrigatorio`
(migration 059) que exige preenchimento para perfis `Gestor` e `Colaborador`.

Em `login.html`, o SELECT já inclui esse campo:
```js
usuarios_perfil?user_id=eq.${uid}&select=nome,perfil,perfil_id,acesso_modulos,colaborador_id
```

---

## Regras de expansão futura

1. **RH e Diretoria:** NÃO implementar ainda. Validar Home do Gestor em produção primeiro.
2. **Nova view/query:** sempre verificar se não expõe dados salariais.
3. **Nova constante usada na Home:** colocar no bloco de constantes antes da IIFE.
4. **Novo módulo no menu:** adicionar entrada no array `ALL_MODS` dentro de `_renderModules`.
5. **A Home é somente leitura:** nenhuma operação de escrita deve ser adicionada a ela.
6. **Princípio:** Home é camada de apresentação/resumo. Regras de negócio pertencem ao módulo respectivo.

---

## Histórico de bugs resolvidos (referência)

| Bug | Causa raiz | Fix |
|---|---|---|
| Foto do gestor nunca aparecia | `_HD_URL` em TDZ — `_hdGet` silenciava com `catch→[]` | Mover `_HD_URL`/`_HD_KEY` para antes da IIFE (commit `e766d3e`) |
| `gc = []` sem erro no console | `_hdGet` tem `try/catch` global que engole TDZ ReferenceError | Diagnóstico: substituir `_hdGet` por `fetch` direto para ver status HTTP bruto |
| Migration 111 | View expõe `resumo_home` sem dados salariais | Executada 2026-10-08, status: ✅ |
