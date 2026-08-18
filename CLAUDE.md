# Sistema RH — Revest do Brasil Acabamentos Ltda

## O que é este projeto

Sistema interno de RH da Revest do Brasil. Aplicação web — **HTML + CSS + JS puro, sem framework, sem build step**.
Backend: **Supabase** (PostgreSQL + REST API via PostgREST). Cada módulo é um `index.html` com CSS e JS inline.

## Stack técnica

- **Frontend:** HTML + CSS + JS puro (sem React/Vue/Angular)
- **Backend:** Supabase — `https://rujtbxwssiofiialnbbg.supabase.co`
  - Chave publicável (usada inline nos módulos JS): ver memory `supabase_config`
  - Chave secreta (apenas em scripts Python de manutenção, nunca no browser): ver memory `supabase_config`
- **Autenticação:** Supabase Auth — token JWT em `localStorage.sb_session`, perfil em `localStorage.sb_perfil`

## Deploy

- **GitHub Pages** — branch `main` do repositório `danieledalosse-a11y/SistemaRH`
- URL pública: `https://danieledalosse-a11y.github.io/SistemaRH`
- Deploy automático após push (CDN leva 5–15 min para propagar)
- **Não usar Netlify** — migrado para GitHub Pages

## Estrutura de pastas

```
SistemaRH/
├── CLAUDE.md
├── index.html                    # Home — cards de módulos
├── login.html                    # Tela de login (Supabase Auth)
├── admissao-online.html          # Formulário do candidato (sem login)
├── docs/
│   ├── empresas.md               # CNPJs e razões sociais
│   ├── estrutura.md              # (desatualizado — usar este CLAUDE.md)
│   └── schema-cadastro.md        # (desatualizado — usar este CLAUDE.md)
├── modulos/
│   ├── cadastro/
│   │   ├── CLAUDE.md             # (desatualizado — usar este CLAUDE.md)
│   │   └── index.html            # ~3.800 linhas — módulo principal de colaboradores
│   ├── ferias/
│   │   ├── CLAUDE.md             # Regras detalhadas do módulo férias
│   │   └── index.html            # ~3.500 linhas
│   ├── processos/
│   │   └── index.html            # Módulo Workflow / Processos RH
│   ├── uniformes/
│   │   ├── index.html            # Módulo de Uniformes & EPI
│   │   └── configuracoes.html    # Config de almoxarifados, catálogo, fornecedores
│   ├── admissao/
│   │   └── index.html            # Painel RH — revisão e efetivação de candidatos
│   ├── desenvolvimento/
│   │   └── index.html            # Módulo Desenvolvimento & Performance
│   ├── colaborador/
│   │   └── index.html            # Ficha pública do colaborador (acesso do gestor)
│   └── parametros/
│       └── index.html            # Parâmetros do sistema
├── scripts/
│   └── setup_desenvolvimento.py  # Seed inicial de competências (rodar 1x)
└── .claude/
    ├── launch.json               # npx serve -l 5500 (nome: "ferias")
    └── agents/
        ├── ferias.md
        ├── admissao.md
        └── desenvolvimento.md
```

## Empresas do grupo

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

## Premissa obrigatória — Rastreabilidade e Auditoria

**Todo módulo deve registrar histórico de movimentações.** Premissa do sistema, não opcional.

- Qualquer alteração relevante gera registro em `colaboradores.historico` (coluna JSONB)
- Cada entrada: `{ tipo, detalhe, data (ISO), usuario (nome) }`
- Exibido na aba "Histórico" da ficha do colaborador no módulo Cadastro

## Padrões de código

- Arquivo único por módulo — CSS e JS inline no `index.html`
- Variáveis globais com `let` no topo do script
- Funções de render: prefixo `render`; filtro: prefixo `filtrar` ou `popular`
- IDs HTML em camelCase descritivo
- Datas internas sempre `YYYY-MM-DD`; exibição `DD/MM/AAAA`
- Nunca usar `innerHTML` com dados de usuário sem sanitizar
- **Nunca usar PowerShell `WriteAllLines` para editar arquivos** — corrompe encoding. Usar Edit tool ou Python

