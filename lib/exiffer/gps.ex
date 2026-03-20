defmodule Exiffer.GPS do
  @keys ~w(longitude latitude altitude)a
  @enforce_keys @keys
  defstruct @keys

  alias Exiffer.Degrees
  alias Exiffer.JPEG.Entry
  alias Exiffer.JPEG.IFD

  def from_entry(%Entry{type: :gps_info} = entry) do
    with {:ok, latitude_ref} <- value(entry, :gps_latitude_ref),
         {:ok, [lat1, lat2, lat3]} <- value(entry, :gps_latitude),
         {:ok, longitude_ref} <- value(entry, :gps_longitude_ref),
         {:ok, [lon1, lon2, lon3]} <- value(entry, :gps_longitude),
         {:ok, _altitude_ref} <- value(entry, :gps_altitude_ref),
         {:ok, {altitude, 1}} <- value(entry, :gps_altitude) do
      latitude = [lat1, lat2, lat3] |> Degrees.from_rational() |> Degrees.to_float()
      longitude = [lon1, lon2, lon3] |> Degrees.from_rational() |> Degrees.to_float()
      latitude = if latitude_ref == "N", do: latitude, else: -latitude
      longitude = if longitude_ref == "E", do: longitude, else: -longitude

      {
        :ok,
        %__MODULE__{
          latitude: latitude,
          longitude: longitude,
          altitude: altitude
        }
      }
    end
  end

  def to_entry(gps) do
    latitude_ref = if gps.latitude >= 0, do: "N", else: "S"
    longitude_ref = if gps.longitude >= 0, do: "E", else: "W"
    latitude = gps.latitude |> Degrees.from_float() |> Degrees.to_rational()
    longitude = gps.longitude |> Degrees.from_float() |> Degrees.to_rational()
    altitude = floor(gps.altitude)

    value = %IFD{
      entries: [
        Entry.new_by_type(:gps_latitude_ref, latitude_ref),
        Entry.new_by_type(:gps_latitude, latitude),
        Entry.new_by_type(:gps_longitude_ref, longitude_ref),
        Entry.new_by_type(:gps_longitude, longitude),
        Entry.new_by_type(:gps_altitude_ref, 0),
        Entry.new_by_type(:gps_altitude, {altitude, 1})
      ]
    }

    Entry.new_by_type(:gps_info, value)
  end

  defp value(entry, type) do
    case Enum.find(entry.value.entries, &(&1.type == type)) do
      nil ->
        {:error, "Field #{type} not found"}

      field ->
        {:ok, field.value}
    end
  end
end
