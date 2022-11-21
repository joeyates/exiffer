defmodule Mix.Tasks.Exiffer.Rewrite do
  @moduledoc """
  Rewrite image file metadata
  """

  use Mix.Task

  @shortdoc "Rewrites an image file"
  # @callback run([String.t(), String.t()]) :: {:ok}
  def run([input, output]) do
    {:ok} = Exiffer.rewrite(input, output)
  end
end
