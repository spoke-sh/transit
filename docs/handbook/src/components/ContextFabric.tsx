import type { ReactElement } from "react";

import fabric from "../../../design/handbook-theme/images/d5-fabric-pockets.jpg";

export default function ContextFabric(): ReactElement {
  return (
    <img
      className="context-fabric"
      src={fabric}
      alt="The graphite fabric straightens after the resonance zones, develops small pockets, and ends in an angled opening with an indistinct form partly hidden behind its rim."
      width={724}
      height={2172}
      loading="lazy"
      decoding="async"
    />
  );
}
