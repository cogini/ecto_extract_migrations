defmodule EctoExtractMigrations.CreateTable do
  import NimbleParsec

  alias EctoExtractMigrations.Common

  # https://www.postgresql.org/docs/current/sql-createtable.html

  whitespace = Common.whitespace()
  name = Common.name()

  global =
    choice([string("GLOBAL"), string("LOCAL")])
    |> concat(whitespace)

  temporary =
    choice([string("TEMPORARY"), string("TEMP")])
    |> concat(whitespace)

  unlogged =
    string("UNLOGGED") |> ignore(whitespace)

  if_not_exists =
    string("IF NOT EXISTS") |> ignore(whitespace)

  schema_name = name
  bare_table_name = name
  schema_qualified_table_name =
    schema_name |> ascii_char([?.]) |> concat(name)

  table_name = choice([schema_qualified_table_name, bare_table_name])

  column_name = name

  # https://www.postgresql.org/docs/current/datatype.html
  data_type =
    choice([
      string("bigint"), string("BIGINT"),
      string("bigserial"), string("BIGSERIAL"),
# bit [ (n) ]
      string("bit"), string("BIT"),
# bit varying [ (n) ]
      string("bit varying"), string("BIT VARYING"),
      string("boolean"), string("BOOLEAN"),
      string("box"), string("BOX"),
      string("bytea"), string("BYTEA"),
# character [ (n) ]
      string("character"), string("CHARACTER"),
# character varying [ (n) ]
      string("character varying"), string("CHARACTER VARYING"),
      string("cidr"), string("CIDR"),
      string("circle"), string("CIRCLE"),
      string("date"), string("DATE"),
      string("double precision"), string("DOUBLE PRECISION"),
      string("inet"), string("INET"),
      string("integer"), string("INTEGER"),
# interval [ fields ] [ (p) ]
      string("json"), string("JSON"),
      string("jsonb"), string("JSONB"),
      string("line"), string("LINE"),
      string("lseg"), string("LSEG"),
      string("macaddr"), string("MACADDR"),
      string("macaddr8"), string("MACADDR8"),
      string("money"), string("MONEY"),
# numeric [ (p, s) ]
      string("numeric"), string("NUMERIC"),
# decimal [ (p, s) ]
      string("decimal"), string("DECIMAL"),
      string("path"), string("PATH"),
      string("pg_lsn"), string("PG_LSN"),
      string("point"), string("POINT"),
      string("polygon"), string("POLYGON"),
      string("real"), string("REAL"),
      string("smallint"), string("SMALLINT"),
      string("smallserial"), string("SMALLSERIAL"),
      string("serial"), string("SERIAL"),
      string("text"), string("TEXT"),
# time [ (p) ] [ without time zone ]
      string("time"), string("TIME"),
      string("time without time zone"), string("TIME WITHOUT TIME ZONE"),
# time [ (p) ] with time zone	timetz
      string("time with time zone"), string("TIME WITH TIME ZONE"),
# timestamp [ (p) ] [ without time zone ]
      string("timestamp"), string("TIMESTAMP"),
# timestamp [ (p) ] [ without time zone ]
      string("timestamp without time zone"), string("TIMESTAMP WITHOUT TIME ZONE"),
# timestamp [ (p) ] with time zone	timestamptz
      string("timestamp with time zone"), string("TIMESTAMP WITH TIME ZONE"),
      string("tsquery"), string("TSQUERY"),
      string("tsvector"), string("TSVECTOR"),
      string("txid_snapshot"), string("TXID_SNAPSHOT"),
      string("uuid"), string("UUID"),
      string("xml"), string("XML"),
    ]) |> unwrap_and_tag(:type)

  collation =
    ignore(whitespace)
    |> string("COLLATION")
    |> concat(name)

  constraint_name =
    ignore(whitespace)
    |> string("CONSTRAINT")
    |> concat(name)

  null =
    ignore(whitespace)
    |> choice([string("NULL") |> replace(true),
      string("NOT NULL") |> replace(false)])
    |> unwrap_and_tag(:null)

  primary_key =
    ignore(whitespace)
    |> string("PRIMARY KEY")
    |> replace(true)
    |> unwrap_and_tag(:primary_key)

  default =
    ignore(whitespace)
    |> string("DEFAULT")
    |> ignore(whitespace)
    |> choice([
      integer(min: 1) |> unwrap_and_tag(:integer),
      choice([
        string("TRUE") |> replace(true),
        string("FALSE") |> replace(false)])
        |> unwrap_and_tag(:boolean)
    ])

# [ CONSTRAINT constraint_name ]
# { NOT NULL |
#   NULL |
#   CHECK ( expression ) [ NO INHERIT ] |
#   DEFAULT default_expr |
#   GENERATED ALWAYS AS ( generation_expr ) STORED |
#   GENERATED { ALWAYS | BY DEFAULT } AS IDENTITY [ ( sequence_options ) ] |
#   UNIQUE index_parameters |
#   PRIMARY KEY index_parameters |
#   REFERENCES reftable [ ( refcolumn ) ] [ MATCH FULL | MATCH PARTIAL | MATCH SIMPLE ]
#     [ ON DELETE referential_action ] [ ON UPDATE referential_action ] }
# [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

  column_constraint =
    (optional(constraint_name))
    # |> optional(null)

  column_spec =
    column_name |> unwrap_and_tag(:name)
    |> ignore(whitespace)
    |> concat(data_type)
    |> ignore(optional(constraint_name))
    |> optional(null)
    |> optional(default)
    |> optional(primary_key)
    |> ignore(optional(ascii_char([?,])))
    # |> ignore(optional(collation))
    # |> ignore(optional(column_constraint))
    # |> ignore(optional(whitespace))

  create_table =
    ignore(string("CREATE")) |> ignore(whitespace)
    |> ignore(optional(global))
    |> ignore(optional(temporary))
    |> ignore(optional(unlogged))
    |> ignore(string("TABLE")) |> ignore(whitespace)
    |> ignore(optional(if_not_exists))
    |> concat(table_name)
    |> ignore(whitespace)
    |> ignore(ascii_char([?(]))
    |> ignore(optional(whitespace))
    |> repeat(column_spec)
    |> ignore(string(");"))
    |> ignore(optional(whitespace))

  defparsec :parse, create_table

  defparsec :parse_column, column_spec

  defparsec :parse_table_name, table_name
end
