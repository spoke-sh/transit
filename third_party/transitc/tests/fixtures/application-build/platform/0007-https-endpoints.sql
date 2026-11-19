-- Native contract and qualification: contracts/fabric-resources-v1.md; Platform #130.
-- Domain ownership, certificates and HTTPS routes are explicit fabric resources.
-- Existing DNS is customer-owned; reads expose the records the customer must add.
GRANT USAGE ON SCHEMA deployments TO ROLE SETTING('networking.executor_role');

CREATE TABLE networking.domains (
  id UUID PRIMARY KEY,
  environment_id UUID NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT,
  hostname TEXT NOT NULL,
  authority OBJECT_ID NOT NULL UNIQUE,
  profile_id UUID NOT NULL,
  profile_revision BINARY NOT NULL,
  certificate_placement PLACEMENT NOT NULL,
  claim_generation BIGINT NOT NULL,
  revision BIGINT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('unverified', 'verified', 'retired')),
  tls_state TEXT NOT NULL CHECK (tls_state IN ('pending', 'issued', 'renewal_pending', 'failed', 'expired')),
  deletion_protected BOOLEAN NOT NULL,
  challenge_name TEXT NOT NULL,
  challenge_value TEXT NOT NULL,
  challenge_expires_at TIMESTAMPTZ NOT NULL,
  certificate_ref RESOURCE_BINDING,
  validation_name TEXT,
  validation_value TEXT,
  not_after TIMESTAMPTZ,
  observation_sequence BIGINT NOT NULL,
  observed_at TIMESTAMPTZ,
  active_operation UUID
);

-- The current hostname claim is distinct from the retained history of owners.
CREATE TABLE networking.hostname_claims (
  hostname TEXT PRIMARY KEY,
  domain_id UUID NOT NULL UNIQUE REFERENCES networking.domains(id) ON DELETE RESTRICT,
  generation BIGINT NOT NULL
);

CREATE TABLE networking.endpoints (
  id UUID PRIMARY KEY,
  domain_id UUID NOT NULL REFERENCES networking.domains(id) ON DELETE RESTRICT,
  environment_id UUID NOT NULL REFERENCES tenancy.environments(id) ON DELETE RESTRICT,
  authority OBJECT_ID NOT NULL UNIQUE,
  target_kind TEXT NOT NULL CHECK (target_kind IN ('transit_instance', 'static_application')),
  instance_id UUID REFERENCES deployments.instances(id) ON DELETE RESTRICT,
  static_application_id UUID REFERENCES publication.static_applications(id) ON DELETE RESTRICT,
  target_revision BIGINT NOT NULL,
  profile_id UUID NOT NULL,
  profile_revision BINARY NOT NULL,
  placement PLACEMENT NOT NULL,
  revision BIGINT NOT NULL,
  generation BIGINT NOT NULL,
  state TEXT NOT NULL CHECK (state IN ('absent', 'ready', 'retired')),
  deletion_protected BOOLEAN NOT NULL,
  active_operation UUID,
  binding RESOURCE_BINDING,
  dns_target TEXT,
  CHECK ((target_kind = 'transit_instance' AND instance_id IS NOT NULL AND static_application_id IS NULL)
    OR (target_kind = 'static_application' AND static_application_id IS NOT NULL AND instance_id IS NULL))
);

CREATE TABLE networking.ingress_operations (
  id UUID PRIMARY KEY,
  domain_id UUID NOT NULL REFERENCES networking.domains(id) ON DELETE RESTRICT,
  endpoint_id UUID REFERENCES networking.endpoints(id) ON DELETE RESTRICT,
  action TEXT NOT NULL CHECK (action IN ('verify_domain', 'retire_domain', 'bind_endpoint', 'retire_endpoint')),
  subject SUBJECT_ID NOT NULL,
  native_ref OPERATION NOT NULL UNIQUE
) WITH (immutable = TRUE);

CREATE QUEUE networking.ingress_work (
  operation_id UUID NOT NULL
) WITH (active_leases = 8, max_attempts = 1);

CREATE DATAFLOW networking.claim_domain
  FROM COMMAND (
    environment_id UUID,
    expected_revision BIGINT,
    hostname TEXT,
    profile_id UUID,
    profile_revision BINARY
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET env = SELECT * FROM tenancy.environments WHERE id = request.environment_id;
    LET profile = SELECT * FROM networking.profiles WHERE id = request.profile_id;
    REQUIRE env IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'manage_domains', env.authority)
      AND profile IS NOT NULL AND profile.enabled AND profile.provider = 'aws'
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', profile.authority) ELSE 'Forbidden';
    REQUIRE env.revision = request.expected_revision AND profile._revision = request.profile_revision ELSE 'StaleTarget';
    -- Canonical ASCII FQDN, no wildcard/IP/public suffix or platform-reserved name.
    REQUIRE CUSTOMER_HOSTNAME_VALID(request.hostname) ELSE 'InvalidHostname';
    LET claim = SELECT * FROM networking.hostname_claims WHERE hostname = request.hostname;
    IF claim IS NOT NULL THEN
      LET previous = SELECT * FROM networking.domains WHERE id = claim.domain_id;
      REQUIRE previous.state = 'retired' AND previous.active_operation IS NULL
        AND previous.certificate_ref IS NULL ELSE 'DomainUnavailable';
    END IF;
    REQUIRE (SELECT COUNT(*) FROM networking.domains WHERE profile_id = profile.id AND state <> 'retired')
      < profile.domain_limit ELSE 'CapacityExceeded';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'domain');
    LET object = ALLOCATE AUTHORIZATION OBJECT 'platform.domain' ID command_id PARENT env.authority;
    GRANT ACTIONS ('inspect', 'verify', 'bind', 'retire', 'protect') ON OBJECT object TO SUBJECT CURRENT_SUBJECT();
    LET claim_generation = COALESCE(claim.generation, 0) + 1;
    -- CloudFront's certificate must be in the qualified certificate region.
    LET placement = BIND PLACEMENT 'aws' ACCOUNT profile.cloud_account REGION 'us-east-1'
      CONNECTION profile.certificate_connection_ref ROLE profile.role_ref;
    INSERT INTO networking.domains VALUES (command_id, env.id, request.hostname, object, profile.id, profile._revision,
      placement, claim_generation, 1, 'unverified', 'pending', TRUE,
      '_spoke.' || request.hostname, CAST(OPERATION_ID(command_id, 'ownership-challenge') AS TEXT),
      NOW() + INTERVAL '48 hours', NULL, NULL, NULL, NULL, 0, NULL, NULL);
    IF claim IS NULL THEN
      INSERT INTO networking.hostname_claims VALUES (request.hostname, command_id, claim_generation);
    ELSE
      UPDATE networking.hostname_claims SET domain_id = command_id, generation = claim_generation WHERE hostname = request.hostname;
    END IF;
    RETURN JSON_OBJECT('id', command_id, 'revision', 1);
  END;

