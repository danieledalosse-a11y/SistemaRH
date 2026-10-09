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
| `_avHtml(nome, fotoUrl, cls)` | ~495 | `<div>` de avatar com foto ou iniciais — **usar sempre, inclusive no modal** |

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

### Módulos (`_renderModules`)

- Exibe SOMENTE módulos presentes em `p.acesso_modulos`
- Tiles centralizados: ícone 52px + border-radius 14px + nome 14px bold
- Sem descrição nos tiles — ícone + nome apenas
- Fonte: dados locais (`sb_perfil`) — **zero fetch**

---

## REGRA DE SEGURANÇA SALARIAL — obrigatória

> **A Home do Gestor nunca deve buscar nem exibir `salario_anterior`, `salario_novo` ou
> qualquer valor nominal de remuneração.**

### View `v_historico_eventos_home` (migration 111)

A Home lê atividades **sempre** desta view, nunca de `historico_eventos` diretamente.

**Campos expostos pela view:**
```
id, colaborador_id, tipo, titulo, data_evento, resumo_home
```

**`resumo_home` para eventos salariais** substitui valores nominais por percentual + mês/ano + cargo.
Exemplo: `"+8% · set/2026 · cargo mantido"`

> **Nunca substituir a view por query direta a `historico_eventos` na Home.**

---

## Queries da Home (somente leitura)

| Dado | Tabela/View | Filtro principal |
|---|---|---|
| Foto do gestor | `colaboradores` | `id=eq.${p.colaborador_id}&select=foto_url` |
| Apelido | `param_gestor` | `gestor_id=eq.${uid}&select=apelido` |
| Equipe | `colaboradores` | `gestor=ilike.${apelido}&data_demissao=is.null&select=id,nome,cargo,setor,data_nascimento,data_admissao,foto_url` |
| Férias | `ferias` | `colaborador_id=in.(${teamIds})` |
| Atividades | `v_historico_eventos_home` | `colaborador_id=in.(${teamIds})&order=id.desc&limit=5` |

A Home **nunca escreve** no banco. Toda query é GET via `_hdGet`.

---

## Erros esperados / conhecidos

| Endpoint | Código | Motivo |
|---|---|---|
| `param_gestor?gestor_id=...` | 400 | Tabela sem RLS para gestor ou coluna inexistente — não impede funcionamento |
| `ferias?...&select=...dias_corridos` | 400 | Coluna `dias_corridos` não existe na tabela `ferias` — fix pendente |

---

## Estrutura visual da Home Gestor (UX revisado 2026-10-09)

### Blocos e ordem (imutável)

1. **Saudação** — avatar gestor + nome + meta + mini-avatares equipe + data
2. **Módulos** — grid de tiles, ícone + nome apenas
3. **Eventos** — grid 2 colunas: Próximos aniversários | Tempo de Casa
4. **Férias da equipe**
5. **Últimas Atividades**

**Nunca reorganizar a ordem dos blocos.**

### Cards de Eventos (Aniversários e Tempo de Casa)

- Header do card: ícone colorido (30px, bolo = âmbar, relógio = verde) + título + botão "Ver todos →"
- **Card exibe os 3 primeiros** registros mais próximos (limite visual para compactação)
- Apresentação horizontal: `hd-person-grid` → colunas `hd-person-col`
  - Avatar 46px com foto (`background-image`) ou iniciais (fallback)
  - `ring-today` (amber) para aniversário hoje
  - `ring-top` (verde) para maior tempo de casa
  - Nome: 2 primeiros nomes completos, 10px bold, max-width 76px
  - **Aniversários:** data em `hd-person-date-sm` (cinza, sem pill) ou `hd-today-pill` (âmbar, sem fundo)
  - **Tempo de Casa:** anos em `hd-years-text` (verde, sem fundo) + data do aniversário em `hd-person-date-sm`

### Botão "Ver todos →"

- **Aparece sempre que há qualquer registro** (`length > 0`) — não depende de haver mais do que o limite visual
- Conceito: Home = resumo compacto; "Ver todos" = porta para consulta completa
- Botão oculto no HTML por padrão (`style="display:none"`), ativado por JS em `_renderEventos`

### Modal "Ver todos"

- Abre lista **completa** de todos os registros dentro da janela de 60 dias (não só os que ficaram de fora)
- Cada linha: `_avHtml(nome, foto_url, 'hd-modal-av')` + nome completo + cargo · setor + data/anos
- `cargo` e `setor` vêm da query de equipe (já disponíveis no objeto `c`)
- Cor da data: âmbar para aniversário hoje, verde para tempo de casa, cinza para demais
- **Sem subtítulo** — contagem removida a pedido (2026-10-09)
- Fecha ao clicar fora (overlay) ou no ×
- **Preparado para Diretoria:** cargo e setor já presentes para dar contexto em equipes maiores
- **Não criar lógica paralela de avatar** — sempre usar `_avHtml`, que já tem foto + fallback

