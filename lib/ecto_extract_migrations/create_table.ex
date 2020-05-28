defmodule Mix.Tasks.Ecto.Extract.Migrations.CreateTable do

  alias Mix.Tasks.Ecto.Extract.Migrations.ParseError

  def parse_sql({line, _index}, {_fun, local, global}) do
    # Mix.shell().info("create_table> #{line} #{inspect local}")

    line = String.trim(line)

    if Regex.match?(~r/\);/, line) do
      local = Enum.reverse([line | local])
      sql = Enum.join(local)

      # Mix.shell().info("create_table> #{sql}")

      case Regex.named_captures(~r/\s*CREATE\s+TABLE\s+(?<table>[\w\."]+)\s+\((?<fields>.*)\);$/, sql) do
        nil ->
          raise ParseError, line: line, message: "create table: #{sql}"
        data ->
          # Mix.shell().info("create_table> SQL #{sql}")
          field_data = parse_fields(data["fields"] <> ",", %{}, [])
          # Mix.shell().info("create_table> table: #{data["table"]} #{inspect field_data}")
          {nil, nil, [%{type: :create_table, sql: sql, table: data["table"], fields: field_data} | global]}
      end
    else
      {&parse_sql/2, [line | local], global}
    end
  end

  def parse_fields(",", data, acc) do
    Enum.reverse([data | acc])
  end
  def parse_fields(field, data, [] = acc) when map_size(data) == 0 do
    # Mix.shell().info("parse_fields> start: #{field} #{inspect data} #{inspect acc}")
    cond do
      r = Regex.named_captures(~r/^CONSTRAINT (?<rest>.*)/i, field) ->
        parse_constraint(r["rest"], %{}, acc)
      r = Regex.named_captures(~r/"?(?<name>[\w\s]+)"\s+(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], %{name: r["name"]}, acc)
      r = Regex.named_captures(~r/^(?<name>\w+)\s+(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], %{name: r["name"]}, acc)
      true ->
        raise ParseError, message: "error name: #{inspect field} #{inspect data} #{inspect acc}"
    end
  end
  def parse_fields("," <> field, data, acc) do
    # Mix.shell().info("parse_fields> next: #{field} #{inspect data} #{inspect acc}")
    cond do
      r = Regex.named_captures(~r/^CONSTRAINT (?<rest>.*)/i, field) ->
        parse_constraint(r["rest"], %{}, acc)
      r = Regex.named_captures(~r/"?(?<name>[\w\s]+)"\s+(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], %{name: r["name"]}, acc)
      r = Regex.named_captures(~r/^(?<name>\w+)\s+(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], %{name: r["name"]}, [data | acc])
      true ->
        raise ParseError, message: "error name: #{inspect field} #{inspect data} #{inspect acc}"
    end
  end
  def parse_fields("[]" <> rest, data, acc) do
    parse_fields(rest, Map.put(data, :is_array, true), acc)
  end
  def parse_fields(" " <> rest, data, acc), do: parse_fields(rest, data, acc)
  def parse_fields(field, data, acc) do
    # Mix.shell().info("parse_field: middle: #{inspect field}, #{inspect data} #{inspect acc}")
    cond do
      r = Regex.named_captures(~r/^public.case_payment_status(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, "public.case_payment_status"), acc)

      r = Regex.named_captures(~r/^numeric\((?<precision>\d+),\s*(?<scale>\d+)\)(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.merge(data, %{type: :numeric, precision: r["precision"], scale: r["scale"]}), acc)
      r = Regex.named_captures(~r/^character varying\s*\((?<size>\d+)\)(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.merge(data, %{type: :string, size: r["size"]}), acc)
      r = Regex.named_captures(~r/^character varying(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :string), acc)
      r = Regex.named_captures(~r/^text(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :text), acc)
      r = Regex.named_captures(~r/^bytea(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :bytea), acc)
      r = Regex.named_captures(~r/^jsonb(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :jsonb), acc)
      r = Regex.named_captures(~r/^json(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :json), acc)
      r = Regex.named_captures(~r/^integer(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :integer), acc)
      r = Regex.named_captures(~r/^bigint(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :bigint), acc)
      r = Regex.named_captures(~r/^double precision(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :double_precision), acc)
      r = Regex.named_captures(~r/^boolean(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :boolean), acc)
      r = Regex.named_captures(~r/^point(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :point), acc)
      r = Regex.named_captures(~r/^tsvector(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :tsvector), acc)
      r = Regex.named_captures(~r/^date(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :date), acc)
      r = Regex.named_captures(~r/^time without time zone(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :time), acc)
      r = Regex.named_captures(~r/^timestamp without time zone(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :timestamp), acc)
      r = Regex.named_captures(~r/^timestamp with time zone(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :type, :timestampz), acc)
      r = Regex.named_captures(~r/^NOT NULL(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :null, false), acc)
      r = Regex.named_captures(~r/^PRIMARY KEY(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :primary_key, true), acc)
      r = Regex.named_captures(~r/^DEFAULT (?<rest>.*)/i, field) ->
        parse_default(r["rest"], data, acc)
      r = Regex.named_captures(~r/^REFERENCES (?<references>[^,]+)(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :references, r["references"]), acc)
      true ->
        raise ParseError, message: "error field: #{inspect field} #{inspect data} #{inspect acc}"
    end
  end

  def parse_default("timezone('UTC'::text, now())" <> rest, data, acc) do
    parse_fields(rest, Map.put(data, :default, "timezone('UTC'::text, now())"), acc)
  end
  def parse_default("NULL::character varying" <> rest, data, acc) do
    parse_fields(rest, Map.put(data, :default, "NULL"), acc)
  end
  def parse_default(field, data, acc) do
    cond do
      r = Regex.named_captures(~r/^'(?<value>[^']*)'::character varying(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :default, r["value"]), acc)
      r = Regex.named_captures(~r/^'(?<value>[^']*)'::text(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :default, r["value"]), acc)
      r = Regex.named_captures(~r/^'(?<value>[^']*)'::jsonb(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :default, r["value"]), acc)
      r = Regex.named_captures(~r/^'(?<value>[^']*)'::json(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :default, r["value"]), acc)
      r = Regex.named_captures(~r/^'(?<value>[^']*)'::integer\[\](?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :default, r["value"]), acc)
      r = Regex.named_captures(~r/^TRUE(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :default, true), acc)
      r = Regex.named_captures(~r/^FALSE(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :default, false), acc)
      r = Regex.named_captures(~r/^(?<value>[^ ,]+)(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.put(data, :default, r["value"]), acc)
      true ->
        raise ParseError, message: "error default: #{inspect field} #{inspect data} #{inspect acc}"
    end
  end

  def parse_constraint(field, data, acc) do
    cond do
      r = Regex.named_captures(~r/^(?<name>\w+) (?<value>[^,]+)(?<rest>.*)/i, field) ->
        parse_fields(r["rest"], Map.merge(data, %{name: r["name"], value: r["value"]}), acc)
      true ->
        raise ParseError, message: "error constraint: #{inspect field} #{inspect data} #{inspect acc}"
    end
  end

end
