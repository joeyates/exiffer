defmodule Exiffer.GPS do
  @enforce_keys ~w(longitude latitude altitude)a
  defstruct ~w(longitude latitude altitude)a

  def parse(gps) do
    case Regex.named_captures(
      ~r/(?<latitude>\-?\d{1,3}(\.\d+)?),(?<longitude>\-?\d{1,3}(\.\d+)?),(?<altitude>\d+(\.\d+)?)/,
      gps
    ) do
      %{"latitude" => latitude, "longitude" => longitude, "altitude" => altitude} ->
        {
          :ok,
          %__MODULE__{
            longitude: to_f(longitude),
            latitude: to_f(latitude),
            altitude: to_f(altitude)
          }
        }
      _ ->
        {:error, :unparseable}
    end
  end

  def parse!(gps) do
    {:ok, parsed} = parse(gps)
    parsed
  end

  defp to_f(s) do
    s
    |> Float.parse()
    |> elem(0)
  end
end
