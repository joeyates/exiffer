defmodule Exiffer.MixProject do
  use Mix.Project

  @app :exiffer

  def project do
    [
      app: @app,
      version: "0.1.0",
      elixir: "~> 1.14",
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
    if Mix.env() == :prod do
      [{:mod, {Exiffer.CLI, []}} | application]
    else
      application
    end
  end

  defp deps do
    [
      {:bakeware, ">= 0.0.0", runtime: false}
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
end
