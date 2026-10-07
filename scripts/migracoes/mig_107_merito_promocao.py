"""
MIG 107 — Mérito e Promoção / Agosto 2026
Resultado: 15 historico_remuneracao (ids 422–436) + 6 historico_eventos (ids 105–110) + 9 PATCHs

REGRAS (consultar aqui antes de alterar)
─────────────────────────────────────────
R1  Percentual: inteiro — 6.0 = 6% (ficha-render.js usa toFixed(2) sem ×100)
R2  Motivos carregados de param_motivo_reajuste — sem hardcode de labels
R3  'dissidio_coletivo' é código texto da Mig 106; mapeado via label do 0.3
R4  historico_eventos.origem: só aceita 'sistema' (constraint do banco)
R5  Idempotência: PATCH em colaboradores só executa se houve INSERT novo nesta execução
    → reexecução completa não sobrescreve alteração posterior de outro processo
R6  Mudança de setor causada por promoção → incluir setor_ant/nov no dados do evento
    promocao (não criar alteracao_setor separado; alteracao_setor = sem promoção de cargo)

DECISÕES INDIVIDUAIS
─────────────────────
· Heloisa (1619): planilha diz "Promoção" mas obs = "Mesma função" → tratada como Mérito
  Se cargo mudar futuramente, alterar para motivo 0.2 e adicionar evento ev_prom
· Maria Clara (1727): atualizar_cargo=False — cargo já correto no banco desde 16/09/2026
  Mudança de setor (CD→Compras) registrada nos dados do evento de promoção
· Marcos (1683): sem dissídio na planilha — promoção pura
· Daniele (1611) e Heloisa (1619): dissídio já existe (Mig 106, ids 331/337)
  — guard de idempotência pula; somente o mérito é inserido

PENDÊNCIAS ABERTAS
───────────────────
· Parâmetros Gerais: corrigir label 'dissidio_coletivo' de "Reajuste integral" → "Dissídio coletivo"
· Mig E-bis: Felipe Gonçalves (CD/485, id=1711) — sal.banco R$1.024,69 ≠ planilha R$2.163,00
"""

import sys, json, urllib.request
sys.stdout.reconfigure(encoding='utf-8')

SB_URL     = 'https://rujtbxwssiofiialnbbg.supabase.co'
import os
SB_KEY     = os.environ.get('SUPABASE_SECRET_KEY', '')  # nunca usar no browser; definir antes de executar
DATA_VIG   = '2026-08-01'
REG_POR    = 'RH'
REG_POR_EV = 'Migração Mérito&Promoção ago/2026'
ORIGEM_EV  = 'sistema'  # R4: único valor aceito pela constraint


# ── helpers HTTP ─────────────────────────────────────────────────────────────

def get(path):
    req = urllib.request.Request(f'{SB_URL}/rest/v1/{path}')
    req.add_header('apikey', SB_KEY); req.add_header('Authorization', f'Bearer {SB_KEY}')
    with urllib.request.urlopen(req) as r: return json.loads(r.read())

def post(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f'{SB_URL}/rest/v1/{path}', data=data, method='POST')
    req.add_header('apikey', SB_KEY); req.add_header('Authorization', f'Bearer {SB_KEY}')
    req.add_header('Content-Type', 'application/json'); req.add_header('Prefer', 'return=representation')
    with urllib.request.urlopen(req) as r: return json.loads(r.read())

def patch(path, body):
    data = json.dumps(body).encode()
    req = urllib.request.Request(f'{SB_URL}/rest/v1/{path}', data=data, method='PATCH')
    req.add_header('apikey', SB_KEY); req.add_header('Authorization', f'Bearer {SB_KEY}')
    req.add_header('Content-Type', 'application/json'); req.add_header('Prefer', 'return=representation')
    with urllib.request.urlopen(req) as r: return json.loads(r.read())


# ── Etapa 1 — motivos do banco (R2, R3) ──────────────────────────────────────

print('=' * 70 + '\nETAPA 1 — Carregar param_motivo_reajuste\n' + '=' * 70)

