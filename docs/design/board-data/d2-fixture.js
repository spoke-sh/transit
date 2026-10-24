/* Synthetic design data. These are not observations of a Transit deployment. */
window.BOARD_D2 = (() => {
  const states = [
    'value','value','value','null','value','missing',
    'value','type_error','value','conflict','value','value',
    ...Array(74).fill('value'), ...Array(7).fill('null'),
    ...Array(4).fill('missing'), ...Array(2).fill('type_error'), 'conflict',
  ];
  let valueIndex = 0;
  const rows = states.map((state, i) => ({
    document: `note_${String(i + 1).padStart(4, '0')}`,
    order: 1004 + i,
    delay: { state, value: state === 'value' ? [12, 18, 24, 30, 36, 48][valueIndex++ % 6] : null },
    region: ['West', 'East', 'Central'][i % 3],
    revision: 84,
  }));
  const counts = Object.fromEntries(['value', 'null', 'missing', 'type_error', 'conflict']
    .map(state => [state, rows.filter(row => row.delay.state === state).length]));
  const distribution = [12, 18, 24, 30, 36, 48].map(value => ({
    value, count: rows.filter(row => row.delay.state === 'value' && row.delay.value === value).length,
  }));
  return {
    synthetic: true,
    realm: 'Storefront',
    catalogObservation: 'cat-042',
    rows, counts, distribution,
    displayedRows: rows.slice(0,12),
    assets: [
      ['orders', 'Table', 'Customer orders and delivery commitments', '12', '42', '4'],
      ['shipments', 'Table', 'Carrier assignments and delivery estimates', '9', '38', '3'],
      ['inventory', 'Table', 'Available and reserved stock by warehouse', '7', '42', '2'],
      ['supplier_ledger', 'Foreign table', 'Declared mainframe inventory projection', '4', '—', '1'],
      ['delivery_notes', 'Document', 'Collaborative delivery notes and exceptions', '5', '84', '1'],
      ['carrier_quotes', 'Key-value', 'Carrier responses with an explicit decoder', '3', '17', '1'],
      ['at_risk_deliveries', 'Maintained view', 'Orders whose shipment delay exceeds 24 hours', '6', '—', '2'],
    ],
    result: [[1004, 12, 36], [1019, 12, 48], [1042, 18, 29]],
    basis: { orders: { definition: 12, revision: 42 }, shipments: { definition: 9, revision: 38 } },
    branches: {
      source: 'reallocate-inventory', target: 'main', base: 'm-040', sourceHead: 'm-043', targetHead: 'm-042',
      changes: [
        ['warehouse / 12', 'reserved_qty', '120', '90', '−30'],
        ['warehouse / 18', 'reserved_qty', '40', '70', '+30'],
      ],
      modeled: [['At-risk deliveries', '14', '5', '9 fewer'], ['Exposure · USD', '428.00', '112.00', '316.00 lower']],
    },
    ddl: { sql: 'DROP TABLE inventory RESTRICT;', blockers: ['warehouse_coverage', 'reallocation_plan'] },
  };
})();
