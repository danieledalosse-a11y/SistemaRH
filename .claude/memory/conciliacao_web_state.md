---
name: conciliacao-web-state
description: "Estado atual do Conciliação Web (produção, infraestrutura, pendências em aberto) — para arquitetura e regras de negócio, ver CLAUDE.md do projeto, não duplicado aqui"
metadata:
  node_type: memory
  type: project
  originSessionId: d581bbf4-b2b6-4157-af2f-abc45ea67cb7
  modified: 2026-08-19T20:00:34.308Z
---

## O que é

Web app de conciliação bancária da Revest do Brasil Acabamentos Ltda, substituindo um `.exe` desktop (Python/Tkinter) usado pelo gestor financeiro (Flávio). Localização: `C:\Users\reves\REVEST DO BRASIL ACABAMENTOS LTDA\RH - Documentos\16- CONCILIACAO WEB`. **Em produção desde 2026-08-12:** https://conciliacao.revestacabamentos.com.br

**Arquitetura, regras de negócio, decisões que divergem do desktop original (`14-CONCILIACAO`), convenções de teste e processo de deploy: tudo isso está no `CLAUDE.md` do próprio projeto — não duplicar aqui.** Esta memória guarda só o que o CLAUDE.md não cobre: infraestrutura/credenciais, histórico operacional (o que já foi feito no servidor), e o que ainda está em aberto entre sessões.

## Infraestrutura do servidor

VPS própria da empresa ("INTRA REVEST"), Ubuntu 18.04 (EOL), provedor Locaweb/PublicCloud — `vps23053.publiccloud.com.br` / IP `191.252.93.196`. Compartilhada com e-mail corporativo (Postfix) e serviços antigos (MySQL, PostgreSQL, phpMyAdmin). Acesso root via SSH — credenciais em [[conciliacao-web-auth]].

- App roda como serviço systemd `conciliacao-web` (`uvicorn app.main:app --host 127.0.0.1 --port 8811`, `Restart=on-failure`), em `/opt/conciliacao-web/` (`backend/` com `venv/` Python 3.11.9 compilado do source — o sistema só tinha Python 3.6; `frontend/` estático, servido pelo próprio FastAPI via `StaticFiles`).
- Web na frente: OpenLiteSpeed (OLS), vhost próprio `conciliacao-web` em `/usr/local/lsws/conf/vhosts/conciliacao-web/vhconf.conf`, proxy pra `127.0.0.1:8811`. Cache de navegador desativado só nesse vhost (`enableExpires 0`).
- HTTPS via Let's Encrypt (`certbot certonly --webroot`), renovação automática, válido até 2026-11-10. DNS: CNAME `conciliacao` → `vps23053.publiccloud.com.br`, administrado pela Byte a Byte (acesso via Maycon, TI da empresa).
- **Restrição de acesso por IP fixo** (só os links da Matriz: `179.184.66.130`, `200.195.169.233`, `201.86.33.9`, `201.86.33.10`, `200.195.169.234`) — implementada via `rewrite` no vhost (não `accessControl`, que não funciona de forma confiável dentro de `context type=proxy` no OLS — limitação conhecida). **Ainda não confirmado pela usuária** um teste de fora da rede da Matriz (ex.: celular com Wi-Fi desligado) — pendente desde 2026-08-12.
- `fail2ban` (bane IP após 5 tentativas SSH erradas em 10 min) + `ufw` (`default deny incoming`, libera só 22/80/443/25/9102) ativos desde 2026-08-12.
- Backup diário automático dos dados (`backend/storage/`) às 3h, script `/opt/conciliacao-web/scripts/backup_diario.py`: compacta em `.tar.gz` (rotação 30 dias em `/root/backups_conciliacao/`) e envia por e-mail via relay Gmail (porta 25 de saída é bloqueada pelo provedor da VPS) — credenciais em [[conciliacao-web-auth]].
- Backup automático da própria hospedagem (Bacula, 2x/dia) — **não confirmado** se cobre `/opt` especificamente.
- Repositório Git privado: https://github.com/danieledalosse-a11y/conciliacao-web (conta `danieledalosse-a11y`, `gh` CLI autenticado nesta máquina via device flow).