motivos_raw = get('param_motivo_reajuste?select=codigo,descricao,ativo&order=ordem.asc')
MOTIVOS = {m['codigo']: m['descricao'] for m in motivos_raw if m['ativo']}
print(f'  Motivos ativos: {MOTIVOS}')

for cod in ('0.1', '0.2', '0.3'):
    if cod not in MOTIVOS:
        print(f'  ERRO: código {cod!r} ausente em param_motivo_reajuste. Abortando.')
        sys.exit(1)

if 'dissidio_coletivo' not in MOTIVOS:                     # R3
    MOTIVOS['dissidio_coletivo'] = MOTIVOS['0.3']
    print(f'  dissidio_coletivo mapeado para label de 0.3: {MOTIVOS["0.3"]!r}')

print(f'  0.1={MOTIVOS["0.1"]!r}  0.2={MOTIVOS["0.2"]!r}  dissidio={MOTIVOS["dissidio_coletivo"]!r}')


# ── construtores ──────────────────────────────────────────────────────────────

def rem(cod, sal_ant, sal_nov, pct):
    return {'data_vigencia': DATA_VIG, 'motivo_codigo': cod,
            'motivo_descricao': MOTIVOS[cod],   # snapshot do label (R2)
            'salario_anterior': sal_ant, 'salario_novo': sal_nov,
            'percentual': pct,                  # inteiro: 6.0 = 6% (R1)
            'observacao': None, 'registrado_por': REG_POR}

def ev_prom(c_ant, c_nov, s_ant, s_nov, pct, set_ant=None, set_nov=None):
    dados = {'cargo_anterior': c_ant, 'cargo_novo': c_nov,
             'salario_anterior': s_ant, 'salario_novo': s_nov, 'percentual': pct,
             'motivo_codigo': '0.2', 'motivo_descricao': MOTIVOS['0.2']}
    if set_ant: dados['setor_anterior'] = set_ant   # R6: snapshot texto
    if set_nov: dados['setor_novo']     = set_nov
    resumo = (f'R$ {s_ant:,.2f} → R$ {s_nov:,.2f} (+{pct:.2f}%)'
              .replace(',', 'X').replace('.', ',').replace('X', '.'))
    return {'tipo': 'promocao', 'titulo': f'Promoção para {c_nov}', 'resumo': resumo,
            'dados': dados, 'data_evento': DATA_VIG,
            'registrado_por': REG_POR_EV, 'origem': ORIGEM_EV}  # R4


# ── Etapa 2 — plano (9 colaboradores) ────────────────────────────────────────
#
# Campos por colaborador:
#   colab_id, nome, cargo_novo, sal_final, atualizar_cargo, registros, evento
#
# atualizar_cargo=False → PATCH só atualiza salario (não mexe no cargo)
# evento=None          → mérito puro, sem historico_eventos
# ─────────────────────────────────────────────────────────────────────────────

