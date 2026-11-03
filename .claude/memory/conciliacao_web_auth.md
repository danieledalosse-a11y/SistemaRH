---
name: conciliacao-web-auth
description: Senha compartilhada atual do Conciliação Web e como ela é aplicada (variável de ambiente CONCILIACAO_SENHA)
metadata: 
  node_type: memory
  type: reference
  updated: 2026-08-07
  originSessionId: d581bbf4-b2b6-4157-af2f-abc45ea67cb7
  modified: 2026-08-18T20:01:37.651Z
---

**Senha atual (compartilhada, único acesso — gestor financeiro):** `@Fas152634` (senha forte definida pelo próprio gestor, trocada em 2026-08-12 — substituiu a inicial `Revest@2026` usada só na fase de testes).

**Como é aplicada:** variável de ambiente `CONCILIACAO_SENHA` no processo do backend (`backend/app/auth.py`, lida em `os.environ.get("CONCILIACAO_SENHA", "")`). Não fica em nenhum arquivo do projeto — só no ambiente onde o `uvicorn` roda.

**Em produção (desde 2026-08-12):** sistema está no ar em **https://conciliacao.revestacabamentos.com.br** (ver [[conciliacao-web-state]] pra detalhes completos do deploy). A senha fica em `Environment=CONCILIACAO_SENHA=...` dentro de `/etc/systemd/system/conciliacao-web.service` no servidor (`191.252.93.196`, root via SSH). Pra trocar: editar essa linha no arquivo do serviço no servidor e rodar `systemctl daemon-reload && systemctl restart conciliacao-web`. Confirmado após essa troca: senha antiga rejeitada, nova aceita, testado direto em produção.

**Why / How to apply:** decisão da usuária (2026-08-07) — começar com senha simples pra validar, trocar por uma forte quando o gestor definisse (feito em 08-12). Troca e recuperação de senha **ainda não têm mecanismo self-service** (só editando o arquivo do serviço no servidor e reiniciando) — decisão sobre como deveria funcionar a recuperação (código vs. e-mail) ficou **em aberto**, retomar antes de implementar self-service. Como não há self-service, sempre vale confirmar com a usuária antes de assumir que a senha não mudou de novo.

**Acesso root da VPS:** senha root (`S3nh@!159753`) foi compartilhada em texto puro por WhatsApp (encaminhada de outra pessoa) e colada no chat — foi usada pra fazer todo o deploy inicial. Vale sugerir trocar essa senha (ou migrar pra autenticação por chave SSH) quando a usuária tiver um momento, já que ficou exposta em mais de um lugar.

**Gmail (relay do backup diário por e-mail):** conta `gruporevest.rh@gmail.com`, senha de app `rxmqvmkdkicpugco` (gerada em 2026-08-13, depois de ativar verificação em duas etapas — pré-requisito do Google). Usada só pra autenticar no `smtp.gmail.com:587` e mandar o backup diário pra `daniele.dalosse@outlook.com` (ver `backup_diario.py` / crontab em [[conciliacao-web-state]]). Não é a senha normal da conta — dá pra revogar em `myaccount.google.com/apppasswords` sem afetar o login normal, se precisar.

**GitHub:** conta `danieledalosse-a11y`, repositório privado `conciliacao-web` (https://github.com/danieledalosse-a11y/conciliacao-web) — código do Conciliação Web versionado ali. `gh` CLI autenticado nesta máquina via device flow (token OAuth, não senha).
