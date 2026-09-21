# Módulo Cadastro — Instruções para o Claude

## O que faz

Consulta e visualização de colaboradores da Revest do Brasil. Lê dados do Supabase e exibe cards/tabela com filtros por empresa, setor, situação, vínculo etc.

## Arquivo

`modulos/cadastro/index.html` — autocontido (CSS + JS inline).

## Fonte de dados

**Supabase** — tabela `colaboradores`. Não usa mais planilha xlsx.

## Modelo de dados (`COLABORADORES[]`)

Mapeado pela função `supabaseToJS(row)`:

```js
{
  _sbId,            // colaboradores.id
  matricula,        // col matricula
  nome,
  cargo,
  dataAdmissao,
  dataIngressoGrupo,
  dataNascimento,
  dataDemissao,
  empresa,          // empresa_registro (nome_simplificado)
  empresaAtuacao,   // empresa_atuacao
  setor,
  gestor,
  sexo,
  pcd,              // boolean
  aprendiz,         // boolean (derivado de isAprendiz(cargo))
  proLabore,        // boolean — mapeado de colaboradores.pro_labore
  tipoVinculo,      // 'clt' | 'pro_labore' | 'promotora'
  situacao,         // 'Ativo' | 'Inativo' (derivado de data_demissao)
  dependentesLista, // JSONB [{nome, parentesco, data_nascimento}]
}
```

## Parametrizações usadas

| Tabela | Campo | Uso |
|---|---|---|
| `param_setor` | `descricao`, `empresa_codigo` | Lista de setores no formulário |
| `param_cargo` | `nome` | Lista de cargos no formulário |
| `param_tipo_vinculo` | `codigo`, `descricao` | Lista de vínculos |
| `param_empresa` | `nome_simplificado` | Empresas disponíveis |

### Regra obrigatória — `param_setor` e setor

O campo Setor do colaborador é **sempre carregado de `param_setor`** — sem valores fixos no código.

```js
// Carregamento (init)
SETORES = await sbGet('param_setor', 'select=descricao,empresa_codigo&ativo=eq.true&order=ordem,descricao');

// População do select no formulário (filtrada por empresa_codigo quando aplicável)
```

**Nunca hardcodar setor no código.** Qualquer setor novo deve ser criado em `param_setor` via Parâmetros Gerais.

### Regra obrigatória — `tipo_vinculo` vs setor

- **`tipo_vinculo`** identifica o vínculo contratual (`'clt'`, `'pro_labore'`, `'promotora'`) — **fonte única de verdade** para lógica de negócio
- **`setor`** representa a área organizacional — campo independente, vem de `param_setor`
- **Nunca** usar `setor` ou `cargo` para identificar pró-labore ou promotora no código
- O setor `'Pro-labore'` existe em `param_setor` (id=21) e é o setor organizacional dos sócios; isso **não substitui** a identificação pelo `tipo_vinculo`

## Regras de negócio

- `tipoVinculo === 'pro_labore'` → excluído de visualizações operacionais (quadro, métricas de CLT)
- Ativo/Inativo determinado por `data_demissao` (null = Ativo)
- Gestor vê apenas colaboradores do seu setor
- RH vê todos
- `aprendiz` detectado por palavras-chave no cargo ("aprendiz", "jovem aprendiz")

## Controle de acesso

Carrega `permissoes.js` e chama `guardModulo('cadastro')`. Ver [[permissoes]].

## Chave de integração com outros módulos

O campo `matricula` (ou `_sbId`) é a chave para cruzar dados com outros módulos.
