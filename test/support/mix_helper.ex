# This file borrows from https://github.com/phoenixframework/phoenix/blob/058ccf777747c77a5972e35a6e1a9d6b8c55d534/installer/test/mix_helper.exs

defmodule MixHelper do
  def copy_tmp(%{tmp_dir: tmp}, path) do
    if not File.regular?(path) do
      raise "copy_tmp/2: source file '#{path}' does not exist"
    end

    source_stat = File.stat!(path)
    filename = Path.basename(path)
    destination = Path.join(tmp, filename)
    File.copy!(path, destination)
    File.write_stat!(destination, source_stat)
    {:ok, destination}
  end

  def in_tmp_dir(%{tmp_dir: tmp_dir}, function) do
    try do
      File.cd!(tmp_dir, fn ->
        function.()
      end)
    after
      File.rm_rf!(tmp_dir)
    end
  end
end
