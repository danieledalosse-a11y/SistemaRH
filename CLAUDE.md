# Sistema RH — Revest do Brasil Acabamentos Ltda

## O que é este projeto

Sistema interno de RH da Revest do Brasil. Aplicação web — **HTML + CSS + JS puro, sem framework, sem build step**.
Backend: **Supabase** (PostgreSQL + REST API via PostgREST). Cada módulo é um `index.html` com CSS e JS inline.

## Stack técnica

- **Frontend:** HTML + CSS + JS puro (sem React/Vue/Angular)
- **Backend:** Supabase — `https://rujtbxwssiofiialnbbg.supabase.co`
  - Chave publicável (usada inline nos módulos JS): ver memory `supabase_config`
  - Chave secreta (scripts Python de manutenção — nunca no browser): ver memory `supabase_config`
- **Auth:** Supabase Auth — token JWT em `localStorage.sb_session`, perfil em `localStorage.sb_perfil`

## Deploy

- **GitHub Pages** — branch `main` → `danieledalosse-a11y/SistemaRH`
- URL: `https://danieledalosse-a11y.github.io/SistemaRH`
- Deploy automático após push (CDN: 5–15 min)
- **Não usar Netlify** — migrado para GitHub Pages

## Estrutura de pastas

```
SistemaRH/
├── CLAUDE.md                     # Esta documentação
├── index.html                    # Home — cards de módulos (RBAC aplicado)
├── login.html                    # Tela de login (Supabase Auth)
├── admissao-online.html          # Formulário do candidato (sem login)
├── modulos/
│   ├── cadastro/index.html       # ~3.800 linhas — gestão de colaboradores
│   ├── ferias/index.html         # ~6.000 linhas — controle de férias
│   ├── processos/index.html      # Workflow / Processos RH
│   ├── uniformes/index.html      # Uniformes & EPI
│   ├── uniformes/configuracoes.html  # Config de almoxarifados, catálogo, kits
│   ├── admissao/index.html       # Painel RH — revisão e efetivação de candidatos
│   ├── desenvolvimento/index.html # Desenvolvimento & Performance
│   ├── colaborador/index.html    # Ficha do colaborador (acesso gestor)
│   └── parametros/index.html     # Parâmetros do sistema (apenas admin)
├── docs/                         # Arquivos desatualizados — ignorar, usar este CLAUDE.md
├── scripts/
│   └── setup_desenvolvimento.py  # Seed inicial de competências (rodar 1x)
└── .claude/
    ├── launch.json               # npx serve -l 5500 (nome: "ferias")
    └── agents/                   # Agentes especializados por módulo
```

---

## Perfis de usuário

Definidos na tabela `usuarios_perfil` (campos: `id`, `nome`, `perfil`, `acesso_modulos[]`, `colaborador_id`).

| Perfil | Quem é | Acesso |
|---|---|---|
| `admin` | Daniele Dalosse (RH principal) | Todos os módulos + Parâmetros |
| `rh` | Heloisa, Evelyn | Módulos conforme `acesso_modulos` |
| `gestor` | Carlos, Oriel | `ferias` + `processos` (visão da própria equipe) |
| `diretoria` | diretoria@gruporevest.com.br | Apenas `ferias` (somente leitura) |
| `logistica` | Logistica | Apenas `uniformes` |

### RBAC na Home (`index.html`)

- `admin` → vê todos os cards, incluindo botão Parâmetros
- Demais perfis → apenas os módulos listados em `acesso_modulos` são exibidos
- Cards ocultados por `display:none` via JS após login

### Perfil `gestor` — comportamento especial por módulo

**Férias:** ao entrar no módulo, `IS_RH = false` → chama `initGestor()` (nunca `carregarDoSupabase()`). O gestor vê apenas:
- Painel com alertas (risco de dobra, sem agendamento, saindo em breve)
- Timeline mensal da equipe
- Lista de colaboradores da equipe com saldo e status
- Pode solicitar férias (enviadas como `pendente` para aprovação do RH)
- **Não vê:** Visão RH geral, Lançar, Minha Equipe, Histórico

