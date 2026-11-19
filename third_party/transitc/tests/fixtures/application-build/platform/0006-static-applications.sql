-- Native contract and qualification: contracts/fabric-resources-v1.md; Platform #131.
-- Static applications publish prebuilt bytes; they do not own Transit instances.
CREATE SCHEMA publication AUTHORIZATION SETTING('schemas.publication_owner');
GRANT USAGE ON SCHEMA publication TO ROLE SETTING('publication.executor_role');
GRANT USAGE ON SCHEMA publication TO ROLE SETTING('publication.effect_role');
GRANT USAGE ON SCHEMA publication TO ROLE SETTING('publication.reader_role');
GRANT USAGE ON SCHEMA publication TO ROLE SETTING('networking.executor_role');
GRANT USAGE ON SCHEMA tenancy TO ROLE SETTING('publication.executor_role');

CREATE DOCUMENT publication.profiles (
  id UUID PRIMARY KEY,
  authority OBJECT_ID NOT NULL,
  provider TEXT NOT NULL,
  cloud_account TEXT NOT NULL,
  region TEXT NOT NULL,
  connection_ref CONNECTION_ID NOT NULL,
  template ARTIFACT NOT NULL,
  template_sha256 BINARY NOT NULL,
  role_ref TEXT NOT NULL,
  application_limit BIGINT NOT NULL CHECK (application_limit > 0),
  retained_bytes_limit BIGINT NOT NULL CHECK (retained_bytes_limit > 0),
  bundle_bytes_limit BIGINT NOT NULL CHECK (bundle_bytes_limit > 0),
  bundle_files_limit BIGINT NOT NULL CHECK (bundle_files_limit > 0),
  enabled BOOLEAN NOT NULL
) WITH (profile = 'versioned', write_authority = SETTING('publication.operator_role'));

CREATE TABLE publication.static_applications (
  id UUID PRIMARY KEY,
  environment_id UUID NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  authority OBJECT_ID NOT NULL UNIQUE,
  profile_id UUID NOT NULL,
  profile_revision BINARY NOT NULL,
  placement PLACEMENT NOT NULL,
  revision BIGINT NOT NULL,
  generation BIGINT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('absent', 'ready', 'retired')),
  deletion_protected BOOLEAN NOT NULL,
  active_operation UUID,
  active_bundle UUID,
  binding RESOURCE_BINDING,
  endpoint TEXT,
  UNIQUE (environment_id, name)
);

CREATE TABLE publication.bundles (
  id UUID PRIMARY KEY,
  static_application_id UUID NOT NULL REFERENCES publication.static_applications(id) ON DELETE RESTRICT,
  artifact ARTIFACT NOT NULL,
  manifest_sha256 BINARY NOT NULL,
  bytes BIGINT NOT NULL,
  files BIGINT NOT NULL,
  entry_document TEXT NOT NULL,
  spa_routes JSON NOT NULL
) WITH (immutable = TRUE);

-- Exact versions outlive promotion and retirement so open pages and rollback
-- retain their original bytes. Purging bundles is a separate, explicit policy.
CREATE TABLE publication.object_versions (
  bundle_id UUID NOT NULL REFERENCES publication.bundles(id) ON DELETE RESTRICT,
  path TEXT NOT NULL,
  version OBJECT_VERSION NOT NULL,
  sha256 BINARY NOT NULL,
  bytes BIGINT NOT NULL,
  PRIMARY KEY (bundle_id, path)
) WITH (immutable = TRUE);

CREATE TABLE publication.operations (
  id UUID PRIMARY KEY,
  static_application_id UUID NOT NULL REFERENCES publication.static_applications(id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN ('provision', 'publish', 'retire')),
  bundle_id UUID REFERENCES publication.bundles(id) ON DELETE RESTRICT,
  generation BIGINT NOT NULL,
  subject SUBJECT_ID NOT NULL,
  native_ref OPERATION NOT NULL UNIQUE
) WITH (immutable = TRUE);

CREATE QUEUE publication.work (
  operation_id UUID NOT NULL
) WITH (active_leases = 8, max_attempts = 1);

