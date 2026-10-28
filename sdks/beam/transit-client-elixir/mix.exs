defmodule TransitClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :transit_client_elixir,
      version: "0.0.1",
      elixir: "~> 1.18",
      deps: [{:transit_client, "== 0.0.1"}],
      package: [files: ["lib", "docs", "mix.exs", "README.md"]]
    ]
  end

  def application, do: [extra_applications: [:transit_client]]
end
