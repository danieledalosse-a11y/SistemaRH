---
name: feedback-tdz-constantes
description: "Regra crítica: constantes do index.html usadas em renderHomeGestor devem ficar ANTES da IIFE RBAC para evitar TDZ silencioso"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-10-08T19:13:19.873Z
---

Toda `const` em `index.html` que é usada (direta ou indiretamente) por qualquer função chamada sincronamente pela IIFE RBAC deve ser declarada **antes** da IIFE.

**Why:** A IIFE (linha ~418) chama `routeHomePerfil → renderHomeGestor` sincronamente. `const` declaradas depois da IIFE estão em Temporal Dead Zone (TDZ) nesse momento. Se uma dessas constantes for acessada dentro de `renderHomeGestor` ou de qualquer função por ela chamada, JavaScript lança `ReferenceError: Cannot access 'X' before initialization`. O `_hdGet` tem `try/catch` que **silencia** esse erro e retorna `[]` — fazendo a feature falhar sem nenhum log visível.

**Como identificar o problema:** a feature não funciona na carga da página, mas funciona ao chamar a mesma função manualmente no console (pois aí o script já foi todo executado e as constantes estão inicializadas).

**Constantes já movidas (bloco "Constantes declaradas antes da IIFE"):**
- `_AV_COLORS` — paleta de cores de avatares
- `_HD_URL` — URL do Supabase (fix commit e766d3e, 2026-10-08)
- `_HD_KEY` — chave publicável do Supabase (fix commit e766d3e, 2026-10-08)

**How to apply:** ao adicionar qualquer nova constante (`const`) que será referenciada em `renderHomeGestor` ou funções auxiliares da Home (`_hdGet`, `_hdHeaders`, `_avColor`, `_avHtml`, etc.), colocá-la **no bloco de constantes antes da IIFE** (~linha 415), nunca depois. Funções (`function` declarations) são hoisted com valor e não têm esse problema — só `const` e `let`.
