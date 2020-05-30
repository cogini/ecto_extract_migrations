defmodule EctoExtractMigrations.AlterTable do
  import NimbleParsec

  alias EctoExtractMigrations.Common

  # https://www.postgresql.org/docs/current/sql-altertable.html

  whitespace = Common.whitespace()
  name = Common.name()

  schema_name = name
  bare_table_name = name |> unwrap_and_tag(:table_name)
  schema_qualified_table_name =
    schema_name |> ignore(ascii_char([?.])) |> concat(name) |> tag(:table_name)

  table_name = choice([schema_qualified_table_name, bare_table_name])

  if_exists =
    ignore(whitespace)
    |> string("IF EXISTS")

  only =
    ignore(whitespace)
    |> string("ONLY")

  table_constraint_name =
    name |> unwrap_and_tag(:constraint_name)

  table_constraint_primary_key =
    ignore(whitespace)
    |> ignore(string("PRIMARY KEY"))
    |> ignore(whitespace)
    |> ignore(ascii_char([?(]))
    |> times(name |> ignore(optional(ascii_char([?,]))) |> ignore(optional(whitespace)), min: 1)
    |> ignore(ascii_char([?)]))
    |> ignore(optional(whitespace))
    |> tag(:primary_key)

  # [ CONSTRAINT constraint_name ]
  # { CHECK ( expression ) [ NO INHERIT ] |
  #   UNIQUE ( column_name [, ... ] ) index_parameters |
  #   PRIMARY KEY ( column_name [, ... ] ) index_parameters |
  #   EXCLUDE [ USING index_method ] ( exclude_element WITH operator [, ... ] ) index_parameters [ WHERE ( predicate ) ] |
  #   FOREIGN KEY ( column_name [, ... ] ) REFERENCES reftable [ ( refcolumn [, ... ] ) ]
  #     [ MATCH FULL | MATCH PARTIAL | MATCH SIMPLE ] [ ON DELETE referential_action ] [ ON UPDATE referential_action ] }
  # [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

  add_table_constraint =
    string("ADD")
    |> ignore(whitespace)
    |> string("CONSTRAINT")
    |> ignore(whitespace)
    |> replace(:add_constraint) |> unwrap_and_tag(:action)
    |> concat(table_constraint_name)
    |> concat(table_constraint_primary_key)

  action =
    ignore(whitespace)
    |> times(add_table_constraint, min: 1)
    |> ignore(optional(ascii_char([?,])))

  alter_table =
    ignore(string("ALTER"))
    |> ignore(whitespace)
    |> ignore(string("TABLE"))
    |> ignore(optional(if_exists))
    |> ignore(optional(only))
    |> ignore(whitespace)
    |> concat(table_name)
    |> times(action, min: 1)
    |> ignore(ascii_char([?;]))
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  defparsec :parse, alter_table
end
