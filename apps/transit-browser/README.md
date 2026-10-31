# Browser runtime role

This entry point composes the [browser library](../../packages/zig/transit-browser/README.md)
with the shared bounded HTTP server. `transit server` selects it through the
private embedded role dispatcher when `browser_file` is configured. The optional
`zig build transit-browser` artifact accepts one argument: that JSON file.
