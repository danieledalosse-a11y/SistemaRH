-- 141_corrigir_em_experiencia.sql
-- Corrige campo em_experiencia para colaboradores cujo período já encerrou.
-- Afeta somente registros com data_fim_experiencia preenchida e no passado.
-- A regra de exibição no sistema já não depende deste campo (usa data_fim_experiencia),
-- mas a correção elimina inconsistência nos dados e facilita auditorias futuras.

-- ─── VERIFICAÇÃO PRÉVIA ────────────────────────────────────────────────────────
-- Execute este bloco primeiro para confirmar quais registros serão afetados.
-- Esperado: ~20 registros.

SELECT matricula, nome, data_admissao, data_fim_experiencia, em_experiencia
FROM colaboradores
WHERE em_experiencia = true
  AND data_fim_experiencia IS NOT NULL
  AND data_fim_experiencia < CURRENT_DATE
ORDER BY data_admissao;

-- ─── NOTAS SOBRE REVERSÃO ──────────────────────────────────────────────────────
-- O campo em_experiencia é boolean sem histórico automático.
-- A correção é segura pois:
--   1. A regra de exibição do sistema não depende mais deste campo após este ajuste
--      (usa data_fim_experiencia, que permanece intacta).
--   2. O valor correto é derivável de data_fim_experiencia sempre que necessário.
-- Para reverter caso necessário (substituir as matrículas conforme a consulta acima):
--   UPDATE colaboradores SET em_experiencia = true WHERE matricula IN ('001', '002', ...);

-- ─── CORREÇÃO ─────────────────────────────────────────────────────────────────
-- Execute SOMENTE após confirmar a consulta de verificação prévia acima.

UPDATE colaboradores
SET em_experiencia = false
WHERE em_experiencia = true
  AND data_fim_experiencia IS NOT NULL
  AND data_fim_experiencia < CURRENT_DATE;
-- Afeta: ~20 registros

-- ─── VERIFICAÇÕES PÓS-EXECUÇÃO ────────────────────────────────────────────────

-- 1. Deve retornar 0 (nenhum registro incorreto restante):
SELECT COUNT(*) AS incorretos_restantes
FROM colaboradores
WHERE em_experiencia = true
  AND data_fim_experiencia IS NOT NULL
  AND data_fim_experiencia < CURRENT_DATE;

-- 2. Mostra quantos ainda estão legitimamente em experiência:
SELECT COUNT(*) AS em_experiencia_vigente
FROM colaboradores
WHERE em_experiencia = true
  AND (data_fim_experiencia IS NULL OR data_fim_experiencia >= CURRENT_DATE);

-- 3. Lista completa dos que continuam em experiência (para conferência manual):
SELECT matricula, nome, data_admissao, data_fim_experiencia
FROM colaboradores
WHERE em_experiencia = true
  AND (data_fim_experiencia IS NULL OR data_fim_experiencia >= CURRENT_DATE)
ORDER BY data_fim_experiencia;
