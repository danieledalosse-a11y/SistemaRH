-- Migration 039: Histórico de valores do bônus de indicação
CREATE TABLE IF NOT EXISTS param_bonus_indicacao (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  valor        NUMERIC(10,2) NOT NULL,
  vigencia_inicio DATE NOT NULL,
  vigencia_fim    DATE,                    -- NULL = vigente até hoje
  observacao   TEXT,
  criado_por   TEXT,
  criado_em    TIMESTAMPTZ DEFAULT NOW()
);

-- Habilitar RLS e permitir leitura pública (mesmo padrão das outras param_*)
ALTER TABLE param_bonus_indicacao ENABLE ROW LEVEL SECURITY;
CREATE POLICY "leitura publica" ON param_bonus_indicacao FOR SELECT USING (true);
CREATE POLICY "escrita autenticada" ON param_bonus_indicacao FOR ALL USING (auth.role() = 'authenticated');

-- Registros históricos — ajuste as datas conforme necessário
INSERT INTO param_bonus_indicacao (valor, vigencia_inicio, vigencia_fim, observacao, criado_por) VALUES
  (300.00, '2024-01-01', '2026-06-30', 'Valor inicial do bônus de indicação', 'RH Revest'),
  (500.00, '2026-07-01', NULL,         'Reajuste aprovado — julho/2026',       'RH Revest');