CREATE DATAFLOW networking.verify_domain
  FROM COMMAND (
    domain_id UUID,
    expected_revision BIGINT,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET domain = SELECT * FROM networking.domains WHERE id = request.domain_id;
    REQUIRE domain IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'verify', domain.authority) ELSE 'Forbidden';
    REQUIRE domain.revision = request.expected_revision AND domain.active_operation IS NULL
      AND domain.state = 'unverified' AND domain.challenge_expires_at > NOW() ELSE 'StaleTarget';
    LET digest = DIGEST(ROW(domain.id, domain.revision, domain.hostname, domain.claim_generation, 'verify'));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), domain.authority, 'verify', digest, domain.revision) ELSE 'Forbidden';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'certificate-operation');
    LET operation = ACCEPT OPERATION command_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET domain.id REVISION domain.revision;
    INSERT INTO networking.ingress_operations VALUES (command_id, domain.id, NULL, 'verify_domain', CURRENT_SUBJECT(), operation);
    UPDATE networking.domains SET active_operation = command_id, revision = revision + 1 WHERE id = domain.id;
    ENQUEUE INTO networking.ingress_work VALUES (command_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', domain.id, 'revision', domain.revision + 1,
      'operation_id', command_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE DATAFLOW networking.protect_domain
  FROM COMMAND (
    domain_id UUID,
    expected_revision BIGINT,
    protected BOOLEAN
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET domain = SELECT * FROM networking.domains WHERE id = request.domain_id;
    REQUIRE domain IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'protect', domain.authority) ELSE 'Forbidden';
    REQUIRE domain.revision = request.expected_revision ELSE 'StaleTarget';
    UPDATE networking.domains SET deletion_protected = request.protected, revision = revision + 1 WHERE id = domain.id;
    RETURN JSON_OBJECT('id', domain.id, 'revision', domain.revision + 1, 'protected', request.protected);
  END;

CREATE DATAFLOW networking.retire_domain
  FROM COMMAND (
    domain_id UUID,
    expected_revision BIGINT,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET domain = SELECT * FROM networking.domains WHERE id = request.domain_id;
    REQUIRE domain IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'retire', domain.authority) ELSE 'Forbidden';
    REQUIRE domain.revision = request.expected_revision AND domain.active_operation IS NULL
      AND domain.state <> 'retired' ELSE 'StaleTarget';
    REQUIRE NOT domain.deletion_protected ELSE 'DeletionProtected';
    REQUIRE NOT EXISTS (SELECT 1 FROM networking.endpoints WHERE domain_id = domain.id AND state <> 'retired') ELSE 'Referenced';
    LET digest = DIGEST(ROW(domain.id, domain.revision, domain.claim_generation, 'retire'));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), domain.authority, 'retire', digest, domain.revision) ELSE 'Forbidden';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'domain-retirement');
    LET operation = ACCEPT OPERATION command_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET domain.id REVISION domain.revision;
    INSERT INTO networking.ingress_operations VALUES (command_id, domain.id, NULL, 'retire_domain', CURRENT_SUBJECT(), operation);
    UPDATE networking.domains SET active_operation = command_id, revision = revision + 1 WHERE id = domain.id;
    ENQUEUE INTO networking.ingress_work VALUES (command_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', domain.id, 'revision', domain.revision + 1,
      'operation_id', command_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE DATAFLOW networking.bind_endpoint
  FROM COMMAND (
    domain_id UUID,
    expected_revision BIGINT,
    target_kind TEXT,
    target_id UUID,
    target_revision BIGINT,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET domain = SELECT * FROM networking.domains WHERE id = request.domain_id;
    REQUIRE domain IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'bind', domain.authority) ELSE 'Forbidden';
    REQUIRE domain.revision = request.expected_revision AND domain.active_operation IS NULL
      AND domain.state = 'verified' AND domain.tls_state = 'issued' AND domain.not_after > NOW()
      AND domain.observed_at >= NOW() - INTERVAL '2 hours' ELSE 'DomainNotReady';
    LET profile = SELECT * FROM networking.profiles WHERE id = domain.profile_id;
    REQUIRE profile.enabled AND profile._revision = domain.profile_revision
      AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', profile.authority) ELSE 'ProfileChanged';
    REQUIRE NOT EXISTS (SELECT 1 FROM networking.endpoints WHERE domain_id = domain.id AND state <> 'retired') ELSE 'Referenced';
    REQUIRE (SELECT COUNT(*) FROM networking.endpoints WHERE profile_id = profile.id AND state <> 'retired')
      < profile.endpoint_limit ELSE 'CapacityExceeded';
    LET instance_id = CASE WHEN request.target_kind = 'transit_instance' THEN request.target_id ELSE NULL END;
    LET static_id = CASE WHEN request.target_kind = 'static_application' THEN request.target_id ELSE NULL END;
    IF request.target_kind = 'transit_instance' THEN
      LET target = SELECT * FROM deployments.instances WHERE id = request.target_id;
      REQUIRE target IS NOT NULL AND target.environment_id = domain.environment_id
        AND target.revision = request.target_revision AND target.desired_state = 'running'
        AND target.active_operation IS NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'bind_endpoint', target.authority)
        ELSE 'TargetNotReady';
      LET network = SELECT * FROM networking.networks WHERE id = target.network_id;
      REQUIRE network.state = 'ready' AND network.active_operation IS NULL
        AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'use', network.authority)
        AND network.placement.cloud_account = profile.cloud_account AND network.placement.region = profile.region
        ELSE 'NetworkNotReady';
    ELSE
      REQUIRE request.target_kind = 'static_application' ELSE 'InvalidRequest';
      LET target = SELECT * FROM publication.static_applications WHERE id = request.target_id;
      REQUIRE target IS NOT NULL AND target.environment_id = domain.environment_id
        AND target.revision = request.target_revision AND target.state = 'ready' AND target.active_bundle IS NOT NULL
        AND target.active_operation IS NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'bind_endpoint', target.authority)
        ELSE 'TargetNotReady';
      REQUIRE target.placement.cloud_account = profile.cloud_account
        AND NOT EXISTS (SELECT 1 FROM networking.target_holds WHERE target_id = target.id AND NOT released) ELSE 'Referenced';
    END IF;
    LET digest = DIGEST(ROW(domain.id, domain.revision, domain.claim_generation, request.target_kind, request.target_id, request.target_revision));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), domain.authority, 'bind', digest, domain.revision) ELSE 'Forbidden';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'endpoint');
    LET object = ALLOCATE AUTHORIZATION OBJECT 'platform.endpoint' ID command_id PARENT domain.authority;
    GRANT ACTIONS ('inspect', 'retire', 'protect') ON OBJECT object TO SUBJECT CURRENT_SUBJECT();
    LET placement = BIND PLACEMENT profile.provider ACCOUNT profile.cloud_account REGION profile.region
      CONNECTION profile.connection_ref ROLE profile.role_ref TEMPLATE profile.endpoint_template_sha256;
    LET operation_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'endpoint-operation');
    LET operation = ACCEPT OPERATION operation_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET command_id REVISION 0;
    INSERT INTO networking.endpoints VALUES (command_id, domain.id, domain.environment_id, object, request.target_kind,
      instance_id, static_id, request.target_revision, profile.id, profile._revision, placement, 1, 1, 'absent', TRUE, operation_id, NULL, NULL);
    INSERT INTO networking.target_holds VALUES (request.target_id, request.target_kind, command_id, TRUE, FALSE);
    IF instance_id IS NOT NULL THEN
      LET selected_network = SELECT i.network_id FROM deployments.instances i WHERE i.id = instance_id;
      INSERT INTO networking.attachments VALUES (selected_network, command_id, 'endpoint', FALSE);
    END IF;
    INSERT INTO networking.ingress_operations VALUES (operation_id, domain.id, command_id, 'bind_endpoint', CURRENT_SUBJECT(), operation);
    ENQUEUE INTO networking.ingress_work VALUES (operation_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', command_id, 'revision', 1, 'operation_id', operation_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE DATAFLOW networking.protect_endpoint
  FROM COMMAND (
    endpoint_id UUID,
    expected_revision BIGINT,
    protected BOOLEAN
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.command.v1')
  AS BEGIN ATOMIC
    LET endpoint = SELECT * FROM networking.endpoints WHERE id = request.endpoint_id;
    REQUIRE endpoint IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'protect', endpoint.authority) ELSE 'Forbidden';
    REQUIRE endpoint.revision = request.expected_revision ELSE 'StaleTarget';
    UPDATE networking.endpoints SET deletion_protected = request.protected, revision = revision + 1 WHERE id = endpoint.id;
    RETURN JSON_OBJECT('id', endpoint.id, 'revision', endpoint.revision + 1, 'protected', request.protected);
  END;

CREATE DATAFLOW networking.retire_endpoint
  FROM COMMAND (
    endpoint_id UUID,
    expected_revision BIGINT,
    authority AUTHORIZATION
  ) AS request
  WITH (idempotency = 'original_subject_request', result = 'platform.operation.v1')
  AS BEGIN ATOMIC
    LET endpoint = SELECT * FROM networking.endpoints WHERE id = request.endpoint_id;
    REQUIRE endpoint IS NOT NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'retire', endpoint.authority) ELSE 'Forbidden';
    REQUIRE endpoint.revision = request.expected_revision AND endpoint.active_operation IS NULL
      AND endpoint.state = 'ready' ELSE 'StaleTarget';
    REQUIRE NOT endpoint.deletion_protected ELSE 'DeletionProtected';
    IF endpoint.target_kind = 'static_application' THEN
      LET app = SELECT * FROM publication.static_applications WHERE id = endpoint.static_application_id;
      REQUIRE app.active_operation IS NULL AND NATIVE_ALLOWED(CURRENT_SUBJECT(), 'bind_endpoint', app.authority) ELSE 'TargetNotReady';
    END IF;
    UPDATE networking.target_holds SET mutating = TRUE WHERE endpoint_id = endpoint.id;
    LET digest = DIGEST(ROW(endpoint.id, endpoint.revision, 'retire'));
    REQUIRE NATIVE_AUTHORIZES(request.authority, CURRENT_SUBJECT(), endpoint.authority, 'retire', digest, endpoint.revision) ELSE 'Forbidden';
    LET command_id = OPERATION_ID(CURRENT_REQUEST_ID(), 'endpoint-operation');
    LET operation = ACCEPT OPERATION command_id SUBJECT CURRENT_SUBJECT() AUTHORITY request.authority
      CANDIDATE digest TARGET endpoint.id REVISION endpoint.revision;
    INSERT INTO networking.ingress_operations VALUES (command_id, endpoint.domain_id, endpoint.id, 'retire_endpoint', CURRENT_SUBJECT(), operation);
    UPDATE networking.endpoints SET active_operation = command_id, revision = revision + 1, generation = generation + 1 WHERE id = endpoint.id;
    ENQUEUE INTO networking.ingress_work VALUES (command_id) CONTINUATION operation;
    RETURN JSON_OBJECT('id', endpoint.id, 'revision', endpoint.revision + 1,
      'operation_id', command_id, 'native_operation', operation, 'outcome', 'accepted');
  END;

