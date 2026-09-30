defmodule ElixirCatalogAdapter do
  alias Transit.Client
  alias Transit.Station.Sdk.Catalog, as: C
  def open(c, i, r), do: result(C.open(Client.convert(c), Client.convert(i), C.convert(r)))
  def close(c), do: result(C.close(c))
  def capabilities(c), do: result(C.capabilities(c))
  def describe(c), do: result(C.describe(c))
  def lookup(c, name), do: result(C.lookup(c, name))
  def definition(c, object, revision), do: result(C.definition(c, object, revision))
  def list(c), do: result(C.list(c))
  def list(c, :undefined), do: result(C.list(c))
  def list(c, cursor), do: result(C.list(c, C.convert(cursor)))

  def compile_sql(c, sql, operation, object, table),
    do: result(C.compile_sql(c, sql, operation, object, table))

  def prepare_initialize(c, configuration),
    do: result(C.prepare_initialize(c, C.convert(configuration)))

  def prepare_create(c, request), do: result(C.prepare_create(c, C.convert(request)))
  def prepare_policy(c, change), do: result(C.prepare_policy(c, C.convert(change)))
  def submit(c, prepared), do: result(C.submit(c, C.convert(prepared)))
  def observe(c, prepared, input), do: result(C.observe(c, C.convert(prepared), input))

  def input_disposition(c, prepared, input),
    do: result(C.input_disposition(c, C.convert(prepared), input))

  def status(c, original), do: result(C.status(c, C.convert(original)))
  defp result({:ok, value}), do: {:ok, C.native(value)}
  defp result({:uncertain, prepared, error}), do: {:uncertain, C.native(prepared), error(error)}
  defp result({:error, value}), do: {:error, error(value)}
  defp result({:error, value, evidence}), do: {:error, error(value), evidence}

  defp error(%Client.Error{} = e),
    do: {:transit_error, e.kind, e.phase, e.status || :undefined, e.code || :undefined}
end
