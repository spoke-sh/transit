CREATE INTERFACE board WITH (realm = 49, revision = 18446744073709551615,
  components = 1, entry = 'atlas', theme = 'mono');
CREATE THEME board.mono WITH (density = 'comfortable');
CREATE THEME board.dense WITH (density = 'compact');
CREATE BINDING board.catalog WITH (kind = 'inspection', projection = 'atlas', page_budget = 1);
CREATE BINDING board.items WITH (kind = 'query', resource = 7, source = 'items', source_kind = 'table',
  schema = '0000000000000000000000000000000000000000000000000000000000000000',
  profile = 'unified_v2', query = 'SELECT id, value FROM items', refresh = 'follow', starts = 8);
CREATE BINDING board.update WITH (kind = 'command', service = 1, target = 9, revision = 1, codec = 1);
CREATE SCREEN board.atlas WITH (path = '/atlas', label = 'Atlas', area = 'workspace', renderer = 'atlas', binding = 'catalog');
CREATE SCREEN board.explore WITH (path = '/explore', label = 'Explore', area = 'workspace', renderer = 'worksheet', binding = 'items');
CREATE ACTION board.open WITH (label = 'Open Explore', kind = 'navigate', target = 'explore');
CREATE ACTION board.follow WITH (label = 'Follow changes', kind = 'follow', target = 'items');
CREATE ACTION board.apply WITH (label = 'Apply reviewed change', kind = 'command', target = 'update');
