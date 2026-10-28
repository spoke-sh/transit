# Release packages and installation

Transit release packages identify the software version, source commit and exact
contract definition. Package installation does not initialize an application,
grant permissions or migrate retained data. Follow the
[versioning policy](versioning.md) before replacing an executable used by an
existing installation.

## Artifacts and platforms

The [release workflow](../../../.github/workflows/release.yml) builds a static
Linux x86_64 bundle using the pinned Zig compiler, musl and OpenSSL 3.6.4. Its
executables do not require Nix or host shared libraries. The archive includes
`transit` with embedded Board assets, `transit-admin`, `transit-node`,
`transit-query-host`, `transit-board`, `transit-delivery` and
`transit-station-controller`, plus dependency notices and build metadata.

| Distribution | Location for a published version |
| --- | --- |
| Executables | GitHub Release asset `transit-<version>-linux-x86_64.tar.gz` |
| Integrity and identity | `SHA256SUMS` and `release-manifest.json` on the same GitHub Release |
| Local server container | `ghcr.io/spoke-sh/transit:<version>` |
| Standalone component containers | `ghcr.io/spoke-sh/transit-node:<version>`, with the same naming rule for the other bundled executables |
| Helm chart | `oci://ghcr.io/spoke-sh/transit/charts/transit`, chart version `<version>` |

macOS and Windows executables are not produced. The local supervisor requires
Linux process groups and parent-death signals; console editing requires Linux
terminal/inotify APIs, and the authority clock uses Linux `adjtimex`. Other Linux
architectures require separate build and installed-runtime qualification.
The Substrate runtime-controller image needs its pinned provider CLI and remains
outside this artifact set. SDK registry publication is separate from the runtime
bundle; the matching SDK manifests remain available in source.

## Install a published release

For a published version, the repository installer downloads its archive and
checks its SHA-256 digest before installing anything. To install the latest
published version into `~/.local`:

```sh
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/spoke-sh/transit/main/install.sh | sh
```

Pin both the script and package version when reproducing an installation:

```sh
curl --proto '=https' --tlsv1.2 -fsSL \
  https://raw.githubusercontent.com/spoke-sh/transit/v0.0.1/install.sh \
  | sh -s -- --version 0.0.1 --prefix "$HOME/.local"
```

Assets become available only after that tag's publication succeeds. A source
checkout or workflow dry run does not create a public release. The installer
requires Linux x86_64, `curl`, `tar`, `sha256sum` and ordinary POSIX utilities.
Checksums detect corrupted downloads; they share the release host's trust.

Each version is installed beneath `<prefix>/lib/transit/<version>`, with command
symlinks in `<prefix>/bin`. Put that bin directory on `PATH` and run
`transit --version`. Installation refuses to overwrite an existing version
directory, unrelated binary or unrelated symlink. Previous version directories
remain available; no server starts and no installation data changes. Switching a
symlink back does not make an incompatible retained installation readable.
Use the [local guide](../guides/quickstart.md) after installation.

## Containers and Helm

The local server container runs as UID/GID 65532. Its services retain their
loopback/private admission boundaries; publishing container ports does not expose
them on every interface. Use the in-container console or an explicit tunnel.
The local supervisor requires `--init` so its managed children have a parent
other than PID 1. Provide persistent data and writable temporary storage:

```sh
docker run -d --init --name transit --read-only \
  --mount type=volume,source=transit-data,target=/data \
  --tmpfs /tmp:rw,mode=1777 ghcr.io/spoke-sh/transit:0.0.1
docker exec -it transit transit console
```

The host must supply the synchronized clock required by the runtime. Configuration
uses the existing [server settings](../../../apps/transit-cli/docs/server.md).
Mount configuration and secret references explicitly; never put credentials in
images. For non-local deployments, select the standalone component images and
the existing [chart configuration and bootstrap procedure](../../../charts/transit/README.md).
Fetch the versioned chart with:

```sh
helm pull --version 0.0.1 oci://ghcr.io/spoke-sh/transit/charts/transit
```

The chart still requires explicit public genesis, component configuration,
separately provisioned credentials and recorded grants. Publishing the chart does
not supply these, install Substrate, or authorize bootstrap or replacement.

## Publication and retries

Tag pushes run full ordinary CI plus the distribution build, installed startup,
SQL/restart, container and Helm checks. Only successful tag builds can publish.
Pull requests and manual dispatch build artifacts without publishing. Tag names
must match `VERSION` at a clean commit. Builds retain artifacts in GitHub Actions;
publication uses those artifacts without rebuilding them.

The publisher checks existing image identities, chart bytes and release assets
before reusing them; different bytes under an existing version are refused.
Registry uploads can precede completion of the GitHub Release. A failed run leaves
those versioned objects visible; rerunning the same source/artifacts reuses
identical objects and fills missing ones. The GitHub Release remains a draft until
all uploads succeed. Published versions and their tags must not be replaced.

GitHub's repository token needs `packages: write` for GHCR and `contents: write`
for Release assets. Package visibility is configured in GitHub Packages; confirm
public access before advertising anonymous installation. Repository and
organization policy can restrict these permissions. See GitHub's
[container registry permissions](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
and Helm's [OCI registry semantics](https://docs.helm.sh/docs/topics/registries/).
