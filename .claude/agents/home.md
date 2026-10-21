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
  ├─ _renderModules(p)                  ← síncrono
  ├─ _renderAvisos(perfil)              ← async, logo após módulos
  │
  └─ await Promise.all([
        ferias da equipe,
        v_historico_eventos_home (atividades),
        param_marco_tempo_casa (marcos de tempo de casa) ← .catch(()=>[]) independente
     ])
      └─ _renderEventos(team, hoje, marcosGestor) / _renderFerias / _renderAtividades
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
| Apelido + pgGestorId | `param_gestor` | `colaborador_id=eq.${p.colaborador_id}&select=id,apelido` — `param_gestor` NÃO tem coluna `gestor_id`; usar `colaborador_id` (FK real, preenchida em todos os gestores ativos) |
| Equipe | `colaboradores` | `gestor=ilike.${apelido}&data_demissao=is.null&select=id,nome,cargo,setor,data_nascimento,data_admissao,data_ingresso_grupo,foto_url,tipo_vinculo,empresa_atuacao` |
| Escopos extras (aniversários) | `param_escopo_home` | `gestor_id=eq.${pgGestorId}&modulo=eq.aniversarios&ativo=eq.true` — via `_resolverEscoposHome` |
| Férias | `ferias` | `colaborador_id=in.(${teamIds})&select=colaborador_id,status,periodos,periodo1_inicio,periodo1_fim,periodo2_inicio,periodo2_fim` |
| Atividades | `v_historico_eventos_home` | `colaborador_id=in.(${teamIds})&order=id.desc&limit=5` |
| Marcos de tempo de casa | `param_marco_tempo_casa` | `select=anos&ativo=eq.true&order=anos` — `.catch(() => [])` independente; falha → `marcosGestor=[]`, sem troféus, Home continua funcionando |

A Home **nunca escreve** no banco. Toda query é GET via `_hdGet`.

---

## param_escopo_home — escopo adicional de aniversariantes (migration 133, out/2026)

Tabela `param_escopo_home`: expande colaboradores visíveis nos blocos Aniversários e Tempo de Casa sem alterar a equipe base.

**Campos:** `gestor_id INTEGER` (FK → `param_gestor.id`), `modulo TEXT` (`'aniversarios'` agora; extensível), `tipo TEXT` (gestor/empresa_atuacao/setor/todos), `valor TEXT`, `gestor_ref_id BIGINT` (FK → `param_gestor.id`), `ativo BOOLEAN`. Sem RLS própria — mesmo padrão de `param_escopo_ferias`.

**Função `_resolverEscoposHome(gestorId, modulo, idsBase, colSelect)`:**
- Busca escopos ativos do gestor para o módulo
- `tipo='gestor'`: usa `gestor_ref_id` para buscar apelido em `param_gestor`, então `colaboradores?gestor=ilike.{apelido}`
- `tipo='empresa_atuacao'`: filtra por `empresa_atuacao` normalizada
- `tipo='setor'`: filtra por setor
- `tipo='todos'`: todos os CLT ativos
- `tipo='colaborador'`: busca por `id=eq.{valor}` — sem filtro CLT
- `tipo='tipo_vinculo'`: filtra `tipo_vinculo` do colaborador (lowercase); `valor2` opcional para filtrar também por `empresa_atuacao` (normalizada) — sem filtro CLT
- `tipo='cargo'`: filtra `cargo` do colaborador (normalização lowercase+trim+NFD) — sem filtro CLT
- Dedup: remove ids já em `idsBase` (equipe própria)
- Falha silenciosa: `.catch(() => [])` — Home continua com `team` base

**Separação de escopos no render:**
- `team` = equipe base (usada em mini-avatares, férias, atividades, bell)
- `teamAniversarios` = `team` + extras — usada **somente em `_renderEventos`**
- Nunca ampliar outros blocos sem intenção explícita

