import { createFileRoute } from "@tanstack/react-router";
import { DefinitionEditor } from "../definition";
export const Route = createFileRoute("/recovery/definition")({ component: DefinitionEditor });