**Processos:** filtro por `criado_por_user_id = USUARIO_ID` nas queries de Concluídos e Cancelados.

**Cadastro:** sem restrição de perfil implementada — acesso liberado apenas para quem tem `cadastro` em `acesso_modulos`.

### Perfil `diretoria` — comportamento especial

No módulo Férias: `IS_RH = true` (não é gestor), mas provavelmente acesso somente leitura por não ter `acesso_modulos` com cadastro/processos. A visão de diretoria não possui tela dedicada diferente — vê a mesma interface de RH do módulo de férias.

---

## Premissa obrigatória — Rastreabilidade e Auditoria

**Todo módulo deve registrar histórico de movimentações.** Premissa do sistema, não opcional.

- Qualquer alteração relevante gera registro em `colaboradores.historico` (coluna JSONB)
- Cada entrada: `{ tipo, detalhe, data (ISO), usuario (nome de quem fez) }`
- Exibido na aba "Histórico" da ficha do colaborador no módulo Cadastro

## Padrões de código

- Arquivo único por módulo — CSS e JS inline no `index.html`
- Variáveis globais com `let` no topo do script
- Funções render: prefixo `render`; filtro: prefixo `filtrar` ou `popular`
- IDs HTML em camelCase descritivo
- Datas internas sempre `YYYY-MM-DD`; exibição `DD/MM/AAAA`
- Nunca usar `innerHTML` com dados de usuário sem sanitizar
- **Nunca usar PowerShell `WriteAllLines` para editar arquivos** — corrompe encoding. Usar Edit tool do Claude ou Python

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

---

# MÓDULO CADASTRO (`modulos/cadastro/index.html`)

Módulo principal de gestão de colaboradores. ~3.800 linhas, CSS + JS inline.

## Navegação

1. **Tela de empresas** — cards com contagem de ativos por empresa
2. **Lista de colaboradores** — filtros por situação, busca por nome/matrícula, exportação Excel
3. **Ficha do colaborador** — drawer lateral com abas: Geral | Contato | Documentos | Família | Remuneração | Benefícios | Histórico

## Tabela `colaboradores` — campos principais

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | int | PK |
| `nome` | text | Nome completo (caixa alta) |
| `cargo` | text | Cargo |
| `setor` | text | Setor |
| `empresa` | text | Empresa de registro |
| `empresa_atuacao` | text | Empresa de atuação |
| `nome_comercial` | text | Unidade/nome comercial |
| `data_admissao` | date | |
| `data_demissao` | date | Preenchido = inativo |
| `motivo_demissao` | text | |
| `obs_desligamento` | text | |
| `tipo_contrato` | text | CLT / PJ / Aprendiz / Estágio |
| `periodo_experiencia` | int | Dias da 1ª etapa (padrão 45) |
| `dias_prorrogacao` | int | Dias da prorrogação (padrão 45) |
| `data_fim_experiencia` | date | Fim do contrato de experiência |
| `em_experiencia` | boolean | Ainda no período de experiência |
| `prorrogacao_45_gerado` | boolean | Flag: workflow de 45 dias já criado |
| `avaliacao_90_gerado` | boolean | Flag: workflow de 90 dias já criado |
| `indicado_por_id` | int FK | ID do colaborador que fez a indicação |
| `indicacao_bonus_gerado` | boolean | Flag: workflow de bônus já criado |
| `salario` | numeric | Salário base |
| `pcd` | boolean | Pessoa com deficiência |
| `afastado_inss` | boolean | Afastado pelo INSS |
| `primeiro_emprego` | boolean | |
| `comissionado` | boolean | |
| `historico` | jsonb | Array de movimentações para auditoria |
| `foto_url` | text | URL da foto |
| `celular`, `whatsapp` | text | |
| `cpf`, `rg`, `pis`, `cnh` | text | |
| `naturalidade_estado`, `naturalidade_cidade` | text | |
| `nacionalidade` | text | Brasileiro(a) / Estrangeiro(a) |
| `vt` | boolean | Vale Transporte |
| `vt_valor` | numeric | |
| `va`, `vr` | boolean | Vale Alimentação / Refeição |
| `gestor` | text | Nome do gestor responsável |
| `codigo` | text | Matrícula |

