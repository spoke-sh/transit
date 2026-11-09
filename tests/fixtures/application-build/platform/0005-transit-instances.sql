-- Fresh deployments baseline. Define objects in their owning schema from the start.
CREATE SCHEMA deployments AUTHORIZATION SETTING('schemas.deployments_owner');
GRANT USAGE ON SCHEMA deployments TO ROLE SETTING('deployments.executor_role');
GRANT USAGE ON SCHEMA deployments TO ROLE SETTING('deployments.reader_role');
GRANT USAGE ON SCHEMA deployments TO ROLE SETTING('deployments.effect_role');
GRANT USAGE ON SCHEMA deployments TO ROLE SETTING('deployments.operator_role');

-- Platform stores control records. Each instance owns a different Transit
-- installation, credential set, storage authority and application ledger.

CREATE TABLE deployments.instances (
  id UUID PRIMARY KEY,
  environment_id UUID NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  network_id UUID NOT NULL REFERENCES networking.networks(id) ON DELETE RESTRICT,
  authority OBJECT_ID NOT NULL UNIQUE,
  installation_id UUID NOT NULL UNIQUE,
  revision BIGINT NOT NULL,
  generation BIGINT NOT NULL,
  desired_state TEXT NOT NULL CHECK (desired_state IN ('running', 'stopped', 'retired')),
  active_configuration UUID,
  active_placement UUID,
  active_operation UUID,
  native_definition TEXT,
  deletion_protected BOOLEAN NOT NULL,
  retain_until TIMESTAMPTZ,
  UNIQUE (environment_id, name)
);

-- Provider/profile configuration is separately operator-granted. It supplies
-- approved immutable CloudFormation template bytes and role/network references,
-- never an arbitrary caller template, shell command or credential value.
CREATE DOCUMENT deployments.profiles (
  id UUID PRIMARY KEY,
  provider TEXT NOT NULL,
  cloud_account TEXT NOT NULL,
  region TEXT NOT NULL,
  connection_ref CONNECTION_ID NOT NULL,
  authority OBJECT_ID NOT NULL,
  template ARTIFACT NOT NULL,
  template_sha256 BINARY NOT NULL,
  cloud_role_ref TEXT NOT NULL,
  enabled BOOLEAN NOT NULL,
  cpu_limit BIGINT NOT NULL,
  memory_limit BIGINT NOT NULL,
  storage_limit BIGINT NOT NULL,
  instance_limit BIGINT NOT NULL,
  minimum_retention_seconds BIGINT NOT NULL,
  CHECK (cpu_limit >= 0 AND memory_limit >= 0 AND storage_limit >= 0
    AND instance_limit >= 0 AND minimum_retention_seconds >= 0)
) WITH (profile = 'versioned', write_authority = SETTING('deployments.operator_role'));

CREATE TABLE deployments.placements (
  id UUID PRIMARY KEY,
  profile_id UUID NOT NULL,
  profile_revision BINARY NOT NULL,
  provider TEXT NOT NULL,
  cloud_account TEXT NOT NULL,
  region TEXT NOT NULL,
  connection_ref CONNECTION_ID NOT NULL,
  template_sha256 BINARY NOT NULL,
  configuration_sha256 BINARY NOT NULL,
  configuration JSON NOT NULL
) WITH (immutable = TRUE);

CREATE TABLE deployments.instance_configurations (
  id UUID PRIMARY KEY,
  instance_id UUID NOT NULL REFERENCES deployments.instances(id) ON DELETE RESTRICT,
  runtime_image TEXT NOT NULL,
  native_definition TEXT NOT NULL,
  runtime_configuration ARTIFACT NOT NULL,
  configuration_sha256 BINARY NOT NULL,
  cpu BIGINT NOT NULL,
  memory BIGINT NOT NULL,
  storage BIGINT NOT NULL,
  CHECK (cpu > 0 AND memory > 0 AND storage > 0)
) WITH (immutable = TRUE);

CREATE TABLE deployments.cloud_resources (
  instance_id UUID NOT NULL REFERENCES deployments.instances(id) ON DELETE RESTRICT,
  logical_id TEXT NOT NULL,
  provider TEXT NOT NULL,
  cloud_account TEXT NOT NULL,
  region TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  incarnation TEXT NOT NULL,
  creating_operation UUID NOT NULL,
  generation BIGINT NOT NULL,
  retained BOOLEAN NOT NULL,
  retired BOOLEAN NOT NULL,
  PRIMARY KEY (instance_id, logical_id, incarnation),
  UNIQUE (provider, cloud_account, region, resource_type, resource_id, incarnation)
);

CREATE TABLE deployments.retention_holds (
  id UUID PRIMARY KEY,
  instance_id UUID NOT NULL REFERENCES deployments.instances(id) ON DELETE RESTRICT,
  reason TEXT NOT NULL,
  authority OBJECT_ID NOT NULL,
  released_at TIMESTAMPTZ
);

CREATE STREAM deployments.observations (
  instance_id UUID NOT NULL,
  operation_id UUID NOT NULL,
  generation BIGINT NOT NULL,
  evidence EVIDENCE NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL
) WITH (retention = 'native_operation_and_resource_holds');

-- An environment directly owns each Transit instance. Customer definitions and
-- migration history live inside that instance; there is no application parent.
CREATE DATAFLOW deployments.register_instance
  FROM COMMAND (
    environment_id UUID,
    expected_revision BIGINT,
    name TEXT,
    network_id UUID,
    network_revision BIGINT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET env = SELECT * FROM tenancy.environments WHERE id = request.environment_id;
    REQUIRE env IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'register_instance', env.authority)
      ELSE 'Forbidden';
    REQUIRE env.revision = request.expected_revision ELSE 'StaleTarget';
    REQUIRE LENGTH(request.name) BETWEEN 1 AND 120 ELSE 'InvalidName';
    LET network = SELECT * FROM networking.networks WHERE id = request.network_id;
    REQUIRE network IS NOT NULL AND network.environment_id = env.id
      AND network.revision = request.network_revision AND network.state = 'ready' AND network.active_operation IS NULL
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', network.authority) ELSE 'NetworkNotReady';
    LET id = OPERATION_ID(CURRENT_REQUEST_ID(), 'instance');
    LET object = ALLOCATE AUTHORIZATION OBJECT 'platform.instance' ID id PARENT env.authority;
    GRANT ACTIONS ('inspect', 'configure', 'prepare', 'deploy', 'suspend', 'resume', 'retire', 'protect', 'hold', 'bind_endpoint')
      ON OBJECT object TO SUBJECT CURRENT_SUBJECT();
    INSERT INTO deployments.instances VALUES (
      id, env.id, request.name, network.id, object, OPERATION_ID(id, 'installation'), 1, 0,
      'stopped', NULL, NULL, NULL, NULL, TRUE, NULL
    );
    INSERT INTO networking.attachments VALUES (network.id, id, 'transit_instance', FALSE);
    RETURN JSON_OBJECT('id', id, 'revision', 1);
  END;