CREATE VIEW networking.current_ingress_operations AS
  SELECT o.id FROM networking.ingress_operations o JOIN networking.domains d ON d.id = o.domain_id
  JOIN networking.hostname_claims claim ON claim.domain_id = d.id AND claim.generation = d.claim_generation
  JOIN networking.profiles p ON p.id = d.profile_id
  LEFT JOIN networking.endpoints e ON e.id = o.endpoint_id
  WHERE NATIVE_OPERATION_CURRENT(o.native_ref) AND p.enabled AND p._revision = d.profile_revision
    AND NATIVE_ALLOWED(o.subject, 'use', p.authority)
    AND ((o.endpoint_id IS NULL AND d.active_operation = o.id)
      OR (o.endpoint_id IS NOT NULL AND e.active_operation = o.id))
    AND (o.action <> 'retire_domain' OR (NOT d.deletion_protected
      AND NOT EXISTS (SELECT 1 FROM networking.endpoints bound WHERE bound.domain_id = d.id AND bound.state <> 'retired')))
    AND (o.action <> 'retire_endpoint' OR NOT e.deletion_protected)
    AND (o.action <> 'bind_endpoint' OR (d.state = 'verified' AND d.tls_state = 'issued' AND d.not_after > NOW()
      AND d.observed_at >= NOW() - INTERVAL '2 hours'
      AND ((e.target_kind = 'transit_instance' AND EXISTS (SELECT 1 FROM deployments.instances i
        JOIN networking.networks n ON n.id = i.network_id WHERE i.id = e.instance_id
          AND i.revision = e.target_revision AND i.active_operation IS NULL AND i.desired_state = 'running'
          AND n.state = 'ready' AND n.active_operation IS NULL
          AND NATIVE_ALLOWED(o.subject, 'bind_endpoint', i.authority) AND NATIVE_ALLOWED(o.subject, 'use', n.authority)))
        OR (e.target_kind = 'static_application' AND EXISTS (SELECT 1 FROM publication.static_applications a
          WHERE a.id = e.static_application_id AND a.revision = e.target_revision AND a.active_operation IS NULL
            AND a.state = 'ready' AND NATIVE_ALLOWED(o.subject, 'bind_endpoint', a.authority))))))
    AND (o.action <> 'retire_endpoint' OR e.target_kind <> 'static_application'
      OR EXISTS (SELECT 1 FROM publication.static_applications a WHERE a.id = e.static_application_id
        AND a.active_operation IS NULL AND NATIVE_ALLOWED(o.subject, 'bind_endpoint', a.authority)));

