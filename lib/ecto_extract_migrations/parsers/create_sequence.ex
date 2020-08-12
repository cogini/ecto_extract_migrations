defmodule EctoExtractMigrations.Parsers.CreateSequence do
  import NimbleParsec

  require EctoExtractMigrations.Parsers.Common
  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-createsequence.html

  whitespace = Common.whitespace()

  sequence_name =
    Common.table_name(:name)

  temporary =
    ignore(optional(whitespace))
    |> choice([string("TEMPORARY"), string("TEMP")])
    |> replace(true)
    |> unwrap_and_tag(:temporary)

  if_not_exists =
    ignore(optional(whitespace))
    |> string("IF NOT EXISTS")

  data_type =
    ignore(optional(whitespace))
    |> ignore(string("AS"))
    |> ignore(whitespace)
    |> choice([
      string("smallint") |> replace(:smallint),
      string("integer") |> replace(:integer),
      string("bigint") |> replace(:integer)])
    |> unwrap_and_tag(:data_type)

  increment =
    ignore(optional(whitespace))
    |> ignore(string("INCREMENT"))
    |> ignore(optional(whitespace))
    |> ignore(optional(string("BY")))
    |> ignore(optional(whitespace))
    |> integer(min: 1)
    |> unwrap_and_tag(:increment)

  minvalue =
    ignore(optional(whitespace))
    |> ignore(string("MINVALUE"))
    |> ignore(whitespace)
    |> integer(min: 1)
    |> unwrap_and_tag(:minvalue)

  no_minvalue =
    ignore(optional(whitespace))
    |> string("NO MINVALUE") |> replace(false)
    |> unwrap_and_tag(:minvalue)

  maxvalue =
    ignore(optional(whitespace))
    |> ignore(string("MAXVALUE"))
    |> ignore(whitespace)
    |> integer(min: 1)
    |> unwrap_and_tag(:maxvalue)

  no_maxvalue =
    ignore(optional(whitespace))
    |> string("NO MAXVALUE") |> replace(false)
    |> unwrap_and_tag(:maxvalue)

  start =
    ignore(optional(whitespace))
    |> ignore(string("START"))
    |> ignore(optional(whitespace))
    |> ignore(optional(string("WITH")))
    |> ignore(optional(whitespace))
    |> integer(min: 1)
    |> unwrap_and_tag(:start)

  cache =
    ignore(optional(whitespace))
    |> ignore(string("CACHE"))
    |> ignore(whitespace)
    |> integer(min: 1)
    |> unwrap_and_tag(:cache)

  cycle =
    ignore(optional(whitespace))
    |> choice([string("NO CYCLE") |> replace(false), string("CYCLE") |> replace(true)])
    |> unwrap_and_tag(:cycle)

  owned_by =
    ignore(optional(whitespace))
    |> string("OWNED BY")
    |> ignore(whitespace)
    |> choice([Common.table_name(), string("NONE") |> replace(:none)])
    |> unwrap_and_tag(:owned_by)

  create_sequence =
    ignore(string("CREATE"))
    |> optional(temporary)
    |> ignore(whitespace)
    |> ignore(string("SEQUENCE"))
    |> ignore(optional(if_not_exists))
    |> ignore(whitespace)
    |> concat(sequence_name)
    |> optional(data_type)
    |> ignore(whitespace)
    |> optional(start)
    |> optional(increment)
    |> optional(choice([minvalue, no_minvalue]))
    |> optional(choice([maxvalue, no_maxvalue]))
    |> optional(cache)
    |> optional(cycle)
    |> optional(owned_by)
    |> ignore(ascii_char([?;]))
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  match_create_sequence =
    ignore(string("CREATE"))
    |> optional(temporary)
    |> ignore(whitespace)
    |> ignore(string("SEQUENCE"))

  defparsec :parsec_create_sequence, create_sequence
  defparsec :parsec_match, match_create_sequence

  def parse(sql) do
    case parsec_create_sequence(sql) do
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

  def tag, do: :create_sequence
end
