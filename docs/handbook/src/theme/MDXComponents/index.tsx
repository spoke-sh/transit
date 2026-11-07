import type { ComponentProps } from "react";
import MDXComponents from "@theme-original/MDXComponents";
import type { MDXComponentsObject } from "@theme/MDXComponents";

export default {
  ...MDXComponents,
  // Tables scroll horizontally on narrow screens. Include keyboard access in
  // the server-rendered HTML so it also works before hydration or without JS.
  table: (props: ComponentProps<"table">) => <table tabIndex={0} {...props} />,
} satisfies MDXComponentsObject;
