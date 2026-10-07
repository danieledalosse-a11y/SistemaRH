/* ── Capitalização de nomes (banco guarda em caps) ── */
function _titleCase(str) {
  if (!str) return str;
  const min = new Set(['de','da','do','dos','das','e','em','na','no']);
  return str.toLowerCase().split(' ').map((w,i) =>
    (!i || !min.has(w)) ? w.charAt(0).toUpperCase()+w.slice(1) : w
  ).join(' ');
}

/* ── Tabs ── */
function showTab(id, btn) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.sec').forEach(s => s.classList.remove('active'));
  btn.classList.add('active');
  document.getElementById('sec-'+id).classList.add('active');
  if (id==='carreira')       renderCarreira();
  if (id==='financeiro')     renderFinanceiro();
  if (id==='ferias')        renderFerias();
  if (id==='desenvolvimento') renderDesenvolvimento();
  if (id==='historico')     renderHistorico();
}

/* ── Hero ── */
const _VINCULO_LABEL = { clt: 'CLT', promotora: 'Promotora', pro_labore: 'Pró-labore' };

/* SVG ícones para métricas — stroke, sem fill */
const _MI_ICO = {
  mat:    `<svg viewBox="0 0 24 24" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2"/><line x1="3" y1="9" x2="21" y2="9"/><line x1="7" y1="4" x2="7" y2="9"/><line x1="17" y1="4" x2="17" y2="9"/></svg>`,
  vinc:   `<svg viewBox="0 0 24 24" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/></svg>`,
  adm:    `<svg viewBox="0 0 24 24" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>`,
  tempo:  `<svg viewBox="0 0 24 24" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15.5 14"/></svg>`,
  grupo:  `<svg viewBox="0 0 24 24" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>`,
  emp:    `<svg viewBox="0 0 24 24" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>`,
  gestor: `<svg viewBox="0 0 24 24" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>`,
};

function _miItem(ico, label, val, color) {
  return `<div class="hero-meta-item">
    <div class="hero-mi-ico${color?' '+color:''}">${ico}</div>
    <div class="hero-mi-txt">
      <span class="hero-mi-label">${label}</span>
      <span class="hero-mi-val">${val}</span>
    </div>
  </div>`;
}

function renderHero() {
  const c = _colab;

  /* ── Foto / iniciais ── */
  const ini = (c.nome||'?').split(' ').map(w=>w[0]).join('').slice(0,2).toUpperCase();
  const ph  = document.getElementById('heroPhoto');
  if (c.foto_url) {
    ph.innerHTML = `<img src="${c.foto_url}" alt="${c.nome}">`;
  } else {
    ph.textContent = ini;
  }

  /* ── Topbar ── */
  document.getElementById('topbarNome').textContent = _titleCase(c.nome) || 'Ficha';

  /* ── Nome ── */
  document.getElementById('heroNome').textContent = _titleCase(c.nome) || '—';

  /* ── Badge de status ── */
  const ativo = !c.data_demissao;
  document.getElementById('heroStatusBadge').innerHTML =
    `<span class="hero-status-badge ${ativo?'ativo':'inativo'}">${ativo?'Ativo':'Inativo'}</span>`;

  /* ── Cargo ── */
  document.getElementById('heroCargo').textContent = c.cargo || '';

  /* ── Localização: Setor · Unidade ── */
  const ICO_ORG = `<svg viewBox="0 0 24 24" fill="none" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 7V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2"/></svg>`;
  const ICO_PIN = `<svg viewBox="0 0 24 24" fill="none" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13S3 17 3 10a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>`;

  const locItems = [];
  if (c.setor)
    locItems.push(`<span class="hero-loc-item">${ICO_ORG}<span>${c.setor}</span></span>`);
  const unidade = c.empresa_atuacao_nome || c.empresa_atuacao;
  if (unidade)
    locItems.push(`<span class="hero-loc-item">${ICO_PIN}<span>${unidade}</span></span>`);
  document.getElementById('heroLoc').innerHTML =
    locItems.join('<span class="hero-loc-sep">·</span>');

  /* ── Meta: 4 métricas em 1 linha ── */
  const vinculoVal = c.tipo_vinculo ? (_VINCULO_LABEL[c.tipo_vinculo] || c.tipo_vinculo) : null;
  const metaItems = [];
  if (c.matricula)
    metaItems.push(_miItem(_MI_ICO.mat,   'Matrícula',     c.matricula,             'c-blue'));
  if (vinculoVal)
    metaItems.push(_miItem(_MI_ICO.vinc,  'Vínculo',       vinculoVal,              ''));
  if (c.data_admissao)
    metaItems.push(_miItem(_MI_ICO.adm,   'Admissão',      fd(c.data_admissao),     'c-blue'));
  if (c.data_admissao)
    metaItems.push(_miItem(_MI_ICO.tempo, 'Tempo de casa', tempoStr(c.data_admissao), 'c-purple'));

  document.getElementById('heroMeta').innerHTML =
    metaItems.length ? `<div class="hero-meta-row">${metaItems.join('')}</div>` : '';

  /* ── Botões — links para Cadastro e Processos ── */
  const sbId = c.id;
  const baseUrl = '../../modulos/'; // relativo à ficha, que fica em modulos/colaborador/
  document.getElementById('btnEditarCadastro').href = `../cadastro/index.html?id=${sbId}`;
  document.getElementById('acoesAbrir').href        = `../cadastro/index.html?id=${sbId}`;
  document.getElementById('acoesProcessos').href    = `../processos/index.html?colaborador_id=${sbId}`;

  /* ── Alertas e lembretes ── */
  document.getElementById('heroAlertas').innerHTML = _buildAlertas();
}