-- Immutable runtime configuration is separate from the customer's application.
-- No customer SQL, application artifact or migration digest enters this command.
CREATE DATAFLOW deployments.register_configuration
  FROM COMMAND (
    instance_id UUID,
    expected_revision BIGINT,
    runtime_image TEXT,
    native_definition TEXT,
    runtime_configuration ARTIFACT,
    configuration_sha256 BINARY,
    cpu BIGINT,
    memory BIGINT,
    storage BIGINT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET instance = SELECT * FROM deployments.instances WHERE id = request.instance_id;
    REQUIRE instance IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'configure', instance.authority)
      ELSE 'Forbidden';
    REQUIRE instance.revision = request.expected_revision ELSE 'StaleTarget';
    REQUIRE IMAGE_DIGEST_VALID(request.runtime_image) AND DEFINITION_VALID(request.native_definition)
      AND ARTIFACT_VERIFIED(request.runtime_configuration, request.configuration_sha256)
      AND RUNTIME_CONFIGURATION_VALID(request.runtime_configuration, 'spoke.transit.runtime.v1')
      AND request.cpu > 0 AND request.memory > 0 AND request.storage > 0 ELSE 'UnverifiedArtifact';
    LET id = OPERATION_ID(CURRENT_REQUEST_ID(), 'configuration');
    INSERT INTO deployments.instance_configurations VALUES (id, instance.id, request.runtime_image,
      request.native_definition, request.runtime_configuration, request.configuration_sha256,
      request.cpu, request.memory, request.storage);
    RETURN JSON_OBJECT('id', id);
  END;

AUTHORIZE DATAFLOW deployments.register_instance AS ROLE SETTING('deployments.executor_role');
AUTHORIZE DATAFLOW deployments.register_configuration AS ROLE SETTING('deployments.executor_role');
ACTIVATE DATAFLOW deployments.register_instance;
ACTIVATE DATAFLOW deployments.register_configuration;

-- Candidate creation is read/review work. Only exact-candidate admission grants
-- execution, under the original subject and current native authority.
CREATE TABLE deployments.candidates (
  id UUID PRIMARY KEY,
  instance_id UUID NOT NULL REFERENCES deployments.instances(id) ON DELETE RESTRICT,
  expected_revision BIGINT NOT NULL,
  expected_generation BIGINT NOT NULL,
  action TEXT NOT NULL CHECK (action IN ('provision', 'replace', 'suspend', 'resume', 'retire', 'purge')),
  configuration_id UUID NOT NULL REFERENCES deployments.instance_configurations(id) ON DELETE RESTRICT,
  placement_id UUID NOT NULL REFERENCES deployments.placements(id) ON DELETE RESTRICT,
  retained_definition TEXT,
  digest BINARY NOT NULL UNIQUE
) WITH (immutable = TRUE);

CREATE TABLE deployments.operations (
  id UUID PRIMARY KEY,
  candidate_id UUID NOT NULL UNIQUE REFERENCES deployments.candidates(id) ON DELETE RESTRICT,
  instance_id UUID NOT NULL REFERENCES deployments.instances(id) ON DELETE RESTRICT,
  generation BIGINT NOT NULL,
  subject SUBJECT_ID NOT NULL,
  native_ref OPERATION NOT NULL UNIQUE
) WITH (immutable = TRUE);

CREATE TABLE deployments.reservations (
  operation_id UUID PRIMARY KEY REFERENCES deployments.operations(id) ON DELETE RESTRICT,
  instance_id UUID NOT NULL,
  profile_id UUID NOT NULL,
  cpu BIGINT NOT NULL,
  memory BIGINT NOT NULL,
  storage BIGINT NOT NULL,
  instances BIGINT NOT NULL,
  compute_released BOOLEAN NOT NULL,
  storage_released BOOLEAN NOT NULL
);
-- This is an ordinary current read, not a materialized authorization projection.
-- Guards evaluate it again at native dispatch/commit/disclosure boundaries.
CREATE VIEW deployments.authorized_operations AS
  SELECT o.id FROM deployments.operations o
  JOIN deployments.candidates c ON c.id = o.candidate_id
  JOIN deployments.instances i ON i.id = o.instance_id
  JOIN deployments.placements p ON p.id = c.placement_id
  JOIN deployments.profiles profile ON profile.id = p.profile_id
  JOIN networking.networks network ON network.id = i.network_id
  WHERE i.active_operation = o.id AND i.generation = o.generation
    AND NATIVE_OPERATION_CURRENT(o.native_ref)
    AND NATIVE_ALLOWED(o.subject, 'use', profile.authority)
    AND profile.enabled AND profile._revision = p.profile_revision
    AND network.state = 'ready' AND network.active_operation IS NULL
    AND NATIVE_ALLOWED(o.subject, 'use', network.authority)
    AND (c.action NOT IN ('retire', 'purge') OR (NOT i.deletion_protected
      AND NOT EXISTS (SELECT 1 FROM networking.target_holds h WHERE h.target_id = i.id AND NOT h.released)))
    AND (c.action <> 'purge' OR (i.desired_state = 'retired' AND i.retain_until <= NOW()
      AND NOT EXISTS (SELECT 1 FROM deployments.retention_holds h
        WHERE h.instance_id = i.id AND h.released_at IS NULL)));

CREATE QUEUE deployments.lifecycle (
  operation_id UUID NOT NULL
) WITH (active_leases = 8, max_attempts = 1);

CREATE QUEUE deployments.verification (
  operation_id UUID NOT NULL
) WITH (active_leases = 8, max_attempts = 1);

