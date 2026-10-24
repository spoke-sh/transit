/* Repository design prototype. Navigation is local; no Transit API is called. */
const f = window.BOARD_D2;
const paths = {
  logo:'M3 6h18M7 6v15M17 6v15M3 13h18',
  search:'m20 20-5-5M17 10a7 7 0 1 1-14 0 7 7 0 0 1 14 0',
  grid:'M3 3h7v7H3zM14 3h7v7h-7zM3 14h7v7H3zM14 14h7v7h-7z',
  table:'M3 4h18v16H3zM3 9h18M9 9v11M15 9v11',
  book:'M5 3h15v18H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2M7 3v18M11 8h5M11 12h5',
  branch:'M6 3v12a4 4 0 0 0 4 4h8M6 7h7a4 4 0 0 0 4-4M18 16l3 3-3 3',
  graph:'M4 5h5v5H4zM15 3h5v5h-5zM15 16h5v5h-5zM9 7h6M7 10v8h8',
  chevron:'m9 5 7 7-7 7', down:'m6 9 6 6 6-6', arrow:'M4 12h16m-6-6 6 6-6 6',
  play:'m8 5 11 7-11 7z', plus:'M12 4v16M4 12h16',
  file:'M6 3h8l4 4v14H6zM14 3v5h5M9 12h6M9 16h6',
  cube:'m12 3 9 5v9l-9 5-9-5V8zM3 8l9 5 9-5M12 13v9M7 5l10 6',
  lock:'M6 10h12v11H6zM8 10V6a4 4 0 0 1 8 0v4',
  clock:'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M12 7v5l3 2',
  check:'m5 12 4 4L19 6', info:'M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M12 11v6M12 7v.1',
  warning:'m12 3 10 18H2zM12 9v5M12 17v.1',
  filter:'M3 5h18M6 12h12M9 19h6', download:'M12 3v12m-5-5 5 5 5-5M4 17v4h16v-4',
  refresh:'M20 8a8 8 0 1 0 0 8M20 3v5h-5',
  panel:'M3 4h18v16H3zM15 4v16', link:'m10 14 4-4M8 16l-1 1a4 4 0 0 1-6-6l5-5a4 4 0 0 1 6 0M16 8l1-1a4 4 0 0 1 6 6l-5 5a4 4 0 0 1-6 0',
  eye:'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0',
  terminal:'m4 6 6 6-6 6M13 18h7', dots:'M5 12h.1M12 12h.1M19 12h.1',
};
const icon = name => `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><path d="${paths[name] || paths.table}"/></svg>`;
const badge = (s, kind='') => `<span class="badge ${kind}">${s}</span>`;
const button = (label, name='', kind='', href='') => href
  ? `<a class="button ${kind}" href="#${href}">${name ? icon(name) : ''}${label}</a>`
  : `<button class="button ${kind}" data-note="This control is illustrated in the D2 design review; it does not execute an operation.">${name ? icon(name) : ''}${label}</button>`;
const crumb = s => `<div class="breadcrumb"><a href="#catalog">Workspace</a>${icon('chevron')}<a href="#catalog">Data</a>${s ? `${icon('chevron')}<span>${s}</span>`:''}</div>`;
const tabs = (items,active,right='') => `<div class="tabs">${items.map(([s,target])=>`<a class="tab ${s===active?'active':''}" href="#${target}">${s}</a>`).join('')}<span class="tab-right">${right}</span></div>`;
const notice = (text, kind='') => `<div class="notice ${kind}">${icon(kind?'warning':'info')}<div>${text}</div></div>`;
const assetIcon = kind => kind==='Document'?'file':kind==='Maintained view'?'graph':kind==='Key-value'?'cube':'table';
const heading = (title, sub, actions='', name='') => `<div class="page-heading"><div><div class="heading-with-icon">${name?icon(name):''}<h1>${title}</h1></div><p class="subtitle">${sub}</p></div><div class="actions">${actions}</div></div>`;

