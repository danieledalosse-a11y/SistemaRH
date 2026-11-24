-- Migration 148: Remove colunas empresa legado (empresa_registro_nome, empresa_atuacao_nome)
--
-- Pré-condições verificadas em 2026-11-24:
--   1. Zero referências em código executável em produção (Phase 1 concluída)
--   2. Zero dependências SQL: views, funções, RPCs e policies não usam essas colunas
--   3. Backup dos dados salvo em: RH - Documentos/backup_empresa_nome_colunas_2026-11-24.csv
--   4. Dados divergentes são valores pré-normalização; classificação descontinuada (migrations 008/009)
--
-- Registros corrigidos antes do DROP:
--   id=1801 ISABELA CRISTINA COSTA MARRIQUE  → empresa_atuacao = 'Paranavaí'
--   id=1669 RICARDO EMERSON DO NASCIMENTO    → empresa_atuacao = 'Matriz'

BEGIN;

-- ── Passo 1: Corrigir empresa_atuacao dos 2 colaboradores com valor vazio ──────

-- Validar estado anterior (deve retornar exatamente 2 linhas com empresa_atuacao NULL)
DO $$
DECLARE
  v_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO v_count
  FROM colaboradores
  WHERE id IN (1801, 1669)
    AND empresa_atuacao IS NULL
    AND empresa_atuacao_nome IS NOT NULL;

  IF v_count <> 2 THEN
    RAISE EXCEPTION
      'Pré-validação falhou: esperado 2 registros com empresa_atuacao NULL, encontrado %. '
      'Verifique o estado do banco antes de continuar.',
      v_count;
  END IF;
END $$;

-- Corrigir com valores explícitos conforme verificação de 2026-11-24
UPDATE colaboradores SET empresa_atuacao = 'Paranavaí'
WHERE id = 1801
  AND empresa_atuacao IS NULL;

UPDATE colaboradores SET empresa_atuacao = 'Matriz'
WHERE id = 1669
  AND empresa_atuacao IS NULL;

-- ── Passo 2: Validar que as correções foram aplicadas ────────────────────────

DO $$
DECLARE
  v_isabela TEXT;
  v_ricardo TEXT;
  v_vazios  INTEGER;
BEGIN
  SELECT empresa_atuacao INTO v_isabela FROM colaboradores WHERE id = 1801;
  SELECT empresa_atuacao INTO v_ricardo FROM colaboradores WHERE id = 1669;

  IF v_isabela <> 'Paranavaí' THEN
    RAISE EXCEPTION 'Correção falhou: id=1801 empresa_atuacao esperado ''Paranavaí'', obtido ''%''', v_isabela;
  END IF;

  IF v_ricardo <> 'Matriz' THEN
    RAISE EXCEPTION 'Correção falhou: id=1669 empresa_atuacao esperado ''Matriz'', obtido ''%''', v_ricardo;
  END IF;

  -- Confirmar que não existe nenhum empresa_atuacao vazio em toda a tabela
  SELECT COUNT(*) INTO v_vazios
  FROM colaboradores
  WHERE empresa_atuacao IS NULL OR empresa_atuacao = '';

  IF v_vazios > 0 THEN
    RAISE EXCEPTION
      'Validação pós-correção falhou: ainda existem % registros com empresa_atuacao vazio.',
      v_vazios;
  END IF;
END $$;

-- ── Passo 3: Remover colunas legado ─────────────────────────────────────────

ALTER TABLE colaboradores
  DROP COLUMN IF EXISTS empresa_registro_nome,
  DROP COLUMN IF EXISTS empresa_atuacao_nome;

COMMIT;
