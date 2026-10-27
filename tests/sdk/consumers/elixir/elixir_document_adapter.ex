defmodule ElixirDocumentAdapter do
  @behaviour Transit.Station.Sdk.Codec
  @behaviour Transit.Station.Sdk.Handler
  alias Transit.Client
  alias Transit.Station.Sdk.{Runner, ServiceConfig, Activation, Incoming, Committed}
  alias Transit.Station.Sdk.Document
  alias Document.{Dot, Change, Prepared, Reference}
  @max 18_446_744_073_709_551_615
  def type_id, do: "test.document-control"
  def version, do: 1
  def max_encoded_bytes, do: 243
  def encode(bytes), do: {:ok, bytes}
  def decode(bytes), do: {:ok, bytes}

  def golden(fixtures, cfg) do
    for entry <- fixtures["changes"] do
      bytes = Base.decode16!(entry["wire_hex"], case: :mixed)
      {:ok, change} = Document.decode(bytes)
      {:ok, %Prepared{bytes: ^bytes}} = Document.prepare(change)

      for size <- [0, 1, byte_size(bytes) - 1],
          do: {:error, _} = Document.decode(binary_part(bytes, 0, size))
    end

    reference = Base.decode16!(fixtures["reference_hex"], case: :mixed)

    {:ok, %Reference{document: @max, revision: @max} = ref} =
      Document.decode_reference(72, reference)

    {:ok, ^reference} = Document.encode_reference(ref)
    root = %Dot{}

    change = %Change{
      document: @max,
      replica: @max,
      first: 1,
      operations: [
        {:assign, root, "value", [], {:signed, -9_223_372_036_854_775_808}},
        {:assign, root, "body", [], :text},
        {:insert, %Dot{counter: 2, replica: @max}, root, {:character, 0x1F642}}
      ]
    }

    expected = Base.decode16!(hd(cfg["changes"]), case: :mixed)
    {:ok, %Prepared{bytes: ^expected}} = Document.prepare(change)

    {:error, _} =
      Document.prepare(%{
        change
        | operations: [{:assign, root, "x", [], {:string, <<0xED, 0xA0, 0x80>>}}]
      })

    :ok
  end

  def prepare(cfg),
    do:
      Enum.map(cfg["changes"], fn bytes ->
        {:ok, change} = Document.decode(Base.decode16!(bytes, case: :mixed))
        {:ok, prepared} = Document.prepare(change)
        prepared
      end)

  def open(cfg, shared, changes) do
    {:ok, client} = Client.config(cfg["url"], :native_v1, %{timeout_ms: 15_000})

    service = %ServiceConfig{
      client: client,
      activation: %Activation{
        process: %Client.ProcessRef{realm: 72, pid: cfg["pid"]},
        generation: cfg["generation"],
        credential: %Client.Credential{
          realm: 72,
          principal: cfg["principal"],
          seed_file: cfg["seed_file"]
        }
      }
    }

    Runner.open(service, __MODULE__, {shared, changes}, __MODULE__,
      failure_policy: :stop,
      recovery: :fresh_ownership
    )
  end

  def initialize(turn, context) do
    {:ok, :ok} = Document.create(Document.owner(turn, @max), 1)
    {:ok, context}
  end

  def handle_message(turn, %Incoming{kind: :cast, value: command}, {shared, changes} = context) do
    owner = Document.owner(turn, @max)
    :beam_document_controller.put(shared, :escaped, owner)

    phase =
      case command do
        "initialize" ->
          :null

        "checkpoint" ->
          {:ok, result} = Document.checkpoint(owner, 90)
          Atom.to_string(result.phase)

        "window" ->
          {:ok, :ok} = Document.merge_window(owner, 2)
          :null

        "retire" ->
          {:ok, :ok} = Document.retire(owner)
          :null

        value when value in ["0", "1"] ->
          index = String.to_integer(value)
          {:ok, result} = Document.stage(owner, index + 1, Enum.at(changes, index), 256)
          Atom.to_string(result.phase)
      end

    :beam_document_controller.put(shared, :phase, phase)
    {:ok, context}
  end

  def next(runner), do: Runner.next(runner)
  def close(runner), do: Runner.close(runner)
  def expired(owner), do: Document.merge_window(owner, 0)
  defp resource(cfg), do: %Client.ResourceRef{realm: 72, resource: cfg["resource"]}
  defp mapped({:ok, value}, fun), do: {:ok, fun.(value)}
  defp mapped(error, _), do: error

  def describe(runner, cfg),
    do:
      mapped(
        Document.describe(runner, resource(cfg), @max),
        &Map.take(&1, [:reference, :floor, :merge_window, :retired])
      )

  defp assignments(values), do: Enum.map(values, &{&1.id, &1.value})

  def path(runner, reference, names),
    do:
      mapped(Document.path(runner, reference, names), fn value ->
        %{status: value.field.status, assignments: assignments(value.field.assignments)}
      end)

  def sequence(runner, reference),
    do:
      mapped(Document.sequence(runner, reference, %Dot{counter: 2, replica: @max}), fn value ->
        %{
          items: Enum.map(value.items, &{&1.id, assignments(&1.field.assignments)}),
          next: value.next || :undefined
        }
      end)

  def accepted(runner, reference) do
    with {:ok, change} <- Document.accepted_change(runner, reference),
         {:ok, prepared} <- Document.prepare(change),
         do: {:ok, prepared.bytes}
  end

  def resynchronize(runner, cfg),
    do:
      mapped(Document.resynchronize(runner, resource(cfg), @max, @max), fn value ->
        3 = value.reference.revision
        Map.take(value, [:previous_counter, :clock])
      end)

  def revision(%Reference{revision: revision}), do: revision
  def view(%Client.Error{} = error), do: Map.take(error, [:kind, :code, :phase])
  def event(%Committed{}), do: :committed
  def event(value), do: value
end
