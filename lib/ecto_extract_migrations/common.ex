defmodule EctoExtractMigrations.Common do
  import NimbleParsec

  def whitespace do
    ascii_char([32, ?\t, ?\n]) |> times(min: 1)
  end

  # https://www.postgresql.org/docs/current/sql-syntax-lexical.html

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

  def convert_type(value, acc) do
    [String.downcase(value) |> String.to_existing_atom() | acc]
  end

  def atom_type({name, :size}) do
    uc = String.upcase(name)
    a = String.to_atom(name)
    choice([string(name), string(uc)])
    |> replace(a)
    |> unwrap_and_tag(:type)
    |> optional(
      ignore(ascii_char([?(]))
      |> integer(min: 1)
      |> ignore(ascii_char([?)]))
      |> unwrap_and_tag(:size)
    )
  end
  def atom_type(name) do
    uc = String.upcase(name)
    a = String.to_atom(name)
    choice([string(name), string(uc)]) |> replace(a) |> unwrap_and_tag(:type)
  end
end
