-- Migration 066: Desabilitar RLS nas tabelas dp_*
-- Motivo: tabelas criadas via SQL Editor com RLS habilitado por default no Supabase.
-- Padrao do projeto: tabelas dev_* e colaboradores nao usam RLS (acesso controlado
-- pela camada de autenticacao do sistema via guardModulo + sb_session).

ALTER TABLE dp_escalas              DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_escala_opcoes        DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_criterios            DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_modelos              DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_versoes              DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_versao_blocos        DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_versao_criterios     DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_ciclos               DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_ciclo_participantes  DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_avaliacoes           DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_respostas            DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_resultados           DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_regras_financeiras        DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_regra_financeira_opcoes   DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_regra_financeira_faixas   DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_resultados_financeiros    DISABLE ROW LEVEL SECURITY;
ALTER TABLE dp_historico_eventos    DISABLE ROW LEVEL SECURITY;
