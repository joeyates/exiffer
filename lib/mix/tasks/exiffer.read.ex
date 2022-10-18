defmodule Mix.Tasks.Exiffer.Read do
  @moduledoc """
  Print image file metadata
  """

  use Mix.Task

  @shortdoc "Prints image file metadata"
  @callback run([String.t()]) :: {:ok}
  def run(args) do
    {:ok} = Exiffer.dump(args)
  end
end
