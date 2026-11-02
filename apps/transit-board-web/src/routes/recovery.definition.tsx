import { createFileRoute } from "@tanstack/react-router";
import { DefinitionEditor } from "../features";
export const Route = createFileRoute("/recovery/definition")({ component: DefinitionEditor });
