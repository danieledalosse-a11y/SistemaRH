-- Migration 069: Distinguir catálogo de biblioteca em dp_criterios
-- SistemaRH Revest do Brasil Acabamentos Ltda
-- Data: 2026-09-29
--
-- Problema resolvido:
--   dp_criterios misturava "sugestões do catálogo" com "critérios adotados pela Revest".
--   O campo dev_competencias_id indica origem (veio do seed), mas não adoção.
--   Este campo separa os dois conceitos sem duplicar registros.
--
-- Lógica:
--   na_biblioteca = false → sugestão do catálogo, não adotada ainda
--   na_biblioteca = true  → critério deliberadamente adotado pela Revest
--
-- Impacto no motor D&P: zero (dp_versoes, dp_ciclos, triggers não usam este campo)
-- Pré-condição: migration 065 executada (dp_criterios existe)


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 1: Adicionar coluna
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE dp_criterios
  ADD COLUMN na_biblioteca BOOLEAN NOT NULL DEFAULT false;


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 2: Marcar critérios criados pela Revest como adotados
-- (dev_competencias_id IS NULL = não veio do seed, foi criado pelo RH)
-- ═══════════════════════════════════════════════════════════════════════════

UPDATE dp_criterios
  SET na_biblioteca = true
  WHERE dev_competencias_id IS NULL;

-- Os 39 do seed (dev_competencias_id IS NOT NULL) ficam com na_biblioteca = false.
-- Adoção futura: UPDATE dp_criterios SET na_biblioteca = true WHERE id = '<uuid>'


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 3: Permissões
-- ═══════════════════════════════════════════════════════════════════════════

-- A tabela dp_criterios já tem GRANT de migrations anteriores.
-- Não é necessário regranting — a nova coluna herda as permissões da tabela.

NOTIFY pgrst, 'reload schema';


-- ═══════════════════════════════════════════════════════════════════════════
-- BLOCO 4: Validação (executar após os blocos acima e conferir resultados)
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Contagem geral — esperado: ~39 registros no catálogo, 0 na biblioteca (se nenhum foi criado)
-- SELECT
--   COUNT(*) FILTER (WHERE dev_competencias_id IS NOT NULL AND na_biblioteca = false) AS catalogo_nao_adotado,
--   COUNT(*) FILTER (WHERE dev_competencias_id IS NOT NULL AND na_biblioteca = true)  AS catalogo_adotado,
--   COUNT(*) FILTER (WHERE dev_competencias_id IS NULL     AND na_biblioteca = true)  AS biblioteca_revest,
--   COUNT(*) FILTER (WHERE dev_competencias_id IS NULL     AND na_biblioteca = false) AS inconsistente
-- FROM dp_criterios;

-- 2. Verificar que não existe o estado impossível (criado pelo RH mas não na biblioteca)
-- SELECT id, nome FROM dp_criterios
--   WHERE dev_competencias_id IS NULL AND na_biblioteca = false;
-- → deve retornar zero linhas

-- 3. Amostra do catálogo (esperado: 39 linhas com na_biblioteca = false)
-- SELECT id, nome, tipo, na_biblioteca FROM dp_criterios
--   WHERE dev_competencias_id IS NOT NULL
--   ORDER BY tipo, nome
--   LIMIT 10;

-- 4. Confirmar que motor D&P não foi afetado (estrutura de dp_versoes inalterada)
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'dp_versoes' ORDER BY ordinal_position;
