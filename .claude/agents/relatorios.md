---
name: relatorios
description: Especialista no módulo Central de Relatórios do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/relatorios/index.html, ou quando a tarefa envolver criação de novos relatórios (PDF ou Excel) no sistema. Cobre também a lógica de geração compartilhada entre Relatórios e Cadastro.
---

# Skill: Módulo Central de Relatórios — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).
Arquivo principal: `C:\Users\reves\SistemaRH\modulos\relatorios\index.html`

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo inline no index.html.
2. **Nunca duplicar lógica de dados** — o módulo carrega diretamente do Supabase (campo `select` enxuto, só o que usa). Não depende do Cadastro estar aberto.
3. **Cadastro não pode ser alterado** — a Central de Relatórios é um novo ponto de acesso, não uma extensão do Cadastro. Qualquer melhoria na lógica de relatório deve ser aplicada nos dois módulos separadamente.
4. **Painel lateral, não inline** — filtros e botões PDF/Excel ficam no painel lateral (`.detail-panel`), nunca diretamente nos cards da central.
5. **Auditoria**: toda nova tela deve registrar eventos no `colaboradores.historico` quando aplicável.

## Estrutura do módulo

### Layout

```
Topbar (navy #2C3E6B)
└── .layout (flex, height: 100vh - 56px)
    ├── .central (flex:1, scroll)
    │   ├── .mod-header (navy, título do módulo)
    │   ├── .cat-label (separador de categoria)
    │   └── .cards-grid → .rel-card (cards clicáveis)
    └── .detail-panel (width: 0 → 360px ao abrir)
        └── .detail-inner (título, filtros, botões PDF/Excel, nota técnica)
```

### Categorias de relatórios

| Categoria | Relatórios | Tag |
|---|---|---|
| Periódicos | Aniversários do Mês, Tempo de Casa, Dependentes | `tag-new` |
| Colaboradores | Por Empresa/Setor, Por Gênero, PCD e Jovem Aprendiz | `tag-exist` |
| RH | (expansível, placeholder) | `tag-soon` |

### Objeto RELATORIOS

Cada relatório é uma entrada no objeto `RELATORIOS` com:
```js
{
  cat: 'Categoria',
  title: 'Título',
  desc: 'Descrição longa para o painel',
  note: 'Nota técnica (origem dos dados, reutilização)',
  renderFiltros: () => '<html dos filtros>',
  pdf:   () => funcaoGerarPDF(),
  excel: () => funcaoGerarExcel(),
}
```

Para adicionar um novo relatório: acrescentar entrada no objeto `RELATORIOS`, criar card HTML na `.central`, e implementar `_dados*()` + `gerar*PDF()` + `gerar*Excel()`.

## Variáveis globais

```js
let COLABORADORES = [];  // todos os colaboradores carregados do Supabase
let EMPRESAS      = [];  // lista de empresas distintas (empresa_atuacao sem prefixo numérico)
let MARCOS        = [];  // anos de marco carregados de param_marco_tempo_casa (ex: [1,5,10,15,20])
let _relAtivo     = null; // id do relatório com painel aberto
```

## Carregamento de dados

Carregado em paralelo no `init()`:
```js
const [dados, marcosRows] = await Promise.all([
  sbGet('colaboradores',
    'select=id,nome,cargo,data_admissao,data_nascimento,data_demissao,' +
    'empresa_registro,empresa_atuacao,setor,gestor,sexo,pcd,pro_labore,' +
    'dependentes_lista&order=nome'),
  sbGet('param_marco_tempo_casa', 'select=anos&ativo=eq.true&order=anos'),
]);
COLABORADORES = dados.map(supabaseToJS);
MARCOS = marcosRows.map(r => r.anos);
```

`supabaseToJS(row)` — mapeamento enxuto (sem campos de documentos, banco, VT etc.):
```js
{
  _sbId, nome, cargo, dataAdmissao, dataNascimento,
  empresa, empresaAtuacao, setor, gestor, sexo,
  pcd, aprendiz, proLabore, situacao,
  dependentesLista  // JSONB array: [{nome, parentesco, data_nascimento}]
}
```

## Helpers críticos

```js
function stripNum(s)  // remove prefixo numérico "01 - " do setor/empresa
function fmtDateBR(iso) // "YYYY-MM-DD" → "DD/MM/AAAA"
function idadeAnos(iso) // calcula idade em anos completos
function empresaFiltro() // lê select #f-empresa do painel ativo
function situacaoFiltro() // lê select #f-situacao do painel ativo
function mesAtual() // lê select #f-mes do painel ativo
function popularFiltroEmpresas() // repopula todos os select.emp-filter após abrir painel
```

