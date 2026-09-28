import { Link, useRouterState } from "@tanstack/react-router";
import { selectedScreen, useInterface } from "./interface";
import { Atlas } from "./atlas";
import { Activity, Operations } from "./foundations";
import { DefinitionEditor } from "./definition";
import { UnifiedWorkspace } from "./unified-workspace";
import { QueryWorkspace } from "./query-workspace";
/** Component artifacts interpret one whole validated declaration generation. */
export function DeclaredView() {
  const current = useInterface();
  const path = useRouterState({ select: (state) => state.location.pathname });
  if (!current) return null;
  const definition = current.compiled.definition;
  const screen = selectedScreen(definition, path);
  if (!screen)
    return (
      <main>
        <h1>Screen unavailable</h1>
        <p>This path is absent from the current interface.</p>
      </main>
    );
  const binding = definition.bindings.find((value) => value.name === screen.binding)!;
  let view;
  switch (screen.renderer) {
    case "atlas":
      view = (
        <Atlas
          projection={
            "inspection" in binding.source && binding.source.inspection.projection === "resources"
              ? "resources"
              : "inspection" in binding.source &&
                  binding.source.inspection.projection === "processes"
                ? "processes"
                : "all"
          }
          initialEmphasis={
            "inspection" in binding.source && binding.source.inspection.projection === "resources"
              ? "resources"
              : "processes"
          }
        />
      );
      break;
    case "records":
      view = <Atlas initialEmphasis="resources" projection="resources" />;
      break;
    case "activity":
      view = <Activity />;
      break;
    case "operations":
      view = <Operations />;
      break;
    case "definition":
      view = <DefinitionEditor />;
      break;
    case "worksheet": {
      if (!("query" in binding.source)) throw new Error("Invalid worksheet binding");
      const query = binding.source.query;
      view = (
        <main>
          <h1>{screen.label}</h1>
          {query.profile === "unified_v2" ? (
            <UnifiedWorkspace
              followLabel={
                definition.actions.find(
                  (action) => "follow" in action.target && action.target.follow === binding.name,
                )?.label
              }
              binding={query}
              resource={query.resource}
              mode="browse"
              visible
              onBack={() => history.back()}
            />
          ) : (
            <QueryWorkspace
              binding={query}
              resource={query.resource}
              mode="browse"
              visible
              onBack={() => history.back()}
            />
          )}
        </main>
      );
      break;
    }
    case "work_items":
      view = (
        <main>
          <h1>Component unavailable</h1>
          <p>This screen requires the downstream work-item application artifact.</p>
        </main>
      );
      break;
  }
  return (
    <div key={`${current.identity}/${screen.name}`}>
      <nav className="declared-actions" aria-label="Declared navigation">
        {definition.actions.flatMap((action) => {
          if (!("navigate" in action.target)) return [];
          const name = action.target.navigate;
          const target = definition.screens.find((candidate) => candidate.name === name)!;
          return (
            <Link key={action.name} to={target.path}>
              {action.label}
            </Link>
          );
        })}
      </nav>
      {view}
    </div>
  );
}
