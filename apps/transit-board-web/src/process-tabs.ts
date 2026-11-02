export const tabs = [
  "process",
  "mailbox",
  "outbox",
  "effects",
  "payloads",
  "history",
  "associations",
] as const;
export type Tab = (typeof tabs)[number];
