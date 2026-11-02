import React from "react";
import ReactDOM from "react-dom/client";
import { createRouter, RouterProvider } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";
import "./style.css";
import { setRequestScheduler } from "@transit/reactive-client";
import { RequestScheduler } from "./request-scheduler";
setRequestScheduler(new RequestScheduler().run);
const router = createRouter({ routeTree, defaultPreload: false });
declare module "@tanstack/react-router" {
  interface Register {
    router: typeof router;
  }
}
ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <RouterProvider router={router} />
  </React.StrictMode>,
);