CREATE DATAFLOW deployments.prepare_candidate
  FROM COMMAND (
    instance_id UUID,
    expected_revision BIGINT,
    action TEXT,
    configuration_id UUID,
    profile_id UUID
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.candidate.v1')
  AS BEGIN ATOMIC
    LET instance = SELECT * FROM deployments.instances WHERE id = request.instance_id;
    REQUIRE instance IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'prepare', instance.authority) ELSE 'Forbidden';
    REQUIRE instance.revision = request.expected_revision AND instance.active_operation IS NULL ELSE 'StaleTarget';
    LET configuration = SELECT * FROM deployments.instance_configurations WHERE id = request.configuration_id;
    LET profile = SELECT * FROM deployments.profiles WHERE id = request.profile_id;
    REQUIRE configuration IS NOT NULL AND configuration.instance_id = instance.id
      AND profile IS NOT NULL AND profile.enabled AND profile.provider = 'aws'
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', profile.authority) ELSE 'Forbidden';
    REQUIRE ARTIFACT_VERIFIED(profile.template, profile.template_sha256)
      AND AWS_INSTALLATION_TEMPLATE_VALID(profile.template, 'spoke.transit.aws.v1') ELSE 'UnqualifiedProfile';
    REQUIRE request.action IN ('provision', 'replace', 'suspend', 'resume', 'retire', 'purge') ELSE 'InvalidAction';
    IF request.action = 'provision' THEN
      REQUIRE instance.active_configuration IS NULL AND instance.generation = 0 ELSE 'AlreadyProvisioned';
    ELSE
      LET placement = SELECT * FROM deployments.placements WHERE id = instance.active_placement;
      REQUIRE placement IS NOT NULL AND placement.profile_id = profile.id
        AND placement.profile_revision = profile._revision ELSE 'PlacementChanged';
      IF request.action <> 'replace' THEN
        REQUIRE configuration.id = instance.active_configuration ELSE 'ConfigurationChanged';
      END IF;
    END IF;
    IF request.action IN ('replace', 'resume') THEN
      REQUIRE instance.native_definition = configuration.native_definition ELSE 'IncompatibleDefinition';
      LET active = SELECT * FROM deployments.instance_configurations WHERE id = instance.active_configuration;
      REQUIRE active.storage = configuration.storage ELSE 'StorageResizeUnsupported';
    END IF;
    REQUIRE (request.action IN ('provision', 'replace') AND instance.desired_state <> 'retired')
      OR (request.action = 'suspend' AND instance.desired_state = 'running')
      OR (request.action = 'resume' AND instance.desired_state = 'stopped')
      OR (request.action = 'retire' AND instance.desired_state <> 'retired')
      OR (request.action = 'purge' AND instance.desired_state = 'retired') ELSE 'InvalidTransition';
    LET network = SELECT * FROM networking.networks WHERE id = instance.network_id;
    LET network_profile = SELECT * FROM networking.profiles WHERE id = network.profile_id;
    REQUIRE network.state = 'ready' AND network.active_operation IS NULL
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', network.authority)
      AND network_profile.provider = profile.provider AND network_profile.cloud_account = profile.cloud_account
      AND network_profile.region = profile.region ELSE 'NetworkNotReady';
    LET config = JSON_OBJECT('network', NETWORK_PARAMETERS(network.binding), 'role', profile.cloud_role_ref);
    LET placement_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'placement');
    INSERT INTO deployments.placements VALUES (placement_id, profile.id, profile._revision,
      profile.provider, profile.cloud_account, profile.region, profile.connection_ref,
      profile.template_sha256, DIGEST(config), config);
    LET id = OPERATION_ID(CURRENT_REQUEST_ID(), 'candidate');
    LET digest = DIGEST(ROW(id, instance.id, instance.revision, instance.generation, request.action,
      configuration.id, placement_id, profile._revision, configuration.runtime_image,
      configuration.configuration_sha256, instance.native_definition));
    INSERT INTO deployments.candidates VALUES (id, instance.id, instance.revision, instance.generation,
      request.action, configuration.id, placement_id, instance.native_definition, digest);
    RETURN JSON_OBJECT('id', id, 'digest', digest, 'action', request.action,
      'target_revision', instance.revision, 'configuration', configuration.id, 'placement', placement_id);
  END;

CREATE DATAFLOW deployments.admit_candidate
  FROM COMMAND (
    candidate_id UUID,
    candidate_digest BINARY,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET candidate = SELECT * FROM deployments.candidates WHERE id = request.candidate_id;
    REQUIRE candidate IS NOT NULL AND candidate.digest = request.candidate_digest ELSE 'InvalidCandidate';
    LET instance = SELECT * FROM deployments.instances WHERE id = candidate.instance_id;
    REQUIRE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', instance.authority) ELSE 'Forbidden';
    -- AUTHORIZATION is an exact review or a current, bounded standing grant.
    -- Native validation also enforces action rights; knowing a digest grants none.
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), instance.authority,
      candidate.action, candidate.digest, candidate.expected_revision) ELSE 'Forbidden';
    REQUIRE instance.revision = candidate.expected_revision AND instance.generation = candidate.expected_generation
      AND instance.active_operation IS NULL ELSE 'StaleTarget';
    LET placement = SELECT * FROM deployments.placements WHERE id = candidate.placement_id;
    LET profile = SELECT * FROM deployments.profiles WHERE id = placement.profile_id;
    REQUIRE NOT EXISTS (SELECT 1 FROM networking.target_holds WHERE target_id = instance.id AND mutating AND NOT released) ELSE 'Referenced';
    LET configuration = SELECT * FROM deployments.instance_configurations WHERE id = candidate.configuration_id;
    REQUIRE profile.enabled AND profile._revision = placement.profile_revision
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', profile.authority) ELSE 'ProfileChanged';
    IF candidate.action IN ('retire', 'purge') THEN
      REQUIRE NOT instance.deletion_protected ELSE 'DeletionProtected';
      REQUIRE NOT EXISTS (SELECT 1 FROM networking.target_holds WHERE target_id = instance.id AND NOT released)
        ELSE 'Referenced';
    END IF;
    IF candidate.action = 'purge' THEN
      REQUIRE instance.retain_until IS NOT NULL AND instance.retain_until <= NOW()
        AND NOT EXISTS (SELECT 1 FROM deployments.retention_holds WHERE instance_id = instance.id AND released_at IS NULL)
        ELSE 'Retained';
    END IF;
    LET running = candidate.action IN ('provision', 'replace', 'resume');
    LET cpu = CASE WHEN running THEN configuration.cpu ELSE 0 END;
    LET memory = CASE WHEN running THEN configuration.memory ELSE 0 END;
    LET storage = CASE WHEN candidate.action = 'provision' THEN configuration.storage ELSE 0 END;
    -- Serializable predicate reads protect empty ranges and concurrent admission.
    -- Replacement reserves its full new compute before releasing the old hold.
    LET used = SELECT COALESCE(SUM(CASE WHEN compute_released THEN 0 ELSE cpu END), 0) AS cpu,
      COALESCE(SUM(CASE WHEN compute_released THEN 0 ELSE memory END), 0) AS memory,
      COALESCE(SUM(CASE WHEN storage_released THEN 0 ELSE storage END), 0) AS storage,
      COALESCE(SUM(CASE WHEN storage_released THEN 0 ELSE instances END), 0) AS instances
      FROM deployments.reservations WHERE profile_id = profile.id;
    REQUIRE used.cpu + cpu <= profile.cpu_limit AND used.memory + memory <= profile.memory_limit
      AND used.storage + storage <= profile.storage_limit
      AND used.instances + CASE WHEN candidate.action = 'provision' THEN 1 ELSE 0 END <= profile.instance_limit
      ELSE 'CapacityExceeded';
    LET id = OPERATION_ID(CURRENT_REQUEST_ID(), 'deployment');
    LET operation = ACCEPT OPERATION id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE candidate.digest TARGET instance.id REVISION instance.revision;
    INSERT INTO deployments.operations VALUES (id, candidate.id, instance.id, instance.generation + 1,
      CURRENT_SUBJECT(), operation);
    INSERT INTO deployments.reservations VALUES (id, instance.id, profile.id, cpu, memory, storage,
      CASE WHEN candidate.action = 'provision' THEN 1 ELSE 0 END, FALSE, FALSE);
    UPDATE deployments.instances SET active_operation = id, revision = revision + 1, generation = generation + 1
      WHERE id = instance.id AND revision = candidate.expected_revision;
    ENQUEUE INTO deployments.lifecycle VALUES (id) CONTINUATION operation;
    RETURN JSON_OBJECT('operation_id', id, 'native_operation', operation, 'outcome', 'accepted');
  END;

AUTHORIZE DATAFLOW deployments.prepare_candidate AS ROLE SETTING('deployments.executor_role');
AUTHORIZE DATAFLOW deployments.admit_candidate AS ROLE SETTING('deployments.executor_role');
ACTIVATE DATAFLOW deployments.prepare_candidate;

