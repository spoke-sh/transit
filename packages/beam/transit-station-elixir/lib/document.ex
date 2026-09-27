defmodule Transit.Station.Sdk.Document.Dot do
  @derive {Inspect, only: []}
  defstruct counter: 0, replica: 0
end

defmodule Transit.Station.Sdk.Document.Change do
  @enforce_keys [:document, :replica, :first]
  @derive {Inspect, only: []}
  defstruct [:document, :replica, :first, epoch: 1, type_revision: 1, previous: 0, operations: []]
end

defmodule Transit.Station.Sdk.Document.Prepared do
  @enforce_keys [:document, :bytes]
  @derive {Inspect, only: []}
  defstruct [:document, :bytes]
end

defmodule Transit.Station.Sdk.Document.Reference do
  @enforce_keys [:resource, :document, :epoch, :type_revision, :revision]
  @derive {Inspect, only: []}
  defstruct [:resource, :document, :epoch, :type_revision, :revision]
end

defmodule Transit.Station.Sdk.Document.Assignment do
  @enforce_keys [:id, :value]
  @derive {Inspect, only: []}
  defstruct [:id, :value]
end

defmodule Transit.Station.Sdk.Document.Field do
  @enforce_keys [:status]
  @derive {Inspect, only: []}
  defstruct [:status, assignments: []]
end

defmodule Transit.Station.Sdk.Document.Description do
  @enforce_keys [
    :reference,
    :source_revision,
    :floor,
    :merge_window,
    :active_job,
    :retired,
    :change_format
  ]
  @derive {Inspect, only: []}
  defstruct [
    :reference,
    :source_revision,
    :floor,
    :merge_window,
    :active_job,
    :retired,
    :change_format
  ]
end

defmodule Transit.Station.Sdk.Document.PathValue do
  @enforce_keys [:reference, :source_revision, :field]
  @derive {Inspect, only: []}
  defstruct [:reference, :source_revision, :field]
end

defmodule Transit.Station.Sdk.Document.Item do
  @enforce_keys [:id, :field]
  @derive {Inspect, only: []}
  defstruct [:id, :field]
end

defmodule Transit.Station.Sdk.Document.Page do
  @enforce_keys [:reference, :source_revision]
  @derive {Inspect, only: []}
  defstruct [:reference, :source_revision, items: [], next: nil]
end

defmodule Transit.Station.Sdk.Document.Resynchronization do
  @enforce_keys [:reference, :floor, :replica, :previous_counter, :clock]
  @derive {Inspect, only: []}
  defstruct [:reference, :floor, :replica, :previous_counter, :clock]
end

defmodule Transit.Station.Sdk.Document.Progress do
  @enforce_keys [:phase]
  @derive {Inspect, only: []}
  defstruct [:phase, revision: nil]
end

defmodule Transit.Station.Sdk.Document.Owner do
  @enforce_keys [:turn, :document]
  @derive {Inspect, only: [:document]}
  defstruct [:turn, :document]
end

