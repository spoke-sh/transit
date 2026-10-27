const SCREENS = {
  'macro-map': {
    label: 'Active Study: Figure 1 — Macro World Map, Faction Archipelago & Anchored Protocol Apps',
    mode: 'Seed #8841-IRON-TIDE · Macro View (1.0×)',
  },
  'faction-archeology': {
    label: 'Active Study: Figure 2 — Computing Factions & Software Archeology Across Geological Strata',
    mode: 'Seed #8841-IRON-TIDE · Archeology Lens',
  },
  'simready-dock': {
    label: 'Active Study: Figure 3 — Meso Isometric Facility Populated with nvidia/simready-assets',
    mode: 'Sector 04 Dock · SimReady USD View (12×)',
  },
  'agent-pov': {
    label: 'Active Study: Figure 4 — Micro First-Person Agent POV, Counterfactual Branches & Manual Takeover',
    mode: 'Possessed: Forklift-07 (PID 204 · Zoom 100×)',
  },
  'modernization-loop': {
    label: 'Active Study: Figure 5 — Non-Stop Modernization Optimization Workbench & Fault-Injection Proof',
    mode: 'Corridor Optimization · 100× Headless CI',
  },
  'mmo-mainnet': {
    label: 'Active Study: Figure 6 — Persistent MMO Mainnet & Five-Axis Rolling Live Upgrades',
    mode: 'MMO Mainnet · Uptime: 412d · Epoch 31 -> 32',
  },
};

window.WORLD_SIM_D1 = {
  counts: { value: 942, null: 28, missing: 14, type_error: 9, conflict: 7 },
};

function selectScreen(screenKey) {
  const key = SCREENS[screenKey] ? screenKey : 'macro-map';
  document.querySelectorAll('.screen').forEach(el => {
    el.classList.toggle('active', el.id === `screen-${key}`);
  });
  document.querySelectorAll('#screen-nav .mode-tab').forEach(tab => {
    tab.classList.toggle('active', tab.dataset.screen === key);
  });
  const meta = SCREENS[key];
  const labelEl = document.getElementById('status-screen-label');
  if (labelEl) labelEl.textContent = meta.label;
  const modeEl = document.getElementById('hdr-mode-pill');
  if (modeEl) modeEl.textContent = meta.mode;
  window.WORLD_SIM_D1_SCREEN = key;
}

window.addEventListener('hashchange', () => {
  selectScreen(location.hash.replace(/^#/, ''));
});

document.querySelectorAll('#screen-nav .mode-tab').forEach(tab => {
  tab.addEventListener('click', event => {
    event.preventDefault();
    const target = tab.dataset.screen;
    location.hash = target;
    selectScreen(target);
  });
});

selectScreen(location.hash.replace(/^#/, ''));
