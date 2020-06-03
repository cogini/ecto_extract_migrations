defmodule EctoExtractMigrations.Parsers.Common do
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
    |> concat(utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, 32], min: 1))
    |> ignore(ascii_char([?"]))
  end

  def name do
    choice([quoted_identifier(), identifier()])
  end

  def schema_name do
    name()
  end

  def schema_qualified_table_name() do
    schema_name() |> ignore(ascii_char([?.])) |> concat(name())
  end

  def table_name do
    choice([schema_qualified_table_name(), name()])
  end

  def column_name do
    choice([quoted_identifier(), identifier()])
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
  def atom_type({name, [:precision, :scale]}) do
    uc = String.upcase(name)
    a = String.to_atom(name)
    choice([string(name), string(uc)])
    |> replace(a)
    |> unwrap_and_tag(:type)
    |> optional(
        ignore(ascii_char([?(]))
        |> integer(min: 1)
        |> ignore(ascii_char([?,]))
        |> integer(min: 1)
        |> ignore(ascii_char([?)]))
        |> tag(:size)
      )
  end
  def atom_type(name) do
    uc = String.upcase(name)
    a = String.to_atom(name)
    choice([string(name), string(uc)]) |> replace(a) |> unwrap_and_tag(:type)
  end

  def column_list(tag_name) do
    ignore(ascii_char([?(]))
    |> times(name() |> ignore(optional(ascii_char([?,]))) |> ignore(optional(whitespace())), min: 1)
    |> ignore(ascii_char([?)]))
    |> tag(tag_name)
  end

  def table_name(tag_name) do
    bare = name() |> unwrap_and_tag(tag_name)
    schema = name() |> ignore(ascii_char([?.])) |> concat(name()) |> tag(tag_name)
    choice([schema, bare])
  end

end