PLANO = [
    # 1 ── Wilson Vieira Silva · Metalshop · mat 212 · id=1687
    #       Dissídio + Promoção: Aux Sep Merc → Analista de Expedição
    {'colab_id': 1687, 'nome': 'WILSON VIEIRA SILVA',
     'cargo_novo': 'Analista de Expedição', 'sal_final': 3552.0072067, 'atualizar_cargo': True,
     'registros': [rem('dissidio_coletivo', 3147.91,    3336.7846,     6.00),
                   rem('0.2',              3336.7846,   3552.0072067,  6.45)],
     'evento': ev_prom('Auxiliar de Separação de Mercadorias', 'Analista de Expedição',
                       3336.7846, 3552.0072067, 6.45)},

    # 2 ── Marcos dos Santos Medeiros · Metalshop · mat 213 · id=1683
    #       Promoção pura (sem dissídio na planilha): Motorista A → Assistente de Frota
    {'colab_id': 1683, 'nome': 'MARCOS DOS SANTOS MEDEIROS',
     'cargo_novo': 'Assistente de Frota', 'sal_final': 3668.713, 'atualizar_cargo': True,
     'registros': [rem('0.2', 3461.05, 3668.713, 6.00)],
     'evento': ev_prom('Motorista A', 'Assistente de Frota', 3461.05, 3668.713, 6.00)},

    # 3 ── Felipe Ramires dos Santos · Log · mat 119 · id=1776
    #       Dissídio + Promoção: Assist Compras Jr → Pleno
    {'colab_id': 1776, 'nome': 'FELIPE RAMIRES DOS SANTOS',
     'cargo_novo': 'Assistente de Compras Pleno', 'sal_final': 3928.0692738, 'atualizar_cargo': True,
     'registros': [rem('dissidio_coletivo', 3505.89,   3716.2434,    6.00),
                   rem('0.2',              3716.2434,  3928.0692738, 5.70)],
     'evento': ev_prom('Assistente de Compras Jr.', 'Assistente de Compras Pleno',
                       3716.2434, 3928.0692738, 5.70)},

    # 4 ── Alessandra Aparecida Fogaca · Matriz · mat 606 · id=1606
    #       Dissídio piso (6.01% efetivo) + Mérito — cargo Caixa sem mudança
    {'colab_id': 1606, 'nome': 'ALESSANDRA APARECIDA FOGACA',
     'cargo_novo': None, 'sal_final': 2735.0904, 'atualizar_cargo': False,
     'registros': [rem('dissidio_coletivo', 2163.00, 2293.00,   6.01),
                   rem('0.1',              2293.00, 2735.0904, 19.28)],
     'evento': None},

    # 5 ── Gisele Dias do Nascimento · CD · mat 345 · id=1689
    #       Vínculo ativo desde 2022; ids 1871/1872 são inativos
    #       Dissídio + Promoção: Assist Compras Jr → Pleno
    {'colab_id': 1689, 'nome': 'GISELE DIAS DO NASCIMENTO',
     'cargo_novo': 'Assistente de Compras Pleno', 'sal_final': 3928.0692738, 'atualizar_cargo': True,
     'registros': [rem('dissidio_coletivo', 3505.89,   3716.2434,    6.00),
                   rem('0.2',              3716.2434,  3928.0692738, 5.70)],
     'evento': ev_prom('Assistente de Compras Jr.', 'Assistente de Compras Pleno',
                       3716.2434, 3928.0692738, 5.70)},

    # 6 ── Maria Clara Avelino da Silva de Paula · CD→Compras · mat 416 · id=1727
    #       Dissídio + Promoção + mudança de setor
    #       atualizar_cargo=False: cargo já correto no banco desde 16/09/2026
    #       setor_ant/nov nos dados do evento (R6): mudança de setor = parte da promoção
    {'colab_id': 1727, 'nome': 'MARIA CLARA AVELINO DA SILVA DE PAULA',
     'cargo_novo': 'Assistente de Compras Pleno', 'sal_final': 3928.0692738, 'atualizar_cargo': False,
     'registros': [rem('dissidio_coletivo', 3505.89,   3716.2434,    6.00),
                   rem('0.2',              3716.2434,  3928.0692738, 5.70)],
     'evento': ev_prom('Assistente Administrativo', 'Assistente de Compras Pleno',
                       3716.2434, 3928.0692738, 5.70,
                       set_ant='2148 - CD', set_nov='148 - Compras')},

    # 7 ── Edileusa Maia dos Santos · Atelier · mat 219 · id=1768
    #       Dissídio piso + Promoção: Vendedor(a) Jr → Pleno
    {'colab_id': 1768, 'nome': 'EDILEUSA MAIA DOS SANTOS',
     'cargo_novo': 'Vendedor(a) Pleno', 'sal_final': 2652.00, 'atualizar_cargo': True,
     'registros': [rem('dissidio_coletivo', 2266.00, 2402.00, 6.00),
                   rem('0.2',              2402.00, 2652.00, 10.41)],
     'evento': ev_prom('Vendedor(a) Júnior', 'Vendedor(a) Pleno', 2402.00, 2652.00, 10.41)},

    # 8 ── Daniele Martins Dalosse da Silva · Matriz · mat 410 · id=1611
    #       Dissídio já existe (Mig 106, id=331) — só o mérito é inserido
    {'colab_id': 1611, 'nome': 'DANIELE MARTINS DALOSSE DA SILVA',
     'cargo_novo': None, 'sal_final': 6551.136, 'atualizar_cargo': False,
     'registros': [rem('0.1', 5955.58, 6551.136, 10.00)],
     'evento': None},

    # 9 ── Heloisa Ferreira Lima Maeda · Matriz · mat 346 · id=1619
    #       Dissídio já existe (Mig 106, id=337) — só o mérito é inserido
    #       Planilha rotula "Promoção" mas obs="Mesma função" → motivo 0.1 (ver decisões no topo)
    {'colab_id': 1619, 'nome': 'HELOISA FERREIRA LIMA MAEDA',
     'cargo_novo': None, 'sal_final': 6551.136, 'atualizar_cargo': False,
     'registros': [rem('0.1', 5955.58, 6551.136, 10.00)],
     'evento': None},
]