## Estado atual (2026-08-18)

Sistema em produção, com o histórico real de pendências do desktop importado (2026-08-12), janela de pendências em 90 dias, e as correções mais recentes (`id_origem` estável do lado do banco, saldo de referência do BB, Histórico agrupado por dia com desfazer/desconciliar granular — ver CLAUDE.md) já no ar.

**Pendências em aberto:**
- Confirmação da usuária sobre o teste de restrição de IP pelo celular (Wi-Fi desligado) — nunca foi feito.
- Decisão sobre troca/recuperação de senha self-service — adiada, ver [[conciliacao-web-auth]].
- Rotacionar a senha root da VPS (foi compartilhada em texto puro por WhatsApp) — sugerido, não feito.
- Confirmar com a Byte a Byte/TI se o backup da hospedagem cobre `/opt`.

**Evento notável — BB Matriz arquivado e resetado (2026-08-14):** durante o diagnóstico do bug de `id_origem`, a conta `bb_matriz` acumulou ~380 registros de teste (2026-08-11 a 08-14). Por pedido da usuária, esses dados foram **movidos** (nunca apagados) para `/root/arquivado_dados_teste_conciliacao/2026-08-14_bb_matriz_agosto/` no servidor, e a conta foi restaurada pro estado pós-importação do desktop (achado via backup automático das 08:37 de 13/08, anterior a qualquer teste daquele dia — 242 resolvidas + 8 ativas). O gestor vem reprocessando agosto normalmente desde então (dias 13 e 14/08 já refeitos e confirmados corretos); não há mais lacuna pendente.

## Cuidados já aprendidos (evitar repetir)

- **Incidente grave (2026-08-19): login quebrado em produção por 2 deploys que sobrescreveram uma linha só-do-servidor.** Detalhe técnico completo e a correção definitiva estão no CLAUDE.md ("Incidente grave..."). O que vale lembrar aqui: o sintoma (login falha, "Failed to fetch") pareceu por horas ser rede/firewall/cache do lado da usuária — foi uma investigação longa na direção errada antes de eu checar se o PRÓPRIO deploy tinha quebrado algo. **Sempre que "funcionava antes de uma mudança, parou depois", comparar o que está servido em produção (`curl` direto na URL pública) com o esperado ANTES de investigar causas externas.**

- **Nunca testar usando a empresa "Matriz"** (dado real do gestor) — usar a empresa isolada **"Pedras"**. Um incidente real (2026-08-06): testes automatizados feitos em paralelo com a usuária testando ao vivo quase apagaram uma conciliação real dela num `rm -f *.json` de "limpeza" — recuperado 100% pelo mecanismo de backup do "Desfazer", mas a lição ficou: nunca `rm -f`/wildcard em `backend/storage/pendencias/`, `historico/` ou `pendencias_backups/`; limpar só o arquivo específico da conta de teste.
- **`preview_start` pode reaproveitar um servidor errado** por colisão de porta/nome numa sessão com múltiplos projetos abertos — se acontecer, rodar `python3 -m http.server <porta>` manualmente numa porta dedicada em vez de confiar no nome.
- Ao testar localmente via navegador, acessar pela MESMA origem do backend (`http://127.0.0.1:8811`, que já serve o frontend) — a porta estática separada (5500/5501) esbarra no CORS travado só pro domínio de produção.
- ~~Avisar pra dar Ctrl+Shift+R após deploy de frontend~~ — **resolvido em 2026-08-19** (middleware `Cache-Control: no-store` em `app/main.py`, ver CLAUDE.md). Causou confusão real duas vezes (usuária e gestor, em dias diferentes) antes de ser corrigido.

## Como continuar esta sessão

Esta conversa começou dentro da sessão do projeto PainelRH — `16- CONCILIACAO WEB` foi adicionado à mesma sessão, não é uma sessão separada. Numa sessão nova apontando só pra essa pasta, esta memória não carrega automaticamente (memória é por diretório de projeto) — nesse caso, recriar um resumo equivalente lá ou continuar usando esta sessão multi-pasta.
