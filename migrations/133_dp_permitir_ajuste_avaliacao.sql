-- 133_dp_permitir_ajuste_avaliacao.sql
--
-- Habilita o fluxo de ajuste de avaliações concluídas pelo RH/admin.
--
-- Problema: o trigger trg_bloquear_reverter_conclusao (migration 126) bloqueia
-- qualquer transição de 'concluida'/'publicada' para outro status. Isso impedia
-- dpAbrirAjuste de reverter para 'respondida', retornando HTTP 400.
--
-- Solução: exceção explícita e restrita no trigger — permite apenas a transição
-- concluida → respondida e somente quando auth_perfil() IN ('rh', 'admin').
-- Todas as demais proteções do trigger original ficam intactas:
--   - concluida  → nao_iniciada / em_andamento  : continua bloqueado
--   - publicada  → qualquer coisa               : continua bloqueado
--   - concluida  → respondida por gestor/outros  : continua bloqueado
--
-- Adicionalmente, registra os dois valores de evento que dpAbrirAjuste e
-- dpConcluirAjuste já usam no código mas nunca foram incluídos no ENUM.
-- Como dpRegistrarEvento é fire-and-forget (try/catch), a ausência não
-- causava erro visível, mas os registros de auditoria nunca eram gravados.
--
-- Compatibilidade:
--   - ALTER TYPE … ADD VALUE IF NOT EXISTS é idempotente (PostgreSQL 9.1+).
--   - Em Supabase, ADD VALUE precisa rodar fora de bloco de transação explícito.
--     No SQL Editor do Dashboard, cada instrução comita automaticamente — seguro.
--     Executar as três instruções separadamente se o cliente agrupa em transação.
--   - CREATE OR REPLACE FUNCTION substitui a versão anterior sem DROP; o trigger
--     existente (DROP/CREATE) continua apontando para a mesma função.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Adicionar valores ao ENUM dp_evento_historico
--    (Executar ANTES do restante; em ambientes que agrupam em transação,
--     commitar aqui e executar o bloco 2 em seguida.)
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS 'avaliacao_ajuste_iniciado';
ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS 'avaliacao_ajuste_concluido';

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Atualizar função do trigger de reversão de status
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION dp_fn_bloquear_reverter_conclusao()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Nenhuma restrição quando o status não saiu de 'concluida'/'publicada'
  IF OLD.status NOT IN ('concluida', 'publicada') THEN
    RETURN NEW;
  END IF;

  -- O status não mudou — nada a fazer
  IF NEW.status IN ('concluida', 'publicada') THEN
    RETURN NEW;
  END IF;

  -- Única exceção permitida: RH/admin pode reverter 'concluida' → 'respondida'
  -- para executar um ajuste pontual de respostas antes de reconcluir.
  -- 'publicada' não tem exceção — publicação é definitiva.
  IF OLD.status = 'concluida'
     AND NEW.status = 'respondida'
     AND auth_perfil() IN ('rh', 'admin') THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION
    'Avaliação % não pode ser reaberta (status atual: %, solicitado: %, perfil: %).',
    OLD.id, OLD.status, NEW.status, auth_perfil();
END;
$$;

-- O trigger já existe (migration 126); DROP/CREATE garante que aponta para a
-- função atualizada. Sem impacto em outros triggers da tabela.
DROP TRIGGER IF EXISTS trg_bloquear_reverter_conclusao ON dp_avaliacoes;
CREATE TRIGGER trg_bloquear_reverter_conclusao
  BEFORE UPDATE ON dp_avaliacoes
  FOR EACH ROW EXECUTE FUNCTION dp_fn_bloquear_reverter_conclusao();
