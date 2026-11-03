---
name: logistica-state
description: "Estado atual do SistemaLogistica — stack, estrutura, premissas e pendências do projeto de roteirização"
metadata:
  node_type: memory
  type: project
  originSessionId: 8e11c10d-113b-4981-b647-572426f7bcda
  modified: 2026-10-22T21:13:27.725Z
---

## Premissa de desenvolvimento

Claude é o desenvolvedor. Dani define necessidades de negócio e valida resultados.
Dani pode fazer ações pontuais quando instruída com clareza (ex: rodar SQL no Supabase).
Priorizar soluções integradas, sem dependência técnica recorrente da usuária.

**Why:** A usuária não é da área técnica e não deve precisar resolver configurações técnicas por conta própria.

**How to apply:** Sempre fornecer instruções exatas quando uma ação da usuária for necessária. Nunca deixar uma etapa técnica implícita.

---

## Stack (React + Vite)

- **Frontend:** React 18 + Vite + vite-plugin-pwa (PWA/offline)
- **Banco:** Supabase (PostgreSQL, @supabase/supabase-js) — projeto NOVO, independente do SistemaRH
- **Hosting:** GitHub Pages — deploy automático via GitHub Actions (push → publicado em ~2 min)
- **Mapas:** Google Maps JS API
- **IA:** Claude API (Anthropic) — leitura PDF/JPEG + assistente
- **Importação:** SheetJS (xlsx npm package)
- **Roteamento:** react-router-dom v6

---

## Localização do projeto

```
C:\Dev\SistemaLogistica\
```

> Movido em 22/10/2026 da pasta OneDrive/SharePoint para evitar conflitos de sincronização com node_modules.

---

## Estrutura atual (criada)

```
SistemaLogistica/
├── CLAUDE.md
├── .claude/agents/logistica.md
├── .github/workflows/deploy.yml        ← GitHub Actions (build + deploy automático)
├── src/
│   ├── main.jsx, App.jsx
│   ├── components/{shared,planejamento,gestao}/
│   ├── pages/{Login,Home,NotFound}.jsx
│   ├── modules/{importacao,roteirizacao,frota,parametros}/
│   ├── services/{supabase,claude-api,geocodificacao}.js
│   ├── hooks/{useAuth,useParametros}.js
│   ├── styles/tokens.css
│   └── utils/formatters.js
├── supabase/migrations/ (001, 002, 003)
├── index.html, vite.config.js, package.json
├── .gitignore, .env.example
```

---

## O que ainda falta para começar o desenvolvimento

1. **Criar projeto Supabase** — projeto novo, separado do SistemaRH
2. **Executar migrations** no Supabase Dashboard (001, 002, 003)
3. **Preencher SB_URL e SB_KEY** em `index.html` e `permissoes.js`
4. **Criar repositório GitHub** para o projeto
5. **Configurar GitHub Pages**
6. **Obter amostra real do CSV do FRONTER F7** — define o parser de importação
7. **Implementar módulos** (planejamento, frota, parâmetros)

---

## Fase atual

Fase 1 — Planejamento & Roteirização. Estrutura base criada. Aguardando criação do Supabase para iniciar implementação.
