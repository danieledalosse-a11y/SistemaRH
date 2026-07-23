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
├── docs/
│   ├── empresas.md          # CNPJs e razões sociais das 11 empresas do grupo
│   ├── estrutura.md         # Roadmap de módulos
│   └── schema-cadastro.md   # Schema Supabase documentado
├── modulos/
│   ├── cadastro/
│   │   ├── CLAUDE.md
│   │   └── index.html       # Módulo de cadastro de colaboradores
│   └── ferias/
│       ├── CLAUDE.md        # Regras detalhadas do módulo férias
│       ├── index.html       # Módulo principal (~3.200 linhas, CSS+JS inline)
│       └── index.BACKUP.html
└── .claude/launch.json
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

## Módulos implementados

1. **Cadastro** — consulta e ficha de colaboradores (`modulos/cadastro/`)
2. **Férias** — períodos aquisitivos, lançamentos e aprovações (`modulos/ferias/`)

## Módulos planejados

3. Painel de Colaboradores + Indicadores
4. Medicina e Segurança / Treinamentos / Benefícios
5. Ponto, Folha, Comissões

## Preferências da usuária (RH)

- Nunca abreviar valores monetários (`R$ 12.500,00`, não `12,5k`)
- Apresentar proposta antes de implementar — aguardar aprovação
- Respostas curtas e diretas
- Soluções simples que possam evoluir, em vez de complexas desde o início
