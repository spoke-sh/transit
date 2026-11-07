import type { Statement, Story } from "./stories";

// Product direction: Streams/Queues (06), Documents (07), managed computation
// and source/output composition (12). See the site README for source owners.
// SQL highlighting is presentational; target labels identify proposed examples.
const target = (code: string): Statement => ({ language: "sql", intent: "target", code });

export const deliveryStatements = {
  capture: target(`CREATE STREAM delivery_events (
    order_id BIGINT,
    status TEXT,
    delay_minutes BIGINT
);
PRODUCE INTO delivery_events VALUES
    (42, 'delayed', 45);`),
  context: target("CREATE DOCUMENT delivery_context;"),
  rules: target("CREATE KV delivery_rules (INT64);"),
  history: target(`SELECT order_id, status, delay_minutes
FROM STREAM_SLICE(
    delivery_events, OFFSET 0 TO 100
);`),
  tables: target(`CREATE TABLE deliveries (
    order_id BIGINT PRIMARY KEY,
    delay_minutes BIGINT NOT NULL
);
CREATE TABLE attention (
    order_id BIGINT PRIMARY KEY,
    delay_minutes BIGINT NOT NULL
);`),
  derive: target(`CREATE DATAFLOW delivery_attention
INTO attention AS
SELECT order_id, delay_minutes
FROM deliveries
WHERE delay_minutes > 30;`),
  activate: target(`AUTHORIZE DATAFLOW delivery_attention;
ACTIVATE DATAFLOW delivery_attention;
SHOW DATAFLOW delivery_attention;`),
  revision: target("SHOW DATAFLOW delivery_attention REVISION 1;"),
  queue: target(`CREATE QUEUE followups (
    order_id BIGINT,
    reason TEXT
);
ENQUEUE INTO followups VALUES
    (42, 'delivery_delayed');`),
  claim: target(`CLAIM order_id, reason
FROM followups
LIMIT 1 WITH LEASE '30s';`),
  settle: target("ACK ON QUEUE followups RECEIPT ?;"),
  close: target(`PRODUCE INTO delivery_events VALUES
    (42, 'delivered', 0);`),
};

export const deliveryJourney = [
  {
    route: "stories/capture-context",
    title: "Keep what happened",
    kinds: "STREAM · DOCUMENT · KV",
  },
  {
    route: "stories/keep-answers-current",
    title: "Keep answers current",
    kinds: "TABLE · DATAFLOW",
  },
  {
    route: "stories/turn-changes-into-work",
    title: "Turn changes into work",
    kinds: "QUEUE · EFFECTS",
  },
] as const;

const premise =
  "Follow an illustrative delivery application through the planned connected workflow. Target SQL shows the intended experience, including proposed grammar; this is not an executable tutorial. Linked references describe current support.";
const preparation = { label: "Start with the runnable dataset", to: "/stories/first-dataset" };

