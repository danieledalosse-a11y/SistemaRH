---
name: feedback-style
description: Preferências de resposta e estilo de colaboração confirmadas pela usuária
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 32ffb793-7e1c-481e-b441-84ffa52b6b17
  modified: 2026-10-08T19:16:58.665Z
---

Sempre salvar arquivos editados na pasta do projeto: `C:\Users\reves\REVEST DO BRASIL ACABAMENTOS LTDA\RH - Documentos\4.0-FOLHA DE PAGAMENTO\CLAUDE\PainelRH`.

**Why:** A usuária confirmou explicitamente esse caminho como destino padrão.  
**How to apply:** Toda edição de `index.html`, `app.js`, `styles.css` vai para esse diretório. Após mudanças nos 3 arquivos fonte, regenerar sempre o `Painel-Salarial-RH.html` (arquivo autocontido).

---

Nunca abreviar valores monetários nos painéis — usar número completo (ex: `R$ 12.500,00` e não `12,5k`).

**Why:** Usuária pediu explicitamente ao perceber labels abreviados no gráfico SVG.  
**How to apply:** Em todos os `fmtBRL`, `fmtBRLNoSymbol`, e rótulos de gráficos SVG, usar o valor completo.

---

Em todo formulário de cadastro com campo "Ordem", preencher automaticamente com max(ordem)+1 ao abrir para novo item.

**Why:** Usuária definiu como padrão do sistema para evitar conflitos de numeração.
**How to apply:** Em qualquer modal de criação no SistemaRH, calcular o próximo número de ordem com base nos registros já existentes na listagem atual.

---

Antes de executar qualquer mudança significativa, analisar e apresentar a proposta primeiro.

**Why:** Padrão estabelecido pela usuária — ela aprova cada etapa antes da execução.  
**How to apply:** Responder "posso fazer X desta forma — o que acha?" e aguardar "pode fazer" antes de editar arquivos.

---

Todo módulo, feature ou regra implementada deve ter skill e contexto documentados — sem exceção.

**Why:** O sistema é premium e precisa garantir que alterações futuras não causem impacto inesperado nem consumam tokens excessivos tentando entender o que já foi definido. É premissa central do projeto.  
**How to apply:**
- Ao implementar ou alterar qualquer módulo: atualizar (ou criar) o arquivo `.claude/agents/<modulo>.md` com arquitetura, regras críticas, queries, HTML relevante, bugs resolvidos e regras de expansão.
- Ao descobrir regras de runtime, padrões de dados ou comportamentos não óbvios: registrar em `memory/sistemarh_state.md` E na skill do módulo afetado.
- Ao encerrar uma sessão que produziu algo novo: verificar se skill e memória estão sincronizados com o que foi feito.
- Nunca deixar código funcionando mas sem documentação correspondente — código sem contexto é dívida técnica.
