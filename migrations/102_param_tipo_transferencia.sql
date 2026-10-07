-- Migration 102 — param_tipo_transferencia
-- Parametriza os tipos de transferência, eliminando os valores hardcoded
-- 'unidade' e 'cnpj' do frontend (processos/index.html) e do backend
-- (fn_concluir_transferencia_cnpj).
--
-- Padrão: codigo estável para lógica programática + label editável pelo RH.
-- Histórico em historico_eventos.dados armazena ambos (codigo + label snapshot).

CREATE TABLE IF NOT EXISTS param_tipo_transferencia (
  codigo      TEXT PRIMARY KEY,
  label       TEXT        NOT NULL,
  descricao   TEXT,
  ordem       INT         NOT NULL DEFAULT 0,
  ativo       BOOLEAN     NOT NULL DEFAULT TRUE
);

INSERT INTO param_tipo_transferencia (codigo, label, descricao, ordem, ativo) VALUES
  ('unidade', 'Transferência de unidade',      'Altera apenas onde o colaborador atua (empresa_atuacao). O vínculo contratual (empresa_registro) permanece o mesmo.', 1, TRUE),
  ('cnpj',    'Alteração de CNPJ/contrato',    'Altera o vínculo contratual (empresa_registro) e onde o colaborador atua (empresa_atuacao). Gera novo contrato de trabalho.', 2, TRUE)
ON CONFLICT (codigo) DO NOTHING;
