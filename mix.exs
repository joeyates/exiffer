defmodule Exiffer.MixProject do
  use Mix.Project

  @app :exiffer

  def project() do
    [
      app: @app,
      version: "0.2.5",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Read and update image metadata",
      package: package(),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      releases: [{@app, release()}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application() do
    if Mix.env() == :test do
      [extra_applications: [:logger]]
    else
      [
        mod: {Exiffer.CLI, []},
        extra_applications: [:logger]
      ]
    end
  end

  defp deps() do
    [
      {:burrito, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:green, "~> 0.1.11", only: :dev},
      {:helpful_options, ">= 0.3.3"},
      {:jason, ">= 0.0.0"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp release() do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      quiet: true,
      strip_beams: Mix.env() == :prod,
      steps: [:assemble, &Burrito.wrap/1],
      burrito: [
        targets: [
          linux: [os: :linux, cpu: :x86_64]
        ]
      ]
    ]
  end

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
