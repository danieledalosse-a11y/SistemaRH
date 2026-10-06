-- Migration 081 — _validar_dados_evento
-- Função auxiliar: valida presença e tipo básico dos campos de dados JSONB
-- antes de qualquer INSERT em historico_eventos.
-- Chamada dentro das RPCs fn_concluir_* antes do INSERT.
-- Tipos suportados: currency, percent (numéricos), date, text.

CREATE OR REPLACE FUNCTION _validar_dados_evento(p_tipo TEXT, p_dados JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_schema    JSONB;
  v_campo     JSONB;
  v_valor     TEXT;
  v_num       NUMERIC;
  v_data      DATE;
BEGIN
  SELECT dados_schema INTO v_schema
  FROM tipos_evento
  WHERE codigo = p_tipo AND ativo = TRUE;

  IF v_schema IS NULL THEN
    RAISE EXCEPTION 'Tipo de evento "%" desconhecido ou inativo.', p_tipo;
  END IF;

  FOR v_campo IN SELECT value FROM jsonb_array_elements(v_schema) LOOP

    v_valor := p_dados->>(v_campo->>'campo');

    -- Verifica presença se obrigatório
    IF (v_campo->>'obrigatorio')::BOOLEAN = TRUE
       AND (v_valor IS NULL OR trim(v_valor) = '')
    THEN
      RAISE EXCEPTION
        'Campo obrigatório ausente ou vazio no evento tipo "%": campo "%".',
        p_tipo, v_campo->>'campo';
    END IF;

    -- Verifica compatibilidade de tipo se o valor está presente
    IF v_valor IS NOT NULL AND trim(v_valor) <> '' THEN
      CASE v_campo->>'tipo'
        WHEN 'currency', 'percent' THEN
          BEGIN
            v_num := v_valor::NUMERIC;
          EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
              'Campo "%" deve ser numérico. Valor recebido: "%".',
              v_campo->>'campo', v_valor;
          END;
        WHEN 'date' THEN
          BEGIN
            v_data := v_valor::DATE;
          EXCEPTION WHEN OTHERS THEN
            RAISE EXCEPTION
              'Campo "%" deve ser uma data válida (YYYY-MM-DD). Valor recebido: "%".',
              v_campo->>'campo', v_valor;
          END;
        WHEN 'text' THEN
          NULL; -- presença já verificada acima
        ELSE
          NULL; -- tipos futuros não causam erro (extensível sem alterar a função)
      END CASE;
    END IF;

  END LOOP;
END;
$$;
