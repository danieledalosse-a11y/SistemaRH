-- Adiciona colunas para rastreamento de gozo real (acordos informais)
-- na tabela ferias.
--
-- realizacoes: lista de utilizações parciais do período oficial
--   [{ saida, retorno, dias, obs, criadoEm }, ...]
--
-- obs_gestor: acordo informal registrado pelo RH (visível apenas ao RH
--   na aba Acordos/Realizações do drawer)

ALTER TABLE ferias
  ADD COLUMN IF NOT EXISTS realizacoes  JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS obs_gestor   TEXT;

COMMENT ON COLUMN ferias.realizacoes IS
  'Lista de utilizações reais de férias (gozo fracionado). '
  'Cada item: { saida: date, retorno: date, dias: int, obs: text|null, criadoEm: timestamptz }';

COMMENT ON COLUMN ferias.obs_gestor IS
  'Acordo informal entre gestor e colaborador sobre período real de gozo. '
  'Visível apenas ao RH na aba Acordos do painel de férias.';
