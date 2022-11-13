defmodule Mix.Tasks.Exiffer.Read do
  @moduledoc """
  Print image file metadata
  """

  use Mix.Task

  @shortdoc "Prints image file metadata"
  @callback run([String.t()]) :: {:ok}
  def run(args) do
    [filename] = args
    {:ok} = Exiffer.dump(filename)
  end
end
