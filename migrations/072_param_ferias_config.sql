-- Migration 072: Tabela de configuração do módulo Férias
-- SistemaRH Revest do Brasil Acabamentos Ltda
-- Data: 2026-09-30
--
-- Contexto:
--   Centraliza parâmetros operacionais do módulo Férias que o RH
--   pode ajustar sem alterar código. Estrutura de linha única (singleton).
--
-- Parâmetros iniciais:
--   dias_resposta_visivel: quantos dias uma resposta do RH (aprovação ou
--   rejeição) fica visível na "Atividade Recente" do gestor antes de
--   migrar automaticamente para Histórico. Padrão: 7 dias.

CREATE TABLE IF NOT EXISTS param_ferias_config (
  id                      INTEGER PRIMARY KEY DEFAULT 1,
  dias_resposta_visivel   INTEGER NOT NULL DEFAULT 7,
  criado_em               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  atualizado_em           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT param_ferias_config_singleton CHECK (id = 1)
);

-- Seed: linha única
INSERT INTO param_ferias_config (id, dias_resposta_visivel)
VALUES (1, 7)
ON CONFLICT (id) DO NOTHING;

-- RLS: leitura pública (mesmo padrão das outras tabelas param_*)
ALTER TABLE param_ferias_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY "param_ferias_config_select"
  ON param_ferias_config FOR SELECT USING (true);

CREATE POLICY "param_ferias_config_update"
  ON param_ferias_config FOR UPDATE USING (true);

NOTIFY pgrst, 'reload schema';
