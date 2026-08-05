---
name: desenvolvimento
description: Especialista no módulo Desenvolvimento & Performance do SistemaRH Revest. Use este skill quando for implementar, depurar ou documentar qualquer coisa em modulos/desenvolvimento/index.html ou nos scripts Python de manutenção das tabelas dev_*.
---

# Skill: Módulo Desenvolvimento & Performance — SistemaRH Revest

## Contexto do projeto

Sistema RH da Revest do Brasil. Stack: HTML + CSS + JS puro, sem framework.
Backend: Supabase REST API (`https://rujtbxwssiofiialnbbg.supabase.co`).
Arquivo principal: `C:\Users\reves\SistemaRH\modulos\desenvolvimento\index.html` (CSS+JS inline).

## Regras obrigatórias

1. **Nunca separar CSS ou JS em arquivos externos** — tudo permanece inline no index.html.
2. **Nunca usar a chave secreta do Supabase no browser** — chave publicável apenas no index.html.
3. **Sempre apresentar proposta antes de implementar** — aguardar aprovação da usuária.
4. **Nunca abreviar valores monetários** (`R$ 12.500,00`, não `12,5k`).

## Tabelas Supabase (módulo desenvolvimento)

### `dev_competencias`
```
id, nome, descricao, tipo ('comportamental'|'tecnica'), area (TEXT), ativo (BOOL), created_at
```
- 39 competências pré-cadastradas (6 comportamentais + áreas: Logística, Vendas, Marketing, Projetos, Atendimento, Adm. Financeiro, Compras, E-commerce)
- Script de seed: `scripts/setup_desenvolvimento.py`

### `dev_ciclos`
```
id, nome, periodo_inicio (DATE), periodo_fim (DATE), prazo_auto_avaliacao (DATE),
prazo_gestor (DATE), status ('rascunho'|'aberto'|'fechado'), competencias_ids (JSONB [])
```
- `competencias_ids`: array de IDs das competências do ciclo. Se vazio, usa todas as competências ativas.
- Status: rascunho → aberto (ativo) → fechado

### `dev_avaliacoes`
```
id, ciclo_id (FK dev_ciclos), matricula_colaborador (TEXT),
notas_auto (JSONB {}), notas_gestor (JSONB {}), notas_rh (JSONB {}),
obs_auto, obs_gestor, obs_rh, status ('pendente'|'em_andamento'|'concluido'),
created_at, updated_at
```
- `notas_*`: `{ "competencia_id": nota_1_a_5 }` — chave é o ID da competência como string
- Uma avaliação por colaborador por ciclo (upsert por ciclo_id + matricula)

### `dev_pdi`
```
id, matricula_colaborador (TEXT), ciclo_id (FK),
acoes (JSONB [{ acao, prazo, area, done }]), created_at, updated_at
```
- `acoes`: array de objetos `{ acao: string, prazo: "YYYY-MM-DD"|"", area: string, done: bool }`
- Um PDI por colaborador (upsert por matricula). ciclo_id é opcional.

### `dev_historico`
```
id, matricula_colaborador, data (DATE), tipo ('avaliacao'|'pdi'|'admissao'|'ferias'|'geral'),
titulo, descricao, modulo_origem, referencia_id, created_by, created_at
```
- Timeline unificada do colaborador — qualquer módulo pode gravar aqui

### `colaboradores` — campo adicionado
```
foto_url TEXT  -- URL pública no Supabase Storage (nullable)
```

## Escala de notas (1–5)

| Nota | Rótulo | Cor |
|---|---|---|
| 1 | Insatisfatório | vermelho (`var(--red)`) |
| 2 | Em desenvolvimento | âmbar (`#B45309`) |
| 3 | Dentro do esperado | azul (`#026AA2`) |
| 4 | Acima do esperado | verde (`#027A48`) |
| 5 | Referência | roxo (`var(--purple)`) |

## Estrutura do módulo (abas)

| Aba | O que faz |
|---|---|
| Colaboradores | Lista com métricas, seletor de ciclo, filtros. Click abre drawer. |
| Ciclos de Avaliação | CRUD de ciclos, mudança de status (rascunho→aberto→fechado) |
| Competências | Biblioteca — ativar/desativar por competência |

## Drawer do colaborador (3 sub-abas)

- **Avaliação** — grid de competências do ciclo com escala 1-5, campo de observações. Salva em `dev_avaliacoes`.
- **PDI** — lista de ações com prazo, check de conclusão, exclusão. Salva em `dev_pdi`.
- **Histórico** — timeline da `dev_historico` — leitura apenas.

## Perfis (ainda não separados por login)

| Perfil | Permissão planejada |
|---|---|
| Colaborador | Preenche auto-avaliação |
| Gestor | Preenche avaliação do gestor + vê equipe |
| RH | Visão completa, cria ciclos e competências |

> Atualmente todos os usuários logados têm acesso completo (perfil RH). Separação por perfil é pendente.

## Padrão de acesso ao Supabase

```js
const SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const SB_KEY = 'eyJ...'; // publishable key
const HDR = { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=representation' };
async function sbGet(path)        { const r = await fetch(SB_URL+path,{headers:HDR}); return r.ok ? r.json() : []; }
async function sbPost(path,body)  { const r = await fetch(SB_URL+path,{method:'POST',  headers:HDR,body:JSON.stringify(body)}); return r.ok ? r.json() : null; }
async function sbPatch(path,body) { const r = await fetch(SB_URL+path,{method:'PATCH', headers:HDR,body:JSON.stringify(body)}); return r.ok ? r.json() : null; }
```

## Pendências / próximas features

- Upload de foto do colaborador no módulo Cadastro (campo `foto_url` já existe no banco)
- Separação de acesso por perfil (Colaborador / Gestor / RH)
- Avaliação do gestor (atualmente só auto-avaliação está implementada no drawer)
- Relatórios gerenciais (médias por área, evolução por ciclo)
- Marcar avaliação como "concluída" (status atual salva como `em_andamento`)
