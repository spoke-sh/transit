-- Native contract and qualification: contracts/fabric-resources-v1.md; Platform #130.
-- Networks are fabric resources owned directly by an environment.
CREATE SCHEMA networking AUTHORIZATION SETTING('schemas.networking_owner');
GRANT USAGE ON SCHEMA networking TO ROLE SETTING('networking.executor_role');
GRANT USAGE ON SCHEMA networking TO ROLE SETTING('networking.effect_role');
GRANT USAGE ON SCHEMA networking TO ROLE SETTING('networking.reader_role');
GRANT USAGE ON SCHEMA networking TO ROLE SETTING('deployments.executor_role');
GRANT USAGE ON SCHEMA networking TO ROLE SETTING('publication.executor_role');
GRANT USAGE ON SCHEMA tenancy TO ROLE SETTING('networking.executor_role');

-- Operators qualify these immutable artifacts and connector scopes before use.
CREATE DOCUMENT networking.profiles (
  id UUID PRIMARY KEY,
  authority OBJECT_ID NOT NULL,
  provider TEXT NOT NULL,
  cloud_account TEXT NOT NULL,
  region TEXT NOT NULL,
  connection_ref CONNECTION_ID NOT NULL,
  certificate_connection_ref CONNECTION_ID NOT NULL,
  network_template ARTIFACT NOT NULL,
  network_template_sha256 BINARY NOT NULL,
  endpoint_template ARTIFACT NOT NULL,
  endpoint_template_sha256 BINARY NOT NULL,
  role_ref TEXT NOT NULL,
  network_limit BIGINT NOT NULL CHECK (network_limit > 0),
  endpoint_limit BIGINT NOT NULL CHECK (endpoint_limit > 0),
  domain_limit BIGINT NOT NULL CHECK (domain_limit > 0),
  enabled BOOLEAN NOT NULL
) WITH (profile = 'versioned', write_authority = SETTING('networking.operator_role'));

CREATE TABLE networking.networks (
  id UUID PRIMARY KEY,
  environment_id UUID NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  authority OBJECT_ID NOT NULL UNIQUE,
  profile_id UUID NOT NULL,
  profile_revision BINARY NOT NULL,
  placement PLACEMENT NOT NULL,
  cidr TEXT NOT NULL,
  revision BIGINT NOT NULL,
  generation BIGINT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('absent', 'ready', 'retired')),
  deletion_protected BOOLEAN NOT NULL,
  active_operation UUID,
  binding RESOURCE_BINDING,
  UNIQUE (environment_id, name)
);

-- A retained attachment is a dependency, never an implicit data-plane grant.
-- Instances release it only after verified purge; HTTPS endpoints after withdrawal.
CREATE TABLE networking.attachments (
  network_id UUID NOT NULL REFERENCES networking.networks(id) ON DELETE RESTRICT,
  consumer_id UUID NOT NULL,
  consumer_kind TEXT NOT NULL CHECK (consumer_kind IN ('transit_instance', 'endpoint')),
  released BOOLEAN NOT NULL,
  PRIMARY KEY (network_id, consumer_id)
);

-- Endpoint dependencies are retained until exact withdrawal is verified.
CREATE TABLE networking.target_holds (
  target_id UUID NOT NULL,
  target_kind TEXT NOT NULL CHECK (target_kind IN ('transit_instance', 'static_application')),
  endpoint_id UUID NOT NULL UNIQUE,
  mutating BOOLEAN NOT NULL,
  released BOOLEAN NOT NULL,
  PRIMARY KEY (target_id, endpoint_id)
);

CREATE TABLE networking.network_operations (
  id UUID PRIMARY KEY,
  network_id UUID NOT NULL REFERENCES networking.networks(id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN ('provision', 'retire')),
  generation BIGINT NOT NULL,
  subject SUBJECT_ID NOT NULL,
  native_ref OPERATION NOT NULL UNIQUE
) WITH (immutable = TRUE);

CREATE QUEUE networking.network_work (
  operation_id UUID NOT NULL
) WITH (active_leases = 8, max_attempts = 1);

