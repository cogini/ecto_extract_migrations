defmodule Mix.Tasks.Ecto.Extract.Migrations do
  defmodule ParseError do
    defexception message: "default message"
  end

  @moduledoc """
  Create Ecto migration files from database schema.

  ## Command line options

    * `--migrations-path` - target dir for migrations, defaults to "priv/repo/migrations".
    * `--sql-file` - target dir for migrations, defaults to "priv/repo/migrations".
    * `--repo` - Name of repo

  ## Usage

      # Copy default templates into your project
      mix systemd.init
  """
  @shortdoc "Initialize template files"

  # Directory where output migration files go
  # TODO: this should be generated from repo name
  @migrations_path "priv/repo/migrations"

  @app :ecto_extract_migrations

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    opts = [
      strict: [
        migrations_path: :string,
        sql_file: :string,
        repo: :string,
        verbose: :boolean
      ]
    ]
    {overrides, _} = OptionParser.parse!(args, opts)

    migrations_path = overrides[:migrations_path] || @migrations_path
    sql_file = overrides[:sql_file]
    repo = overrides[:repo] || "Repo"

    :ok = File.mkdir_p(migrations_path)

    {_, _, results} =
      sql_file
      |> File.stream!
      |> Stream.map(&String.trim_trailing/1)
      |> Stream.reject(&String.match?(&1, ~r/^\s*--/)) # skip comments
      |> Stream.reject(&String.match?(&1, ~r/^\s*$/))  # skip blank lines
      # |> Stream.each(&Mix.shell().info/1)
      |> Enum.reduce({nil, nil, []}, &dispatch/2)

    objects = Enum.reverse(results)
    Mix.shell().info("#{inspect List.first(objects)}")
    
    for data <- objects do
      Mix.shell().info("SQL: #{data[:sql]}}")
      Mix.shell().info("#{data[:type]} #{data[:table]} #{inspect data[:fields]}")
      {schema, name} = parse_name(data[:table])
      module_name = "#{Macro.camelize(schema)}.#{Macro.camelize(name)}"

      bindings = [
        repo: repo,
        module_name: module_name,
        table: name,
        prefix: format_prefix(schema),
        primary_key: format_primary_key(data[:fields]),
        fields: Enum.map(data[:fields], &format_field/1)
      ]

      template_dir = Application.app_dir(@app, ["priv", "templates"])
      template_path = Path.join(template_dir, "create_table.eex")
      {:ok, migration} = eval_template(template_path, bindings)

      Mix.shell().info(migration)
    end

  end

  def dispatch(line, {nil, _local, global} = state) do
    # Mix.shell().info("dispatch> #{line}")
    cond do
      String.match?(line, ~r/^\s*CREATE TABLE/) ->
          create_table(line, {&create_table/2, [], global})
        true ->
          state
    end
  end
  def dispatch(line, {fun, _local, _global} = state), do: fun.(line, state)

  # def create_table(line = "CREATE TABLE" <> _rest, {_fun, local, _global} = state) do
  #   Mix.shell().info("create_table> #{line} #{inspect local}")
  #   state
  # end
  def create_table(line, {fun, local, global}) do
    # Mix.shell().info("create_table> #{line} #{inspect local}")

    line = String.trim(line)

    if Regex.match?(~r/\);/, line) do
      local = Enum.reverse([line | local])
      sql = Enum.join(local)

      # Mix.shell().info("create_table> #{sql}")

      case Regex.named_captures(~r/\s*CREATE\s+TABLE\s+(?<table>[\w\."]+)\s+\((?<fields>.*)\);$/, sql) do
        nil ->
          raise ParseError, message: "create table: #{sql}"
        data ->
          # Mix.shell().info("create_table> SQL #{sql}")
          field_data = parse_fields(data["fields"] <> ",", %{}, [])
          # Mix.shell().info("create_table> table: #{data["table"]} #{inspect field_data}")
          {nil, nil, [%{type: :create_table, sql: sql, table: data["table"], fields: field_data} | global]}
      end
    else
      {fun, [line | local], global}
    end
  end

  @doc "Evaluate template file with bindings"
  @spec eval_template(Path.t(), Keyword.t()) :: {:ok, binary} | {:error, term}
  def eval_template(template_file, bindings \\ []) do
    {:ok, EEx.eval_file(template_file, bindings, trim: true)}
  rescue
    e ->
      {:error, {:template, e}}
  end

  def format_prefix("public"), do: ""
  def format_prefix(name), do: ", prefix: \"#{name}\""

  def format_primary_key(fields) do
    if Enum.any?(fields, &has_primary_key/1) do
      ""
    else
      ", primary_key: false"
    end
  end

  def has_primary_key(%{primary_key: true}), do: true
  def has_primary_key(%{name: "id"}), do: true
  def has_primary_key(_), do: false

  def format_field(field) do
    values = for key <- [:name, :type, :size, :precision, :scale, :default, :null],
      Map.has_key?(field, key), do: format_field(key, field[key])
    "      add #{Enum.join(values, ", ")}\n"
  end

  def format_field(:name, value), do: ":#{value}"
  def format_field(:type, value), do: ":#{value}"
  def format_field(:default, value) when is_integer(value), do: "default: #{value}"
  def format_field(:default, value) when is_float(value), do: "default: #{value}"
  def format_field(:default, value) when is_boolean(value), do: "default: #{value}"
  def format_field(:default, value) when value in ["", "{}", "[]"] do
    ~s(default: "#{value}")
  end
  def format_field(:default, value) when is_binary(value) do
    ~s|default: fragment("#{value}")|
  end
  def format_field(key, value), do: "#{key}: #{value}"

  def parse_name(name) when is_binary(name), do: parse_name(String.split(name, "."))
  def parse_name([schema, name]), do: {schema, name}
  def parse_name([name]), do: {"public", name}

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
