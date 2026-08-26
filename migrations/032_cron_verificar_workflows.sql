-- Habilita pg_cron (executar uma vez no projeto Supabase, se ainda não ativo)
-- create extension if not exists pg_cron;

-- Remove job anterior se existir
select cron.unschedule('verificar-workflows-diario')
where exists (
  select 1 from cron.job where jobname = 'verificar-workflows-diario'
);

-- Cria job: roda todo dia às 07:00 horário de Brasília (10:00 UTC)
select cron.schedule(
  'verificar-workflows-diario',
  '0 10 * * *',
  $$
  select
    net.http_post(
      url := 'https://rujtbxwssiofiialnbbg.supabase.co/functions/v1/verificar-workflows',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || current_setting('app.service_role_key', true)
      ),
      body := '{}'::jsonb
    )
  $$
);
