defmodule EctoExtractMigrations.Parsers.CreateIndex do
  import NimbleParsec

  require EctoExtractMigrations.Parsers.Common
  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-createindex.html

  # CREATE [ UNIQUE ] INDEX [ CONCURRENTLY ] [ [ IF NOT EXISTS ] name ] ON [ ONLY ] table_name [ USING method ]
  #   ( { column_name | ( expression ) } [ COLLATE collation ] [ opclass ] [ ASC | DESC ] [ NULLS { FIRST | LAST } ] [, ...] )
  #   [ INCLUDE ( column_name [, ...] ) ]
  #   [ WITH ( storage_parameter = value [, ... ] ) ]
  #   [ TABLESPACE tablespace_name ]
  # [ WHERE predicate ]

  whitespace = Common.whitespace()
  identifier = Common.identifier()
  name = Common.name()

  table_name =
    Common.table_name(:table_name)

  index_name =
    Common.table_name(:name)

  column_name = Common.column_name() |> post_traverse(:to_atom) |> label("column_name")

  defp to_atom(_rest, acc, context, _line, _offset) do
    atoms = Enum.map(acc, &String.to_atom/1)
    {atoms, context}
  end

  defp wrap_parens(_rest, acc, context, _line, _offset) do
    values = Enum.map(acc, &("(" <> &1 <> ")"))
    {values, context}
  end

  defp unwrap_parens_traverse(_rest, acc, context, _line, _offset) do
    values = Enum.map(acc, &unwrap_parens/1)
    {values, context}
  end

  # defp unwrap_parens_traverse(_rest, acc, context, _line, _offset) do
  #   values = Enum.map(acc, &unwrap_parens/1)
  #   {values, context}
  # end

  def unwrap_parens(value) do
    String.replace_prefix(value, "(", "") |> String.replace_suffix(")", "")
  end

  unique =
    ignore(optional(whitespace))
    |> string("UNIQUE")
    |> replace(true)
    |> unwrap_and_tag(:unique)

  concurrently =
    ignore(optional(whitespace))
    |> string("CONCURRENTLY")
    |> replace(true)
    |> unwrap_and_tag(:concurrently)

  if_not_exists =
    ignore(optional(whitespace))
    |> string("IF NOT EXISTS")

  only =
    ignore(optional(whitespace))
    |> string("ONLY")

  using =
    ignore(whitespace)
    |> ignore(string("USING"))
    |> ignore(whitespace)
    |> concat(Common.name())
    |> unwrap_and_tag(:using)

  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> label(")")

  expression =
    utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?=, ?>, ?<, ?\s, ?', ?-, ?:], min: 1)
    |> post_traverse(:wrap_parens)
    |> label("expression")

  sql_expression =
    # utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?=, ?>, ?<, ?\s, ?', ?-, ?:, ?(, ?)], min: 1)
    utf8_string([{:not, ?;}], min: 1)
    |> label("sql_expression")

  defcombinatorp(:expr,
    ignore(lparen)
    |> choice([parsec(:expr), expression])
    |> ignore(rparen)
    |> label("expr")
  )

  column =
    choice([column_name, parsec(:expr)])

  key =
    ignore(lparen)
    |> times(column |> ignore(optional(ascii_char([?,]))) |> ignore(optional(whitespace)), min: 1)
    |> ignore(rparen)
    |> tag(:key)
    |> label("key")

  include =
    ignore(optional(whitespace))
    |> ignore(string("INCLUDE"))
    |> ignore(whitespace)
    |> ignore(lparen)
    |> times(column |> ignore(optional(ascii_char([?,]))) |> ignore(optional(whitespace)), min: 1)
    |> ignore(rparen)
    |> tag(:include)
    |> label("include")

  equal_sign = ascii_char([?=]) |> label("=")
  semicolon = ascii_char([?;]) |> label(";")

  storage_parameter =
    identifier
    |> concat(whitespace)
    |> concat(equal_sign)
    |> concat(whitespace)
    |> concat(identifier)
    |> label("storage_parameter")

  with_ =
    ignore(optional(whitespace))
    |> ignore(string("WITH"))
    |> ignore(whitespace)
    |> ignore(lparen)
    |> times(storage_parameter |> ignore(optional(ascii_char([?,]))) |> ignore(optional(whitespace)), min: 1)
    |> ignore(rparen)
    |> tag(:with)
    |> label("with")

  tablespace =
    ignore(optional(whitespace))
    |> ignore(string("TABLESPACE"))
    |> ignore(whitespace)
    |> concat(name)
    |> unwrap_and_tag(:tablespace)
    |> label("tablespace")

  where =
    ignore(optional(whitespace))
    |> ignore(string("WHERE"))
    |> ignore(whitespace)
    |> concat(sql_expression) |> post_traverse(:unwrap_parens_traverse)
    |> unwrap_and_tag(:where)
    |> label("where")

  create_index =
    ignore(string("CREATE"))
    |> optional(unique)
    |> ignore(whitespace)
    |> ignore(string("INDEX"))
    |> optional(concurrently)
    |> ignore(optional(if_not_exists))
    |> ignore(whitespace)
    |> concat(index_name)
    |> ignore(whitespace)
    |> ignore(string("ON"))
    |> ignore(optional(only))
    |> ignore(whitespace)
    |> concat(table_name)
    |> optional(using)
    |> ignore(whitespace)
    |> concat(key)
    |> optional(include)
    |> optional(with_)
    |> optional(tablespace)
    |> optional(where)
    |> ignore(semicolon)
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  defparsec :parsec_create_index, create_index


  # :name - the name of the index. Defaults to "#{table}_#{column}_index".
  # :unique - indicates whether the index should be unique. Defaults to false.
  # :concurrently - indicates whether the index should be created/dropped concurrently.
  # :using - configures the index type.
  # :prefix - specify an optional prefix for the index.
  # :where - specify conditions for a partial index.
  # :include - specify fields for a covering index. This is not supported by all databases. For more information on PostgreSQL support, please read the official docs.

  def parse(sql) do
    case parsec_create_index(sql) do
      {:ok, [value], _, _, _, _} ->
        {:ok, value}
      error -> error
    end
  end

  def match(line), do: parse(line)
end