/* ── Toggle do dropdown Ações ── */
function _toggleAcoes(e) {
  e.stopPropagation();
  const menu = document.getElementById('heroAcoesMenu');
  menu.classList.toggle('open');
}
document.addEventListener('click', () => {
  document.getElementById('heroAcoesMenu')?.classList.remove('open');
});

/* ── Painel Alertas e lembretes ── */
function _buildAlertas() {
  const c    = _colab;
  const HOJE = new Date(); HOJE.setHours(0,0,0,0);
  const alertas = [];

  /* Processos abertos */
  if (_processosAbertos.length) {
    const n = _processosAbertos.length;
    alertas.push({ cor:'amber', txt: `${n} processo${n>1?'s':''} aberto${n>1?'s':''} em andamento` });
  }

  /* Em período de experiência */
  if (c.em_experiencia) {
    alertas.push({ cor:'amber', txt:'Em período de experiência' });
  }

  /* Férias vencendo: fim do período concessivo < 60 dias */
  _ferias.forEach(pa => {
    if (!pa.pa_fim || pa.status === 'cancelado') return;
    const fim = new Date(pa.pa_fim + 'T00:00:00'); fim.setHours(0,0,0,0);
    const diasFim = Math.ceil((fim - HOJE) / 86400000);
    const totalDias = pa.total_dias || 30;
    let usado = 0;
    buildLancamentos(pa).forEach(l => { if (l.dias) usado += Number(l.dias); });
    const saldo = totalDias - usado - (pa.dias_antecipados||0) - (pa.abono_pecuniario||0);
    if (saldo > 0 && diasFim >= 0 && diasFim < 60)
      alertas.push({ cor:'warn', txt:`Férias vencendo em ${diasFim} dia${diasFim!==1?'s':''} — ${saldo} dias de saldo` });
  });

  /* Próximas férias agendadas: início futuro ≤ 90 dias */
  _ferias.forEach(pa => {
    buildLancamentos(pa).forEach(l => {
      if (!l.inicio) return;
      const ini = new Date(l.inicio + 'T00:00:00'); ini.setHours(0,0,0,0);
      const d = Math.ceil((ini - HOJE) / 86400000);
      if (d > 0 && d <= 90)
        alertas.push({ cor:'info', txt:`Férias agendadas em ${d} dia${d!==1?'s':''} — ${fd(l.inicio)}` });
    });
  });

  /* Aniversário ≤ 30 dias */
  if (c.data_nascimento) {
    const nasc = new Date(c.data_nascimento + 'T00:00:00');
    const aniv = new Date(HOJE.getFullYear(), nasc.getMonth(), nasc.getDate());
    if (aniv < HOJE) aniv.setFullYear(aniv.getFullYear() + 1);
    const d = Math.ceil((aniv - HOJE) / 86400000);
    if (d <= 30)
      alertas.push({ cor:'info', txt: d === 0 ? 'Aniversário hoje!' : `Aniversário em ${d} dia${d!==1?'s':''}` });
  }

  if (!alertas.length)
    alertas.push({ cor:'ok', txt:'Tudo em dia' });

  return `<div class="hero-alertas-title">Alertas e lembretes</div>` +
    alertas.map(a =>
      `<div class="hero-alerta-item"><div class="hero-alerta-dot ${a.cor}"></div><span>${a.txt}</span></div>`
    ).join('');
}

