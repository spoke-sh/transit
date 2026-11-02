import { createFileRoute } from "@tanstack/react-router";
import { JourneyPage } from "../features";
export const Route = createFileRoute("/processes/$pid/journey")({ component: JourneyPage });
