---
name: feedback-return-minimal
description: "Lição aprendida: return=representation em escritas Supabase dobra custo de RLS — sempre usar return=minimal em saves D&P e qualquer módulo que não precise do retorno do banco"
metadata:
  node_type: memory
  type: feedback
  modified: 2026-10-23T20:45:53.501Z
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
---

Toda operação de escrita via PostgREST com `Prefer: return=representation` faz o banco executar **dois passes de RLS**: um para a escrita (INSERT/UPDATE) e um para o SELECT que retorna as linhas. Com políticas RLS complexas (subqueries aninhadas), isso dobra o custo.

**Why:** Diagnóstico D&P em 2026-10-23: UPSERT dp_respostas ~4.700ms, PATCH dp_avaliacoes ~1.850ms = ~6.500ms total. Após mudar para `return=minimal`: ~580ms + ~360ms = ~940ms — redução de 86%.

**How to apply:**
- Em qualquer operação de escrita onde o retorno do banco **não é necessário para prosseguir** (o código não usa campos gerados pelo banco como `id`, `created_at`, nem campos computados por triggers): usar `return=minimal`.
- Para o D&P especificamente: usar `_dpUpsertMinimal` e `_dpPatchMinimal` (funções locais já implementadas) em `salvarAvaliacao()` e `_dpSalvarParaNavegar()`.
- Para novos módulos: antes de usar `return=representation` em um save, perguntar: "Precisamos do retorno do banco para algo?" Se não, usar `return=minimal` desde o início.
- Atualizar memória local com merge por chave natural (não depender do retorno do banco para sincronizar estado).
- As funções globais `sbUpsert`/`sbPatch` mantêm `return=representation` para não quebrar outros usos — criar variantes locais `_<modulo>UpsertMinimal` / `_<modulo>PatchMinimal` por módulo.

**Schema cache Supabase (plano gratuito):** ao criar funções novas via SQL Editor, o PostgREST pode demorar ~15 minutos para reconhecê-las na execução (PGRST202). O OpenAPI spec (`/rest/v1/`) e o `curl` com service key confirmam disponibilidade, mas o browser com JWT de usuário pode ainda receber 404 até o cache sincronizar.