/* ── Resumo ── */
function renderResumo() {
  const c = _colab;
  const vinculoLabel = c.tipo_vinculo ? (_VINCULO_LABEL[c.tipo_vinculo] || c.tipo_vinculo) : null;

  // saldo total de férias pendente
  const HOJE = new Date().toISOString().slice(0,10);
  let saldoPendente = 0;
  _ferias.forEach(pa => {
    const totalDias = pa.total_dias || 30;
    let usado = 0;
    const lancs = buildLancamentos(pa);
    lancs.forEach(l => { if (l.dias) usado += Number(l.dias); });
    const saldo = totalDias - usado - (pa.dias_antecipados||0) - (pa.abono_pecuniario||0);
    if (saldo > 0 && pa.status !== 'cancelado') saldoPendente += saldo;
  });

  // última avaliação
  let mediaUlt = null, nomeUltCiclo = '';
  if (_avaliacoes.length && _ciclos.length) {
    const ult = _avaliacoes[0];
    const ciclo = _ciclos.find(c => c.id === ult.ciclo_id);
    nomeUltCiclo = ciclo ? ciclo.nome : '';
    const notas = Object.values(ult.notas_gestor||{}).concat(Object.values(ult.notas_auto||{}));
    const vals  = notas.map(Number).filter(n=>n>0);
    if (vals.length) mediaUlt = (vals.reduce((a,b)=>a+b,0)/vals.length).toFixed(1);
  }

  document.getElementById('resumoCards').innerHTML = `
    <div class="rcard c-blue">
      <div class="rcard-label">Tempo de casa</div>
      <div class="rcard-val blue" style="font-size:20px;margin-top:6px">${tempoStr(c.data_admissao)}</div>
      <div class="rcard-sub">desde ${fd(c.data_admissao)}</div>
    </div>
    <div class="rcard c-amber">
      <div class="rcard-label">Saldo de férias</div>
      <div class="rcard-val amber">${saldoPendente}</div>
      <div class="rcard-sub">${saldoPendente===1?'dia pendente':'dias pendentes'}</div>
    </div>
    <div class="rcard c-purple">
      <div class="rcard-label">Última avaliação</div>
      <div class="rcard-val purple">${mediaUlt||'—'}</div>
      <div class="rcard-sub">${nomeUltCiclo||'Nenhuma avaliação'}</div>
    </div>
    <div class="rcard c-green">
      <div class="rcard-label">Ciclos avaliados</div>
      <div class="rcard-val green">${_avaliacoes.length}</div>
      <div class="rcard-sub">${_avaliacoes.length===1?'ciclo':'ciclos'}</div>
    </div>`;

  document.getElementById('resumoInfo').innerHTML = `
    <div class="info-card">
      <div class="info-card-title">Dados Pessoais</div>
      ${infoRow('CPF', c.cpf)}
      ${infoRow('RG', c.rg)}
      ${infoRow('Data de nascimento', fd(c.data_nascimento))}
      ${infoRow('Naturalidade', c.naturalidade)}
      ${infoRow('Estado civil', c.estado_civil)}
      ${infoRow('Escolaridade', c.escolaridade)}
    </div>
    <div class="info-card">
      <div class="info-card-title">Dados Profissionais</div>
      ${infoRow('Matrícula', c.matricula)}
      ${infoRow('Cargo', c.cargo)}
      ${infoRow('Setor', c.setor)}
      ${infoRow('Empresa de registro', c.empresa_registro_nome || c.empresa_registro)}
      ${infoRow('Unidade de atuação', c.empresa_atuacao_nome || c.empresa_atuacao)}
      ${infoRow('Tipo de vínculo', vinculoLabel)}
      ${infoRow('Gestor', c.gestor)}
      ${infoRow('Admissão', fd(c.data_admissao))}
      ${infoRow('Ingresso no Grupo', fd(c.data_ingresso_grupo))}
      ${infoRow('Tipo de contrato', c.tipo_contrato)}
      ${infoRow('Regime de horas', c.regime_horas)}
      ${c.data_demissao ? infoRow('Desligamento', fd(c.data_demissao)) : ''}
    </div>`;
}

function infoRow(label, val) {
  if (!val || val === '—') return '';
  return `<div class="info-row"><label>${label}</label><span>${val}</span></div>`;
}

