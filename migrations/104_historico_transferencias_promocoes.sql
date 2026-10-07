-- Migration 104 — historico_eventos: 7 eventos históricos de transferência e promoção
-- Registra os eventos de transferência interna e promoção de 5 colaboradores
-- que tiveram quebra de vínculo (inativo → ativo) sem registro de evento na timeline.
--
-- Execução: via script Python (val_mig104.py) — REST API Supabase.
-- Esta migration documenta os registros para controle de versão.
--
-- Atualiza também dados_schema do tipo 'transferencia' em tipos_evento para
-- documentar o campo tipo_transferencia_label (snapshot do label parametrizado).
--
-- Eventos inseridos:
-- 1. Marcilene (1787)  — transferencia  2025-05-01  CD → Red
-- 2. Sabrina (1778)    — transferencia  2025-08-01  Matriz → Matriz (renovação Log)
-- 3. Ana Claudia (1752)— transferencia  2025-07-01  Matriz → Matriz (renovação Sarandi)
-- 4. Maria Luiza (1629)— transferencia  2023-11-01  Matriz → Matriz
-- 5. Maria Luiza (1629)— promocao       2023-11-01  Atendente → Assistente de E-commerce
-- 6. Francisco (1688)  — transferencia  2025-08-01  Matriz → Matriz (renovação CD)
-- 7. Francisco (1688)  — promocao       2025-08-01  Ajudante de Expedição → Operador de Logística
--
-- Campos tipo_transferencia_label: snapshot do label em param_tipo_transferencia na época.
-- Campos salario_anterior/salario_novo em promocao: não preenchidos (dados não disponíveis).

-- Atualizar dados_schema do tipo 'transferencia' para documentar tipo_transferencia_label
UPDATE tipos_evento
SET dados_schema = '[
  {"tipo":"text",   "campo":"empresa_origem",           "label":"Empresa de origem",  "obrigatorio":true},
  {"tipo":"text",   "campo":"empresa_destino",          "label":"Empresa de destino", "obrigatorio":true},
  {"tipo":"text",   "campo":"tipo_transferencia",       "label":"Tipo (código)",      "obrigatorio":false},
  {"tipo":"text",   "campo":"tipo_transferencia_label", "label":"Tipo (label)",        "obrigatorio":false}
]'::JSONB
WHERE codigo = 'transferencia';
