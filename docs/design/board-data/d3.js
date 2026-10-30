// Local interaction study. Selection never submits SQL or changes Transit state.
(() => {
  const data = window.BOARD_D3_FIXTURE;
  const root = document.getElementById('app');
  const screens = {
    dataset: { area: 'Data', title: 'shipments', description: 'Table · public · definition d17', tabs: ['Rows', 'Schema'] },
    workbook: { area: 'Workbooks', title: 'Shipment distribution', description: 'Session workbook · unsaved · one illustrative SQL cell', tabs: ['Worksheet', 'Plan'] },
    changes: { area: 'Changes', title: 'Review delivery corrections', description: 'Three-way comparison · proposal fixture · publication unavailable', tabs: ['Data changes', 'Schema changes'] },
  };
  let screen = 'dataset';
  let selected = 'column';
  let dimension = 'Profile';
  let inspectorOpen = true;
  let navigatorOpen = false;
  let fullDetail = false;
  let view = 0;
  let changeIndex = 0;
  let rowIndex = 0;
  let draft = data.sql;
  let returnFocus = 'inspect';
  let tableScroll = [0, 0];
  const escape = value => String(value).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
  const button = (label, action, extra = '') => '<button type="button" data-action="' + action + '" ' + extra + '>' + label + '</button>';
  const field = (label, value) => '<div><dt>' + label + '</dt><dd>' + value + '</dd></div>';
  const subject = () => {
    if (selected === 'column') return { title: 'delay_minutes', path: 'shipments / column', kind: 'INT64 · nullable', dimensions: ['Profile', 'Definition'] };
    if (selected === 'table') return { title: 'shipments', path: 'public / table', kind: 'Object tbl:31 · definition d17', dimensions: ['Definition', 'Storage', 'Lineage', 'Policy'] };
    if (selected === 'row') return { title: data.rows[rowIndex].id, path: 'shipments / row', kind: 'Value in preview main@c104', dimensions: ['Definition'] };
    if (selected === 'result') return { title: 'Result 01', path: 'Shipment distribution / result', kind: 'Submitted SQL · main@c104', dimensions: ['Definition', 'Execution'] };
    if (selected === 'operator') return { title: 'Scan shipments', path: 'Result 01 / operator', kind: 'Recorded execution fixture', dimensions: ['Execution', 'Definition'] };
    const change = data.changes[changeIndex];
    return { title: change.id + ' / ' + change.field, path: 'shipments / change', kind: change.kind + ' · candidate-bound evidence', dimensions: ['Change', 'Definition', 'Lineage'] };
  };
  function profile() {
    const p = data.profile;
    return '<div class="scope-note"><strong>' + p.population + ' received rows</strong><br>Preview main@c104 · source coverage unknown</div>' +
      '<div class="stat-pair"><div><strong>' + p.values + '</strong><span>Typed values</span></div><div><strong>' + p.nulls + '</strong><span>SQL NULL</span></div></div>' +
      '<section><h3>Delay distribution</h3><p>Minutes · ' + p.values + ' typed values; NULL excluded</p><div class="histogram" role="img" aria-label="Six delay bins contain 4, 4, 4, 4, 4 and 2 values.">' +
      p.bins.map(bin => '<div class="bin"><span>' + bin.label + '</span><span class="bar-track"><span class="bar" style="width:' + (bin.count / 4 * 100) + '%"></span></span><span>' + bin.count + '</span></div>').join('') +
      '</div><dl>' + field('Minimum', p.minimum + ' min') + field('Maximum', p.maximum + ' min') + field('Distinct typed values', p.distinct) + '</dl></section>' +
      '<section><h3>Population, not a sample</h3><p>These statistics describe the received window. They do not estimate the full Table or a random sample.</p><p>This ordinary Table has values and SQL NULL. Other cell states are shown only for sources that support them.</p></section>';
  }
  function storage() {
    const s = data.storage;
    return '<div class="scope-note"><strong>Physical observation s201 · main</strong><br>Illustrative current metadata · independent of preview c104</div>' +
      '<section><h3>Reachable encoded data</h3><div class="stat-pair"><div><strong>' + s.reachableMiB + ' <small>MiB</small></strong><span>Distinct reachable data bytes</span></div></div>' +
      '<div class="storage-bar" role="img" aria-label="64 MiB of reachable data: 52 MiB shared and 12 MiB exclusive."><span style="width:81.25%"></span><span style="width:18.75%"></span></div>' +
      '<div class="legend"><span><i class="swatch"></i>Shared · 52 MiB</span><span><i class="swatch exclusive"></i>Exclusive · 12 MiB</span></div>' +
      '<dl>' + field('Logical rows at storage observation', '8,192') + field('Reclaimable bytes', 'Unavailable') + field('Retention', 'Unlimited') + '</dl></section>' +
      '<section><h3>delay_minutes · segment example</h3><dl>' + field('Logical type', 'INT64') + field('Ordering', 'Numeric') + field('Observed codec', 'Bitpacking') + field('Index coverage', 'Not supplied') + '</dl><p>One representative segment; other segments may use different encodings.</p></section>' +
      '<section><h3>Shared bytes have one identity</h3><p>52 MiB is also reachable from another branch. Summing branch totals would count it twice.</p><p>Exclusive bytes are not necessarily reclaimable: retained cuts and other roots may still need them.</p></section>';
  }
  function execution() {
    return '<div class="scope-note"><strong>Result 01 · main@c104</strong><br>Illustrative completed execution; no runtime measurement</div>' +
      '<section><h3>' + (selected === 'operator' ? 'Scan shipments' : 'Statement outcome') + '</h3><dl>' +
      field('Estimated source rows', '64') + field('Observed scanned rows', '42') +
      field('Scan output rows', '42') + field('Aggregate result rows', '3') +
      field('Verified terminal count', '3') + field('Spill evidence', 'Not supplied') + '</dl></section>' +
      '<section><h3>Estimates & observations</h3><p>Estimated rows describe the prepared plan. Actual rows belong to this execution. Neither can substitute for its terminal outcome.</p></section>' +
      '<section><h3>Source</h3><dl>' + field('Table', 'public.shipments') + field('Definition', 'd17') +
      field('Data basis', 'main@c104') + '</dl><p>This fixture has one source. Independent source cuts must remain labeled as a vector.</p></section>';
  }
  function changeDetails() {
    const c = data.changes[changeIndex];
    return '<div class="scope-note"><strong>' + c.kind + (c.kind === 'Conflict' ? ' · unresolved' : ' · proposed') + '</strong><br>Exact comparison inputs remain visible in the workspace.</div>' +
      '<dl class="change-values">' + field('Base · main@c100', escape(c.base)) + field('Source · corrections@c108', escape(c.source)) +
      field('Target · main@c104', escape(c.target)) + '</dl>' +
      '<section><h3>' + (c.kind === 'Conflict' ? 'Both branches changed this field' : 'Logical data difference') + '</h3>' +
      '<p>' + (c.kind === 'Conflict' ? 'The source and target changed 12 to different values. Selecting this row does not resolve the conflict.' : 'The change is aligned by stable row and field identities across the fixed inputs.') + '</p></section>' +
      '<section><h3>Publication</h3><p>Review applies to these exact inputs. A changed target requires a fresh comparison. Resolution and publication need their separately authorized owners.</p></section>';
  }
  function details() {
    if (dimension === 'Profile') return profile();
    if (dimension === 'Storage') return storage();
    if (dimension === 'Execution') return execution();
    if (dimension === 'Change') return changeDetails();
    if (dimension === 'Lineage') return '<section><h3>Registered dependency fixture</h3><dl>' + field('Source', 'shipments / d17') + field('Dependent', 'shipment_summary / d8') +
      '</dl><p>This registered edge does not establish a foreign key, join cardinality, complete lineage or current freshness.</p></section><section><h3>Impact</h3><p>Candidate-specific recomputation and constraint evidence belong here when supplied by the owner. Their absence is not evidence of no impact.</p></section>';
    if (dimension === 'Policy') return '<section><h3>Current policy observation</h3><dl>' + field('Inspection', 'Read only') + field('Retention', 'Unlimited') +
      field('Masking evidence', 'Not supplied') + field('Observation basis', 'Independent policy read') +
      '</dl><p>Historical data does not restore historical grants. Policy details require current authorized disclosure.</p></section>';
    if (selected === 'row') {
      const row = data.rows[rowIndex];
      return '<section><h3>Typed row</h3><dl>' + Object.entries(row).map(([key, value]) => field(escape(key), value === null ? 'SQL NULL' : escape(value))).join('') +
        '</dl><p>Only the received preview row is displayed. Selection does not load additional data.</p></section>';
    }
    if (selected === 'result') return '<section><h3>Submitted SQL</h3><pre class="mono">' + escape(data.sql) +
      '</pre><dl>' + field('Result identity', 'result:01') + field('Completion', '3 verified rows') + field('Source basis', 'main@c104') + '</dl></section>';
    return '<section><h3>Logical definition</h3><dl>' + field('Object', 'tbl:31 · shipments') + field('Definition', 'd17') +
      field('Selected column', selected === 'column' ? 'col:7 · delay_minutes' : '—') + field('Type', selected === 'column' ? 'INT64 · nullable' : 'Table') +
      field('Ordering', 'Numeric for delay_minutes') + '</dl></section><section><h3>Definition and observation</h3>' +
      '<p>Object identity survives rename. Schema revision, data cut and current authorization are separate.</p><p>Physical codec belongs to the stored representation; it does not change the logical type.</p></section>';
  }
  function inspector() {
    const s = subject();
    return '<aside class="inspector" aria-label="Selection inspector">' +
      '<div class="inspector-top"><span class="eyebrow">Inspector</span>' + button('Close', 'close-inspector', 'aria-label="Close inspector"') + '</div>' +
      (screen === 'dataset' && selected !== 'table' ? button('← shipments', 'select-table', 'class="plain"') : '') +
      '<p class="subject-path">' + escape(s.path) + '</p><h2>' + escape(s.title) + '</h2><span class="subject-kind">' + escape(s.kind) + '</span>' +
      '<div class="dimensions" aria-label="Inspection dimensions">' + s.dimensions.map(name => button(name, 'dimension', 'data-value="' + name + '" aria-pressed="' + (dimension === name) + '"')).join('') +
      '</div><div id="inspector-detail">' + details() + '</div><div class="inspector-footer">' + button('Open ' + dimension.toLowerCase() + ' in workspace ↗', 'full-detail') + '</div></aside>';
  }
  function table() {
    return '<div class="toolbar">' + button('Preview rows', 'preview', 'class="primary"') + '<a class="button" href="#workbook">Open workbook</a><span class="note">Preview fixture · explicit read</span></div>' +
      '<div class="table-scroll"><table aria-label="Shipment preview"><thead><tr>' +
      '<th>Shipment<small>STRING</small></th><th>Order<small>STRING</small></th><th class="' + (selected === 'column' ? 'selected' : '') + '">' +
      button('delay_minutes<small>INT64 · nullable</small>', 'select-column', 'aria-pressed="' + (selected === 'column') + '"') +
      '</th><th>Region<small>STRING</small></th><th>Status<small>STRING</small></th></tr></thead><tbody>' +
      data.rows.map((row, i) => '<tr><td>' + button(row.id, 'select-row', 'class="row-select" data-index="' + i + '"') + '</td><td>' + row.order + '</td><td class="' +
        (selected === 'column' ? 'selected' : '') + '">' + (row.delay === null ? '<span class="null">NULL</span>' : row.delay) + '</td><td>' + row.region + '</td><td>' + row.status + '</td></tr>').join('') +
      '</tbody></table></div><div class="result-status"><strong>24 received · display limit reached</strong><p>Source coverage unknown</p></div>' +
      '<p class="basis-line">Preview basis: main@c104 · definition d17 · terminal outcome not received</p>';
  }
  function schema() {
    return '<div class="subheading"><h2>Table definition</h2><small>Metadata only · d17</small></div><div class="table-scroll"><table aria-label="Table schema"><thead><tr><th>Column</th><th>Logical type</th><th>Nullable</th><th>Identity</th></tr></thead><tbody>' +
      [['shipment_id', 'STRING', 'No', 'col:1'], ['order_id', 'STRING', 'No', 'col:2'], ['delay_minutes', 'INT64', 'Yes', 'col:7'], ['region', 'STRING', 'No', 'col:8']].map(row =>
        '<tr>' + row.map(cell => '<td>' + cell + '</td>').join('') + '</tr>').join('') +
      '</tbody></table></div><p class="basis-line">Metadata has its own observation. Opening this view does not start a data scan.</p>';
  }
  function plan() {
    return '<div class="subheading"><h3>Execution path</h3><small>Recorded fixture · select an operator</small></div><div class="plan">' +
      button('Scan shipments<small>42 rows observed</small>', 'select-operator', 'aria-pressed="' + (selected === 'operator') + '"') +
      '<span aria-hidden="true">→</span>' + button('Aggregate by region<small>3 output rows</small>', 'select-result', 'aria-pressed="' + (selected === 'result') + '"') +
      '</div><p class="basis-line">Estimates and actual execution evidence stay distinct.</p>';
  }
  function workbook() {
    if (view === 1) return '<h2>Result 01 · query plan</h2>' + plan() + '<div class="result-status"><strong>Complete · 3 result rows verified</strong><p>Submitted SQL · main@c104</p></div>';
    return '<div class="notebook-note"><h2>Where are shipments concentrated?</h2><p>Compare counts by region, then inspect the scan behind this result.</p></div>' +
      '<div class="cell-header"><span class="eyebrow">SQL cell 01</span>' + button('Run', 'run', 'class="primary"') + '</div>' +
      '<label class="eyebrow" for="sql-draft">SQL draft</label><textarea id="sql-draft" spellcheck="false">' + escape(draft) + '</textarea>' +
      '<p class="draft-state" id="draft-state">' + (draft === data.sql ? 'Submitted text shown · illustrative execution' : 'Earlier result · edited draft has not run') + '</p>' +
      '<div class="subheading"><h3>Result 01</h3>' + button('Inspect result', 'select-result') + '</div>' +
      '<div class="table-scroll"><table aria-label="Grouped shipment result"><thead><tr><th>region<small>STRING</small></th><th>shipments<small>INT64</small></th></tr></thead><tbody>' +
      data.result.map(row => '<tr><td>' + row[0] + '</td><td>' + row[1] + '</td></tr>').join('') + '</tbody></table></div>' +
      '<div class="result-status"><strong>Complete · 3 result rows verified</strong><p>Submitted SQL · main@c104</p></div>' + plan();
  }
  function comparisonBasis() {
    return '<div class="comparison-basis" aria-label="Comparison inputs">' +
      '<div><span class="eyebrow">Base</span><strong>main</strong><code>c100 · definition d17</code></div>' +
      '<div><span class="eyebrow">Source</span><strong>corrections</strong><code>c108 · definition d17</code></div>' +
      '<div><span class="eyebrow">Target</span><strong>main</strong><code>c104 · definition d17</code></div></div>';
  }
  function changes() {
    if (view === 1) return '<h2>Schema comparison fixture</h2><p class="notice">Definition d17 is unchanged across these three fixture inputs. Physical segment rewrites do not create logical schema or data changes.</p>';
    return '<div class="subheading"><h2>shipments</h2><small>4 fixture differences · 1 unresolved conflict</small></div>' +
      '<div class="table-scroll"><table aria-label="Branch differences"><thead><tr><th>Row / field</th><th>Change</th><th>Base</th><th>Source</th><th>Target</th></tr></thead><tbody>' +
      data.changes.map((c, i) => '<tr class="' + (changeIndex === i ? 'selected' : '') + '"><td>' + button(c.id, 'select-change', 'class="row-select" data-index="' + i + '"') +
        '<br><small>' + c.field + '</small></td><td>' + (c.kind === 'Conflict' ? '<span class="conflict">Conflict</span>' : c.kind) + '</td><td>' + c.base + '</td><td>' + c.source + '</td><td>' + c.target + '</td></tr>').join('') +
      '</tbody></table></div><div class="result-status"><strong>Comparison fixture · not a publication</strong><p>Exact inputs shown above</p></div>' +
      '<div class="notice"><strong>Publication unavailable in this prototype.</strong> Resolve conflicts, validate the combined candidate and recheck the target through the owning services.</div>';
  }
  function render() {
    const previous = window.BOARD_D3_STATE;
    const retainPosition = previous?.screen === screen && previous?.view === view && previous?.fullDetail === fullDetail;
    const position = window.scrollY;
    const tablePosition = root.querySelector('.table-scroll');
    if (!retainPosition) tableScroll = [0, 0];
    else if (tablePosition?.offsetParent !== null && tablePosition) {
      tableScroll = [tablePosition.scrollTop, tablePosition.scrollLeft];
    }
    const meta = screens[screen];
    const labels = [['dataset', 'Data'], ['workbook', 'Workbooks'], ['changes', 'Changes']];
    root.innerHTML = '<header class="app-header"><div class="brand">▥ transit<span>Board</span></div><nav class="areas" aria-label="Activities">' +
      labels.map(([key, label]) => '<a href="#' + key + '"' + (screen === key ? ' aria-current="page"' : '') + '>' + label + '</a>').join('') +
      button('Operations', 'operations') + '</nav><p class="study-label">D3 · TOPOLOGY STUDY<br>Synthetic data · no service connection</p></header>' +
      '<div class="context"><span class="path">Local demo<span class="separator">/</span>Demo realm<span class="separator">/</span>logistics.public</span>' +
      '<span class="basis"><span>Branch <strong>main</strong></span><span>View basis <strong class="mono">c104</strong></span></span></div>' +
      '<div class="work-area">' + (navigatorOpen ? '<aside class="navigator" aria-label="Object navigator"><p class="eyebrow">Objects · fixture page</p><nav><a href="#dataset" aria-current="page">▤ shipments</a></nav><p class="eyebrow">Recent work</p><nav><a href="#workbook">Shipment distribution</a><a href="#changes">Delivery corrections</a></nav><small>Navigation never executes SQL.</small></aside>' : '') +
      '<main class="workspace"><div class="workspace-heading">' + button(navigatorOpen ? 'Hide objects' : 'Objects', 'navigator', 'aria-expanded="' + navigatorOpen + '"') +
      '<div class="title"><p class="eyebrow">' + meta.area + '</p><h1>' + meta.title + '</h1><p>' + meta.description + '</p></div>' +
      button(inspectorOpen && !fullDetail ? 'Inspector open' : 'Inspect', 'inspect', 'aria-expanded="' + (inspectorOpen && !fullDetail) + '"') + '</div>' +
      '<div class="object-tabs" aria-label="Workspace views">' + meta.tabs.map((name, i) => button(name, 'view', 'data-index="' + i + '" aria-pressed="' + (view === i && !fullDetail) + '"')).join('') +
      '</div>' + (screen === 'changes' ? '<div class="comparison-context">' + comparisonBasis() + '</div>' : '') +
      (screen !== 'changes' && inspectorOpen && !fullDetail ? '<p class="narrow-evidence">' + (screen === 'dataset' ?
        'Preview main@c104 · 24 received · display limit reached · source coverage unknown' :
        'Result 01 · submitted SQL · main@c104 · 3 result rows verified' + (draft !== data.sql ? ' · Earlier result; edited draft has not run' : '')) + '</p>' : '') +
      '<div class="content ' + (inspectorOpen && !fullDetail ? 'has-inspector' : '') + '">' +
      '<section class="canvas" id="main" aria-label="Working surface">' + (fullDetail ? '<div class="full-detail"><div class="toolbar">' + button('← Return to ' + meta.tabs[view].toLowerCase(), 'back-detail') +
        '</div><p class="eyebrow">' + escape(subject().path) + '</p><h2>' + escape(subject().title) + ' · ' + dimension + '</h2>' +
        details() + '</div>' :
        screen === 'dataset' ? (view === 0 ? table() : schema()) : screen === 'workbook' ? workbook() : changes()) +
      '</section>' + (inspectorOpen && !fullDetail ? inspector() : '') + '</div></main></div><div id="announcement" role="status" aria-live="polite">Design study · all rows, comparisons and metrics are synthetic.</div>';
    const nextTable = root.querySelector('.table-scroll');
    if (retainPosition && nextTable?.offsetParent !== null && nextTable) {
      nextTable.scrollTop = tableScroll[0]; nextTable.scrollLeft = tableScroll[1];
    }
    window.scrollTo(0, retainPosition ? position : 0);
    window.BOARD_D3_STATE = { screen, selected, dimension, inspectorOpen, navigatorOpen, fullDetail, view };
  }
  function focusAction(action) {
    const index = action === 'select-change' ? changeIndex : action === 'select-row' ? rowIndex : action === 'view' ? view : null;
    const target = root.querySelector('[data-action="' + action + '"]' + (index === null ? '' : '[data-index="' + index + '"]'));
    if (target) target.focus({ preventScroll: true });
  }
  function select(kind, initialDimension, origin) {
    selected = kind; dimension = initialDimension; inspectorOpen = true; fullDetail = false;
    returnFocus = origin;
    // Reclaim navigation width; selection never creates a second inspector.
    navigatorOpen = false;
    render();
    if (window.innerWidth <= 1000) focusAction('close-inspector');
    else focusAction(origin);
  }
  root.addEventListener('input', event => {
    if (event.target.id !== 'sql-draft') return;
    draft = event.target.value;
    document.getElementById('draft-state').textContent = draft === data.sql ?
      'Submitted text shown · illustrative execution' : 'Earlier result · edited draft has not run';
  });
  root.addEventListener('click', event => {
    const target = event.target.closest('button[data-action]');
    if (!target) return;
    const action = target.dataset.action;
    if (action === 'preview' || action === 'run' || action === 'operations') {
      document.getElementById('announcement').textContent = action === 'operations' ?
        'Operations remains an installed Board destination. This study contains only three workbench scenarios.' :
        'Prototype only. No SQL was submitted; the fixture and original result basis are unchanged.';
      return;
    }
    if (action === 'select-column') return select('column', 'Profile', action);
    if (action === 'select-table') return select('table', 'Definition', 'inspect');
    if (action === 'select-row') { rowIndex = Number(target.dataset.index); return select('row', 'Definition', action); }
    if (action === 'select-operator') return select('operator', 'Execution', action);
    if (action === 'select-result') return select('result', 'Definition', action);
    if (action === 'select-change') { changeIndex = Number(target.dataset.index); return select('change', 'Change', action); }
    if (action === 'dimension') dimension = target.dataset.value;
    if (action === 'navigator') { navigatorOpen = !navigatorOpen; if (navigatorOpen && window.innerWidth <= 1350) inspectorOpen = false; }
    if (action === 'inspect') { inspectorOpen = !inspectorOpen || fullDetail; fullDetail = false; if (inspectorOpen) navigatorOpen = false; }
    if (action === 'close-inspector') inspectorOpen = false;
    if (action === 'view') { view = Number(target.dataset.index); fullDetail = false; }
    if (action === 'full-detail') fullDetail = true;
    if (action === 'back-detail') { fullDetail = false; inspectorOpen = true; }
    render();
    if (action === 'dimension') root.querySelector('[data-action="dimension"][aria-pressed="true"]').focus({ preventScroll: true });
    else if (action === 'close-inspector') focusAction(returnFocus);
    else if (action === 'full-detail') focusAction('back-detail');
    else if (action === 'back-detail') focusAction('full-detail');
    else if (action === 'inspect' && inspectorOpen && window.innerWidth <= 1000) focusAction('close-inspector');
    else focusAction(action);
  });
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && inspectorOpen && !fullDetail) {
      inspectorOpen = false; render(); focusAction(returnFocus);
    }
  });
  function navigate() {
    const next = location.hash.slice(1);
    screen = Object.hasOwn(screens, next) ? next : 'dataset';
    selected = screen === 'dataset' ? 'column' : screen === 'workbook' ? 'operator' : 'change';
    dimension = screen === 'dataset' ? 'Profile' : screen === 'workbook' ? 'Execution' : 'Change';
    inspectorOpen = window.innerWidth > 1000; navigatorOpen = false; fullDetail = false; view = 0;
    returnFocus = 'inspect'; render();
  }
  window.addEventListener('hashchange', navigate);
  navigate();
})();
