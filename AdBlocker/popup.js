'use strict';

const toggleInput  = document.getElementById('toggle-input');
const counterNum   = document.getElementById('counter-num');
const resetBtn     = document.getElementById('reset-btn');
const statusLine   = document.getElementById('status-line');
const toggleLabel  = document.getElementById('toggle-label');

// ---- State vom Background laden ----
browser.runtime.sendMessage({ type: 'GET_STATE' }).then(state => {
  toggleInput.checked = state.enabled;
  counterNum.textContent = state.blockedCount;
  updateStatus(state.enabled);
}).catch(() => {
  // Background nicht erreichbar
});

// ---- Toggle ----
toggleInput.addEventListener('change', () => {
  const val = toggleInput.checked;
  browser.runtime.sendMessage({ type: 'SET_ENABLED', value: val });
  updateStatus(val);
});

// ---- Zähler zurücksetzen ----
resetBtn.addEventListener('click', () => {
  browser.runtime.sendMessage({ type: 'RESET_COUNTER' }).then(() => {
    counterNum.textContent = '0';
  });
});

// ---- Status-Anzeige aktualisieren ----
function updateStatus(active) {
  if (active) {
    statusLine.textContent = 'Schutz aktiv';
    statusLine.className   = 'active';
    toggleLabel.textContent = 'Aktiv';
  } else {
    statusLine.textContent = 'Schutz deaktiviert';
    statusLine.className   = 'inactive';
    toggleLabel.textContent = 'Inaktiv';
  }
}
