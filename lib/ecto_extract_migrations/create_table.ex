defmodule EctoExtractMigrations.CreateTable do
  import NimbleParsec

  # https://www.postgresql.org/docs/current/sql-createtable.html

  # https://www.postgresql.org/docs/current/sql-syntax-lexical.html
  whitespace = ascii_char([32, ?\t])
               |> times(min: 1)

  # identifier = utf8_string([], min: 1)
  identifier = utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_], min: 1)
#  identifier = utf8_string([{:not, [?., ?;, ?(, ?}], min: 1)

  quoted_identifier = ignore(ascii_char([?"]))
                      |> concat(identifier)
                      |> ignore(ascii_char([?"]))

  name = choice([identifier, quoted_identifier])

  schema_name = name
  table_name = name

  schema_qualified_table_name = schema_name |> ascii_char([?.]) |> concat(table_name)

  create_table = string("CREATE")
           |> ignore(whitespace)
           |> string("TABLE")
           |> ignore(whitespace)

  defparsec :parse, ignore(create_table)
  |> choice([schema_qualified_table_name, table_name])

  defparsec :parse_table_name, choice([schema_qualified_table_name, table_name])
end
