{ lib, root }:
let
  workspace = lib.fileset.unions [
    (root + /package.json)
    (root + /pnpm-lock.yaml)
    (root + /pnpm-workspace.yaml)
  ];
  # Preserve the runtime workspace's importers so its pinned dependency-store
  # hash does not depend on application source or on the native/test trees.
  frontend = lib.fileset.unions [
    (root + /apps/transit-board-web)
    (root + /packages/ts)
    (root + /examples/serving/web)
    (root + /examples/work-items/web)
  ];
  manifests = lib.fileset.intersection frontend (
    lib.fileset.fileFilter (file: file.name == "package.json") root
  );
  navigation = lib.fileset.fileFilter (
    file: file.name == "README.md" || file.name == "AGENTS.md"
  ) root;
  source =
    fileset:
    lib.fileset.toSource {
      inherit root;
      fileset = lib.fileset.difference fileset navigation;
    };
in
{
  frontendDependencies = source (lib.fileset.union workspace manifests);
  boardAssets = source (
    lib.fileset.unions [
      workspace
      manifests
      (root + /apps/transit-board-web)
      (root + /packages/ts)
      (root + /tasks/embed_web.py)
      (root + /contracts/transit-board-v1.openapi.json)
    ]
  );
  runtime = source (
    lib.fileset.unions [
      workspace
      (root + /build)
      (root + /build.zig)
      (root + /build.zig.zon)
      (root + /apps)
      (root + /packages)
      (root + /third_party)
      (lib.fileset.difference (root + /examples) (root + /examples/station-sdk))
      (root + /tasks)
      (root + /contracts)
    ]
  );
}
