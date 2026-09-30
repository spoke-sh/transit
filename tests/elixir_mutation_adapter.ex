defmodule ElixirMutationAdapter do
  alias Transit.Client
  alias Transit.Station.Sdk.Mutations, as: M
  def open(c, i, r), do: result(M.open(Client.convert(c), Client.convert(i), M.convert(r)))
  def close(c), do: result(M.close(c))
  def describe(c), do: result(M.describe(c))
  def compile_sql(c, n, sql, namespace), do: result(M.compile_sql(c, n, sql, namespace))
  def prepare_next(c, compiled), do: result(M.prepare_next(c, M.convert(compiled)))

  def prepare_control(c, control, reference),
    do: result(M.prepare_control(c, control, M.convert(reference)))

  def submit(c, prepared), do: result(M.submit(c, M.convert(prepared)))
  def observe(c, prepared, input), do: result(M.observe(c, M.convert(prepared), input))
  def rejection(c, prepared, input), do: result(M.rejection(c, M.convert(prepared), input))
  def status(c, reference), do: result(M.status(c, M.convert(reference)))
  defp result({:ok, value}), do: {:ok, M.native(value)}
  defp result({:uncertain, prepared, error}), do: {:uncertain, M.native(prepared), error(error)}
  defp result({:error, value}), do: {:error, error(value)}

  defp error(%Client.Error{} = e),
    do: {:transit_error, e.kind, e.phase, e.status || :undefined, e.code || :undefined}
end