function catalog() {
  return `${crumb('Catalog')}${heading('Data catalog','Explore datasets, understand their relationships and follow the computations they support.',button('Open workbook','book','','workbook'))}
    ${tabs([['All data','catalog'],['Relationships','relationships'],['Lineage','lineage']],'All data','Catalog observation · cat-042')}
    <div class="toolbar"><label class="search">${icon('search')}<input id="catalog-filter" placeholder="Search names and descriptions" aria-label="Search catalog"></label>${button('All kinds','down')}${button('Filters','filter')}<span class="spacer"></span><span class="small-text muted">7 objects · main</span></div>
    <div class="catalog-grid"><div>
      <div class="panel"><table aria-label="Catalog"><thead><tr><th>Object</th><th>Kind</th><th>Definition</th><th>Data revision</th><th>Dependents</th></tr></thead><tbody id="catalog-rows">
        ${f.assets.map(([name,kind,desc,def,rev,deps],i)=>`<tr class="${i===0?'selected-row':''}" data-search="${name} ${kind} ${desc}"><td><a class="asset-name" href="#${name==='delivery_notes'?'dataset':name==='at_risk_deliveries'?'lineage':'relationships'}">${icon(assetIcon(kind))}${name}</a><div class="asset-description">${desc}</div></td><td class="asset-kind">${kind}</td><td class="mono">d-${def.padStart(3,'0')}</td><td class="mono">${rev==='—'?rev:`r-${rev.padStart(3,'0')}`}</td><td class="num">${deps}</td></tr>`).join('')}
      </tbody></table><div class="table-foot"><span id="catalog-count">7 objects visible to this workspace</span><span>— &nbsp; No single data revision</span></div></div>
      <div class="recent"><div class="recent-head"><h2>Continue exploring</h2><a class="small-text muted" href="#workbook">View workbooks ${icon('arrow')}</a></div><div class="recent-cards">
        <a class="recent-card" href="#workbook">${icon('book')}<div><h3>Delivery risk investigation</h3><p class="small-text muted">3 cells · orders, shipments</p></div>${icon('arrow')}</a>
        <a class="recent-card" href="#dataset">${icon('file')}<div><h3>Inspect delivery notes</h3><p class="small-text muted">Document projection · 5 cell states</p></div>${icon('arrow')}</a>
      </div></div>
    </div><aside class="panel"><div class="panel-heading"><h2>Object details</h2>${icon('panel')}</div><div class="detail-body">
      <div class="asset-name">${icon('table')}orders</div><p>Customer orders and delivery commitments. A starting point for fulfillment analysis.</p>${badge('Table')}
      <dl class="facts"><dt>Object identity</dt><dd class="mono">cat:101</dd><dt>Definition</dt><dd class="mono">d-012</dd><dt>Observed data</dt><dd class="mono">r-042</dd><dt>Columns</dt><dd>6</dd><dt>Registered dependents</dt><dd>4</dd></dl>
      <hr class="rule"><h3>Connected data</h3><ul class="mini-list"><li><a href="#relationships">shipments</a><span class="muted">Join candidate</span></li><li><a href="#relationships">inventory</a><span class="muted">Join candidate</span></li><li><a href="#lineage">at_risk_deliveries</a><span class="muted">Derived</span></li></ul>
      <hr class="rule">${button('Explore relationships','graph','','relationships')}<p class="small-text">Metadata is shown here. Previewing rows is a separate, explicit read.</p>
    </div></aside></div>`;
}