-- Native AWS operations use the exact connection/account/region frozen by the
-- placement, under separate effect authority. No customer-supplied AWS action,
-- endpoint, IAM role or template is accepted by these sinks.
CREATE SINK deployments.create_stack INTO AWS OPERATION 'cloudformation:CreateStack'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');
CREATE SINK deployments.update_stack INTO AWS OPERATION 'cloudformation:UpdateStack'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');
CREATE SINK deployments.delete_stack INTO AWS OPERATION 'cloudformation:DeleteStack'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');

CREATE DATAFLOW deployments.provision_instance
  FROM QUEUE deployments.lifecycle AS request
    WHERE (SELECT c.action FROM deployments.operations o JOIN deployments.candidates c ON c.id = o.candidate_id WHERE o.id = request.operation_id) = 'provision'
  AS BEGIN
    LET operation = SELECT * FROM deployments.operations WHERE id = request.operation_id;
    LET candidate = SELECT * FROM deployments.candidates WHERE id = operation.candidate_id;
    LET instance = SELECT * FROM deployments.instances WHERE id = operation.instance_id;
    LET placement = SELECT * FROM deployments.placements WHERE id = candidate.placement_id;
    LET profile = SELECT * FROM deployments.profiles WHERE id = placement.profile_id;
    LET configuration = SELECT * FROM deployments.instance_configurations WHERE id = candidate.configuration_id;
    REQUIRE NATIVE_OPERATION_CURRENT(operation.native_ref)
      AND instance.active_operation = operation.id AND instance.generation = operation.generation
      AND profile._revision = placement.profile_revision ELSE 'StaleOperation';
    -- This generic native allocator creates a protected installation identity and
    -- bootstrap secret reference, not a provisioner or hidden lifecycle program.
    LET bootstrap = ALLOCATE INSTALLATION instance.installation_id USING PLACEMENT placement.id
      EFFECT OPERATION_ID(operation.id, 'bootstrap') OWNER instance.authority
      DEFINITION configuration.native_definition
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id);
    LET stack = EXECUTE SINK deployments.create_stack
      EFFECT OPERATION_ID(operation.id, 'create-stack') USING PLACEMENT placement.id
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
      REQUEST JSON_OBJECT(
        'StackName', 'spoke-' || CAST(instance.installation_id AS TEXT),
        'ClientRequestToken', CAST(OPERATION_ID(operation.id, 'create-stack') AS TEXT),
        'TemplateBody', ARTIFACT_TEXT(profile.template, placement.template_sha256),
        'RoleARN', profile.cloud_role_ref, 'DisableRollback', TRUE,
        'Parameters', AWS_PARAMETERS(placement.configuration, JSON_OBJECT(
          'InstallationId', instance.installation_id, 'WriterGeneration', operation.generation,
          'RuntimeImage', configuration.runtime_image, 'NativeDefinition', configuration.native_definition,
          'RuntimeConfiguration', configuration.runtime_configuration,
          'ConfigurationDigest', configuration.configuration_sha256, 'BootstrapSecretRef', bootstrap.secret_ref,
          'Cpu', configuration.cpu, 'Memory', configuration.memory, 'StorageLimit', configuration.storage, 'DesiredCount', 1)),
        'Tags', AWS_TAGS(instance.id, operation.id, candidate.digest)
      ) ON REPLAY OBSERVE ONLY;
    REQUIRE stack.accepted AND stack.resource_id IS NOT NULL ELSE 'ProviderRefused';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id) ELSE 'Forbidden';
      INSERT INTO deployments.cloud_resources VALUES (instance.id, '$stack', placement.provider,
        placement.cloud_account, placement.region, 'AWS::CloudFormation::Stack', stack.resource_id,
        stack.incarnation, operation.id, operation.generation, FALSE, FALSE)
        ON CONFLICT DO ASSERT SAME ROW;
      ENQUEUE INTO deployments.verification VALUES (operation.id) CONTINUATION operation.native_ref;
      HANDOFF operation.native_ref TO deployments.verification;
    END;
  ON FAILURE failure
    -- Native outcome remains authoritative. Do not erase the admission or its
    -- reservations: a partial/unknown stack can still own billable resources.
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

AUTHORIZE SINK deployments.create_stack AS ROLE SETTING('deployments.effect_role');
AUTHORIZE SINK deployments.update_stack AS ROLE SETTING('deployments.effect_role');
AUTHORIZE SINK deployments.delete_stack AS ROLE SETTING('deployments.effect_role');
AUTHORIZE DATAFLOW deployments.provision_instance AS ROLE SETTING('deployments.executor_role');
ACTIVATE SINK deployments.create_stack;
ACTIVATE SINK deployments.update_stack;
ACTIVATE SINK deployments.delete_stack;
ACTIVATE DATAFLOW deployments.provision_instance;