CREATE DATAFLOW publication.create_static_application
  FROM COMMAND (
    environment_id UUID,
    expected_revision BIGINT,
    name TEXT,
    profile_id UUID,
    profile_revision BINARY,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET env = SELECT * FROM tenancy.environments WHERE id = request.environment_id;
    LET profile = SELECT * FROM publication.profiles WHERE id = request.profile_id;
    REQUIRE env IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'create_static_application', env.authority)
      AND profile IS NOT NULL AND profile.enabled AND profile.provider = 'aws'
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', profile.authority) ELSE 'Forbidden';
    REQUIRE env.revision = request.expected_revision AND profile._revision = request.profile_revision ELSE 'StaleTarget';
    REQUIRE LENGTH(request.name) BETWEEN 1 AND 120 ELSE 'InvalidName';
    REQUIRE ARTIFACT_VERIFIED(profile.template, profile.template_sha256)
      AND AWS_STATIC_TEMPLATE_VALID(profile.template, 'spoke.static.aws.v1') ELSE 'UnqualifiedProfile';
    -- Retired distributions and retained origins continue consuming capacity.
    REQUIRE (SELECT COUNT(*) FROM publication.static_applications WHERE profile_id = profile.id)
      < profile.application_limit ELSE 'CapacityExceeded';
    LET digest = DIGEST(ROW(env.id, env.revision, request.name, profile.id, profile._revision));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), env.authority,
      'create_static_application', digest, env.revision) ELSE 'Forbidden';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'static-application');
    LET object = ALLOCATE AUTHORIZATION OBJECT 'platform.static_application' ID command_id PARENT env.authority;
    GRANT ACTIONS ('inspect', 'publish', 'retire', 'protect', 'bind_endpoint') ON OBJECT object TO SUBJECT CURRENT_SUBJECT();
    LET placement = BIND PLACEMENT profile.provider ACCOUNT profile.cloud_account REGION profile.region
      CONNECTION profile.connection_ref ROLE profile.role_ref TEMPLATE profile.template_sha256;
    LET operation_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'static-operation');
    LET operation = ACCEPT OPERATION operation_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET command_id REVISION 0;
    INSERT INTO publication.static_applications VALUES (command_id, env.id, request.name, object, profile.id, profile._revision,
      placement, 1, 1, 'absent', TRUE, operation_id, NULL, NULL, NULL);
    INSERT INTO publication.operations VALUES (operation_id, command_id, 'provision', NULL, 1, CURRENT_SUBJECT(), operation);
    ENQUEUE INTO publication.work VALUES (operation_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', command_id, 'revision', 1, 'operation_id', operation_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE DATAFLOW publication.publish_bundle
  FROM COMMAND (
    static_application_id UUID,
    expected_revision BIGINT,
    artifact ARTIFACT,
    manifest_sha256 BINARY,
    entry_document TEXT,
    spa_routes JSON,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET app = SELECT * FROM publication.static_applications WHERE id = request.static_application_id;
    REQUIRE app IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'publish', app.authority) ELSE 'Forbidden';
    REQUIRE app.revision = request.expected_revision AND app.active_operation IS NULL AND app.state = 'ready' ELSE 'StaleTarget';
    REQUIRE NOT EXISTS (SELECT 1 FROM networking.target_holds WHERE target_id = app.id AND mutating AND NOT released) ELSE 'Referenced';
    LET profile = SELECT * FROM publication.profiles WHERE id = app.profile_id;
    REQUIRE profile.enabled AND profile._revision = app.profile_revision
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', profile.authority) ELSE 'ProfileChanged';
    LET manifest = VERIFIED_STATIC_MANIFEST(request.artifact, request.manifest_sha256);
    REQUIRE manifest.complete AND manifest.bytes <= profile.bundle_bytes_limit AND manifest.file_count BETWEEN 1 AND profile.bundle_files_limit
      AND STATIC_ROUTES_VALID(manifest, request.entry_document, request.spa_routes)
      AND REVISION_SCOPED_ASSETS(manifest) ELSE 'UnverifiedArtifact';
    LET used = SELECT COALESCE(SUM(b.bytes), 0) FROM publication.bundles b
      JOIN publication.static_applications a ON a.id = b.static_application_id WHERE a.profile_id = profile.id;
    REQUIRE used + manifest.bytes <= profile.retained_bytes_limit ELSE 'CapacityExceeded';
    LET digest = DIGEST(ROW(app.id, app.revision, request.manifest_sha256, request.entry_document, request.spa_routes));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), app.authority,
      'publish', digest, app.revision) ELSE 'Forbidden';
    LET bundle_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'bundle');
    INSERT INTO publication.bundles VALUES (bundle_id, app.id, request.artifact, request.manifest_sha256,
      manifest.bytes, manifest.file_count, request.entry_document, request.spa_routes);
    RETAIN ARTIFACT request.artifact FOR OBJECT app.authority REFERENCE bundle_id;
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'static-operation');
    LET operation = ACCEPT OPERATION command_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET app.id REVISION app.revision;
    INSERT INTO publication.operations VALUES (command_id, app.id, 'publish', bundle_id, app.generation + 1, CURRENT_SUBJECT(), operation);
    UPDATE publication.static_applications SET active_operation = command_id, revision = revision + 1, generation = generation + 1 WHERE id = app.id;
    ENQUEUE INTO publication.work VALUES (command_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', app.id, 'revision', app.revision + 1, 'operation_id', command_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE DATAFLOW publication.protect_static_application
  FROM COMMAND (
    static_application_id UUID,
    expected_revision BIGINT,
    protected BOOLEAN
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET app = SELECT * FROM publication.static_applications WHERE id = request.static_application_id;
    REQUIRE app IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'protect', app.authority) ELSE 'Forbidden';
    REQUIRE app.revision = request.expected_revision ELSE 'StaleTarget';
    UPDATE publication.static_applications SET deletion_protected = request.protected, revision = revision + 1 WHERE id = app.id;
    RETURN JSON_OBJECT('id', app.id, 'revision', app.revision + 1, 'protected', request.protected);
  END;

CREATE DATAFLOW publication.retire_static_application
  FROM COMMAND (
    static_application_id UUID,
    expected_revision BIGINT,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET app = SELECT * FROM publication.static_applications WHERE id = request.static_application_id;
    REQUIRE app IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'retire', app.authority) ELSE 'Forbidden';
    REQUIRE app.revision = request.expected_revision AND app.active_operation IS NULL AND app.state = 'ready' ELSE 'StaleTarget';
    REQUIRE NOT app.deletion_protected ELSE 'DeletionProtected';
    REQUIRE NOT EXISTS (SELECT 1 FROM networking.target_holds WHERE target_id = app.id AND NOT released) ELSE 'Referenced';
    LET digest = DIGEST(ROW(app.id, app.revision, 'retire'));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), app.authority, 'retire', digest, app.revision) ELSE 'Forbidden';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'static-operation');
    LET operation = ACCEPT OPERATION command_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET app.id REVISION app.revision;
    INSERT INTO publication.operations VALUES (command_id, app.id, 'retire', NULL, app.generation + 1, CURRENT_SUBJECT(), operation);
    UPDATE publication.static_applications SET active_operation = command_id, revision = revision + 1, generation = generation + 1 WHERE id = app.id;
    ENQUEUE INTO publication.work VALUES (command_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', app.id, 'revision', app.revision + 1, 'operation_id', command_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE VIEW publication.current_operations AS
  SELECT o.id FROM publication.operations o JOIN publication.static_applications a ON a.id = o.static_application_id
  JOIN publication.profiles p ON p.id = a.profile_id
  WHERE a.active_operation = o.id AND a.generation = o.generation AND NATIVE_OPERATION_CURRENT(o.native_ref)
    AND p.enabled AND p._revision = a.profile_revision AND NATIVE_ALLOWED(o.subject, 'use', p.authority)
    AND (o.action <> 'retire' OR (NOT a.deletion_protected
      AND NOT EXISTS (SELECT 1 FROM networking.target_holds h WHERE h.target_id = a.id AND NOT h.released)));

CREATE SINK publication.create_stack INTO AWS OPERATION 'cloudformation:CreateStack'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');
CREATE SINK publication.put_object INTO AWS OPERATION 's3:PutObject'
  WITH (connection = 'bound_placement', body = 'verified_artifact_range', capture = 'version_and_checksum', recovery = 'original_request_observation');
CREATE SINK publication.update_distribution INTO AWS OPERATION 'cloudfront:UpdateDistribution'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');

CREATE DATAFLOW publication.provision_static_application
  FROM QUEUE publication.work AS request
    WHERE (SELECT action FROM publication.operations WHERE id = request.operation_id) = 'provision'
  AS BEGIN
    LET operation = SELECT * FROM publication.operations WHERE id = request.operation_id;
    LET app = SELECT * FROM publication.static_applications WHERE id = operation.static_application_id;
    LET profile = SELECT * FROM publication.profiles WHERE id = app.profile_id;
    LET stack = EXECUTE SINK publication.create_stack USING PLACEMENT app.placement
      EFFECT OPERATION_ID(operation.id, 'static-create')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id)
      REQUEST JSON_OBJECT('StackName', 'spoke-static-' || CAST(app.id AS TEXT), 'ClientRequestToken', CAST(operation.id AS TEXT),
        'DisableRollback', TRUE, 'TemplateBody', ARTIFACT_TEXT(profile.template, profile.template_sha256),
        'Parameters', AWS_PARAMETERS(JSON_OBJECT('StaticApplicationId', app.id))) ON REPLAY OBSERVE ONLY;
    LET resource_binding = BIND CLOUD RESOURCES stack USING PLACEMENT app.placement OWNER app.authority OPERATION operation.native_ref;
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE publication.static_applications SET binding = resource_binding WHERE id = app.id;
    END;
    LET observed = AWAIT OBSERVATION FROM AWS STACK resource_binding.stack_id USING PLACEMENT app.placement
      EFFECT OPERATION_ID(operation.id, 'static-ready')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id)
      UNTIL status IN ('CREATE_COMPLETE', 'CREATE_FAILED') WITH (deadline = '20m', interval = '10s');
    REQUIRE observed.complete AND observed.status = 'CREATE_COMPLETE' AND observed.operation_id = operation.id
      AND observed.stack_incarnation = resource_binding.incarnation AND observed.template_sha256 = profile.template_sha256
      AND PRIVATE_VERSIONED_ORIGIN_VERIFIED(observed, app.id) ELSE 'CloudNotReady';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE publication.static_applications SET state = 'ready', active_operation = NULL, revision = revision + 1 WHERE id = app.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('static_application_id', app.id, 'outcome', 'ready');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

