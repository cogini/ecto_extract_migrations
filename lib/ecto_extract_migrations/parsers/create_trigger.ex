defmodule EctoExtractMigrations.Parsers.CreateTrigger do
  @moduledoc "Parser for CREATE TRIGGER."

  import NimbleParsec

  require EctoExtractMigrations.Parsers.Common
  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-createtrigger.html
  #
  # CREATE [ CONSTRAINT ] TRIGGER name { BEFORE | AFTER | INSTEAD OF } { event [ OR ... ] }
  #     ON table_name
  #     [ FROM referenced_table_name ]
  #     [ NOT DEFERRABLE | [ DEFERRABLE ] [ INITIALLY IMMEDIATE | INITIALLY DEFERRED ] ]
  #     [ REFERENCING { { OLD | NEW } TABLE [ AS ] transition_relation_name } [ ... ] ]
  #     [ FOR [ EACH ] { ROW | STATEMENT } ]
  #     [ WHEN ( condition ) ]
  #   EXECUTE { FUNCTION | PROCEDURE } function_name ( arguments )

  # where event can be one of:

  #   INSERT
  #   UPDATE [ OF column_name [, ... ] ]
  #   DELETE
  #   TRUNCATE

# CREATE TRIGGER chat_message_update BEFORE UPDATE ON chat.message FOR EACH ROW EXECUTE PROCEDURE public.chat_update_timestamp();

  whitespace = Common.whitespace()
  name = Common.name()

  constraint =
    ignore(optional(whitespace))
    |> ignore(string("CONSTRAINT"))

  trigger_name =
    name |> unwrap_and_tag(:name)

  # when_ =
  #   choice([
  #     string("BEFORE"),
  #     string("AFTER"),
  #     string("INSTEAD OF")
  #   ])

  # event =
  #   choice([
  #     string("INSERT"),
  #     string("UPDATE"),
  #     string("DELETE"),
  #     string("TRUNCATE")
  #   ])

  # table_name =
  #   Common.table_name(:table_name)

  semicolon = ascii_char([?;]) |> label(";")

  create_trigger =
    ignore(string("CREATE"))
    |> optional(constraint)
    |> ignore(whitespace)
    |> ignore(string("TRIGGER"))
    |> ignore(whitespace)
    |> concat(trigger_name)
    # |> ignore(when_)
    # |> ignore(whitespace)
    # |> ignore(event)
    # |> ignore(whitespace)
    # |> ignore(string("ON"))
    # |> ignore(whitespace)
    # |> concat(table_name)
    # |> ignore(optional(choice([
    #   string("FOR EACH ROW"),
    #   string("FOR EACH STATEMENT")
    # ])
    |> ignore(utf8_string([{:not, ?;}], min: 1))
    |> ignore(semicolon)
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  defparsec :parsec_parse, create_trigger
  defparsec :parsec_match, create_trigger

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