**Parâmetros Gerais:** seção "Home do Gestor" → "Escopo de Visualização — Home". Inicialização requer `escopo_home` no bloco `if/else if` que chama `carregarGestores()` + `carregarSetores()` + `carregarEmpresasAtuacao()` + `carregarColaboradoresParaEscopo()` + `carregarTiposVinculo()` + `carregarCargos()` (commit `f1f5f46`).

**Tipos de escopo disponíveis:** `gestor`, `empresa_atuacao`, `setor`, `tipo_vinculo` (com `valor2` opcional para empresa), `cargo`, `colaborador`, `todos`.

**`carregarCargos()`:** busca DISTINCT cargos ativos de `colaboradores` (campo `cargo`, `data_demissao=is.null`), ordenados alfabeticamente. Armazenado em `cargosList[]`.

**Evolução:** para adicionar novo módulo (ex: `ferias`), basta adicionar opção no dropdown `home_modulo` (Parâmetros) e bloco correspondente em `_resolverEscoposHome`. Tabela e migration não precisam mudar.

---

## Erros esperados / conhecidos

| Endpoint | Código | Motivo |
|---|---|---|
| `param_gestor?colaborador_id=...` | resultado vazio | gestor sem `colaborador_id` — fallback `apelido = primeiroNome` (nome do JWT); Home continua |

---

## Estrutura visual da Home Gestor (UX revisado out/2026)

### Layout de duas colunas (commit `fd54464`)

```
.home-dash  { display: grid; grid-template-columns: 1fr 288px; gap: 16px; max-width: 1100px }
  .hd-main    ← coluna esquerda (flex-column, gap:10px)
  .hd-sidebar ← coluna direita sticky, flex-column, gap:10px
```

**Coluna principal `.hd-main` — ordem imutável:**
1. **Saudação** — avatar gestor + nome + meta + mini-avatares + data
2. **Módulos** — grid de tiles
3. **Comunicados** — carousel condicional
4. **Férias da equipe**
5. **Últimas Atividades**

**Sidebar `.hd-sidebar` — ordem imutável:**
1. **Aniversariantes da equipe**
2. **Tempo de Casa**

**Nunca reorganizar a ordem dos blocos nem mover sidebar para a coluna principal.**

### Responsivo

| Breakpoint | Comportamento |
|---|---|
| `>900px` | Grid 2 colunas, sidebar sticky |
| `≤900px` | Grid 1 coluna; sidebar vira `grid 1fr 1fr` (cards lado a lado) |
| `≤700px` | Grid 1 coluna; sidebar vira `grid 1fr` (empilhado) |

### Cards de Eventos (Aniversários e Tempo de Casa) — sidebar

- Ficam no `.hd-sidebar` (coluna direita), um abaixo do outro
- Header do card: ícone colorido (36px, bolo = âmbar, relógio = verde) + título + botão "Ver todos →"
- **Card exibe os 3 primeiros** registros mais próximos (limite visual para compactação)
- **Apresentação no sidebar: lista vertical** — CSS override em `.hd-sidebar .hd-person-*`
  - `.hd-person-grid`: `flex-direction:column` (era horizontal com scroll)
  - `.hd-person-col`: `flex-direction:row; align-items:center; gap:10px` — avatar à esquerda + info à direita
  - `.hd-person-info`: wrapper `div` que agrupa nome + detalhe (necessário para layout row) — gerado por `_personColHtml`
  - Avatar 38px no sidebar; `ring-today` (amber) e `ring-top` (verde) preservados
  - Nome: 2 primeiros nomes, 13px, text-overflow:ellipsis, alinhado à esquerda
  - **Aniversários:** data em `hd-person-date-sm` ou `hd-today-pill` — alinhamento left
  - **Tempo de Casa:** anos em `hd-years-text` + data em `hd-person-date-sm`
  - **Marco de tempo de casa:** troféu 🏆 (`.hd-marco-icon`) inline após os anos — preservado
