-- Migration 055 — RLS: leitura pública de param_empresa
-- Mesmo padrão já adotado nas demais tabelas param_ (param_tipo_vinculo, param_cargo, etc.)
-- Permite SELECT para o role anon (chave publicável) — sem abrir escrita

CREATE POLICY "param_empresa_select_anon"
  ON public.param_empresa
  FOR SELECT
  TO anon
  USING (true);
