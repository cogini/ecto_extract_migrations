defmodule EctoExtractMigrations.CreateSchema do
  import NimbleParsec

  alias EctoExtractMigrations.Common

  # CREATE SCHEMA foo;

  create_schema = ignore(string("CREATE"))
           |> ignore(Common.whitespace())
           |> ignore(string("SCHEMA"))
           |> ignore(Common.whitespace())
           |> concat(Common.name())
           |> ignore(ascii_char([?;]))
           |> optional(Common.whitespace())

  defparsec :parse, create_schema
end