CREATE DATAFLOW networking.create_network
  FROM COMMAND (
    environment_id UUID,
    expected_revision BIGINT,
    name TEXT,
    cidr TEXT,
    profile_id UUID,
    profile_revision BINARY,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET env = SELECT * FROM tenancy.environments WHERE id = request.environment_id;
    LET profile = SELECT * FROM networking.profiles WHERE id = request.profile_id;
    REQUIRE env IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'create_network', env.authority)
      AND profile IS NOT NULL AND profile.enabled AND profile.provider = 'aws'
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', profile.authority) ELSE 'Forbidden';
    REQUIRE env.revision = request.expected_revision AND profile._revision = request.profile_revision ELSE 'StaleTarget';
    REQUIRE LENGTH(request.name) BETWEEN 1 AND 120 AND PRIVATE_IPV4_CIDR_VALID(request.cidr) ELSE 'InvalidRequest';
    REQUIRE ARTIFACT_VERIFIED(profile.network_template, profile.network_template_sha256)
      AND AWS_NETWORK_TEMPLATE_VALID(profile.network_template, 'spoke.network.aws.v1') ELSE 'UnqualifiedProfile';
    -- Serializable admission includes uncertain creations; observations never admit quota.
    REQUIRE (SELECT COUNT(*) FROM networking.networks WHERE profile_id = profile.id AND state <> 'retired')
      < profile.network_limit ELSE 'CapacityExceeded';
    LET digest = DIGEST(ROW(env.id, env.revision, request.name, request.cidr, profile.id, profile._revision));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), env.authority,
      'create_network', digest, env.revision) ELSE 'Forbidden';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'network');
    LET object = ALLOCATE AUTHORIZATION OBJECT 'platform.network' ID command_id PARENT env.authority;
    GRANT ACTIONS ('inspect', 'use', 'retire', 'protect') ON OBJECT object TO SUBJECT CURRENT_SUBJECT();
    LET placement = BIND PLACEMENT profile.provider ACCOUNT profile.cloud_account REGION profile.region
      CONNECTION profile.connection_ref ROLE profile.role_ref TEMPLATE profile.network_template_sha256;
    LET operation_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'network-operation');
    LET operation = ACCEPT OPERATION operation_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET command_id REVISION 0;
    INSERT INTO networking.networks VALUES (command_id, env.id, request.name, object, profile.id, profile._revision,
      placement, request.cidr, 1, 1, 'absent', TRUE, operation_id, NULL);
    INSERT INTO networking.network_operations VALUES (operation_id, command_id, 'provision', 1, CURRENT_SUBJECT(), operation);
    ENQUEUE INTO networking.network_work VALUES (operation_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', command_id, 'revision', 1, 'operation_id', operation_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE DATAFLOW networking.protect_network
  FROM COMMAND (
    network_id UUID,
    expected_revision BIGINT,
    protected BOOLEAN
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET network = SELECT * FROM networking.networks WHERE id = request.network_id;
    REQUIRE network IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'protect', network.authority) ELSE 'Forbidden';
    REQUIRE network.revision = request.expected_revision ELSE 'StaleTarget';
    UPDATE networking.networks SET deletion_protected = request.protected, revision = revision + 1 WHERE id = network.id;
    RETURN JSON_OBJECT('id', network.id, 'revision', network.revision + 1, 'protected', request.protected);
  END;

CREATE DATAFLOW networking.retire_network
  FROM COMMAND (
    network_id UUID,
    expected_revision BIGINT,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET network = SELECT * FROM networking.networks WHERE id = request.network_id;
    REQUIRE network IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'retire', network.authority) ELSE 'Forbidden';
    REQUIRE network.revision = request.expected_revision AND network.active_operation IS NULL
      AND network.state = 'ready' ELSE 'StaleTarget';
    REQUIRE NOT network.deletion_protected ELSE 'DeletionProtected';
    REQUIRE NOT EXISTS (SELECT 1 FROM networking.attachments WHERE network_id = network.id AND NOT released)
      ELSE 'Referenced';
    LET digest = DIGEST(ROW(network.id, network.revision, 'retire'));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), network.authority,
      'retire', digest, network.revision) ELSE 'Forbidden';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'network-operation');
    LET operation = ACCEPT OPERATION command_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET network.id REVISION network.revision;
    INSERT INTO networking.network_operations VALUES (command_id, network.id, 'retire', network.generation + 1,
      CURRENT_SUBJECT(), operation);
    UPDATE networking.networks SET active_operation = command_id, revision = revision + 1, generation = generation + 1
      WHERE id = network.id;
    ENQUEUE INTO networking.network_work VALUES (command_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', network.id, 'revision', network.revision + 1,
      'operation_id', command_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE VIEW networking.current_network_operations AS
  SELECT o.id FROM networking.network_operations o JOIN networking.networks n ON n.id = o.network_id
  JOIN networking.profiles p ON p.id = n.profile_id
  WHERE n.active_operation = o.id AND n.generation = o.generation AND NATIVE_OPERATION_CURRENT(o.native_ref)
    AND p.enabled AND p._revision = n.profile_revision AND NATIVE_ALLOWED(o.subject, 'use', p.authority)
    AND (o.action <> 'retire' OR (NOT n.deletion_protected
      AND NOT EXISTS (SELECT 1 FROM networking.attachments a WHERE a.network_id = n.id AND NOT a.released)));

CREATE SINK networking.create_stack INTO AWS OPERATION 'cloudformation:CreateStack'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');
CREATE SINK networking.delete_stack INTO AWS OPERATION 'cloudformation:DeleteStack'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');

CREATE DATAFLOW networking.provision_network
  FROM QUEUE networking.network_work AS request
    WHERE (SELECT action FROM networking.network_operations WHERE id = request.operation_id) = 'provision'
  AS BEGIN
    LET operation = SELECT * FROM networking.network_operations WHERE id = request.operation_id;
    LET network = SELECT * FROM networking.networks WHERE id = operation.network_id;
    LET profile = SELECT * FROM networking.profiles WHERE id = network.profile_id;
    LET stack = EXECUTE SINK networking.create_stack USING PLACEMENT network.placement
      EFFECT OPERATION_ID(operation.id, 'network-create')
      GUARD EXISTS (SELECT 1 FROM networking.current_network_operations WHERE id = operation.id)
      REQUEST JSON_OBJECT('StackName', 'spoke-network-' || CAST(network.id AS TEXT),
        'ClientRequestToken', CAST(operation.id AS TEXT), 'DisableRollback', TRUE,
        'TemplateBody', ARTIFACT_TEXT(profile.network_template, profile.network_template_sha256),
        'Parameters', AWS_PARAMETERS(JSON_OBJECT('NetworkId', network.id, 'Cidr', network.cidr)))
      ON REPLAY OBSERVE ONLY;
    -- Native bindings retain complete or partial resource identities before any
    -- readiness check. Unknown effects keep the original operation and quota.
    LET resource_binding = BIND CLOUD RESOURCES stack USING PLACEMENT network.placement OWNER network.authority
      OPERATION operation.native_ref;
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_network_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.networks SET binding = resource_binding WHERE id = network.id;
    END;
    LET observed = AWAIT OBSERVATION FROM AWS STACK resource_binding.stack_id USING PLACEMENT network.placement
      EFFECT OPERATION_ID(operation.id, 'network-ready')
      GUARD EXISTS (SELECT 1 FROM networking.current_network_operations WHERE id = operation.id)
      UNTIL status IN ('CREATE_COMPLETE', 'CREATE_FAILED') WITH (deadline = '20m', interval = '10s');
    REQUIRE observed.complete AND observed.status = 'CREATE_COMPLETE'
      AND observed.operation_id = operation.id AND observed.stack_incarnation = resource_binding.incarnation
      AND observed.template_sha256 = profile.network_template_sha256
      AND PRIVATE_NETWORK_VERIFIED(observed, network.id, network.cidr) ELSE 'NetworkNotReady';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_network_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.networks SET state = 'ready', active_operation = NULL, revision = revision + 1 WHERE id = network.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('network_id', network.id, 'outcome', 'ready');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

CREATE DATAFLOW networking.withdraw_network
  FROM QUEUE networking.network_work AS request
    WHERE (SELECT action FROM networking.network_operations WHERE id = request.operation_id) = 'retire'
  AS BEGIN
    LET operation = SELECT * FROM networking.network_operations WHERE id = request.operation_id;
    LET network = SELECT * FROM networking.networks WHERE id = operation.network_id;
    LET removed = EXECUTE SINK networking.delete_stack USING PLACEMENT network.placement
      EFFECT OPERATION_ID(operation.id, 'network-delete')
      GUARD EXISTS (SELECT 1 FROM networking.current_network_operations WHERE id = operation.id)
        AND NO_NATIVE_RESOURCE_REFERENCES(network.binding)
      REQUEST JSON_OBJECT('StackName', network.binding.stack_id, 'ClientRequestToken', CAST(operation.id AS TEXT))
      ON REPLAY OBSERVE ONLY;
    LET observed = AWAIT OBSERVATION FROM AWS STACK network.binding.stack_id USING PLACEMENT network.placement
      EFFECT OPERATION_ID(operation.id, 'network-absent')
      GUARD EXISTS (SELECT 1 FROM networking.current_network_operations WHERE id = operation.id)
      UNTIL status = 'DELETE_COMPLETE' WITH (deadline = '20m', interval = '10s');
    REQUIRE observed.complete AND observed.operation_id = operation.id
      AND EXACT_RESOURCE_ABSENCE(observed, network.binding) ELSE 'DeletionUnresolved';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_network_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.networks SET state = 'retired', active_operation = NULL, revision = revision + 1 WHERE id = network.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('network_id', network.id, 'outcome', 'retired');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

-- Authority and activation precede HTTP ingress. No public SQL execution.
AUTHORIZE DATAFLOW networking.create_network AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.create_network;
AUTHORIZE DATAFLOW networking.protect_network AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.protect_network;
AUTHORIZE DATAFLOW networking.retire_network AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.retire_network;
AUTHORIZE SINK networking.create_stack AS ROLE SETTING('networking.effect_role');
ACTIVATE SINK networking.create_stack;
AUTHORIZE SINK networking.delete_stack AS ROLE SETTING('networking.effect_role');
ACTIVATE SINK networking.delete_stack;
AUTHORIZE DATAFLOW networking.provision_network AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.provision_network;
AUTHORIZE DATAFLOW networking.withdraw_network AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.withdraw_network;

CREATE SOURCE networking.create_network_http
  FROM HTTP REQUEST
  INTO COMMAND networking.create_network
  WITH (
    method = 'POST',
    path = '/platform/v1/environments/{environment_id}/networks',
    path_arguments = JSON '["environment_id"]',
    body_arguments = JSON '["expected_revision","name","cidr","profile_id","profile_revision","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.create_network/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.create_network_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.create_network_http;

CREATE SOURCE networking.protect_network_http
  FROM HTTP REQUEST
  INTO COMMAND networking.protect_network
  WITH (
    method = 'PATCH',
    path = '/platform/v1/networks/{network_id}/protection',
    path_arguments = JSON '["network_id"]',
    body_arguments = JSON '["expected_revision","protected"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.protect_network/{request_id}',
    response_status = 200,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.protect_network_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.protect_network_http;

CREATE SOURCE networking.retire_network_http
  FROM HTTP REQUEST
  INTO COMMAND networking.retire_network
  WITH (
    method = 'POST',
    path = '/platform/v1/networks/{network_id}/retire',
    path_arguments = JSON '["network_id"]',
    body_arguments = JSON '["expected_revision","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.retire_network/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.retire_network_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.retire_network_http;

CREATE PUBLICATION networking.network_catalog AS
  SELECT n.id, n.environment_id, n.name, n.profile_id, n.revision, n.generation, n.state, n.deletion_protected, n.active_operation, n.cidr
  FROM networking.networks n WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', n.authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('networking.reader_role'),
    response_profile = 'platform.networks.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/networks',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/networks/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION networking.network_catalog;
ACTIVATE PUBLICATION networking.network_catalog;

CREATE PUBLICATION networking.profile_catalog AS
  SELECT id, _revision AS revision, provider, region, network_limit, endpoint_limit, domain_limit
  FROM networking.profiles WHERE enabled AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('networking.reader_role'),
    response_profile = 'platform.network-profiles.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/network-profiles',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/network-profiles/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION networking.profile_catalog;
ACTIVATE PUBLICATION networking.profile_catalog;

CREATE PUBLICATION networking.network_operations_catalog AS
  SELECT o.id, o.network_id, o.action, NATIVE_OUTCOME(o.native_ref) AS outcome
  FROM networking.network_operations o JOIN networking.networks r ON r.id = o.network_id
  WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', r.authority)
    AND NATIVE_OPERATION_VISIBLE(CURRENT_SUBJECT(), o.native_ref)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('networking.reader_role'),
    response_profile = 'platform.network-operations.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/network-operations',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/network-operations/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION networking.network_operations_catalog;
ACTIVATE PUBLICATION networking.network_operations_catalog;
