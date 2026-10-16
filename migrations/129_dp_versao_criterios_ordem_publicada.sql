-- Migration 129: permite alterar SOMENTE a coluna `ordem` em dp_versao_criterios
-- de uma versão publicada (em_uso=true).
--
-- Contexto: `ordem` é puramente cosmética — define a sequência de exibição dos
-- critérios no formulário de avaliação. Não interfere em cálculos, respostas,
-- históricos, snapshots, bônus ou comparabilidade entre ciclos.
--
-- A proteção de todos os campos estruturais permanece inalterada. O trigger
-- continua bloqueando qualquer UPDATE que altere tipo_resposta, escala_id,
-- peso, valor_se_sim, valor_se_nao, nota_min, nota_max, etc.
--
-- Requer: migration 116 (dp_fn_versao_proteger_em_uso) já aplicada.
-- NÃO EXECUTAR sem aprovação explícita da usuária.

CREATE OR REPLACE FUNCTION dp_fn_versao_proteger_em_uso()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_em_uso BOOLEAN;
BEGIN
  SELECT em_uso INTO v_em_uso
  FROM dp_versoes
  WHERE id = COALESCE(NEW.versao_id, OLD.versao_id);

  IF NOT v_em_uso THEN
    -- Versão não publicada: permite tudo
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;

  -- Versão publicada — duas exceções permitidas:

  -- Exceção 1 (migration 116): escrita do snapshot de nome (NULL → valor),
  --   sem alterar nenhum campo estrutural.
  IF TG_OP = 'UPDATE'
     AND NEW.criterio_nome_snapshot IS NOT NULL
     AND OLD.criterio_nome_snapshot IS NULL
     AND NEW.versao_id              = OLD.versao_id
     AND NEW.criterio_id            = OLD.criterio_id
     AND NEW.bloco_id               IS NOT DISTINCT FROM OLD.bloco_id
     AND NEW.ordem                  IS NOT DISTINCT FROM OLD.ordem
     AND NEW.tipo_resposta          = OLD.tipo_resposta
     AND NEW.escala_id              IS NOT DISTINCT FROM OLD.escala_id
     AND NEW.peso                   IS NOT DISTINCT FROM OLD.peso
     AND NEW.obrigatorio            = OLD.obrigatorio
     AND NEW.contribui_calculo      = OLD.contribui_calculo
     AND NEW.nota_min               IS NOT DISTINCT FROM OLD.nota_min
     AND NEW.nota_max               IS NOT DISTINCT FROM OLD.nota_max
     AND NEW.valor_se_sim           IS NOT DISTINCT FROM OLD.valor_se_sim
     AND NEW.valor_se_nao           IS NOT DISTINCT FROM OLD.valor_se_nao
     AND NEW.obs_condicao           IS NOT DISTINCT FROM OLD.obs_condicao
     AND NEW.instrucao_avaliador    IS NOT DISTINCT FROM OLD.instrucao_avaliador
  THEN
    RETURN NEW;
  END IF;

  -- Exceção 2 (migration 129): reordenação — somente `ordem` muda,
  --   todos os campos estruturais permanecem idênticos.
  IF TG_OP = 'UPDATE'
     AND NEW.versao_id              = OLD.versao_id
     AND NEW.criterio_id            = OLD.criterio_id
     AND NEW.criterio_nome_snapshot IS NOT DISTINCT FROM OLD.criterio_nome_snapshot
     AND NEW.bloco_id               IS NOT DISTINCT FROM OLD.bloco_id
     AND NEW.ordem                  IS DISTINCT FROM OLD.ordem       -- APENAS ordem muda
     AND NEW.tipo_resposta          = OLD.tipo_resposta
     AND NEW.escala_id              IS NOT DISTINCT FROM OLD.escala_id
     AND NEW.peso                   IS NOT DISTINCT FROM OLD.peso
     AND NEW.obrigatorio            = OLD.obrigatorio
     AND NEW.contribui_calculo      = OLD.contribui_calculo
     AND NEW.nota_min               IS NOT DISTINCT FROM OLD.nota_min
     AND NEW.nota_max               IS NOT DISTINCT FROM OLD.nota_max
     AND NEW.valor_se_sim           IS NOT DISTINCT FROM OLD.valor_se_sim
     AND NEW.valor_se_nao           IS NOT DISTINCT FROM OLD.valor_se_nao
     AND NEW.obs_condicao           IS NOT DISTINCT FROM OLD.obs_condicao
     AND NEW.instrucao_avaliador    IS NOT DISTINCT FROM OLD.instrucao_avaliador
  THEN
    RETURN NEW;
  END IF;

  -- Qualquer outra operação em versão publicada: bloquear
  RAISE EXCEPTION 'Esta versão está publicada e em uso. Crie uma nova versão para fazer alterações.';
END;
$$;

-- Triggers já existem (criados em 065b, substituídos em 116).
-- Apenas a função foi atualizada — nenhum trigger precisa ser recriado.
