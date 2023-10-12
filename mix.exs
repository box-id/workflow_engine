defmodule WorkflowEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :workflow_engine,
      version: "0.4.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ok, "~> 2.3"},
      {:jason, "~> 1.2"},
      {:ex_minimatch, github: "box-id/ex_minimatch", ref: "ee65d07"},
      # Our fork of JsonLogic is used at runtime and during tests, but in production it has to be
      # provided by upstream application to avoid version conflicts
      {:json_logic, github: "box-id/json_logic_elixir", tag: "1.0.0", only: [:dev, :test]},
      # Same for BXDK. We could use `optional: true`, but since git tags are exact, this is not
      # a suitable way of expressing a "minimum version" requirement.
      {:bxdk, github: "box-id/bxdk", tag: "0.21.0", only: [:dev, :test]},
      {:mix_test_watch, "~> 1.0", only: :dev, runtime: false},
      {:mox, "~> 1.0", only: :test},
      {:bypass, "~> 2.1", only: :test}
    ]
  end
end
