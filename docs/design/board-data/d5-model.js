/* Fixed synthetic study, not a SQL parser or a Transit client. */
(() => {
  const source = [
    { region: 'West', delay: 12 }, { region: 'West', delay: 32 },
    { region: 'East', delay: 24 }, { region: 'North', delay: 48 },
    { region: 'East', delay: 8 }, { region: 'West', delay: 42 },
  ];
  const sql = 'SELECT region, delay_minutes\nFROM shipments\nWHERE delay_minutes > 15';
  const computeA = threshold => source.filter(row => row.delay > threshold)
    .map(row => [row.region, row.delay]);
  const computeB = rows => Object.entries(rows.reduce((counts, [region]) => {
    counts[region] = (counts[region] || 0) + 1;
    return counts;
  }, {}));
  const result = (rows, revision, basis, generation = 1) =>
    ({ rows, revision, basis, generation, terminal: rows.length });
  function initial() {
    const rows = computeA(15);
    return {
      route: 'workbook', left: false, right: false, lastSide: 'right',
      tab: 'inspector', selected: 'a', dirty: false, notice: '',
      selections: { workbook: 'a', catalog: 'catalog', operations: 'operations' },
      mode: 'disabled', remaining: 0, generation: 1, sequence: 0,
      ready: false, once: false, running: null, visible: true,
      counts: { a: 1, b: 1, c: 1 },
      cells: {
        a: { name: 'delayed_shipments', sql, revision: 1, status: 'current',
          output: result(rows, 1, 'shipments · fixture cut s104'), threshold: 15 },
        b: { name: 'by_region', revision: 1, status: 'current',
          sql: 'SELECT region, COUNT(*) AS delayed\nFROM delayed_shipments\nGROUP BY region',
          output: result(computeB(rows), 1, 'delayed_shipments · revision 1') },
        c: { name: 'total_shipments', revision: 1, status: 'current',
          sql: 'SELECT COUNT(*) AS total\nFROM shipments',
          output: result([[source.length]], 1, 'shipments · independent fixture cut s103') },
      },
    };
  }
  function recognize(text) {
    const match = /^SELECT\s+region,\s*delay_minutes\s+FROM\s+shipments\s+WHERE\s+delay_minutes\s*>\s*(\d{1,3})\s*;?\s*$/i.exec(text);
    return match ? Number(match[1]) : null;
  }
  function reduce(previous, event) {
    const state = structuredClone(previous);
    const effects = [];
    const a = state.cells.a, b = state.cells.b;
    switch (event.type) {
      case 'LEFT': state.left = event.open ?? !state.left; state.lastSide = 'left'; break;
      case 'RIGHT': state.right = event.open ?? !state.right; state.lastSide = 'right'; break;
      case 'TAB': state.tab = event.tab; state.right = true; state.lastSide = 'right'; break;
      case 'SELECT': state.selected = event.id; state.tab = 'inspector'; state.right = true; state.lastSide = 'right'; break;
      case 'NOTICE': state.notice = event.text; break;
      case 'ROUTE':
        state.selections[state.route] = state.selected;
        state.route = event.route;
        state.selected = state.selections[event.route];
        if (state.mode === 'enabled') state.mode = 'paused';
        state.ready = false; state.once = false;
        state.generation += 1;
        effects.push({ type: 'clear-debounce' });
        break;
      case 'EDIT': {
        if (event.sql === a.sql) break;
        a.sql = event.sql; a.revision += 1; state.generation += 1;
        a.threshold = recognize(event.sql);
        a.status = a.threshold === null ? 'invalid' : 'dirty';
        b.status = a.threshold === null ? 'blocked' : 'waiting';
        state.dirty = true; state.ready = false; state.once = false;
        effects.push({ type: 'clear-debounce' });
        if (state.mode === 'enabled' && !event.composing)
          effects.push({ type: 'debounce', generation: state.generation });
        break;
      }
      case 'READY':
        if (event.generation === state.generation && state.mode === 'enabled') state.ready = true;
        break;
      case 'LIVE':
        if (state.mode === 'enabled') {
          state.mode = 'paused'; state.ready = false; effects.push({ type: 'clear-debounce' });
        } else if (state.mode === 'disabled' || state.mode === 'exhausted') {
          state.mode = 'enabled'; state.remaining = 8; state.ready = true;
        } else { state.mode = 'enabled'; state.ready = true; }
        break;
      case 'RUN': state.once = true; state.ready = true; break;
      case 'HIDE':
        state.visible = false; state.generation += 1; state.ready = false; state.once = false;
        if (state.mode === 'enabled') state.mode = 'paused';
        effects.push({ type: 'clear-debounce' }); break;
      case 'SHOW': state.visible = true; break;
      case 'COMPLETE': {
        const run = state.running;
        if (!run || run.id !== event.run.id) break;
        state.running = null;
        if (run.generation !== state.generation) {
          if (state.cells[run.cell].status === 'running') state.cells[run.cell].status = 'dirty';
          effects.push({ type: 'discard', id: run.id });
          break;
        }
        const cell = state.cells[run.cell];
        cell.output = result(event.rows, run.revision, run.basis, run.generation);
        cell.status = 'current'; state.counts[run.cell] += 1;
        if (run.cell === 'a') b.status = 'dirty';
        break;
      }
    }
    if (state.ready && state.visible && state.route === 'workbook' && !state.running &&
        (state.mode === 'enabled' || state.once) && a.status !== 'invalid') {
      const id = ['a', 'b'].find(key => state.cells[key].status === 'dirty');
      if (!id) { state.once = false; state.ready = false; }
      else if (!state.once && state.remaining <= 0) { state.mode = 'exhausted'; state.ready = false; }
      else {
        const cell = state.cells[id];
        const run = {
          id: ++state.sequence, cell: id, generation: state.generation,
          revision: cell.revision, threshold: a.threshold,
          input: id === 'b' ? structuredClone(a.output) : null,
          basis: id === 'a' ? 'shipments · fixture cut s104' : `delayed_shipments · revision ${a.output.revision}`,
        };
        state.running = run; cell.status = 'running';
        if (!state.once) state.remaining -= 1;
        effects.push({ type: 'evaluate', run });
      }
    }
    return { state, effects };
  }
  globalThis.BOARD_D5_MODEL = {
    initial, reduce, source,
    evaluate: run => run.cell === 'a' ? computeA(run.threshold) : computeB(run.input.rows),
  };
})();
