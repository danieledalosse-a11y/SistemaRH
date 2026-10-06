-- Migration 084 — Correções de arquitetura (Fase 2 Parte A)
--
-- 1. Adiciona categoria 'desempenho' ao CHECK de tipos_evento
--    para suportar eventos de D&P (avaliações, PDI, feedback).
--
-- 2. Cria índice parcial de unicidade em historico_eventos
--    para eventos vinculados a tabelas específicas via ref_tabela/ref_id
--    (férias, dev_avaliacoes, etc.) — previne duplicatas sem processo_id.

-- ── 1. Categoria desempenho ──────────────────────────────────────────────────
ALTER TABLE tipos_evento
  DROP CONSTRAINT tipos_evento_categoria_check;

ALTER TABLE tipos_evento
  ADD CONSTRAINT tipos_evento_categoria_check
  CHECK (categoria IN (
    'financeiro',
    'carreira',
    'beneficio',
    'ausencia',
    'cadastro',
    'desempenho'
  ));

-- ── 2. Unicidade por ref_tabela/ref_id (apenas quando ref_id está preenchido) ─
-- Garante que um mesmo registro de outra tabela não gere dois eventos.
-- NULLs são excluídos: eventos manuais ou sem referência cruzada são permitidos.
CREATE UNIQUE INDEX uq_evento_ref
  ON historico_eventos(colaborador_id, ref_tabela, ref_id)
  WHERE ref_id IS NOT NULL;
