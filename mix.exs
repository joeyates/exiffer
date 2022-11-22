defmodule Exiffer.MixProject do
  use Mix.Project

  def project do
    [
      app: :exiffer,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:bakeware, ">= 0.0.0", runtime: false}
    ]
  end
end