function cell(row) {
  const {state,value} = row.delay;
  if(state==='value') return `<span class="mono">${value}</span>`;
  const labels = { null:'null',missing:'missing',type_error:'type_error',conflict:'conflict · 2 values' };
  return `<span class="state ${state==='type_error'?'error':state==='conflict'?'conflict':''}">${labels[state]}</span>`;
}
function profile() {
  return `<aside class="panel profile" aria-label="Selected column profile"><div class="eyebrow">Column profile</div><h2 style="margin-top:15px">delay_hours</h2><p class="basis">Projection type · INT64<br>Basis: 100 preview rows at revision r-084</p>
    <div class="segmented-bar" aria-label="82 values, 8 null, 5 missing, 3 type errors, 2 conflicts">${Object.entries(f.counts).map(([state,count])=>`<span class="segment-${state}" style="flex:${count}"></span>`).join('')}</div>
    <div class="state-list">${Object.entries(f.counts).map(([state,count])=>`<div><i class="swatch segment-${state}"></i><span class="mono">${state}</span><b>${count} <span class="muted">&nbsp; ${count}%</span></b></div>`).join('')}</div>
    <hr class="rule"><h3>Value distribution</h3><p class="basis">82 typed values · excludes other states</p>
    <div class="histogram">${f.distribution.map(({count})=>`<div><span>${count}</span><div class="bar" style="height:${count/14*108}px"></div></div>`).join('')}</div><div class="hist-axis">${f.distribution.map(({value})=>`<span>${value}h</span>`).join('')}</div>
    <dl class="facts"><dt>Minimum</dt><dd>12 hours</dd><dt>Maximum</dt><dd>48 hours</dd><dt>Distinct values in preview</dt><dd>6</dd></dl>
    ${notice('<strong>5 cells need interpretation.</strong><br>3 type errors and 2 conflicts. Open a cell to inspect its source values.','bad')}
    <details><summary>Type, encoding and collation</summary><dl class="facts"><dt>Logical type</dt><dd>INT64</dd><dt>Physical encoding</dt><dd>Projection dependent</dd><dt>Collation</dt><dd>Not applicable</dd></dl></details>
    <hr class="rule"><p class="basis">This is a bounded preview, not a whole-dataset profile or a random sample.</p>
  </aside>`;
}
function dataset() {
  return `${crumb('delivery_notes')}${heading('delivery_notes','Collaborative delivery notes and exceptions, viewed through the delivery_status projection.',button('Open in workbook','book','','workbook')+button('Preview 100 rows','play','primary'),'file')}
    <div class="meta-line">${badge('Document')}<span>Object <code>cat:201</code></span><span>Definition <code>d-005</code></span><span>Observed revision <code>r-084</code></span></div>
    ${tabs([['Preview','dataset'],['Relationships','relationships'],['Lineage','lineage']],'Preview','Read-only preview')}
    <div class="toolbar">${button('delivery_status projection','down')}<span class="small-text muted">100 rows received · preview limit reached</span><span class="spacer"></span><button id="profile-toggle" class="button laptop-profile" aria-expanded="false">${icon('panel')}Column profile</button>${button('Refresh preview','refresh','small')}</div>
    <div class="preview-layout" id="preview-layout"><div><div class="panel"><table class="data-grid" aria-label="Delivery notes preview"><thead><tr><th class="row-index">#</th><th>document_id<span class="column-type">STRING</span></th><th>order_id<span class="column-type">INT64</span></th><th class="selected-col">delay_hours ${icon('down')}<span class="column-type">INT64 · projected field</span></th><th>region<span class="column-type">STRING</span></th><th>revision<span class="column-type">Document revision</span></th></tr></thead><tbody>
      ${f.displayedRows.map((row,i)=>`<tr><td class="row-index">${i+1}</td><td class="mono">${row.document}</td><td class="mono">${row.order}</td><td class="selected-col">${cell(row)}</td><td>${row.region}</td><td class="mono">r-${String(row.revision).padStart(3,'0')}</td></tr>`).join('')}
    </tbody></table><div class="table-foot"><span>Showing rows 1–12 of the 100-row preview</span><span>Dataset coverage unknown</span></div></div>
    <p class="below-note">Profiles describe the 100-row preview. A preview limit does not establish the total size of the dataset.</p></div>${profile()}</div>`;
}

