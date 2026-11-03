---
name: feedback-browser-preview
description: NAO fazer verificacao visual pelo browser — confiar no build, usuaria testa no celular
metadata:
  node_type: memory
  type: feedback
  originSessionId: c2c9fa93-bdd1-47fe-bae3-0fef52960cf6
  modified: 2026-09-01T14:10:44.879Z
---

NAO fazer verificacao visual completa pelo browser embutido do Claude. Confiar em `npm run build` (ou equivalente) passando sem erros. A usuaria testa no celular/PC depois.

**Why:** Verificacao visual pelo browser consome muitos tokens e tempo — cada screenshot, scroll, preenchimento de campo e clique gera custo. A sessao de 2026-09-01 gastou a maior parte dos tokens tentando preencher formularios e tirar screenshots.

**How to apply:** Apos editar codigo frontend, rodar apenas o build. Se passar sem erros de TypeScript/lint, considerar pronto. Usar browser preview SOMENTE para debug de bug visual especifico que nao aparece no build. Nao iniciar dev server para "conferir se ficou bonito".

---

NUNCA abrir sessao do Claude de um projeto para trabalhar em outro. Cada projeto tem seu proprio diretorio e suas proprias sessoes.

**Why:** Sessao do PainelRH foi usada para trabalhar no Prompt Master, causando problemas de cwd, dev server com diretorio errado, e worktree desnecessario. A usuaria ficou "assustada" ao saber disso.

**How to apply:** Prompt Master: abrir Claude em `AMBIENTES VENDAS\prompt-master`. PainelRH: abrir em `4.0-FOLHA DE PAGAMENTO\CLAUDE\PainelRH`. SistemaRH: abrir em seu diretorio proprio. Nunca cruzar.
