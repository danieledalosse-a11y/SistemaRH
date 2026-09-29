-- Migration 068: Corrigir dp_validar_versao após migration 067
-- Regra 2: faixas_conceito foi removido de dp_versoes (migration 067)
--          → verificar tabela_conceito_id IS NULL

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

  -- Regra 3: criterios calculaveis com escala precisam de valor_numerico em todas as opcoes
  IF v_versao.tipo_calculo != 'qualitativo' THEN
    SELECT COUNT(DISTINCT vc.id) INTO v_escala_inv
    FROM dp_versao_criterios vc
    JOIN dp_escala_opcoes eo ON eo.escala_id = vc.escala_id
    WHERE vc.versao_id = p_versao_id
      AND vc.tipo_resposta IN ('binario', 'escala')
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
