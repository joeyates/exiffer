defmodule Exiffer.Degrees do
  @keys ~w(degrees minutes seconds)a
  @enforce_keys @keys
  defstruct @keys

  def from_float(f) do
    abs = abs(f)
    degrees = floor(abs)
    degrees_remainder = abs - degrees
    minutes = floor(60 * degrees_remainder)
    minutes_remainder = degrees_remainder - minutes / 60
    seconds = 3600 * minutes_remainder
    %__MODULE__{degrees: degrees, minutes: minutes, seconds: seconds}
  end

  def to_float(%__MODULE__{} = degrees) do
    degrees.degrees + degrees.minutes / 60.0 + degrees.minutes / 3600.0
  end

  def to_rational(%__MODULE__{} = degrees) do
    microseconds = floor(degrees.seconds * 1_000_000)
    [{degrees.degrees, 1}, {degrees.minutes, 1}, {microseconds, 1_000_000}]
  end

  def from_rational([rational_degrees, rational_minutes, rational_seconds]) do
    {degrees, 1} = rational_degrees
    {minutes, 1} = rational_minutes
    {microseconds, 1_000_000} = rational_seconds
    seconds = microseconds / 1_000_000
    %__MODULE__{degrees: degrees, minutes: minutes, seconds: seconds}
  end
end
