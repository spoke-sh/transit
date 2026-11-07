import Layout from "@theme-original/DocItem/Layout";
import { useDoc } from "@docusaurus/plugin-content-docs/client";
import type { Props } from "@theme/DocItem/Layout";
import { HandbookPageContext, handbookRoute } from "../../../components/HandbookPage";
import "../../../css/handbook.css";

export default function HandbookLayout(props: Props) {
  const { metadata } = useDoc();
  const route = handbookRoute(metadata.id);
  return (
    <HandbookPageContext.Provider value={route}>
      <div className="handbook-page" data-handbook-page={route}>
        <Layout {...props} />
      </div>
    </HandbookPageContext.Provider>
  );
}