CREATE DATAFLOW publication.deliver_bundle
  FROM QUEUE publication.work AS request
    WHERE (SELECT action FROM publication.operations WHERE id = request.operation_id) = 'publish'
  AS BEGIN
    LET operation = SELECT * FROM publication.operations WHERE id = request.operation_id;
    LET app = SELECT * FROM publication.static_applications WHERE id = operation.static_application_id;
    LET bundle = SELECT * FROM publication.bundles WHERE id = operation.bundle_id;
    LET manifest = VERIFIED_STATIC_MANIFEST(bundle.artifact, bundle.manifest_sha256);
    FOR file IN manifest.files ORDER BY path DO
      LET object = EXECUTE SINK publication.put_object USING PLACEMENT app.placement
        EFFECT OPERATION_ID(operation.id, file.path)
        GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id)
        REQUEST JSON_OBJECT('Bucket', app.binding.bucket_id, 'Key', BUNDLE_OBJECT_KEY(app.id, bundle.id, file.path),
          'IfNoneMatch', '*', 'ChecksumSHA256', BASE64(file.sha256), 'ContentType', file.media_type,
          'Body', ARTIFACT_RANGE(bundle.artifact, file.offset, file.bytes)) ON REPLAY OBSERVE ONLY;
      REQUIRE OBJECT_VERSION_VERIFIED(object, file.sha256, file.bytes, app.binding) ELSE 'ObjectNotVerified';
      BEGIN ATOMIC
        REQUIRE EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id) ELSE 'StaleOperation';
        INSERT INTO publication.object_versions VALUES (bundle.id, file.path, object.version, file.sha256, file.bytes);
      END;
    END FOR;
    LET previous = OBSERVE AWS DISTRIBUTION app.binding.distribution_id USING PLACEMENT app.placement
      EFFECT OPERATION_ID(operation.id, 'distribution-before')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id);
    REQUIRE previous.complete AND previous.incarnation = app.binding.distribution_incarnation ELSE 'ObservationMismatch';
    LET config = STATIC_DISTRIBUTION_CONFIGURATION(previous.configuration, app.id, bundle.id,
      bundle.manifest_sha256, bundle.entry_document, bundle.spa_routes);
    -- Preserve unrelated aliases/TLS and compare the exact provider configuration.
    LET selected = EXECUTE SINK publication.update_distribution USING PLACEMENT app.placement
      EFFECT OPERATION_ID(operation.id, 'select-bundle')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id)
      REQUEST JSON_OBJECT('Id', app.binding.distribution_id, 'IfMatch', previous.etag, 'DistributionConfig', config)
      ON REPLAY OBSERVE ONLY;
    LET observed = AWAIT OBSERVATION FROM AWS DISTRIBUTION app.binding.distribution_id USING PLACEMENT app.placement
      EFFECT OPERATION_ID(operation.id, 'bundle-propagated')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id)
      UNTIL status = 'Deployed' WITH (deadline = '20m', interval = '10s');
    REQUIRE observed.complete AND observed.incarnation = app.binding.distribution_incarnation
      AND DISTRIBUTION_CONFIGURATION_MATCHES(observed, config, selected) ELSE 'DeliveryNotVerified';
    LET delivered = AWAIT OBSERVATION FROM HTTPS BUNDLE observed.https_endpoint MANIFEST manifest
      EFFECT OPERATION_ID(operation.id, 'bundle-byte-proof')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id)
      WITH (deadline = '20m', interval = '30s', redirects = 'reject', credentials = 'none',
        max_bytes = manifest.bytes, max_files = manifest.file_count);
    REQUIRE PUBLIC_BUNDLE_BYTES_VERIFIED(delivered, manifest, app.id, bundle.id) ELSE 'DeliveryNotVerified';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE publication.static_applications SET active_bundle = bundle.id, endpoint = observed.https_endpoint,
        active_operation = NULL, revision = revision + 1 WHERE id = app.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('static_application_id', app.id, 'bundle_id', bundle.id, 'outcome', 'published');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