/* helper compartilhado: badge colorido de motivo de reajuste */
function _motivoBadge(cod, label) {
  if (!label) return '';
  const c = String(cod || '');
  let bg, txt;
  if (c === '0.2') { bg = '#ECFDF3'; txt = '#027A48'; }       // Promoção
  else if (c === '0.1') { bg = '#EFF4FF'; txt = '#1849A9'; }  // Mérito
  else if (c === '0.3' || c === '0.5') { bg = '#FFFAEB'; txt = '#92400E'; } // Dissídio/Acordo
  else if (c === '0.4') { bg = '#F4F3FF'; txt = '#5925DC'; }  // Equiparação
  else if (c === '0.6') { bg = '#F0F9FF'; txt = '#026AA2'; }  // Enquadramento
  else { bg = '#F2F4F7'; txt = '#344054'; }
  return `<span class="tl-motivo-badge" style="background:${bg};color:${txt}">${label}</span>`;
}

/* ── Carreira ── */
function renderCarreira() {
  const el = document.getElementById('carreiraContent');
  const eventos = [];

  // Cargo de admissão: inferido do cargo_anterior do registro mais antigo em
  // historico_remuneracao que tenha mudança de cargo. Evita mostrar o cargo atual
  // (pós-promoção) como cargo de entrada.
  // _historicoRemuneracao está ordenado DESC → o último é o mais antigo.
  let cargoAdmissao = _colab.cargo || 'colaborador';
  const comCargo = _historicoRemuneracao.filter(h => h.cargo_novo && h.cargo_anterior);
  if (comCargo.length) {
    cargoAdmissao = comCargo[comCargo.length - 1].cargo_anterior || cargoAdmissao;
  }

  // Admissão sintética
  if (_colab.data_admissao) {
    eventos.push({
      data: _colab.data_admissao,
      tipo: 'admissao',
      titulo: `Admitido como ${cargoAdmissao}`,
      descricao: [_colab.empresa_registro_nome, _colab.setor].filter(Boolean).join(' · '),
    });
  }

  // Mudanças de cargo via historico_remuneracao (fonte primária e mais confiável)
  _historicoRemuneracao.forEach(h => {
    if (!h.cargo_novo) return;
    eventos.push({
      data: h.data_vigencia,
      tipo: 'promocao',
      titulo: `Promovido para ${h.cargo_novo}`,
      cargo_anterior: h.cargo_anterior || null,
      motivo_codigo: h.motivo_codigo || null,
      motivo_descricao: h.motivo_descricao || null,
    });
  });

  // Transferências de unidade/CNPJ (de _processosConcluidos — sem representação em historico_remuneracao)
  _processosConcluidos.forEach(p => {
    const dx = p.dados_extras || {};
    if (p.tipo === 'transferencia_cnpj' || p.tipo === 'transferencia') {
      const dataEvt = dx.data_transferencia || (p.concluido_em || p.created_at || '').slice(0, 10);
      eventos.push({
        data: dataEvt,
        tipo: 'pdi',
        titulo: 'Transferência',
        descricao: [dx.empresa_origem, dx.empresa_destino].filter(Boolean).join(' → ') || dx.motivo || '',
      });
    }
  });

  eventos.sort((a, b) => (b.data || '').localeCompare(a.data || ''));

  if (!eventos.length) {
    el.innerHTML = `<div class="empty-state"><p>Nenhum evento de carreira registrado.</p></div>`;
    return;
  }

  const ICONS = {
    admissao: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><polyline points="17 11 19 13 23 9"/></svg>`,
    promocao: `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 11 12 6 7 11"/><polyline points="17 18 12 13 7 18"/></svg>`,
    pdi:      `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>`,
  };

  el.innerHTML = `<div class="timeline">${eventos.map(e => {
    const tipo = e.tipo || 'geral';
    const icon = ICONS[tipo] || ICONS.pdi;
    const descHtml = [
      e.cargo_anterior ? `De: ${e.cargo_anterior}` : '',
      e.motivo_descricao ? _motivoBadge(e.motivo_codigo, e.motivo_descricao) : '',
      e.descricao || '',
    ].filter(Boolean).join(' · ');
    return `<div class="tl-item">
      <div class="tl-dot ${tipo}">${icon}</div>
      <div class="tl-content">
        <div class="tl-titulo">${e.titulo || '—'}</div>
        ${descHtml ? `<div class="tl-desc">${descHtml}</div>` : ''}
        <div class="tl-date">${fd(e.data)}</div>
      </div>
    </div>`;
  }).join('')}</div>`;
}

