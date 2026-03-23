defmodule Exiffer.MixProject do
  use Mix.Project

  @app :exiffer

  def project() do
    [
      app: @app,
      version: "0.6.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Read and update image metadata",
      package: package(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    [extra_applications: [:logger]]
  end

  defp deps() do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:green, "~> 0.1.11", only: :dev},
      {:jason, ">= 0.0.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package() do
    %{
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/joeyates/exiffer"
      },
      maintainers: ["Joe Yates"]
    }
  end

  defp aliases() do
    [
      "check.format": "format --check-formatted",
      check: [
        "check.format",
        "cmd mix test"
      ]
    ]
  end
end
