defprotocol Exiffer.Serialize do
  @doc "Serialize image data"
  def write(data, io_device)
  def binary(data)
  def puts(data)
end

defimpl Exiffer.Serialize, for: List do
  def write(list, io_device) do
    Enum.each(list, fn item ->
      Exiffer.Serialize.write(item, io_device)
    end)
    :ok
  end

  def binary(list) do
    Enum.map(list, fn item ->
      Exiffer.Serialize.binary(item)
    end)
    |> Enum.join()
  end

  def puts(list) do
    Enum.each(list, fn item ->
      Exiffer.Serialize.puts(item)
    end)
  end
end
