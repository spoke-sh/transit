defmodule ElixirUnifiedAdapter do
  alias Transit.Client
  alias Transit.Station.Sdk.UnifiedQuery, as: Q

  def prepare(s, p, b) do
    plan = Q.convert(p)

    case elem(p, 2) do
      {:transit_unified_predicate_program, _} = original ->
        %Q.PredicateProgram{} = plan.predicate
        ^original = Q.native(plan.predicate)

      _ ->
        :ok
    end

    result(Q.prepare(Q.convert(s), plan, Q.convert(b)))
  end

  def decode(c, i, r), do: result(Q.decode_arrow(Q.convert(c), i, r))
  def open(c, i, r), do: result(Q.open(Client.convert(c), Client.convert(i), Q.convert(r)))
  def close(c), do: result(Q.close(c))
  def describe(c, s), do: result(Q.describe(c, Q.convert(s)))
  def inspect(c, s, n, sql, b), do: result(Q.inspect_sql(c, Q.convert(s), n, sql, Q.convert(b)))
  def next(c, n, b), do: result(Q.prepare_next(c, n, Q.convert(b)))
  def submit(c, p), do: result(Q.submit(c, Q.convert(p)))
  def observe(c, p), do: result(Q.observe(c, p))
  def status(c, n), do: result(Q.status(c, n))
  def page(c, n, p), do: result(Q.page(c, n, Q.convert(p)))
  defp result({:ok, %Client.AdmissionReceipt{position: p}}), do: {:ok, {:transit_admission, p}}
  defp result({:ok, value}), do: {:ok, Q.native(value)}
  defp result({:uncertain, prepared, error}), do: {:uncertain, Q.native(prepared), error(error)}
  defp result({:error, value}), do: {:error, error(value)}

  defp error(%Client.Error{} = e),
    do: {:transit_error, e.kind, e.phase, e.status || :undefined, e.code || :undefined}
end
