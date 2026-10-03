-- Migration 073 — UNIQUE constraint em param_motivo_desligamento.codigo
-- Executar via Supabase Dashboard > SQL Editor
-- Contexto: após deduplicação da tabela (migration manual out/2026),
--           garantir que nenhum novo código duplicado seja inserido.

ALTER TABLE param_motivo_desligamento
ADD CONSTRAINT uq_pmd_codigo UNIQUE (codigo);