-- Observation is native, bounded scheduled work. Neither a browser read nor a
-- Platform polling process drives it. All evidence names the exact generation.
CREATE DATAFLOW deployments.observe_instance
  FROM QUEUE deployments.verification AS request
  AS BEGIN
    LET operation = SELECT * FROM deployments.operations WHERE id = request.operation_id;
    LET candidate = SELECT * FROM deployments.candidates WHERE id = operation.candidate_id;
    LET instance = SELECT * FROM deployments.instances WHERE id = operation.instance_id;
    LET placement = SELECT * FROM deployments.placements WHERE id = candidate.placement_id;
    LET configuration = SELECT * FROM deployments.instance_configurations WHERE id = candidate.configuration_id;
    LET stack = SELECT * FROM deployments.cloud_resources
      WHERE instance_id = instance.id AND logical_id = '$stack' AND NOT retired;
    REQUIRE candidate.action IN ('provision', 'replace', 'resume') AND stack IS NOT NULL ELSE 'InvalidOperation';
    LET cloud = AWAIT OBSERVATION FROM AWS STACK stack.resource_id USING PLACEMENT placement.id
      EFFECT OPERATION_ID(operation.id, 'stack-ready')
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
      UNTIL status IN ('CREATE_COMPLETE', 'UPDATE_COMPLETE', 'CREATE_FAILED', 'UPDATE_FAILED', 'UPDATE_ROLLBACK_COMPLETE')
      WITH (deadline = '20m', interval = '10s', max_resources = 64, max_bytes = 262144);
    -- Bind every positively observed resource before readiness can fail. Native
    -- receipts retain partial/unknown discovery; it never proves missing=absent.
    REQUIRE cloud.stack_incarnation = stack.incarnation AND cloud.operation_id = operation.id
      ELSE 'ObservationMismatch';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id) ELSE 'StaleOperation';
      FOR resource IN cloud.resources DO
        LET existing = SELECT * FROM deployments.cloud_resources
          WHERE provider = placement.provider AND cloud_account = placement.cloud_account
            AND region = placement.region AND resource_type = resource.type
            AND resource_id = resource.id AND incarnation = resource.incarnation;
        IF existing IS NULL THEN
          INSERT INTO deployments.cloud_resources VALUES (instance.id, resource.logical_id, placement.provider,
            placement.cloud_account, placement.region, resource.type, resource.id, resource.incarnation,
            operation.id, operation.generation, resource.retained, FALSE);
        ELSE
          REQUIRE existing.instance_id = instance.id AND existing.logical_id = resource.logical_id
            AND NOT existing.retired AND existing.retained = resource.retained ELSE 'ResourceOwnershipConflict';
        END IF;
      END FOR;
      PRODUCE INTO deployments.observations VALUES (instance.id, operation.id, operation.generation,
        EVIDENCE_SET(cloud), NOW());
    END;
    REQUIRE cloud.complete AND cloud.status IN ('CREATE_COMPLETE', 'UPDATE_COMPLETE')
      AND cloud.stack_incarnation = stack.incarnation
      AND cloud.template_sha256 = placement.template_sha256
      AND cloud.parameters.WriterGeneration = operation.generation ELSE 'CloudNotReady';
    -- The peer must prove possession of this installation's bootstrap identity.
    -- It reports native ledger verification and retained storage, not just health.
    LET proof = AWAIT OBSERVATION FROM TRANSIT INSTALLATION instance.installation_id
      AT cloud.private_endpoint EFFECT OPERATION_ID(operation.id, 'installation-ready')
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
      WITH (deadline = '10m', interval = '10s', authentication = 'installation_identity');
    REQUIRE proof.installation_id = instance.installation_id AND proof.writer_generation = operation.generation
      AND proof.runtime_image = configuration.runtime_image AND proof.native_definition = configuration.native_definition
      AND proof.runtime_configuration = configuration.runtime_configuration
      AND RETAINED_INSTALLATION_VERIFIED(proof, instance.installation_id, candidate.expected_generation,
        operation.generation, configuration.runtime_image, configuration.native_definition)
      AND proof.configuration_sha256 = configuration.configuration_sha256
      AND proof.storage_identity = cloud.storage_identity AND proof.private_endpoint_verified
      AND proof.single_writer ELSE 'InstallationNotVerified';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id) ELSE 'StaleOperation';
      PRODUCE INTO deployments.observations VALUES (instance.id, operation.id, operation.generation,
        EVIDENCE_SET(cloud, proof), NOW());
      -- Promotion is this conditional decision, not a second background owner.
      UPDATE deployments.instances SET active_configuration = configuration.id, active_placement = placement.id,
        native_definition = configuration.native_definition, desired_state = 'running', active_operation = NULL,
        revision = revision + 1 WHERE id = instance.id AND active_operation = operation.id;
      -- Old compute is released only after native fencing proof. Storage holds
      -- from provisioning survive every subsequent compute operation.
      REQUIRE candidate.action = 'provision' OR proof.previous_writer_fenced ELSE 'WriterNotFenced';
      UPDATE deployments.reservations SET compute_released = TRUE
        WHERE instance_id = instance.id AND operation_id <> operation.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('instance_id', instance.id,
        'configuration', configuration.id, 'generation', operation.generation, 'outcome', 'ready');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

-- These publications serve management clients. Current native rights decide
-- every disclosure, including exact-item reads and each continuation page.
-- Public resource references are inspectable; connection/credential handles,
-- bootstrap material, placement configuration and raw native grants stay private.
-- Candidate resource amounts are frozen review inputs. The current_* columns
-- are separately labeled observations and never authorize admission.

CREATE PUBLICATION deployments.configuration_catalog AS
  SELECT r.id, r.instance_id, r.runtime_image, r.native_definition,
    r.configuration_sha256, r.cpu, r.memory, r.storage
  FROM deployments.instance_configurations r JOIN deployments.instances i ON i.id = r.instance_id
  WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', i.authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('deployments.reader_role'),
    response_profile = 'platform.instance-configurations.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/instance-configurations',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/instance-configurations/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );

CREATE PUBLICATION deployments.profile_catalog AS
  SELECT id, _revision AS revision, provider, cloud_account, region,
    cpu_limit, memory_limit, storage_limit, instance_limit, minimum_retention_seconds
  FROM deployments.profiles
  WHERE enabled AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('deployments.reader_role'),
    response_profile = 'platform.profiles.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/profiles',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/profiles/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );

CREATE PUBLICATION deployments.candidate_catalog AS
  SELECT c.id, c.instance_id, c.digest, c.expected_revision, c.expected_generation,
    c.action, c.configuration_id, c.placement_id, c.retained_definition,
    r.runtime_image, r.native_definition, r.configuration_sha256,
    r.cpu, r.memory, r.storage,
    p.profile_id, p.profile_revision, p.provider, p.cloud_account, p.region, p.template_sha256,
    CASE WHEN c.action IN ('provision', 'replace', 'resume') THEN r.cpu ELSE 0 END AS reserve_cpu,
    CASE WHEN c.action IN ('provision', 'replace', 'resume') THEN r.memory ELSE 0 END AS reserve_memory,
    CASE WHEN c.action = 'provision' THEN r.storage ELSE 0 END AS reserve_storage,
    CASE WHEN c.action = 'provision' THEN 1 ELSE 0 END AS reserve_instances,
    i.revision AS current_revision, i.generation AS current_generation,
    i.deletion_protected AS current_deletion_protected, i.retain_until AS current_retain_until
  FROM deployments.candidates c
    JOIN deployments.instances i ON i.id = c.instance_id
    JOIN deployments.instance_configurations r ON r.id = c.configuration_id
    JOIN deployments.placements p ON p.id = c.placement_id
    JOIN deployments.profiles profile ON profile.id = p.profile_id
  WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', i.authority)
    AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', profile.authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('deployments.reader_role'),
    response_profile = 'platform.candidates.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/candidates',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/candidates/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );

CREATE PUBLICATION deployments.instance_catalog AS
  SELECT i.id, i.environment_id, i.name, i.network_id, i.revision, i.generation,
    i.desired_state, i.active_configuration, i.active_operation, i.deletion_protected, i.retain_until
  FROM deployments.instances i WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', i.authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('deployments.reader_role'),
    response_profile = 'platform.instances.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/instances',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/instances/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );

CREATE PUBLICATION deployments.operation_catalog AS
  SELECT o.id, o.instance_id, o.candidate_id, o.generation, NATIVE_OUTCOME(o.native_ref) AS outcome
  FROM deployments.operations o JOIN deployments.instances i ON i.id = o.instance_id
  WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', i.authority)
    AND NATIVE_OPERATION_VISIBLE(CURRENT_SUBJECT(), o.native_ref)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('deployments.reader_role'),
    response_profile = 'platform.operations.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/operations',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/operations/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );

AUTHORIZE DATAFLOW deployments.observe_instance AS ROLE SETTING('deployments.executor_role');
AUTHORIZE PUBLICATION deployments.instance_catalog;
AUTHORIZE PUBLICATION deployments.operation_catalog;
ACTIVATE DATAFLOW deployments.observe_instance;
ACTIVATE PUBLICATION deployments.instance_catalog;
ACTIVATE PUBLICATION deployments.operation_catalog;
AUTHORIZE PUBLICATION deployments.configuration_catalog;
ACTIVATE PUBLICATION deployments.configuration_catalog;
AUTHORIZE PUBLICATION deployments.profile_catalog;
ACTIVATE PUBLICATION deployments.profile_catalog;
AUTHORIZE PUBLICATION deployments.candidate_catalog;
ACTIVATE PUBLICATION deployments.candidate_catalog;

