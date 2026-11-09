-- Fresh tenancy baseline. Define objects in their owning schema from the start.
CREATE SCHEMA tenancy AUTHORIZATION SETTING('schemas.tenancy_owner');
GRANT USAGE ON SCHEMA tenancy TO ROLE SETTING('tenancy.executor_role');
GRANT USAGE ON SCHEMA tenancy TO ROLE SETTING('deployments.executor_role');
GRANT USAGE ON SCHEMA tenancy TO ROLE SETTING('tenancy.reader_role');

-- Explicit onboarding. OAuth establishes identity; this program grants only
-- the scope the eligible original caller deliberately creates (#100).
CREATE TABLE tenancy.organizations (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  authority OBJECT_ID NOT NULL UNIQUE,
  created_by SUBJECT_ID NOT NULL,
  revision BIGINT NOT NULL CHECK (revision > 0)
);

CREATE TABLE tenancy.projects (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL REFERENCES tenancy.organizations(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  authority OBJECT_ID NOT NULL UNIQUE,
  revision BIGINT NOT NULL CHECK (revision > 0),
  UNIQUE (organization_id, name)
);

CREATE TABLE tenancy.environments (
  id UUID PRIMARY KEY,
  project_id UUID NOT NULL REFERENCES tenancy.projects(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  authority OBJECT_ID NOT NULL UNIQUE,
  revision BIGINT NOT NULL CHECK (revision > 0),
  UNIQUE (project_id, name)
);

CREATE TABLE tenancy.memberships (
  organization_id UUID NOT NULL REFERENCES tenancy.organizations(id) ON DELETE RESTRICT,
  subject SUBJECT_ID NOT NULL,
  grant_ref GRANT_ID NOT NULL,
  PRIMARY KEY (organization_id, subject)
);

CREATE DATAFLOW tenancy.create_owned_scope
  FROM COMMAND (
    name TEXT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    REQUIRE LENGTH(request.name) BETWEEN 1 AND 120 ELSE 'InvalidName';
    REQUIRE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'onboard', SETTING('tenancy.onboarding_resource'))
      ELSE 'Forbidden';
    LET id = OPERATION_ID(CURRENT_REQUEST_ID(), 'organization');
    LET object = ALLOCATE AUTHORIZATION OBJECT 'platform.organization' ID id;
    LET grant = GRANT ACTIONS ('inspect', 'create_project', 'manage_membership', 'rename', 'delete')
      ON OBJECT object TO SUBJECT CURRENT_SUBJECT();
    INSERT INTO tenancy.organizations VALUES (id, request.name, object, CURRENT_SUBJECT(), 1);
    INSERT INTO tenancy.memberships VALUES (id, CURRENT_SUBJECT(), grant);
    RETURN JSON_OBJECT('id', id, 'revision', 1);
  END;

CREATE DATAFLOW tenancy.create_project
  FROM COMMAND (
    organization_id UUID,
    expected_revision BIGINT,
    name TEXT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET parent = SELECT * FROM tenancy.organizations WHERE id = request.organization_id;
    REQUIRE parent IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'create_project', parent.authority)
      ELSE 'Forbidden';
    REQUIRE parent.revision = request.expected_revision ELSE 'StaleTarget';
    REQUIRE LENGTH(request.name) BETWEEN 1 AND 120 ELSE 'InvalidName';
    LET id = OPERATION_ID(CURRENT_REQUEST_ID(), 'project');
    LET object = ALLOCATE AUTHORIZATION OBJECT 'platform.project' ID id PARENT parent.authority;
    GRANT ACTIONS ('inspect', 'create_environment', 'rename', 'delete')
      ON OBJECT object TO SUBJECT CURRENT_SUBJECT();
    INSERT INTO tenancy.projects VALUES (id, parent.id, request.name, object, 1);
    RETURN JSON_OBJECT('id', id, 'revision', 1);
  END;

CREATE DATAFLOW tenancy.create_environment
  FROM COMMAND (
    project_id UUID,
    expected_revision BIGINT,
    name TEXT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET parent = SELECT * FROM tenancy.projects WHERE id = request.project_id;
    REQUIRE parent IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'create_environment', parent.authority)
      ELSE 'Forbidden';
    REQUIRE parent.revision = request.expected_revision ELSE 'StaleTarget';
    REQUIRE LENGTH(request.name) BETWEEN 1 AND 120 ELSE 'InvalidName';
    LET id = OPERATION_ID(CURRENT_REQUEST_ID(), 'environment');
    LET object = ALLOCATE AUTHORIZATION OBJECT 'platform.environment' ID id PARENT parent.authority;
    GRANT ACTIONS ('inspect', 'register_instance', 'create_network', 'create_static_application', 'manage_domains', 'rename', 'delete')
      ON OBJECT object TO SUBJECT CURRENT_SUBJECT();
    INSERT INTO tenancy.environments VALUES (id, parent.id, request.name, object, 1);
    RETURN JSON_OBJECT('id', id, 'revision', 1);
  END;

-- Names are mutable labels; scope IDs and native authorization objects survive.
CREATE VIEW tenancy.scope_objects AS
  SELECT 'organization' AS kind, id, NULL AS parent_id, name, authority, revision FROM tenancy.organizations
  UNION ALL SELECT 'project', id, organization_id, name, authority, revision FROM tenancy.projects
  UNION ALL SELECT 'environment', id, project_id, name, authority, revision FROM tenancy.environments;

CREATE DATAFLOW tenancy.rename_scope
  FROM COMMAND (
    kind TEXT,
    id UUID,
    expected_revision BIGINT,
    name TEXT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET scope = SELECT * FROM tenancy.scope_objects WHERE kind = request.kind AND id = request.id;
    REQUIRE scope IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'rename', scope.authority) ELSE 'Forbidden';
    REQUIRE scope.revision = request.expected_revision ELSE 'StaleTarget';
    REQUIRE LENGTH(request.name) BETWEEN 1 AND 120 ELSE 'InvalidName';
    CASE request.kind
      WHEN 'organization' THEN UPDATE tenancy.organizations SET name = request.name, revision = revision + 1 WHERE id = scope.id;
      WHEN 'project' THEN UPDATE tenancy.projects SET name = request.name, revision = revision + 1 WHERE id = scope.id;
      WHEN 'environment' THEN UPDATE tenancy.environments SET name = request.name, revision = revision + 1 WHERE id = scope.id;
    END CASE;
    RETURN JSON_OBJECT('id', scope.id, 'revision', scope.revision + 1);
  END;

CREATE DATAFLOW tenancy.delete_empty_scope
  FROM COMMAND (
    kind TEXT,
    id UUID,
    expected_revision BIGINT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET scope = SELECT * FROM tenancy.scope_objects WHERE kind = request.kind AND id = request.id;
    REQUIRE scope IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'delete', scope.authority) ELSE 'Forbidden';
    REQUIRE scope.revision = request.expected_revision ELSE 'StaleTarget';
    -- RESTRICT covers projects/environments and the dependent fabric resources.
    -- Any refusal aborts the entire transaction, including authority retirement.
    CASE request.kind
      WHEN 'organization' THEN
        DELETE FROM tenancy.memberships WHERE organization_id = scope.id;
        DELETE FROM tenancy.organizations WHERE id = scope.id;
      WHEN 'project' THEN DELETE FROM tenancy.projects WHERE id = scope.id;
      WHEN 'environment' THEN DELETE FROM tenancy.environments WHERE id = scope.id;
    END CASE;
    RETIRE AUTHORIZATION OBJECT scope.authority RETAIN RECEIPTS;
    RETURN JSON_OBJECT('id', scope.id, 'outcome', 'deleted');
  END;

-- Complete, paged reads recheck current native rights at disclosure. Membership
-- is product metadata; neither it nor a cached projection decides access.
CREATE PUBLICATION tenancy.scopes AS
  SELECT kind, id, parent_id, name, revision
  FROM tenancy.scope_objects WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('tenancy.reader_role'),
    response_profile = 'platform.scopes.v1',
    page_size = 64,
    order_by = 'kind,id',
    snapshot_path = '/platform/v1/scopes',
    key_columns = JSON '["kind","id"]',
    item_path = '/platform/v1/scopes/{kind}/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );

AUTHORIZE DATAFLOW tenancy.create_owned_scope AS ROLE SETTING('tenancy.executor_role');
AUTHORIZE DATAFLOW tenancy.create_project AS ROLE SETTING('tenancy.executor_role');
AUTHORIZE DATAFLOW tenancy.create_environment AS ROLE SETTING('tenancy.executor_role');
AUTHORIZE PUBLICATION tenancy.scopes;
ACTIVATE DATAFLOW tenancy.create_owned_scope;
ACTIVATE DATAFLOW tenancy.create_project;
ACTIVATE DATAFLOW tenancy.create_environment;
ACTIVATE PUBLICATION tenancy.scopes;

AUTHORIZE DATAFLOW tenancy.rename_scope AS ROLE SETTING('tenancy.executor_role');
AUTHORIZE DATAFLOW tenancy.delete_empty_scope AS ROLE SETTING('tenancy.executor_role');
ACTIVATE DATAFLOW tenancy.rename_scope;
ACTIVATE DATAFLOW tenancy.delete_empty_scope;

-- HTTP invokes the installed command under the original authenticated subject.
-- The native command_json_v1 profile owns strict decoding, request identity,
-- current-session/grant checks and retained results; it contains no product policy.
-- GET result_path observes the original result and never invokes the command.
CREATE SOURCE tenancy.create_owned_scope_http
  FROM HTTP REQUEST
  INTO COMMAND tenancy.create_owned_scope
  WITH (
    method = 'POST',
    path = '/platform/v1/organizations',
    path_arguments = JSON '[]',
    body_arguments = JSON '["name"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/tenancy.create_owned_scope/{request_id}',
    response_status = 201,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE tenancy.create_project_http
  FROM HTTP REQUEST
  INTO COMMAND tenancy.create_project
  WITH (
    method = 'POST',
    path = '/platform/v1/organizations/{organization_id}/projects',
    path_arguments = JSON '["organization_id"]',
    body_arguments = JSON '["expected_revision","name"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/tenancy.create_project/{request_id}',
    response_status = 201,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE tenancy.create_environment_http
  FROM HTTP REQUEST
  INTO COMMAND tenancy.create_environment
  WITH (
    method = 'POST',
    path = '/platform/v1/projects/{project_id}/environments',
    path_arguments = JSON '["project_id"]',
    body_arguments = JSON '["expected_revision","name"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/tenancy.create_environment/{request_id}',
    response_status = 201,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE tenancy.rename_scope_http
  FROM HTTP REQUEST
  INTO COMMAND tenancy.rename_scope
  WITH (
    method = 'PATCH',
    path = '/platform/v1/scopes/{kind}/{id}',
    path_arguments = JSON '["kind","id"]',
    body_arguments = JSON '["expected_revision","name"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/tenancy.rename_scope/{request_id}',
    response_status = 200,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE tenancy.delete_empty_scope_http
  FROM HTTP REQUEST
  INTO COMMAND tenancy.delete_empty_scope
  WITH (
    method = 'DELETE',
    path = '/platform/v1/scopes/{kind}/{id}',
    path_arguments = JSON '["kind","id"]',
    body_arguments = JSON '["expected_revision"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/tenancy.delete_empty_scope/{request_id}',
    response_status = 200,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

-- Route activation follows command authorization and activation. It grants no
-- caller rights; the dataflows still enforce their own current native authority.
AUTHORIZE SOURCE tenancy.create_owned_scope_http AS ROLE SETTING('tenancy.executor_role');
AUTHORIZE SOURCE tenancy.create_project_http AS ROLE SETTING('tenancy.executor_role');
AUTHORIZE SOURCE tenancy.create_environment_http AS ROLE SETTING('tenancy.executor_role');
AUTHORIZE SOURCE tenancy.rename_scope_http AS ROLE SETTING('tenancy.executor_role');
AUTHORIZE SOURCE tenancy.delete_empty_scope_http AS ROLE SETTING('tenancy.executor_role');
ACTIVATE SOURCE tenancy.create_owned_scope_http;
ACTIVATE SOURCE tenancy.create_project_http;
ACTIVATE SOURCE tenancy.create_environment_http;
ACTIVATE SOURCE tenancy.rename_scope_http;
ACTIVATE SOURCE tenancy.delete_empty_scope_http;
