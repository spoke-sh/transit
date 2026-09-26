defmodule TransitClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :transit_client_elixir,
      version: "0.2.0",
      elixir: "~> 1.18",
      deps: [{:transit_client, "== 0.2.0"}],
      package: [files: ["lib", "docs", "mix.exs", "README.md"]]
    ]
  end

  def application, do: [extra_applications: [:transit_client]]
end
