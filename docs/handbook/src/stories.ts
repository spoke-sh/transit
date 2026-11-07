// Story examples stay tied to the runnable quickstart. The content check verifies
// each excerpt against that owner; these pages do not execute SQL in the browser.
export const statements = {
  define: {
    language: "sql",
    code: "CREATE TABLE tasks (\n    id BIGINT PRIMARY KEY,\n    title TEXT NOT NULL,\n    done BOOLEAN DEFAULT FALSE\n);",
  },
  inspect: { language: "sql", code: "SHOW TABLES;\nDESCRIBE tasks;" },
  insert: {
    language: "sql",
    code: "INSERT INTO tasks (id, title) VALUES\n    (1, 'Review the data model'),\n    (2, 'Explore query results');",
  },
  count: { language: "sql", code: "SELECT COUNT(*) FROM tasks WHERE done = FALSE;" },
  update: {
    language: "sql",
    code: "UPDATE tasks SET done = TRUE WHERE id = 1;\nSELECT COUNT(*) FROM tasks WHERE done = FALSE;",
  },
  evolve: {
    language: "sql",
    code: "ALTER TABLE tasks ADD COLUMN priority BIGINT DEFAULT 1;\nDESCRIBE tasks;\nSELECT id, title, done, priority FROM tasks;",
  },
  server: {
    language: "bash",
    code: "mkdir -p .cache/docs-start\ncd .cache/docs-start\ntransit server",
  },
  console: { language: "bash", code: "cd .cache/docs-start\ntransit console" },
  restart: { language: "bash", code: "transit server" },
} as const;

export type Statement = (typeof statements)[keyof typeof statements];
type StoryLink = { label: string; to: string };
export type StoryStep = {
  id: string;
  label: string;
  title: string;
  paragraphs: string[];
  statement?: Statement;
  observation: { value: string; detail: string };
  reference: StoryLink;
};
export type Story = {
  route: string;
  title: string;
  headline: string;
  description: string;
  premise: string;
  preparation: StoryLink;
  steps: StoryStep[];
  next: StoryLink;
};

