import type { ReactElement } from "react";
import Link from "@docusaurus/Link";
import { deliveryJourney } from "../delivery-story";

export default function StoryJourney({ route }: { route: string }): ReactElement {
  return (
    <nav className="transit-story-journey" aria-label="The connected workflow">
      <p className="transit-kicker">ONE APPLICATION, THREE CHAPTERS</p>
      <ol>
        {deliveryJourney.map((chapter, index) => (
          <li key={chapter.route}>
            <Link
              to={`/${chapter.route}`}
              aria-current={route === chapter.route ? "page" : undefined}
            >
              <span className="transit-kicker">
                0{index + 1} / {chapter.kinds}
              </span>
              <span>
                {chapter.title} <span aria-hidden="true">→</span>
              </span>
            </Link>
          </li>
        ))}
      </ol>
    </nav>
  );
}