-- Stack updates use the identical reviewed template and immutable placement.
-- DesiredCount=0 and verified writer configuration precede any new image/definition.
CREATE DATAFLOW deployments.replace_instance
  FROM QUEUE deployments.lifecycle AS request
    WHERE (SELECT c.action FROM deployments.operations o JOIN deployments.candidates c ON c.id = o.candidate_id WHERE o.id = request.operation_id) IN ('replace', 'resume', 'suspend')
  AS BEGIN
    LET operation = SELECT * FROM deployments.operations WHERE id = request.operation_id;
    LET candidate = SELECT * FROM deployments.candidates WHERE id = operation.candidate_id;
    LET instance = SELECT * FROM deployments.instances WHERE id = operation.instance_id;
    LET placement = SELECT * FROM deployments.placements WHERE id = candidate.placement_id;
    LET configuration = SELECT * FROM deployments.instance_configurations WHERE id = candidate.configuration_id;
    LET stack = SELECT * FROM deployments.cloud_resources
      WHERE instance_id = instance.id AND logical_id = '$stack' AND NOT retired;
    REQUIRE stack IS NOT NULL AND instance.native_definition = candidate.retained_definition
      AND instance.native_definition = configuration.native_definition ELSE 'IncompatibleDefinition';
    -- Native comparison verifies the actual retained installation before stopping
    -- compute; metadata alone cannot authorize a binary/storage cutover.
    LET compatibility = OBSERVE TRANSIT INSTALLATION instance.installation_id
      EFFECT OPERATION_ID(operation.id, 'compatibility') USING PLACEMENT placement.id
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id);
    REQUIRE compatibility.native_definition = configuration.native_definition
      AND compatibility.installation_id = instance.installation_id ELSE 'IncompatibleDefinition';
    LET stop = EXECUTE SINK deployments.update_stack
      EFFECT OPERATION_ID(operation.id, 'stop') USING PLACEMENT placement.id
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
      REQUEST JSON_OBJECT('StackName', stack.resource_id, 'UsePreviousTemplate', TRUE,
        'ClientRequestToken', CAST(OPERATION_ID(operation.id, 'stop') AS TEXT),
        'Parameters', AWS_PREVIOUS_PARAMETERS(JSON_OBJECT('DesiredCount', 0))) ON REPLAY OBSERVE ONLY;
    REQUIRE stop.accepted ELSE 'ProviderRefused';
    LET stopped = AWAIT OBSERVATION FROM AWS STACK stack.resource_id USING PLACEMENT placement.id
      EFFECT OPERATION_ID(operation.id, 'stopped')
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
      UNTIL status = 'UPDATE_COMPLETE' AND desired_count = 0 AND running_count = 0 WITH (deadline = '20m', interval = '10s');
    REQUIRE stopped.complete AND stopped.stack_incarnation = stack.incarnation
      AND stopped.operation_id = operation.id AND stopped.template_sha256 = placement.template_sha256
      ELSE 'StopUnverified';
    LET fence = FENCE INSTALLATION instance.installation_id BEFORE GENERATION operation.generation
      EFFECT OPERATION_ID(operation.id, 'fence') EVIDENCE stopped
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id);
    REQUIRE fence.previous_writer_released ELSE 'WriterNotFenced';
    IF candidate.action = 'suspend' THEN
      BEGIN ATOMIC
        REQUIRE EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id) ELSE 'StaleOperation';
        PRODUCE INTO deployments.observations VALUES (instance.id, operation.id, operation.generation,
          EVIDENCE_SET(stopped, fence), NOW());
        UPDATE deployments.instances SET desired_state = 'stopped', active_operation = NULL, revision = revision + 1
          WHERE id = instance.id AND active_operation = operation.id;
        UPDATE deployments.reservations SET compute_released = TRUE WHERE instance_id = instance.id;
        COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('instance_id', instance.id, 'outcome', 'stopped');
      END;
    ELSE
      LET start = EXECUTE SINK deployments.update_stack
        EFFECT OPERATION_ID(operation.id, 'start') USING PLACEMENT placement.id
        GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
          AND FENCE_CURRENT(fence)
        REQUEST JSON_OBJECT('StackName', stack.resource_id, 'UsePreviousTemplate', TRUE,
          'ClientRequestToken', CAST(OPERATION_ID(operation.id, 'start') AS TEXT),
          'Parameters', AWS_PREVIOUS_PARAMETERS(JSON_OBJECT(
            'RuntimeImage', configuration.runtime_image, 'NativeDefinition', configuration.native_definition,
            'RuntimeConfiguration', configuration.runtime_configuration,
            'ConfigurationDigest', configuration.configuration_sha256, 'WriterGeneration', operation.generation,
            'Cpu', configuration.cpu, 'Memory', configuration.memory, 'DesiredCount', 1))) ON REPLAY OBSERVE ONLY;
      REQUIRE start.accepted ELSE 'ProviderRefused';
      BEGIN ATOMIC
        REQUIRE EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id) ELSE 'StaleOperation';
        ENQUEUE INTO deployments.verification VALUES (operation.id) CONTINUATION operation.native_ref;
        HANDOFF operation.native_ref TO deployments.verification;
      END;
    END IF;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;
AUTHORIZE DATAFLOW deployments.replace_instance AS ROLE SETTING('deployments.executor_role');
ACTIVATE DATAFLOW deployments.replace_instance;

-- Protection changes are explicit, current-authority metadata transactions.
-- Protection can be enabled while work is pending, invalidating its next guard.
CREATE DATAFLOW deployments.protect_instance
  FROM COMMAND (
    instance_id UUID,
    expected_revision BIGINT,
    protected BOOLEAN
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET instance = SELECT * FROM deployments.instances WHERE id = request.instance_id;
    REQUIRE instance IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'protect', instance.authority) ELSE 'Forbidden';
    REQUIRE instance.revision = request.expected_revision ELSE 'StaleTarget';
    UPDATE deployments.instances SET deletion_protected = request.protected, revision = revision + 1
      WHERE id = instance.id AND revision = request.expected_revision;
    RETURN JSON_OBJECT('id', instance.id, 'revision', instance.revision + 1, 'protected', request.protected);
  END;

-- A new hold cannot race an admitted purge. Protection can still stop future
-- undispatched effects; it cannot undo an already accepted remote deletion.
CREATE DATAFLOW deployments.hold_instance
  FROM COMMAND (
    instance_id UUID,
    expected_revision BIGINT,
    reason TEXT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET instance = SELECT * FROM deployments.instances WHERE id = request.instance_id;
    REQUIRE instance IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'hold', instance.authority) ELSE 'Forbidden';
    REQUIRE instance.revision = request.expected_revision AND instance.active_operation IS NULL ELSE 'StaleTarget';
    REQUIRE LENGTH(request.reason) BETWEEN 1 AND 1000 ELSE 'InvalidReason';
    REQUIRE EXISTS (SELECT 1 FROM deployments.cloud_resources WHERE instance_id = instance.id AND retained AND NOT retired)
      ELSE 'NoRetainedResources';
    LET id = OPERATION_ID(CURRENT_REQUEST_ID(), 'hold');
    INSERT INTO deployments.retention_holds VALUES (id, instance.id, request.reason, instance.authority, NULL);
    UPDATE deployments.instances SET revision = revision + 1 WHERE id = instance.id;
    RETURN JSON_OBJECT('hold_id', id, 'revision', instance.revision + 1);
  END;