## Workflows automáticos gerados pelo Cadastro

Ao salvar demissão ou ao carregar (`carregarDoSupabase()`), o módulo dispara criação automática de processos:

| Situação | Tipo de workflow | Gatilho | Flag anti-duplicata |
|---|---|---|---|
| Demissão registrada | `demissao` | salvar `data_demissao` | verifica processo aberto existente |
| Demissão + colaborador tem uniforme | `devolucao_uniforme` | salvar `data_demissao` | verifica processo aberto existente |
| Faltam ≤ 12 dias para fim dos 45 dias | `prorrogacao_experiencia` | `carregarDoSupabase()` | `prorrogacao_45_gerado` |
| Faltam ≤ 12 dias para fim dos 90 dias | `avaliacao_final_experiencia` | `carregarDoSupabase()` | `avaliacao_90_gerado` |
| Faltam ≤ 12 dias para 90 dias (com indicação) | `bonus_indicacao` | `carregarDoSupabase()` | `indicacao_bonus_gerado` |

### Função `_sincronizarProcessoDemissao()`
Cria processo `demissao` + checklist de 19 itens. Prazos calculados a partir de `data_demissao`. Não duplica.

### Função `_criarWorkflowDevolucaoUniforme()`
Verifica `unif_movimentacoes` (tipo=entrega) antes de criar. Checklist: receber → avaliar → registrar no módulo Uniformes → confirmar estoque.

### Funções `verificarExperienciaWorkflows()` e `verificarBonusIndicacao()`
Rodam em `carregarDoSupabase()`. Janela de 12 dias para os três tipos.

## Campo Indicação

- Checkbox "Foi indicado" → exibe busca de colaborador indicador
- `indicado_por_id` salvo no banco
- Se indicador não estiver em `COLABORADORES` local (outra unidade/demitido), busca direto no Supabase pelo ID

---

# MÓDULO WORKFLOW / PROCESSOS (`modulos/processos/index.html`)

## Abas

| Aba | Conteúdo |
|---|---|
| Em andamento | Cards ativos, agrupados por urgência |
| Concluídos | Histórico com filtro de período + busca por nome |
| Cancelados | Histórico com filtro de período + busca por nome |
| Novo processo | Formulário para criar processo manualmente |

## Tabelas Supabase

- **`processos_rh`**: `id`, `tipo`, `status` (aberto/concluido/cancelado), `colaborador_id`, `colaborador_nome`, `criado_por`, `criado_por_user_id`, `criado_em`, `concluido_em`, `atualizado_em`, `dados_extras` (JSONB)
- **`processos_checklist`**: `id`, `processo_id`, `item`, `prazo_dias`, `ordem`, `concluido`

## Tipos de processo (`TIPO_CONFIG`)

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

## Checklists padrão

### Admissão (19 itens, agrupados em `GRUPOS_ADMISSAO`)
- 📋 Documentação & Comunicação
- 🖥️ Sistemas (Fronter, e-mail TI, Sênior)
- 💳 Benefícios (VT, VA, VG, Alelo Pagamento)
- 🛡️ Planos & Seguros (Mixtra, Wellhub, Corplife, Seguro de Vida)
- 🪪 Uniforme & Crachá

### Demissão (19 itens, agrupados em `GRUPOS_DEMISSAO`)
- 📋 Comunicação & Registro (aviso prévio, ponto, arte de desligamento)
- 💳 Benefícios & Acessos (VA, VT, Plano de Saúde, Seguro, sistemas)
- 📄 Documentação Rescisória (verbas, uniforme, exame, rescisão, FGTS)
- 🤝 Homologação

## Regras de prazos

- Tipo `demissao`: prazos calculados a partir de `dados_extras.data_demissao` (não da criação)
- Demais tipos: prazos calculados a partir de `criado_em`
- Stripe de urgência: vermelho (vencido) / âmbar (vence hoje) / verde (ok)
- Agrupamento em andamento: **Atrasados** → **Próximos (≤ 3 dias)** → **Em andamento**