export const deliveryStories = {
  model: {
    route: "stories/data-model",
    title: "Explore the data model",
    headline: "Start with the data.\nBuild the whole application.",
    description:
      "An order is running late. Keep the evidence, understand the situation, and give someone the work to resolve it. Each data kind has a part to play.",
    intent: "target",
    premise,
    preparation,
    steps: [
      {
        id: "events",
        label: "STREAM",
        title: "Keep what happened.",
        paragraphs: [
          "A parcel is collected, delayed, then delivered. A STREAM retains those observations so different consumers can follow the same history and ask new questions of it.",
        ],
        statement: deliveryStatements.capture,
        caption: "The story begins with order 42 running 45 minutes late.",
        observation: {
          value: "An event becomes lasting evidence",
          detail:
            "Consumer progress belongs to each consumer. Reading historical slices leaves that progress alone.",
        },
        reference: { label: "Streams and consumer progress", to: "/reference/streams" },
      },
      {
        id: "context",
        label: "DOCUMENT",
        title: "Keep the context with it.",
        paragraphs: [
          "The carrier's response, delivery instructions and customer conversation carry more meaning than a status field. The planned DOCUMENT model preserves structured content, revisions and original source parts while making useful paths queryable.",
        ],
        statement: deliveryStatements.context,
        caption: "A place for the detail behind the delivery.",
        observation: {
          value: "Rich context, useful fields",
          detail:
            "Extract a delivery window without throwing away the document it came from. Choose the document's revision and merge policy explicitly.",
        },
        reference: { label: "Documents, structure and revisions", to: "/reference/documents" },
      },
      {
        id: "rules",
        label: "KV",
        title: "Remember what matters for this customer.",
        paragraphs: [
          "A standard delivery can wait thirty minutes. An urgent one needs attention sooner. KV gives the application a direct way to look up a threshold by its service key; the planned computation can bind the rule revision it used.",
        ],
        statement: deliveryStatements.rules,
        caption: "Typed keyed state for application rules.",
        observation: {
          value: "standard → 30 minutes",
          detail:
            "An illustrative rule value. Publishing a KV definition and writing its entries are separate operations.",
        },
        reference: { label: "Keyed state and its public operations", to: "/reference/state" },
      },
      {
        id: "answers",
        label: "TABLE + DATAFLOW",
        title: "Turn the facts into an answer that keeps up.",
        paragraphs: [
          "TABLE gives the application a queryable picture of its deliveries. DATAFLOW describes how to derive useful results and keep publishing complete answers as inputs change.",
          "The connected target brings event history, document fields and keyed rules into those computations. Ask which deliveries need attention, then let Transit maintain that answer.",
        ],
        statement: deliveryStatements.derive,
        caption:
          "A simple threshold makes the computation visible. The answer story declares its source and output Tables.",
        observation: {
          value: "Facts → useful state → maintained answers",
          detail:
            "DATAFLOW connects the data kinds. Its definition, activation, source progress and completed results remain inspectable.",
        },
        reference: {
          label: "Managed computations and their lifecycle",
          to: "/reference/queries#managed-table-computations",
        },
      },
      {
        id: "work",
        label: "QUEUE",
        title: "Give the answer somewhere to go.",
        paragraphs: [
          "A late delivery needs follow-up. QUEUE gives that work a destination, a lease and a recorded settlement. Workers can share the load; delayed work and retry policies decide when another attempt becomes eligible.",
          "The planned composition commits changes to application state, consumed progress and new work together. Station builds durable application behavior and governed effects on those primitives.",
        ],
        statement: deliveryStatements.claim,
        caption: "A worker takes responsibility for one follow-up.",
        observation: {
          value: "An answer becomes accountable work",
          detail:
            "A queue acknowledgement records settlement. An external action has its own authorization and recorded outcome.",
        },
        reference: { label: "Queues, leases and settlement", to: "/reference/streams" },
      },
      {
        id: "change",
        label: "POLICY + HISTORY",
        title: "Change the rule. Keep the reasoning.",
        paragraphs: [
          "Tomorrow, the business may need a different threshold or delivery policy. Versioned definitions and results keep the basis of earlier decisions inspectable.",
          "The planned branch, diff and merge experience lets a team review changes to data and definitions before publishing them. Access, retention and activation remain explicit choices.",
        ],
        observation: {
          value: "A system you can explain and evolve",
          detail:
            "Reviewing or merging a definition does not authorize an external effect. Retention has no expiry unless the application opts in.",
        },
        reference: {
          label: "Versioned data, computation and policies",
          to: "/reference/data-model",
        },
      },
    ],
    next: { label: "Keep what happened", to: "/stories/capture-context" },
  },
  capture: {
    route: "stories/capture-context",
    title: "Keep what happened",
    headline: "Every event has a story.\nKeep enough to tell it.",
    description:
      "Follow order 42 from a carrier update to retained history, rich context and the rules that give it meaning.",
    intent: "target",
    premise,
    preparation,
    steps: [
      {
        id: "arrive",
        label: "Retain",
        title: "Give every arrival a place.",
        paragraphs: [
          "A carrier reports a forty-five-minute delay. Append the observation to delivery_events. Other consumers can follow the same history at their own pace.",
          "The planned SOURCE lifecycle connects external feeds to explicit destinations such as STREAM. Retained observations give decoding, replay and later analysis a common starting point.",
        ],
        statement: deliveryStatements.capture,
        caption: "Order 42 is delayed. The observation stays available for the next question.",
        observation: {
          value: "One observation. Many uses.",
          detail:
            "The application chooses retention. Each consumer can resume from its own recorded progress through the retained history.",
        },
        reference: { label: "Stream declarations and delivery", to: "/reference/streams" },
      },
      {
        id: "context",
        label: "Preserve",
        title: "Keep the detail behind the status.",
        paragraphs: [
          "The delivery has instructions, a promised window and a carrier response. DOCUMENT is the planned home for that structured context, including source parts and revision history.",
          "Project the fields a computation needs while retaining the richer record for the person investigating the delay.",
        ],
        statement: deliveryStatements.context,
        caption: "The context remains useful beyond the first projection.",
        observation: {
          value: "A field leads back to its source",
          detail:
            "A missing field, a null value and a failed conversion carry different meaning; a projection should preserve that distinction.",
        },
        reference: {
          label: "Document representations and query projections",
          to: "/reference/documents",
        },
      },
      {
        id: "rules",
        label: "Remember",
        title: "Give each service its own rule.",
        paragraphs: [
          "Store the allowed delay under a service key in delivery_rules. KV fits this direct lookup: a small decision can depend on one exact piece of application state.",
          "In the connected workflow, the computation records the rule revision along with the events and document projections it used.",
        ],
        statement: deliveryStatements.rules,
        caption: "The scenario uses standard → 30 minutes; this declaration does not populate it.",
        observation: {
          value: "The rule has an identity and a revision",
          detail:
            "Application rule values are distinct from Transit's access grants and retention policies.",
        },
        reference: { label: "KV state, identities and revisions", to: "/reference/state" },
      },
      {
        id: "revisit",
        label: "Revisit",
        title: "Ask a new question of the same history.",
        paragraphs: [
          "A historical slice makes a bounded range of events available to relational queries. Examine it, join it to application data, or use it to understand how a delivery reached its current state.",
          "The target STREAM_SLICE grammar makes the read boundary explicit. CONSUME and COMMIT OFFSET separately own a consumer's progress.",
        ],
        statement: deliveryStatements.history,
        caption: "Proposed read-only grammar for a bounded historical slice.",
        observation: {
          value: "History becomes an input",
          detail:
            "The next chapter turns these observations, context and rules into application state and maintained answers.",
        },
        reference: { label: "Relational query inputs", to: "/reference/queries" },
      },
    ],
    next: { label: "Keep answers current", to: "/stories/keep-answers-current" },
  },
  answers: {
    route: "stories/keep-answers-current",
    title: "Keep answers current",
    headline: "Ask once.\nGive the answer a future.",
    description:
      "A delivery changes. The useful answer changes with it. DATAFLOW makes that relationship part of the application.",
    intent: "target",
    premise,
    preparation,
    steps: [
      {
        id: "shape",
        label: "Shape",
        title: "Give the application a useful view.",
        paragraphs: [
          "The connected target combines delivery_events, delivery_context and delivery_rules into queryable delivery state. Each source contributes something different: what happened, what it means, and what matters.",
          "For the small query below, deliveries holds the current delay and attention holds the derived answer. Declaring the Tables creates their shape; input projection and population are separate work.",
        ],
        statement: deliveryStatements.tables,
        caption: "Two explicit destinations: application state and the derived answer.",
        observation: {
          value: "Events + context + rules → useful state",
          detail:
            "Broader Stream, Document and KV inputs extend the managed Table computation model. Their adapters and grammar are part of the planned composition.",
        },
        reference: {
          label: "Data representations and computation lifetimes",
          to: "/reference/data-model",
        },
      },
      {
        id: "derive",
        label: "Derive",
        title: "Write the question once.",
        paragraphs: [
          "Which deliveries are more than thirty minutes late? Put that question in a DATAFLOW and name its output. The literal threshold keeps this example compact; the broader target can bind keyed rules and document fields as inputs.",
          "The declaration gives the computation an identity. Its inputs, output and intended lifetime become inspectable parts of the application.",
        ],
        statement: deliveryStatements.derive,
        caption: "A maintained answer has a definition and a destination.",
        observation: {
          value: "Order 42 needs attention",
          detail:
            "Illustrative result after the forty-five-minute delay has reached deliveries and a computation revision has completed.",
        },
        reference: {
          label: "Managed Table computations",
          to: "/reference/queries#managed-table-computations",
        },
      },
      {
        id: "activate",
        label: "Activate",
        title: "Let the answer keep up.",
        paragraphs: [
          "Authorize the computation, then activate it. Transit owns the work of advancing its answer; the client does not need to keep a console session open.",
          "The planned wider dataflow model adds richer inputs and incremental computation. The application still needs to see which revision completed, what is pending and whether a dependency is blocking progress.",
        ],
        statement: deliveryStatements.activate,
        caption: "Publish, authorize, activate, then inspect completion.",
        observation: {
          value: "A complete answer while the next one is underway",
          detail:
            "Activation confirms a control transition. Inspect the completed revision and its source position to understand the answer's freshness.",
        },
        reference: {
          label: "Dataflow controls, progress and recovery",
          to: "/reference/queries#managed-table-computations",
        },
      },
      {
        id: "explain",
        label: "Explain",
        title: "Follow an answer back to its cause.",
        paragraphs: [
          "Someone asks why order 42 appeared in the attention list. A retained revision identifies the computation and the source basis of that answer.",
          "As inputs broaden, that same principle connects a decision to its events, context and rule revision. The next step is to give the decision an explicit destination for work.",
        ],
        statement: deliveryStatements.revision,
        caption: "Inspect a completed revision's metadata without starting new work.",
        observation: {
          value: "An answer with a traceable basis",
          detail:
            "Keep source progress, result completion and external effects distinct. A readable result does not itself dispatch a follow-up.",
        },
        reference: {
          label: "Retained computation revisions",
          to: "/reference/queries#managed-table-computations",
        },
      },
    ],
    next: { label: "Turn changes into work", to: "/stories/turn-changes-into-work" },
  },
  work: {
    route: "stories/turn-changes-into-work",
    title: "Turn changes into work",
    headline: "An answer can do more\nthan fill a screen.",
    description:
      "Order 42 needs attention. Give that work a destination, a responsible worker and an outcome the application can inspect.",
    intent: "target",
    premise,
    preparation,
    steps: [
      {
        id: "route",
        label: "Route",
        title: "Give attention a destination.",
        paragraphs: [
          "A newly delayed delivery creates a follow-up. QUEUE holds the work until an eligible worker claims it. The statement below shows one deliberate enqueue for order 42.",
          "The connected target couples source progress, application state and outgoing work in one transaction. The application defines when a changed answer creates new work; rereading a result does not enqueue it again.",
        ],
        statement: deliveryStatements.queue,
        caption: "One follow-up, with a reason the worker can inspect.",
        observation: {
          value: "The decision and its next step stay connected",
          detail:
            "Dataflow output and outbox composition extend this handoff. External delivery still has its own recorded outcome.",
        },
        reference: { label: "Queues and transactional composition", to: "/reference/streams" },
      },
      {
        id: "claim",
        label: "Claim",
        title: "Share work without losing responsibility.",
        paragraphs: [
          "A worker claims the follow-up with a lease. Other workers can take other work. Delays, retry policies and key ordering give the application control over when and where work proceeds.",
          "The claim returns a receipt bound to that lease. Settlement uses the receipt so a stale worker cannot acknowledge work that has been reassigned.",
        ],
        statement: deliveryStatements.claim,
        caption: "A bounded responsibility to handle this follow-up.",
        observation: {
          value: "Available → claimed → settled",
          detail:
            "Lease expiry can make work eligible again. It does not prove that an external action never happened.",
        },
        reference: { label: "Queue claims and receipt-bound controls", to: "/reference/streams" },
      },
      {
        id: "settle",
        label: "Settle",
        title: "Record what the work accomplished.",
        paragraphs: [
          "An authorized worker contacts the carrier or opens a support case, records the outcome, then settles the queue claim. Station and connectors supply durable behavior and governed external effects above the data model.",
          "If a remote outcome is unknown, the connector's recovery policy must resolve it. Replaying history or reading a result never sends the request again.",
        ],
        statement: deliveryStatements.settle,
        caption: "The placeholder is the receipt from the claim, not a new work identity.",
        observation: {
          value: "Intent → authorized action → recorded outcome",
          detail:
            "Queue acknowledgement and external success are separate facts. Together they tell the application what remains unresolved.",
        },
        reference: { label: "Connectors and recorded effects", to: "/reference/connectors" },
      },
      {
        id: "learn",
        label: "Continue",
        title: "The outcome becomes the next fact.",
        paragraphs: [
          "The parcel arrives. Record the delivery event. When the projection advances and the next computation completes, order 42 can leave the attention list.",
          "The same history now explains the delay, the decision to act and the eventual delivery. A new question can start from that evidence.",
        ],
        statement: deliveryStatements.close,
        caption: "The story returns to the stream it began with.",
        observation: {
          value: "Keep the facts. Improve the next decision.",
          detail:
            "STREAM remembers. DOCUMENT adds context. KV supplies rules. TABLE and DATAFLOW keep answers useful. QUEUE carries the next work.",
        },
        reference: {
          label: "The shared data, computation and policy model",
          to: "/reference/data-model",
        },
      },
    ],
    next: { label: "Create your first dataset", to: "/stories/first-dataset" },
  },
} satisfies Record<string, Story>;
