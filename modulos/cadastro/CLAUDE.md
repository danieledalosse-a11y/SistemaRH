# Módulo Cadastro — Instruções para o Claude

## O que faz

Consulta e visualização de colaboradores da Revest do Brasil. Lê a planilha `Cadastros.xlsx` e exibe cards/tabela com filtros por empresa, setor, situação.

## Arquivo

`modulos/cadastro/index.html` — autocontido (CSS + JS inline).

## Planilha de origem

**Arquivo:** `Cadastros.xlsx`
**Aba:** a que contém "cadastro" no nome, excluindo "bkp", "empresa", "config" — senão pega a primeira aba.

### Mapeamento de colunas (índice base 0, leitura via `{ header: 1 }`)

| Índice | Nome na planilha | Campo JS |
|---|---|---|
| 0 | Codigo Empresa Registro | `codEmpresa` |
| 1 | Setor | `setor` |
| 2 | Empresa Registro | `empresa` |
| 3 | Empresa Atuação | `empresaAtuacao` |
| 4 | Empresa Folha | `empresaFolha` |
| 5 | Codigo Fronter | `codFronter` |
| 6 | Pro-labore | `proLabore` (boolean) |
| 7 | Codigo Colaborador (matrícula) | `codigo` |
| 8 | Data Admissão | `dataAdmissao` |
| 9 | Nome Colaborador | `nome` |
| 10 | Data de Nascimento | `dataNascimento` |
| 11 | Sexo | `sexo` |
| 12 | Dependente | `dependentes` |
| 13 | Cargo Colaborador | `cargo` |
| 14 | Data Demissão | `dataDemissao` |
| 15 | MOTIVO | `motivo` |
| 16 | — | (ignorado) |
| 17 | Nome Comercial / Unidade | `nomeComercial` |
| 18 | Gestor Responsavel | `gestor` |

### Regras de parse

- Primeira linha (índice 0) = cabeçalho → `rows.slice(1)`
- `proLabore`: verdadeiro se col 6 não vazia e não zero
- `situacao`: `'Ativo'` se `dataDemissao` vazia, `'Inativo'` se preenchida
- `aprendiz`: detectado por palavras-chave no cargo ("aprendiz", "jovem aprendiz")

## Modelo de dados (`COLABORADORES[]`)

```js
{
  codEmpresa, setor, empresa, empresaAtuacao, empresaFolha, codFronter,
  proLabore,    // boolean
  codigo,       // matrícula — chave de cruzamento com outros módulos
  dataAdmissao, nome, dataNascimento, sexo, dependentes, cargo,
  dataDemissao, motivo, situacao,   // 'Ativo' ou 'Inativo'
  nomeComercial, gestor, aprendiz,
  // campos preenchidos manualmente no sistema (não vêm da planilha):
  afastadoINSS, pcd,
}
```

## Filtros disponíveis

- `filtroEmpresa` — por Empresa Registro
- Situação (Ativo/Inativo)
- Busca por nome ou matrícula

## Regras de negócio

- `pro_labore = true` → excluído de visualizações operacionais
- Ativo/Inativo determinado por `dataDemissao`, não pelo campo Situação da planilha
- Gestor vê apenas colaboradores do seu setor
- RH vê todos

## Chave de integração com outros módulos

O campo `codigo` (col 7, matrícula) é a chave usada para cruzar dados com outros módulos.
- No módulo Férias: coluna `Registro` da planilha de férias = `codigo` do cadastro
- No `CADASTRO_MAP` do módulo Férias: `Map<codigo, {empresa, empresaAtuacao, dataDemissao}>`