- **Regra de data para Tempo de Casa:** `_refCasa = c.data_ingresso_grupo || c.data_admissao` — mesma regra do Relatório Tempo de Casa e do Cadastro. **Nunca usar `c.data_admissao` direto** para calcular anos ou aniversário de empresa — colaboradores com ingresso anterior ao contrato atual ficariam com tempo incorreto (commit `25b3262`)
- Linha divisória `border-bottom: 1px solid var(--border)` entre cada pessoa (exceto última)
- No breakpoint ≤900px: layout horizontal é restaurado (CSS revert) pois sidebar vira 2 colunas

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
- **`_openModal` é função global** (escopo de script), não local a `_renderEventos` — acessível por qualquer função da Home

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

**Assinatura:** `_renderFerias(feriasData, periodosList, emGozo, hoje, colabMap)`

**Fonte de dados — `periodosList`** (construído em `renderHomeGestor` após o fetch):
- Cada row da tabela é "explodida" em entradas individuais `{ colaborador_id, inicio, fim }`
- Fonte principal: itens de `periodos[]` JSONB com `status` aprovado ou agendado (exclui cancelado/excluido)
- Fallback: campos flat `periodo1_inicio/fim` e `periodo2_inicio/fim` quando `periodos=[]` (registros legados)
- `emGozo`: períodos onde `ini <= hoje <= fim`, deduplicados por `colaborador_id`
- `proximos`: períodos com `ini > hoje` e `ini - hoje <= 30 dias`, deduplicados por `colaborador_id`

**Visual — dois stats lado a lado:**
- Número grande colorido (`active` = âmbar para em gozo; `next` = azul para agendadas)
- Label abaixo do número
- Stack de avatares sobrepostos (`.hd-ferias-stack`): máximo 5 fotos visíveis + indicador `+N` para excedentes
  - Avatares 28px, sobrepostos com `margin-left: -8px`, borda `var(--surface)` para efeito premium
  - Foto real via `background-image` quando `foto_url` disponível; iniciais coloridas como fallback
  - Indicador `+N` usa `.hd-ferias-stack-more` (fundo cinza neutro)
- Linha de nomes resumida (`.hd-ferias-stack-nomes`): até 2 primeiros nomes + "e mais N"
- **Botão "Ver todos →"** — aparece sempre que há colaboradores na categoria (nunca omitido por quantidade)
  - Em gozo: abre modal com detalhe em âmbar
  - Agendadas: abre modal com detalhe em verde
  - Modal: `_openModal` com foto + nome + cargo + setor + período (`DD/MM → DD/MM · N dias`)
  - Classe `.hd-ferias-vertodos` — fica no rodapé de cada coluna (não no header do card, pois são dois grupos independentes)
  - **Padrão visual alinhado ao `.hd-ver-todos`:** `font-weight:500`, `white-space:nowrap`, `text-decoration:none` (commit `cf5db31`)
- Quando count = 0: stack, linha de nomes e botão não são renderizados (sem espaço vazio)

---

## HTML da Home — IDs relevantes

| ID | Elemento | Container | Preenchido por |
|---|---|---|---|
| `hd-gestor-av` | Avatar do gestor | `.hd-main` | `renderHomeGestor` |
| `hd-greeting-title` | "Boa tarde, Nome!" | `.hd-main` | `renderHomeGestor` |
| `hd-greeting-meta` | "Grupo · N colabs · Perfil" | `.hd-main` | `renderHomeGestor` |
| `hd-team-row` | Mini-avatares da equipe | `.hd-main` | `renderHomeGestor` |
| `hd-date-weekday` / `hd-date-full` | Data | `.hd-main` | `renderHomeGestor` |
| `hd-mod-row` | Grid de módulos | `.hd-main` | `_renderModules` |
| `hd-avisos-wrap` | Wrapper carousel | `.hd-main` | `_renderAvisos` |
| `hd-aniv-list` | Lista aniversários | `.hd-sidebar` | `_renderEventos` |
| `hd-casa-list` | Lista tempo de casa | `.hd-sidebar` | `_renderEventos` |
| `hd-aniv-vertodos` | Botão "Ver todos" aniversários | `.hd-sidebar` | `_renderEventos` |
| `hd-casa-vertodos` | Botão "Ver todos" tempo de casa | `.hd-sidebar` | `_renderEventos` |
| `hd-ferias-stats` | Stats de férias | `.hd-main` | `_renderFerias` |
| `hd-act-list` | Lista de atividades | `.hd-main` | `_renderAtividades` |
| `hd-bell-wrap` | Wrapper do sino | topbar | `renderHomeGestor` |
| `hd-bell-btn` | Botão do sino | topbar | `_toggleBellPanel` |
| `hd-bell-badge` | Badge numérico vermelho | topbar | `_loadPendencias` |
| `hd-bell-panel` | Painel suspenso de pendências | topbar | `_toggleBellPanel` / `_bellExpandir` |

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

