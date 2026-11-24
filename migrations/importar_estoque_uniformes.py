"""
Importa a aba 'Estoque' do Excel para o Supabase.
Executa APÓS rodar a migration 027_uniformes_entradas.sql.

Uso:
  python importar_estoque_uniformes.py
"""

import openpyxl
import requests
import json
import sys
from datetime import date

# ─── Configuração ─────────────────────────────────────────────────────────────
XLSX_PATH  = r"C:\Users\reves\REVEST DO BRASIL ACABAMENTOS LTDA\RH - Documentos\15 - UNIFORMES (EVELYN)\PLANILHA CONTROLE ESTOQUE.xlsx"
SB_URL     = "https://rujtbxwssiofiialnbbg.supabase.co"
SB_SECRET  = input("Cole a Service Role Key do Supabase: ").strip()

HEADERS = {
    "apikey":        SB_SECRET,
    "Authorization": f"Bearer {SB_SECRET}",
    "Content-Type":  "application/json",
    "Prefer":        "return=representation",
}

# ─── Helpers Supabase ─────────────────────────────────────────────────────────
def sb_get(tabela, params=""):
    r = requests.get(f"{SB_URL}/rest/v1/{tabela}?{params}", headers=HEADERS)
    r.raise_for_status()
    return r.json()

def sb_post(tabela, dados):
    r = requests.post(f"{SB_URL}/rest/v1/{tabela}", headers=HEADERS, json=dados)
    r.raise_for_status()
    return r.json()

def sb_patch(tabela, filtro, dados):
    r = requests.patch(f"{SB_URL}/rest/v1/{tabela}?{filtro}",
                       headers={**HEADERS, "Prefer": "return=minimal"}, json=dados)
    r.raise_for_status()

# ─── Leitura do Excel ─────────────────────────────────────────────────────────
def detectar_genero(titulo):
    t = (titulo or "").upper()
    if "FEMININA" in t or "FEMININO" in t or "VENDEDORA" in t:
        return "feminino"
    if "MASCULINA" in t or "MASCULINO" in t or "VENDEDOR" in t:
        return "masculino"
    return "unissex"

def ler_excel():
    wb = openpyxl.load_workbook(XLSX_PATH, data_only=True)
    ws = wb["Estoque"]

    grupos = []       # lista de dicts com dados prontos para importar
    genero_atual = "unissex"

    for row in ws.iter_rows(values_only=True):
        desc, categoria, tamanho, fornecedor, qtd, custo, *_ = (list(row) + [None]*10)[:10]

        # linha de cabeçalho de grupo (ex: "CAMISAS MASCULINAS")
        if desc and not tamanho and not fornecedor and not qtd:
            genero_atual = detectar_genero(str(desc))
            continue

        # linha de cabeçalho de coluna
        if desc == "Descrição do Uniforme":
            continue

        # linha de totais (sem descrição ou sem tamanho)
        if not desc or not tamanho or not fornecedor:
            continue

        # linha de dado válido
        try:
            qtd_int   = int(qtd)   if qtd   else 0
            custo_val = float(custo) if custo else 0.0
        except (TypeError, ValueError):
            continue

        if qtd_int <= 0:
            continue

        grupos.append({
            "nome":      str(desc).strip(),
            "categoria": str(categoria).strip() if categoria else None,
            "genero":    genero_atual,
            "tamanho":   str(tamanho).strip(),
            "fornecedor":str(fornecedor).strip().upper(),
            "quantidade":qtd_int,
            "valor_unitario": round(custo_val, 2),
        })

    return grupos

# ─── Buscar almoxarifados ──────────────────────────────────────────────────────
def buscar_almoxarifados():
    rows = sb_get("unif_almoxarifados", "ativo=eq.true&select=id,nome")
    print("\nAlmoxarifados disponíveis:")
    for i, a in enumerate(rows):
        print(f"  {i+1}. {a['nome']}")
    idx = int(input("Escolha o almoxarifado para importar o estoque (número): ").strip()) - 1
    return rows[idx]["id"]

