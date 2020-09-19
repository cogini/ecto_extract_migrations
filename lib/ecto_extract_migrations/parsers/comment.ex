defmodule EctoExtractMigrations.Parsers.Comment do
  @moduledoc "Parser for SQL comments."

  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  whitespace = Common.whitespace()

  empty_comment =
    string("--\n")
    |> replace("")
    |> unwrap_and_tag(:comment)

  comment_text =
    ignore(string("--"))
    |> ignore(optional(whitespace))
    |> utf8_string([{:not, ?\n}], min: 1)
    |> unwrap_and_tag(:comment)

  comment =
    ignore(optional(whitespace))
    |> choice([empty_comment, comment_text])
    |> reduce({Enum, :into, [%{}]})

  defparsec :parsec_parse, comment
  defparsec :parsec_match, comment

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