## Comunicados da Home (`_renderAvisos`)

### Visão geral

Bloco condicional posicionado entre `#hd-mod-row` (módulos) e `#hd-evt-row` (eventos da equipe). Aparece **somente quando há avisos ativos** para o perfil do usuário; quando vazio, fica `display:none` sem ocupar espaço.

### Carousel v2 (commits `fd8b9d2`, `bac3107`, `534f8be`, out/2026)

**Layout HTML gerado por `_renderAvisos`:**

```
.hd-avisos-wrap [.single quando 1 aviso]
  .hd-avisos-hd
    .hd-avisos-hd-left
      .hd-avisos-title-group  ← ícone megafone + título + badge count
      .hd-avisos-subtitle     ← "Fique por dentro das novidades..."
    button.hd-avisos-ver-todos
  .hd-avisos-carousel  ← display:flex; align-items:center; gap:6px
    [button.hd-avisos-arrow#hd-avisos-prev]  ← só quando multi
    .hd-avisos-viewport  ← flex:1; overflow:hidden
      .hd-avisos-track    ← display:flex; gap:12px; transform via JS
        .hd-aviso-card.{tipo}  (× N cards)
    [button.hd-avisos-arrow#hd-avisos-next]  ← só quando multi
  [.hd-avisos-dots]  ← só quando multi, abaixo do carousel
```

**Card interno:**
```
.hd-aviso-card.{tipo}
  .hd-aviso-card-top
    .hd-aviso-badge-tipo.{tipo}   ← badge sólido escuro (urgente=#c53030, info=#2b6cb0, lembrete=#b7791f)
    .hd-aviso-tipo-icon.{tipo}    ← círculo 42px com SVG
  .hd-aviso-card-titulo
  .hd-aviso-card-corpo            ← 3 linhas max, opcional
  .hd-aviso-card-footer
    .hd-aviso-card-footer-date    ← ícone calendário + "Publicado em DD/MM/AAAA"
    .hd-aviso-card-footer-arrow   ← círculo 22px com seta
```

**Ícone da seção:** megafone (`<svg viewBox="0 0 24 24"><path d="M3 11l19-9-9 19-2-8-8-2z"/></svg>`) — **não usar sino** (já existe sino de notificações na topbar).

**Comportamento por quantidade:**
- 1 aviso (`!multi`): wrap recebe classe `.single`; card expande `flex:0 0 100%`; setas e bolinhas não renderizadas
- 2+ avisos: setas laterais + bolinhas abaixo; `_avisosSetIdx` calcula largura do card por `track.parentElement.offsetWidth`

### Função `_renderAvisos(perfil)`

```js
async function _renderAvisos(perfil) {
  // Chamada em renderHomeGestor após _renderModules(p)
  // perfil = (p.perfil || '').toLowerCase()
}
```

- Busca `param_aviso_home` com `ativo=eq.true&data_inicio=lte.${hoje}`
- Campos selecionados: `id, titulo, corpo, tipo, publico, colaboradores_ids, data_fim`
- Filtra no JS (segunda camada de segurança):
  - Descarta `data_fim < hoje`
  - Exibe se `publico.includes('todos')`, `publico.includes(perfil)` ou `colaboradores_ids.includes(p.colaborador_id)`
- RLS já garante no banco que o usuário recebe apenas os avisos permitidos

### Tabela `param_aviso_home`