CREATE SINK networking.request_certificate INTO AWS OPERATION 'acm:RequestCertificate'
  WITH (connection = 'bound_placement', capture = 'resource_reference', recovery = 'original_request_observation');
CREATE SINK networking.delete_certificate INTO AWS OPERATION 'acm:DeleteCertificate'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');
CREATE SINK networking.update_distribution INTO AWS OPERATION 'cloudfront:UpdateDistribution'
  WITH (connection = 'bound_placement', capture = 'redacted', recovery = 'original_request_observation');

CREATE DATAFLOW networking.issue_certificate
  FROM QUEUE networking.ingress_work AS request
    WHERE (SELECT action FROM networking.ingress_operations WHERE id = request.operation_id) = 'verify_domain'
  AS BEGIN
    LET operation = SELECT * FROM networking.ingress_operations WHERE id = request.operation_id;
    LET domain = SELECT * FROM networking.domains WHERE id = operation.domain_id;
    LET ownership = AWAIT OBSERVATION FROM DNS TXT domain.challenge_name
      EFFECT OPERATION_ID(operation.id, 'domain-ownership')
      GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
      UNTIL value = domain.challenge_value AND NOW() < domain.challenge_expires_at
      WITH (deadline = '10m', interval = '30s', resolver = 'public_authoritative');
    REQUIRE DNS_OWNERSHIP_VERIFIED(ownership, domain.hostname, domain.challenge_value, domain.claim_generation)
      ELSE 'DomainNotVerified';
    LET certificate = EXECUTE SINK networking.request_certificate USING PLACEMENT domain.certificate_placement
      EFFECT OPERATION_ID(operation.id, 'request-certificate')
      GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
      REQUEST JSON_OBJECT('DomainName', domain.hostname, 'ValidationMethod', 'DNS',
        'IdempotencyToken', REPLACE(CAST(operation.id AS TEXT), '-', '')) ON REPLAY OBSERVE ONLY;
    LET resource_binding = BIND CLOUD RESOURCES certificate USING PLACEMENT domain.certificate_placement
      OWNER domain.authority OPERATION operation.native_ref;
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.domains SET certificate_ref = resource_binding WHERE id = domain.id;
    END;
    LET validation = AWAIT OBSERVATION FROM AWS CERTIFICATE resource_binding.resource_id USING PLACEMENT domain.certificate_placement
      EFFECT OPERATION_ID(operation.id, 'certificate-validation-record')
      GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
      UNTIL validation_record IS NOT NULL WITH (deadline = '10m', interval = '10s');
    REQUIRE validation.complete AND CERTIFICATE_IDENTITY_MATCHES(validation, resource_binding, domain.hostname) ELSE 'ObservationMismatch';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.domains SET validation_name = validation.validation_record.name,
        validation_value = validation.validation_record.value, revision = revision + 1 WHERE id = domain.id;
    END;
    -- The customer publishes this CNAME and keeps it for ACM managed renewal.
    LET issued = AWAIT OBSERVATION FROM AWS CERTIFICATE resource_binding.resource_id USING PLACEMENT domain.certificate_placement
      EFFECT OPERATION_ID(operation.id, 'certificate-issued')
      GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
      UNTIL status IN ('ISSUED', 'FAILED', 'VALIDATION_TIMED_OUT') WITH (deadline = '48h', interval = '60s');
    REQUIRE issued.complete AND issued.status = 'ISSUED' AND issued.not_after > NOW()
      AND CERTIFICATE_IDENTITY_MATCHES(issued, resource_binding, domain.hostname) ELSE 'CertificateNotReady';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.domains SET state = 'verified', tls_state = 'issued', not_after = issued.not_after, observed_at = issued.observed_at,
        active_operation = NULL, revision = revision + 1 WHERE id = domain.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('domain_id', domain.id, 'outcome', 'verified');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