CREATE DATAFLOW publication.withdraw_static_application
  FROM QUEUE publication.work AS request
    WHERE (SELECT action FROM publication.operations WHERE id = request.operation_id) = 'retire'
  AS BEGIN
    LET operation = SELECT * FROM publication.operations WHERE id = request.operation_id;
    LET app = SELECT * FROM publication.static_applications WHERE id = operation.static_application_id;
    LET previous = OBSERVE AWS DISTRIBUTION app.binding.distribution_id USING PLACEMENT app.placement
      EFFECT OPERATION_ID(operation.id, 'retire-before')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id);
    REQUIRE previous.complete AND previous.incarnation = app.binding.distribution_incarnation ELSE 'ObservationMismatch';
    LET disabled = EXECUTE SINK publication.update_distribution USING PLACEMENT app.placement
      EFFECT OPERATION_ID(operation.id, 'disable-static')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id)
      REQUEST JSON_OBJECT('Id', app.binding.distribution_id, 'IfMatch', previous.etag,
        'DistributionConfig', DISABLE_DISTRIBUTION(previous.configuration)) ON REPLAY OBSERVE ONLY;
    LET observed = AWAIT OBSERVATION FROM AWS DISTRIBUTION app.binding.distribution_id USING PLACEMENT app.placement
      EFFECT OPERATION_ID(operation.id, 'static-withdrawn')
      GUARD EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id)
      UNTIL status = 'Deployed' AND NOT enabled WITH (deadline = '20m', interval = '10s');
    REQUIRE observed.complete AND EXACT_DISTRIBUTION_WITHDRAWAL(observed, app.binding, disabled) ELSE 'RetirementUnverified';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM publication.current_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE publication.static_applications SET state = 'retired', endpoint = NULL,
        active_operation = NULL, revision = revision + 1 WHERE id = app.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('static_application_id', app.id, 'outcome', 'retired');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

