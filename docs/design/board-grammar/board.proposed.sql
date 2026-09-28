-- PROPOSAL ONLY. None of this file is executable Transit SQL.
-- INTERFACE / SCREEN / BINDING / ACTION / THEME are missing grammar.
-- Projection/operation names and options are synthetic design vocabulary.
-- M23 must version typed owners, capabilities, conditional publication and
-- authorization before adding these statements to the checked grammar.
-- This program describes composition; it does not provision grants, values,
-- listeners, schemas or arbitrary code, and does not execute on import.

CREATE THEME mono WITH (surface = 'white', ink = 'black', spacing_unit = 8,
  requires_semantic_profile = 'board_grammar_v1');
CREATE INTERFACE board WITH (theme = 'mono', shell = 'transit_console',
  entry = 'workspace.atlas', contract_version = 1);

CREATE SCREEN board.workspace.atlas WITH (label = 'Atlas',
  path = '/workspace/atlas', renderer = 'atlas', binding = 'atlas');
CREATE BINDING board.atlas WITH (kind = 'inspection', projection = 'board.catalog',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.workspace.explore WITH (label = 'Explore',
  path = '/workspace/explore', renderer = 'worksheet', binding = 'explore');
CREATE BINDING board.explore WITH (kind = 'finite_query', source = 'query.items',
  query = 'SELECT id, value FROM items LIMIT 32', profile = 'qualified_source',
  initial_admission = 'explicit', refresh = 'snapshot', page_budget = 1);

CREATE SCREEN board.workspace.connections WITH (label = 'Connections',
  path = '/workspace/connections', renderer = 'definition_collection', binding = 'connections');
CREATE BINDING board.connections WITH (kind = 'inspection', projection = 'catalog.connections',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.workspace.sources WITH (label = 'Sources',
  path = '/workspace/sources', renderer = 'definition_collection', binding = 'sources');
CREATE BINDING board.sources WITH (kind = 'inspection', projection = 'catalog.sources',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.workspace.sinks WITH (label = 'Sinks',
  path = '/workspace/sinks', renderer = 'definition_collection', binding = 'sinks');
CREATE BINDING board.sinks WITH (kind = 'inspection', projection = 'catalog.sinks',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.workspace.activity WITH (label = 'Activity',
  path = '/workspace/activity', renderer = 'evidence_sequence', binding = 'activity');
CREATE BINDING board.activity WITH (kind = 'inspection', projection = 'operations.receipts',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.operations.overview WITH (label = 'Overview',
  path = '/operations/overview', renderer = 'dependency_list', binding = 'overview');
CREATE BINDING board.overview WITH (kind = 'inspection', projection = 'operations.foundations',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.operations.access WITH (label = 'Access',
  path = '/operations/access', renderer = 'definition_collection', binding = 'access');
CREATE BINDING board.access WITH (kind = 'inspection', projection = 'security.metadata',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.operations.secrets_trust WITH (label = 'Secrets & trust',
  path = '/operations/secrets_trust', renderer = 'definition_collection', binding = 'secrets_trust');
CREATE BINDING board.secrets_trust WITH (kind = 'inspection', projection = 'security.secret_trust_metadata',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.operations.capabilities WITH (label = 'Capabilities',
  path = '/operations/capabilities', renderer = 'capability_list', binding = 'capabilities');
CREATE BINDING board.capabilities WITH (kind = 'inspection', projection = 'services.capabilities',
  refresh = 'snapshot', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.operations.runtime_storage WITH (label = 'Runtime & storage',
  path = '/operations/runtime_storage', renderer = 'evidence_list', binding = 'runtime_storage');
CREATE BINDING board.runtime_storage WITH (kind = 'inspection', projection = 'runtime.observations',
  refresh = 'follow_changes', require_advertised_capability = true, page_budget = 1);

CREATE SCREEN board.operations.diagnostics WITH (label = 'Diagnostics',
  path = '/operations/diagnostics', renderer = 'signal_list', binding = 'diagnostics');
CREATE BINDING board.diagnostics WITH (kind = 'inspection', projection = 'telemetry.observations',
  refresh = 'snapshot', require_advertised_capability = true, page_budget = 1);

-- Capability names identify required checks; declarations confer no rights.
CREATE ACTION board.run_query WITH (screen = 'workspace.explore',
  operation = 'query.submit', trigger = 'explicit', authority = 'query');
CREATE ACTION board.follow_changes WITH (screen = 'workspace.explore',
  operation = 'view.follow', trigger = 'explicit', requires = 'qualified_watch');
CREATE ACTION board.apply_change WITH (operation = 'definitions.apply',
  trigger = 'explicit_review', authority = 'attributable_operator',
  expected_revision = 'required', recovery = 'same_operation');

-- The migration plan conditionally publishes a validated interface revision.
-- No generic APPLY, implicit reconciliation, continuous query or safe inverse
-- is supplied by these candidate CREATE statements. See REACTIVE_APPLICATIONS.md.
