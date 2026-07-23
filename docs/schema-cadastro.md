# Schema — Cadastro Base

Baseado na planilha `Cadastros.xlsx` aba `Cadastro` (698 linhas, 19 colunas úteis).

---

## Tabelas

### empresas
| Campo | Tipo | Descrição |
|---|---|---|
| id | uuid PK | |
| codigo | text | Código Empresa Registro |
| razao_social | text | Empresa Registro |
| nome_comercial | text | Nome Comercial / Unidade |
| empresa_atuacao | text | Empresa Atuação |
| empresa_folha | text | Empresa Folha |
| ativa | boolean | default true |

### setores
| Campo | Tipo | Descrição |
|---|---|---|
| id | uuid PK | |
| nome | text | Setor |
| empresa_id | uuid FK → empresas | |

### cargos
| Campo | Tipo | Descrição |
|---|---|---|
| id | uuid PK | |
| nome | text | Cargo Colaborador |

### gestores (usuários com perfil gestor)
| Campo | Tipo | Descrição |
|---|---|---|
| id | uuid PK | |
| nome | text | Gestor Responsavel |
| email | text | para login |
| setor_id | uuid FK → setores | setor que gerencia |

### colaboradores ⭐ (tabela principal)
| Campo | Tipo | Origem planilha |
|---|---|---|
| id | uuid PK | — |
| codigo | text UNIQUE | Codigo Colaborador (matrícula) |
| codigo_fronter | text | Codigo Fronter |
| nome | text | Nome Colaborador |
| data_admissao | date | Data Admissão |
| data_nascimento | date | Data de Nascimento |
| sexo | text | Sexo (M/F) |
| dependentes | integer | Dependente |
| cargo_id | uuid FK → cargos | Cargo Colaborador |
| setor_id | uuid FK → setores | Setor |
| empresa_id | uuid FK → empresas | Empresa Registro |
| gestor_id | uuid FK → gestores | Gestor Responsavel |
| pro_labore | boolean | Pro-labore |
| situacao | text | SITUAÇÃO (Ativo/Inativo) |
| data_demissao | date | Data Demissão |
| motivo_demissao | text | MOTIVO |
| tipo_contrato | text | CLT/PJ/Aprendiz/Estágio (a enriquecer) |
| whatsapp | text | (a enriquecer — já usado em Férias) |
| foto_url | text | (futuro — upload) |
| created_at | timestamptz | auto |
| updated_at | timestamptz | auto |

---

## Regras de negócio

- `pro_labore = true` → excluído de todos os módulos operacionais (férias, ponto, etc.)
- `situacao = 'Inativo'` + `data_demissao preenchida` → colaborador desligado
- Chave de identidade para integração com módulo Férias: `codigo` (= Registro na planilha de férias)
- Gestor vê apenas colaboradores do seu `setor_id`
- RH vê todos

---

## Campos a enriquecer no sistema (não existem na planilha atual)
- CPF, RG, PIS
- Endereço
- Telefone / WhatsApp
- Email
- Tipo de contrato (CLT, PJ, Aprendiz, Estágio)
- Jornada de trabalho
- Salário base
- Centro de custo
- Foto