function entity(name,style,fields,meta,selected=false) {
  return `<div class="entity ${selected?'selected':''}" data-entity="${name}" style="${style}"><header>${icon('table')}${name}</header><div class="entity-meta">${meta}</div>${fields.map(([field,type,key])=>`<div class="field ${key?'key':''}" data-field="${field}"><span>${field}</span><em>${type}${key?' · KEY':''}</em></div>`).join('')}</div>`;
}
function relationships() {
  return `${crumb('Relationships')}${heading('Relationships','Explore a focused neighborhood. Inspect a join candidate before adding SQL to a workbook.',button('Open workbook','book','','workbook'))}
    ${tabs([['All data','catalog'],['Relationships','relationships'],['Lineage','lineage']],'Relationships','Catalog observation · cat-042')}
    <div class="toolbar">${button('Focus: orders','table')}${button('1 hop','down')}${button('Join candidates visible','eye')}<span class="spacer"></span><span class="small-text muted">3 objects · 2 candidate joins</span></div>
    <div class="canvas-layout"><div class="graph"><div class="graph-top"><span class="graph-title">Schema relationships</span>${badge('Metadata only · no query running')}</div><div class="graph-space">
      <svg class="graph-svg" aria-hidden="true"><path id="join-orders" class="candidate chosen"/><path id="join-warehouse" class="candidate"/></svg>
      ${entity('orders','left:7%;top:7%', [['order_id','INT64',true],['customer_id','INT64'],['warehouse_id','INT64'],['promised_day','INT64'],['amount_cents','INT64'],['region','STRING']], 'cat:101 · d-012',true)}
      ${entity('shipments','left:64%;top:7%', [['shipment_id','INT64',true],['order_id','INT64'],['carrier_code','STRING'],['eta_day','INT64'],['delay_hours','INT64']], 'cat:102 · d-009')}
      ${entity('inventory','left:64%;top:62%', [['warehouse_id','INT64',true],['on_hand_qty','INT64'],['reserved_qty','INT64']], 'cat:103 · d-007')}
      <span id="join-orders-label" class="edge-label">order_id = order_id</span><span id="join-warehouse-label" class="edge-label">warehouse_id = warehouse_id</span>
    </div><div class="graph-legend"><span><i class="line-sample dashed"></i>Join candidate · not a declared foreign key</span><span>Computation dependencies are in Lineage</span></div></div>
    <aside class="panel join-side"><div class="panel-heading"><h2>Join candidate</h2>${icon('link')}</div><div class="detail-body"><h3>orders → shipments</h3><p>Matching names and compatible logical types suggest this path. They do not establish a relationship or its cardinality.</p>${badge('Candidate · not declared')}
    <dl class="facts"><dt>Left field</dt><dd>orders.order_id · INT64</dd><dt>Right field</dt><dd>shipments.order_id · INT64</dd><dt>Cardinality</dt><dd>Not verified</dd></dl><hr class="rule"><h3>SQL to insert</h3><div class="code-box"><pre class="sql sql-small"><span class="kw">SELECT</span> o.order_id,
       s.delay_hours
<span class="kw">FROM</span> orders <span class="kw">AS</span> o
<span class="kw">INNER JOIN</span> shipments <span class="kw">AS</span> s
  <span class="kw">ON</span> o.order_id = s.order_id;</pre></div>
    ${button('Insert into workbook','plus','primary','workbook')}<p class="small-text">Inserts a draft cell. Review the query and run it explicitly.</p>${notice('A compatible join can still multiply rows. Inspect the keys and result before using it in an analysis.')}
    </div></aside></div>`;
}

function workbook() {
  return `${crumb('Workbooks')}${heading('Delivery risk investigation','An explanation, a query and its evidence — together.',badge('Explicit run')+button('History','clock')+button('Share','link'))}
    <div class="meta-line"><span style="border:0;padding:0">Storefront / main</span><span>Current draft saved locally</span><span>Result observations are scoped to each cell</span></div>
    <div class="tabs"><span class="tab active">Workbook</span><span class="tab-right">3 cells · 1 changed draft</span></div>
    <div class="workbook-layout"><div><div class="workbook-narrative"><div class="eyebrow" style="margin-bottom:15px">01 &nbsp; Context</div><h2>Which deliveries need attention?</h2><p>Find orders with a shipment delay above the threshold. Use the result to investigate warehouse capacity before proposing any inventory changes.</p></div>
    <div class="panel"><div class="cell-head"><span class="cell-number">02</span><h3>Delayed shipments</h3>${badge('SQL')}<div class="actions">${button('Run cell','play','primary')}</div></div>
    <div class="cell-editor"><div class="line-numbers">1\n2\n3\n4\n5\n6</div><pre class="sql"><span class="kw">SELECT</span> o.order_id, o.warehouse_id, s.delay_hours
<span class="kw">FROM</span> orders <span class="kw">AS</span> o
<span class="kw">INNER JOIN</span> shipments <span class="kw">AS</span> s <span class="kw">ON</span> o.order_id = s.order_id
<span class="kw">WHERE</span> s.delay_hours &gt; <span class="changed-token">48</span>
<span class="kw">ORDER BY</span> o.order_id;</pre></div>
    <div class="result-banner">${icon('clock')}Earlier result · run-028 used delay_hours &gt; 24. The current draft has not run.</div>
    <div class="result-toolbar"><strong>Table</strong><span class="muted">3 rows · result complete</span><span class="right">${button('Result details','panel','small')}</span></div>
    <table class="result-grid"><thead><tr><th>order_id <span class="muted">· INT64</span></th><th>warehouse_id <span class="muted">· INT64</span></th><th>delay_hours <span class="muted">· INT64</span></th></tr></thead><tbody>${f.result.map(row=>`<tr>${row.map(v=>`<td>${v}</td>`).join('')}</tr>`).join('')}</tbody></table>
    <div class="result-details"><strong>run-028</strong> &nbsp;·&nbsp; Query q-028 &nbsp;·&nbsp; Draft d-017 &nbsp;·&nbsp; Terminal completion received<br>Source observations: orders r-042 + shipments r-038. Independent revisions; no atomic cross-source snapshot claimed.</div></div>
    <div class="cell-next"><span class="cell-number">03</span>${icon('plus')}Add a finding or the next query</div>
    </div><aside class="workbook-aside"><div class="eyebrow">In this workbook</div><ol class="outline"><li>01 &nbsp; Context</li><li class="current">02 &nbsp; Delayed shipments</li><li>03 &nbsp; Next step</li></ol><hr class="rule"><h3>Selected result basis</h3><p>run-028 · the earlier result shown in cell 02</p>
    ${Object.entries(f.basis).map(([name,b])=>`<div class="basis-row"><code>${name}</code><div class="muted">Definition d-${String(b.definition).padStart(3,'0')}<br>Data revision r-${String(b.revision).padStart(3,'0')}</div></div>`).join('')}
    <p>These observations explain this result. Keeping a result in the workbook does not retain its source data.</p><hr class="rule"><h3>Execution</h3><dl class="facts"><dt>Mode</dt><dd>Explicit run</dd><dt>Live session</dt><dd>Off</dd></dl><p>Editing changes the draft. It does not run a query or apply a change.</p>
    </aside></div>`;
}