## Perfis de acesso

| Perfil | Vê | Pode lançar | Pode aprovar |
|---|---|---|---|
| RH | Todos os colaboradores | Sim | Sim |
| Gestor | Apenas sua equipe | Sim | Não |

---

## Módulo Cadastro (`modulos/cadastro/index.html`)

Módulo principal de gestão de colaboradores. ~3.800 linhas, CSS + JS inline.

### Tabelas Supabase principais

- **`colaboradores`** — tabela central. Campos relevantes:
  - `id` (int), `nome`, `cargo`, `setor`, `empresa`, `empresa_atuacao`, `nome_comercial`
  - `data_admissao`, `data_demissao`, `motivo_demissao`, `obs_desligamento`
  - `tipo_contrato` (CLT/PJ/Aprendiz/Estágio), `periodo_experiencia`, `dias_prorrogacao`, `data_fim_experiencia`
  - `em_experiencia` (boolean), `prorrogacao_45_gerado` (boolean), `avaliacao_90_gerado` (boolean)
  - `indicado_por_id` (FK → colaboradores.id), `indicacao_bonus_gerado` (boolean)
  - `salario`, `comissao`, `pcd`, `afastado_inss`, `primeiro_emprego`, `comissionado`
  - `historico` (JSONB — array de movimentações)
  - `foto_url`, `celular`, `whatsapp`, `cpf`, `rg`, `pis`, `cnh`
  - `naturalidade_estado`, `naturalidade_cidade`, `nacionalidade`
  - `vt` (boolean — vale transporte), `vt_valor`, `va` (boolean), `vr` (boolean)

### Workflows automáticos gerados pelo Cadastro

O Cadastro dispara automaticamente criação de processos em `processos_rh` nas situações:

| Evento | Tipo workflow | Gatilho | Flag de controle |
|---|---|---|---|
| Demissão registrada | `demissao` | Ao salvar `data_demissao` | Verifica duplicata por colaborador |
| Faltam ≤ 12 dias para fim dos 45 dias de experiência | `prorrogacao_experiencia` | `carregarDoSupabase()` | `prorrogacao_45_gerado` |
| Faltam ≤ 12 dias para fim dos 90 dias de experiência | `avaliacao_final_experiencia` | `carregarDoSupabase()` | `avaliacao_90_gerado` |
| Faltam ≤ 12 dias para completar 90 dias (colaborador com indicação) | `bonus_indicacao` | `carregarDoSupabase()` | `indicacao_bonus_gerado` |
| Demissão registrada + colaborador tem uniforme em posse | `devolucao_uniforme` | Ao salvar `data_demissao` | Verifica itens em `unif_movimentacoes` |

### Função `_sincronizarProcessoDemissao()`

Chamada ao salvar demissão. Cria `demissao` em `processos_rh` + checklist de 19 itens (aviso, benefícios, documentação rescisória, homologação). Prazos calculados a partir de `data_demissao`. Não cria duplicata se já houver processo aberto.

### Funções `verificarExperienciaWorkflows()` e `verificarBonusIndicacao()`

Chamadas em `carregarDoSupabase()`. Iteram COLABORADORES ativos em experiência / com indicação e criam workflows quando dentro da janela de 12 dias.

---

## Módulo Workflow / Processos (`modulos/processos/index.html`)

Gerencia processos RH em andamento, concluídos e cancelados.

### Tabelas Supabase

- **`processos_rh`**: `id`, `tipo`, `status` (aberto/concluido/cancelado), `colaborador_id`, `colaborador_nome`, `criado_por`, `criado_em`, `concluido_em`, `atualizado_em`, `dados_extras` (JSONB)
- **`processos_checklist`**: `id`, `processo_id` (FK), `item`, `prazo_dias`, `ordem`, `concluido`