### Atividades (`_renderAtividades`)

Badge colorido por tipo antes do título:

| Tipo | Classe | Label |
|---|---|---|
| promoção | `.promocao` | Promoção |
| reajuste/salarial | `.reajuste` | Reajuste salarial |
| férias | `.ferias` | Férias |
| avaliação/desempenho | `.avaliacao` | Avaliação |
| admissão | `.admissao` | Admissão |
| doc/arquivo | `.doc` | Documento |

**Lógica promoção x reajuste sem redundância:**
- Promoção: `titulo` = "Cargo Novo · Nome" (extrai trecho após "para "); `resumo` = só percentual + mês/ano
- Reajuste: `titulo` = nome do colaborador; `resumo` = `resumo_home` completo ("% · mês/ano · cargo mantido")

### Férias da equipe (`_renderFerias`)

- Dois stats lado a lado: número grande "em férias hoje" + número "agendadas (30 dias)"
- Mini-avatares (iniciais por `colaborador_id`) abaixo de cada stat
- Sem chips de texto

---

## HTML da Home — IDs relevantes

| ID | Elemento | Preenchido por |
|---|---|---|
| `hd-gestor-av` | Avatar do gestor | `renderHomeGestor` |
| `hd-greeting-title` | "Boa tarde, Nome!" | `renderHomeGestor` |
| `hd-greeting-meta` | "Grupo · N colabs · Perfil" | `renderHomeGestor` |
| `hd-team-row` | Mini-avatares da equipe | `renderHomeGestor` |
| `hd-date-weekday` / `hd-date-full` | Data | `renderHomeGestor` |
| `hd-mod-row` | Grid de módulos | `_renderModules` |
| `hd-aniv-list` | Container avatares aniversários | `_renderEventos` |
| `hd-casa-list` | Container avatares tempo de casa | `_renderEventos` |
| `hd-aniv-vertodos` | Botão "Ver todos" aniversários | `_renderEventos` |
| `hd-casa-vertodos` | Botão "Ver todos" tempo de casa | `_renderEventos` |
| `hd-ferias-stats` | Stats de férias | `_renderFerias` |
| `hd-act-list` | Lista de atividades | `_renderAtividades` |

---

## CSS do avatar do gestor

```css
.hd-gestor-av {
  width: 80px; height: 80px; border-radius: 50%;
  display: flex; align-items: center; justify-content: center;
  font-size: 24px; font-weight: 700; color: #fff; flex-shrink: 0;
  background: var(--blue);
  background-size: cover; background-position: center;
}
```


**Valores do card saudação (`.hd-greeting`):** `padding: 24px 28px`, `gap: 20px`
**`.hd-greeting-main`:** `gap: 18px`
**`.hd-greeting-title`:** `font-size: 22px`

---

## `usuarios_perfil.colaborador_id` — fonte canônica

O campo `colaborador_id` em `usuarios_perfil` é o vínculo oficial entre usuário Auth e
registro em `colaboradores`. Protegido pelo trigger `trg_check_colaborador_obrigatorio`
(migration 059) que exige preenchimento para perfis `Gestor` e `Colaborador`.

---

## Regras de expansão futura

1. **RH e Diretoria:** NÃO implementar ainda. Validar Home do Gestor em produção primeiro.
2. **Nova view/query:** sempre verificar se não expõe dados salariais.
3. **Nova constante usada na Home:** colocar no bloco de constantes antes da IIFE.
4. **Novo módulo no menu:** adicionar entrada no array `ALL_MODS` dentro de `_renderModules`.
5. **A Home é somente leitura:** nenhuma operação de escrita deve ser adicionada a ela.
6. **Modal de consulta:** sempre usar `_avHtml` — nunca recriar lógica de avatar.
7. **Cargo e setor no modal:** já disponíveis na query de equipe — não adicionar nova query.

---

## Histórico de bugs resolvidos (referência)

| Bug | Causa raiz | Fix |
|---|---|---|
| Foto do gestor nunca aparecia | `_HD_URL` em TDZ — `_hdGet` silenciava com `catch→[]` | Mover `_HD_URL`/`_HD_KEY` para antes da IIFE (commit `e766d3e`) |
| `gc = []` sem erro no console | `_hdGet` tem `try/catch` global que engole TDZ ReferenceError | Diagnóstico: substituir `_hdGet` por `fetch` direto para ver status HTTP bruto |
| Migration 111 | View expõe `resumo_home` sem dados salariais | Executada 2026-10-08, status: ✅ |
| Fotos não apareciam no modal | Modal criava `<div>` de avatar manualmente em vez de usar `_avHtml` | Substituir por `_avHtml(r.nome, r.foto_url, 'hd-modal-av')` |
