"""Check repository Markdown links and fences without external dependencies."""
from pathlib import Path
import os
import re

from paths import ROOT as root
files = [root / "README.md", root / "AGENTS.md"]
for source in ("docs", "contracts", "examples", "packages", "sdks", "apps", "deploy", "charts", "launchers", "nix", "tasks", "tests", "bindings"):
    for directory, children, names in os.walk(root / source):
        # Check source documentation, not downloaded tools or generated output.
        children[:] = sorted(name for name in children if not name.startswith(".") and name not in {"node_modules", "zig-out", "zig-pkg", "dist", "coverage"})
        files.extend(Path(directory) / name for name in sorted(names) if name.endswith(".md"))
errors = []
links = 0
for file in files:
    content = file.read_text()
    if not content.endswith("\n") or len(re.findall(r"^```", content, re.M)) % 2:
        errors.append(f"{file.relative_to(root)}: missing newline or unbalanced code fence")
    # Fenced examples can contain syntax such as Python's Codec[T](Protocol),
    # which resembles a Markdown link but is literal code.
    prose = re.sub(r"^```[^\n]*\n.*?^```[ \t]*$", "", content, flags=re.M | re.S)
    for target in re.findall(r"(?<!!)\[[^\]]*\]\(([^)]+)\)", prose):
        if re.match(r"^[a-z][a-z0-9+.-]*:", target):
            continue
        path, _, anchor = target.partition("#")
        destination = file.parent / path if path else file
        links += 1
        if not destination.exists():
            errors.append(f"{file.relative_to(root)}: missing {target}")
        elif anchor and destination.suffix == ".md":
            headings = re.findall(r"^#{1,6}\s+(.+)$", destination.read_text(), re.M)
            slugs = [re.sub(r"[^\w\- ]", "", h.lower()).replace(" ", "-") for h in headings]
            if anchor not in slugs:
                errors.append(f"{file.relative_to(root)}: missing heading {target}")
if errors:
    raise SystemExit("\n".join(errors))
print(f"Documentation: {links} local links across {len(files)} files passed")
