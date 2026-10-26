defmodule ElixirCatalogAdapter do
  alias Transit.Client
  alias Transit.Station.Sdk.Catalog, as: C

  def open(c, i, r, service),
    do: result(C.open(Client.convert(c), Client.convert(i), C.convert(r), service))

  def open(c, i, r), do: result(C.open(Client.convert(c), Client.convert(i), C.convert(r)))
  def close(c), do: result(C.close(c))
  def capabilities(c), do: result(C.capabilities(c))
  def describe(c), do: result(C.describe(c))
  def namespace(c, n), do: result(C.namespace(c, n))
  def namespaces(c), do: result(C.namespaces(c))
  def namespaces(c, cursor), do: result(C.namespaces(c, C.convert(cursor)))
  def tables(c), do: result(C.tables(c))
  def tables(c, n, cursor), do: result(C.tables(c, n, C.convert(cursor)))
  def lookup(c, name), do: result(C.lookup(c, name))
  def lookup(c, name, n), do: result(C.lookup(c, name, n))

  def compile_sql(c, sql, identity, object),
    do: result(C.compile_sql(c, sql, C.convert(identity), C.convert(object)))

  def prepare(c, name, identity, operation),
    do: result(C.prepare(c, name, C.convert(identity), C.convert(operation)))

  def load(c, saved), do: result(C.load(c, C.convert(saved)))
  def forget(c, intent), do: result(C.forget(c, C.convert(intent)))
  def preview(c, intent), do: result(C.preview(c, C.convert(intent)))
  def stage(c, intent), do: result(C.stage(c, C.convert(intent)))
  def admit(c, original), do: result(C.admit(c, C.convert(original)))
  def inspect(c, original), do: result(C.inspect(c, C.convert(original)))
  def execute(c, original, steps), do: result(C.execute(c, C.convert(original), steps))
  def cancel(c, original), do: result(C.cancel(c, C.convert(original)))

  def prepare_snapshot(c, metadata, operation),
    do: result(C.prepare_snapshot(c, C.convert(metadata), operation))

  def acquire_snapshot(c, acquisition), do: result(C.acquire_snapshot(c, C.convert(acquisition)))
  def snapshot_status(c, owner), do: result(C.snapshot_status(c, C.convert(owner)))
  def snapshot_metadata(c, snapshot), do: result(C.snapshot_metadata(c, C.convert(snapshot)))
  def release_snapshot(c, snapshot), do: result(C.release_snapshot(c, C.convert(snapshot)))
  def basis(metadata), do: C.basis(C.convert(metadata)) |> C.native()
  def save(value), do: result(C.save(C.convert(value)))
  def restore(kind, data), do: result(C.restore(kind, data))
  defp result({:ok, value}), do: {:ok, C.native(value)}
  defp result({:uncertain, original, error}), do: {:uncertain, C.native(original), error(error)}
  defp result({:error, value}), do: {:error, error(value)}
  defp result({:error, value, evidence}), do: {:error, error(value), evidence}

  defp error(%Client.Error{} = e),
    do:
      {:transit_error, e.kind, e.phase, e.status || :undefined, e.code || :undefined,
       e.diagnostic || :undefined, e.diagnostic_invalid}
end
