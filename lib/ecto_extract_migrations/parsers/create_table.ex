defmodule EctoExtractMigrations.Parsers.CreateTable do
  import NimbleParsec

  require EctoExtractMigrations.Parsers.Common
  alias EctoExtractMigrations.Parsers.Common

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


  # [ CONSTRAINT constraint_name ]
  # { CHECK ( expression ) [ NO INHERIT ] |
  #   UNIQUE ( column_name [, ... ] ) index_parameters |
  #   PRIMARY KEY ( column_name [, ... ] ) index_parameters |
  #   EXCLUDE [ USING index_method ] ( exclude_element WITH operator [, ... ] ) index_parameters [ WHERE ( predicate ) ] |
  #   FOREIGN KEY ( column_name [, ... ] ) REFERENCES reftable [ ( refcolumn [, ... ] ) ]
  #     [ MATCH FULL | MATCH PARTIAL | MATCH SIMPLE ] [ ON DELETE referential_action ] [ ON UPDATE referential_action ] }
  # [ DEFERRABLE | NOT DEFERRABLE ] [ INITIALLY DEFERRED | INITIALLY IMMEDIATE ]

  # CONSTRAINT case_coupon_current_uses_check CHECK ((current_uses >= 0))

  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> label(")")

  def wrap_parens(_rest, acc, context, _line, _offset) do
    values = Enum.map(acc, &("(" <> &1 <> ")"))
    {values, context}
  end

  expression =
    utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?=, ?>, ?<, ?\s, ?', ?-, ?:], min: 1)
    |> post_traverse(:wrap_parens)
    |> label("expression")

  defcombinatorp(:expr,
    ignore(lparen)
    |> choice([parsec(:expr), expression])
    |> ignore(rparen)
    |> label("expr")
  )

  table_constraint_check =
    ignore(string("CHECK"))
    |> ignore(whitespace)
    # |> utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, 32, ?(, ?), ?=, ?<, ?>], min: 1)
    |> parsec(:expr)
    |> unwrap_and_tag(:check)
    |> optional(string("NO INHERIT"))
    |> label("CHECK")

  table_constraint_name =
    name |> unwrap_and_tag(:name) |> label("constraint_name")

  table_constraint =
    string("CONSTRAINT") |> replace(:constraint) |> unwrap_and_tag(:type)
    |> ignore(whitespace)
    |> concat(table_constraint_name)
    |> ignore(whitespace)
    |> concat(table_constraint_check)

  column_name = name

  def convert_type(value, acc) do
    [String.downcase(value) |> String.to_existing_atom() | acc]
  end

