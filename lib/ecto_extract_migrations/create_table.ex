defmodule EctoExtractMigrations.CreateTable do
  import NimbleParsec

  require EctoExtractMigrations.Common
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
  bare_table_name = name |> unwrap_and_tag(:name)
  schema_qualified_table_name =
    schema_name |> ignore(ascii_char([?.])) |> concat(name) |> tag(:name)

  table_name = choice([schema_qualified_table_name, bare_table_name])

  column_name = name

  def convert_type(value, acc) do
    [String.downcase(value) |> String.to_existing_atom() | acc]
  end

# interval [ fields ] [ (p) ]
# numeric [ (p, s) ]
# decimal [ (p, s) ]
# time [ (p) ] [ without time zone ]
# time [ (p) ] with time zone	timetz
# timestamp [ (p) ] [ without time zone ]
# timestamp [ (p) ] [ without time zone ]
# timestamp [ (p) ] with time zone	timestamptz
  data_type =
    choice(Enum.map([
      "bigint",
      "bigserial",
      {"bit", :size},
      {"bit varying", :size},
      "boolean",
      "box",
      "bytea",
      {"character varying", :size},
      {"character", :size},
      "cidr",
      "circle",
      "date",
      "double precision",
      "inet",
      "integer",
      "json",
      "jsonb",
      "line",
      "lseg",
      "macaddr",
      "macaddr8",
      "money",
      "numeric",
      "decimal",
      "path",
      "pg_lsn",
      "point",
      "polygon",
      "real",
      "smallint",
      "smallserial",
      "serial",
      "text",
      "time",
      "time without time zone",
      "time with time zone",
      "timestamp",
      "timestamp without time zone",
      "timestamp with time zone",
      "tsquery",
      "tsvector",
      "txid_snapshot",
      "uuid",
      "xml",
    ], &Common.atom_type/1))

  data_type_size =
    ignore(ascii_char([?(]))
    |> integer(min: 1)
    ignore(ascii_char([?)]))

  # https://www.postgresql.org/docs/current/datatype.html
  # data_type =
  #   choice([
  #     simple_data_type("bigint"),
  #     simple_data_type("bigserial"),
# # bit [ (n) ]
  #     simple_data_type("bit"),
# # bit varying [ (n) ]
  #     simple_data_type("bit varying"),
  #     simple_data_type("boolean"),
  #     simple_data_type("box"),
  #     simple_data_type("bytea"),
# # character varying [ (n) ]
# #      choice([string("character varying"), string("CHARACTER VARYING")]) |> optional(data_type_size),
# # character [ (n) ]
  #     simple_data_type("character"),
  #     simple_data_type("cidr"),
  #     simple_data_type("circle"),
  #     simple_data_type("date"),
  #     simple_data_type("double precision"),
  #     simple_data_type("inet"),
  #     simple_data_type("integer"),
# # interval [ fields ] [ (p) ]
  #     simple_data_type("json"),
  #     simple_data_type("jsonb"),
  #     simple_data_type("line"),
  #     simple_data_type("lseg"),
  #     simple_data_type("macaddr"),
  #     simple_data_type("macaddr8"),
  #     simple_data_type("money"),
# # numeric [ (p, s) ]
  #     simple_data_type("numeric"),
# # decimal [ (p, s) ]
  #     simple_data_type("decimal"),
  #     simple_data_type("path"),
  #     simple_data_type("pg_lsn"),
  #     simple_data_type("point"),
  #     simple_data_type("polygon"),
  #     simple_data_type("real"),
  #     simple_data_type("smallint"),
  #     simple_data_type("smallserial"),
  #     simple_data_type("serial"),
  #     simple_data_type("text"),
# # time [ (p) ] [ without time zone ]
  #     simple_data_type("time"),
  #     simple_data_type("time without time zone"),
# # time [ (p) ] with time zone	timetz
  #     simple_data_type("time with time zone"),
# # timestamp [ (p) ] [ without time zone ]
  #     simple_data_type("timestamp"),
# # timestamp [ (p) ] [ without time zone ]
  #     simple_data_type("timestamp without time zone"),
# # timestamp [ (p) ] with time zone	timestamptz
  #     simple_data_type("timestamp with time zone"),
  #     simple_data_type("tsquery"),
  #     simple_data_type("tsvector"),
  #     simple_data_type("txid_snapshot"),
  #     simple_data_type("uuid"),
  #     simple_data_type("xml"),
  #     ])

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
    |> ignore(string("DEFAULT"))
    |> ignore(whitespace)
    |> choice([
      integer(min: 1),
      choice([
        string("TRUE") |> replace(true),
        string("FALSE") |> replace(false)])
    ]) |> unwrap_and_tag(:default)

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

  column_spec =
    ignore(times(whitespace, min: 0))
    |> concat(column_name) |> unwrap_and_tag(:name)
    |> ignore(whitespace)
    |> concat(data_type)
    |> ignore(optional(constraint_name))
    |> optional(null)
    |> optional(default)
    |> optional(primary_key)
    |> ignore(optional(ascii_char([?,])))
    |> reduce({Enum, :into, [%{}]})
    # |> ignore(optional(collation))
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
    |> times(column_spec, min: 0)
    |> ignore(times(whitespace, min: 0))
    |> ignore(string(");"))
    |> ignore(optional(whitespace))

  defparsec :parsec_create_table, create_table

  defparsec :parse_column, column_spec

  defparsec :parsec_table_name, table_name

  def parse(sql) do
    case parsec_create_table(sql) do
      {:ok, value, _, _, _, _} ->
        {attrs, columns} = Enum.reduce(value, {%{}, []}, &reduce_table/2)
        {:ok, Map.put(attrs, :columns, Enum.reverse(columns))}
      {:error, reason, _, _, _, _} ->
        {:error, reason}
    end
  end

  def reduce_table(value, {m, l}) when is_map(value), do: {m, [value | l]}
  def reduce_table({key, value}, {m, l}), do: {Map.put(m, key, value), l}

  def parse_table_name(name), do: value(parsec_table_name(name))

  def value({:ok, value, _, _, _, _}), do: {:ok, value}
  def value({:error, value, _, _, _, _}), do: {:error, value}

end
