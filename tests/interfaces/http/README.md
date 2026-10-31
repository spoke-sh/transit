
## Browser authentication

`just test::browser-auth` runs `browser_auth.py` with the embedded Transit
executable. Independent Google, GitHub and Facebook peers verify code exchange,
PKCE and app binding. The fixture tests durable replay rejection, restart,
revocation, bounded read-only publication and exact HTTP/WebSocket origins.
`just test::browser-unit` includes independently signed OIDC claim/signature
negative controls. Provider credentials and external provider availability are
outside these deterministic fixtures.