CREATE DATAFLOW networking.publish_endpoint
  FROM QUEUE networking.ingress_work AS request
    WHERE (SELECT action FROM networking.ingress_operations WHERE id = request.operation_id) = 'bind_endpoint'
  AS BEGIN
    LET operation = SELECT * FROM networking.ingress_operations WHERE id = request.operation_id;
    LET endpoint = SELECT * FROM networking.endpoints WHERE id = operation.endpoint_id;
    LET domain = SELECT * FROM networking.domains WHERE id = endpoint.domain_id;
    LET profile = SELECT * FROM networking.profiles WHERE id = endpoint.profile_id;
    IF endpoint.target_kind = 'transit_instance' THEN
      LET target = SELECT * FROM deployments.instances WHERE id = endpoint.instance_id;
      LET network = SELECT * FROM networking.networks WHERE id = target.network_id;
      REQUIRE target.revision = endpoint.target_revision AND target.active_operation IS NULL
        AND target.desired_state = 'running' AND NATIVE_ALLOWED(operation.subject, 'bind_endpoint', target.authority)
        AND NATIVE_ALLOWED(operation.subject, 'use', network.authority) ELSE 'TargetNotReady';
      REQUIRE ARTIFACT_VERIFIED(profile.endpoint_template, profile.endpoint_template_sha256)
        AND AWS_HTTPS_TEMPLATE_VALID(profile.endpoint_template, 'spoke.https.aws.v1') ELSE 'UnqualifiedProfile';
      LET stack = EXECUTE SINK networking.create_stack USING PLACEMENT endpoint.placement
        EFFECT OPERATION_ID(operation.id, 'endpoint-create')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
          AND NATIVE_ALLOWED(operation.subject, 'bind_endpoint', target.authority)
        REQUEST JSON_OBJECT('StackName', 'spoke-endpoint-' || CAST(endpoint.id AS TEXT),
          'ClientRequestToken', CAST(operation.id AS TEXT), 'DisableRollback', TRUE,
          'TemplateBody', ARTIFACT_TEXT(profile.endpoint_template, profile.endpoint_template_sha256),
          'Parameters', AWS_PARAMETERS(NETWORK_PARAMETERS(network.binding), JSON_OBJECT('EndpointId', endpoint.id,
            'InstallationId', target.installation_id, 'DomainName', domain.hostname, 'CertificateArn', domain.certificate_ref.resource_id)))
        ON REPLAY OBSERVE ONLY;
      LET resource_binding = BIND CLOUD RESOURCES stack USING PLACEMENT endpoint.placement OWNER endpoint.authority OPERATION operation.native_ref;
      BEGIN ATOMIC
        REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
        UPDATE networking.endpoints SET binding = resource_binding WHERE id = endpoint.id;
      END;
      LET observed = AWAIT OBSERVATION FROM AWS STACK resource_binding.stack_id USING PLACEMENT endpoint.placement
        EFFECT OPERATION_ID(operation.id, 'endpoint-ready')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
        UNTIL status IN ('CREATE_COMPLETE', 'CREATE_FAILED') WITH (deadline = '20m', interval = '10s');
      REQUIRE observed.complete AND observed.status = 'CREATE_COMPLETE'
        AND observed.operation_id = operation.id AND observed.stack_incarnation = resource_binding.incarnation
        AND HTTPS_INGRESS_CONFIGURATION_VERIFIED(observed, domain.hostname, target.installation_id, domain.certificate_ref)
        ELSE 'EndpointNotReady';
      BEGIN ATOMIC
        REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
        UPDATE networking.endpoints SET dns_target = observed.distribution_hostname, revision = revision + 1 WHERE id = endpoint.id;
      END;
    ELSE
      LET app = SELECT * FROM publication.static_applications WHERE id = endpoint.static_application_id;
      REQUIRE app.revision = endpoint.target_revision AND app.active_operation IS NULL
        AND NATIVE_ALLOWED(operation.subject, 'bind_endpoint', app.authority) ELSE 'TargetNotReady';
      LET previous = OBSERVE AWS DISTRIBUTION app.binding.distribution_id USING PLACEMENT app.placement
        EFFECT OPERATION_ID(operation.id, 'alias-before')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id);
      REQUIRE previous.complete AND previous.incarnation = app.binding.distribution_incarnation ELSE 'ObservationMismatch';
      LET selected = EXECUTE SINK networking.update_distribution USING PLACEMENT app.placement
        EFFECT OPERATION_ID(operation.id, 'bind-static-domain')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
          AND NATIVE_ALLOWED(operation.subject, 'bind_endpoint', app.authority)
        REQUEST JSON_OBJECT('Id', app.binding.distribution_id, 'IfMatch', previous.etag,
          'DistributionConfig', BIND_DISTRIBUTION_DOMAIN(previous.configuration, domain.hostname, domain.certificate_ref))
        ON REPLAY OBSERVE ONLY;
      LET resource_binding = BIND CLOUD RESOURCES selected USING PLACEMENT app.placement OWNER endpoint.authority
        REFERENCE app.binding OPERATION operation.native_ref;
      BEGIN ATOMIC
        REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
        UPDATE networking.endpoints SET binding = resource_binding WHERE id = endpoint.id;
      END;
      LET observed = AWAIT OBSERVATION FROM AWS DISTRIBUTION app.binding.distribution_id USING PLACEMENT app.placement
        EFFECT OPERATION_ID(operation.id, 'alias-ready')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
        UNTIL status = 'Deployed' WITH (deadline = '20m', interval = '10s');
      REQUIRE observed.complete AND DISTRIBUTION_DOMAIN_MATCHES(observed, domain.hostname, domain.certificate_ref, selected)
        ELSE 'EndpointNotReady';
      BEGIN ATOMIC
        REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
        UPDATE networking.endpoints SET dns_target = observed.distribution_hostname, revision = revision + 1 WHERE id = endpoint.id;
      END;
    END IF;
    -- The destination is published before waiting for the customer's CNAME/ALIAS.
    LET served = AWAIT OBSERVATION FROM HTTPS ENDPOINT domain.hostname
      EFFECT OPERATION_ID(operation.id, 'tls-route-proof')
      GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
      WITH (deadline = '20m', interval = '30s', redirects = 'reject', credentials = 'none');
    REQUIRE HTTPS_ROUTE_VERIFIED(served, endpoint.id, domain.hostname, domain.certificate_ref, endpoint.target_kind,
      COALESCE(endpoint.instance_id, endpoint.static_application_id)) ELSE 'EndpointNotReady';
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.endpoints SET state = 'ready', active_operation = NULL, revision = revision + 1 WHERE id = endpoint.id;
      UPDATE networking.target_holds SET mutating = FALSE WHERE endpoint_id = endpoint.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('endpoint_id', endpoint.id, 'outcome', 'ready');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