### Tipos de processo (`TIPO_CONFIG`)

| tipo | Label | Ícone | Cor |
|---|---|---|---|
| `admissao` | Admissão | 👤 | green |
| `demissao` | Demissão | 🚪 | red |
| `reajuste` | Reajuste Salarial | 💰 | blue |
| `vt_avulso` | VT Avulso | 🚌 | purple |
| `vt_alteracao` | Alteração de VT | 🚌 | purple |
| `bonus_indicacao` | Bônus de Indicação | ⭐ | amber |
| `atestado` | Atestado > 3 dias | 📋 | amber |
| `prorrogacao_experiencia` | Prorrogação de Experiência | 📝 | amber |
| `avaliacao_final_experiencia` | Avaliação Final de Experiência | 📝 | amber |
| `devolucao_uniforme` | Devolução de Uniforme | 👕 | blue |

### Aba Em andamento

- Cards agrupados: Atrasados / Próximos (≤ 3 dias) / Em andamento
- Busca por nome ou tipo de processo
- Stripe de urgência colorida (vermelho/âmbar/verde)

### Abas Concluídos e Cancelados

- Filtro por período (30/60/90 dias / Todos)
- Busca por nome de colaborador (filtragem local no cache)
- Concluídos: ordenados por `concluido_em`
- Cancelados: ordenados por `criado_em`

### Prazos de demissão

Para tipo `demissao`, prazos calculados a partir de `dados_extras.data_demissao` (não da criação do processo).

---

## Módulo Uniformes (`modulos/uniformes/index.html`)

Controle de entrega, devolução e estoque de uniformes e EPI.

### Tabelas Supabase

| Tabela | Descrição |
|---|---|
| `unif_catalogo` | Catálogo de peças (nome, tipo, gênero, variante, logo) |
| `unif_almoxarifados` | Almoxarifados cadastrados (atualmente: Matriz e CD) |
| `unif_estoque` | Saldo por item + almoxarifado |
| `unif_entradas` | Entradas de estoque (compras/recebimentos) |
| `unif_movimentacoes` | Todas as movimentações: entrega e devolução por colaborador |
| `unif_fornecedores` | Fornecedores |
| `unif_kits` | Kits padrão por cargo |

### Campos de `unif_movimentacoes`

`id`, `colaborador_id`, `item_id`, `almoxarifado_id`, `tipo` (entrega/devolucao/nao_entregue), `condicao_devolucao` (reutilizavel/descarte/…), `tamanho`, `qtd`, `data_movimentacao`, `registrado_por`, `motivo_pendencia`, `dados_extras`

### Lógica de saldo

Saldo em poder do colaborador = entregas (tipo=entrega) − devoluções (tipo=devolucao) registradas.

---

## Módulo Férias (`modulos/ferias/index.html`)

Ver `modulos/ferias/CLAUDE.md` para regras detalhadas.

---

## Módulo Admissão Online

- `admissao-online.html` — formulário do candidato (sem login, público)
- `modulos/admissao/index.html` — painel RH: revisão de fichas, efetivação de candidatos

---

## Módulo Desenvolvimento & Performance (`modulos/desenvolvimento/index.html`)

Avaliações de competências por colaborador. Tabelas: `dev_competencias`, `dev_avaliacoes`, `dev_planos`.

---

## Preferências da usuária (RH)

- Nunca abreviar valores monetários (`R$ 12.500,00`, não `12,5k`)
- **Apresentar proposta antes de implementar — aguardar aprovação**
- Respostas curtas e diretas
- Soluções simples que possam evoluir

## Regras gerais de colaboradores

- `pro_labore = true` → excluído de todos os módulos operacionais
- Ativo/Inativo: determinado por `data_demissao` preenchida
- Matrículas podem se repetir entre empresas — identificação correta: matrícula + nome