print()
print('=' * 70 + '\nETAPA 2 — Plano carregado\n' + '=' * 70)
print(f'  Colaboradores: {len(PLANO)} | '
      f'historico_remuneracao: {sum(len(p["registros"]) for p in PLANO)} | '
      f'historico_eventos: {sum(1 for p in PLANO if p["evento"])}')


# ── Etapa 3 — estado pré-existente (base do guard de idempotência) ───────────

print()
print('=' * 70 + '\nETAPA 3 — Verificar estado pré-existente (idempotência)\n' + '=' * 70)

hist_exist, ev_exist = [], []
for p in PLANO:
    cid = p['colab_id']
    hist_exist += get(f'historico_remuneracao?colaborador_id=eq.{cid}&data_vigencia=eq.{DATA_VIG}&select=id,colaborador_id,motivo_codigo')
    ev_exist   += get(f'historico_eventos?colaborador_id=eq.{cid}&tipo=eq.promocao&data_evento=eq.{DATA_VIG}&select=id,colaborador_id,tipo,data_evento')

set_hist = {(h['colaborador_id'], h['motivo_codigo']) for h in hist_exist}
set_ev   = {(e['colaborador_id'], e['tipo'], e['data_evento']) for e in ev_exist}

print(f'  historico_remuneracao existente em {DATA_VIG}: {len(hist_exist)} registros')
for h in hist_exist:
    print(f'    id={h["id"]} | colab={h["colaborador_id"]} | motivo={h["motivo_codigo"]!r} → será IGNORADO (já existe)')
print(f'  historico_eventos tipo=promocao em {DATA_VIG}: {len(ev_exist)} registros')
for e in ev_exist:
    print(f'    id={e["id"]} | colab={e["colaborador_id"]} → será IGNORADO (já existe)')


# ── Etapa 4 — execução ───────────────────────────────────────────────────────

print()
print('=' * 70 + '\nETAPA 4 — Execução\n' + '=' * 70)

rem_inseridos = rem_pulados = ev_inseridos = ev_pulados = atualizados = 0
erros = []

