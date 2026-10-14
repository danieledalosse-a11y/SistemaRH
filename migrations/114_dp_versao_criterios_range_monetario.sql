-- 114_dp_versao_criterios_range_monetario.sql
-- Fase 3: range configurável para critérios numéricos (nota_min, nota_max)
-- Fase 4: valor monetário para critérios Sim/Não (valor_se_sim, valor_se_nao)
-- Opção B: resultado_bonus separado em dp_resultados
-- Correção: constraint escala_obrigatoria e função dp_validar_versao Regra 3
--
-- IMPORTANTE: Executar somente após autorização explícita do RH.
-- Todas as novas colunas são nullable → comportamento atual preservado.
-- Resultados históricos já calculados em dp_resultados não são afetados.

-- ============================================================
-- 1. Novas colunas em dp_versao_criterios
-- ============================================================

ALTER TABLE dp_versao_criterios
  ADD COLUMN IF NOT EXISTS nota_min      NUMERIC,
  ADD COLUMN IF NOT EXISTS nota_max      NUMERIC,
  ADD COLUMN IF NOT EXISTS valor_se_sim  NUMERIC,
  ADD COLUMN IF NOT EXISTS valor_se_nao  NUMERIC DEFAULT 0;

COMMENT ON COLUMN dp_versao_criterios.nota_min     IS 'Valor mínimo esperado para critérios numéricos (orientação e validação)';
COMMENT ON COLUMN dp_versao_criterios.nota_max     IS 'Valor máximo esperado para critérios numéricos (orientação e validação)';
COMMENT ON COLUMN dp_versao_criterios.valor_se_sim IS 'Valor monetário atribuído quando resposta binária = sim';
COMMENT ON COLUMN dp_versao_criterios.valor_se_nao IS 'Valor monetário atribuído quando resposta binária = não (padrão: 0)';

-- ============================================================
-- 2. Corrigir constraint escala_obrigatoria
--    Antes: binario E escala exigiam escala_id
--    Depois: apenas escala exige escala_id
--            (binário com valor_se_sim não precisa de escala_id)
-- ============================================================

ALTER TABLE dp_versao_criterios
  DROP CONSTRAINT IF EXISTS escala_obrigatoria;

ALTER TABLE dp_versao_criterios
  ADD CONSTRAINT escala_obrigatoria CHECK (
    tipo_resposta != 'escala' OR escala_id IS NOT NULL
  );

-- ============================================================
-- 3. Atualizar dp_validar_versao — Regra 3
--    Remover 'binario' do grupo que exige valor_numerico nas opções
--    (binário com valor_se_sim usa os campos da própria versao_criterios)
--    Todas as demais regras preservadas exatamente como em migration 068.
-- ============================================================

CREATE OR REPLACE FUNCTION dp_validar_versao(p_versao_id UUID)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_versao         dp_versoes%ROWTYPE;
  v_erros          JSONB    := '[]'::JSONB;
  v_calculaveis    INTEGER;
  v_escala_inv     INTEGER;
  v_incompativeis  INTEGER;
  v_sem_peso       INTEGER;
