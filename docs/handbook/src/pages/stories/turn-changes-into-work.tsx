import type { ReactElement } from "react";
import StoryPage from "../../components/StoryPage";
import { stories } from "../../stories";

export default function TurnChangesIntoWork(): ReactElement {
  return <StoryPage story={stories.work} />;
}