CREATE DATAFLOW deployments.release_hold
  FROM COMMAND (
    hold_id UUID,
    expected_revision BIGINT
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET hold = SELECT * FROM deployments.retention_holds WHERE id = request.hold_id;
    REQUIRE hold IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'hold', hold.authority) ELSE 'Forbidden';
    LET instance = SELECT * FROM deployments.instances WHERE id = hold.instance_id;
    REQUIRE instance.revision = request.expected_revision AND instance.active_operation IS NULL ELSE 'StaleTarget';
    REQUIRE hold.released_at IS NULL ELSE 'AlreadyReleased';
    UPDATE deployments.retention_holds SET released_at = NOW() WHERE id = hold.id;
    UPDATE deployments.instances SET revision = revision + 1 WHERE id = instance.id;
    RETURN JSON_OBJECT('hold_id', hold.id, 'revision', instance.revision + 1);
  END;

CREATE DATAFLOW deployments.retire_instance
  FROM QUEUE deployments.lifecycle AS request WHERE (SELECT c.action FROM deployments.operations o JOIN deployments.candidates c ON c.id = o.candidate_id WHERE o.id = request.operation_id) = 'retire'
  AS BEGIN
    LET operation = SELECT * FROM deployments.operations WHERE id = request.operation_id;
    LET candidate = SELECT * FROM deployments.candidates WHERE id = operation.candidate_id;
    LET instance = SELECT * FROM deployments.instances WHERE id = operation.instance_id;
    LET placement = SELECT * FROM deployments.placements WHERE id = candidate.placement_id;
    LET profile = SELECT * FROM deployments.profiles WHERE id = placement.profile_id;
    LET stack = SELECT * FROM deployments.cloud_resources
      WHERE instance_id = instance.id AND logical_id = '$stack' AND NOT retired;
    REQUIRE stack IS NOT NULL ELSE 'ResourceNotObserved';
    LET stop = EXECUTE SINK deployments.update_stack
      EFFECT OPERATION_ID(operation.id, 'retire-stop') USING PLACEMENT placement.id
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
      REQUEST JSON_OBJECT('StackName', stack.resource_id, 'UsePreviousTemplate', TRUE,
        'ClientRequestToken', CAST(OPERATION_ID(operation.id, 'retire-stop') AS TEXT),
        'Parameters', AWS_PREVIOUS_PARAMETERS(JSON_OBJECT('DesiredCount', 0))) ON REPLAY OBSERVE ONLY;
    REQUIRE stop.accepted ELSE 'ProviderRefused';
    LET stopped = AWAIT OBSERVATION FROM AWS STACK stack.resource_id USING PLACEMENT placement.id
      EFFECT OPERATION_ID(operation.id, 'retire-stopped')
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
      UNTIL status = 'UPDATE_COMPLETE' AND desired_count = 0 AND running_count = 0 WITH (deadline = '20m', interval = '10s');
    REQUIRE stopped.complete AND stopped.stack_incarnation = stack.incarnation
      AND stopped.operation_id = operation.id AND stopped.template_sha256 = placement.template_sha256
      ELSE 'StopUnverified';
    LET fence = FENCE INSTALLATION instance.installation_id BEFORE GENERATION operation.generation
      EFFECT OPERATION_ID(operation.id, 'retire-fence') EVIDENCE stopped
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id);
    REQUIRE fence.previous_writer_released ELSE 'WriterNotFenced';
    -- The qualified immutable template retains storage/credentials on both
    -- deletion and replacement. No FORCE_DELETE_STACK or rollback cleanup.
    LET deletion = EXECUTE SINK deployments.delete_stack
      EFFECT OPERATION_ID(operation.id, 'retire-stack') USING PLACEMENT placement.id
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id) AND FENCE_CURRENT(fence)
      REQUEST JSON_OBJECT('StackName', stack.resource_id, 'DeletionMode', 'STANDARD',
        'ClientRequestToken', CAST(OPERATION_ID(operation.id, 'retire-stack') AS TEXT)) ON REPLAY OBSERVE ONLY;
    REQUIRE deletion.accepted ELSE 'ProviderRefused';
    LET removed = AWAIT OBSERVATION FROM AWS STACK stack.resource_id USING PLACEMENT placement.id
      EFFECT OPERATION_ID(operation.id, 'retired')
      GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
      UNTIL status = 'DELETE_COMPLETE' WITH (deadline = '20m', interval = '10s', retained_inventory = TRUE);
    REQUIRE removed.complete AND removed.retained_resources_verified AND removed.endpoint_withdrawn ELSE 'RetirementUnverified';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id) ELSE 'StaleOperation';
      PRODUCE INTO deployments.observations VALUES (instance.id, operation.id, operation.generation,
        EVIDENCE_SET(removed, fence), NOW());
      UPDATE deployments.cloud_resources SET retired = TRUE WHERE instance_id = instance.id AND NOT retained;
      UPDATE deployments.instances SET desired_state = 'retired', active_operation = NULL,
        retain_until = NOW() + SECONDS(profile.minimum_retention_seconds), revision = revision + 1
        WHERE id = instance.id AND active_operation = operation.id;
      UPDATE deployments.reservations SET compute_released = TRUE WHERE instance_id = instance.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('instance_id', instance.id, 'outcome', 'retired');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

-- Purge is separately admitted, authorized and exact-resource bounded. The
-- generic connector observes original deletion outcomes before any later step.
CREATE SINK deployments.purge_resource INTO AWS OPERATION 'delete_exact_retained_resource'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation',
    resource_types = 'AWS::EFS::AccessPoint,AWS::EFS::FileSystem,AWS::SecretsManager::Secret');

