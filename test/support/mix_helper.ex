# This file borrows from https://github.com/phoenixframework/phoenix/blob/058ccf777747c77a5972e35a6e1a9d6b8c55d534/installer/test/mix_helper.exs

defmodule MixHelper do
  import ExUnit.Assertions

  def in_tmp_dir(%{tmp_dir: tmp_dir}, function) do
    try do
      File.cd!(tmp_dir, fn ->
        function.()
      end)
    after
      File.rm_rf!(tmp_dir)
    end
  end

  def in_tmp_project(%{tmp_dir: tmp_dir}, function) do
    try do
      File.cd!(tmp_dir, fn ->
        ~w(lib/my_app lib/my_app_web test/my_app test/my_app_web)
        |> Enum.each(&File.mkdir_p!/1)

        File.write!("mix.exs", mixfile_contents())

        Mix.Project.in_project(:my_app, tmp_dir, fn _module ->
          function.()
        end)
      end)
    after
      File.rm_rf!(tmp_dir)
    end
  end

  def assert_file(file) do
    assert File.regular?(file), "Expected #{file} to exist, but does not"
  end

  def assert_file(file, match) do
    cond do
      is_list(match) ->
        assert_file(file, &Enum.each(match, fn m -> assert &1 =~ m end))

      is_binary(match) or is_struct(match, Regex) ->
        assert_file(file, &assert(&1 =~ match))

      is_function(match, 1) ->
        assert_file(file)
        match.(File.read!(file))

      true ->
        raise inspect({file, match})
    end
  end

  def assert_dir(dir) do
    assert File.dir?(dir), "Expected directory '#{dir}' to exist, but does not"
  end

  defp mixfile_contents do
    """
    defmodule MyApp.MixProject do
      use Mix.Project

      def project do
        [app: :my_app, version: "0.1.0"]
      end
    end
    """
  end
end