BEGIN
  SELECT * INTO v_versao FROM dp_versoes WHERE id = p_versao_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('erro', 'Versao nao encontrada');
  END IF;

  -- Regra 1: modelo nao-qualitativo precisa de ao menos um criterio calculavel
  IF v_versao.tipo_calculo != 'qualitativo' THEN
    SELECT COUNT(*) INTO v_calculaveis
    FROM dp_versao_criterios
    WHERE versao_id = p_versao_id AND contribui_calculo = true;
    IF v_calculaveis = 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', 1, 'mensagem', 'Nenhum criterio configurado como contribuinte para o calculo.');
    END IF;
  END IF;

  -- Regra 2: converte_para_conceito exige tabela_conceito_id preenchido
  IF v_versao.converte_para_conceito AND v_versao.tabela_conceito_id IS NULL THEN
    v_erros := v_erros || jsonb_build_object('regra', 2, 'mensagem', 'Conversao para conceito ativada sem tabela de conceito selecionada.');
  END IF;

  -- Regra 3: critérios calculáveis do tipo escala precisam de valor_numerico em todas as opções
  --          (binário com valor_se_sim usa campos próprios — não precisa de escala_id nem valor_numerico)
  IF v_versao.tipo_calculo != 'qualitativo' THEN
    SELECT COUNT(DISTINCT vc.id) INTO v_escala_inv
    FROM dp_versao_criterios vc
    JOIN dp_escala_opcoes eo ON eo.escala_id = vc.escala_id
    WHERE vc.versao_id = p_versao_id
      AND vc.tipo_resposta = 'escala'
      AND vc.contribui_calculo = true
      AND eo.valor_numerico IS NULL;
    IF v_escala_inv > 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', 3, 'mensagem', format('%s criterio(s) calculavel(eis) com opcoes de escala sem valor_numerico.', v_escala_inv));
    END IF;
  END IF;

  -- Regra 4: media_ponderada exige peso > 0 em todos os criterios calculaveis
  IF v_versao.tipo_calculo = 'media_ponderada' THEN
    SELECT COUNT(*) INTO v_sem_peso
    FROM dp_versao_criterios
    WHERE versao_id = p_versao_id AND contribui_calculo = true AND (peso IS NULL OR peso <= 0);
    IF v_sem_peso > 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', 4, 'mensagem', format('%s criterio(s) calculavel(eis) sem peso definido para media ponderada.', v_sem_peso));
    END IF;
  END IF;

  -- Regra 5a: percentual_atingimento exige numerico_com_meta em todos os calculaveis
  IF v_versao.tipo_calculo = 'percentual_atingimento' THEN
    SELECT COUNT(*) INTO v_incompativeis
    FROM dp_versao_criterios
    WHERE versao_id = p_versao_id AND contribui_calculo = true AND tipo_resposta != 'numerico_com_meta';
    IF v_incompativeis > 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', '5a', 'mensagem', format('Percentual de atingimento exige tipo numerico com meta em todos os criterios calculaveis (%s incompativel(eis)).', v_incompativeis));
    END IF;
  END IF;

  -- Regra 5b: qualitativo nao admite contribui_calculo = true
  IF v_versao.tipo_calculo = 'qualitativo' THEN
    SELECT COUNT(*) INTO v_incompativeis
    FROM dp_versao_criterios
    WHERE versao_id = p_versao_id AND contribui_calculo = true;
    IF v_incompativeis > 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', '5b', 'mensagem', format('Tipo qualitativo nao admite criterios contribuintes para calculo (%s encontrado(s)).', v_incompativeis));
    END IF;
  END IF;

  RETURN jsonb_build_object('erros', v_erros, 'valida', jsonb_array_length(v_erros) = 0);
END;
$$;

-- ============================================================
-- 4. Campo resultado_bonus em dp_resultados (Opção B)
--    Permite armazenar o resultado financeiro de critérios
--    binários com valor_se_sim separado da nota_final.
-- ============================================================

ALTER TABLE dp_resultados
  ADD COLUMN IF NOT EXISTS resultado_bonus NUMERIC;

COMMENT ON COLUMN dp_resultados.resultado_bonus IS 'Soma dos valores monetários de critérios binários (Opção B — independente da nota_final)';

-- ============================================================
-- 5. Atualizar constraint resultado_tem_valor em dp_resultados
--    Antes: nota_final IS NOT NULL OR conceito IS NOT NULL
--    Depois: inclui resultado_bonus como terceira opção válida
--    → modelos com APENAS critérios monetários podem ter
--      nota_final=null e conceito=null, desde que resultado_bonus
--      seja preenchido.
--    Resultados históricos: todos têm nota_final ou conceito
--    preenchidos, portanto passam na nova constraint sem alteração.
-- ============================================================

ALTER TABLE dp_resultados
  DROP CONSTRAINT IF EXISTS resultado_tem_valor;

ALTER TABLE dp_resultados
  ADD CONSTRAINT resultado_tem_valor CHECK (
    nota_final IS NOT NULL OR conceito IS NOT NULL OR resultado_bonus IS NOT NULL
  );
