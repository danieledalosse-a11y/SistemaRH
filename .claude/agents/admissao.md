---
name: admissao
description: Especialista no módulo de Admissão Online do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em admissao-online.html (formulário do candidato) ou modulos/admissao/index.html (painel RH de admissão).
---

# Skill: Módulo Admissão Online — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).

Dois arquivos principais:
- `C:\Users\reves\SistemaRH\admissao-online.html` — formulário do candidato (público, acesso por link com token)
- `C:\Users\reves\SistemaRH\modulos\admissao\index.html` — painel interno do RH

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
  → clica "Efetivar Contratação"
  → modal auto-preenche dados + gera matrícula
  → RH confirma → POST colaboradores + PATCH convite status='efetivado'
  → colaborador aparece em TODOS os módulos (férias, cadastro, etc.)
```

## Tabelas Supabase (módulo admissão)

### `admissao_convites`
`id, token (UUID), nome, email, cargo, salario, status, empresa_id, criado_em`

Status: `pendente` → `preenchido` → `efetivado`

Convites efetivados permanecem visíveis no painel na aba "Efetivados" (histórico permanente).

### `admissao_fichas`
Campos principais:
- Pessoais: `nome, nascimento, sexo, nacionalidade, naturalidade, rg, rg_orgao, rg_data, cpf`
- Eleitor: `titulo_eleitor, titulo_zona, titulo_secao`
- Trabalho: `ctps_numero, ctps_serie, pis, cnh_numero, cnh_categoria`
- Endereço: `endereco (concatenado), cep, logradouro, numero, complemento, bairro, cidade, uf`
- Contato: `celular, tel_recado, tel_recado_nome, email`
- Família: `nome_pai, nome_mae, estado_civil, data_casamento`
- Cônjuge: `conjuge_nome, conjuge_cpf, conjuge_rg, conjuge_nascimento`
- Dependentes: `tem_filhos (bool), dependentes (JSONB array)`
- Complementares: `escolaridade, cor_raca, vale_transporte, banco, agencia, conta, primeiro_emprego, hobby`
- Docs: `docs (JSONB — paths no Storage)`
- LGPD: `aceite_lgpd (bool), aceite_lgpd_em`

Migrações executadas: 024 (criação), 027 (logradouro/numero/complemento/bairro)

### `colaboradores`
Tabela master — alimentada na efetivação. Todos os outros módulos leem daqui.
Chave: `matricula` (TEXT, gerada automaticamente com zero-padding)

## Formulário candidato (admissao-online.html)

### Steps e seções

| Step | Seções (cor) |
|---|---|
| 1 | Identificação (azul `sec-id`) + Documentos (roxo `sec-doc`) + Endereço (ciano `sec-end`) + Contato (verde `sec-cont`) |
| 2 | Filiação (âmbar `sec-fam`) + Dependentes (ciano `sec-dep`) |
| 3 | Formação (roxo `sec-comp`) + Dados Bancários (verde `sec-bank`) |
| 4 | Anexos obrigatórios + opcionais |
| 5 | Confirmação + LGPD |

### Campos de endereço (order obrigatória)
CEP → logradouro → número → complemento → bairro → cidade → UF
CEP tem autocomplete ViaCEP: preenche logradouro e bairro via API pública

### Máscaras (funções reutilizáveis)
- CPF: `bindCpfMasks()` — aplica em `#cpf`, `#conjuge_cpf`, `.dep-cpfval`; guarda flag `el._cpfMask`
- Datas: `bindDateMasks()` — texto `DD/MM/AAAA` (sem calendar picker — inviável em mobile para datas antigas); guarda flag `el._dateMask`
- Telefone: `(00) 00000-0000`
- CEP: `00000-000`

**ATENÇÃO:** `bindDateMasks()` e `bindCpfMasks()` devem ser chamados sempre que novos elementos forem inseridos dinamicamente (ex: nova linha de dependente). Os flags `_dateMask` / `_cpfMask` evitam dupla aplicação.

### Dependentes
- Estrutura de cada item: `{ nome, tipo (Filho/Enteado/Outro), cpf (opcional), nascimento (DD/MM/AAAA) }`
- Radio "Possui dependentes = Sim" auto-abre a primeira linha e chama `bindDepEvents()` + masks
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

### Efetivar Contratação
1. `efetivarContratacao(f)`: abre modal com dados pré-preenchidos da ficha
2. `confirmarEfetivar()`:
   - Valida: matrícula, data_admissao, empresa, cargo, tipo_contrato, salario
   - POST `colaboradores` com TODOS os dados da ficha mapeados
   - PATCH `admissao_convites` → `status = 'efetivado'`
   - Recarrega painel (loadFichas + loadConvites)

## Deploy

GitHub Pages — branch `main`:
`https://danieledalosse-a11y.github.io/SistemaRH`

Deploy automático após push (2–3 min). Para testar localmente usar Live Server ou similar.

## Pendências conhecidas

- Geração de PDF/contrato de trabalho a partir da ficha efetivada
- Notificação por email ao candidato quando convite é criado
