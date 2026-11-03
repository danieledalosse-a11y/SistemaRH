---
name: feedback-skill-storage-ephemera
description: "'Save skill' não funciona no ambiente da Dani — para skills novas/customizadas, guardar SKILL.md + references como arquivos normais na pasta dela e ler direto, sem depender do mecanismo de instalação de skill"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 51652317-ceea-4334-81fb-794ecf6485fa
  modified: 2026-09-02T12:01:29.209Z
---

**Conclusão final (depois de testar todos os caminhos):** o fluxo oficial de instalar uma skill nova via `skill-creator` (gerar `.skill`, mandar por `SendUserFile`, usuário clica em "Save skill" no cartão) **não funciona no ambiente da Dani**. Testado nesta ordem, todos falharam:
1. Escrever `SKILL.md`/`references/` direto em `AppData\Roaming\Claude\local-agent-mode-sessions\skills-plugin\{uuid}\{uuid}\skills\` — os arquivos somem sozinhos entre uma mensagem e outra (só a pasta vazia sobra).
2. Empacotar em `.skill` e mandar via `SendUserFile` de dentro dessa mesma pasta efêmera — o cartão aparece no chat, mas ao tentar baixar dá "Não foi possível encontrar este arquivo" (o caminho já tinha sumido).
3. Copiar o `.skill` pra uma pasta real da Dani antes de mandar — esse download funcionou (ela conseguiu ver o arquivo no Explorer), mas ao abrir o `.skill` o Windows não reconhece a extensão e pergunta qual app usar — não é assim que se instala. O botão "Save skill" deveria aparecer no cartão dentro do chat, mas no cliente dela o cartão só mostra opções de navegação da conversa ("Fixar como capítulo", "Bifurcar a partir daqui") — sem botão de salvar. Aparentemente essa função depende de uma permissão de conta/organização que ela não tem habilitada.

**O que fazer em vez disso — abordagem que efetivamente funciona:** não tentar instalar como skill de verdade. Guardar `SKILL.md` e `references/*.md` como **arquivos de texto normais dentro da pasta de trabalho da própria Dani** (o mesmo lugar onde `CLAUDE.md` do PainelRH já vive e funciona de forma confiável) e, quando ela pedir algo que a skill cobriria, **ler esses arquivos diretamente com a ferramenta Read** em vez de esperar o carregamento automático de skill. Local atual da skill "conferencia-folha-pagamento":

```
4.0-FOLHA DE PAGAMENTO\CLAUDE\conferencia-folha-pagamento\SKILL.md
4.0-FOLHA DE PAGAMENTO\CLAUDE\conferencia-folha-pagamento\references\fontes-de-dados.md
```

Se precisar atualizar essas regras no futuro, editar esses arquivos direto com `Edit`/`Write` (são arquivos reais, persistem normalmente) — não precisa reconstruir do zero nem tentar o fluxo de `.skill`/`Save skill` de novo.
