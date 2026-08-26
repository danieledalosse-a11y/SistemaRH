import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const sb = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
)

const hoje = new Date()
hoje.setHours(0, 0, 0, 0)

function addDias(base: string, dias: number): Date {
  const d = new Date(base + 'T00:00:00')
  d.setDate(d.getDate() + dias)
  return d
}

function diasRestantes(data: Date): number {
  return Math.ceil((data.getTime() - hoje.getTime()) / 86400000)
}

function fmtDate(d: Date): string {
  return d.toISOString().slice(0, 10)
}

function fmtMes(d: Date): string {
  return `${String(d.getMonth() + 1).padStart(2, '0')}/${d.getFullYear()}`
}

async function valorBonusPorAdmissao(dataAdm: string): Promise<number | null> {
  const { data } = await sb
    .from('param_bonus_indicacao')
    .select('valor')
    .lte('vigencia_inicio', dataAdm)
    .or(`vigencia_fim.is.null,vigencia_fim.gte.${dataAdm}`)
    .order('vigencia_inicio', { ascending: false })
    .limit(1)
  return data?.[0]?.valor ?? null
}

async function processoAberto(colaboradorId: number, tipo: string, extraFiltro?: string): Promise<boolean> {
  let query = sb
    .from('processos_rh')
    .select('id')
    .eq('colaborador_id', colaboradorId)
    .eq('tipo', tipo)
    .eq('status', 'aberto')
  // Para bonus_indicacao, verifica pelo indicado_id dentro de dados_extras
  if (extraFiltro) {
    query = query.filter('dados_extras->>indicado_id', 'eq', extraFiltro)
  }
  const { data } = await query
  return (data?.length ?? 0) > 0
}

async function criarProcesso(payload: object, checklist: { item: string; prazo_dias: number }[]) {
  const { data, error } = await sb
    .from('processos_rh')
    .insert(payload)
    .select('id')
    .single()
  if (error || !data) throw error ?? new Error('processo não criado')
  const itens = checklist.map((it, i) => ({
    processo_id: data.id,
    item: it.item,
    prazo_dias: it.prazo_dias,
    ordem: i,
    concluido: false,
  }))
  await sb.from('processos_checklist').insert(itens)
  return data.id
}

// ─── Bônus de Indicação ───────────────────────────────────────────────────────

async function verificarBonusIndicacao() {
  const log: string[] = []

  const { data: candidatos } = await sb
    .from('colaboradores')
    .select('id, nome, data_admissao, indicado_por_id')
    .is('data_demissao', null)
    .eq('ativo', true)
    .not('indicado_por_id', 'is', null)
    .eq('indicacao_bonus_gerado', false)

  for (const c of candidatos ?? []) {
    const fim90 = addDias(c.data_admissao, 90)
    const restantes = diasRestantes(fim90)
    if (restantes > 12 || restantes < -30) continue // janela: até 30 dias após vencer

    // Busca indicador
    const { data: indRows } = await sb
      .from('colaboradores')
      .select('id, nome')
      .eq('id', c.indicado_por_id)
      .eq('ativo', true)
    const indicador = indRows?.[0]
    if (!indicador) continue

    if (await processoAberto(indicador.id, 'bonus_indicacao', String(c.id))) continue

    const dataAdm = c.data_admissao.slice(0, 10)
    const valorBonus = await valorBonusPorAdmissao(dataAdm)
    const mesRef = fmtMes(fim90)

    const procId = await criarProcesso({
      tipo: 'bonus_indicacao',
      colaborador_id: indicador.id,
      colaborador_nome: indicador.nome,
      criado_por: 'Sistema (automático)',
      dados_extras: {
        indicado_id: c.id,
        indicado_nome: c.nome,
        data_admissao_indicado: dataAdm,
        mes_folha: mesRef,
        valor_bonus: valorBonus,
      },
    }, [
      { item: `Confirmar que ${c.nome} completou 90 dias de casa (vence ${fim90.toLocaleDateString('pt-BR')}) e ainda está ativo`, prazo_dias: Math.max(restantes, 1) },
      { item: 'Enviar solicitação ao escritório contábil usando o texto da ficha abaixo', prazo_dias: Math.max(restantes, 1) + 2 },
    ])

    await sb.from('colaboradores').update({ indicacao_bonus_gerado: true }).eq('id', c.id)
    log.push(`bonus_indicacao #${procId}: ${indicador.nome} por ${c.nome}`)
  }

  return log
}

// ─── Período de Experiência ───────────────────────────────────────────────────

