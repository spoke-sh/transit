{
  lib,
  buildGo127Module,
  fetchFromGitHub,
  pins,
}:
{
  kind = buildGo127Module {
    pname = "kind";
    version = pins.kind;
    src = fetchFromGitHub {
      owner = "kubernetes-sigs";
      repo = "kind";
      rev = "v${pins.kind}";
      hash = "sha256-exqO/KERw/SOv3dywcrm/DSHY37dfTOhQezg6Nroew0=";
    };
    vendorHash = "sha256-tRpylYpEGF6XqtBl7ESYlXKEEAt+Jws4x4VlUVW8SNI=";
    subPackages = [ "." ];
    env.CGO_ENABLED = 0;
    ldflags = [
      "-s"
      "-w"
    ];
    meta = {
      description = "Kind CLI matched to Transit's Substrate reference";
      homepage = "https://kind.sigs.k8s.io/";
      license = lib.licenses.asl20;
      mainProgram = "kind";
    };
  };

  kubectl-ate = buildGo127Module {
    pname = "kubectl-ate";
    version = "0-unstable-${builtins.substring 0 7 pins.substrate}";
    src = fetchFromGitHub {
      owner = "agent-substrate";
      repo = "substrate";
      rev = pins.substrate;
      hash = "sha256-/KY4vYgHbeiVnpRUsVFOVfoN3SVEtWJrXTj0Pb4Zeqw=";
    };
    # The pinned source includes its complete upstream vendor tree.
    vendorHash = null;
    subPackages = [ "cmd/kubectl-ate" ];
    env.CGO_ENABLED = 0;
    ldflags = [
      "-s"
      "-w"
      "-X=github.com/agent-substrate/substrate/internal/version.Commit=${pins.substrate}"
    ];
    meta = {
      description = "Agent Substrate kubectl plugin at Transit's reference revision";
      homepage = "https://github.com/agent-substrate/substrate";
      license = lib.licenses.asl20;
      mainProgram = "kubectl-ate";
    };
  };
}
