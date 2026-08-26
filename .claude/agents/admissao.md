---
name: admissao
description: Especialista no módulo de Admissão Online do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em admissao-online.html (formulário do candidato) ou modulos/admissao/index.html (painel RH de admissão). Também cobre modulos/cadastro/index.html quando a mudança envolve campos que vêm da ficha de admissão.
---

# Skill: Módulo Admissão Online — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).

Três arquivos principais:
- `C:\Users\reves\SistemaRH\admissao-online.html` — formulário do candidato (público, acesso por link com token)
- `C:\Users\reves\SistemaRH\modulos\admissao\index.html` — painel interno do RH (revisão e efetivação)
- `C:\Users\reves\SistemaRH\modulos\cadastro\index.html` — cadastro do colaborador (recebe dados após efetivação)

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo permanece inline no HTML.
2. **NUNCA usar a chave secreta do Supabase no browser** — apenas `SB_KEY` (publishable) no HTML.
3. **Sempre apresentar proposta antes de implementar** — aguardar aprovação da usuária.
4. **Nunca abreviar valores** (`R$ 12.500,00`, não `12,5k`).
5. **Todo texto salvo vai em maiúsculas** — `up = s => s ? s.toUpperCase() : s` antes de enviar para Supabase.

## Credenciais (browser — publishable key apenas)

```js
const SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const SB_KEY = 'sb_publishable_V4jUw9qvHjN9LvncGunqNQ_o_dj0RdH';
```

## Fluxo completo de admissão

```
RH cria convite (painel admissão)
  → candidato recebe link: admissao-online.html?token=UUID
  → preenche 5 steps do formulário
  → faz upload dos documentos no Storage
  → envia ficha (POST admissao_fichas)
  → RH valida no painel
  → clica "Aprovar Ficha"
  → modal confirma candidato + lista workflows que serão criados
  → RH confirma → PATCH convite status='aprovado'
             → POST processos_rh tipo='admissao' (colaborador_id=null, dados_extras.convite_id)
             → POST checklist admissão (17 itens + Alelo se vendedor)
             → se vale_transporte=true: POST processos_rh tipo='vt_alteracao' operacao='inclusao'
             → POST checklist VT inclusão (4 itens)
  → RH clica "Efetivar Contratação"
  → modal auto-preenche dados + gera matrícula
  → RH confirma → POST colaboradores + PATCH convite status='efetivado'
             → vincula colaborador_id nos processos criados na aprovação (filtra por convite_id em dados_extras)
  → colaborador aparece em TODOS os módulos (férias, cadastro, etc.)
```

## Tabelas Supabase (módulo admissão)

### `admissao_convites`
`id, token (UUID), nome, email, cargo, salario, status, empresa_id, criado_em`

Status: `pendente` → `preenchido` → `efetivado`

Convites efetivados permanecem visíveis no painel na aba "Efetivados" (histórico permanente).

### `admissao_fichas`
Campos principais:
- Pessoais: `nome, nascimento, sexo, nacionalidade, naturalidade, estado_naturalidade, rg, rg_orgao, rg_data, cpf`
- Eleitor: `titulo_eleitor, titulo_zona, titulo_secao`
- Trabalho: `ctps_numero, ctps_serie, pis, cnh_numero, cnh_categoria`
- Endereço: `endereco (concatenado), cep, logradouro, numero, complemento, bairro, cidade, uf`
- Contato: `celular, tel_recado, tel_recado_nome, email`
- Família: `nome_pai, nome_mae, estado_civil, data_casamento`
- Cônjuge: `conjuge_nome, conjuge_cpf, conjuge_rg, conjuge_nascimento`
- Filhos/Dependentes: `tem_filhos (bool), qtd_filhos (int), dependentes (JSONB array)`
- Complementares: `escolaridade, cor_raca, vale_transporte, banco, agencia, conta, primeiro_emprego, hobby`
- Docs: `docs (JSONB — paths no Storage)`
- LGPD: `aceite_lgpd (bool), aceite_lgpd_em`

Migrações executadas: 024 (criação), 027 (logradouro/numero/complemento/bairro), 028 (estado_naturalidade), 029 (qtd_filhos)

### `colaboradores`
Tabela master — alimentada na efetivação. Todos os outros módulos leem daqui.
Chave: `matricula` (TEXT, gerada automaticamente com zero-padding)

Campos relevantes para admissão:
- `naturalidade` (TEXT) — cidade de nascimento
- `estado_naturalidade` (TEXT) — UF de nascimento (2 letras, ex: "SP")
- `escolaridade` (TEXT) — grau de formação em Title Case
- `qtd_filhos` (INTEGER, nullable) — quantidade total de filhos (adicionado 2026-08-25)
- `tem_filhos` (BOOL) — possui filhos menores de 6 anos

## Formulário candidato (admissao-online.html)

