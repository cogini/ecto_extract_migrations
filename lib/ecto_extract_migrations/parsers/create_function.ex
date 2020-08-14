defmodule EctoExtractMigrations.Parsers.CreateFunction do
  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-createfunction.html
  # CREATE [ OR REPLACE ] FUNCTION
  #   name ( [ [ argmode ] [ argname ] argtype [ { DEFAULT | = } default_expr ] [, ...] ] )
  #   [ RETURNS rettype
  #     | RETURNS TABLE ( column_name column_type [, ...] ) ]
  # { LANGUAGE lang_name
  #   | TRANSFORM { FOR TYPE type_name } [, ... ]
  #   | WINDOW
  #   | IMMUTABLE | STABLE | VOLATILE | [ NOT ] LEAKPROOF
  #   | CALLED ON NULL INPUT | RETURNS NULL ON NULL INPUT | STRICT
  #   | [ EXTERNAL ] SECURITY INVOKER | [ EXTERNAL ] SECURITY DEFINER
  #   | PARALLEL { UNSAFE | RESTRICTED | SAFE }
  #   | COST execution_cost
  #   | ROWS result_rows
  #   | SUPPORT support_function
  #   | SET configuration_parameter { TO value | = value | FROM CURRENT }
  #   | AS 'definition'
  #   | AS 'obj_file', 'link_symbol'
  # } ...

  # CREATE FUNCTION public.cast_to_decimal(text, numeric) RETURNS numeric
  #     LANGUAGE plpgsql IMMUTABLE
  #     AS $_$
  # begin
  #     return cast($1 as decimal);
  # exception
  #     when invalid_text_representation then
  #         return $2;
  # end;
  # $_$;

  whitespace = Common.whitespace()
  name = Common.name()

  # data_type = Common.data_type()

  schema_name = name
  bare_name = name |> unwrap_and_tag(:name)
  schema_qualified_name =
    schema_name |> ignore(ascii_char([?.])) |> concat(name) |> tag(:name)

  lparen = ascii_char([?(]) |> label("(")
  rparen = ascii_char([?)]) |> label(")")

  or_replace =
    ignore(whitespace)
    |> ignore(string("OR REPLACE"))

  function_name = choice([schema_qualified_name, bare_name])

  args =
    utf8_string([{:not, ?)}], min: 0)

  returns =
    ignore(whitespace)
    |> ignore(string("RETURNS"))
    |> ignore(whitespace)
    |> concat(name)

  language =
    ignore(whitespace)
    |> ignore(string("LANGUAGE"))
    |> ignore(whitespace)
    |> concat(name)

  immutable =
    ignore(whitespace)
    |> choice([
      string("IMMUTABLE"),
      string("STABLE"),
      string("VOLATILE"),
      choice([string("NOT LEAKPROOF"), string("LEAKPROOF")])
    ])

  as =
    ignore(whitespace)
    |> ignore(string("AS"))
    |> ignore(whitespace)
    |> ascii_string([{:not, ?\s}, {:not, ?\n}], min: 1)
    |> unwrap_and_tag(:delimiter)

  # argname = name

  # arg_definition =
  #   # optional(argname)
  #   # |> ignore(optional(whitespace))
  #   # |> concat(data_type)
  #   data_type
  #   |> optional(string("[]") |> replace(true) |> unwrap_and_tag(:is_array))

  # arg_spec =
  #   ignore(times(whitespace, min: 0))
  #   |> concat(arg_definition)
  #   |> ignore(optional(ascii_char([?,]))) |> label(",")
  #   |> reduce({Enum, :into, [%{}]})

  create_function =
    ignore(string("CREATE"))
    |> ignore(optional(or_replace))
    |> ignore(whitespace)
    |> ignore(string("FUNCTION"))
    |> ignore(whitespace)
    |> concat(function_name)
    |> ignore(optional(whitespace))
    |> ignore(lparen)
    |> ignore(args)
    # |> ignore(optional(whitespace))
    # |> times(arg_spec, min: 0)
    # |> ignore(times(whitespace, min: 0))
    |> ignore(rparen)
    |> ignore(returns)
    |> ignore(optional(language))
    |> ignore(optional(immutable))
    |> concat(as)
    |> reduce({Enum, :into, [%{}]})

  match_create_function =
    ignore(string("CREATE"))
    |> ignore(optional(or_replace))
    |> ignore(whitespace)
    |> ignore(string("FUNCTION"))

  defparsec :parsec_parse, create_function
  defparsec :parsec_match, match_create_function

  def parse(line), do: parse(line, %{sql: ""})

  # Parse SQL for function body until delimiter is reached
  def parse(line, %{sql: lines, delimiter: delimiter, data: data} = state) do
    if line == delimiter <> ";\n" do
      {:ok, data}
    else
      {:continue, Map.merge(state, %{sql: lines <> line})}
    end
  end

  # Parse function head
  def parse(line, %{sql: lines} = state) do
    sql = lines <> line
    case parsec_parse(sql) do
      {:ok, [value], _, _, _, _} ->
        if String.ends_with?(sql, value.delimiter <> ";\n") do
          # SQL has complete statement, not line by line parsing
          {:ok, value}
        else
          # Parsed header, continue and parser will read function body up to delimiter
          new_state = %{sql: sql, data: value, delimiter: value.delimiter}
          {:continue, Map.merge(state, new_state)}
        end
      {:error, _reason, _, _, _, _} = error ->
        {:continue, Map.merge(state, %{sql: sql, error: error})}
    end
  end

  def match(line) do
    case parsec_match(line) do
      {:ok, _, _, _, _, _} ->
        case parsec_parse(line) do
          {:ok, [value], _, _, _, _} ->
            {:ok, value}
          {:error, _reason, _, _, _, _} = error ->
            {:continue, %{sql: line, error: error}}
        end
      {:error, reason, _, _, _, _} ->
        {:error, reason}
    end
  end

end

