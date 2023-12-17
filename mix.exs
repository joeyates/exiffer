defmodule Exiffer.MixProject do
  use Mix.Project

  @app :exiffer

  def project do
    [
      app: @app,
      version: "0.1.8",
      elixir: "~> 1.14",
      description: "Read and update image metadata",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() != :test,
      releases: [{@app, release()}]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    application = [
      extra_applications: [:logger]
    ]

    exiffer_build_cli = System.get_env("EXIFFER_BUILD_CLI")
    if exiffer_build_cli do
      [{:mod, {Exiffer.CLI, []}} | application]
    else
      application
    end
  end

  defp deps do
    [
      {:bakeware, ">= 0.0.0", runtime: false, optional: true},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:helpful_options, ">= 0.3.3"},
      {:jason, ">= 0.0.0"}
    ]
  end

  defp release do
    [
      overwrite: true,
      cookie: "#{@app}_cookie",
      quiet: true,
      steps: [:assemble, &Bakeware.assemble/1],
      strip_beams: Mix.env() == :prod
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/joeyates/exiffer"
      },
      maintainers: ["Joe Yates"]
    }
  end
end
