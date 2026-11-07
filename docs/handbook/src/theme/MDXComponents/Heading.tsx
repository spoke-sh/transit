import Heading from "@theme-original/MDXComponents/Heading";
import type { Props } from "@theme/MDXComponents/Heading";
import { HandbookChapter, useHandbookPage } from "../../components/HandbookPage";
import PossibilityAtlas from "../../components/PossibilityAtlas";

export default function HandbookHeading(props: Props) {
  const route = useHandbookPage();
  return (
    <>
      {props.as === "h1" && route && <HandbookChapter route={route} />}
      <Heading {...props} />
      {route === "guides/introduction" && props.id === "see-what-you-could-build" && (
        <PossibilityAtlas />
      )}
    </>
  );
}
