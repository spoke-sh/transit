-- Fresh catalog baseline. Define objects in their owning schema from the start.
CREATE SCHEMA catalog AUTHORIZATION SETTING('schemas.catalog_owner');
GRANT USAGE ON SCHEMA catalog TO ROLE SETTING('publication.reader_role');

-- The public catalog describes the installed application and its read boundary.
-- Publication below supplies the existing React snapshot/watch contract.
CREATE TABLE catalog.platform_surfaces (
  id BIGINT PRIMARY KEY,
  kind VARCHAR(16) NOT NULL,
  slug VARCHAR(63) NOT NULL,
  title VARCHAR(120) NOT NULL,
  description VARCHAR(1000) NOT NULL,
  route VARCHAR(128) NOT NULL,
  visibility VARCHAR(16) NOT NULL,
  state VARCHAR(16) NOT NULL
);

INSERT INTO catalog.platform_surfaces (id, kind, slug, title, description, route, visibility, state) VALUES
  (1, 'ui', 'platform', 'Platform overview', 'The platform renders its own surface declarations from Transit. Change a declaration and connected views follow.', '/', 'public', 'active'),
  (2, 'ui', 'surface-explorer', 'Surface explorer', 'Browse the interfaces that make up Spoke, all from one shared catalog.', '/ui', 'public', 'active'),
  (3, 'api', 'surfaces', 'Surface catalog', 'Transit serves a complete, attributed snapshot of the explicitly published surface projection.', '/published/surfaces/snapshot', 'public', 'active'),
  (4, 'api', 'events', 'Live updates', 'Transit watches native source watermarks and sends a new snapshot when the source changes.', '/published/surfaces/watch', 'public', 'active'),
  (5, 'security', 'publication', 'Sign-in and explicit grants', 'GitHub sign-in establishes identity through the declared challenge, exchange and session flows. Protected actions require explicit Transit grants.', '/security', 'public', 'active'),
  (6, 'security', 'transport', 'Private data plane', 'CloudFront and the internal ALB route browser traffic to Transit. Native SQL stays local; browser requests enforce the configured origin.', '/security', 'public', 'active');

-- Publish the declared catalog through the existing snapshot/watch wire
-- contract. Publication owns complete cuts, current rights and source watches.
CREATE PUBLICATION catalog.surfaces AS
  SELECT id, kind, slug, title, description, route, visibility, state
  FROM catalog.platform_surfaces WHERE visibility = 'public' AND state = 'active'
  WITH (
    audience = 'public',
    publisher_role = SETTING('publication.reader_role'),
    snapshot_path = '/published/surfaces/snapshot',
    watch_path = '/published/surfaces/watch',
    response_profile = 'browser_publication_v1',
    invalid_session = 'reject',
    watch = 'source_watermark'
  );
AUTHORIZE PUBLICATION catalog.surfaces;
ACTIVATE PUBLICATION catalog.surfaces;
