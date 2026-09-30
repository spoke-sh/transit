-- Artifact proposal. Provisioning binds the actual resource and complete UQS2
-- contract before conditional publication; this file is never a read fallback.
CREATE INTERFACE work_items WITH (realm = 51, revision = 1, components = 1, entry = 'items', theme = 'mono');
CREATE THEME work_items.mono WITH (density = 'comfortable');
CREATE THEME work_items.dense WITH (density = 'compact');
CREATE BINDING work_items.items WITH (kind = 'query', resource = 1, source = 'items', source_kind = 'table',
  schema = '0000000000000000000000000000000000000000000000000000000000000000',
  profile = 'unified_v1', query = 'SELECT * FROM items LIMIT 32', refresh = 'snapshot', starts = 1);
CREATE BINDING work_items.catalog WITH (kind = 'inspection', projection = 'atlas', page_budget = 1);
CREATE SCREEN work_items.items WITH (path = '/items', label = 'Work items', area = 'workspace', renderer = 'work_items', binding = 'items');
CREATE SCREEN work_items.definition WITH (path = '/definition', label = 'Definition', area = 'operations', renderer = 'definition', binding = 'catalog');
CREATE ACTION work_items.open WITH (label = 'Open work items', kind = 'navigate', target = 'items');