## Geração de relatórios

### PDF

Todos abrem nova janela (`window.open`) com HTML completo gerado por `htmlRelPDF()`:
```js
function htmlRelPDF(titulo, chips, total, label, dataHora, blocos)
// Gera o HTML padrão: header navy, chips, total box, blocos, rodapé
// blocos = string HTML com <div class="sh">, <div class="ss">, <table>...
```

Classes CSS do PDF padrão: `.sh` (empresa header), `.sn` (nome), `.sc` (count teal), `.ss` (setor row), `.ssn` (setor nome), `.ssc` (setor count).

### Excel

Todos baixam via `baixarExcel(xlsHtml, nomeArquivo)`:
```js
function baixarExcel(xlsHtml, nomeArquivo)
// Gera Blob + <a download> + click + cleanup
// Extensão sempre .xls (HTML disfarçado — aviso de formato é esperado)
```

**Regra obrigatória para Excel:** todo arquivo deve ter o XML de WorksheetOptions com `<x:DisplayGridlines/>`:
```html
<!--[if gte mso 9]><xml><x:ExcelWorkbook><x:ExcelWorksheets><x:ExcelWorksheet>
<x:Name>NomeDaAba</x:Name>
<x:WorksheetOptions><x:DisplayGridlines/></x:WorksheetOptions>
</x:ExcelWorksheet></x:ExcelWorksheets></x:ExcelWorkbook></xml><![endif]-->
```
**NUNCA** deixar `<x:WorksheetOptions></x:WorksheetOptions>` vazio — causa erro "Desconhecido" no Excel.

### Padrão visual Excel

Constantes de estilo usadas em todos os relatórios Excel:

```js
const F = 'font-family:Calibri,Arial,sans-serif;';
// Empresa: header navy
const EMP_L = `style="${F}font-size:12pt;font-weight:bold;padding:10px 16px;background:#2C3E6B;color:#FFFFFF;border-top:2px solid #1a2d52;border-bottom:2px solid #1a2d52;border-left:2px solid #1a2d52;border-right:none;"`;
const EMP_R = `style="${F}font-size:11pt;font-weight:bold;padding:10px 16px;background:#2C3E6B;color:#5DD6B8;text-align:right;..."`; // count teal
// Setor: azul claro
const SET_L = `style="${F}...background:#EDF1FA;color:#2C5FA8;..."`; // setor nome
const SET_R = `style="${F}...background:#EDF1FA;color:#7A92B0;text-align:right;..."`; // setor count
// Cabeçalho de colunas: cinza claro
const TH_N  = `style="${F}...background:#F0F4FB;color:#5E718A;...width:260pt;"`;
const TH2   = `style="${F}...background:#F0F4FB;color:#5E718A;..."`;
// Células zebradas: bordas invisíveis (mesma cor do fundo)
const TD = (par) => `style="${F}...border:1px solid ${par?'#EEF2FA':'#F5F8FD'};background:${par?'#F5F8FD':'#FFFFFF'};"`;
```

## Relatórios implementados

### Aniversários do Mês

