-- ============================================================
-- MIGRAÇÃO 007: Cria param_tipo_contrato, param_motivo_desligamento
--               e param_regime_horas se ainda não existirem;
--               popula valores iniciais.
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

-- ── param_tipo_contrato ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS param_tipo_contrato (
  id        SERIAL PRIMARY KEY,
  ordem     INTEGER DEFAULT 0,
  codigo    TEXT,
  descricao TEXT NOT NULL,
  ativo     BOOLEAN DEFAULT TRUE
);

INSERT INTO param_tipo_contrato (ordem, codigo, descricao) VALUES
  (1, 'CLT',       'CLT'),
  (2, 'PJ',        'PJ'),
  (3, 'APRENDIZ',  'Jovem Aprendiz'),
  (4, 'ESTAGIO',   'Estágio'),
  (5, 'TEMP',      'Temporário'),
  (6, 'AUTONOMO',  'Autônomo')
ON CONFLICT DO NOTHING;

-- ── param_motivo_desligamento ────────────────────────────────
CREATE TABLE IF NOT EXISTS param_motivo_desligamento (
  id        SERIAL PRIMARY KEY,
  ordem     INTEGER DEFAULT 0,
  codigo    TEXT,
  descricao TEXT NOT NULL,
  ativo     BOOLEAN DEFAULT TRUE
);

INSERT INTO param_motivo_desligamento (ordem, codigo, descricao) VALUES
  (1,  '0.0',  'Colaborador Pediu Encerramento'),
  (2,  '0.1',  'Demitido no Período de Experiência'),
  (3,  '0.2',  'Demitido s/ Justa Causa'),
  (4,  '0.3',  'Demitido com Justa Causa'),
  (5,  '0.4',  'Pediu Demissão'),
  (6,  '0.5',  'JOVEM - Encerramento de Contrato'),
  (7,  '0.6',  'JOVEM - Pediu Encerramento'),
  (8,  '0.7',  'Acordo'),
  (9,  '0.9',  'Transferência'),
  (10, '10.0', 'Abandono de Emprego'),
  (11, '11.0', 'Morte')
ON CONFLICT DO NOTHING;

-- ── param_regime_horas ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS param_regime_horas (
  id           SERIAL PRIMARY KEY,
  ordem        INTEGER DEFAULT 0,
  codigo       TEXT,
  descricao    TEXT NOT NULL,
  horas_dia    TEXT,
  horas_semana TEXT,
  horas_mes    TEXT,
  ativo        BOOLEAN DEFAULT TRUE
);

INSERT INTO param_regime_horas (ordem, codigo, descricao, horas_dia, horas_semana, horas_mes) VALUES
  (1, '44H',   'CLT 44h semanais', '08:00', '44:00', '220:00'),
  (2, '36H',   'CLT 36h semanais', '07:12', '36:00', '180:00'),
  (3, 'PARC',  'Tempo parcial',    '06:00', '30:00', '150:00'),
  (4, 'HOME',  'Teletrabalho',     '08:00', '44:00', '220:00'),
  (5, '12X36', 'Escala 12x36',     '12:00', '36:00', '180:00'),
  (6, 'APREN', 'Aprendiz',         '06:00', '30:00', '150:00')
ON CONFLICT DO NOTHING;