function flowNode(kind,name,detail,classes='',status='') {
  return `<div class="flow-node ${classes}" data-node="${name}"><div class="eyebrow">${kind}</div><h3>${name}</h3><p>${detail}</p>${status}</div>`;
}
function lineage() {
  return `${crumb('at_risk_deliveries / Lineage')}${heading('at_risk_deliveries','Inspect the dependencies, published result and progress of this maintained view.',button('Open workbook','book','','workbook'))}
    ${tabs([['All data','catalog'],['Relationships','relationships'],['Lineage','lineage']],'Lineage','Observed at 10:42:08 UTC · observation obs-118')}
    <div class="toolbar">${button('Focus: at_risk_deliveries','graph')}${button('Dependencies + consumers','down')}<span class="spacer"></span><span class="small-text muted">Registered dependencies and recorded execution evidence</span></div>
    <div class="lineage-grid"><div class="lineage-canvas"><div class="eyebrow">Selected dependency path</div><div class="flow-lanes"><svg class="flow-svg" aria-hidden="true"><defs><marker id="flow-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 1L9 5L0 9"/></marker></defs><g id="flow-edges"></g></svg>
    <div class="flow-lane"><div class="eyebrow">01 &nbsp; Data</div>${flowNode('Table','orders','Observed data r-042<br>Definition d-012','arrow')}${flowNode('Table','shipments','Observed data r-039<br>Result still uses r-038','arrow',badge('Revision r-039 pending','warn'))}</div>
    <div class="flow-lane"><div class="eyebrow">02 &nbsp; Computation</div>${flowNode('Maintained view','at_risk_deliveries','Last complete result<br>orders r-042 · shipments r-038','selected down',badge('Update pending','warn'))}<div class="flow-label">Reads both tables shown at left</div>${flowNode('Published result','Result v-016','Complete for its recorded basis<br>Latest source revision not included')}</div>
    <div class="flow-lane"><div class="eyebrow">03 &nbsp; Consumers</div>${flowNode('Workbook','Fulfillment overview','Reads published result v-016<br>Observation retained in cell')}${flowNode('Station consumer','allocation_coordinator','Input: result v-016<br>Accepted progress recorded','down')}${flowNode('Recorded effect','dispatch_reallocation','Intent eff-814 recorded<br>Remote outcome unknown','',badge('Outcome unresolved','warn'))}</div>
    </div><div class="flow-bottom">Direction: data → computation → published result → consumers.<br>Only registered and visible dependencies are shown. External readers may not be represented.</div></div>
    <aside class="panel"><div class="panel-heading"><h2>Computation progress</h2>${icon('graph')}</div><div class="detail-body"><h3>at_risk_deliveries</h3><p>Definition d-006 · computation comp:401</p>${badge('Last result complete')}
    <hr class="rule"><h3>Observed source progress</h3><div class="progress-row"><span>orders</span><span class="mono">r-042 → r-042</span><small>Included in the last complete result.</small></div><div class="progress-row"><span>shipments</span><span class="mono">r-038 → r-039</span><small>r-039 observed upstream; not yet included.</small></div>
    <div style="margin-top:24px">${notice('The displayed result is complete for its recorded basis. It is behind the latest observed shipments revision.','warn')}</div><hr class="rule"><h3>Activation evidence</h3><dl class="facts"><dt>Observed log position</dt><dd class="mono">18,410</dd><dt>Consumer progress</dt><dd class="mono">18,409</dd><dt>Next delta</dt><dd>Pending</dd></dl><p>Progress is scoped to this computation and its declared inputs. A recorded effect does not prove remote completion.</p></div></aside></div>`;
}