# ─── Cache de catálogo ────────────────────────────────────────────────────────
_catalogo_cache = {}

def obter_ou_criar_item(nome, categoria, genero):
    chave = (nome.lower(), genero)
    if chave in _catalogo_cache:
        return _catalogo_cache[chave]

    # busca existente
    rows = sb_get("unif_catalogo", f"nome=ilike.{requests.utils.quote(nome)}&genero=eq.{genero}&select=id")
    if rows:
        _catalogo_cache[chave] = rows[0]["id"]
        return rows[0]["id"]

    # cria novo
    novo = sb_post("unif_catalogo", {
        "nome":           nome,
        "tipo":           "uniforme",
        "categoria":      categoria,
        "genero":         genero,
        "sistema_tamanho":"letra",
        "prazo_troca_meses": 24,
        "ativo":          True,
    })
    item_id = novo[0]["id"]
    _catalogo_cache[chave] = item_id
    print(f"  [NOVO ITEM] {nome} ({genero})")
    return item_id

# ─── Atualizar estoque (upsert simples) ───────────────────────────────────────
def atualizar_estoque(almox_id, item_id, tamanho, qtd_adicionar, custo):
    rows = sb_get("unif_estoque",
        f"almoxarifado_id=eq.{almox_id}&item_id=eq.{item_id}&tamanho=eq.{requests.utils.quote(tamanho)}&select=id,quantidade,custo_medio")

    if rows:
        r = rows[0]
        qtd_atual   = r["quantidade"] or 0
        custo_atual = float(r["custo_medio"] or 0)
        nova_qtd    = qtd_atual + qtd_adicionar
        # custo médio ponderado
        if nova_qtd > 0:
            novo_custo = round((custo_atual * qtd_atual + custo * qtd_adicionar) / nova_qtd, 2)
        else:
            novo_custo = custo
        sb_patch("unif_estoque", f"id=eq.{r['id']}", {"quantidade": nova_qtd, "custo_medio": novo_custo})
    else:
        sb_post("unif_estoque", {
            "almoxarifado_id": almox_id,
            "item_id":         item_id,
            "tamanho":         tamanho,
            "quantidade":      qtd_adicionar,
            "custo_medio":     custo,
        })

# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    print("=== Importação de Estoque de Uniformes ===\n")

    linhas = ler_excel()
    print(f"Linhas lidas do Excel: {len(linhas)}")

    almox_id = buscar_almoxarifados()
    hoje     = date.today().isoformat()

    erros = []
    for i, l in enumerate(linhas):
        try:
            item_id = obter_ou_criar_item(l["nome"], l["categoria"], l["genero"])

            # registra entrada de lote
            sb_post("unif_entradas", {
                "item_id":         item_id,
                "almoxarifado_id": almox_id,
                "fornecedor":      l["fornecedor"],
                "tamanho":         l["tamanho"],
                "quantidade":      l["quantidade"],
                "valor_unitario":  l["valor_unitario"],
                "logo_bordada":    False,
                "data_entrada":    hoje,
                "obs":             "Importado do controle Excel",
                "status":          "ativo",
                "registrado_por":  "Importação",
            })

            # atualiza saldo do estoque
            atualizar_estoque(almox_id, item_id, l["tamanho"], l["quantidade"], l["valor_unitario"])

            print(f"  [{i+1:03d}] OK — {l['nome']} {l['genero']} {l['tamanho']} x{l['quantidade']} ({l['fornecedor']})")

        except Exception as e:
            msg = f"  [{i+1:03d}] ERRO — {l['nome']} {l['tamanho']}: {e}"
            print(msg)
            erros.append(msg)

    print(f"\n=== Concluído: {len(linhas)-len(erros)} importados, {len(erros)} erros ===")
    if erros:
        print("\nErros:")
        for e in erros:
            print(e)

if __name__ == "__main__":
    main()