defmodule Transit.Station.Sdk.Document do
  alias Transit.Client
  alias Transit.Station.Sdk.{Runner, Turn, Value}
  alias __MODULE__.Owner

  alias __MODULE__.{
    Dot,
    Change,
    Prepared,
    Reference,
    Assignment,
    Field,
    Description,
    PathValue,
    Item,
    Page,
    Resynchronization,
    Progress
  }

  def owner(%Turn{} = turn, document), do: %Owner{turn: turn, document: document}

  def prepare(%Change{} = change, native_host \\ nil) do
    with :ok <- Runner.compatible(),
         do: result(:transit_document.prepare(native(change), Value.optional(native_host)))
  end

  def decode(bytes, native_host \\ nil) do
    with :ok <- Runner.compatible(),
         do: result(:transit_document.decode(bytes, Value.optional(native_host)))
  end

  def encode_reference(%Reference{} = reference, native_host \\ nil) do
    with :ok <- Runner.compatible(),
         do:
           Client.convert(
             :transit_document.encode_reference(native(reference), Value.optional(native_host))
           )
  end

  def decode_reference(realm, bytes, native_host \\ nil) do
    with :ok <- Runner.compatible(),
         do: result(:transit_document.decode_reference(realm, bytes, Value.optional(native_host)))
  end

  def create(
        %Owner{turn: %Turn{native: turn}, document: document},
        type_revision,
        limits \\ [record_bytes: 4096, staging_bytes: 8192, staging_records: 2]
      ),
      do: result(:transit_document.create(turn, document, type_revision, Map.new(limits)))

  def stage(
        %Owner{turn: %Turn{native: turn}, document: document},
        job,
        %Prepared{} = change,
        node_limit \\ 512
      ),
      do: result(:transit_document.stage(turn, document, job, native(change), node_limit))

  def checkpoint(%Owner{turn: %Turn{native: turn}, document: document}, job),
    do: result(:transit_document.checkpoint(turn, document, job))

  def merge_window(%Owner{turn: %Turn{native: turn}, document: document}, revisions),
    do: result(:transit_document.merge_window(turn, document, revisions))

  def reject(%Owner{turn: %Turn{native: turn}, document: document}, job, checkpoint \\ false),
    do: result(:transit_document.reject(turn, document, job, checkpoint))

  def collect(%Owner{turn: %Turn{native: turn}, document: document}, job, options \\ []),
    do:
      result(
        :transit_document.collect(
          turn,
          document,
          job,
          Keyword.get(options, :checkpoint, false),
          Keyword.get(options, :retired, false)
        )
      )

  def retire(%Owner{turn: %Turn{native: turn}, document: document}),
    do: result(:transit_document.retire(turn, document))

  def describe(runner, resource, document),
    do: result(:transit_document.describe(runner, Client.native(resource), document))

  def path(runner, %Reference{} = reference, names),
    do: result(:transit_document.path(runner, native(reference), names))

  def sequence(runner, %Reference{} = reference, %Dot{} = object, cursor \\ nil),
    do:
      result(
        :transit_document.sequence(
          runner,
          native(reference),
          native(object),
          Value.optional(cursor)
        )
      )

  def resynchronize(runner, resource, document, replica),
    do:
      result(:transit_document.resynchronize(runner, Client.native(resource), document, replica))

  def accepted_change(runner, %Reference{} = reference),
    do: result(:transit_document.accepted_change(runner, native(reference)))

  def observed(%Field{assignments: assignments}), do: Enum.map(assignments, & &1.id)
  defp result({:ok, value}), do: {:ok, convert(value)}
  defp result(error), do: Client.convert(error)

  @doc false
  def native(%Dot{} = value),
    do: {:transit_document_dot, native(value.counter), native(value.replica)}

  def native(%Change{} = value),
    do:
      {:transit_document_change, native(value.document), native(value.epoch),
       native(value.type_revision), native(value.replica), native(value.previous),
       native(value.first), native(value.operations)}

  def native(%Prepared{} = value),
    do: {:transit_document_prepared, native(value.document), native(value.bytes)}

  def native(%Reference{} = value),
    do:
      {:transit_document_reference, native(value.resource), native(value.document),
       native(value.epoch), native(value.type_revision), native(value.revision)}

  def native(%Assignment{} = value),
    do: {:transit_document_assignment, native(value.id), native(value.value)}

  def native(%Field{} = value),
    do: {:transit_document_field, native(value.status), native(value.assignments)}

  def native(%Description{} = value),
    do:
      {:transit_document_description, native(value.reference), native(value.source_revision),
       native(value.floor), native(value.merge_window), native(value.active_job),
       native(value.retired), native(value.change_format)}

  def native(%PathValue{} = value),
    do:
      {:transit_document_path, native(value.reference), native(value.source_revision),
       native(value.field)}

  def native(%Item{} = value), do: {:transit_document_item, native(value.id), native(value.field)}

  def native(%Page{} = value),
    do:
      {:transit_document_page, native(value.reference), native(value.source_revision),
       native(value.items), native(value.next)}

  def native(%Resynchronization{} = value),
    do:
      {:transit_document_resynchronization, native(value.reference), native(value.floor),
       native(value.replica), native(value.previous_counter), native(value.clock)}

  def native(%Progress{} = value),
    do: {:transit_document_progress, native(value.phase), native(value.revision)}

  def native(%Client.ResourceRef{} = value), do: Client.native(value)
  def native(nil), do: :undefined
  def native(values) when is_list(values), do: Enum.map(values, &native/1)

  def native(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.map(&native/1) |> List.to_tuple()

  def native(value), do: value

  @doc false
  def convert({:transit_document_dot, counter, replica}),
    do: %Dot{counter: convert(counter), replica: convert(replica)}

  def convert(
        {:transit_document_change, document, epoch, type_revision, replica, previous, first,
         operations}
      ),
      do: %Change{
        document: convert(document),
        epoch: convert(epoch),
        type_revision: convert(type_revision),
        replica: convert(replica),
        previous: convert(previous),
        first: convert(first),
        operations: convert(operations)
      }

  def convert({:transit_document_prepared, document, bytes}),
    do: %Prepared{document: convert(document), bytes: convert(bytes)}

  def convert({:transit_document_reference, resource, document, epoch, type_revision, revision}),
    do: %Reference{
      resource: convert(resource),
      document: convert(document),
      epoch: convert(epoch),
      type_revision: convert(type_revision),
      revision: convert(revision)
    }

  def convert({:transit_document_assignment, id, value}),
    do: %Assignment{id: convert(id), value: convert(value)}

  def convert({:transit_document_field, status, assignments}),
    do: %Field{status: convert(status), assignments: convert(assignments)}

  def convert(
        {:transit_document_description, reference, source_revision, floor, merge_window,
         active_job, retired, change_format}
      ),
      do: %Description{
        reference: convert(reference),
        source_revision: convert(source_revision),
        floor: convert(floor),
        merge_window: convert(merge_window),
        active_job: convert(active_job),
        retired: convert(retired),
        change_format: convert(change_format)
      }

  def convert({:transit_document_path, reference, source_revision, field}),
    do: %PathValue{
      reference: convert(reference),
      source_revision: convert(source_revision),
      field: convert(field)
    }

  def convert({:transit_document_item, id, field}),
    do: %Item{id: convert(id), field: convert(field)}

  def convert({:transit_document_page, reference, source_revision, items, next}),
    do: %Page{
      reference: convert(reference),
      source_revision: convert(source_revision),
      items: convert(items),
      next: convert(next)
    }

  def convert(
        {:transit_document_resynchronization, reference, floor, replica, previous_counter, clock}
      ),
      do: %Resynchronization{
        reference: convert(reference),
        floor: convert(floor),
        replica: convert(replica),
        previous_counter: convert(previous_counter),
        clock: convert(clock)
      }

  def convert({:transit_document_progress, phase, revision}),
    do: %Progress{phase: convert(phase), revision: convert(revision)}

  def convert({:transit_resource, _, _} = value), do: Client.convert(value)
  def convert(:undefined), do: nil
  def convert(values) when is_list(values), do: Enum.map(values, &convert/1)

  def convert(value) when is_tuple(value),
    do: value |> Tuple.to_list() |> Enum.map(&convert/1) |> List.to_tuple()

  def convert(value), do: value
end
