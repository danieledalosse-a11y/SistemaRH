"""
Reimporta a aba 'Estoque' do Excel com estrutura corrigida:
  - nome     = produto real (Camisa Social, Blusa de Frio, etc.)
  - genero   = masculino / feminino / unissex (do cabeçalho do grupo)
  - variante = característica do modelo (Manga Curta, Com Forro, Sem Forro…)
  - logo     = logo bordada (Logo Grupo Revest, Logo Revest Acabamentos, Jovem Aprendiz…)

Executa APÓS rodar a migration 028_uniformes_variante_logo.sql.

Uso:
  python reimportar_estoque_uniformes.py
"""

import openpyxl, requests, shutil, tempfile, os
from datetime import date

XLSX_PATH = r"C:\Users\reves\REVEST DO BRASIL ACABAMENTOS LTDA\RH - Documentos\15 - UNIFORMES (EVELYN)\PLANILHA CONTROLE ESTOQUE.xlsx"
SB_URL    = "https://rujtbxwssiofiialnbbg.supabase.co"
SB_SECRET = input("Cole a Service Role Key do Supabase: ").strip()

HEADERS = {
    "apikey":        SB_SECRET,
    "Authorization": f"Bearer {SB_SECRET}",
    "Content-Type":  "application/json",
    "Prefer":        "return=representation",
}

def sb_get(t, p=""):
    r = requests.get(f"{SB_URL}/rest/v1/{t}?{p}", headers=HEADERS); r.raise_for_status(); return r.json()

def sb_post(t, d):
    r = requests.post(f"{SB_URL}/rest/v1/{t}", headers=HEADERS, json=d); r.raise_for_status(); return r.json()

def sb_patch(t, f, d):
    r = requests.patch(f"{SB_URL}/rest/v1/{t}?{f}", headers={**HEADERS,"Prefer":"return=minimal"}, json=d); r.raise_for_status()

# ─── Mapeamentos ──────────────────────────────────────────────────────────────

LOGOS = {'logo grupo revest', 'logo revest acabamentos', 'logo grupo revest '}

VARIANTES_VALIDAS = {'manga curta','manga longa','com forro','sem forro','social','casual'}

GENERO_PALAVRAS = {
    'masculinas': 'masculino', 'masculino': 'masculino',
    'femininas':  'feminino',  'feminino':  'feminino',
    'unissex':    'unissex',
}

# grupo da planilha → (nome_real_do_item, genero_base)
# quando o item na coluna A for uma logo, o nome real vem daqui
GRUPO_PARA_ITEM = {
    'camisas manga longa (gestores)': 'Camisa Manga Longa',
    'batas':                          'Bata',
    'camisetas zeladoras':            'Camiseta',
    'camisetas jovens':               'Camiseta',
}

def detectar_genero(titulo):
    t = (titulo or '').upper()
    if 'FEMININA' in t or 'FEMININO' in t or 'VENDEDORA' in t or 'COLETES' in t: return 'feminino'
    if 'MASCULINA' in t or 'MASCULINO' in t or 'VENDEDOR' in t: return 'masculino'
    return 'unissex'

def normalizar_tamanho(t):
    if t is None: return None
    s = str(t).strip().upper()
    # remove espaços internos e corrige variantes conhecidas
    s = s.replace(' ', '')
    mapa = {'G1(EGG)': 'G1', 'XGG': 'EGG'}
    return mapa.get(s, s)

def ler_excel():
    tmp = os.path.join(tempfile.gettempdir(), 'estoque_reimp.xlsx')
    shutil.copy2(XLSX_PATH, tmp)
    wb  = openpyxl.load_workbook(tmp, data_only=True)
    ws  = wb['Estoque']

    linhas       = []
    genero_atual = 'unissex'
    grupo_atual  = ''

    for row in ws.iter_rows(values_only=True):
        desc, cat, tam, forn, qtd, custo, *_ = (list(row) + [None]*10)[:10]

        desc_s = str(desc).strip() if desc else ''
        cat_s  = str(cat).strip()  if cat  else ''
        tam_s  = str(tam).strip()  if tam  else ''
        forn_s = str(forn).strip().upper() if forn else ''

        # linha de cabeçalho de grupo
        if desc_s and not tam and not forn and not qtd:
            genero_atual = detectar_genero(desc_s)
            grupo_atual  = desc_s.lower().strip()
            continue

        # linha de cabeçalho de coluna
        if desc_s == 'Descrição do Uniforme': continue

        # linha de total ou vazia
        if not desc_s or not tam_s or not forn_s: continue

        try:
            qtd_int   = int(float(str(qtd)))   if qtd   else 0
            custo_val = float(str(custo)) if custo else 0.0
        except (ValueError, TypeError):
            continue

        if qtd_int <= 0: continue

        # ── Determina nome real, variante, logo e gênero ──────────────────────
        desc_low = desc_s.lower().strip()
        cat_low  = cat_s.lower().strip()

        nome_real = desc_s
        variante  = None
        logo      = None
        genero    = genero_atual

        # Se o item na coluna A É uma logo → o produto vem do grupo
        if desc_low in LOGOS or desc_low.rstrip() in LOGOS:
            nome_real = GRUPO_PARA_ITEM.get(grupo_atual, desc_s)
            logo      = desc_s.strip().rstrip()
            # gênero pode estar na categoria (Masculinas / Femininas)
            if cat_low in GENERO_PALAVRAS:
                genero = GENERO_PALAVRAS[cat_low]
            # variante fica None (não há info adicional)

        else:
            # A categoria pode ser: logo, variante ou gênero
            if cat_low in LOGOS or cat_low.rstrip() in LOGOS:
                logo = cat_s.strip().rstrip()
            elif cat_low in GENERO_PALAVRAS:
                genero = GENERO_PALAVRAS[cat_low]
            elif cat_s and cat_low not in ('', 'none'):
                variante = cat_s.strip()

        tamanho = normalizar_tamanho(tam)
        if not tamanho: continue

        linhas.append({
            'nome':     nome_real,
            'genero':   genero,
            'variante': variante,
            'logo':     logo,
            'tamanho':  tamanho,
            'fornecedor': forn_s,
            'quantidade': qtd_int,
            'valor_unitario': round(custo_val, 2),
        })

    return linhas

