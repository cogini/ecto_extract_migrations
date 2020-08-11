defmodule EctoExtractMigrations.Parsers.CreateSchema do
  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-createschema.html
  # CREATE SCHEMA foo;

  whitespace = Common.whitespace()
  name = Common.name()

  create_schema =
    ignore(string("CREATE SCHEMA"))
    |> ignore(whitespace)
    |> concat(name) |> unwrap_and_tag(:name)
    |> ignore(ascii_char([?;]))
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  defparsec :parsec_create_schema, create_schema

  def parse(sql) do
    case parsec_create_schema(sql) do
      {:ok, [value], _, _, _, _} -> {:ok, value}
      error -> error
    end
  end

  def match(line), do: parse(line)
end
