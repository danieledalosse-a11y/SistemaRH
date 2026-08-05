# Sistema RH — Revest do Brasil Acabamentos Ltda

## O que é este projeto

Sistema interno de RH da Revest do Brasil. Aplicação web local — HTML + CSS + JS puro, sem framework.
Backend: **Supabase** (PostgreSQL + REST API). Cada módulo é um `index.html` com CSS e JS inline.

## Stack técnica

- **Frontend:** HTML + CSS + JS puro (sem React/Vue/Angular)
- **Backend:** Supabase — `https://rujtbxwssiofiialnbbg.supabase.co`
  - Chave publicável (browser): começa com `eyJ...` — usada inline no JS de cada módulo
  - Chave secreta: usada apenas em scripts Python de manutenção (nunca no browser)
- **Servidor de preview:** `npx serve -l 5500` (config em `.claude/launch.json`, nome `"ferias"`)

## Estrutura de pastas

```
SistemaRH/
├── CLAUDE.md
├── index.html               # Home — cards de módulos
├── login.html               # Tela de login (auth via Supabase)
├── admissao-online.html     # Formulário do candidato (sem login)
├── docs/
│   ├── empresas.md          # CNPJs e razões sociais das 11 empresas do grupo
│   ├── estrutura.md         # Roadmap de módulos
│   └── schema-cadastro.md   # Schema Supabase documentado
├── modulos/
│   ├── cadastro/
│   │   ├── CLAUDE.md
│   │   └── index.html       # Módulo de cadastro de colaboradores
│   ├── ferias/
│   │   ├── CLAUDE.md        # Regras detalhadas do módulo férias
│   │   ├── index.html       # Módulo principal (~3.500 linhas, CSS+JS inline)
│   │   └── index.BACKUP.html
│   ├── admissao/
│   │   └── index.html       # Painel RH de admissão (review de fichas, efetivar)
│   └── desenvolvimento/
│       └── index.html       # Módulo Desenvolvimento & Performance
├── scripts/
│   └── setup_desenvolvimento.py  # Seed das competências iniciais (rodar 1x)
└── .claude/
    ├── launch.json
    └── agents/
        ├── ferias.md
        └── admissao.md
```

## Empresas do grupo

Ver `docs/empresas.md` para CNPJs completos.

| Código | Abrev | Empresa |
|---|---|---|
| 0148 | Matriz | Revest do Brasil Acabamentos Ltda Matriz |
| 2148 | CD | Revest do Brasil Acabamentos Ltda CD |
| 3148 | Atelier | Revest do Brasil Acabamentos Ltda Atelier |
| 4148 | Paranavaí | Revest do Brasil Acabamentos Ltda Paranavaí |
| 5148 | Porto Rico | Revest do Brasil Acabamentos Ltda Porto Rico |
| 0167 | Metalshop | Revest Metalshop Comercio de Materiais de Construção Eireli |
| 0584 | JP | JP Revestimentos Ltda |
| 0392 | Log | Revestlog Acabamentos Ltda |

## Padrões de código

- Arquivo único por módulo (`index.html`) — CSS e JS inline
- Variáveis globais em `let` no topo do script
- Funções de render: prefixo `render` (ex: `renderCalendario`, `renderListaAnual`)
- Funções de filtro: prefixo `filtrar` ou `popular`
- IDs HTML em camelCase descritivo (ex: `lancarBusca`, `filtroAtivoLista`)
- Datas internas sempre `YYYY-MM-DD`; exibição via `formatDate()` como `DD/MM/AAAA`
- Nunca usar `innerHTML` com dados de usuário sem sanitizar

## Acesso e perfis

| Perfil | Vê | Pode lançar | Pode aprovar |
|---|---|---|---|
| RH | Todos os colaboradores | Sim | Sim |
| Gestor | Apenas sua equipe | Sim | Não |

## Regras gerais de colaboradores

- `pro_labore = true` → excluído de todos os módulos operacionais
- Ativo/Inativo: determinado por `data_demissao` preenchida no Supabase
- Chave de identidade entre módulos: matrícula do colaborador
- Matrículas **podem se repetir entre empresas diferentes** — identificação correta requer matrícula + nome

## Deploy

- **GitHub Pages** — branch `main` do repositório `danieledalosse-a11y/SistemaRH`
- URL: `https://danieledalosse-a11y.github.io/SistemaRH`
- Deploy automático após push (1–3 min de delay)
- **Não usar Netlify** — migrado para GitHub Pages

## Módulos implementados

| # | Módulo | Caminho | Skill |
|---|---|---|---|
| 1 | Cadastro | `modulos/cadastro/index.html` | — |
| 2 | Férias | `modulos/ferias/index.html` | `ferias` |
| 3 | Admissão Online (candidato) | `admissao-online.html` | `admissao` |
| 4 | Admissão (painel RH) | `modulos/admissao/index.html` | `admissao` |
| 5 | Desenvolvimento & Performance | `modulos/desenvolvimento/index.html` | `desenvolvimento` |

## Módulos planejados

- Indicadores (turnover, headcount, absenteísmo)
- Medicina e Segurança / Treinamentos
- Ponto, Folha, Comissões

## Preferências da usuária (RH)

- Nunca abreviar valores monetários (`R$ 12.500,00`, não `12,5k`)
- Apresentar proposta antes de implementar — aguardar aprovação
- Respostas curtas e diretas
- Soluções simples que possam evoluir, em vez de complexas desde o início
