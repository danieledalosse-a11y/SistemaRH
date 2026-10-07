-- Migration 105 — alteracao_setor + ajustes nos eventos históricos da Mig 104
--
-- 105-A: param_tipo_transferencia adicionado ao CATS do módulo Parâmetros Gerais
--        (frontend apenas — modulos/parametros/index.html, commit 81e56c6)
--
-- 105-B: Novo tipo de evento 'alteracao_setor' em tipos_evento
--        Executado via REST API (Python). Documentado abaixo para controle de versão.
--
-- 105-C: Correção dos eventos históricos da Mig 104 (historico_eventos)
--        Pendente de execução — aguardando aprovação.

-- 105-B: INSERT tipos_evento[alteracao_setor]
-- (executado via REST API; este bloco é apenas documentação)
/*
INSERT INTO tipos_evento (codigo, categoria, label, icone_chave, dados_schema, resumo_template)
VALUES (
  'alteracao_setor',
  'carreira',
  'Mudança de Setor',
  'briefcase',
  '[
    {"tipo":"text","campo":"setor_anterior",       "label":"Setor anterior",         "obrigatorio":true},
    {"tipo":"text","campo":"setor_anterior_label",  "label":"Setor anterior (label)",  "obrigatorio":false},
    {"tipo":"text","campo":"setor_novo",            "label":"Setor novo",              "obrigatorio":true},
    {"tipo":"text","campo":"setor_novo_label",       "label":"Setor novo (label)",       "obrigatorio":false}
  ]'::JSONB,
  '{setor_anterior_label} → {setor_novo_label}'
);
*/

-- 105-C: Ajustes em historico_eventos (a executar)
-- Remover:  id=90 (Sabrina — normalização de setor, não é evento real)
-- Remover:  id=92 (Maria Luiza — redundante com promoção id=93)
-- Remover:  id=94 (Francisco — redundante com promoção id=95)
-- Substituir: id=91 (Ana Claudia transferencia → alteracao_setor SDI Adm → Matriz Adm)
-- Criar:    Gisele (mat=345) — promocao Assistente Administrativo → Assistente de Compras Jr., 2022-10-01
--           (colaborador_id a confirmar no banco antes da inserção)
