// Synthetic design inputs only. No service responses, private data or timings.
(() => {
  const rows = Array.from({ length: 24 }, (_, i) => ({
    id: 'S-' + String(401 + i),
    order: 'O-' + String(8101 + i),
    delay: i < 22 ? i * 3 : null,
    region: ['North', 'West', 'Central'][i % 3],
    status: i < 22 ? 'Received' : 'Awaiting scan',
  }));
  const values = rows.flatMap(row => row.delay === null ? [] : [row.delay]);
  const bins = Array.from({ length: 6 }, (_, i) => ({
    label: (i * 12) + '–' + (i * 12 + 11),
    count: values.filter(value => value >= i * 12 && value < (i + 1) * 12).length,
  }));
  window.BOARD_D3_FIXTURE = {
    rows,
    profile: {
      population: rows.length, values: values.length, nulls: rows.length - values.length,
      minimum: Math.min(...values), maximum: Math.max(...values),
      distinct: new Set(values).size, bins,
    },
    sql: 'SELECT region, COUNT(*) AS shipments\nFROM public.shipments\nGROUP BY region;',
    result: [['North', 15], ['West', 18], ['Central', 9]],
    storage: { reachableMiB: 64, sharedMiB: 52, exclusiveMiB: 12 },
    changes: [
      { id: 'S-418', field: 'delay_minutes', kind: 'Conflict', base: '12', source: '18', target: '24' },
      { id: 'S-409', field: 'region', kind: 'Modified', base: 'North', source: 'West', target: 'North' },
      { id: 'S-425', field: 'shipment_id', kind: 'Added', base: 'Absent', source: 'S-425', target: 'Absent' },
      { id: 'S-402', field: 'shipment_id', kind: 'Removed', base: 'S-402', source: 'Absent', target: 'S-402' },
    ],
  };
})();