for p in PLANO:
    cid = p['colab_id']
    print(f'\n  ── {p["nome"]} (id={cid})')

    rem_novos = 0
    for rec in p['registros']:
        chave = (cid, rec['motivo_codigo'])
        if chave in set_hist:
            print(f'    [SKIP] historico_rem motivo={rec["motivo_codigo"]!r} já existe')
            rem_pulados += 1
        else:
            try:
                r = post('historico_remuneracao', {'colaborador_id': cid, **rec})
                set_hist.add(chave)
                print(f'    [OK]   historico_rem id={r[0]["id"]} | motivo={rec["motivo_codigo"]!r} | {rec["salario_anterior"]} → {rec["salario_novo"]} ({rec["percentual"]}%)')
                rem_inseridos += 1; rem_novos += 1
            except Exception as ex:
                erros.append(f'rem colab={cid} motivo={rec["motivo_codigo"]}: {ex}')
                print(f'    [ERRO] {ex}')

    if p['evento']:
        ev = p['evento']
        chave_ev = (cid, ev['tipo'], ev['data_evento'])
        if chave_ev in set_ev:
            print(f'    [SKIP] historico_ev tipo={ev["tipo"]!r} em {ev["data_evento"]} já existe')
            ev_pulados += 1
        else:
            try:
                r = post('historico_eventos', {'colaborador_id': cid, **ev})
                set_ev.add(chave_ev)
                print(f'    [OK]   historico_ev id={r[0]["id"]} | {ev["titulo"]!r}')
                ev_inseridos += 1
            except Exception as ex:
                erros.append(f'ev colab={cid} tipo=promocao: {ex}')
                print(f'    [ERRO] {ex}')

    # R5: PATCH só se houve INSERT novo nesta execução
    if rem_novos == 0:
        print(f'    [SKIP] colaboradores PATCH: nenhum histórico novo inserido nesta execução')
    else:
        try:
            body = {'salario': round(p['sal_final'], 2)}
            if p['atualizar_cargo'] and p['cargo_novo']:
                body['cargo'] = p['cargo_novo']
            patch(f'colaboradores?id=eq.{cid}', body)
            print(f'    [OK]   colaboradores PATCH: {", ".join(f"{k}={v!r}" for k,v in body.items())}')
            atualizados += 1
        except Exception as ex:
            erros.append(f'patch colab={cid}: {ex}')
            print(f'    [ERRO] patch colaboradores: {ex}')


# ── Etapa 5 — validação pós-execução ─────────────────────────────────────────

print()
print('=' * 70 + '\nETAPA 5 — Validação pós-execução\n' + '=' * 70)

rem_banco = ev_banco = colabs_fin = []
rem_banco, ev_banco, colabs_fin = [], [], []
for p in PLANO:
    cid = p['colab_id']
    rem_banco  += get(f'historico_remuneracao?colaborador_id=eq.{cid}&data_vigencia=eq.{DATA_VIG}&select=id,colaborador_id,motivo_codigo,salario_anterior,salario_novo,percentual&order=id.asc')
    ev_banco   += get(f'historico_eventos?colaborador_id=eq.{cid}&tipo=eq.promocao&data_evento=eq.{DATA_VIG}&select=id,colaborador_id,titulo&order=id.asc')
    colabs_fin += get(f'colaboradores?id=eq.{cid}&select=id,nome,cargo,salario')

rem_banco.sort(key=lambda x: x['id'])

print(f'  historico_remuneracao em {DATA_VIG}: {len(rem_banco)} registros')
for h in rem_banco:
    print(f'    id={h["id"]} | colab={h["colaborador_id"]} | {h["motivo_codigo"]} | {h["salario_anterior"]} → {h["salario_novo"]} ({h["percentual"]}%)')

print(f'  historico_eventos promoção em {DATA_VIG}: {len(ev_banco)} eventos')
for e in sorted(ev_banco, key=lambda x: x['id']):
    print(f'    id={e["id"]} | colab={e["colaborador_id"]} | {e["titulo"]!r}')

print()
print('  Salários finais no banco:')
for c in sorted(colabs_fin, key=lambda x: x['id']):
    esp = next((p['sal_final'] for p in PLANO if p['colab_id'] == c['id']), None)
    ok = '✓' if esp and abs(c['salario'] - esp) < 0.02 else f'✗ esperado={esp}'
    print(f'    id={c["id"]} | {c["nome"]!r} | cargo={c["cargo"]!r} | salario={c["salario"]} | {ok}')

print()
print('=' * 70)
print('MIG 107 CONCLUÍDA')
print(f'  historico_remuneracao inseridos:  {rem_inseridos}  |  pulados (já existiam): {rem_pulados}')
print(f'  historico_eventos inseridos:      {ev_inseridos}   |  pulados (já existiam): {ev_pulados}')
print(f'  colaboradores atualizados:        {atualizados}')
print(f'  erros:                            {len(erros)}')
if erros:
    for e in erros: print(f'    {e}')
print('=' * 70)
