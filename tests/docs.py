"""Check repository Markdown links and fences without external dependencies."""
from pathlib import Path
import re

root = Path(__file__).resolve().parent.parent
files = [root / "README.md", root / "AGENTS.md", *sorted((root / "docs").rglob("*.md")), *sorted((root / "contracts").rglob("*.md")), *sorted((root / "examples").rglob("*.md"))]
errors = []
links = 0
for file in files:
    content = file.read_text()
    if not content.endswith("\n") or len(re.findall(r"^```", content, re.M)) % 2:
        errors.append(f"{file.relative_to(root)}: missing newline or unbalanced code fence")
    for target in re.findall(r"(?<!!)\[[^\]]*\]\(([^)]+)\)", content):
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