# ─── Cache catálogo ───────────────────────────────────────────────────────────
_cat_cache = {}

def obter_ou_criar_item(nome, genero, variante, logo):
    chave = (nome.lower(), genero, (variante or '').lower(), (logo or '').lower())
    if chave in _cat_cache: return _cat_cache[chave]

    enc = requests.utils.quote
    params = f"nome=ilike.{enc(nome)}&genero=eq.{genero}&select=id"
    if variante: params += f"&variante=eq.{enc(variante)}"
    else:        params += "&variante=is.null"
    if logo:     params += f"&logo=eq.{enc(logo)}"
    else:        params += "&logo=is.null"

    rows = sb_get('unif_catalogo', params)
    if rows:
        _cat_cache[chave] = rows[0]['id']
        return rows[0]['id']

    novo = sb_post('unif_catalogo', {
        'nome': nome, 'tipo': 'uniforme', 'genero': genero,
        'variante': variante, 'logo': logo,
        'sistema_tamanho': 'letra', 'prazo_troca_meses': 24, 'ativo': True,
    })
    iid = novo[0]['id']
    _cat_cache[chave] = iid
    label = f"{nome} ({genero})" + (f" · {variante}" if variante else "") + (f" · {logo}" if logo else "")
    print(f"  [NOVO ITEM] {label}")
    return iid

def atualizar_estoque(almox_id, item_id, tamanho, qtd, custo):
    enc = requests.utils.quote
    rows = sb_get('unif_estoque',
        f"almoxarifado_id=eq.{almox_id}&item_id=eq.{item_id}&tamanho=eq.{enc(tamanho)}&select=id,quantidade,custo_medio")
    if rows:
        r = rows[0]
        qtd_a = r['quantidade'] or 0
        cus_a = float(r['custo_medio'] or 0)
        nova_qtd = qtd_a + qtd
        novo_custo = round((cus_a * qtd_a + custo * qtd) / nova_qtd, 2) if nova_qtd else custo
        sb_patch('unif_estoque', f"id=eq.{r['id']}", {'quantidade': nova_qtd, 'custo_medio': novo_custo})
    else:
        sb_post('unif_estoque', {
            'almoxarifado_id': almox_id, 'item_id': item_id,
            'tamanho': tamanho, 'quantidade': qtd, 'custo_medio': custo,
        })

def main():
    print("=== Reimportação de Estoque de Uniformes ===\n")
    linhas = ler_excel()
    print(f"Linhas lidas: {len(linhas)}")

    almoxs = sb_get('unif_almoxarifados', 'ativo=eq.true&select=id,nome')
    print("\nAlmoxarifados:")
    for i, a in enumerate(almoxs): print(f"  {i+1}. {a['nome']}")
    idx      = int(input("Almoxarifado (número): ").strip()) - 1
    almox_id = almoxs[idx]['id']
    hoje     = date.today().isoformat()

    erros = []
    for i, l in enumerate(linhas):
        try:
            item_id = obter_ou_criar_item(l['nome'], l['genero'], l['variante'], l['logo'])
            sb_post('unif_entradas', {
                'item_id': item_id, 'almoxarifado_id': almox_id,
                'fornecedor': l['fornecedor'], 'tamanho': l['tamanho'],
                'quantidade': l['quantidade'], 'valor_unitario': l['valor_unitario'],
                'logo_bordada': bool(l['logo']),
                'data_entrada': hoje, 'obs': 'Reimportado do Excel',
                'status': 'ativo', 'registrado_por': 'Importação',
            })
            atualizar_estoque(almox_id, item_id, l['tamanho'], l['quantidade'], l['valor_unitario'])
            logo_info = f" [{l['logo']}]" if l['logo'] else ''
            var_info  = f" · {l['variante']}" if l['variante'] else ''
            print(f"  [{i+1:03d}] OK — {l['nome']} ({l['genero']}){var_info}{logo_info} {l['tamanho']} x{l['quantidade']}")
        except Exception as e:
            msg = f"  [{i+1:03d}] ERRO — {l}: {e}"
            print(msg); erros.append(msg)

    print(f"\n=== Concluído: {len(linhas)-len(erros)} importados, {len(erros)} erros ===")
    if erros:
        for e in erros: print(e)

if __name__ == "__main__":
    main()
