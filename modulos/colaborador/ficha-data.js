/* ── Supabase — mesmo padrão do Cadastro ── */
const SB_URL = 'https://rujtbxwssiofiialnbbg.supabase.co';
const SB_KEY = 'sb_publishable_V4jUw9qvHjN9LvncGunqNQ_o_dj0RdH';
let SB_HEADERS = {};

async function _sbRefreshSession() {
  try {
    const sess = JSON.parse(localStorage.getItem('sb_session') || '{}');
    if (!sess.refresh_token) return false;
    const r = await fetch(`${SB_URL}/auth/v1/token?grant_type=refresh_token`, {
      method: 'POST',
      headers: { apikey: SB_KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({ refresh_token: sess.refresh_token }),
    });
    if (!r.ok) return false;
    const data = await r.json();
    if (!data.access_token) return false;
    const newSess = { ...sess, access_token: data.access_token, refresh_token: data.refresh_token || sess.refresh_token, expires_at: Date.now() + (data.expires_in || 3600) * 1000 };
    localStorage.setItem('sb_session', JSON.stringify(newSess));
    SB_HEADERS = { ...SB_HEADERS, Authorization: `Bearer ${data.access_token}` };
    return true;
  } catch { return false; }
}

async function sbGet(path) {
  let r = await fetch(SB_URL + path, { headers: SB_HEADERS });
  if (r.ok) return r.json();
  const txt = await r.text().catch(() => '');
  if (r.status === 401 || txt.includes('JWT expired') || txt.includes('PGRST303')) {
    if (await _sbRefreshSession()) {
      r = await fetch(SB_URL + path, { headers: SB_HEADERS });
      if (r.ok) return r.json();
    }
    localStorage.removeItem('sb_session');
    localStorage.removeItem('sb_perfil');
    window.location.href = '../../login.html';
    return [];
  }
  return [];
}

/* ── Auth ── */
function logout() {
  localStorage.removeItem('sb_session');
  localStorage.removeItem('sb_perfil');
  window.location.href = '../../login.html';
}

/* ── URL params ── */
function getParam(k) { return new URLSearchParams(window.location.search).get(k); }

/* ── Dados ── */
let _colab = null, _ferias = [], _avaliacoes = [], _ciclos = [], _pdi = [], _historico = [];

/* ── Helpers ferias ── */
function addDays(dateStr, days) {
  const d = new Date(dateStr + 'T00:00:00');
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}
function buildLancamentos(pa) {
  const lancs = [];
  if (pa.periodo1_inicio && pa.dias1) {
    const d = Number(pa.dias1);
    lancs.push({ inicio: pa.periodo1_inicio, fim: addDays(pa.periodo1_inicio, d - 1), dias: d, status: pa.status1 || null });
  }
  if (pa.periodo2_inicio && pa.dias2) {
    const d = Number(pa.dias2);
    lancs.push({ inicio: pa.periodo2_inicio, fim: addDays(pa.periodo2_inicio, d - 1), dias: d, status: pa.status2 || null });
  }
  (pa.realizacoes || []).forEach(r => {
    const ini = r.inicio || r.saida;
    if (ini && Number(r.dias) > 0)
      lancs.push({ inicio: ini, fim: r.fim || r.retorno || ini, dias: Number(r.dias), status: (r.status || 'gozado').toLowerCase() });
  });
  return lancs;
}

/* ── Formatação ── */
function fd(d) {
  if (!d) return '—';
  const [y,m,day] = d.split('-');
  return `${day}/${m}/${y}`;
}
function diasEntre(d1, d2) {
  if (!d1||!d2) return null;
  return Math.round((new Date(d2)-new Date(d1))/(1000*60*60*24));
}
function tempoStr(dataAdm) {
  if (!dataAdm) return '—';
  const ms = Date.now() - new Date(dataAdm).getTime();
  const dias = Math.floor(ms/(1000*60*60*24));
  if (dias < 30)  return `${dias} dia${dias!==1?'s':''}`;
  const meses = Math.floor(dias/30.4);
  if (meses < 12) return `${meses} mês${meses!==1?'es':''}`;
  const anos  = Math.floor(meses/12);
  const rm    = meses % 12;
  return rm > 0 ? `${anos} ano${anos!==1?'s':''} e ${rm} mês${rm!==1?'es':''}` : `${anos} ano${anos!==1?'s':''}`;
}

/* ── Init ── */
async function init() {
  const paramId        = getParam('id');
  const paramMatricula = getParam('matricula');
  if (!paramId && !paramMatricula) { mostrarErro('Colaborador não informado.'); return; }

  const ref = document.referrer;
  document.getElementById('btnVoltar').href = ref && ref.includes('SistemaRH') ? ref : '../../index.html';

  // Passo 1 — identificar o colaborador
  const filtro = paramId
    ? `id=eq.${encodeURIComponent(paramId)}`
    : `matricula=eq.${encodeURIComponent(paramMatricula)}`;
  const colabs = await sbGet(`/rest/v1/colaboradores?${filtro}&limit=1`);
  if (!colabs || !colabs.length) {
    mostrarErro('Colaborador não encontrado.');
    return;
  }
  _colab = colabs[0];

  // Passo 2 — buscar dados relacionados com as chaves corretas de cada tabela
  const colabId  = _colab.id;
  const matricula = _colab.matricula;

  const [ferias, avaliacoes, ciclos, pdi, hist] = await Promise.all([
    sbGet(`/rest/v1/ferias?colaborador_id=eq.${colabId}&order=ano.desc`),
    matricula ? sbGet(`/rest/v1/dev_avaliacoes?matricula_colaborador=eq.${encodeURIComponent(matricula)}&select=*`) : Promise.resolve([]),
    sbGet('/rest/v1/dev_ciclos?order=created_at.desc'),
    matricula ? sbGet(`/rest/v1/dev_pdi?matricula_colaborador=eq.${encodeURIComponent(matricula)}&select=*`) : Promise.resolve([]),
    matricula ? sbGet(`/rest/v1/dev_historico?matricula_colaborador=eq.${encodeURIComponent(matricula)}&order=data.desc&limit=100`) : Promise.resolve([]),
  ]);

  _ferias      = ferias || [];
  _avaliacoes  = avaliacoes || [];
  _ciclos      = ciclos || [];
  _pdi         = pdi || [];
  _historico   = hist || [];

  renderHero();
  renderResumo();

  document.getElementById('mainContainer').style.display = 'none';
  document.getElementById('heroArea').style.display = '';
  document.getElementById('tabsArea').style.display = '';
  document.getElementById('tabContent').style.display = '';
}

function mostrarErro(msg) {
  document.getElementById('mainContainer').innerHTML = `
    <div class="empty-state" style="padding:80px 24px">
      <svg viewBox="0 0 24 24" fill="none" stroke-width="1.5"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>
      <p style="font-size:15px;font-weight:600;margin-bottom:6px">${msg}</p>
      <p><a href="../../index.html" style="color:var(--blue)">Voltar ao início</a></p>
    </div>`;
}