-- Authority and activation precede HTTP ingress. No public SQL execution.
AUTHORIZE DATAFLOW publication.create_static_application AS ROLE SETTING('publication.executor_role');
ACTIVATE DATAFLOW publication.create_static_application;
AUTHORIZE DATAFLOW publication.publish_bundle AS ROLE SETTING('publication.executor_role');
ACTIVATE DATAFLOW publication.publish_bundle;
AUTHORIZE DATAFLOW publication.protect_static_application AS ROLE SETTING('publication.executor_role');
ACTIVATE DATAFLOW publication.protect_static_application;
AUTHORIZE DATAFLOW publication.retire_static_application AS ROLE SETTING('publication.executor_role');
ACTIVATE DATAFLOW publication.retire_static_application;
AUTHORIZE SINK publication.create_stack AS ROLE SETTING('publication.effect_role');
ACTIVATE SINK publication.create_stack;
AUTHORIZE SINK publication.put_object AS ROLE SETTING('publication.effect_role');
ACTIVATE SINK publication.put_object;
AUTHORIZE SINK publication.update_distribution AS ROLE SETTING('publication.effect_role');
ACTIVATE SINK publication.update_distribution;
AUTHORIZE DATAFLOW publication.provision_static_application AS ROLE SETTING('publication.executor_role');
ACTIVATE DATAFLOW publication.provision_static_application;
AUTHORIZE DATAFLOW publication.deliver_bundle AS ROLE SETTING('publication.executor_role');
ACTIVATE DATAFLOW publication.deliver_bundle;
AUTHORIZE DATAFLOW publication.withdraw_static_application AS ROLE SETTING('publication.executor_role');
ACTIVATE DATAFLOW publication.withdraw_static_application;

