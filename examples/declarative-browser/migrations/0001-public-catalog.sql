CREATE TABLE catalog_items (
    id BIGINT PRIMARY KEY,
    category TEXT,
    slug TEXT,
    title TEXT,
    description TEXT,
    href TEXT,
    visibility TEXT,
    status TEXT
);
INSERT INTO catalog_items (id, category, slug, title, description, href, visibility, status)
VALUES (9007199254740993, 'guide', 'welcome', 'Welcome', 'A public catalog example', '/guides/welcome', 'public', 'published');
INSERT INTO catalog_items (id, category, slug, title, description, href, visibility, status)
VALUES (2, 'draft', 'private', 'Private draft', 'This row must not be published', '/drafts/private', 'private', 'draft');
