-- Migration 080 — processo_auditoria
-- Registra quem fez o quê em cada processo RH.
-- NÃO aparece na timeline do colaborador — é auditoria interna.
--
-- Regras de preenchimento por ação:
--   criado    → dados_antes=NULL, dados_depois=NULL
--   editado   → dados_antes=snapshot anterior, dados_depois=snapshot novo
--   aprovado  → dados_antes=NULL, dados_depois=NULL
--   reprovado → dados_antes=NULL, dados_depois=NULL
--   concluido → dados_antes=NULL, dados_depois=NULL (gravado pela RPC fn_concluir_*)
--   cancelado → dados_antes=NULL, dados_depois=NULL
--
-- Apenas 'concluido' gera evento em historico_eventos. As demais ações são auditoria pura.

CREATE TABLE processo_auditoria (
  id                 BIGSERIAL    PRIMARY KEY,
  processo_id        BIGINT       NOT NULL
                                  REFERENCES processos_rh(id) ON DELETE RESTRICT,
  acao               TEXT         NOT NULL
                                  CHECK (acao IN (
                                    'criado','editado','aprovado','reprovado','concluido','cancelado'
                                  )),
  detalhe            TEXT,
  dados_antes        JSONB,       -- preenchido apenas em 'editado'
  dados_depois       JSONB,       -- preenchido apenas em 'editado'
  usuario            TEXT         NOT NULL,    -- nome legível
  usuario_id         UUID,                     -- auth.uid() — referência estável
  criado_em          TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_pa_processo
  ON processo_auditoria(processo_id, criado_em DESC);

ALTER TABLE processo_auditoria ENABLE ROW LEVEL SECURITY;

CREATE POLICY "pa_leitura_autenticada"
  ON processo_auditoria FOR SELECT
  USING (auth.role() = 'authenticated');

-- Apenas RPCs SECURITY DEFINER inserem (via fn_registrar_auditoria_processo ou fn_concluir_*)
CREATE POLICY "pa_sem_escrita_direta"
  ON processo_auditoria FOR INSERT
  WITH CHECK (FALSE);
