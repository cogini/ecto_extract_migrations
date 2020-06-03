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

  table_name =
    Common.table_name(:table_name)

  index_name =
    Common.table_name(:name)

  unique =
    ignore(optional(whitespace))
    |> string("UNIQUE")

  concurrently =
    ignore(optional(whitespace))
    |> string("CONCURRENTLY")

  if_not_exists =
    string("IF NOT EXISTS") |> ignore(whitespace)

  only =
    ignore(optional(whitespace))
    |> string("ONLY")

  using =
    ignore(whitespace)
    |> ignore(string("USING"))
    |> ignore(whitespace)
    |> concat(Common.name())
    |> unwrap_and_tag(:using)

  key =
    utf8_string([{:not, ?;}], min: 1)
    |> unwrap_and_tag(:key)

  create_index =
    ignore(string("CREATE"))
    |> ignore(optional(unique))
    |> ignore(whitespace)
    |> ignore(string("INDEX"))
    |> ignore(optional(concurrently))
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
    |> ignore(string(";"))
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  defparsec :parsec_create_index, create_index

  def parse(sql) do
    case parsec_create_index(sql) do
      {:ok, [value], _, _, _, _} ->
        value = update_in(value[:key], &fix_key/1) 
        {:ok, value}
      error -> error
    end
  end

  def unwrap_parens(value) do
    String.replace_prefix(value, "(", "") |> String.replace_suffix(")", "")
  end

  def fix_key(value) do
    value
    |> unwrap_parens
    |> String.split(~r/,\s+/)
  end

end