## Filtros

- Em andamento: busca por nome ou tipo de processo
- Concluídos: filtro período (30/60/90/Todos) + busca por nome (cache local)
- Cancelados: filtro período + busca por nome (cache local)
- Concluídos ordena por `concluido_em`; Cancelados ordena por `criado_em`

## Lógicas de negócio especiais no Workflow

1. **Bônus de indicação automático** — `verificarBonusIndicacao()` roda no `init()`. Cria processo `bonus_indicacao` quando faltam ≤ 12 dias para o indicado completar 90 dias. Valor do bônus lido de `param_bonus_indicacao` (registro com `vigencia_fim = null`).
2. **Efeito automático de VT** — ao concluir o item de VT em processos `admissao` ou `vt_alteracao`, `_aplicarEfeitoVT()` atualiza `vt`, `vt_cartao`, `vt_passes`, `vt_linha` no colaborador e registra no `historico` JSONB.
3. **Cancelamento de demissão reverte o cadastro** — ao cancelar processo `demissao`, o sistema limpa `data_demissao` e `motivo_demissao` do colaborador, reativando-o automaticamente.
4. **Conclusão com pendências** — exige justificativa; salva em `dados_extras.conclusao_justificativa`.
5. **Admissão de vendedor** — item "Pedir cartão Alelo Pagamento" (prazo 3 dias) inserido no checklist somente se cargo contiver "vendedor".

## Campos extras por tipo (`dados_extras`)

| tipo | Campos |
|---|---|
| `reajuste` | `salario_novo`, `data_vigencia` |
| `vt_alteracao` | `operacao` (inclusao/cancelamento), `vt_cartao`, `vt_passes`, `vt_linha`, `motivo` |
| `vt_avulso` | `linha_vt`, `valor` |
| `bonus_indicacao` | `indicado_id`, `indicado_nome`, `data_conclusao_experiencia`, `mes_folha`, `valor_bonus` |
| `atestado` | `data_atestado`, `dias_afastamento`, `cid` |
| `demissao` | `data_demissao`, `motivo`, `motivo_cancelamento`, `conclusao_justificativa` |
| `devolucao_uniforme` | `data_demissao`, `qtd_itens` |

## Perfil gestor

Nas queries de Concluídos e Cancelados adiciona `&criado_por_user_id=eq.{USUARIO_ID}`.

---

# MÓDULO FÉRIAS (`modulos/ferias/index.html`)

Ver também `modulos/ferias/CLAUDE.md` para detalhes técnicos de implementação.

## Visão RH (perfil `rh` / `admin` / `diretoria`)

### Abas principais

| Aba | Função |
|---|---|
| Visão RH | Lista anual + Calendário mensal (sub-abas com toggle) |
| Lançar | Lançamento de férias por colaborador |
| Minha Equipe | Visão simplificada da equipe do RH |
| Histórico | Histórico de movimentações de férias |

### Chips de status (Lista anual)
- **Todos** — sem filtro
- **Em férias hoje** — colaboradores com lançamento ativo hoje
- **Sem agendamento** — sem lançamento no `ANO_REF` com saldo > 0
- **Risco de dobra** — PA com menos de 180 dias para vencer sem agendamento
- **Aguard. aprovação** — status `pendente`

### Risco de dobra
| Nível | Condição |
|---|---|
| Crítico | ≤ 30 dias para o limite de dobra |
| Alto | ≤ 90 dias |
| Atenção | ≤ 180 dias |

Limite de dobra = 12 meses após início do PA.

### Filtros independentes por sub-aba
Lista anual e Calendário têm filtros separados (ativo/inativo, empresa, setor). Mudança em um não afeta o outro.

### Drawer do colaborador
Painel lateral com abas: **Resumo** | **Histórico** | **Lançar**. RH pode editar e lançar períodos; gestor só pode ver e solicitar.

