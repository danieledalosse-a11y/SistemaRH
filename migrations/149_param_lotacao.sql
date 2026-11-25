-- Migration 149: tabela param_lotacao + coluna colaboradores.lotacao
-- Seed inicial a partir de empresa_atuacao (casing original preservado, sem duplicatas)

CREATE TABLE IF NOT EXISTS param_lotacao (
  id          serial PRIMARY KEY,
  descricao   text    NOT NULL,
  ativo       boolean NOT NULL DEFAULT true,
  ordem       int     NOT NULL DEFAULT 0,
  CONSTRAINT param_lotacao_descricao_unique UNIQUE (descricao)
);

-- Seed: valores distintos de empresa_atuacao, casing original preservado.
-- Deduplicação por lower(trim()) — quando há variações de maiúsculas/espaços
-- só o primeiro valor encontrado (order by empresa_atuacao) é inserido.
-- ON CONFLICT DO NOTHING está amparado pela constraint acima.
WITH base AS (
  SELECT
    TRIM(empresa_atuacao)                                   AS descricao,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(TRIM(empresa_atuacao))
      ORDER BY empresa_atuacao
    ) AS rn,
    DENSE_RANK() OVER (
      ORDER BY LOWER(TRIM(empresa_atuacao))
    ) AS ordem
  FROM colaboradores
  WHERE empresa_atuacao IS NOT NULL
    AND TRIM(empresa_atuacao) <> ''
)
INSERT INTO param_lotacao (descricao, ordem)
SELECT descricao, ordem
FROM base
WHERE rn = 1
ON CONFLICT (descricao) DO NOTHING;

-- Adiciona coluna lotacao em colaboradores (nulo por padrão — sem alterar cadastros existentes)
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS lotacao text;
