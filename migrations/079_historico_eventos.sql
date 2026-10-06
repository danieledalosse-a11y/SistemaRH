-- Migration 079 — historico_eventos
-- Tabela central da linha do tempo da Ficha do Colaborador.
-- Toda conclusão de processo grava aqui um evento padronizado.
-- O frontend lê exclusivamente desta tabela para montar a timeline.

CREATE TABLE historico_eventos (
  id                 BIGSERIAL    PRIMARY KEY,
  colaborador_id     BIGINT       NOT NULL
                                  REFERENCES colaboradores(id) ON DELETE RESTRICT,
  tipo               TEXT         NOT NULL
                                  REFERENCES tipos_evento(codigo),

  -- Conteúdo pronto para renderização (gerado pela RPC, não pelo frontend)
  titulo             TEXT         NOT NULL,
  resumo             TEXT,
  dados              JSONB,

  -- Data do fato (vigência / gozo / transferência) — nunca a data de registro
  data_evento        DATE         NOT NULL,

  -- Rastreabilidade
  registrado_por     TEXT         NOT NULL,    -- nome legível
  registrado_por_id  UUID,                     -- auth.uid() — referência estável
  registrado_em      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  -- Referência cruzada para dado especializado (soft FK)
  ref_tabela         TEXT,        -- ex: 'historico_remuneracao'
  ref_id             BIGINT,      -- ID na tabela especializada

  -- Processo que originou o evento
  processo_id        BIGINT       REFERENCES processos_rh(id),

  -- Origem: distingue eventos novos de dados convertidos do legado (fases futuras)
  origem             TEXT         NOT NULL DEFAULT 'sistema'
                                  CHECK (origem IN ('sistema','legado','manual')),

  -- Unicidade: um processo gera exatamente um evento por colaborador
  CONSTRAINT uq_evento_processo UNIQUE (colaborador_id, processo_id)
);

-- Índice principal de leitura (Ficha: por colaborador, cronológico)
CREATE INDEX idx_he_colab_data
  ON historico_eventos(colaborador_id, data_evento DESC);

-- Índice auxiliar para consultas por tipo
CREATE INDEX idx_he_tipo
  ON historico_eventos(tipo);

-- RLS
ALTER TABLE historico_eventos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "he_leitura_autenticada"
  ON historico_eventos FOR SELECT
  USING (auth.role() = 'authenticated');

-- Apenas RPCs SECURITY DEFINER podem inserir. Frontend nunca acessa diretamente.
CREATE POLICY "he_sem_escrita_direta"
  ON historico_eventos FOR INSERT
  WITH CHECK (FALSE);
