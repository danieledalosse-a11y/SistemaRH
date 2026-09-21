// permissoes.js — carregado no login, lido localmente (zero chamadas de rede nos módulos)
const _PERM = (() => {
  try { return JSON.parse(localStorage.getItem('sb_permissoes') || '{}'); }
  catch { return {}; }
})();

// {} no módulo = sem restrição (admin). Ausência da aba/ação na lista = bloqueado.
function podeAba(modulo, aba) {
  if (!_PERM[modulo]) return true;
  const abas = _PERM[modulo].abas;
  return !abas || abas.includes(aba);
}

function podeAcao(modulo, acao) {
  if (!_PERM[modulo]) return true;
  const acoes = _PERM[modulo].acoes;
  return !acoes || acoes.includes(acao);
}

// Verifica autenticação + autorização ao módulo.
// Redireciona para login.html se não autenticado/expirado.
// Redireciona para index.html se autenticado mas sem acesso ao módulo.
// Admin sempre passa. Qualquer outro perfil precisa ter 'chave' em acesso_modulos.
function guardModulo(chave) {
  const sessRaw = localStorage.getItem('sb_session');
  if (!sessRaw) { window.location.href = '../../login.html'; return false; }
  try {
    const s = JSON.parse(sessRaw);
    if (s.expires_at < Date.now()) {
      localStorage.clear();
      window.location.href = '../../login.html';
      return false;
    }
    const p = JSON.parse(localStorage.getItem('sb_perfil') || '{}');
    if ((p.perfil || '') === 'admin') return true;
    const acesso = Array.isArray(p.acesso_modulos) ? p.acesso_modulos : [];
    if (acesso.includes(chave)) return true;
    window.location.href = '../../index.html';
    return false;
  } catch(_) {
    window.location.href = '../../login.html';
    return false;
  }
}
