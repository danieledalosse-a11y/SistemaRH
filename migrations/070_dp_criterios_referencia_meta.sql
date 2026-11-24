-- Migration 070: Campos de referência e meta mensurável em dp_criterios
-- SistemaRH Revest do Brasil Acabamentos Ltda
-- Data: 2026-09-29
--
-- Escopo:
--   1. dp_criterios: adicionar referencia, meta_valor, meta_unidade
--   2. dp_meta_unidades: tabela parametrizável de unidades de meta
--
-- Todos os novos campos são opcionais (nullable).
-- Nenhum campo existente é alterado.
-- Motor D&P (dp_versoes, dp_ciclos, dp_versao_criterios, triggers): não tocado.
-- Critérios existentes continuam funcionando sem preenchimento retroativo.


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 1: Novos campos em dp_criterios
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE dp_criterios
  ADD COLUMN referencia   TEXT,       -- "Resultado esperado / Referência" — textual opcional
  ADD COLUMN meta_valor   NUMERIC,    -- valor numérico da meta conceitual (ex: 90)
  ADD COLUMN meta_unidade TEXT;       -- unidade da meta (ex: '%', 'R$') — referencia dp_meta_unidades.simbolo


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 2: Tabela de unidades de meta (parametrizável)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE dp_meta_unidades (
  id      UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
  label   TEXT     NOT NULL,          -- nome exibido (ex: "Porcentagem")
  simbolo TEXT     NOT NULL UNIQUE,   -- símbolo (ex: "%") — armazenado em meta_unidade
  ativo   BOOLEAN  NOT NULL DEFAULT true,
  ordem   SMALLINT NOT NULL DEFAULT 0
);

INSERT INTO dp_meta_unidades (label, simbolo, ordem) VALUES
  ('Porcentagem',  '%',        1),
  ('Reais',        'R$',       2),
  ('Quantidade',   'unid.',    3),
  ('Pontos',       'pts',      4),
  ('Horas',        'h',        5),
  ('Dias',         'dias',     6),
  ('Outro',        'outro',    7);


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 3: Permissões
-- ═══════════════════════════════════════════════════════════════════════════

GRANT SELECT, INSERT, UPDATE, DELETE ON dp_meta_unidades TO anon, authenticated;

NOTIFY pgrst, 'reload schema';


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 4: Validação
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Novos campos em dp_criterios (esperado: referencia, meta_valor, meta_unidade presentes)
-- SELECT column_name, data_type, is_nullable
--   FROM information_schema.columns
--   WHERE table_name = 'dp_criterios'
--     AND column_name IN ('referencia','meta_valor','meta_unidade')
--   ORDER BY column_name;

-- 2. Unidades cadastradas (esperado: 7 linhas)
-- SELECT simbolo, label, ordem FROM dp_meta_unidades ORDER BY ordem;

-- 3. Campos existentes intactos (esperado: nome, descricao, tipo, area, ativo, na_biblioteca presentes)
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'dp_criterios' ORDER BY ordinal_position;

-- 4. Motor intocado (esperado: nenhuma coluna nova em dp_versao_criterios)
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'dp_versao_criterios' ORDER BY ordinal_position;