### Steps e seções

| Step | Seções (cor) |
|---|---|
| 1 | Identificação (azul `sec-id`) + Documentos (roxo `sec-doc`) + Endereço (ciano `sec-end`) + Contato (verde `sec-cont`) |
| 2 | Filiação (âmbar `sec-fam`) + Dependentes (ciano `sec-dep`) |
| 3 | Formação (roxo `sec-comp`) + Dados Bancários (verde `sec-bank`) |
| 4 | Anexos obrigatórios + opcionais |
| 5 | Confirmação + LGPD |

### Campos de endereço (ordem obrigatória)
CEP → logradouro → número → complemento → bairro → cidade → UF
CEP tem autocomplete ViaCEP: preenche logradouro e bairro via API pública

### Cidade e UF de nascimento (campo separado desde 2026-08-25)
- **UF de Nascimento** (`estado_naturalidade`): `<select>` com as 27 UFs
- **Cidade de Nascimento** (`naturalidade`): input texto com autocomplete via API IBGE
  - Só habilita após UF selecionada
  - Ao digitar 3+ letras busca municípios do estado selecionado (`https://servicodados.ibge.gov.br/api/v1/localidades/estados/{UF}/municipios`)
  - Filtra localmente, exibe dropdown com até 8 sugestões
- Antes era um único campo de texto livre ("Ex: São Paulo - SP") — NÃO voltar a esse formato

### Grau de Formação (padronizado em 2026-08-25)
- Campo interno: `escolaridade` (em todos os três arquivos)
- Rótulo visual: **"Grau de Formação"** nas três visões
- Opções (Title Case, igual em todos): `Fundamental Incompleto, Fundamental Completo, Médio Incompleto, Médio Completo, Superior Incompleto, Superior Completo, Pós-graduação, Mestrado, Doutorado`
- Normalização na revisão (modulos/admissao): converte qualquer capitalização para Title Case antes de preencher o select

### Máscaras (funções reutilizáveis)
- CPF: `bindCpfMasks()` — aplica em `#cpf`, `#conjuge_cpf`, `.dep-cpfval`; guarda flag `el._cpfMask`
- Datas: `bindDateMasks()` — texto `DD/MM/AAAA` (sem calendar picker — inviável em mobile para datas antigas); guarda flag `el._dateMask`
- Telefone: `(00) 00000-0000`
- CEP: `00000-000`

**ATENÇÃO:** `bindDateMasks()` e `bindCpfMasks()` devem ser chamados sempre que novos elementos forem inseridos dinamicamente (ex: nova linha de dependente). Os flags `_dateMask` / `_cpfMask` evitam dupla aplicação.

### Filhos e Dependentes
- Seção renomeada: "Possui filhos?" (antes: "Possui dependentes?")
- Campo `qtd_filhos` (number, min 1, max 20) aparece quando "Sim" — informa total de filhos
- Os cards de dependentes (nome, tipo, CPF, nascimento, cidade) são **exclusivos para filhos menores de 6 anos**
- Estrutura de cada dependente: `{ nome, tipo (Filho/Enteado/Outro), cpf (opcional), nascimento (DD/MM/AAAA), cidade_nascimento }`
- Radio "Sim" auto-abre a primeira linha e chama `bindDepEvents()` + masks
- Campos obrigatórios por dependente: nome, tipo, nascimento (CPF é opcional)

### Documentos
**Obrigatórios:** RG (frente apenas — verso removido), CPF, Foto 3x4, Comprovante de residência, CTPS  
**Opcionais:** CNH, Título de eleitor, Comprovante bancário, Certidão dos dependentes (`depOnly: true` — só aparece se `tem_filhos = true`)

### Upload de documentos
```js
// Padrão de URL
`${SB_URL}/storage/v1/object/admissao-docs/${token}/${key}.${ext}`
// Headers obrigatórios
{ Authorization: `Bearer ${SB_KEY}`, 'x-upsert': 'true' }
```
- `x-upsert: true` permite substituir arquivo já enviado
- Usar `SB_KEY` direto como Bearer (token anônimo era instável)
- Candidatos podem tirar foto diretamente pelo celular (input type=file com câmera)

### Conversão para data ISO
`parseDateBR(str)`: converte `DD/MM/AAAA` → `YYYY-MM-DD`; retorna `''` se inválido

## Painel RH (modulos/admissao/index.html)

### Geração de matrícula automática
```js
// Busca top 10 matrículas em desc, extrai parte numérica, max+1, mantém zero-padding
const rows = await sb.GET('colaboradores?select=matricula&order=matricula.desc&limit=10')
// Ex: "0042" → 43 → "0043"
```
Matrícula é editável pelo RH antes de confirmar.

### Aprovar Ficha (cria workflows)

