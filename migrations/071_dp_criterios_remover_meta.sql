-- Migration 071: Remover campos de meta numérica de dp_criterios
-- SistemaRH Revest do Brasil Acabamentos Ltda
-- Data: 2026-09-29
--
-- Contexto:
--   Migration 070 criou meta_valor, meta_unidade e dp_meta_unidades.
--   Após revisão de UX, o conceito foi simplificado:
--   a competência terá apenas "referencia" (Resultado esperado — texto livre).
--   Meta operacional permanece exclusivamente no motor (dp_versao_criterios).
--
-- Pré-condição: todos os campos têm apenas NULL (zero dados a preservar).
-- Motor D&P: não referencia esses campos.


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 1: Remover colunas de meta de dp_criterios
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE dp_criterios
  DROP COLUMN meta_valor,
  DROP COLUMN meta_unidade;


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 2: Remover tabela de unidades (sem FKs externas, sem dados)
-- ═══════════════════════════════════════════════════════════════════════════

DROP TABLE dp_meta_unidades;


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 3: Reload schema
-- ═══════════════════════════════════════════════════════════════════════════

NOTIFY pgrst, 'reload schema';


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 4: Validação
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Confirmar que meta_valor e meta_unidade foram removidos (esperado: zero linhas)
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'dp_criterios'
--     AND column_name IN ('meta_valor', 'meta_unidade');

-- 2. Confirmar que dp_meta_unidades não existe mais (esperado: zero linhas)
-- SELECT table_name FROM information_schema.tables
--   WHERE table_name = 'dp_meta_unidades';

-- 3. Confirmar que referencia permanece (esperado: 1 linha)
-- SELECT column_name, data_type FROM information_schema.columns
--   WHERE table_name = 'dp_criterios' AND column_name = 'referencia';
