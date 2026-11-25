---
name: cadastro
description: Especialista no módulo Cadastro de Colaboradores do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/cadastro/index.html, incluindo ficha do colaborador, linha do tempo (historico JSONB), navegação por setores/empresas e edição de dados cadastrais. Também cobre modulos/admissao/index.html quando a mudança envolve campos que vêm da ficha de admissão.
---

# Skill: Módulo Cadastro — SistemaRH Revest

## Contexto

Arquivo principal: `C:\Users\reves\SistemaRH\modulos\cadastro\index.html` (~4.200+ linhas, tudo inline).
Painel de admissão: `C:\Users\reves\SistemaRH\modulos\admissao\index.html` (~2.600+ linhas, tudo inline).
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
| `cnh_categoria` | text | Categoria CNH — preenchida pela admissão online |
| `qtd_filhos` | int | Quantidade de filhos — preenchida pela admissão online |
| `possui_filhos` | text | 'Sim' ou 'Não' — derivado de `tem_filhos` na efetivação |
| `motivo_demissao` | text | Motivo operacional do desligamento — flui para Workflow e Excel |
| `obs_desligamento` | text | Contexto do desligamento (texto livre) |
| `aviso_previo` | text | Tipo de aviso (Trabalhado / Indenizado) — de `param_aviso_previo` |
| `data_aviso` | date | Data em que o aviso prévio foi comunicado |
| `venc_aviso` | date | Vencimento do aviso — calculado automaticamente |
| `lotacao` | text | Local de lotação — de `param_lotacao`; preenchido via UPDATE em nov/2026 |
| `causa_rescisao` | text | **Legado** — não exibido nem editado; mantido no banco para histórico |

## Campo Lotação (nov/2026)

Campo `lotacao` (text) adicionado ao drawer, aba Geral, **abaixo de Empresa (atuação)** e acima de Tipo de Vínculo.

- Alimentado por `param_lotacao` (ativo, ordenado por `ordem, descricao`).
- Campo opcional — não bloqueia save quando vazio.
- Carregado em `carregarLotacaoParam()` → `popularSelectLotacao(valorAtual?)`, chamado junto com as demais cargas iniciais.
- Mapeado em `mapRow`, `abrirFicha`, `syncColabState`, payload de novo colaborador e payload de atualização.
- Incluído no array de reset ao iniciar novo cadastro (`df-lotacao`).
- **Independente de Empresa (atuação)** — pode ter valor diferente; ambos os campos coexistem sem relação de dependência.

**Seed e carga inicial (migration 149 + UPDATE pontual):**
1. Migration criou `param_lotacao` com seed a partir de `colaboradores.empresa_atuacao` (casing original, dedup por `LOWER/TRIM`).
2. UPDATE preencheu `colaboradores.lotacao` via JOIN com `param_lotacao` (`LOWER(pl.descricao) = LOWER(TRIM(empresa_atuacao))`), somente onde `lotacao IS NULL`. Colaboradores sem `empresa_atuacao` ficaram com `lotacao` nulo.

## Fluxo de desligamento (Aba Geral — seção Desligamento)

Todos os dados de desligamento ficam em **uma única seção**, na aba Geral:

| Campo UI | ID DOM | Coluna DB | Uso fora do drawer |
|---|---|---|---|
| Motivo de desligamento | `df-motivo` | `motivo_demissao` | **Workflow** + **Excel** |
| Observação | `df-obsDesligamento` | `obs_desligamento` | — |
| Data de demissão | `df-demissao` | `data_demissao` | **Gatilho do Workflow** + **Excel** + Processos |
| Aviso prévio | `df-aviso` | `aviso_previo` | — |
| Data do aviso | `df-dataAviso` | `data_aviso` | — |
| Vencimento do aviso | `df-vencAviso` | `venc_aviso` | — (calculado auto) |

**Regra:** `causa_rescisao` foi removida da UI em nov/2026 (redundante com `motivo_demissao`). A coluna existe no banco mas não deve ser exibida ou editada em código novo.

### Workflow de demissão

Disparado APENAS quando `data_demissao` muda (linha ~3766 em `salvarFicha()`). Chama `_sincronizarProcessoDemissao(sbId, nomeColab, novaData, motivo)` que usa `motivo_demissao`. Não usa `causa_rescisao`, `aviso_previo` ou `data_aviso`.

### Cálculo do vencimento do aviso

`calcularVencimentoAviso()` lê `df-dataAviso` e usa `REGRAS_AVISO` (configuradas no banco) com dedução de dias úteis e feriados. `df-vencAviso` tem `background:var(--bg-alt,#f5f5f5)` para indicar que é calculado automaticamente.

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

**Fallback para tipos desconhecidos:** `{ label: h.tipo, cor: '#64748b' }` — exibe o `tipo` como texto puro em cinza.

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

## Integração com Admissão Online — campos preservados na efetivação

### CNH Categoria (`cnh_categoria`)

**Fluxo:** candidato preenche texto livre no formulário online → salvo em `admissao_fichas.cnh_categoria` → painel de revisão exibe como `input[type=text]` (nunca SELECT) → `salvarAlteracoesPainel()` usa `fv('cnh_categoria') || currentFicha.cnh_categoria || null` → `confirmarEfetivar()` usa `up(f.cnh_categoria) || null`.

**Regra crítica (fix nov/2026):** o campo no painel de revisão **DEVE ser `fi()` (input texto)**, nunca `fiSel()` (SELECT com opções fixas). Um SELECT com opções fixas causa perda do valor original quando o candidato preencheu algo que não corresponde exatamente às opções. No save, sempre usar o fallback `|| currentFicha.cnh_categoria || null` para preservar o valor original quando o campo estiver em branco.

### Possui filhos / Quantidade de filhos (`tem_filhos`, `qtd_filhos`)

**Fluxo:** candidato seleciona Sim/Não e informa quantidade no formulário online → salvo em `admissao_fichas.tem_filhos` e `admissao_fichas.qtd_filhos` → painel exibe toggle Sim/Não com seção de dependentes → `salvarAlteracoesPainel()` usa `getPanelDeps().length > 0 || currentFicha.tem_filhos || false` para `tem_filhos` → `confirmarEfetivar()` usa `f.tem_filhos ? 'Sim' : 'Não'` e `f.qtd_filhos`.

**Regra crítica (fix nov/2026):**
1. A inicialização do toggle usa `f.tem_filhos || deps.length` — garante que o botão "Sim" já apareça destacado quando o candidato declarou filhos, mesmo sem dependentes individuais cadastrados
2. O save de `tem_filhos` usa `getPanelDeps().length > 0 || currentFicha.tem_filhos || false` — preserva o valor original quando o RH não adicionou dependentes pelo painel
3. `qtd_filhos` é lido do input `panel-qtd-filhos` que é pré-preenchido com `f.qtd_filhos` — preservado automaticamente

### Regra geral para campos da ficha de admissão

Quando um campo existe tanto na ficha online quanto no painel de revisão: o save do painel deve **sempre** ter um fallback para o valor original (`currentFicha.campoOriginal`), para evitar que uma interação do RH com o painel sobrescreva o dado do candidato com vazio.
