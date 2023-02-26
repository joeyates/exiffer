defprotocol Exiffer.Buffer do
  @doc "Manipulate buffers"
  def offset_buffer(buffer, offset)
  def seek(buffer, position)
  def consume(buffer, count)
  def skip(buffer, count)
  def random(buffer, read_position, count)
  def tell(buffer)
end