CREATE DATAFLOW networking.withdraw_endpoint
  FROM QUEUE networking.ingress_work AS request
    WHERE (SELECT action FROM networking.ingress_operations WHERE id = request.operation_id) = 'retire_endpoint'
  AS BEGIN
    LET operation = SELECT * FROM networking.ingress_operations WHERE id = request.operation_id;
    LET endpoint = SELECT * FROM networking.endpoints WHERE id = operation.endpoint_id;
    LET domain = SELECT * FROM networking.domains WHERE id = endpoint.domain_id;
    IF endpoint.target_kind = 'transit_instance' THEN
      LET removed = EXECUTE SINK networking.delete_stack USING PLACEMENT endpoint.placement
        EFFECT OPERATION_ID(operation.id, 'endpoint-delete')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
        REQUEST JSON_OBJECT('StackName', endpoint.binding.stack_id, 'ClientRequestToken', CAST(operation.id AS TEXT)) ON REPLAY OBSERVE ONLY;
      LET observed = AWAIT OBSERVATION FROM AWS STACK endpoint.binding.stack_id USING PLACEMENT endpoint.placement
        EFFECT OPERATION_ID(operation.id, 'endpoint-absent')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
        UNTIL status = 'DELETE_COMPLETE' WITH (deadline = '20m', interval = '10s');
      REQUIRE observed.complete AND EXACT_RESOURCE_ABSENCE(observed, endpoint.binding) ELSE 'DeletionUnresolved';
    ELSE
      LET app = SELECT * FROM publication.static_applications WHERE id = endpoint.static_application_id;
      LET previous = OBSERVE AWS DISTRIBUTION app.binding.distribution_id USING PLACEMENT app.placement
        EFFECT OPERATION_ID(operation.id, 'unbind-before')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id);
      REQUIRE previous.complete AND previous.incarnation = app.binding.distribution_incarnation ELSE 'ObservationMismatch';
      LET removed = EXECUTE SINK networking.update_distribution USING PLACEMENT app.placement
        EFFECT OPERATION_ID(operation.id, 'unbind-static-domain')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
        REQUEST JSON_OBJECT('Id', app.binding.distribution_id, 'IfMatch', previous.etag,
          'DistributionConfig', UNBIND_DISTRIBUTION_DOMAIN(previous.configuration, domain.hostname, domain.certificate_ref))
        ON REPLAY OBSERVE ONLY;
      LET observed = AWAIT OBSERVATION FROM AWS DISTRIBUTION app.binding.distribution_id USING PLACEMENT app.placement
        EFFECT OPERATION_ID(operation.id, 'alias-absent')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
        UNTIL status = 'Deployed' WITH (deadline = '20m', interval = '10s');
      REQUIRE observed.complete AND EXACT_DOMAIN_WITHDRAWAL(observed, domain.hostname, domain.certificate_ref, removed)
        ELSE 'RetirementUnverified';
    END IF;
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.endpoints SET state = 'retired', active_operation = NULL, revision = revision + 1 WHERE id = endpoint.id;
      UPDATE networking.target_holds SET released = TRUE, mutating = FALSE WHERE endpoint_id = endpoint.id;
      UPDATE networking.attachments SET released = TRUE WHERE consumer_id = endpoint.id AND consumer_kind = 'endpoint';
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('endpoint_id', endpoint.id, 'outcome', 'retired');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