/* ── Financeiro ── */
function renderFinanceiro() {
  const el = document.getElementById('financeiroContent');

  if (!_historicoRemuneracao.length) {
    el.innerHTML = `<div class="empty-state"><p>Nenhum reajuste salarial registrado.</p></div>`;
    return;
  }

  function fBRL(v) {
    if (v == null || v === '') return null;
    return Number(v).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
  }

  const hoje = new Date().toISOString().slice(0, 10);

  // Paleta por código de motivo (alinhada com param_motivo_reajuste)
  function _motivoCfg(cod) {
    const c = String(cod || '');
    if (c === '0.2') return { border: '#12B76A', bg: '#ECFDF3', txt: '#027A48' }; // Promoção
    if (c === '0.1') return { border: '#1849A9', bg: '#EFF4FF', txt: '#1849A9' }; // Mérito
    if (c === '0.3' || c === '0.5') return { border: '#F79009', bg: '#FFFAEB', txt: '#92400E' }; // Dissídio/Acordo
    if (c === '0.4') return { border: '#5925DC', bg: '#F4F3FF', txt: '#5925DC' }; // Equiparação
    if (c === '0.6') return { border: '#026AA2', bg: '#F0F9FF', txt: '#026AA2' }; // Enquadramento
    return { border: '#667085', bg: '#F9FAFB', txt: '#344054' };
  }

  el.innerHTML = `<div class="fin-list">${_historicoRemuneracao.map(h => {
    const novo     = fBRL(h.salario_novo);
    const ant      = fBRL(h.salario_anterior);
    const aplicado = !!(h.aplicado_em || h.data_vigencia <= hoje);
    const cor      = _motivoCfg(h.motivo_codigo);
    const motivoLabel = h.motivo_descricao || 'Reajuste salarial';

    const pctNum = h.percentual != null ? Number(h.percentual) : null;
    const pctStr = pctNum != null
      ? `${pctNum > 0 ? '+' : ''}${pctNum.toFixed(2).replace('.', ',')}%`
      : null;

    const statusHtml = aplicado
      ? `<span class="fin-status ok">✓ Aplicado</span>`
      : `<span class="fin-status pend">⏳ Pendente</span>`;

    // Linha de valores: De R$ X → R$ Y  +12%
    const salDeHtml = ant ? `<span class="fin-sal-de">${ant}</span><span class="fin-sal-sep">→</span>` : '';
    const salPctHtml = pctStr ? `<span class="fin-pct-badge ${pctNum >= 0 ? 'pos' : 'neg'}">${pctStr}</span>` : '';

    // Linha de cargo
    const cargoHtml = h.cargo_novo
      ? `<div class="fin-cargo-row">
          ${h.cargo_anterior ? `<span class="fin-cargo-de">${h.cargo_anterior}</span><span class="fin-cargo-sep">→</span>` : ''}
          <span class="fin-cargo-novo">${h.cargo_novo}</span>
        </div>`
      : '';

    const obsHtml = h.observacao
      ? `<div class="fin-obs">${h.observacao}</div>`
      : '';

    return `<div class="fin-card" style="border-left-color:${cor.border}">
      <div class="fin-card-top">
        <span class="fin-motivo-tag" style="background:${cor.bg};color:${cor.txt}">${motivoLabel}</span>
        ${statusHtml}
      </div>
      <div class="fin-values-row">${salDeHtml}<span class="fin-sal-novo">${novo || '—'}</span>${salPctHtml}</div>
      ${cargoHtml}${obsHtml}
      <div class="fin-footer">
        <span class="fin-vigencia">Vigência: <strong>${fd(h.data_vigencia)}</strong></span>
        ${h.registrado_por ? `<span class="fin-by">por ${h.registrado_por}</span>` : ''}
      </div>
    </div>`;
  }).join('')}</div>`;
}

