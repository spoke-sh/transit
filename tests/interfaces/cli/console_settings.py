"""Assertions for the human settings layout, including JSON result sessions."""

NAMES = ('connection', 'connection_source', 'endpoint', 'format', 'format_source', 'timing', 'timing_source')


def parse_show(output):
    lines = output.decode('ascii').splitlines()
    assert len(lines) == len(NAMES), output
    settings = {}
    for name, line in zip(NAMES, lines):
        assert line[:19] == name.rjust(17)+': ', line
        value = line[19:]
        assert value and all(' ' <= char <= '~' for char in value), line
        settings[name] = value
    return settings


def read_show(shell):
    return parse_show(b'\n'.join(shell.read(json_line=False) for _ in NAMES)+b'\n')
