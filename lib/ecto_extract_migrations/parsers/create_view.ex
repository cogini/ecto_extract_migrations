defmodule EctoExtractMigrations.Parsers.CreateView do
  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-createview.html

  whitespace = Common.whitespace()
  name = Common.name()

  schema_name = name
  bare_table_name = name |> unwrap_and_tag(:name)
  schema_qualified_table_name =
    schema_name |> ignore(ascii_char([?.])) |> concat(name) |> tag(:name)

  view_name = choice([schema_qualified_table_name, bare_table_name])

  view_data =
    utf8_string([{:not, ?;}], min: 1)

  create_view =
    ignore(string("CREATE VIEW"))
    |> ignore(whitespace)
    |> concat(view_name)
    |> ignore(whitespace)
    |> ignore(string("AS"))
    |> ignore(whitespace)
    |> ignore(view_data)
    |> ignore(ascii_char([?;]))
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  match_create_view =
    ignore(string("CREATE VIEW"))

  defparsec :parsec_create_view, create_view
  defparsec :parsec_match, match_create_view

  def parse(sql) do
    case parsec_create_view(sql) do
      {:ok, [value], _, _, _, _} -> {:ok, value}
      error -> error
    end
  end

  def match(sql) do
    case parse(sql) do
      {:ok, value} ->
        {:ok, value}
      _ ->
        case parsec_match(sql) do
          {:ok, _, _, _, _, _} -> :start
          error -> error
        end
    end
  end

  def tag, do: :create_view
end
