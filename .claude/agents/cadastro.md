---
name: cadastro
description: Especialista no módulo Cadastro de Colaboradores do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/cadastro/index.html, incluindo ficha do colaborador, linha do tempo (historico JSONB), navegação por setores/empresas e edição de dados cadastrais.
---

# Skill: Módulo Cadastro — SistemaRH Revest

## Contexto

Arquivo principal: `C:\Users\reves\SistemaRH\modulos\cadastro\index.html` (~4.200+ linhas, tudo inline).
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo permanece inline no index.html.
2. **Nunca usar a chave secreta no browser** — chave publicável apenas no index.html.
3. **Sempre apresentar proposta antes de implementar** — aguardar aprovação da usuária.
4. **`guardModulo('cadastro')` obrigatório** — primeira linha do bloco de auth; ver [[permissoes]].

## Tabela `colaboradores`

Campos principais usados no módulo:

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | int | PK |
| `nome` | text | Nome completo |
| `matricula` | int | Matrícula |
| `cargo` | text | Cargo atual |
| `setor` | text | Setor atual |
| `empresa_registro` | text | Empresa do registro trabalhista |
| `empresa_atuacao` | text | Empresa onde atua fisicamente |
| `data_admissao` | date | Data de admissão original — **nunca alterar sem análise de impacto** |
| `data_demissao` | date | Null = colaborador ativo |
| `ativo` | bool | true = ativo |
| `historico` | JSONB | Array append-only de movimentações |
| `gestor` | text | Nome do gestor (texto, não FK) |

## Histórico — `historico` JSONB

Array append-only de eventos. Renderizado em `renderHistoricoFicha()` (linha ~4068).

### Estrutura de cada evento

```json
{
  "tipo": "empresa",
  "de": "valor anterior",
  "para": "novo valor",
  "data": "YYYY-MM-DD",
  "usuario": "Nome do usuário",
  "detalhe": "texto opcional — se presente, substitui de/para na exibição"
}
```

### META — tipos conhecidos e sua exibição

| `tipo` | Label exibido | Cor |
|---|---|---|
| `admissao` | Admissão | `#10b981` (verde) |
| `admissao_link` | Admissão via formulário | `#10b981` |
| `ficha_preenchida` | Ficha preenchida | `#10b981` |
| `efetivacao` | Efetivação | `#10b981` |
| `cargo` | Cargo alterado | `#f59e0b` (âmbar) |
| `setor` | Setor alterado | `#f59e0b` |
| `gestor` | Gestor alterado | `#f59e0b` |
| `nome` | Nome alterado | `#f59e0b` |
| `empresa` | Empresa alterada | `#6366f1` (índigo) |
| `demissao` | Desligamento | `#ef4444` (vermelho) |

**Fallback para tipos desconhecidos:** `{ label: h.tipo, cor: '#64748b' }` — exibe o `tipo` como texto puro em cinza. Funcional mas não polido.

### Como representar uma transferência de CNPJ

Usar `tipo: "empresa"` (já mapeado no META como "Empresa alterada"):

```json
{
  "tipo": "empresa",
  "de": "Matriz / Gerente Comercial",
  "para": "Paranavaí / Gerente de Vendas",
  "data": "2023-10-01",
  "usuario": "Correção cadastral — transferência de CNPJ"
}
```

O campo `de/para` fica visível na timeline. O contexto da transferência vai no `usuario` (campo livre).

**Nunca criar `tipo: "transferencia_cnpj"`** sem antes adicionar ao META — caso contrário exibe string crua em cinza.

## Cadastro duplicado por transferência de CNPJ

### Como identificar

- Dois registros na tabela `colaboradores` com mesmo nome/CPF
- Um tem `data_admissao` = data original de contratação, `data_demissao` preenchida, `ativo=false`
- Outro tem `data_admissao` = data da transferência, `data_demissao=null`, `ativo=true`

### Impactos em outros módulos

| Módulo | Impacto |
|---|---|
| **Férias** | PAs do cadastro duplicado têm ciclo errado (baseado na data de transferência, não na admissão original). Ver skill [[ferias]] seção "PA com ciclo de datas incorreto". |
| **Uniformes** | Movimentações ficam vinculadas ao cadastro duplicado (`unif_movimentacoes.colaborador_id`) |
| **Parâmetros** | Entrada em `param_gestor` pode apontar para o cadastro duplicado |
| **Histórico** | `historico_eventos` referencia o `colaborador_id` errado |

### Procedimento de correção

Ver skill [[ferias]] seção "PA com ciclo de datas incorreto — causa e correção" para o passo-a-passo completo, incluindo a ordem de migração e como lidar com FK violations iterativas.

## Integração com Admissão Online

Quando um colaborador completa a ficha de admissão online, o módulo Cadastro recebe:
- Evento `admissao_link` ou `ficha_preenchida` no `historico`
- Dados preenchidos pelo candidato ficam disponíveis para revisão no drawer

Ver skill [[admissao]] para detalhes do fluxo.