CREATE DATAFLOW networking.withdraw_domain
  FROM QUEUE networking.ingress_work AS request
    WHERE (SELECT action FROM networking.ingress_operations WHERE id = request.operation_id) = 'retire_domain'
  AS BEGIN
    LET operation = SELECT * FROM networking.ingress_operations WHERE id = request.operation_id;
    LET domain = SELECT * FROM networking.domains WHERE id = operation.domain_id;
    IF domain.certificate_ref IS NOT NULL THEN
      LET removed = EXECUTE SINK networking.delete_certificate USING PLACEMENT domain.certificate_placement
        EFFECT OPERATION_ID(operation.id, 'certificate-delete')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
          AND NO_NATIVE_RESOURCE_REFERENCES(domain.certificate_ref)
        REQUEST JSON_OBJECT('CertificateArn', domain.certificate_ref.resource_id) ON REPLAY OBSERVE ONLY;
      LET observed = AWAIT OBSERVATION FROM AWS CERTIFICATE domain.certificate_ref.resource_id USING PLACEMENT domain.certificate_placement
        EFFECT OPERATION_ID(operation.id, 'certificate-absent')
        GUARD EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id)
        UNTIL absent WITH (deadline = '10m', interval = '10s');
      REQUIRE observed.complete AND EXACT_RESOURCE_ABSENCE(observed, domain.certificate_ref) ELSE 'DeletionUnresolved';
    END IF;
    BEGIN ATOMIC
      REQUIRE EXISTS (SELECT 1 FROM networking.current_ingress_operations WHERE id = operation.id) ELSE 'StaleOperation';
      UPDATE networking.domains SET state = 'retired', certificate_ref = NULL, active_operation = NULL,
        revision = revision + 1 WHERE id = domain.id;
      COMPLETE OPERATION operation.native_ref RESULT JSON_OBJECT('domain_id', domain.id, 'outcome', 'retired');
    END;
  ON FAILURE failure
    PRESERVE OPERATION failure WITH RESOURCES AND RESERVATIONS;
  END;

-- ACM renews DNS-validated certificates in use. Native bounded observation,
-- independent of browser reads, records renewal, failure and expiry for this claim.
CREATE STREAM networking.certificate_observations (
  domain_id UUID NOT NULL,
  claim_generation BIGINT NOT NULL,
  certificate RESOURCE_BINDING NOT NULL,
  sequence BIGINT NOT NULL,
  evidence EVIDENCE NOT NULL
) WITH (retention = 'native_operation_and_resource_holds');

CREATE SOURCE networking.certificate_watch
  FROM AWS OBSERVATIONS OF networking.domains KEY id
  INTO STREAM networking.certificate_observations
  WITH (
    resource_column = 'certificate_ref',
    placement_column = 'certificate_placement',
    binding_columns = JSON '["id","claim_generation"]',
    resource_filter = 'state <> ''retired'' AND certificate_ref IS NOT NULL',
    operation = 'acm:DescribeCertificate',
    interval = '1h',
    max_in_flight = 8,
    max_response_bytes = 65536,
    progress = 'native_retained_per_resource',
    authority = SETTING('networking.observation_authority')
  );

CREATE DATAFLOW networking.observe_certificate
  FROM STREAM networking.certificate_observations AS observation
  AS BEGIN ATOMIC
    LET domain = SELECT * FROM networking.domains WHERE id = observation.domain_id;
    IF domain IS NOT NULL AND domain.state = 'verified' AND domain.active_operation IS NULL
      AND domain.claim_generation = observation.claim_generation
      AND domain.certificate_ref = observation.certificate AND observation.sequence > domain.observation_sequence THEN
      REQUIRE CERTIFICATE_EVIDENCE_VERIFIED(observation.evidence, domain.certificate_ref, domain.hostname) ELSE 'ObservationMismatch';
      UPDATE networking.domains SET tls_state = CERTIFICATE_TLS_STATE(observation.evidence),
      not_after = CERTIFICATE_NOT_AFTER(observation.evidence), observed_at = observation.evidence.observed_at,
        observation_sequence = observation.sequence, revision = revision + 1 WHERE id = domain.id;
    END IF;
  END;

-- Authority and activation precede HTTP ingress. No public SQL execution.
AUTHORIZE DATAFLOW networking.claim_domain AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.claim_domain;
AUTHORIZE DATAFLOW networking.verify_domain AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.verify_domain;
AUTHORIZE DATAFLOW networking.protect_domain AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.protect_domain;
AUTHORIZE DATAFLOW networking.retire_domain AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.retire_domain;
AUTHORIZE DATAFLOW networking.bind_endpoint AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.bind_endpoint;
AUTHORIZE DATAFLOW networking.protect_endpoint AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.protect_endpoint;
AUTHORIZE DATAFLOW networking.retire_endpoint AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.retire_endpoint;
AUTHORIZE SINK networking.request_certificate AS ROLE SETTING('networking.effect_role');
ACTIVATE SINK networking.request_certificate;
AUTHORIZE SINK networking.delete_certificate AS ROLE SETTING('networking.effect_role');
ACTIVATE SINK networking.delete_certificate;
AUTHORIZE SINK networking.update_distribution AS ROLE SETTING('networking.effect_role');
ACTIVATE SINK networking.update_distribution;
AUTHORIZE DATAFLOW networking.issue_certificate AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.issue_certificate;
AUTHORIZE DATAFLOW networking.publish_endpoint AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.publish_endpoint;
AUTHORIZE DATAFLOW networking.withdraw_endpoint AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.withdraw_endpoint;
AUTHORIZE DATAFLOW networking.withdraw_domain AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.withdraw_domain;
AUTHORIZE DATAFLOW networking.observe_certificate AS ROLE SETTING('networking.executor_role');
ACTIVATE DATAFLOW networking.observe_certificate;
AUTHORIZE SOURCE networking.certificate_watch AS ROLE SETTING('networking.effect_role');
ACTIVATE SOURCE networking.certificate_watch;

