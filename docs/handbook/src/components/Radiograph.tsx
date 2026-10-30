import type { ReactElement } from "react";
import radiograph from "../../../design/handbook-theme/images/d6-radiograph.jpg";

export default function Radiograph(): ReactElement {
  return (
    <div className="radiograph-visual">
      <div className="radiograph-volume">
        <img
          className="radiograph-poster"
          src={radiograph}
          alt="Silver membranes expose translucent internal folds and a deeper pocket, with a vermilion thread receding through them."
          width={1774}
          height={887}
          loading="lazy"
          decoding="async"
        />
      </div>
      <div className="radiograph-controls">
        <a href="#handbook">
          Skip to the handbook <span aria-hidden="true">↓</span>
        </a>
      </div>
    </div>
  );
}