async function verificarExperiencia() {
  const log: string[] = []

  const { data: candidatos } = await sb
    .from('colaboradores')
    .select('id, nome, data_admissao, data_fim_experiencia, periodo_experiencia, prorrogacao_45_gerado, avaliacao_90_gerado')
    .eq('ativo', true)
    .eq('em_experiencia', true)
    .is('data_demissao', null)

  for (const c of candidatos ?? []) {
    const adm = c.data_admissao

    // Prazo 45 dias
    if (!c.prorrogacao_45_gerado) {
      const periodo = parseInt(c.periodo_experiencia ?? '45')
      const fim45 = addDias(adm, periodo)
      const restantes45 = diasRestantes(fim45)
      if (restantes45 >= 0 && restantes45 <= 12) {
        if (!(await processoAberto(c.id, 'prorrogacao_experiencia'))) {
          const procId = await criarProcesso({
            tipo: 'prorrogacao_experiencia',
            colaborador_id: c.id,
            colaborador_nome: c.nome,
            criado_por: 'Sistema (automático)',
            dados_extras: { fim_45_dias: fmtDate(fim45), dias_restantes: restantes45 },
          }, [
            { item: `Avaliar colaborador ${c.nome} — 1º período de experiência vence em ${fim45.toLocaleDateString('pt-BR')}`, prazo_dias: Math.max(restantes45, 1) },
            { item: 'Obter parecer do gestor: prorrogar por mais 45 dias ou encerrar contrato', prazo_dias: Math.max(restantes45, 1) },
            { item: 'Enviar prorrogação de contrato ao escritório contábil', prazo_dias: Math.max(restantes45, 1) },
            { item: 'Arquivar documento assinado de prorrogação', prazo_dias: Math.max(restantes45, 1) + 1 },
          ])
          await sb.from('colaboradores').update({ prorrogacao_45_gerado: true }).eq('id', c.id)
          log.push(`prorrogacao_experiencia #${procId}: ${c.nome}`)
        }
      }
    }

    // Prazo 90 dias
    if (!c.avaliacao_90_gerado) {
      const fim90 = c.data_fim_experiencia
        ? new Date(c.data_fim_experiencia + 'T00:00:00')
        : addDias(adm, 90)
      const restantes90 = diasRestantes(fim90)
      if (restantes90 >= 0 && restantes90 <= 12) {
        if (!(await processoAberto(c.id, 'avaliacao_final_experiencia'))) {
          const procId = await criarProcesso({
            tipo: 'avaliacao_final_experiencia',
            colaborador_id: c.id,
            colaborador_nome: c.nome,
            criado_por: 'Sistema (automático)',
            dados_extras: { fim_experiencia: fmtDate(fim90), dias_restantes: restantes90 },
          }, [
            { item: `Avaliação final de ${c.nome} — experiência vence em ${fim90.toLocaleDateString('pt-BR')}`, prazo_dias: Math.max(restantes90, 1) },
            { item: 'Obter parecer do gestor: confirmar efetivação ou iniciar desligamento', prazo_dias: Math.max(restantes90, 1) },
          ])
          await sb.from('colaboradores').update({ avaliacao_90_gerado: true }).eq('id', c.id)
          log.push(`avaliacao_final_experiencia #${procId}: ${c.nome}`)
        }
      }
    }
  }

  return log
}

// ─── Limpeza de em_experiencia vencido ───────────────────────────────────────

async function limparExperienciaVencida() {
  const hojeStr = fmtDate(hoje)
  const { data } = await sb
    .from('colaboradores')
    .select('id, data_admissao, data_fim_experiencia, periodo_experiencia')
    .eq('em_experiencia', true)
    .eq('ativo', true)

  const vencidos = (data ?? []).filter(c => {
    const fim = c.data_fim_experiencia
      ? new Date(c.data_fim_experiencia + 'T00:00:00')
      : addDias(c.data_admissao, parseInt(c.periodo_experiencia ?? '90'))
    return fmtDate(fim) < hojeStr
  })

  if (vencidos.length) {
    const ids = vencidos.map(c => c.id)
    await sb.from('colaboradores').update({ em_experiencia: false }).in('id', ids)
  }

  return vencidos.length
}

// ─── Handler principal ────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  // Aceita chamada via cron (POST sem body) ou manual com Authorization
  try {
    const [logBonus, logExp, vencidos] = await Promise.all([
      verificarBonusIndicacao(),
      verificarExperiencia(),
      limparExperienciaVencida(),
    ])

    const resultado = {
      executado_em: new Date().toISOString(),
      bonus_indicacao: logBonus,
      experiencia: logExp,
      em_experiencia_corrigidos: vencidos,
    }

    console.log('verificar-workflows:', JSON.stringify(resultado))
    return new Response(JSON.stringify(resultado), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('verificar-workflows erro:', err)
    return new Response(JSON.stringify({ erro: String(err) }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
