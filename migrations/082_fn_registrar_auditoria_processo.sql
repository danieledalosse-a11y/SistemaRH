-- Migration 082 — fn_registrar_auditoria_processo
-- RPC para o frontend registrar ações de auditoria em processos.
-- O frontend NUNCA insere diretamente em processo_auditoria.
-- O usuario_id é capturado de auth.uid() — não do parâmetro.
--
-- Ações permitidas via esta função: criado, editado, aprovado, reprovado, cancelado.
-- A ação 'concluido' é registrada exclusivamente pelas RPCs fn_concluir_* (não aqui).
-- 'editado' exige dados_antes e dados_depois. As demais ações não devem recebê-los.

CREATE OR REPLACE FUNCTION fn_registrar_auditoria_processo(
  p_processo_id  BIGINT,
  p_acao         TEXT,
  p_usuario      TEXT,
  p_detalhe      TEXT    DEFAULT NULL,
  p_dados_antes  JSONB   DEFAULT NULL,
  p_dados_depois JSONB   DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Ações permitidas via frontend
  IF p_acao NOT IN ('criado','editado','aprovado','reprovado','cancelado') THEN
    RAISE EXCEPTION
      'Ação "%" não permitida via esta função. A ação "concluido" é registrada pelas RPCs fn_concluir_*.',
      p_acao;
  END IF;

  -- 'editado' exige snapshot antes e depois
  IF p_acao = 'editado' AND (p_dados_antes IS NULL OR p_dados_depois IS NULL) THEN
    RAISE EXCEPTION 'Ação "editado" requer dados_antes e dados_depois.';
  END IF;

  -- Demais ações não devem receber snapshot
  IF p_acao <> 'editado' AND (p_dados_antes IS NOT NULL OR p_dados_depois IS NOT NULL) THEN
    RAISE EXCEPTION 'Ação "%" não deve receber dados_antes/dados_depois.', p_acao;
  END IF;

  INSERT INTO processo_auditoria (
    processo_id, acao, detalhe, dados_antes, dados_depois, usuario, usuario_id
  ) VALUES (
    p_processo_id,
    p_acao,
    p_detalhe,
    p_dados_antes,
    p_dados_depois,
    p_usuario,
    auth.uid()
  );

  RETURN jsonb_build_object('ok', true);
END;
$$;
