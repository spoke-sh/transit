import type { ReactElement } from "react";

import wavefront from "../../../design/handbook-theme/images/d4-context-wavefront.webp";

export default function ContextEchoes(): ReactElement {
  return (
    <div
      className="context-scene"
      role="img"
      aria-label="A vermilion result trace unfolds through suspended wavefronts, with two graphite echoes retaining the forms that shaped it."
    >
      {["far", "near", "result"].map((layer) => (
        <img
          key={layer}
          className={`context-layer context-layer--${layer}`}
          src={wavefront}
          alt=""
          aria-hidden="true"
          width={1536}
          height={1024}
          loading="lazy"
          decoding="async"
        />
      ))}
    </div>
  );
}
