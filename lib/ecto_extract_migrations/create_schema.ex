defmodule EctoExtractMigrations.CreateSchema do
  import NimbleParsec

  alias EctoExtractMigrations.Common

  # https://www.postgresql.org/docs/current/sql-createschema.html
  # CREATE SCHEMA foo;

  whitespace = Common.whitespace()
  name = Common.name()

  create_schema = ignore(string("CREATE"))
           |> ignore(whitespace)
           |> ignore(string("SCHEMA"))
           |> ignore(whitespace)
           |> concat(name) |> unwrap_and_tag(:name)
           |> ignore(ascii_char([?;]))
           |> optional(whitespace)

  defparsec :parse, create_schema
end
