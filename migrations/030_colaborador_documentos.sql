-- Pasta Funcional Digital: documentos dos colaboradores
-- Executar no Supabase SQL Editor

CREATE TABLE IF NOT EXISTS colaborador_documentos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  colaborador_id  bigint NOT NULL REFERENCES colaboradores(id) ON DELETE CASCADE,
  nome            text NOT NULL,
  categoria       text NOT NULL CHECK (categoria IN ('admissao','contrato','saude','vt','financeiro','rescisao','outros')),
  url             text NOT NULL,
  tipo_arquivo    text NOT NULL DEFAULT 'pdf' CHECK (tipo_arquivo IN ('pdf','imagem','outro')),
  data_documento  date,
  data_validade   date,
  criado_em       timestamptz NOT NULL DEFAULT now(),
  criado_por      text
);

CREATE INDEX IF NOT EXISTS idx_colab_docs_colaborador ON colaborador_documentos(colaborador_id);
CREATE INDEX IF NOT EXISTS idx_colab_docs_validade    ON colaborador_documentos(data_validade) WHERE data_validade IS NOT NULL;

-- RLS: mesma política das demais tabelas (anon com chave publicável)
ALTER TABLE colaborador_documentos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_all" ON colaborador_documentos
  FOR ALL TO anon USING (true) WITH CHECK (true);