export const stories = {
  dataset: {
    route: "stories/first-dataset",
    title: "Create your first dataset",
    headline: "A few statements.\nA dataset you can build on.",
    description:
      "Give your tasks a home. Ask what is left to do. Change the shape as your application grows.",
    premise:
      "Follow this sequence in a new local installation on Linux x86_64, with the Transit executable on PATH and ports 19101–19108 free. Use the same installed bundle when you resume. The examples below show expected observations; this page does not connect to a server.",
    preparation: { label: "Installation and local setup", to: "/guides/quickstart" },
    steps: [
      {
        id: "start",
        label: "Start",
        title: "Make room for your data.",
        paragraphs: [
          "Start Transit in a new working directory. The executable includes the local database, SQL service and Board. Wait for server.ready and board.ready before continuing.",
          "Keep this directory: it holds the installation and its data. Default listeners bind to loopback for a trusted single-user installation.",
        ],
        statement: statements.server,
        observation: {
          value: "One local installation",
          detail: "Board opens at http://127.0.0.1:19107 with the default configuration.",
        },
        reference: {
          label: "Defaults, configuration and readiness",
          to: "/guides/quickstart#start-with-defaults",
        },
      },
      {
        id: "connect",
        label: "Connect",
        title: "Open a conversation with it.",
        paragraphs: [
          "Leave the server running. In a second terminal, start from the same parent directory and open the console.",
          "The local connection supplies an authorized catalog and Table writer. Run the following SQL statements in this console.",
        ],
        statement: statements.console,
        observation: {
          value: "Ready for SQL",
          detail: "The console connects to the installation in this working directory.",
        },
        reference: {
          label: "Console setup",
          to: "/guides/quickstart#read-and-write-from-a-second-terminal",
        },
      },
      {
        id: "define",
        label: "Define",
        title: "Say what a task is.",
        paragraphs: [
          "Every task has an identity, a title and a completion flag. The primary key keeps identities unique; the required title and default completion flag make the shape explicit.",
        ],
        statement: statements.define,
        observation: {
          value: "A Table with a definition",
          detail:
            "Creation publishes the schema. It does not insert rows. Use SHOW TABLES and DESCRIBE tasks to inspect it.",
        },
        reference: { label: "Table definitions and identity", to: "/reference/tables" },
      },
      {
        id: "write",
        label: "Write",
        title: "Give the definition something to hold.",
        paragraphs: [
          "Add two tasks. Omit done and let the declared default do its work. Both tasks start unfinished.",
        ],
        statement: statements.insert,
        observation: {
          value: "2 tasks · done = false",
          detail:
            "A successful mutation reports its applied outcome. An unconfirmed write needs its original outcome resolved before you repeat it.",
        },
        reference: {
          label: "Writes and their outcomes",
          to: "/guides/quickstart#write-rows-and-compute-an-answer",
        },
      },
      {
        id: "ask",
        label: "Ask",
        title: "Turn the rows into an answer.",
        paragraphs: [
          "Ask how much work remains. This finite query reads a fresh snapshot of the tasks you just inserted.",
        ],
        statement: statements.count,
        observation: {
          value: "2 unfinished tasks",
          detail:
            "Expected after the two inserts. A complete result answers the question for that read.",
        },
        reference: { label: "SELECT and result semantics", to: "/reference/sql/select" },
      },
      {
        id: "change",
        label: "Change",
        title: "Make progress. See it from another session.",
        paragraphs: [
          "Open another transit console in the same installation directory. Mark the first task complete, then count again.",
          "Run the count again in the first console too. Each new SELECT sees a fresh snapshot; the two sessions keep independent cursors.",
        ],
        statement: statements.update,
        observation: {
          value: "1 unfinished task",
          detail:
            "Expected after task 1 is marked complete. An earlier result does not update itself.",
        },
        reference: {
          label: "Independent sessions",
          to: "/guides/quickstart#observe-a-change-from-another-session",
        },
      },
      {
        id: "evolve",
        label: "Evolve",
        title: "Let the shape grow with the work.",
        paragraphs: [
          "Add a priority when the application needs one. The default supplies a value for existing and future rows.",
          "Transit validates and publishes the schema and data successor together. An already open reader keeps its original schema and data until that read ends.",
        ],
        statement: statements.evolve,
        observation: {
          value: "Both tasks have priority 1",
          detail:
            "DESCRIBE shows the new column. The SELECT shows the values under the published schema.",
        },
        reference: { label: "Supported schema changes", to: "/reference/sql/alter-table" },
      },
      {
        id: "resume",
        label: "Resume",
        title: "Stop the server. Keep the work.",
        paragraphs: [
          "Enter .quit in the consoles and press Ctrl-C in the server terminal. From the same directory, restart with the same configuration and installed artifacts.",
          "Reconnect and run the count again: one task remains unfinished. Repeating this whole sequence in an existing installation creates new operations; inspect the existing data first.",
        ],
        statement: statements.restart,
        observation: {
          value: "1 unfinished task, after restart",
          detail:
            "Accepted data stays in the installation. Missing state or changed artifacts cause startup to refuse recovery rather than recreate history.",
        },
        reference: {
          label: "Stopping, resuming and uncertain outcomes",
          to: "/guides/quickstart#stop-and-resume",
        },
      },
    ],
    next: { label: "Explore the data model", to: "/stories/data-model" },
  },
  model: {
    route: "stories/data-model",
    title: "Explore the data model",
    headline: "Start with the data.\nFollow what it makes possible.",
    description:
      "A task list is a small example of a larger model: data with meaning, computation with a lifetime, and policies with observable consequences.",
    premise:
      "This story explains the task dataset from the quickstart; its SQL excerpts illustrate that walkthrough. Other data kinds and computation lifetimes have their own public operations; each chapter links to its owner.",
    preparation: { label: "Create the example dataset", to: "/stories/first-dataset" },
    steps: [
      {
        id: "shape",
        label: "Represent",
        title: "Give each kind of data the right shape.",
        paragraphs: [
          "Tasks fit a Table: typed records with keys, defaults and required fields. Key-value objects fit keyed state; Documents hold structured edits and collaborative text; Streams retain events; Queues carry leased work.",
          "Choose the representation for what the data means. The data model reference identifies the SQL or typed caller operations available for each one.",
        ],
        statement: statements.define,
        observation: {
          value: "Data has a declared meaning",
          detail:
            "A task row has a typed value or SQL NULL in each cell. Documents and query adapters also distinguish missing values, conversion errors and conflicts.",
        },
        reference: {
          label: "Representations and their interfaces",
          to: "/reference/data-model#choose-a-data-representation",
        },
      },
      {
        id: "identity",
        label: "Identify",
        title: "Keep the object distinct from its name.",
        paragraphs: [
          "The name tasks helps you find a Table. Its stable identity and immutable definition tell an operation which object and interpretation it uses.",
          "Renaming preserves Table and column identities. Dropping and recreating the same name makes a different object. Saved operations retain their original binding.",
        ],
        statement: statements.inspect,
        observation: {
          value: "A name. An object. A definition.",
          detail:
            "SHOW TABLES locates the published Table; DESCRIBE exposes its schema. These are separate from the rows a query reads.",
        },
        reference: {
          label: "Definitions, data and dependencies",
          to: "/reference/data-model#describe-definitions-data-and-dependencies-separately",
        },
      },
      {
        id: "change",
        label: "Evolve",
        title: "Change the definition without rewriting an earlier read.",
        paragraphs: [
          "The application now needs priorities. Publish a new column with a default, then inspect the schema and rows together.",
          "New readers see the published successor. A reader holding an earlier snapshot keeps its original interpretation and data for that read's lifetime.",
        ],
        statement: statements.evolve,
        observation: {
          value: "New reads include priority",
          detail:
            "Both existing tasks have priority 1. Schema revisions, data revisions and read snapshots answer different questions.",
        },
        reference: {
          label: "Change, history and retained reads",
          to: "/reference/data-model#understand-change-and-history",
        },
      },
      {
        id: "compute",
        label: "Compute",
        title: "Choose how long an answer should live.",
        paragraphs: [
          "A finite SELECT answers a question against fresh source snapshots. Captured queries retain their original request, progress and result so callers can recover them. Maintained relations publish successive complete revisions as source history advances.",
          "The console supports interactive and explicit captured queries. Maintained relational queries use typed Zig owners and an authenticated host with explicit activation and wakeups.",
        ],
        statement: statements.count,
        observation: {
          value: "A result has a basis and a lifetime",
          detail:
            "This SELECT is a finite read. It does not create an automatically maintained view.",
        },
        reference: {
          label: "Computation lifetimes",
          to: "/reference/data-model#choose-a-computation-lifetime",
        },
      },
      {
        id: "govern",
        label: "Govern",
        title: "Make the boundaries part of the model.",
        paragraphs: [
          "Permissions decide who can read and change an object. Retention decides which history may expire. Budgets bound the work a computation may consume.",
          "Current authorization still applies to retained results. History has no expiry by default; application opt-in is required. These policies have distinct owners and do not form one cross-owner atomic transaction.",
        ],
        observation: {
          value: "Access · lifetime · permitted work",
          detail:
            "An old snapshot cannot preserve revoked permission. Disk pressure cannot consent to deleting application history.",
        },
        reference: {
          label: "Policy owners and controls",
          to: "/reference/data-model#govern-access-and-lifetime",
        },
      },
      {
        id: "observe",
        label: "Observe",
        title: "Ask whether the declaration is being fulfilled.",
        paragraphs: [
          "Inspect the published definition, the original operation's outcome, and the data basis and completion of a result. Those observations tell you what happened, not just what was requested.",
          "A valid definition, accepted work, a complete result and an up-to-date result are different facts. Their owning interfaces expose the evidence; Transit does not provide a single catalog-wide declaration health view.",
        ],
        observation: {
          value: "Intent → operation → observable outcome",
          detail:
            "Keep definition identity, source basis and completion evidence together when presenting an answer.",
        },
        reference: { label: "Data, computation and policies", to: "/reference/data-model" },
      },
    ],
    next: { label: "Follow a query to its result", to: "/stories/query-results" },
  },
  queries: {
    route: "stories/query-results",
    title: "Follow a query to its result",
    headline: "An answer is useful.\nKnowing what it answers is essential.",
    description:
      "Follow one count as the data changes, then choose what needs to survive beyond the current read.",
    premise:
      "Begin at the point where the dataset walkthrough has inserted two unfinished tasks, before either is completed. These are expected observations at successive points in that example, not live results from your installation.",
    preparation: { label: "Create your first dataset", to: "/stories/first-dataset" },
    steps: [
      {
        id: "ask",
        label: "Ask",
        title: "Ask a precise question.",
        paragraphs: [
          "How many tasks remain unfinished? The predicate selects the rows; COUNT turns them into one answer. Fuze executes the query over authorized sources.",
        ],
        statement: statements.count,
        observation: {
          value: "2 unfinished tasks",
          detail: "Expected after the initial two inserts, before either task is marked complete.",
        },
        reference: { label: "Finite SELECT queries", to: "/reference/sql/select" },
      },
      {
        id: "read-again",
        label: "Read again",
        title: "New work changes the next answer.",
        paragraphs: [
          "Complete the first task, then ask again. A new interactive SELECT reads a fresh snapshot.",
          "The earlier count of two remains an answer about its earlier read. It is not a promise about the current Table.",
        ],
        statement: statements.update,
        observation: {
          value: "2 → 1",
          detail:
            "Two successive completed reads, separated by an accepted change. The first result is not a live subscription.",
        },
        reference: {
          label: "Interactive query sessions",
          to: "/reference/queries#interactive-sessions",
        },
      },
      {
        id: "complete",
        label: "Complete",
        title: "Know when you have the whole answer.",
        paragraphs: [
          "Larger results arrive in bounded pages. Pages are delivery units; successful completion establishes coverage of the result.",
          "A disconnected transport or a partial prefix does not establish an empty or complete answer. Do not start a fresh SELECT and splice its different snapshot into the existing result.",
        ],
        observation: {
          value: "Rows + source basis + completion",
          detail:
            "Independent sources can have independent snapshots. A source vector does not imply one global atomic snapshot.",
        },
        reference: {
          label: "Result recovery and display",
          to: "/reference/queries#recovery-and-display",
        },
      },
      {
        id: "retain",
        label: "Retain",
        title: "Keep an answer you need to return to.",
        paragraphs: [
          "Choose captured execution when the original request, progress and retained result need to survive a disconnect or worker loss. Recover that original accepted query and inspect its recorded outcome.",
          "Choose a maintained relation when you need successive complete revisions. Typed Zig owners bind the definition and source vectors; an authenticated host supplies activation and wakeups. SQL does not provide an automatic materialized-view service.",
        ],
        observation: {
          value: "Interactive · captured · maintained",
          detail:
            "Choose the lifetime explicitly. Reading a saved definition starts no work, and retained results still require current permission.",
        },
        reference: { label: "Query execution and recovery", to: "/reference/queries" },
      },
    ],
    next: { label: "Explore the data model", to: "/stories/data-model" },
  },
} satisfies Record<string, Story>;

export const storySearchEntries = Object.values(stories).map((story) => ({
  title: story.title,
  route: story.route,
  text: [
    story.headline,
    story.description,
    story.premise,
    ...story.steps.flatMap((step) => [
      step.title,
      ...step.paragraphs,
      step.observation.value,
      step.observation.detail,
    ]),
  ].join(" "),
}));