CREATE SOURCE publication.create_static_application_http
  FROM HTTP REQUEST
  INTO COMMAND publication.create_static_application
  WITH (
    method = 'POST',
    path = '/platform/v1/environments/{environment_id}/static-applications',
    path_arguments = JSON '["environment_id"]',
    body_arguments = JSON '["expected_revision","name","profile_id","profile_revision","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/publication.create_static_application/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE publication.create_static_application_http AS ROLE SETTING('publication.executor_role');
ACTIVATE SOURCE publication.create_static_application_http;

CREATE SOURCE publication.publish_bundle_http
  FROM HTTP REQUEST
  INTO COMMAND publication.publish_bundle
  WITH (
    method = 'POST',
    path = '/platform/v1/static-applications/{static_application_id}/bundles',
    path_arguments = JSON '["static_application_id"]',
    body_arguments = JSON '["expected_revision","artifact","manifest_sha256","entry_document","spa_routes","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/publication.publish_bundle/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE publication.publish_bundle_http AS ROLE SETTING('publication.executor_role');
ACTIVATE SOURCE publication.publish_bundle_http;

CREATE SOURCE publication.protect_static_application_http
  FROM HTTP REQUEST
  INTO COMMAND publication.protect_static_application
  WITH (
    method = 'PATCH',
    path = '/platform/v1/static-applications/{static_application_id}/protection',
    path_arguments = JSON '["static_application_id"]',
    body_arguments = JSON '["expected_revision","protected"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/publication.protect_static_application/{request_id}',
    response_status = 200,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE publication.protect_static_application_http AS ROLE SETTING('publication.executor_role');
ACTIVATE SOURCE publication.protect_static_application_http;

CREATE SOURCE publication.retire_static_application_http
  FROM HTTP REQUEST
  INTO COMMAND publication.retire_static_application
  WITH (
    method = 'POST',
    path = '/platform/v1/static-applications/{static_application_id}/retire',
    path_arguments = JSON '["static_application_id"]',
    body_arguments = JSON '["expected_revision","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/publication.retire_static_application/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE publication.retire_static_application_http AS ROLE SETTING('publication.executor_role');
ACTIVATE SOURCE publication.retire_static_application_http;

CREATE PUBLICATION publication.application_catalog AS
  SELECT a.id, a.environment_id, a.name, a.profile_id, a.revision, a.generation, a.state, a.deletion_protected, a.active_operation, a.active_bundle, a.endpoint
  FROM publication.static_applications a WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', a.authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('publication.reader_role'),
    response_profile = 'platform.static-applications.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/static-applications',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/static-applications/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION publication.application_catalog;
ACTIVATE PUBLICATION publication.application_catalog;

CREATE PUBLICATION publication.bundle_catalog AS
  SELECT b.id, b.static_application_id, b.manifest_sha256, b.bytes, b.files, b.entry_document, b.spa_routes
  FROM publication.bundles b JOIN publication.static_applications a ON a.id = b.static_application_id
  WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', a.authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('publication.reader_role'),
    response_profile = 'platform.static-bundles.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/static-bundles',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/static-bundles/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION publication.bundle_catalog;
ACTIVATE PUBLICATION publication.bundle_catalog;

CREATE PUBLICATION publication.profile_catalog AS
  SELECT id, _revision AS revision, provider, region, application_limit, retained_bytes_limit, bundle_bytes_limit, bundle_files_limit
  FROM publication.profiles WHERE enabled AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('publication.reader_role'),
    response_profile = 'platform.static-profiles.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/static-profiles',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/static-profiles/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION publication.profile_catalog;
ACTIVATE PUBLICATION publication.profile_catalog;

CREATE PUBLICATION publication.operations_catalog AS
  SELECT o.id, o.static_application_id, o.action, NATIVE_OUTCOME(o.native_ref) AS outcome
  FROM publication.operations o JOIN publication.static_applications r ON r.id = o.static_application_id
  WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', r.authority)
    AND NATIVE_OPERATION_VISIBLE(CURRENT_SUBJECT(), o.native_ref)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('publication.reader_role'),
    response_profile = 'platform.static-operations.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/static-operations',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/static-operations/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION publication.operations_catalog;
ACTIVATE PUBLICATION publication.operations_catalog;