## Visão Gestor (perfil `gestor`)

Ao entrar no módulo: `initGestor()` é chamada. Esconde abas de RH completamente.

### Identificação da equipe
- Busca `param_gestor` pelo `colaborador_id` do perfil → obtém apelido
- Busca `colaboradores` filtrado por `gestor=eq.{apelido}` e `ativo=eq.true`

### Abas do gestor

| Aba | Conteúdo |
|---|---|
| Painel | 3 cards de alerta + lista integrada da equipe |
| Timeline | Calendário mensal com férias da equipe |

### Cards de alerta do gestor
1. **Risco de dobra** — colaboradores sem agendamento com PA vencendo em < 60 dias
2. **Sem agendamento** — colaboradores sem férias agendadas
3. **Saindo em breve** — colaboradores com férias nos próximos 30 dias

### Lista integrada (Painel)
Mostra toda a equipe por padrão. Ao clicar num card de alerta, filtra para aquele grupo. Cada colaborador mostra: nome, cargo, saldo de dias, status.

### Solicitação de férias pelo gestor
- Gestor pode abrir drawer de um colaborador e solicitar período
- Lançamento salvo como `status: 'pendente'` — aguarda aprovação do RH

## Regras de negócio CLT

- Mínimo 14 dias corridos na parcela principal
- Até 3 parcelas (mínimo 5 dias cada parcela extra)
- Férias não podem iniciar nos 2 dias antes de feriado ou domingo
- Risco de dobra: PA vence sem férias → empresa paga em dobro

## Tabelas Supabase

- **`colaboradores`**: lidos `id, nome, cargo, setor, gestor, empresa_registro_nome, empresa_atuacao_nome, data_demissao`
- **`ferias`**: `id, colaborador_id, matricula_colaborador, ano, pa_inicio, pa_fim, status, dias_antecipados, abono_pecuniario` + colunas de lançamento inline (`periodo*`)
- **`param_gestor`**: `colaborador_id`, `apelido`, `nome` — vincula usuário gestor à sua equipe

---

# MÓDULO UNIFORMES (`modulos/uniformes/index.html`)

## Abas

| Aba | Conteúdo |
|---|---|
| Painel | KPIs (itens zerados, estoque baixo) + alertas + entregas recentes |
| Colaboradores | Busca colaborador → ver itens em posse + registrar entrega/devolução |
| Estoque | Saldo por item/almoxarifado + movimentações |
| Catálogo | Itens disponíveis |
| Solicitações | Solicitações de uniformes |

## Tabelas Supabase

| Tabela | Descrição |
|---|---|
| `unif_catalogo` | Catálogo de peças (nome, tipo, gênero, variante, logo) |
| `unif_almoxarifados` | Almoxarifados: **Almoxarifado Matriz** e **Almoxarifado CD** |
| `unif_estoque` | Saldo atual por item + almoxarifado |
| `unif_entradas` | Entradas de estoque (compras/recebimentos) |
| `unif_movimentacoes` | Todas as movimentações por colaborador |
| `unif_fornecedores` | Fornecedores |
| `unif_kits` | Kits padrão por cargo |

## Campos de `unif_movimentacoes`

`colaborador_id`, `item_id`, `almoxarifado_id`, `tipo` (entrega / devolucao / nao_entregue), `condicao_devolucao` (reutilizavel / descarte), `tamanho`, `qtd`, `data_movimentacao`, `registrado_por`, `motivo_pendencia`

## Lógica de saldo do colaborador

Saldo em posse = entregas (tipo=entrega) − devoluções registradas.

## Kits

Ao efetuar admissão, o sistema sugere kit padrão baseado no cargo (`unif_kits`). Os itens do kit são entregues registrando movimentações individuais.

## Devolução na demissão

Quando demissão é registrada no Cadastro e colaborador tem entregas em `unif_movimentacoes`, o workflow `devolucao_uniforme` é criado automaticamente no módulo Processos. A devolução em si é registrada neste módulo pelo botão "Registrar devolução" na aba Colaboradores.

## `configuracoes.html`

