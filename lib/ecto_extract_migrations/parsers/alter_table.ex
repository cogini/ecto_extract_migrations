defmodule EctoExtractMigrations.Parsers.AlterTable do
  @moduledoc "Parser for ALTER TABLE."

  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-altertable.html

  whitespace = Common.whitespace()
  name = Common.name()

  schema_name = name
  bare_table_name = name |> unwrap_and_tag(:table)
  schema_qualified_table_name =
    schema_name |> ignore(ascii_char([?.])) |> concat(name) |> tag(:table)

  table_name = choice([schema_qualified_table_name, bare_table_name])

  if_exists =
    ignore(whitespace)
    |> string("IF EXISTS")

  only =
    ignore(whitespace)
    |> string("ONLY")

  table_constraint_name =
    name |> unwrap_and_tag(:constraint_name) |> label("constraint_name")

  table_constraint_primary_key =
    ignore(whitespace)
    |> string("PRIMARY KEY") |> replace(:primary_key) |> unwrap_and_tag(:type)
    |> ignore(whitespace)
    |> concat(Common.column_list(:primary_key))
    |> label("PRIMARY KEY")

  table_constraint_unique =
    ignore(whitespace)
    |> string("UNIQUE") |> replace(:unique) |> unwrap_and_tag(:type)
    |> ignore(whitespace)
    |> concat(Common.column_list(:columns))
    |> label("UNIQUE")

  on_delete =
    ignore(whitespace)
    |> ignore(string("ON DELETE"))
    |> ignore(whitespace)
    |> choice([
      string("CASCADE") |> replace(:cascade),
      string("RESTRICT") |> replace(:restrict),
      string("SET NULL") |> replace(:set_null)
    ])
    |> unwrap_and_tag(:on_delete)
    |> label("ON DELETE")

  on_update =
    ignore(whitespace)
    |> ignore(string("ON UPDATE"))
    |> ignore(whitespace)
    |> choice([
      string("CASCADE") |> replace(:cascade),
      string("RESTRICT") |> replace(:restrict),
      string("SET NULL") |> replace(:set_null)
    ])
    |> unwrap_and_tag(:on_update)
    |> label("ON UPDATE")

  table_constraint_foreign_key =
    ignore(whitespace)
    |> string("FOREIGN KEY") |> replace(:foreign_key) |> unwrap_and_tag(:type)
    |> ignore(whitespace)
    |> concat(Common.column_list(:columns))
    |> ignore(whitespace)
    |> ignore(string("REFERENCES"))
    |> ignore(whitespace)
    |> concat(Common.table_name(:references_table))
    |> concat(Common.column_list(:references_columns))
    |> times(choice([on_delete, on_update]), min: 0)

  # table_constraint
  #
  # [ CONSTRAINT constraint_name ]
  # { CHECK ( expression ) [ NO INHERIT ] |
  #   UNIQUE ( column_name [, ... ] ) index_parameters |
  #   PRIMARY KEY ( column_name [, ... ] ) index_parameters |
  #   EXCLUDE [ USING index_method ] ( exclude_element WITH operator [, ... ] ) index_parameters [ WHERE ( predicate ) ] |
  #   FOREIGN KEY ( column_name [, ... ] ) REFERENCES reftable [ ( refcolumn [, ... ] ) ]
  #     [ MATCH FULL | MATCH PARTIAL | MATCH SIMPLE ] [ ON DELETE referential_action ] [ ON UPDATE referential_action ] }
  # [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

  add_table_constraint =
    string("ADD CONSTRAINT") |> replace(:add_table_constraint) |> unwrap_and_tag(:action)
    |> ignore(whitespace)
    |> concat(table_constraint_name)
    |> choice([table_constraint_primary_key, table_constraint_foreign_key, table_constraint_unique])

  column_name = name

  alter_column =
    ignore(string("ALTER COLUMN"))
    |> ignore(whitespace)
    |> concat(column_name) |> unwrap_and_tag(:column)
    |> ignore(whitespace)

  # ALTER TABLE ONLY chat.assignment ALTER COLUMN id SET DEFAULT nextval('chat.assignment_id_seq'::regclass);

  # This assumes that the default is a sequence
  default =
    utf8_string([{:not, ?;}], min: 1)
    |> unwrap_and_tag(:fragment)
    |> unwrap_and_tag(:default)

  set_default =
    ignore(string("SET DEFAULT"))
    |> ignore(whitespace)
    |> replace(:set_default) |> unwrap_and_tag(:action)
    |> concat(default)

  action =
    ignore(whitespace)
    # |> times(add_table_constraint, min: 1)
    |> choice([add_table_constraint, alter_column |> concat(set_default)])
    |> ignore(optional(ascii_char([?,])))

  alter_table =
    ignore(string("ALTER TABLE"))
    |> ignore(optional(if_exists))
    |> ignore(optional(only))
    |> ignore(whitespace)
    |> concat(table_name)
    |> times(action, min: 1)
    |> ignore(ascii_char([?;]))
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  match_alter_table =
    ignore(string("ALTER TABLE"))

  defparsec :parsec_parse, alter_table
  defparsec :parsec_match, match_alter_table

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
