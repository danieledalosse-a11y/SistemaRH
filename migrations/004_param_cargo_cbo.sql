-- ============================================================
-- MIGRAÇÃO 004: param_cbo + param_cargo + normalização de cargos
-- Rodar no Supabase Dashboard → SQL Editor
-- Fonte CBO: Classificação Brasileira de Ocupações (MTE)
-- Nota: códigos CBO são sugestões — verifique em mtecbo.gov.br
-- ============================================================

-- ── 1. TABELA param_cbo (referência CBO/MTE) ─────────────────
CREATE TABLE IF NOT EXISTS param_cbo (
  id           BIGSERIAL PRIMARY KEY,
  codigo       TEXT NOT NULL UNIQUE,
  titulo       TEXT NOT NULL,
  grupo        TEXT,
  ativo        BOOLEAN DEFAULT TRUE,
  criado_por   TEXT,
  alterado_por TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── 2. POPULAR param_cbo ─────────────────────────────────────
INSERT INTO param_cbo (codigo, titulo, grupo) VALUES
('3541-05', 'Vendedor de comércio varejista',             'Vendas e Atendimento'),
('3541-10', 'Promotor de vendas',                         'Vendas e Atendimento'),
('3541-20', 'Vendedor de serviços',                       'Vendas e Atendimento'),
('4214-25', 'Atendente de lojas e mercados',              'Vendas e Atendimento'),
('1317-15', 'Gerente de vendas no varejo',                'Vendas e Atendimento'),
('1421-05', 'Gerente comercial',                          'Vendas e Atendimento'),
('1421-15', 'Gerente de compras',                         'Compras'),
('4110-10', 'Auxiliar administrativo',                    'Administrativo'),
('4231-10', 'Auxiliar de escritório',                     'Administrativo'),
('1231-05', 'Gerente administrativo',                     'Administrativo'),
('4101-05', 'Supervisor administrativo',                  'Administrativo'),
('2521-05', 'Analista de recursos humanos e de pessoal',  'Recursos Humanos'),
('2521-10', 'Analista de treinamento e desenvolvimento',  'Recursos Humanos'),
('3513-05', 'Assistente financeiro',                      'Financeiro'),
('4213-05', 'Auxiliar de cobrança',                       'Financeiro'),
('5211-25', 'Operador de caixa',                          'Financeiro'),
('1231-20', 'Gerente financeiro',                         'Financeiro'),
('2312-05', 'Analista de publicidade e marketing',        'Marketing e Design'),
('1227-15', 'Gerente de marketing',                       'Marketing e Design'),
('2393-25', 'Designer gráfico',                           'Marketing e Design'),
('2393-05', 'Designer de produto',                        'Marketing e Design'),
('2124-05', 'Analista de sistemas (desenvolvimento)',      'Tecnologia da Informação'),
('3172-15', 'Técnico de suporte em TI',                   'Tecnologia da Informação'),
('1236-05', 'Gerente de tecnologia da informação',        'Tecnologia da Informação'),
('3511-05', 'Analista de compras',                        'Compras'),
('4141-05', 'Almoxarife',                                 'Logística e Expedição'),
('4141-10', 'Auxiliar de logística',                      'Logística e Expedição'),
('4141-20', 'Auxiliar de expedição',                      'Logística e Expedição'),
('4141-25', 'Conferente-expedidor',                       'Logística e Expedição'),
('4142-05', 'Operador de empilhadeira',                   'Logística e Expedição'),
('1228-10', 'Gerente de logística e distribuição',        'Logística e Expedição'),
('7825-05', 'Motorista de veículo leve (CNH B)',           'Transporte'),
('7825-10', 'Motorista de veículo pesado (CNH C)',         'Transporte'),
('7825-15', 'Motorista de carga a granel (CNH C/E)',       'Transporte'),
('7825-20', 'Motorista de ônibus (CNH D)',                 'Transporte'),
('7826-05', 'Motociclista de entregas (CNH A)',            'Transporte'),
('7824-25', 'Ajudante de motorista',                      'Transporte'),
('9101-05', 'Auxiliar de manutenção geral',               'Manutenção'),
('3942-05', 'Projetista de produtos e serviços',          'Projetos'),
('5142-35', 'Zelador de edifícios',                       'Outros'),
('9919-15', 'Auxiliar geral de serviços',                 'Outros'),
('1312-05', 'Diretor administrativo',                     'Outros')
ON CONFLICT (codigo) DO NOTHING;

-- ── 3. TABELA param_cargo ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS param_cargo (
  id           BIGSERIAL PRIMARY KEY,
  nome         TEXT NOT NULL,
  cbo_id       BIGINT REFERENCES param_cbo(id),
  cbo_codigo   TEXT,
  ativo        BOOLEAN DEFAULT TRUE,
  ordem        INTEGER,
  criado_por   TEXT,
  alterado_por TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW(),
  updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── 4. POPULAR param_cargo (72 cargos normalizados) ──────────
INSERT INTO param_cargo (nome, cbo_codigo, ordem) VALUES
('Vendedor(a)',                              '3541-05',  10),
('Vendedor(a) Júnior',                      '3541-05',  11),
('Vendedor(a) Pleno(a)',                    '3541-05',  12),
('Vendedor(a) Sênior',                      '3541-05',  13),
('Promotor(a) de Vendas',                   '3541-10',  14),
('Atendente',                               '4214-25',  15),
('Atendente de Balcão',                     '4214-25',  16),
('Gerente de Vendas',                       '1317-15',  17),
('Gerente Comercial',                       '1421-05',  18),
('Gerente de Produtos',                     '1421-05',  19),
('Gerente de E-commerce',                   '1421-05',  20),
('Assistente de E-commerce',                '4214-25',  21),
('Auxiliar de E-commerce',                  '4214-25',  22),
('Ajudante de E-commerce',                  '4214-25',  23),
('Assistente Administrativo',               '4110-10',  30),
('Auxiliar Administrativo',                 '4110-10',  31),
('Auxiliar de Escritório',                  '4231-10',  32),
('Supervisor(a) Administrativo(a)',         '4101-05',  33),
('Gerente Administrativo(a)',               '1231-05',  34),
('Analista de RH',                          '2521-05',  40),
('Auxiliar de RH',                          '4110-10',  41),
('Assistente Financeiro(a)',                '3513-05',  50),
('Auxiliar Financeiro(a)',                  '3513-05',  51),
('Auxiliar de Crédito e Cobrança',          '4213-05',  52),
('Caixa',                                   '5211-25',  53),
('Assistente de Marketing',                 '2312-05',  60),
('Auxiliar de Marketing',                   '2312-05',  61),
('Analista de Marketing',                   '2312-05',  62),
('Coordenador(a) de Marketing',             '1227-15',  63),
('Gerente de Marketing',                    '1227-15',  64),
('Designer Gráfico Jr.',                    '2393-25',  65),
('Designer de Interiores',                  '2393-05',  66),
('Assistente de TI',                        '3172-15',  70),
('Auxiliar de TI',                          '3172-15',  71),
('Desenvolvedor Jr.',                       '2124-05',  72),
('Programador Jr.',                         '2124-05',  73),
('Gerente de TI',                           '1236-05',  74),
('Assistente de Compras',                   '3511-05',  80),
('Assistente de Compras Jr.',               '3511-05',  81),
('Auxiliar de Compras',                     '3511-05',  82),
('Auxiliar de Compras Pleno(a)',            '3511-05',  83),
('Analista de Compras',                     '3511-05',  84),
('Gerente de Compras',                      '1421-15',  85),
('Ajudante de Expedição',                   '4141-20',  90),
('Analista de Expedição',                   '4141-25',  91),
('Gerente de Expedição',                    '1228-10',  92),
('Supervisor de Logística',                 '1228-10',  93),
('Supervisor de Conferência de Mercadorias','4141-25',  94),
('Supervisor de Separação de Mercadorias',  '4141-25',  95),
('Auxiliar de Logística',                   '4141-10',  96),
('Assistente de Logística',                 '4141-10',  97),
('Auxiliar de Separação de Mercadorias',    '4141-20',  98),
('Conferente de Mercadorias',               '4141-25',  99),
('Operador de Logística',                   '4141-10', 100),
('Operador de Empilhadeira',                '4142-05', 101),
('Motorista',                               '7825-10', 110),
('Motorista A',                             '7826-05', 111),
('Motorista B',                             '7825-05', 112),
('Motorista C',                             '7825-10', 113),
('Motorista D',                             '7825-20', 114),
('Ajudante de Entrega',                     '7824-25', 115),
('Supervisor de Frota',                     '1228-10', 116),
('Auxiliar de Manutenção',                  '9101-05', 120),
('Assistente de Manutenção',                '9101-05', 121),
('Projetista',                              '3942-05', 130),
('Auxiliar de Projetista',                  '3942-05', 131),
('Aprendiz - Assistente Administrativo',    '4110-10', 140),
('Aprendiz - Auxiliar Comercial',           '4214-25', 141),
('Aprendiz - Serviço de Vendas',            '3541-05', 142),
('Jovem Aprendiz',                          '4110-10', 143),
('Ajudante Geral',                          '9919-15', 150),
('Zelador(a)',                              '5142-35', 151),
('Sócio-Gerente',                           '1312-05', 152)
ON CONFLICT DO NOTHING;

-- ── 5. Vincular cbo_id a partir do cbo_codigo ─────────────────
UPDATE param_cargo pc
SET cbo_id = (SELECT id FROM param_cbo cb WHERE cb.codigo = pc.cbo_codigo)
WHERE cbo_codigo IS NOT NULL;

-- ── 6. NORMALIZAR colaboradores.cargo ────────────────────────
UPDATE colaboradores SET cargo = CASE cargo
  WHEN 'ADMINSTRADORA DE RH'                THEN 'Analista de RH'
  WHEN 'ANALISTA DE R. H.'                  THEN 'Analista de RH'
  WHEN 'AUXILIAR DE RH'                     THEN 'Auxiliar de RH'
  WHEN 'AJUDANTE DE ENTREGA'                THEN 'Ajudante de Entrega'
  WHEN 'Ajudante de entrega'                THEN 'Ajudante de Entrega'
  WHEN 'AJUDANTE DE EXPEDICAO'              THEN 'Ajudante de Expedição'
  WHEN 'AJUDANTE DE EXPEDIÇÃO'              THEN 'Ajudante de Expedição'
  WHEN 'Ajudante de Expedição'              THEN 'Ajudante de Expedição'
  WHEN 'AJUDANTE GERAL'                     THEN 'Ajudante Geral'
  WHEN 'Ajudante de E-commerce'             THEN 'Ajudante de E-commerce'
  WHEN 'ANALISTA DE COMPRAS'                THEN 'Analista de Compras'
  WHEN 'ANALISTA DE EXPEDICAO'              THEN 'Analista de Expedição'
  WHEN 'ANALISTA DE MARKETING'              THEN 'Analista de Marketing'
  WHEN 'APRENDIZ ASSIST. ADMINISTRATIVO'    THEN 'Aprendiz - Assistente Administrativo'
  WHEN 'Aprendiz Assist. Administrativo'    THEN 'Aprendiz - Assistente Administrativo'
  WHEN 'Aprendiz Assist Administrativo'     THEN 'Aprendiz - Assistente Administrativo'
  WHEN 'Aprendiz Assistente Administrativo' THEN 'Aprendiz - Assistente Administrativo'
  WHEN 'APRENDIZ AUXILIAR COMERCIAL'        THEN 'Aprendiz - Auxiliar Comercial'
  WHEN 'APRENDIZ EM SERV. DE VENDAS'       THEN 'Aprendiz - Serviço de Vendas'
  WHEN 'Aprendiz Serv Vendas'               THEN 'Aprendiz - Serviço de Vendas'
  WHEN 'Jovem Aprendiz'                     THEN 'Jovem Aprendiz'
  WHEN 'ASSISTENTE ADMINISTRATIVO'          THEN 'Assistente Administrativo'
  WHEN 'AUXILIAR ADMINISTRATIVO'            THEN 'Auxiliar Administrativo'
  WHEN 'Aux. Administratrivo'               THEN 'Auxiliar Administrativo'
  WHEN 'ASSISTENTE DE COMPRAS JR'           THEN 'Assistente de Compras Jr.'
  WHEN 'ASSISTENTE DE COMPRAS'              THEN 'Assistente de Compras'
  WHEN 'AUXILIAR DE COMPRAS'                THEN 'Auxiliar de Compras'
  WHEN 'AUXILIAR DE COMPRAS PLENA'          THEN 'Auxiliar de Compras Pleno(a)'
  WHEN 'ASSISTENTE DE E-COMMERCE'           THEN 'Assistente de E-commerce'
  WHEN 'ASSISTENTE DE ECOMMERCE'            THEN 'Assistente de E-commerce'
  WHEN 'AUXILIAR DE E-COMMERCE'             THEN 'Auxiliar de E-commerce'
  WHEN 'ASSISTENTE DE LOGISTICA'            THEN 'Assistente de Logística'
  WHEN 'AUXILIAR DE LOGISTICA'              THEN 'Auxiliar de Logística'
  WHEN 'AUXILIAR DE 392 - LOGISTICA'        THEN 'Auxiliar de Logística'
  WHEN 'ASSISTENTE DE MARKETING'            THEN 'Assistente de Marketing'
  WHEN 'AUXILIAR DE MARKETING'              THEN 'Auxiliar de Marketing'
  WHEN 'ASSISTENTE DE TI'                   THEN 'Assistente de TI'
  WHEN 'AUXILIAR DE TI'                     THEN 'Auxiliar de TI'
  WHEN 'ASSISTENTE FINANCEIRO'              THEN 'Assistente Financeiro(a)'
  WHEN 'ASSISTENTE FINANCEIRO(A)'           THEN 'Assistente Financeiro(a)'
  WHEN 'AUXILIAR FINANCEIRO(A)'             THEN 'Auxiliar Financeiro(a)'
  WHEN 'ASSISTENTE DE MANUTENÇÃO'           THEN 'Assistente de Manutenção'
  WHEN 'Assistente de Manutenção'           THEN 'Assistente de Manutenção'
  WHEN 'AUXILIAR DE MANUTENCAO'             THEN 'Auxiliar de Manutenção'
  WHEN 'Auxiliar de manutenção'             THEN 'Auxiliar de Manutenção'
  WHEN 'ATENDENTE'                          THEN 'Atendente'
  WHEN 'ATENDENTE DE BALCAO'               THEN 'Atendente de Balcão'
  WHEN 'AUX SEPARACAO DE MERCADORIAS'       THEN 'Auxiliar de Separação de Mercadorias'
  WHEN 'Aux. Separação mercadoria'          THEN 'Auxiliar de Separação de Mercadorias'
  WHEN 'AUX. DE CREDITO E COBRANCA'        THEN 'Auxiliar de Crédito e Cobrança'
  WHEN 'AUXILIAR DE ESCRITÓRIO'             THEN 'Auxiliar de Escritório'
  WHEN 'AUXILIAR DE PROJETISTA'             THEN 'Auxiliar de Projetista'
  WHEN 'CAIXA'                              THEN 'Caixa'
  WHEN 'Caixa'                              THEN 'Caixa'
  WHEN 'CONFERENTE DE MERCADORIAS'          THEN 'Conferente de Mercadorias'
  WHEN 'COORDENADOR(A) DE MKT'             THEN 'Coordenador(a) de Marketing'
  WHEN 'DESENVOLVEDOR JR'                   THEN 'Desenvolvedor Jr.'
  WHEN 'PROGRAMADOR JUNIOR'                 THEN 'Programador Jr.'
  WHEN 'DESIGNER DE INTERIORES'             THEN 'Designer de Interiores'
  WHEN 'Designer Gráfico Jr.'               THEN 'Designer Gráfico Jr.'
  WHEN 'GERENTE ADMINISTRATIVO'             THEN 'Gerente Administrativo(a)'
  WHEN 'GERENTE COMERCIAL'                  THEN 'Gerente Comercial'
  WHEN 'GERENTE DE EXPEDICAO'               THEN 'Gerente de Expedição'
  WHEN 'GERENTE DE MARKETING'               THEN 'Gerente de Marketing'
  WHEN 'GERENTE DE T.I.'                    THEN 'Gerente de TI'
  WHEN 'GERENTE DE VENDAS'                  THEN 'Gerente de Vendas'
  WHEN 'Gerente de vendas'                  THEN 'Gerente de Vendas'
  WHEN 'GERENTE DE PRODUTOS'                THEN 'Gerente de Produtos'
  WHEN 'GERENTE E-COMMERCE'                 THEN 'Gerente de E-commerce'
  WHEN 'GERENTE DE E-COMMERCE'              THEN 'Gerente de E-commerce'
  WHEN 'Gerente de Compras'                 THEN 'Gerente de Compras'
  WHEN 'MOTORISTA'                          THEN 'Motorista'
  WHEN 'Motorista'                          THEN 'Motorista'
  WHEN 'MOTORISTA A'                        THEN 'Motorista A'
  WHEN 'MOTORISTA B'                        THEN 'Motorista B'
  WHEN 'Motorista B'                        THEN 'Motorista B'
  WHEN 'MOTORISTA C'                        THEN 'Motorista C'
  WHEN 'MOTORISTA D'                        THEN 'Motorista D'
  WHEN 'OPERADOR DE EMPILHADEIRA'           THEN 'Operador de Empilhadeira'
  WHEN 'Operador de Empilhadeira'           THEN 'Operador de Empilhadeira'
  WHEN 'OPERADOR DE LOGISTICA'              THEN 'Operador de Logística'
  WHEN 'PROJETISTA'                         THEN 'Projetista'
  WHEN 'Projetista'                         THEN 'Projetista'
  WHEN 'PROMOTOR(A) DE VENDAS'             THEN 'Promotor(a) de Vendas'
  WHEN 'SOCIO-GERENTE'                      THEN 'Sócio-Gerente'
  WHEN 'SUPERVISOR CONF DE MERCADORI'       THEN 'Supervisor de Conferência de Mercadorias'
  WHEN 'SUPERVISOR CONF DE MERCADORIAS'     THEN 'Supervisor de Conferência de Mercadorias'
  WHEN 'Sup Separação Mercadorias'          THEN 'Supervisor de Separação de Mercadorias'
  WHEN 'SUPERVISOR DE FROTA'                THEN 'Supervisor de Frota'
  WHEN 'SUPERVISOR DE LOGISTICA'            THEN 'Supervisor de Logística'
  WHEN 'SUPERVISOR(A) ADMINISTRATIVO'       THEN 'Supervisor(a) Administrativo(a)'
  WHEN 'VENDEDOR(A)'                        THEN 'Vendedor(a)'
  WHEN 'Vendedor(a)'                        THEN 'Vendedor(a)'
  WHEN 'VENDEDOR(A) JUNIOR'                 THEN 'Vendedor(a) Júnior'
  WHEN 'VENDEDOR(A) PLENO'                  THEN 'Vendedor(a) Pleno(a)'
  WHEN 'VENDEDOR(A) SENIOR'                 THEN 'Vendedor(a) Sênior'
  WHEN 'ZELADOR(A)'                         THEN 'Zelador(a)'
  WHEN 'Zeladora'                           THEN 'Zelador(a)'
  ELSE cargo
END
WHERE cargo IS NOT NULL;

-- ── 7. Verificação pós-migração (execute separadamente) ──────
-- SELECT cargo, COUNT(*) as qtd FROM colaboradores GROUP BY cargo ORDER BY cargo;
