-- 118_dp_tipo_elegibilidade_atualizar_enum.sql
-- O ENUM dp_tipo_elegibilidade foi criado na migration 065 com valores desatualizados
-- ('setor', 'cargo', 'unidade', 'lista_nominal'). O código JS usa 'por_setor',
-- 'por_cargo', 'por_gestor', 'por_colaborador'. Nenhum ciclo existe — sem dados a migrar.
-- Solução: recriar a coluna e o ENUM com os valores corretos.

-- 1. Remover a coluna que referencia o ENUM
ALTER TABLE dp_ciclos DROP COLUMN IF EXISTS tipo_elegibilidade;

-- 2. Dropar o ENUM antigo
DROP TYPE IF EXISTS dp_tipo_elegibilidade;

-- 3. Recriar com valores corretos (alinhados com o código JS)
CREATE TYPE dp_tipo_elegibilidade AS ENUM (
  'todos',
  'por_setor',
  'por_cargo',
  'por_gestor',
  'por_colaborador'
);

-- 4. Recriar a coluna
ALTER TABLE dp_ciclos
  ADD COLUMN tipo_elegibilidade dp_tipo_elegibilidade NOT NULL DEFAULT 'todos';