/* ── Férias ── */
function renderFerias() {
  const el = document.getElementById('feriasContent');
  if (!_ferias.length) {
    el.innerHTML = `<div class="empty-state"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.5"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg><p>Nenhum período aquisitivo encontrado.</p></div>`;
    return;
  }
  const HOJE = new Date().toISOString().slice(0,10);
  el.innerHTML = _ferias.map(pa => {
    const totalDias = pa.total_dias || 30;
    const lancs = buildLancamentos(pa);
    let usado = 0;
    lancs.forEach(l => { if (l.dias) usado += Number(l.dias); });
    const saldo = totalDias - usado - (pa.dias_antecipados||0) - (pa.abono_pecuniario||0);
    const saldoCls = saldo > 15 ? 'saldo-ok' : saldo > 0 ? 'saldo-warn' : 'saldo-crit';

    const lancsHtml = lancs.length ? lancs.map(l => {
      const dot = l.fim && l.fim < HOJE ? '' : (l.inicio && l.inicio > HOJE ? 'fut' : 'pen');
      return `<div class="ferias-lanc-item">
        <div class="ferias-lanc-dot ${dot}"></div>
        <span>${fd(l.inicio)} → ${fd(l.fim)}</span>
        <span style="color:var(--text-sec)">${l.dias||'?'} dias</span>
        ${l.status ? `<span style="color:var(--text-ter);font-size:11px">${l.status}</span>` : ''}
      </div>`;
    }).join('') : `<div style="font-size:12px;color:var(--text-ter);padding:4px 0">Sem lançamentos</div>`;

    return `<div class="ferias-pa">
      <div class="ferias-pa-header">
        <div>
          <div class="ferias-pa-ano">Período ${pa.ano||'—'}</div>
          <div class="ferias-pa-datas">${fd(pa.pa_inicio)} → ${fd(pa.pa_fim)}</div>
        </div>
        <span class="saldo-badge ${saldoCls}">${saldo} dia${saldo!==1?'s':''} de saldo</span>
      </div>
      <div class="ferias-lanc">${lancsHtml}</div>
    </div>`;
  }).join('');
}

/* ── Desenvolvimento ── */
function renderDesenvolvimento() {
  const el = document.getElementById('devContent');
  if (!_avaliacoes.length && !_pdi.length) {
    el.innerHTML = `<div class="empty-state"><svg viewBox="0 0 24 24" fill="none" stroke-width="1.5"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/></svg><p>Nenhuma avaliação ou PDI registrado.</p></div>`;
    return;
  }
  const LABELS = ['','Insatisfatório','Em desenvolvimento','Dentro do esperado','Acima do esperado','Referência'];
  const N_CLS  = ['','n1','n2','n3','n4','n5'];

  let html = '';

  // avaliacoes por ciclo
  _avaliacoes.forEach(av => {
    const ciclo = _ciclos.find(c => c.id === av.ciclo_id);
    const nomeCiclo = ciclo ? ciclo.nome : `Ciclo ${av.ciclo_id}`;
    const notas = { ...av.notas_gestor, ...av.notas_auto };
    const vals  = Object.values(notas).map(Number).filter(n=>n>0);
    const media = vals.length ? (vals.reduce((a,b)=>a+b,0)/vals.length).toFixed(1) : null;
    const mediaCls = media ? (parseFloat(media)>=4.5?'n5':parseFloat(media)>=3.5?'n4':parseFloat(media)>=2.5?'n3':parseFloat(media)>=1.5?'n2':'n1') : '';

    const notasChips = Object.entries(notas).map(([id,n]) => {
      const ni = parseInt(n);
      if (!ni) return '';
      return `<span class="nota-chip ${N_CLS[ni]}">${LABELS[ni]} (${ni})</span>`;
    }).filter(Boolean).join('');

    html += `<div class="av-ciclo-bloco">
      <div class="av-ciclo-header">
        <div class="av-ciclo-nome">${nomeCiclo}</div>
        ${media ? `<span class="media-grande ${mediaCls}" style="font-size:24px">${media}</span>` : ''}
      </div>
      ${notasChips ? `<div class="av-notas-grid">${notasChips}</div>` : '<p style="font-size:12px;color:var(--text-ter)">Avaliação sem notas preenchidas.</p>'}
      ${av.obs_auto ? `<p style="font-size:12px;color:var(--text-sec);margin-top:8px;padding-top:8px;border-top:1px solid var(--border-light)">"${av.obs_auto}"</p>` : ''}
    </div>`;
  });

  // PDI
  const pdiRec = _pdi[0];
  if (pdiRec && pdiRec.acoes && pdiRec.acoes.length) {
    const acoes = pdiRec.acoes;
    const total = acoes.length;
    const feitas = acoes.filter(a=>a.done).length;
    html += `<div class="av-ciclo-bloco">
      <div class="av-ciclo-header">
        <div class="av-ciclo-nome">PDI — Plano de Desenvolvimento</div>
        <span style="font-size:12px;color:var(--text-sec)">${feitas}/${total} concluídas</span>
      </div>
      <div class="pdi-resumo">
        ${acoes.map(a=>`<div class="pdi-resumo-item ${a.done?'done':''}">
          <div class="pdi-check-ico ${a.done?'ok':'pend'}">${a.done?`<svg viewBox="0 0 10 10" fill="none"><polyline points="2,5 4,7.5 8,2.5" stroke="#fff" stroke-width="2"/></svg>`:''}</div>
          <span>${a.acao}</span>
          ${a.prazo?`<span style="color:var(--text-ter);font-size:11px;margin-left:auto">até ${fd(a.prazo)}</span>`:''}
        </div>`).join('')}
      </div>
    </div>`;
  }

  el.innerHTML = html || `<div class="empty-state"><p>Sem dados de desenvolvimento.</p></div>`;
}

