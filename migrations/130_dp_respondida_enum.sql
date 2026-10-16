-- Migration 130: Adiciona o valor 'respondida' ao ENUM dp_status_avaliacao.
--
-- Representa avaliação com todos os critérios preenchidos, aguardando
-- conclusão formal pelo RH ou gestor. Fica entre 'em_andamento' e 'concluida'.
--
-- ATENÇÃO: Esta migration DEVE ser executada e confirmada (committed) ANTES
-- da migration 131, que cria o trigger que depende do ENUM atualizado.
-- Executar as duas na mesma transação pode causar erro no PostgreSQL.
--
-- NÃO EXECUTAR sem aprovação explícita da usuária.

ALTER TYPE dp_status_avaliacao ADD VALUE IF NOT EXISTS 'respondida' BEFORE 'concluida';
