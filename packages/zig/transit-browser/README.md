# Browser authentication and published reads

`transit-browser` authenticates browser sessions with Google, Facebook or GitHub
and serves operator-selected read-only SQL results through HTTP and WebSocket.
`transit server` runs this listener from the same executable when `browser_file`
references its JSON configuration. The native administration and SQL listeners
remain separate. No additional public CLI command is introduced.

See [configuration and operations](docs/configuration.md) for deployment, schema,
provider setup, authorization and the browser protocol. The implementation uses
the [shared SQL client](../transit-sql-client/README.md) for statement admission,
settlement, result completeness and current native authorization.

`just test::browser-unit` checks origin, cookies, PKCE and independently signed
OIDC tokens. `just test::browser-auth` runs an actual Transit installation with
independent local OAuth peers and an RFC 6455 client. It exercises provider
exchange, durable callback replay rejection, session restart/logout and HTTP/WS
read boundaries. These fixtures do not certify third-party app registration or
real provider credentials.
