CREATE TABLE transit_browser_challenges (id INT64 PRIMARY KEY, state_hash VARCHAR, browser_hash VARCHAR, provider VARCHAR, expires_at INT64, consumed INT64);
CREATE TABLE transit_browser_identities (id INT64 PRIMARY KEY, subject_hash VARCHAR, provider VARCHAR, disabled INT64);
CREATE TABLE transit_browser_sessions (id INT64 PRIMARY KEY, token_hash VARCHAR, identity_id INT64, expires_at INT64, revoked INT64);
