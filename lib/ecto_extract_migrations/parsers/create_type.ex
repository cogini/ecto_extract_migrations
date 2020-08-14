defmodule EctoExtractMigrations.Parsers.CreateType do
  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-createtype.html
  #   CREATE TYPE public.case_payment_status AS ENUM (
  #       'paid',
  #       'unpaid',
  #       'partial'
  #   );

  whitespace = Common.whitespace()
  name = Common.name()

  schema_name = name
  bare_table_name = name |> unwrap_and_tag(:name)
  schema_qualified_table_name =
    schema_name |> ignore(ascii_char([?.])) |> concat(name) |> tag(:name)

  type_name = choice([schema_qualified_table_name, bare_table_name])

  label_name =
    ignore(ascii_char([?']))
    |> utf8_string([{:not, ?'}], min: 1)
    |> ignore(ascii_char([?']))

  labels =
    ignore(ascii_char([?(]))
    |> times(
      ignore(optional(whitespace))
      |> concat(label_name)
      |> ignore(optional(ascii_char([?,])))
      |> ignore(optional(whitespace)), min: 1)
    |> ignore(ascii_char([?)]))
    |> ignore(optional(whitespace))
    |> tag(:labels)

  create_type =
    ignore(string("CREATE TYPE"))
    |> ignore(whitespace)
    |> concat(type_name)
    |> ignore(whitespace)
    |> ignore(string("AS ENUM"))
    |> ignore(whitespace)
    |> concat(labels)
    |> ignore(ascii_char([?;]))
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  match_create_type =
    ignore(string("CREATE TYPE"))

  defparsec :parsec_parse, create_type
  defparsec :parsec_match, match_create_type

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