function branchReview() {
  return `${crumb('Changes / Branch comparison')}${heading('Inventory reallocation','Compare a fixed proposal with main, then inspect the evidence before requesting review.',badge('Change workspace')+button('DDL preview','terminal','','ddl-preview'))}
    <div class="stepper"><span class="current">01 &nbsp; Compare</span><i></i><span>02 &nbsp; Review</span><i></i><span>03 &nbsp; Publish</span><span style="margin-left:auto">Proposal chg-018 · not published</span></div>
    <div class="review-layout"><div><div class="panel"><div class="compare-bar"><div><div class="label">Source branch</div><strong>${icon('branch')} ${f.branches.source}</strong><div class="ref">Fixed head ${f.branches.sourceHead}</div></div>${icon('arrow')}<div><div class="label">Target branch</div><strong>${icon('branch')} main</strong><div class="ref">Fixed head ${f.branches.targetHead} · common base ${f.branches.base}</div></div></div>
    <div class="panel-heading"><h2>Proposed data changes</h2>${badge('2 rows · 1 dataset')}</div><table><thead><tr><th>inventory row</th><th>Field</th><th>main · m-042</th><th>Proposal · m-043</th><th>Change</th></tr></thead><tbody>${f.branches.changes.map(row=>`<tr>${row.map((v,i)=>`<td class="${i===4?'delta':i>1?'mono':''}">${v}</td>`).join('')}</tr>`).join('')}</tbody></table><div class="table-foot"><span>Comparison anchored to source, target and common base</span><span>No merge applied</span></div></div>
    <div class="recent-head" style="margin-top:36px"><h2>Modeled impact</h2>${badge('Scenario run sim-009')}</div><p class="small-text muted">Same evaluation inputs and policy on both branches. These are scenario outputs, not observed delivery outcomes.</p>
    <div class="impact-grid">${f.branches.modeled.map(([label,before,after,delta])=>`<div class="impact"><p>${label}</p><div class="metric"><b class="before">${before}</b>${icon('arrow')}<b>${after}</b></div><span class="positive">↓ ${delta}</span></div>`).join('')}</div>
    <div class="panel"><div class="panel-heading"><h2>Evidence bound to this proposal</h2>${badge('evidence ev-018')}</div><div class="detail-body"><dl class="facts" style="grid-template-columns:220px 1fr;margin:0"><dt>Evaluation</dt><dd style="text-align:left">reallocation_plan · definition d-004</dd><dt>Shared external inputs</dt><dd style="text-align:left">orders r-042 · shipments r-038</dd><dt>Inventory observations</dt><dd style="text-align:left">main m-042 · reallocate-inventory m-043</dd><dt>Publication condition</dt><dd style="text-align:left">Recheck the target head, authority and configured review policy</dd></dl></div></div>
    </div><aside class="panel review-side"><div class="panel-heading"><h2>Review readiness</h2>${icon('eye')}</div><div class="detail-body">${badge('Ready to request review')}<ul class="plain-list"><li>${icon('check')}Source and target observations fixed</li><li>${icon('check')}No conflicts in this comparison</li><li>${icon('check')}Scenario evidence attached</li><li>${icon('clock')}Approval not yet recorded</li></ul><hr class="rule"><h3>Configured policy</h3><p>inventory-review requires one authorized reviewer for this proposal.</p>${notice('If the proposal or target changes, refresh the evidence and satisfy the review policy again.','warn')}${button('Request review','arrow','primary')}<p class="small-text">Requesting review does not publish. Publication is a separate authorized operation.</p></div></aside></div>`;
}

