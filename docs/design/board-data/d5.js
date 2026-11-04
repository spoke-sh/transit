/* Presentation/effects for D5's synthetic fixed-graph study. */
(() => {
  const model = window.BOARD_D5_MODEL;
  let state = model.initial();
  let debounce, noticeTimer, returnFocus;
  const root = document.querySelector('#plane');
  const workspace = document.querySelector('#workspace');
  const escape = value => String(value).replace(/[&<>"']/g, char =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
  const titles = { a: 'delayed_shipments', b: 'by_region', c: 'total_shipments' };
  const statusText = { current: '✓ Current draft', dirty: 'Earlier result', waiting: 'Waiting for input',
    blocked: 'Blocked by input', invalid: 'Invalid draft', running: 'Recalculating…' };
  function table(headers, rows) {
    return `<div class="table-scroll"><table><thead><tr>${headers.map(h => `<th scope="col">${escape(h)}</th>`).join('')}</tr></thead><tbody>${rows.map(row => `<tr>${row.map(v => `<td>${escape(v)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
  }
  function cell(id, index, note) {
    return `<section class="cell" id="cell-${id}" aria-label="${titles[id]}">
      <div class="cell-head"><span class="number">0${index}</span><button class="cell-name" data-select="${id}">${titles[id]}</button><span class="state" id="status-${id}"></span></div>
      <div class="cell-meta">${note}</div>
      <textarea aria-label="SQL for ${titles[id]}" class="sql" id="sql-${id}" spellcheck="false" ${id === 'a' ? '' : 'readonly'}>${escape(state.cells[id].sql)}</textarea>
      <div class="result" id="result-${id}"></div></section>`;
  }
  function workbook() {
    return `<div class="heading"><div><p class="eyebrow">WORKBOOK / SESSION GRAPH</p><h1>Where are shipments delayed?</h1><p>Start with a relation. Build on what it tells you.</p></div><button class="unsaved" id="unsaved">Unsaved ⓘ</button></div>
      <div class="toolbar"><button id="live" class="primary"></button><button id="run">Recalculate changed cells</button><span class="budget" id="budget"></span></div>
      <div class="graph"><span>shipments</span><span>→</span><button data-select="a">delayed_shipments</button><span>→</span><button data-select="b">by_region</button><span class="independent">＋ 1 independent cell</span></div>
      ${cell('a', 1, 'Source relation · try changing 15 to 30; Live recalculates after typing or blur')}
      ${cell('b', 2, 'Depends on delayed_shipments · proposed session relation binding')}
      ${cell('c', 3, 'Independent read · changing the threshold leaves this result alone')}
      <p class="help">Study recognizes this one threshold query. Other SQL shows an invalid draft. Cells 02 and 03 are fixed fixture definitions.</p>`;
  }
  function catalog() {
    return `<div class="heading"><div><p class="eyebrow">CATALOG</p><h1>Your data, in context.</h1><p>Definitions, relationships and observed data.</p></div></div>
      <div class="toolbar"><button disabled>public ▾</button><span class="budget">3 objects · synthetic catalog</span></div>
      <div class="catalog-list">${[
        ['shipments', 'TABLE · 2 columns · selected source'], ['regional_totals', 'TABLE · derived output'], ['delay_projection', 'DATAFLOW · managed computation'],
      ].map(([name, note]) => `<div class="catalog-row"><div><strong>${name}</strong><small>${note}</small></div><button data-inspect-catalog="${name}">Inspect →</button></div>`).join('')}</div>
      <p class="help">Opening metadata starts no scan. The study preserves Catalog’s content hierarchy while changing the surrounding plane.</p>`;
  }
  function operations() {
    return `<div class="heading"><div><p class="eyebrow">OPERATIONS</p><h1>Evidence of the system at work.</h1><p>Capacity, maintenance and computation progress.</p></div></div>
      <div class="toolbar"><span>Last observation · fixture o207</span><span class="budget">Independent of workbook results</span></div>
      <div class="operation-grid"><div class="metric"><p class="eyebrow">RESIDENT ALLOCATION</p><h2>64 MiB</h2><div class="meter"><span style="width:25%"></span></div><small>of 256 MiB configured limit</small></div><div class="metric"><p class="eyebrow">LAST COMPLETED OUTPUT</p><h2>4 rows</h2><p class="muted">Revision 7 · complete</p><small>Current control: active · freshness unknown</small></div></div>
      <div class="operation-list">${table(['Measure', 'Observed value', 'Basis'], [['Allocation', '67,108,864 B', 'node observation o207'], ['Maintenance', 'Idle', 'worker observation m43'], ['Pending computation', 'None observed', 'control observation k11']])}</div>
      <p><button id="inspect-operations">Inspect observation →</button></p><p class="help">All quantities are illustrative. Keep the installed diagrams, exact grids and their distinct observation bases.</p>`;
  }
  let renderedRoute = null;
  function render() {
    const active = state.lastSide === 'left' && state.left ? 'left' : state.right ? 'right' : state.left ? 'left' : 'none';
    root.dataset.left = state.left; root.dataset.right = state.right;
    root.dataset.last = state.lastSide; root.dataset.active = active;
    const narrow = innerWidth < 800;
    const constrained = innerWidth < 1232;
    const leftEffective = state.left && (!constrained || active === 'left');
    const rightEffective = state.right && (!constrained || active === 'right');
    document.querySelector('#left-toggle').setAttribute('aria-expanded', leftEffective);
    document.querySelector('#right-toggle').setAttribute('aria-expanded', rightEffective);
    workspace.inert = narrow && active !== 'none';
    document.querySelectorAll('[data-route]').forEach(button => button.setAttribute('aria-current', button.dataset.route === state.route ? 'page' : 'false'));
    document.querySelectorAll('[role="tab"]').forEach(button => {
      const selected = button.dataset.tab === state.tab;
      button.setAttribute('aria-selected', selected); button.tabIndex = selected ? 0 : -1;
    });
    document.querySelector('#inspector-panel').hidden = state.tab !== 'inspector';
    document.querySelector('#assistant-panel').hidden = state.tab !== 'assistant';
    if (renderedRoute !== state.route) {
      workspace.innerHTML = state.route === 'workbook' ? workbook() : state.route === 'catalog' ? catalog() : operations();
      document.querySelector('#nav-detail').innerHTML = state.route === 'workbook'
      ? `<p class="eyebrow">THIS WORKBOOK</p><small>Where are shipments delayed?</small>${Object.entries(titles).map(([id, title], index) => `<button data-select="${id}">0${index + 1} &nbsp; ${title}</button>`).join('')}<p class="help">Temporary graph<br>3 cells · 1 dependency</p>`
      : state.route === 'catalog' ? '<p class="eyebrow">PUBLIC</p><button data-inspect-catalog="shipments">▦ &nbsp; shipments</button><button data-inspect-catalog="regional_totals">▦ &nbsp; regional_totals</button>'
        : '<p class="eyebrow">OBSERVATIONS</p><p>Storage</p><p>Maintenance</p><p>Computations</p><p class="help">Processes and recovery remain reachable in the installed interface.</p>';
      renderedRoute = state.route;
    }
    if (state.route === 'workbook') {
      const labels = { disabled: 'Enable Live · 8 evaluations', enabled: 'Ⅱ Pause Live', paused: 'Resume Live', exhausted: 'New Live budget · 8 evaluations' };
      document.querySelector('#live').textContent = labels[state.mode];
      document.querySelector('#budget').textContent = state.mode === 'disabled'
        ? 'Manual · fixture results loaded' : `${state.mode === 'enabled' ? 'Live' : state.mode === 'paused' ? 'Paused' : 'Budget exhausted'} · ${state.remaining} evaluations left`;
      for (const id of ['a', 'b', 'c']) {
        const cell = state.cells[id];
        const status = document.querySelector(`#status-${id}`);
        status.textContent = statusText[cell.status]; status.dataset.state = cell.status;
        document.querySelector(`#cell-${id}`).classList.toggle('selected', state.selected === id);
        const output = cell.output;
        const earlier = cell.status !== 'current';
        document.querySelector(`#result-${id}`).innerHTML = `<div class="result-top"><strong>${earlier ? 'EARLIER COMPLETE RESULT' : 'RESULT'} · ${output.rows.length} rows</strong><span>${escape(output.basis)}</span></div>
          ${table(id === 'a' ? ['region · TEXT', 'delay_minutes · INT64'] : id === 'b' ? ['region · TEXT', 'delayed · INT64'] : ['total · INT64'], output.rows)}
          <div class="result-foot"><span>✓ Verified fixture terminal: ${output.terminal} rows${output.terminal === 0 ? ' · empty relation' : ''}</span><span>Draft r${output.revision} · ${state.counts[id]} completed ${state.counts[id] === 1 ? 'evaluation' : 'evaluations'}</span></div>`;
      }
    }
    renderInspector();
    window.BOARD_D5_STATE = structuredClone(state);
  }
  function renderInspector() {
    const panel = document.querySelector('#inspector-panel');
    const cell = state.cells[state.selected];
    if (state.route === 'workbook' && cell) {
      panel.innerHTML = `<p class="eyebrow">SQL CELL / ${cell.name}</p><h2>${cell.name}</h2><p>One declared relation in this temporary workbook.</p><div class="dimension"><strong>Evidence</strong><span>Definition</span><span>Dependencies</span></div>
        <div class="path">${state.selected === 'c' ? 'shipments<br>↓<br>total_shipments' : 'shipments<br>↓<br>delayed_shipments<br>↓<br>by_region'}</div><dl>
        <dt>Draft</dt><dd>Revision ${cell.revision} · ${statusText[cell.status]}</dd>
        <dt>Last complete output</dt><dd>${cell.output.terminal} rows · draft r${cell.output.revision}</dd>
        <dt>Source basis</dt><dd>${escape(cell.output.basis)}</dd>
        <dt>Consistency</dt><dd>Independent source observations. This graph generation is not an atomic snapshot.</dd>
        <dt>Execution lifetime</dt><dd>Temporary, read-only, finite budget. Saving a draft would not keep a reader alive.</dd></dl>`;
    } else if (state.route === 'catalog') {
      panel.innerHTML = `<p class="eyebrow">CATALOG DEFINITION</p><h2>${escape(state.catalogSelection || 'shipments')}</h2><div class="dimension"><strong>Definition</strong><span>Evidence</span></div><dl><dt>Namespace</dt><dd>local / logistics / public</dd><dt>Observation</dt><dd>Synthetic metadata m201</dd><dt>Definition versus data</dt><dd>Selection inspects metadata. Preview would require an explicit read.</dd></dl>`;
    } else {
      panel.innerHTML = '<p class="eyebrow">OPERATIONS EVIDENCE</p><h2>Resident allocation</h2><dl><dt>Readable quantity</dt><dd>64 MiB</dd><dt>Exact bytes</dt><dd>67,108,864</dd><dt>Scope</dt><dd>Node · synthetic observation o207</dd><dt>Limit</dt><dd>256 MiB configured</dd><dt>Interpretation</dt><dd>This is an allocation observation, not dataset size or a workbook snapshot.</dd></dl>';
    }
  }
  function dispatch(event) {
    const next = model.reduce(state, event);
    state = next.state; render();
    for (const effect of next.effects) {
      if (effect.type === 'clear-debounce') clearTimeout(debounce);
      if (effect.type === 'debounce') debounce = setTimeout(() => dispatch({ type: 'READY', generation: effect.generation }), 300);
      if (effect.type === 'evaluate') setTimeout(() => dispatch({ type: 'COMPLETE', run: effect.run, rows: model.evaluate(effect.run) }), 500);
    }
  }
  function announce(text) {
    document.querySelector('#announcement').textContent = text;
    clearTimeout(noticeTimer); noticeTimer = setTimeout(() => document.querySelector('#announcement').textContent = '', 4500);
  }
  function openContext(event, trigger) {
    if (!state.right || event.type === 'SELECT') returnFocus = trigger;
    dispatch(event);
    if (innerWidth < 800) document.querySelector('#close-right').focus();
  }
  function returnToWork() {
    const active = root.dataset.active;
    if (active === 'right') dispatch({ type: 'RIGHT' });
    if (active === 'left') dispatch({ type: 'LEFT' });
    // A narrow Back returns all the way to work, preserving wide-screen intent elsewhere.
    if (innerWidth < 800 && root.dataset.active !== 'none') dispatch({ type: root.dataset.active === 'right' ? 'RIGHT' : 'LEFT' });
    if (returnFocus?.isConnected && returnFocus.getClientRects().length) returnFocus.focus();
    else workspace.focus();
  }
  document.addEventListener('click', event => {
    const button = event.target.closest('button');
    if (!button) return;
    if (button.dataset.route) {
      location.hash = button.dataset.route; dispatch({ type: 'ROUTE', route: button.dataset.route });
      if (innerWidth < 800) { if (state.left) dispatch({ type: 'LEFT' }); if (state.right) dispatch({ type: 'RIGHT' }); }
      workspace.focus(); return;
    }
    if (button.dataset.tab) { openContext({ type: 'TAB', tab: button.dataset.tab }, button); return; }
    if (button.dataset.select) { openContext({ type: 'SELECT', id: button.dataset.select }, button); return; }
    if (button.dataset.inspectCatalog) {
      state.catalogSelection = button.dataset.inspectCatalog;
      openContext({ type: 'SELECT', id: 'catalog' }, button); return;
    }
    switch (button.id) {
      case 'left-toggle': returnFocus = button; dispatch({ type: 'LEFT', open: button.getAttribute('aria-expanded') !== 'true' }); if (innerWidth < 800 && state.left) document.querySelector('[data-route="catalog"]').focus(); break;
      case 'right-toggle': openContext({ type: 'RIGHT', open: button.getAttribute('aria-expanded') !== 'true' }, button); break;
      case 'close-right': case 'back': returnToWork(); break;
      case 'live': dispatch({ type: 'LIVE' }); break;
      case 'run': dispatch({ type: 'RUN' }); break;
      case 'inspect-operations': openContext({ type: 'SELECT', id: 'operations' }, button); break;
      case 'unsaved': announce('Temporary workbook. This study retains drafts between activities; closing or reloading discards them. Save requires the future Document owner.'); break;
    }
  });
  document.addEventListener('input', event => {
    if (event.target.id === 'sql-a') dispatch({ type: 'EDIT', sql: event.target.value, composing: event.isComposing });
  });
  document.addEventListener('compositionend', event => {
    if (event.target.id === 'sql-a') {
      clearTimeout(debounce); debounce = setTimeout(() => dispatch({ type: 'READY', generation: state.generation }), 300);
    }
  });
  document.addEventListener('focusout', event => {
    if (event.target.id === 'sql-a') { clearTimeout(debounce); dispatch({ type: 'READY', generation: state.generation }); }
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && root.dataset.active !== 'none') { event.preventDefault(); returnToWork(); }
    if (event.target.getAttribute('role') === 'tab' && ['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) {
      event.preventDefault(); const tab = event.key === 'Home' ? 'inspector' : event.key === 'End' ? 'assistant' : state.tab === 'inspector' ? 'assistant' : 'inspector';
      dispatch({ type: 'TAB', tab }); document.querySelector(`#tab-${tab}`).focus();
    }
  });
  window.addEventListener('hashchange', () => {
    const route = location.hash.slice(1);
    if (['workbook', 'catalog', 'operations'].includes(route) && route !== state.route) dispatch({ type: 'ROUTE', route });
  });
  window.addEventListener('resize', () => {
    render();
    if (innerWidth < 800 && root.dataset.active === 'right') document.querySelector('#close-right').focus();
  });
  document.addEventListener('visibilitychange', () => dispatch({ type: document.hidden ? 'HIDE' : 'SHOW' }));
  window.addEventListener('beforeunload', event => { if (state.dirty) { event.preventDefault(); event.returnValue = ''; } });
  const initialRoute = location.hash.slice(1);
  if (['catalog', 'operations'].includes(initialRoute)) state.route = initialRoute;
  render();
})();
