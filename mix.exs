defmodule Hyperex.MixProject do
  use Mix.Project

  def project do
    [
      app: :hyperex,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [mod: {Hyperex, []},
    extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~>1.4"},
      {:plug_cowboy, "~> 1.0"},
    ]
  end
end