| Coluna | Tipo | Descrição |
|---|---|---|
| `id` | SERIAL PK | — |
| `titulo` | TEXT NOT NULL | Texto breve |
| `corpo` | TEXT | Mensagem completa (opcional) |
| `tipo` | TEXT | `'info'` \| `'lembrete'` \| `'urgente'` |
| `publico` | TEXT[] | Perfis destinatários ex: `['gestor','rh']` ou `['todos']` |
| `colaboradores_ids` | INTEGER[] | Pessoas específicas (nullable) |
| `data_inicio` | DATE | Início da exibição |
| `data_fim` | DATE | Fim da exibição (NULL = sem limite) |
| `ativo` | BOOLEAN | Liga/desliga imediato |

**Migrations 117 e 118** — ambas executadas em produção.

### RLS (pós migration 118)

```sql
USING (
  'todos' = ANY(publico)
  OR auth_perfil() = ANY(publico)
  OR (auth_colaborador_id() IS NOT NULL
      AND colaboradores_ids IS NOT NULL
      AND colaboradores_ids @> ARRAY[auth_colaborador_id()])
  OR auth_perfil() IN ('admin', 'rh')
);
-- ALL (write): somente admin e rh
USING (auth_perfil() IN ('admin', 'rh'))
```

### CSS principal

```css
.hd-avisos-wrap          { display:flex; flex-direction:column; gap:10px }
.hd-avisos-carousel      { display:flex; align-items:center; gap:6px }
.hd-avisos-viewport      { flex:1; overflow:hidden; min-width:0 }
.hd-aviso-card           { flex:0 0 calc((100% - 24px)/3); padding:14px; gap:8px; border-radius:12px }
.hd-avisos-wrap.single .hd-aviso-card { flex:0 0 100% }  /* card único preenche toda a largura */
.hd-aviso-card.urgente   { background:#fff5f5; border-color:#fed7d7 }
.hd-aviso-card.info      { background:#ebf4ff; border-color:#bee3f8 }
.hd-aviso-card.lembrete  { background:#fffbeb; border-color:#fcd34d }
.hd-aviso-badge-tipo.urgente   { background:#c53030; color:#fff }
.hd-aviso-badge-tipo.info      { background:#2b6cb0; color:#fff }
.hd-aviso-badge-tipo.lembrete  { background:#b7791f; color:#fff }
.hd-aviso-tipo-icon      { width:42px; height:42px; border-radius:50% }
```

### Espaçamento global da Home (ajustado out/2026)

```css
.home-dash { gap:10px; padding:20px 24px 40px }  /* era gap:12px, padding:24px 24px 48px */
```

---

## Bell de pendências (Gestor)

### Visão geral

O sino na topbar (visível apenas para Gestor) é um painel geral de acompanhamento de férias.
Exibe **duas categorias** de itens pendentes, com badge numérico e pulso visual para chamar
atenção. Ao clicar, abre painel suspenso com a lista diferenciada por categoria.

### Funções envolvidas

| Função | Responsabilidade |
|---|---|
| `_loadPendencias(teamIds, team)` | Busca histórico + tabela ferias, deduplica, classifica, armazena em `_bellItens`, atualiza badge |
| `_toggleBellPanel(e)` | Abre/fecha o painel; renderiza os primeiros `_BELL_PAGE_SIZE` (5) itens |
| `_bellExpandir()` | Expande o painel com todos os itens restantes — **sem navegar** |
| `_renderBellLista(itens)` | Gera HTML dos itens com dot colorido + chip de categoria |
| `_getItemHref(h)` | Mapa extensível: `acao → módulo → href` |

### Duas categorias

| Categoria | `_categoria` | Ações | Dot | Chip | Janela |
|---|---|---|---|---|---|
| Aguardando Ciente | `'ciente'` | `aprovado`, `rejeitado`, `alteracao_aprovada`, `alteracao_recusada`, `cancelamento_aprovado`, `cancelamento_recusado` | Azul | "Ag. Ciente" | `dias_resposta_visivel` (7 dias) |
| Aguardando RH | `'aguardando_rh'` | `solicitado`, `alteracao_solicitada`, `cancelamento_solicitado` | Âmbar | "Ag. RH" | Sem limite — item permanece até RH responder |