Gerencia: almoxarifados, catálogo de peças, fornecedores e kits por cargo.

---

# MÓDULO ADMISSÃO

## Formulário do candidato (`admissao-online.html`)

Formulário público (sem login). Candidato preenche dados pessoais, documentos, informações contratuais. Dados salvos em tabela de admissões pendentes.

## Painel RH (`modulos/admissao/index.html`)

RH revisa fichas enviadas pelos candidatos. Pode:
- Aprovar / rejeitar ficha
- Efetivar candidato (cria registro em `colaboradores`)
- Ao efetivar: workflow de `admissao` criado automaticamente em `processos_rh` com checklist de 19 itens

---

# MÓDULO DESENVOLVIMENTO & PERFORMANCE (`modulos/desenvolvimento/index.html`)

Avaliações de competências por colaborador.

## Tabelas

- `dev_competencias` — lista de competências avaliáveis
- `dev_avaliacoes` — avaliações por colaborador
- `dev_planos` — planos de desenvolvimento individual (PDI)

---

# MÓDULO COLABORADOR (`modulos/colaborador/index.html`)

Ficha pública do colaborador — acesso por `?matricula=<valor>` na URL.

## Abas

| Aba | Conteúdo |
|---|---|
| Resumo | KPIs (tempo de casa, saldo férias, última avaliação, ciclos avaliados) + dados pessoais/profissionais |
| Férias | Períodos aquisitivos com lançamentos e saldos |
| Desenvolvimento | Avaliações de desempenho + PDI |
| Histórico | Linha do tempo cronológica consolidando todos os eventos |

## Tabelas lidas

`colaboradores`, `ferias`, `dev_avaliacoes`, `dev_ciclos`, `dev_pdi`, `dev_historico`

## Histórico consolidado

Combina: eventos `dev_historico` + admissão + demissão (de `colaboradores`) + férias gozadas + avaliações. Ordenado por data decrescente.

---

# MÓDULO PARÂMETROS (`modulos/parametros/index.html`)

Acesso exclusivo para perfil `admin`. Sidebar com grupos colapsáveis + busca. Não-admin: somente visualização.

## Tabelas de parâmetros

**Estrutura:** `param_empresa`, `param_setor`, `param_gestor`, `param_gestor_setor`
**Contrato:** `param_tipo_contrato`, `param_instituicao_aprendiz`, `param_escolaridade`
**Jornada:** `param_regime_horas`
**Admissão:** `param_tipo_admissao`, `param_bonus_indicacao` (valor vigente = `vigencia_fim IS NULL`)
**Família:** `param_parentesco`
**Cargos:** `param_cargo` (FK → `param_cbo`); `param_cbo` embutido no JS (somente leitura)
**Desligamento:** `param_motivo_desligamento`, `param_aviso_previo`
**Acesso ao Sistema (admin only):** `usuarios_perfil` — CRUD de usuários e perfis

## Regras importantes

- Exclusão bloqueada se houver vínculo em `colaboradores` — orientar a inativar
- `param_gestor`: liga `colaborador_id` ao `apelido` usado para filtrar `colaboradores.gestor` no módulo Férias
- `param_bonus_indicacao`: registro com `vigencia_fim = null` é o valor vigente; campo `valor` usado pelo módulo Processos
- `param_setor`: salvo no formato `"código - nome"` (ex: `"148 - Compras"`)
- Cada registro tem `criado_por`, `alterado_por` e histórico de alterações no modal

---

# Regras gerais de colaboradores

- `pro_labore = true` → excluído de todos os módulos operacionais
- Ativo/Inativo: determinado por `data_demissao` preenchida
- Matrículas podem se repetir entre empresas — identificação correta: matrícula + nome
- `historico` JSONB é a trilha de auditoria de qualquer alteração relevante

# Preferências da usuária (RH — Daniele)

- Nunca abreviar valores monetários (`R$ 12.500,00`, não `12,5k`)
- **Apresentar proposta antes de implementar — aguardar aprovação**
- Respostas curtas e diretas
- Soluções simples que possam evoluir
