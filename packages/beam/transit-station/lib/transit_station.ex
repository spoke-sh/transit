defmodule Transit.Station do
  @moduledoc """
  Owned native Station port. OTP schedules calls; shared Zig owns every durable
  protocol transition. JSON maps use string keys; integers retain BEAM precision.
  """
  defdelegate open(executable, config), to: :transit_station
  defdelegate close(server), to: :transit_station
  defdelegate request(server, request), to: :transit_station
  defdelegate next(server), to: :transit_station
  defdelegate apply(server, action), to: :transit_station
  defdelegate finish(server, failed), to: :transit_station
  defdelegate pending(server), to: :transit_station
  defdelegate call(server, frozen), to: :transit_station
  defdelegate prepare(server, kind, seed_file, document), to: :transit_station
  defdelegate arrow_cell(server, ipc, row, column), to: :transit_station
end