# interval [ fields ] [ (p) ]
# time [ (p) ] [ without time zone ]
# time [ (p) ] with time zone	timetz
# timestamp [ (p) ] [ without time zone ]
# timestamp [ (p) ] [ without time zone ]
# timestamp [ (p) ] with time zone	timestamptz
  # https://www.postgresql.org/docs/current/datatype.html
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
      "jsonb",
      "json",
      "line",
      "lseg",
      "macaddr8",
      "macaddr",
      "money",
      {"numeric", [:precision, :scale]},
      {"decimal", [:precision, :scale]},
      "path",
      "pg_lsn",
      "point",
      "polygon",
      "real",
      "smallint",
      "smallserial",
      "serial",
      "text",
      "timestamp without time zone",
      "timestamp with time zone",
      "timestamp",
      "time without time zone",
      "time with time zone",
      "time",
      "tsquery",
      "tsvector",
      "txid_snapshot",
      "uuid",
      "xml",
    ], &Common.atom_type/1))

  user_defined_type_bare =
    name |> unwrap_and_tag(:type)

  user_defined_type_schema_qualified =
    schema_name |> ignore(ascii_char([?.])) |> concat(name) |> tag(:type)

  user_defined_type =
    choice([user_defined_type_schema_qualified, user_defined_type_bare])

  collation =
    ignore(whitespace)
    |> ignore(string("COLLATE"))
    |> ignore(whitespace)
    |> concat(name)
    |> unwrap_and_tag(:collation)
    |> label("collation")

  # column_constraint
  #
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

  null =
    ignore(whitespace)
    |> choice([
      string("NULL") |> replace(true),
      string("NOT NULL") |> replace(false)
    ])
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
      string("now()") |> unwrap_and_tag(:fragment),
      string("timezone('UTC'::text, now())") |> unwrap_and_tag(:fragment),
      string("NULL::character varying") |> unwrap_and_tag(:fragment), # redundant
      string("CURRENT_TIMESTAMP") |> unwrap_and_tag(:fragment),
      string("''")
        |> ignore(
          optional(
            choice([
              string("::character varying"),
              string("::character"),
              string("::text"),
            ])
          )
          |> optional(string("[]"))
        )
        |> replace(""),
      ignore(ascii_char([?']))
        |> utf8_string([{:not, ?'}], min: 1)
        |> ignore(ascii_char([?']))
        |> ignore(
          optional(
            choice([
              string("::character varying"),
              string("::character"),
              string("::text"),
              string("::bytea"),
              string("::jsonb"),
              string("::json"),
              string("::integer"),
            ])
          )
          |> optional(string("[]"))
        ),
      integer(min: 1),
      choice([
        string("true") |> replace(true),
        string("TRUE") |> replace(true),
        string("false") |> replace(false),
        string("FALSE") |> replace(false),
      ])
    ]) |> unwrap_and_tag(:default) |> label("default")

  #   REFERENCES reftable [ ( refcolumn ) ] [ MATCH FULL | MATCH PARTIAL | MATCH SIMPLE ]
  #     [ ON DELETE referential_action ] [ ON UPDATE referential_action ] }

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

  references =
    ignore(whitespace)
    |> ignore(string("REFERENCES"))
    |> ignore(whitespace)
    |> concat(Common.table_name(:references_table))
    |> ignore(optional(whitespace))
    |> concat(Common.column_list(:references_column))
    |> times(choice([on_delete, on_update]), min: 0)

    #  avatar_id INTEGER REFERENCES warp_avatar(id) ON DELETE CASCADE);

  column_constraint_name =
    ignore(whitespace)
    |> string("CONSTRAINT")
    |> concat(name)
    |> unwrap_and_tag(:constraint_name)
    |> label("constraint_name")

  column_constraint =
    optional(column_constraint_name)
    |> times(choice([null, default, primary_key, references]), min: 0)

  column_definition =
    column_name |> unwrap_and_tag(:name)
    |> ignore(whitespace)
    |> choice([data_type, user_defined_type])
    |> optional(string("[]") |> replace(true) |> unwrap_and_tag(:is_array))
    |> optional(collation)
    |> optional(column_constraint)

  column_spec =
    ignore(times(whitespace, min: 0))
    |> choice([table_constraint, column_definition])
    |> ignore(optional(ascii_char([?,]))) |> label(",")
    |> reduce({Enum, :into, [%{}]})

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
    |> ignore(string(");")) |> label(";")
    |> ignore(optional(whitespace))

  defparsec :parsec_table_constraint, table_constraint
  defparsec :parsec_table_name, table_name
  defparsec :parsec_create_table, create_table
  defparsec :parsec_column, column_spec

  def parse(sql) do
    case parsec_create_table(sql) do
      {:ok, value, _, _, _, _} ->
        {attrs, columns} = Enum.reduce(value, {%{}, []}, &split_attrs_columns/2)
        columns = Enum.map(Enum.reverse(columns), &fix_column/1)

        {constraints, columns} = Enum.split_with(columns, &is_constraint/1)
        attrs = Map.merge(attrs, %{columns: columns, constraints: constraints})
        attrs = if constraints == [] do
          Map.drop(attrs, [:constraints])
        else
          attrs
        end

        {:ok, attrs}
      error -> error
    end
  end


  def parse_column(sql), do: value(parsec_column(sql))
  def parse_table_constraint(sql), do: value(parsec_table_constraint(sql))

  # Whether definition is a constraint
  def is_constraint(%{type: :constraint}), do: true
  def is_constraint(_), do: false

  # Separate table attributes from column definitions
  def split_attrs_columns(value, {m, l}) when is_map(value), do: {m, [value | l]}
  def split_attrs_columns({key, value}, {m, l}), do: {Map.put(m, key, value), l}

  @doc """
  Modify column attributes to better match migrations.

  Here are the fields in migrations:

  * :primary_key - when true, marks this field as the primary key.
    If multiple fields are marked, a composite primary key will be created.
  * :default - the column's default value. It can be a string, number, empty
    list, list of strings, list of numbers, or a fragment generated by
    fragment/1.
  * :null - when false, the column does not allow null values.
  * :size - the size of the type (for example, the number of characters).
    The default is no size, except for :string, which defaults to 255.
  * :precision - the precision for a numeric type. Required when :scale is
    specified.
  * :scale - the scale of a numeric type. Defaults to 0.
  """
  def fix_column(%{type: type, size: [precision, scale]} = column) when type in [:numeric, :decimal] do
    column
    |> Map.drop([:size])
    |> Map.merge(%{precision: precision, scale: scale})
  end
  # def fix_column(%{type: type, is_array: true} = column) do
  #   column
  #   |> Map.drop([:is_array])
  #   |> Map.merge(%{type: {:array, type}})
  # end
  def fix_column(column), do: column

  def parse_table_name(name), do: value(parsec_table_name(name))

  # Convert parsec result tuple to something simpler
  def value({:ok, value, _, _, _, _}), do: {:ok, value}
  def value(result), do: result
  # def value({:error, value, _, _, _, _}), do: {:error, value}

end
