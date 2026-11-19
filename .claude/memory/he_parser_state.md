---
name: he-parser-state
description: "Estado e regras do parser pivot Senior para o módulo HE — estrutura dos PDFs, state machine, fixes aplicados e resultados de validação por empresa"
metadata:
  node_type: memory
  type: project
  updated: 2026-11-18T00:00:00
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-11-19T14:47:24.629Z
---

## Parser Pivot Senior (_parsePDFPages) — Módulo Horas Extras

### Estrutura geral do PDF Senior CADCALC (pivot)
- Funcionários = COLUNAS (eixo x), tipos HE = LINHAS (eixo y)
- Linha "Trabalhador" é o cabeçalho de colunas (primeira linha da tabela)
- Dados processados de cima para baixo (y crescente)
- `LABEL_X_MAX = 90`, `EMP_X_MIN = 90`, `X_TOL = 5`
- `VALUE_X_MIN_DYN = min(90, cols[0].x − ceil(colSpacing×1.5))` — captura valores largos iniciando antes de x=90
- `colIdxForX`: zona por ponto médio entre colunas adjacentes (não X_TOL fixo)

---

### Dois formatos de PDF identificados e validados

#### Formato A — Grupo Revest (empresa 0148)
Label e quant chegam na mesma linha; "Valor" chega separado:
```
"HExt"       → pendingLabelParts
"50%"  [q…]  → TYPE_RESOLVE: detecta tipo, expectQuant=true, aplica quant
"Valor" [v…] → expectQuant=false, aplica como valor
```
Percentuais: 50 / 70 / 80 / 85 / 100%

#### Formato B — Paranavaí (4148) e Porto Rico (5148)
Para 50% e 60%: quant chega **antes** do label do tipo:
```
[q…] "Quant"  → Fix C: bufferiza (tipo ainda desconhecido)
"HExt"        → pendingLabelParts
"50%"         → TYPE_RESOLVE: detecta tipo, descarrega bufferedQuant como quant
[v…] "Valor"  → aplica como valor
```
Para 80%, 85%, 100%: mesmo formato A.
TOTAL EXTRA: label inclui CNPJ antes → "07.666.823/0004-42 TOTAL EXTRA Quant" → Fix D.
Percentuais: 50 / 60 / 80 / 85 / 100% (60% em vez de 70% — convenção sindical diferente)

---

### State machine — variáveis
```javascript
let pendingLabelParts = [];
let currentType  = null;      // '50','60','70','80','85','100','dsr','pdf_total'
let expectQuant  = false;
let bufferedQuant = [];
let bufferedLabelValor = [];
```

### Regras e fixes aplicados (histórico completo)

| Fix | Descrição | Commit |
|---|---|---|
| Fix base | detectType("Valor") retornava '50' → corrigido | 7b5a0ad |
| Fix base | "Quant" não resolvia pendingLabelParts antes de expectQuant | 7b5a0ad |
| Fix base | DSR S/EXTRA com valores inline tratado como valor → quant=0 | 7b5a0ad |
| Fix base | "Valor" label-only ia para pending → inflava quant (ALDENIR) | 7b5a0ad |
| Fix base | Números largos x<90 descartados → valor=0 (DANIELE) | 7b5a0ad |
| Fix A | hadBufQ: quando bufferedQuant descarregado e há valueItems → vai para bufferedLabelValor | 7b5a0ad |
| Fix B | nV<3, sem label, currentType, !expectQuant → aplica como valor | 7b5a0ad |
| **Fix C** | **Quant antes do label (Formato B): bufferiza quando tipo não resolvido agora** | **27d948b** |
| **Fix D** | **TOTAL EXTRA com CNPJ: `/^\s*total/i` → `/\btotal\b/i` nos dois handlers** | **27d948b** |

#### Fix C — detalhe (linha ~1061, nV≥3 Quant handler)
```javascript
const hadPending = pendingLabelParts.length > 0;
if (hadPending) { currentType = detectType(pendingLabelParts.join(' ')); pendingLabelParts = []; }
if (currentType && hadPending) { expectQuant = true; }
else { bufferedQuant = [...valueItems]; bufferedLabelValor = []; skipApply = true; }
```
**Regra:** só aplica imediatamente se `hadPending && currentType`. Se `currentType` vinha de bloco anterior sem pending recém-resolvido → sempre bufferiza.

#### Fix D — detalhe (linhas ~1061 e ~1157)
Ambos os handlers de Quant (nV≥3 e nV<3):
```javascript
} else if (/quant/i.test(labelStr) && !/\btotal\b/i.test(labelStr)) {
```

---

### Resultados de validação (jan/2026, validado Nov/2026)
| Empresa | Código | Colaboradores | Resultado | Fix |
|---|---|---|---|---|
| Grupo Revest | 0148 | 147 | 147/147 ✓ (zero regressões após Fix C+D) | — |
| Paranavaí | 4148 | incluído abaixo | — | Fix C + Fix D |
| Porto Rico | 5148 | incluído abaixo | — | Fix C + Fix D |
| Paranavaí + Porto Rico | 4148+5148 | 24 | 24/24 ✓ | Fix C + Fix D |

Vinculação Paranavaí/Porto Rico: 15 ativos + 9 inativos + 0 não encontrados.

**Why:** [[feedback-dp-arquitetura-generica]] — parser genérico lê percentuais diretamente do PDF (`/(\d+)%/`), sem lista fixa. 60% é armazenado como `percentuais['60']`, separado de 50%, respeitando a convenção sindical de cada empresa.

---

### Pitfall — colisão de nome `_MESES_PT`
`const _MESES_PT` já existe na linha ~490 como objeto para o parser (mapa `NOMEMÊS → 'MM'`). Declarar outro `const _MESES_PT` em qualquer ponto do script causa `SyntaxError: Identifier already declared`, travando o módulo inteiro antes de qualquer função rodar. Para nomes de meses por extenso usar `_MESES_NOMES` (array, linha ~1075).