/* ── Histórico ── */
function renderHistorico() {
  const el = document.getElementById('histContent');

  // montar eventos: dev_historico + sintetizados de férias + admissão
  const eventos = [..._historico];

  // adicionar admissão se não existe já em historico_eventos
  // cargo de admissão: usa cargo_anterior do reajuste mais antigo com mudança de cargo
  if (_colab.data_admissao && !_tiposEmEventos.has('admissao') && !eventos.some(e=>e.tipo==='admissao')) {
    let _cargoAdm = _colab.cargo || 'colaborador';
    const _comCargo = _historicoRemuneracao.filter(h => h.cargo_novo && h.cargo_anterior);
    if (_comCargo.length) _cargoAdm = _comCargo[_comCargo.length - 1].cargo_anterior || _cargoAdm;
    eventos.push({
      data: _colab.data_admissao,
      tipo: 'admissao',
      titulo: `Admitido como ${_cargoAdm}`,
      descricao: [_colab.empresa_registro_nome, _colab.setor].filter(Boolean).join(' · '),
    });
  }

  // adicionar todos os eventos de historico_eventos (fonte canônica para qualquer tipo)
  const _processosEmEventos = new Set();
  const _tiposEmEventos = new Set();
  _historicoEventos.forEach(ev => {
    if (ev.processo_id) _processosEmEventos.add(ev.processo_id);
    _tiposEmEventos.add(ev.tipo);
    const meta = _tiposEvento[ev.tipo] || {};
    const d = ev.dados || {};
    eventos.push({
      data: ev.data_evento,
      tipo: ev.tipo,
      titulo: ev.titulo,
      descricao: ev.resumo || '',
      cargo_anterior: d.cargo_anterior || null,
      motivo_codigo: d.motivo_codigo || null,
      motivo_descricao: d.motivo_descricao || null,
      processo_id: ev.processo_id,
      registrado_por: ev.registrado_por || null,
      _iconeChave: meta.icone_chave || null,
      _corHex: meta.cor_hex || null,
    });
  });

  // sintetiza promoções de _historicoRemuneracao somente para processos ainda não cobertos
  _historicoRemuneracao.forEach(h => {
    if (!h.cargo_novo) return;
    const dataEvt = h.data_vigencia || (h.created_at || '').slice(0, 10);
    if (h.processo_id && _processosEmEventos.has(h.processo_id)) return;
    if (h.processo_id && eventos.some(e => e.processo_id === h.processo_id)) return;
    eventos.push({
      data: dataEvt,
      tipo: 'promocao',
      titulo: `Promovido para ${h.cargo_novo}`,
      cargo_anterior: h.cargo_anterior || null,
      motivo_codigo: h.motivo_codigo || null,
      motivo_descricao: h.motivo_descricao || null,
      processo_id: h.processo_id,
    });
  });

  // adicionar desligamento se não existe já em historico_eventos
  if (_colab.data_demissao && !_tiposEmEventos.has('demissao') && !eventos.some(e=>e.tipo==='desligamento')) {
    eventos.push({
      data: _colab.data_demissao,
      tipo: 'desligamento',
      titulo: 'Desligamento',
      descricao: _colab.motivo_desligamento || '',
    });
  }

  // adicionar férias gozadas — usa buildLancamentos para compatibilidade com o schema real
  _ferias.forEach(pa => {
    const HOJE = new Date().toISOString().slice(0,10);
    buildLancamentos(pa).forEach(l => {
      if (l.status === 'concluido' || l.status === 'gozado' || (l.fim && l.fim < HOJE)) {
        eventos.push({
          data: l.inicio,
          tipo: 'ferias',
          titulo: `Férias gozadas — PA ${pa.ano}`,
          descricao: `${fd(l.inicio)} → ${fd(l.fim)} · ${l.dias||'?'} dias`,
        });
      }
    });
  });

  // adicionar avaliações
  _avaliacoes.forEach(av => {
    const ciclo = _ciclos.find(c=>c.id===av.ciclo_id);
    const notas = Object.values({...av.notas_gestor,...av.notas_auto}).map(Number).filter(n=>n>0);
    const media = notas.length ? (notas.reduce((a,b)=>a+b,0)/notas.length).toFixed(1) : null;
    eventos.push({
      data: av.updated_at ? av.updated_at.slice(0,10) : av.created_at?.slice(0,10),
      tipo: 'avaliacao',
      titulo: ciclo ? ciclo.nome : 'Avaliação de desempenho',
      descricao: media ? `Média: ${media}` : 'Avaliação sem notas',
    });
  });

  // ordenar decrescente
  eventos.sort((a,b) => (b.data||'').localeCompare(a.data||''));

  if (!eventos.length) {
    el.innerHTML = `<div class="empty-state"><p>Nenhum evento registrado na linha do tempo.</p></div>`;
    return;
  }

  // Ícones indexados por icone_chave (valor de tipos_evento.icone_chave)
  // Tipos sintéticos (admissao, ferias, etc.) usam o mesmo índice via chave arbitrária
  const ICONS = {
    'user-check':   `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><polyline points="17 11 19 13 23 9"/></svg>`,
    'calendar':     `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>`,
    'star':         `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>`,
    'check-square': `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 11 12 14 22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg>`,
    'x-circle':     `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`,
    'chevrons-up':  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 11 12 6 7 11"/><polyline points="17 18 12 13 7 18"/></svg>`,
    'trending-up':  `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>`,
    'building':     `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18M15 3v18M3 9h18M3 15h18"/></svg>`,
    'bus':          `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M8 6v6m8-6v6M3 16h18M3 8a5 5 0 0 1 5-5h8a5 5 0 0 1 5 5v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8z"/><circle cx="7.5" cy="18.5" r="1.5"/><circle cx="16.5" cy="18.5" r="1.5"/></svg>`,
    'clock':        `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>`,
    'shirt':        `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20.38 3.46 16 2a4 4 0 0 1-8 0L3.62 3.46a2 2 0 0 0-1.34 2.23l.58 3.57a1 1 0 0 0 .99.84H6v10c0 1.1.9 2 2 2h8a2 2 0 0 0 2-2V10h2.15a1 1 0 0 0 .99-.84l.58-3.57a2 2 0 0 0-1.34-2.23z"/></svg>`,
    'circle':       `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><circle cx="12" cy="12" r="4"/></svg>`,
  };

  // Mapa tipo-sintético → icone_chave (para tipos que não vêm de tipos_evento)
  const TIPO_ICONE = {
    admissao: 'user-check', ferias: 'calendar', avaliacao: 'star',
    pdi: 'check-square', desligamento: 'x-circle', geral: 'circle',
  };

  el.innerHTML = `<div class="timeline">${eventos.map(e=>{
    const tipo = e.tipo||'geral';
    // ícone: usa icone_chave do evento (vindo de _tiposEvento) ou do mapa de tipos sintéticos
    const chave = e._iconeChave || TIPO_ICONE[tipo] || 'circle';
    const icon = ICONS[chave] || ICONS['circle'];
    // cor: usa cor_hex do evento (vindo de _tiposEvento) — se ausente, cai no CSS class
    const dotStyle = e._corHex
      ? `style="border-color:${e._corHex};background:${e._corHex}18"`
      : '';
    const dotClass = e._corHex ? '' : tipo;
    const descHtml = e.motivo_descricao
      ? [
          e.cargo_anterior ? `De: ${e.cargo_anterior}` : '',
          _motivoBadge(e.motivo_codigo, e.motivo_descricao),
          e.descricao || '',
        ].filter(Boolean).join(' · ')
      : (e.descricao || '');
    return `<div class="tl-item">
      <div class="tl-dot ${dotClass}" ${dotStyle}>${icon}</div>
      <div class="tl-content">
        <div class="tl-titulo">${e.titulo||'—'}</div>
        ${descHtml?`<div class="tl-desc">${descHtml}</div>`:''}
        <div class="tl-date">${fd(e.data)}${(e.created_by||e.registrado_por)?' · '+(e.created_by||e.registrado_por):''}</div>
      </div>
    </div>`;
  }).join('')}</div>`;
}