Itens "Ag. Ciente" aparecem primeiro no painel (requerem ação do Gestor).

### Lógica de `_loadPendencias` — três fontes em paralelo

```
Promise.all([
  ferias_historico (colaborador_id=in.(teamIds), limit=500),
  param_ferias_config (dias_resposta_visivel),
  ferias (status=in.(Solicitado,solicitado,Pendente,pendente,...), fallback)
])
```

**Passo 1 — deduplicação do histórico:** para cada `ferias_id`, mantém o evento com `criado_em` mais recente (espelho de `_gestorAgruparProcessos`).

**Passo 2 — fallback da tabela `ferias`:** registros com status "solicitado/pendente" na tabela `ferias` sem entrada no `ferias_historico` são injetados como `{ acao:'solicitado', _fallback:true }`. Isso cobre solicitudes anteriores ao audit log. O historico **sempre** prevalece sobre o fallback no mesmo `ferias_id`.

**Passo 3 — classificação:**
- `ACOES_CIENTE` → categoria `ciente`, respeita `dias_resposta_visivel`
- `ACOES_AGUARDANDO` → categoria `aguardando_rh`, sem janela de tempo
- Demais ações (`gestor_ciente`, `lancado_rh`, etc.) → ignoradas silenciosamente

**Passo 4 — validação de órfãos:** candidatos `aguardando_rh` vindos do histórico (não fallback) são cruzados com a tabela `ferias` para descartar `ferias_id` que não existem mais. Candidatos fallback têm existência garantida pela query direta.

**Passo 5 — ordenação:** `ciente` antes de `aguardando_rh`; dentro de cada grupo, `criado_em` desc.

### Badge visual

- Tamanho: 18px × 18px, border-radius 9px
- Animação: `bell-pulse` — `box-shadow` vermelho translúcido expande e some a cada 2,4s
- Ativo apenas quando `_bellItens.length > 0`

### Extensão para novos módulos

Para adicionar um novo tipo de notificação:

1. Inserir as ações em `_BELL_MODULO_MAP` com o nome do módulo destino
2. Inserir o módulo e `href` em `_BELL_MODULO_HREF`
3. Inserir labels em `_BELL_ACAO_LABEL`
4. Incluir as ações nos sets `ACOES_CIENTE` ou `ACOES_AGUARDANDO` dentro de `_loadPendencias`
5. Adicionar query à tabela de histórico do novo módulo na `Promise.all`

```js
const _BELL_MODULO_MAP  = { aprovado:'ferias', solicitado:'ferias', /* futuro: avaliacao_concluida:'desenvolvimento' */ };
const _BELL_MODULO_HREF = { ferias:'modulos/ferias/index.html',     /* futuro: desenvolvimento:'modulos/desenvolvimento/index.html' */ };
```

### Comportamento do painel

- Exibe os primeiros 5 itens (`_BELL_PAGE_SIZE`)
- Se houver mais: botão `Ver mais N itens` expande **dentro do painel** (`_bellExpandir`) — sem navegar
- Cada item tem dot colorido + chip de categoria + label da ação + horário relativo
- Fecha ao clicar fora (listener `click` no `document`, removido após uso)
- Se `_bellItens` estiver vazio: exibe "Sem pendências no momento."

### Tolerância a falhas

- `_loadPendencias` chamado com `.catch(() => {})` — não impede o carregamento da Home
- Todas as três queries têm `.catch(() => [])` — fallback para array vazio em erro de rede
- Se `hd-bell-badge` não existir no DOM, a função retorna silenciosamente

---

## Topbar — variante Gestor

Classe `.topbar-gestor` adicionada via JS no início de `renderHomeGestor`:
```js
document.querySelector('.topbar').classList.add('topbar-gestor');
```
Fundo branco, texto escuro, sombra sutil. Aplicada **somente** para perfil Gestor — outros
perfis mantêm a topbar escura (`.topbar` sem a classe).

### Botão Sair na topbar branca