- **Filtros:** mês, empresa de atuação
- **Dados:** `dataNascimento`, filtro `parseInt(iso.split('-')[1]) === mes`
- **Layout:** tabela cronológica plana (sem agrupamento por gestor) — colunas: Data | Dia da semana | Colaborador | Setor | Gestor
- **Ordenação:** dia do mês ASC, nome ASC
- **PDF:** template HTML customizado (não usa `htmlRelPDF`) — nomes em teal (#1A7F6A)
- **Helper:** `DIAS_SEMANA = ['Dom','Seg','Ter','Qua','Qui','Sex','Sáb']` + `diaSemana(mes, dia)`
- **Funções:** `_dadosAniversarios()`, `gerarAniversariosPDF()`, `gerarAniversariosExcel()`

### Tempo de Casa por Mês

- **Filtros:** mês, empresa de atuação, Exibir (select `#f-tc-filtro`: `todos` | `marcos`)
- **Dados:** `dataAdmissao`, filtro `parseInt(iso.split('-')[1]) === mes`
- **Marcos:** carregados dinamicamente de `param_marco_tempo_casa` na variável global `MARCOS` — **nunca hardcoded**
- **Regra:** colaboradores com menos de 1 ano completo (`anosEmpresa < 1`) são excluídos
- **Filtro "Somente marcos":** exibe apenas colaboradores cujo `anosEmpresa` está em `MARCOS`
- **Ordenação:** dia da admissão ASC, nome ASC (ordem cronológica dentro do mês)
- **Colunas:** Nome | Cargo | Data Admissão | Tempo de Casa | Empresa
- **Marcos destacados:** nome em verde (#1A7F6A); troféu apenas na coluna Tempo de Casa (`5 anos 🏆`) — nome sempre limpo, sem ícone ou anos junto
- **Helper:** `tcFiltro()` — lê select `#f-tc-filtro` do painel ativo
- **Funções:** `_dadosTempoCasa()`, `gerarTempoCasaPDF()`, `gerarTempoCasaExcel()`
- **Tabela banco:** `param_marco_tempo_casa` (id, anos, ativo, criado_por) — gerenciada em Parâmetros Gerais → Marcos de Tempo de Casa
- **RLS:** policy `anon_all` para roles `anon` e `authenticated`

### Dependentes

- **Filtros:** empresa de atuação, situação do colaborador
- **Dados:** `dependentesLista` (JSONB array de `{nome, parentesco, data_nascimento}`)
- **Agrupamento:** por colaborador (um bloco por colaborador com seus dependentes)
- **Colunas:** Nome do Dep. | Parentesco | Nascimento | Idade
- **Funções:** `_dadosDependentes()`, `gerarDependentesPDF()`, `gerarDependentesExcel()`

### Por Empresa/Setor (Colaboradores)

- **Filtros:** situação, empresa de atuação, sexo
- **Agrupamento:** Empresa (`empresaAtuacao`) → Setor → lista de colaboradores
- **Ordenação:** empresa ABC, setor ABC, nome ABC; "(Sem empresa)" sempre no final
- **Colunas:** Nome | Cargo | Admissão | Gestor
- **Funções:** `_dadosCadastro(opts)`, `gerarCadastroPDF(opts)`, `gerarCadastroExcel(opts)`

**`_dadosCadastro(opts)`** aceita `{ situacao, empresa, sexo }` como override dos selects do DOM — permite que "Por Gênero" chame com `{ sexoForce: 'M' }` sem abrir painel diferente.

### Por Gênero

- Chama `gerarCadastroPDF({ sexoForce: valor })` / `gerarCadastroExcel({ sexoForce: valor })`
- Filtro de sexo pré-configurado a partir do select `#f-sexo` no painel

### PCD e Jovem Aprendiz

- **Filtros:** tipo (pcd | aprendiz | ambos), empresa de atuação
- **Dados:** `c.pcd` (bool) e `c.aprendiz` (derivado de `isAprendiz(cargo)`)
- **Colunas:** Nome | Cargo | Admissão | Empresa | Tipo
- **Funções:** `_dadosCotas()`, `gerarCotasPDF()`, `gerarCotasExcel()`

## Como adicionar um novo relatório

1. Criar card HTML dentro do `.cat-section` correto:
```html
<div class="rel-card" id="card-meurel" onclick="abrirDetalhe('meurel')">
  <div class="card-top">
    <div class="card-name">Nome do Relatório</div>
    <span class="card-arrow">›</span>
  </div>
  <div class="card-desc">Descrição curta de uma linha.</div>
  <span class="card-tag tag-new">✦ Novo</span>
</div>
```

2. Adicionar entrada no objeto `RELATORIOS`:
```js
meurel: {
  cat: 'Categoria',
  title: 'Nome completo',
  desc: 'Descrição longa exibida no painel.',
  note: 'De onde vêm os dados.',
  renderFiltros: () => `<div class="filter-row">...</div>`,
  pdf:   () => gerarMeuRelPDF(),
  excel: () => gerarMeuRelExcel(),
},
```

3. Implementar `_dadosMeuRel()`, `gerarMeuRelPDF()`, `gerarMeuRelExcel()` seguindo o padrão das funções existentes.

## Relação com módulo Cadastro

O módulo Cadastro (`modulos/cadastro/index.html`) tem suas próprias funções `_dadosRelatorio()`, `gerarRelatorioPDF()`, `gerarRelatorioExcel()` e `gerarRelatorioKPI()`. A Central de Relatórios **não importa nem chama** essas funções — tem implementação própria equivalente (`_dadosCadastro`, `gerarCadastroPDF`, `gerarCadastroExcel`, `_dadosCotas`).

A lógica é a mesma — agrupamento, estilo, cores — mas são implementações independentes. **Nunca modificar o Cadastro como efeito colateral de trabalho na Central de Relatórios**, e vice-versa.
