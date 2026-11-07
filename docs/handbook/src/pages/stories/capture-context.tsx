import type { ReactElement } from "react";
import StoryPage from "../../components/StoryPage";
import { stories } from "../../stories";

export default function CaptureContext(): ReactElement {
  return <StoryPage story={stories.capture} />;
}
