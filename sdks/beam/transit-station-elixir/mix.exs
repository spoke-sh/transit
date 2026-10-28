defmodule TransitStationSdk.MixProject do
  use Mix.Project

  def project do
    [
      app: :transit_station_elixir,
      version: "0.0.1",
      elixir: "~> 1.18",
      deps: [{:transit_client_elixir, "== 0.0.1"}, {:transit_station_sdk, "== 0.0.1"}],
      package: [files: ["lib", "docs", "mix.exs", "README.md"]]
    ]
  end

  def application, do: [extra_applications: [:transit_client_elixir, :transit_station_sdk]]
end
