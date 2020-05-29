defmodule EctoExtractMigrations.Common do
  import NimbleParsec

  def whitespace do
    ascii_char([32, ?\t, ?\n]) |> times(min: 1)
  end

  def identifier do
    # utf8_string([], min: 1)
    utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1)
    # utf8_string([{:not, ?.}], min: 1)
  end

  def quoted_identifier do
    ignore(ascii_char([?"]))
    |> concat(identifier())
    |> ignore(ascii_char([?"]))
  end

  def name do
    choice([identifier(), quoted_identifier()])
  end
end
