#!/usr/bin/env python3
"""Generate a version-pinned Linux Homebrew formula from verified archive hashes."""
import argparse
import json
from pathlib import Path


def formula(manifest):
    version = manifest['release']
    tag = manifest['identity']['tag']
    urls = {}
    for arch in ('x86_64', 'aarch64'):
        name = f'transit-{version}-linux-{arch}.tar.gz'
        urls[arch] = (f'https://github.com/spoke-sh/transit/releases/download/{tag}/{name}',
                      manifest['assets'][name])
    return f'''class Transit < Formula
  desc "Programmable data infrastructure for applications"
  homepage "https://github.com/spoke-sh/transit"
  version "{version}"
  depends_on :linux

  on_intel do
    url "{urls['x86_64'][0]}"
    sha256 "{urls['x86_64'][1]}"
  end
  on_arm do
    url "{urls['aarch64'][0]}"
    sha256 "{urls['aarch64'][1]}"
  end

  def install
    bin.install Dir["bin/*"]
    pkgshare.install "build-info.json", "transit.yaml.example", "notices"
  end

  test do
    assert_match "Transit {version} (git {manifest['source_revision']}; CLI contract 1)", shell_output("#{{bin}}/transit --version")
    assert_match "Options:", shell_output("#{{bin}}/transit server --help")
    assert_match "Options:", shell_output("#{{bin}}/transit console --help")
  end
end
'''


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_text(formula(json.loads(args.manifest.read_text())))