O botão Sair usa a classe compartilhada `.btn-sair` (definida em `shared.css`). O override para
topbar branca está em `index.html`:

```css
/* Override — botão Sair na topbar branca (Home Gestor) */
.topbar-gestor .btn-sair { border-color:var(--border); color:var(--text-ter); background:var(--bg); }
.topbar-gestor .btn-sair:hover { border-color:var(--text-sec); color:var(--text); background:var(--border); }
```

Futuras Homes de RH/Diretoria com topbar branca: adicionar `.topbar-<perfil> .btn-sair { ... }` com os mesmos tokens.
Futuras Homes com topbar azul: herdam `.btn-sair` de `shared.css` automaticamente — sem override.

---

## Recursos compartilhados — `shared.css`

`shared.css` (raiz do projeto) é a fonte única de estilos reutilizáveis entre módulos e Homes.
Carregado em `index.html` via `<link rel="stylesheet" href="shared.css">`.
Nos módulos, carregado automaticamente via `permissoes.js` (injeção no `<head>`).

**Componentes disponíveis:**
- `.btn-sair` — botão Sair com ícone SVG + texto "Sair" (padrão topbar azul)

**Regra:** novas classes compartilhadas entre 2+ telas vão em `shared.css`, nunca inline em cada arquivo.

---

## Regras de expansão futura

1. **RH e Diretoria:** NÃO implementar ainda. Validar Home do Gestor em produção primeiro.
2. **Nova view/query:** sempre verificar se não expõe dados salariais.
3. **Nova constante usada na Home:** colocar no bloco de constantes antes da IIFE.
4. **Novo módulo no menu:** adicionar entrada no array `ALL_MODS` dentro de `_renderModules`.
5. **A Home é somente leitura:** nenhuma operação de escrita deve ser adicionada a ela.
6. **Modal de consulta:** sempre usar `_avHtml` — nunca recriar lógica de avatar.
7. **Cargo e setor no modal:** já disponíveis na query de equipe — não adicionar nova query.
8. **Novo módulo no sino:** ver seção "Extensão para novos módulos" acima.

---

## Histórico de bugs resolvidos (referência)

| Bug | Causa raiz | Fix |
|---|---|---|
| Foto do gestor nunca aparecia | `_HD_URL` em TDZ — `_hdGet` silenciava com `catch→[]` | Mover `_HD_URL`/`_HD_KEY` para antes da IIFE (commit `e766d3e`) |
| `gc = []` sem erro no console | `_hdGet` tem `try/catch` global que engole TDZ ReferenceError | Diagnóstico: substituir `_hdGet` por `fetch` direto para ver status HTTP bruto |
| Migration 111 | View expõe `resumo_home` sem dados salariais | Executada 2026-10-08, status: ✅ |
| Fotos não apareciam no modal | Modal criava `<div>` de avatar manualmente em vez de usar `_avHtml` | Substituir por `_avHtml(r.nome, r.foto_url, 'hd-modal-av')` |
| Botão "Ver todos" em Férias não abria modal | `_openModal` era `function` local dentro de `_renderEventos` — inacessível para `_renderFerias` | Mover `_openModal` para escopo global, antes de `_renderEventos` (commit `5f8a1be`) |
| Leandro (e outros com ingresso anterior ao contrato) apareciam com tempo de casa errado | `_colSelectHome` não buscava `data_ingresso_grupo`; cálculo usava `c.data_admissao` direto | Adicionar `data_ingresso_grupo` na query e usar `_refCasa = c.data_ingresso_grupo \|\| c.data_admissao` (commit `25b3262`) |
| Bell contava ações com nomes errados | `alteracao_rejeitada` / `cancelamento_rejeitado` não existem — nomes corretos são `alteracao_recusada` / `cancelamento_recusado` | Corrigir `ACOES_CIENTE` (commit `6542425`) |
| Bell mostrava só 2 de 5 pendências | Solicitudes antigas sem entrada em `ferias_historico` (anteriores ao audit log) eram invisíveis ao bell | Fallback via tabela `ferias` com merge — espelha `renderGestorAtividade` (commit `92595b2`) |