CREATE DATAFLOW deployments.purge_retained_storage
  FROM QUEUE deployments.lifecycle AS request WHERE (SELECT c.action FROM deployments.operations o JOIN deployments.candidates c ON c.id = o.candidate_id WHERE o.id = request.operation_id) = 'purge'
  AS BEGIN
    LET operation = SELECT * FROM deployments.operations WHERE id = request.operation_id;
    LET candidate = SELECT * FROM deployments.candidates WHERE id = operation.candidate_id;
    LET instance = SELECT * FROM deployments.instances WHERE id = operation.instance_id;
    LET resources = SELECT * FROM deployments.cloud_resources
      WHERE instance_id = instance.id AND retained AND NOT retired ORDER BY resource_type, resource_id;
    REQUIRE instance.desired_state = 'retired' ELSE 'NotRetired';
    FOR resource IN resources DO
      LET deletion = EXECUTE SINK deployments.purge_resource
        EFFECT OPERATION_ID(operation.id, DIGEST(ROW(resource.resource_type, resource.resource_id, resource.incarnation))) USING PLACEMENT candidate.placement_id
        GUARD EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
          AND NO_NATIVE_RESOURCE_REFERENCES(resource.resource_id, resource.incarnation)
        REQUEST JSON_OBJECT('Type', resource.resource_type, 'Id', resource.resource_id,
          'Incarnation', resource.incarnation, 'Force', FALSE) ON REPLAY OBSERVE ONLY;
      REQUIRE deletion.absence_verified ELSE 'DeletionUnresolved';
      BEGIN ATOMIC
        REQUIRE EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id) ELSE 'StaleOperation';
        UPDATE deployments.cloud_resources SET retired = TRUE
          WHERE instance_id = instance.id AND resource_id = resource.resource_id AND incarnation = resource.incarnation;
        PRODUCE INTO deployments.observations VALUES (instance.id, operation.id, operation.generation, deletion.evidence, NOW());
      END;
    END FOR;
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM deployments.authorized_operations WHERE id = operation.id)
        AND NOT EXISTS (SELECT 1 FROM deployments.cloud_resources WHERE instance_id = instance.id AND NOT retired)
        ELSE 'RetainedResourcesRemain';
      UPDATE deployments.reservations SET storage_released = TRUE WHERE instance_id = instance.id;
      UPDATE deployments.instances SET active_operation = NULL, revision = revision + 1 WHERE id = instance.id;
      UPDATE networking.attachments SET released = TRUE WHERE consumer_id = instance.id AND consumer_kind = 'transit_instance';
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('instance_id', instance.id, 'outcome', 'purged');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

AUTHORIZE DATAFLOW deployments.hold_instance AS ROLE SETTING('deployments.executor_role');
AUTHORIZE DATAFLOW deployments.release_hold AS ROLE SETTING('deployments.executor_role');
ACTIVATE DATAFLOW deployments.hold_instance;
ACTIVATE DATAFLOW deployments.release_hold;
AUTHORIZE DATAFLOW deployments.protect_instance AS ROLE SETTING('deployments.executor_role');
AUTHORIZE DATAFLOW deployments.retire_instance AS ROLE SETTING('deployments.executor_role');
AUTHORIZE DATAFLOW deployments.purge_retained_storage AS ROLE SETTING('deployments.executor_role');
AUTHORIZE SINK deployments.purge_resource AS ROLE SETTING('deployments.effect_role');
ACTIVATE DATAFLOW deployments.protect_instance;
ACTIVATE DATAFLOW deployments.retire_instance;
ACTIVATE DATAFLOW deployments.purge_retained_storage;
ACTIVATE SINK deployments.purge_resource;
-- Admission opens only after all lifecycle consumers and sinks are installed.
ACTIVATE DATAFLOW deployments.admit_candidate;

-- HTTP invokes the installed command under the original authenticated subject.
-- The native command_json_v1 profile owns strict decoding, request identity,
-- current-session/grant checks and retained results; it contains no product policy.
-- GET result_path observes the original result and never invokes the command.

CREATE SOURCE deployments.register_instance_http
  FROM HTTP REQUEST
  INTO COMMAND deployments.register_instance
  WITH (
    method = 'POST',
    path = '/platform/v1/environments/{environment_id}/instances',
    path_arguments = JSON '["environment_id"]',
    body_arguments = JSON '["expected_revision","name","network_id","network_revision"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/deployments.register_instance/{request_id}',
    response_status = 201,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE deployments.register_configuration_http
  FROM HTTP REQUEST
  INTO COMMAND deployments.register_configuration
  WITH (
    method = 'POST',
    path = '/platform/v1/instances/{instance_id}/configurations',
    path_arguments = JSON '["instance_id"]',
    body_arguments = JSON '["expected_revision","runtime_image","native_definition","runtime_configuration","configuration_sha256","cpu","memory","storage"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/deployments.register_configuration/{request_id}',
    response_status = 201,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE deployments.prepare_candidate_http
  FROM HTTP REQUEST
  INTO COMMAND deployments.prepare_candidate
  WITH (
    method = 'POST',
    path = '/platform/v1/instances/{instance_id}/candidates',
    path_arguments = JSON '["instance_id"]',
    body_arguments = JSON '["expected_revision","action","configuration_id","profile_id"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/deployments.prepare_candidate/{request_id}',
    response_status = 201,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE deployments.admit_candidate_http
  FROM HTTP REQUEST
  INTO COMMAND deployments.admit_candidate
  WITH (
    method = 'POST',
    path = '/platform/v1/candidates/{candidate_id}/admissions',
    path_arguments = JSON '["candidate_id"]',
    body_arguments = JSON '["candidate_digest","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/deployments.admit_candidate/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE deployments.protect_instance_http
  FROM HTTP REQUEST
  INTO COMMAND deployments.protect_instance
  WITH (
    method = 'PATCH',
    path = '/platform/v1/instances/{instance_id}/protection',
    path_arguments = JSON '["instance_id"]',
    body_arguments = JSON '["expected_revision","protected"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/deployments.protect_instance/{request_id}',
    response_status = 200,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE deployments.hold_instance_http
  FROM HTTP REQUEST
  INTO COMMAND deployments.hold_instance
  WITH (
    method = 'POST',
    path = '/platform/v1/instances/{instance_id}/holds',
    path_arguments = JSON '["instance_id"]',
    body_arguments = JSON '["expected_revision","reason"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/deployments.hold_instance/{request_id}',
    response_status = 201,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

CREATE SOURCE deployments.release_hold_http
  FROM HTTP REQUEST
  INTO COMMAND deployments.release_hold
  WITH (
    method = 'POST',
    path = '/platform/v1/holds/{hold_id}/release',
    path_arguments = JSON '["hold_id"]',
    body_arguments = JSON '["expected_revision"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/deployments.release_hold/{request_id}',
    response_status = 200,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );

-- Route activation follows command authorization and activation. It grants no
-- caller rights; the dataflows still enforce their own current native authority.
AUTHORIZE SOURCE deployments.register_instance_http AS ROLE SETTING('deployments.executor_role');
AUTHORIZE SOURCE deployments.register_configuration_http AS ROLE SETTING('deployments.executor_role');
AUTHORIZE SOURCE deployments.prepare_candidate_http AS ROLE SETTING('deployments.executor_role');
AUTHORIZE SOURCE deployments.admit_candidate_http AS ROLE SETTING('deployments.executor_role');
AUTHORIZE SOURCE deployments.protect_instance_http AS ROLE SETTING('deployments.executor_role');
AUTHORIZE SOURCE deployments.hold_instance_http AS ROLE SETTING('deployments.executor_role');
AUTHORIZE SOURCE deployments.release_hold_http AS ROLE SETTING('deployments.executor_role');
ACTIVATE SOURCE deployments.register_instance_http;
ACTIVATE SOURCE deployments.register_configuration_http;
ACTIVATE SOURCE deployments.prepare_candidate_http;
ACTIVATE SOURCE deployments.admit_candidate_http;
ACTIVATE SOURCE deployments.protect_instance_http;
ACTIVATE SOURCE deployments.hold_instance_http;
ACTIVATE SOURCE deployments.release_hold_http;
