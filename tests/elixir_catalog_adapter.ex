defmodule ElixirCatalogAdapter do
  alias Transit.Client
  alias Transit.Station.Sdk.Catalog, as: C
  def open(c, i, r, service), do: result(C.open(Client.convert(c), Client.convert(i), C.convert(r), service))
  def open(c, i, r), do: result(C.open(Client.convert(c), Client.convert(i), C.convert(r)))
  def close(c), do: result(C.close(c))
  def capabilities(c), do: result(C.capabilities(c))
  def describe(c), do: result(C.describe(c))
  def lookup(c, name), do: result(C.lookup(c, name))
  def definition(c, object, revision), do: result(C.definition(c, object, revision))
  def list(c), do: result(C.list(c))
  def list(c, cursor), do: result(C.list(c, C.convert(cursor)))

  def compile_sql(c, sql, identity, object),
    do: result(C.compile_sql(c, sql, C.convert(identity), C.convert(object)))

  def prepare(c, name, identity, operation),
    do: result(C.prepare(c, name, C.convert(identity), C.convert(operation)))

  def load(c, saved), do: result(C.load(c, C.convert(saved)))
  def forget(c, reference), do: result(C.forget(c, C.convert(reference)))
  def next(c, reference), do: result(C.next(c, C.convert(reference)))
  def status(c, reference), do: result(C.status(c, C.convert(reference)))
  def prepare_resume(c, reference), do: result(C.prepare_resume(c, C.convert(reference)))

  def prepare_control(c, reference, control),
    do: result(C.prepare_control(c, C.convert(reference), control))

  def prepare_initialize(c, configuration),
    do: result(C.prepare_initialize(c, C.convert(configuration)))

  def prepare_dependency(c, dependency, present),
    do: result(C.prepare_dependency(c, C.convert(dependency), present))

  def submit(c, prepared), do: result(C.submit(c, C.convert(prepared)))
  def observe(c, prepared, input), do: result(C.observe(c, C.convert(prepared), input))

  def observe(c, prepared, input, wait),
    do: result(C.observe(c, C.convert(prepared), input, wait))

  def input_disposition(c, prepared, input),
    do: result(C.input_disposition(c, C.convert(prepared), input))

  def progress(c, reference, prepared, input, wait),
    do: result(C.progress(c, C.convert(reference), C.convert(prepared), input, wait))

  def basis(metadata), do: C.basis(C.convert(metadata)) |> C.native()
  defp result({:ok, value}), do: {:ok, C.native(value)}
  defp result({:uncertain, prepared, error}), do: {:uncertain, C.native(prepared), error(error)}
  defp result({:error, value}), do: {:error, error(value)}
  defp result({:error, value, evidence}), do: {:error, error(value), evidence}

  defp error(%Client.Error{} = e),
    do:
      {:transit_error, e.kind, e.phase, e.status || :undefined, e.code || :undefined,
       e.diagnostic || :undefined, e.diagnostic_invalid}
end
