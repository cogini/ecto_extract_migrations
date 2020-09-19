defmodule EctoExtractMigrations.Parsers.CreateView do
  @moduledoc "Parser for CREATE VIEW."

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

  defparsec :parsec_parse, create_view
  defparsec :parsec_match, match_create_view

  def parse(line), do: parse(line, %{sql: ""})

  def parse(line, %{sql: lines} = state) do
    sql = lines <> line
    case parsec_parse(sql) do
      {:ok, [value], _, _, _, _} ->
        {:ok, value}
      {:error, reason, _, _, _, _} ->
        {:continue, Map.merge(state, %{sql: sql, error: reason})}
    end
  end

  def match(line) do
    case parsec_match(line) do
      {:ok, _, _, _, _, _} ->
        case parsec_parse(line) do
          {:ok, [value], _, _, _, _} ->
            {:ok, value}
          {:error, reason, _, _, _, _} ->
            {:continue, %{sql: line, error: reason}}
        end
      {:error, reason, _, _, _, _} ->
        {:error, reason}
    end
  end

end
