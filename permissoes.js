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
