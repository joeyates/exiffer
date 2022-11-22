defmodule Exiffer.CLI do
  use Bakeware.Script

  @impl Bakeware.Script
  def main([]) do
    IO.puts(:stderr, "Please supply a command")
    list_top_level_commands()
    1
  end

  def main(["help" | _args]) do
    list_top_level_commands()
    0
  end

  def main(["read", filename]) do
    Exiffer.CLI.Read.run(filename)
    0
  end

  def main(["rewrite", input, output]) do
    Exiffer.CLI.Rewrite.run(input, output)
    0
  end

  def main([command | _args]) do
    IO.puts(:stderr, "Unknown command: '#{command}'")
    1
  end

  defp list_top_level_commands do
    IO.puts("exiffer read|rewrite")
  end
end