CREATE SOURCE networking.claim_domain_http
  FROM HTTP REQUEST
  INTO COMMAND networking.claim_domain
  WITH (
    method = 'POST',
    path = '/platform/v1/environments/{environment_id}/domains',
    path_arguments = JSON '["environment_id"]',
    body_arguments = JSON '["expected_revision","hostname","profile_id","profile_revision"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.claim_domain/{request_id}',
    response_status = 201,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.claim_domain_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.claim_domain_http;

CREATE SOURCE networking.verify_domain_http
  FROM HTTP REQUEST
  INTO COMMAND networking.verify_domain
  WITH (
    method = 'POST',
    path = '/platform/v1/domains/{domain_id}/verify',
    path_arguments = JSON '["domain_id"]',
    body_arguments = JSON '["expected_revision","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.verify_domain/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.verify_domain_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.verify_domain_http;

CREATE SOURCE networking.protect_domain_http
  FROM HTTP REQUEST
  INTO COMMAND networking.protect_domain
  WITH (
    method = 'PATCH',
    path = '/platform/v1/domains/{domain_id}/protection',
    path_arguments = JSON '["domain_id"]',
    body_arguments = JSON '["expected_revision","protected"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.protect_domain/{request_id}',
    response_status = 200,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.protect_domain_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.protect_domain_http;

CREATE SOURCE networking.retire_domain_http
  FROM HTTP REQUEST
  INTO COMMAND networking.retire_domain
  WITH (
    method = 'POST',
    path = '/platform/v1/domains/{domain_id}/retire',
    path_arguments = JSON '["domain_id"]',
    body_arguments = JSON '["expected_revision","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.retire_domain/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.retire_domain_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.retire_domain_http;

CREATE SOURCE networking.bind_endpoint_http
  FROM HTTP REQUEST
  INTO COMMAND networking.bind_endpoint
  WITH (
    method = 'POST',
    path = '/platform/v1/domains/{domain_id}/endpoints',
    path_arguments = JSON '["domain_id"]',
    body_arguments = JSON '["expected_revision","target_kind","target_id","target_revision","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.bind_endpoint/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.bind_endpoint_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.bind_endpoint_http;

CREATE SOURCE networking.protect_endpoint_http
  FROM HTTP REQUEST
  INTO COMMAND networking.protect_endpoint
  WITH (
    method = 'PATCH',
    path = '/platform/v1/endpoints/{endpoint_id}/protection',
    path_arguments = JSON '["endpoint_id"]',
    body_arguments = JSON '["expected_revision","protected"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.protect_endpoint/{request_id}',
    response_status = 200,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.protect_endpoint_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.protect_endpoint_http;

CREATE SOURCE networking.retire_endpoint_http
  FROM HTTP REQUEST
  INTO COMMAND networking.retire_endpoint
  WITH (
    method = 'POST',
    path = '/platform/v1/endpoints/{endpoint_id}/retire',
    path_arguments = JSON '["endpoint_id"]',
    body_arguments = JSON '["expected_revision","authority"]',
    request_profile = 'command_json_v1',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    request_id_header = 'Idempotency-Key',
    result_path = '/platform/v1/requests/networking.retire_endpoint/{request_id}',
    response_status = 202,
    max_body_bytes = 65536,
    request_timeout = '10s'
  );
AUTHORIZE SOURCE networking.retire_endpoint_http AS ROLE SETTING('networking.executor_role');
ACTIVATE SOURCE networking.retire_endpoint_http;

CREATE PUBLICATION networking.domain_catalog AS
  SELECT d.id, d.environment_id, d.hostname, d.profile_id, d.revision, d.claim_generation, d.state,
    CASE WHEN d.not_after <= NOW() THEN 'expired' ELSE d.tls_state END AS tls_state,
    d.deletion_protected, d.challenge_name, d.challenge_value, d.challenge_expires_at,
    d.validation_name, d.validation_value, d.not_after, d.observed_at, d.active_operation
  FROM networking.domains d WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', d.authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('networking.reader_role'),
    response_profile = 'platform.domains.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/domains',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/domains/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION networking.domain_catalog;
ACTIVATE PUBLICATION networking.domain_catalog;

CREATE PUBLICATION networking.endpoint_catalog AS
  SELECT e.id, e.domain_id, e.environment_id, e.target_kind, COALESCE(e.instance_id, e.static_application_id) AS target_id,
    e.target_revision, e.profile_id, e.revision, e.generation, e.state, e.deletion_protected, e.active_operation, e.dns_target
  FROM networking.endpoints e WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', e.authority)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('networking.reader_role'),
    response_profile = 'platform.endpoints.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/endpoints',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/endpoints/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION networking.endpoint_catalog;
ACTIVATE PUBLICATION networking.endpoint_catalog;

CREATE PUBLICATION networking.ingress_operations_catalog AS
  SELECT o.id, o.domain_id, o.endpoint_id, o.action, NATIVE_OUTCOME(o.native_ref) AS outcome
  FROM networking.ingress_operations o JOIN networking.domains r ON r.id = o.domain_id
  WHERE NATIVE_ALLOWED(CURRENT_SUBJECT(), 'inspect', r.authority)
    AND NATIVE_OPERATION_VISIBLE(CURRENT_SUBJECT(), o.native_ref)
  WITH (
    audience = 'authenticated',
    authentication = 'native_session_or_bearer',
    origin = SETTING('browser.public_origin'),
    publisher_role = SETTING('networking.reader_role'),
    response_profile = 'platform.ingress-operations.v1',
    page_size = 64,
    order_by = 'id',
    snapshot_path = '/platform/v1/ingress-operations',
    key_columns = JSON '["id"]',
    item_path = '/platform/v1/ingress-operations/{id}',
    invalid_session = 'reject',
    disclosure = 'current_authority'
  );
AUTHORIZE PUBLICATION networking.ingress_operations_catalog;
ACTIVATE PUBLICATION networking.ingress_operations_catalog;