function ddlPreview() {
  return `${crumb('Changes / DDL preview')}${heading('DDL impact preview','Inspect catalog admissibility and registered dependents for this exact statement.',badge('Change workspace')+button('Branch comparison','branch','','branch-review'))}
    <div class="stepper"><span class="current">01 &nbsp; Preview</span><i></i><span>02 &nbsp; Review</span><i></i><span>03 &nbsp; Apply</span><span style="margin-left:auto">main · catalog observation cat-042</span></div>
    <div class="review-layout"><div class="panel"><div class="panel-heading"><h2>Proposed statement</h2>${badge('Draft ddl-007')}</div><div class="ddl-code"><pre class="sql"><span class="kw">DROP TABLE</span> inventory <span class="kw">RESTRICT</span>;</pre></div><div class="ddl-block">
    ${notice('<strong>Blocked by 2 registered dependents.</strong><br>This statement is not admissible against the observed catalog. Nothing has been applied.','bad')}
    <h2>Dependencies that prevent removal</h2>${f.ddl.blockers.map((name,i)=>`<div class="dependency-row"><div><strong>${name}</strong><small>${i?'Registered query · query:204':'Maintained view · comp:402'}</small></div><div>Reads inventory<small>Bound to object cat:103</small></div>${badge('Blocks RESTRICT','bad')}</div>`).join('')}
    <hr class="rule"><h3>Resolve the dependencies</h3><p class="subtitle" style="font-size:14px">Inspect each owner and revise the dependent declarations through their public operations. Then preview this statement again against the new catalog observation.</p><div class="actions" style="margin-top:23px">${button('Inspect lineage','graph','','lineage')}${button('Edit draft','terminal')}</div>
    <hr class="rule"><p class="small-text muted">Dependency analysis covers registered catalog references. It does not discover every external application or guarantee that a later apply will succeed.</p></div></div>
    <aside class="panel review-side"><div class="panel-heading"><h2>Preview evidence</h2>${icon('file')}</div><div class="detail-body"><dl class="facts"><dt>Statement draft</dt><dd class="mono">ddl-007</dd><dt>Catalog observation</dt><dd class="mono">cat-042</dd><dt>Object identity</dt><dd class="mono">cat:103</dd><dt>Definition</dt><dd class="mono">d-007</dd><dt>Admissibility</dt><dd style="color:var(--red)">Blocked</dd></dl><hr class="rule"><h3>Next action</h3><p>Resolve the blocking dependents before requesting approval or applying the statement.</p><button class="button primary" disabled>Apply unavailable · blocked</button><p>Preview is read-only. It does not reserve the catalog state or authorize an administrative operation.</p></div></aside></div>`;
}

const screens = {catalog,dataset,relationships,workbook,lineage,'branch-review':branchReview,'ddl-preview':ddlPreview};
document.getElementById('app').innerHTML = `<header class="topbar"><a class="brand" href="#catalog">${icon('logo')}transit<span>Board</span></a><div class="global-search">${icon('search')}<span>Find data, workbooks and declarations</span><kbd>⌘ K</kbd></div><div class="top-context">${icon('cube')}Storefront<span class="separator"></span>${icon('branch')}main ${icon('down')}</div></header>
  <aside class="sidebar"><div class="nav-label eyebrow">Workspace</div><nav class="nav" aria-label="Workspace"><a href="#catalog" data-nav="catalog">${icon('grid')}Data<span class="number">7</span></a><a href="#workbook" data-nav="workbook">${icon('book')}Workbooks<span class="number">2</span></a><a href="#branch-review" data-nav="changes">${icon('branch')}Changes<span class="number">1</span></a></nav><hr class="nav-rule"><div class="nav-label eyebrow">Explore</div><nav class="nav" aria-label="Explore"><a href="#relationships" data-nav="relationships">${icon('graph')}Relationships</a><a href="#lineage" data-nav="lineage">${icon('link')}Lineage</a></nav><div class="pinned"><div class="nav-label eyebrow">Pinned</div><nav class="nav" aria-label="Pinned objects"><a href="#relationships">${icon('table')}orders</a><a href="#dataset">${icon('file')}delivery_notes</a><a href="#lineage">${icon('graph')}at_risk_deliveries</a></nav></div><div class="sidebar-bottom"><strong id="workspace-mode">${icon('lock')} &nbsp; Inspection workspace</strong><span id="workspace-caption">Read-only access to visible data</span></div></aside>
  <main>${Object.entries(screens).map(([key,render])=>`<section class="screen" id="${key}" aria-label="${key}">${render()}</section>`).join('')}</main>`;

