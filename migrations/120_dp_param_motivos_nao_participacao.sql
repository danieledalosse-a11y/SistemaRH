-- 120_dp_param_motivos_nao_participacao.sql
-- Cria tabela de motivos configuráveis para "não participa deste ciclo".
-- RH/admin: leitura + escrita. Gestor/Diretoria: somente leitura (motivos ativos).

CREATE TABLE IF NOT EXISTS dp_param_motivos_nao_participacao (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  descricao   TEXT        NOT NULL,
  ativo       BOOLEAN     NOT NULL DEFAULT TRUE,
  criado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE dp_param_motivos_nao_participacao ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'dp_param_motivos_nao_participacao'
    AND policyname = 'dp_motivos_nao_part_rh_all'
  ) THEN
    CREATE POLICY dp_motivos_nao_part_rh_all ON dp_param_motivos_nao_participacao
      FOR ALL TO authenticated
      USING  (auth_perfil() IN ('rh','admin'))
      WITH CHECK (auth_perfil() IN ('rh','admin'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'dp_param_motivos_nao_participacao'
    AND policyname = 'dp_motivos_nao_part_outros_sel'
  ) THEN
    CREATE POLICY dp_motivos_nao_part_outros_sel ON dp_param_motivos_nao_participacao
      FOR SELECT TO authenticated
      USING (
        auth_perfil() IN ('gestor','diretoria')
        AND ativo = TRUE
      );
  END IF;
END $$;

-- Seed inicial
INSERT INTO dp_param_motivos_nao_participacao (descricao, ativo) VALUES
  ('Afastamento médico / INSS',            TRUE),
  ('Licença maternidade / paternidade',     TRUE),
  ('Desligamento em andamento',             TRUE),
  ('Outros (especificar na observação)',    TRUE)
ON CONFLICT DO NOTHING;