```js
function aprovarFicha(f) {
  // Abre #modalAprovar mostrando candidato + workflows a criar
  // Botão "Aprovar e criar workflows" chama _confirmarAprovar(ficha, temVT)
}

async function _confirmarAprovar(f, temVT) {
  // 1. PATCH admissao_convites status='aprovado'
  // 2. POST processos_rh tipo='admissao' { colaborador_id: null, dados_extras: { convite_id } }
  // 3. POST checklist admissão (17 itens, +Alelo se vendedor)
  // 4. if (temVT): POST processos_rh tipo='vt_alteracao' operacao='inclusao' + 4 itens
}
```

**Regra:** workflows são criados com `colaborador_id=null` e `dados_extras.convite_id=<id>`. O vínculo ocorre na efetivação.

**VT:** só cria workflow de VT se `ficha.vale_transporte === true`.

### Efetivar Contratação

1. `efetivarContratacao(f)`: abre modal com dados pré-preenchidos da ficha
2. `confirmarEfetivar()`:
   - Valida: matrícula, data_admissao, empresa, cargo, tipo_contrato, salario
   - POST `colaboradores` com TODOS os dados da ficha mapeados
   - PATCH `admissao_convites` → `status = 'efetivado'`
   - Vincula `colaborador_id` nos processos criados na aprovação:
     ```js
     // Busca processos abertos com colaborador_id=null e dados_extras.convite_id correspondente
     // PATCH colaborador_id em cada um
     ```
   - **Copia documentos da ficha para a Pasta Funcional Digital** (ver seção abaixo)
   - Recarrega painel (loadFichas + loadConvites)

## Pasta Funcional Digital

### Conceito
Cada colaborador tem uma pasta permanente de documentos acessível pela aba **Arquivos** no drawer do Cadastro. Armazena o ciclo de vida completo de documentos: admissão, contratos, ASOs, VT, rescisão, etc.

### Tabela `colaborador_documentos`
```sql
id              uuid PK
colaborador_id  bigint FK → colaboradores(id) ON DELETE CASCADE
nome            text NOT NULL
categoria       text CHECK (admissao|contrato|saude|vt|financeiro|rescisao|outros)
url             text NOT NULL   -- URL pública do arquivo
tipo_arquivo    text CHECK (pdf|imagem|outro)
data_documento  date
data_validade   date            -- se preenchida, gera alerta de vencimento
criado_em       timestamptz
criado_por      text
```
Migration: `migrations/030_colaborador_documentos.sql`  
RLS: policies `anon_all` (TO anon) e `authenticated_all` (TO authenticated) — ambas obrigatórias porque o módulo Cadastro usa JWT de usuário autenticado.

### Storage bucket `colaborador-docs`
- Bucket público, RLS policy `anon_all` criada via Supabase UI
- Path de upload: `${colaborador_id}/${categoria}/${timestamp}.${ext}`

### Cópia automática na efetivação
Em `confirmarEfetivar()`, após criar o colaborador:
```js
// DOC_LABELS: mapa key → nome legível (ex: rg_frente → 'RG')
// DOC_CATEGORIA: exceções (exame_admissional→saude, comp_banco→financeiro, cart_vt→vt)
// Itera f.docs (JSONB da ficha), constrói URL pública do bucket admissao-docs
// POST colaborador_documentos com todos os docs encontrados
// Erros são silenciosos (try/catch warn) — nunca bloqueiam a efetivação
```

### UI no Cadastro (`modulos/cadastro/index.html`)
- Aba **Arquivos** na drawer (8ª aba, antes de Histórico)
- Documentos agrupados por categoria em acordeão colapsável (fechado por padrão)
- Cabeçalho de cada categoria mostra: dot colorido, nome, contagem, ponto laranja se há vencimento próximo
- Funções JS: `loadDocsPasta(colabId)`, `renderDocsPasta()`, `togglePastaCat(id,btn)`, `abrirDocPasta()`, `deleteDocPasta()`, `abrirFormPasta()`, `fecharFormPasta()`, `salvarDocPasta()`
- Badge laranja na aba se algum documento vence em ≤ 30 dias

### Migração retroativa
Script Python `migrar_docs_admissao.py` (no scratchpad da sessão):
- Busca convites com `status='efetivado'` → fichas → colaboradores (match por CPF)
- Insere em `colaborador_documentos` pulando duplicatas por `(colaborador_id, nome)`
- Usado 1× em 2026-08-26 para migrar 73 docs de 9 colaboradores já efetivados antes do deploy

## Deploy

GitHub Pages — branch `main`:
`https://danieledalosse-a11y.github.io/SistemaRH`

Deploy automático após push (2–3 min). Para testar localmente usar Live Server ou similar.

## Pendências conhecidas

- Geração de PDF/contrato de trabalho a partir da ficha efetivada
- Notificação por email ao candidato quando convite é criado