function navigate() {
  const key = location.hash.slice(1) in screens ? location.hash.slice(1) : 'catalog';
  document.querySelectorAll('.screen').forEach(el => el.classList.toggle('active', el.id===key));
  const nav = ['branch-review','ddl-preview'].includes(key)?'changes':key==='dataset'?'catalog':key;
  document.querySelectorAll('[data-nav]').forEach(el => {
    el.classList.toggle('active',el.dataset.nav===nav);
    if(el.dataset.nav===nav) el.setAttribute('aria-current','page'); else el.removeAttribute('aria-current');
  });
  document.querySelector('main').scrollTop=0;
  const queryWorkspace=['workbook','dataset'].includes(key);
  const mode = nav==='changes'?'Change workspace':queryWorkspace?'Query workspace':'Inspection workspace';
  document.getElementById('workspace-mode').innerHTML=`${icon('lock')} &nbsp; ${mode}`;
  document.getElementById('workspace-caption').textContent=nav==='changes'?'Explicit review and publication':queryWorkspace?'Queries run with workspace authority':'Read-only access to visible data';
  document.title=`${key} · Board design D2`;
  window.BOARD_D2_SCREEN=key;
  requestAnimationFrame(drawEdges);
}
function drawEdges() {
  if(window.BOARD_D2_SCREEN==='relationships') {
    const space=document.querySelector('.graph-space').getBoundingClientRect();
    for(const [id,from,to] of [['join-orders','orders.order_id','shipments.order_id'],['join-warehouse','orders.warehouse_id','inventory.warehouse_id']]) {
      const field=key=>{const [entity,column]=key.split('.'); return document.querySelector(`[data-entity="${entity}"] [data-field="${column}"]`).getBoundingClientRect();};
      const a=field(from), b=field(to), x1=a.right-space.left,y1=(a.top+a.bottom)/2-space.top,x2=b.left-space.left,y2=(b.top+b.bottom)/2-space.top;
      const mid=(x1+x2)/2;
      document.getElementById(id).setAttribute('d',`M${x1} ${y1}H${mid}V${y2}H${x2}`);
      const label=document.getElementById(`${id}-label`);
      label.style.left=`${mid-label.offsetWidth/2}px`;
      label.style.top=`${id==='join-orders'?Math.min(y1,y2)-38:(y1+y2)/2}px`;
    }
  }
  if(window.BOARD_D2_SCREEN==='lineage') {
    const space=document.querySelector('.flow-lanes').getBoundingClientRect();
    const connections=[['orders','at_risk_deliveries'],['shipments','at_risk_deliveries'],['at_risk_deliveries','Result v-016','vertical'],['Result v-016','Fulfillment overview'],['Result v-016','allocation_coordinator'],['allocation_coordinator','dispatch_reallocation','vertical']];
    document.getElementById('flow-edges').innerHTML=connections.map(([from,to,direction])=>{
      const a=document.querySelector(`[data-node="${from}"]`).getBoundingClientRect(), b=document.querySelector(`[data-node="${to}"]`).getBoundingClientRect();
      if(direction==='vertical') {
        const x=(a.left+a.right)/2-space.left,y=a.bottom-space.top,end=b.top-space.top-2;
        return `<path d="M${x} ${y}V${end}"/>`;
      }
      const x1=a.right-space.left,y1=(a.top+a.bottom)/2-space.top,x2=b.left-space.left-2,y2=(b.top+b.bottom)/2-space.top,mid=(x1+x2)/2;
      return `<path d="M${x1} ${y1}H${mid}V${y2}H${x2}"/>`;
    }).join('');
  }
}
window.addEventListener('hashchange',navigate);
window.addEventListener('resize',drawEdges);
document.fonts.ready.then(drawEdges);
navigate();
document.getElementById('catalog-filter').addEventListener('input',event=>{
  let count=0;
  document.querySelectorAll('#catalog-rows tr').forEach(row=>{
    const matches=row.dataset.search.toLowerCase().includes(event.target.value.toLowerCase());
    row.hidden=!matches; if(matches)count++;
  });
  document.getElementById('catalog-count').textContent=`${count} objects visible to this workspace`;
});
document.getElementById('profile-toggle').addEventListener('click',event=>{
  const open=document.getElementById('preview-layout').classList.toggle('profile-open');
  event.currentTarget.setAttribute('aria-expanded',String(open));
});
let toastTimer;
document.addEventListener('click',event=>{
  const target=event.target.closest('[data-note]');
  if(!target)return;
  document.querySelector('.toast')?.remove();
  const toast=document.createElement('div'); toast.className='toast'; toast.setAttribute('role','status'); toast.textContent=target.dataset.note;
  document.body.append(toast); clearTimeout(toastTimer); toastTimer=setTimeout(()=>toast.remove(),4500);
});
