defmodule EctoExtractMigrations.Type do

  alias EctoExtractMigrations.ParseError

  @app :ecto_extract_migrations

  def create_migration(data, bindings) do
    Mix.shell().info("#{data[:type]} #{data[:name]}")

    schema = data.schema
    name = data.name
    bindings = Keyword.merge(bindings, [
      name: name,
      schema: schema,
      module_name: "#{Macro.camelize(schema)}.#{Macro.camelize(name)}",
      sql: data[:sql]
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "type.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

  @doc "Parse line of SQL"
  @spec parse_sql_line({String.t(), non_neg_integer}, {fun() | nil, list() | nil, list()}) :: {fun(), list(), list()}
  def parse_sql_line({line, index}, {_fun, local, global}) do
    # Mix.shell().info("create_table> #{line} #{inspect local}")
    local = local || []

    line = String.trim(line)

    if Regex.match?(~r/\);$/, line) do
      local = Enum.reverse([line | local])
      sql = Enum.join(local)

      case parse_sql(sql) do
        {:ok, data} ->
          {nil, nil, [data | global]}
        {:error, reason} ->
          raise ParseError, line: index, message: reason
      end
    else
      {&parse_sql_line/2, [line | local], global}
    end
  end

# CREATE TYPE public.case_payment_status AS ENUM (
#     'paid',
#     'unpaid',
#     'partial'
# );

  @doc "Parse complete SQL statement"
  @spec parse_sql(String.t()) :: {:ok, Map.t} | {:error, String.t()}
  def parse_sql(sql) do
    # case Regex.named_captures(~r/\s*CREATE\s+TABLE\s+(?<table>[\w\."]+)\s+\((?<fields>.*)\);$/i, sql) do
    case Regex.named_captures(~r/^CREATE\s+TYPE\s+(?<name>[\w\."]+)\s+AS (?<base>[^ ]+)\s+\((?<fields>.*)\);$/i, sql) do
      nil ->
        {:error, "Could not match CREATE TYPE: #{sql}"}
      data ->
        field_data = Regex.split(~r/\s*,\s*/, data["fields"])
        {schema, name} = parse_name(data["name"])
        {:ok, %{type: :type, sql: sql, schema: schema, name: name, base: data["base"], fields: field_data}}
    end
  end

  def parse_name(name) when is_binary(name), do: parse_name(String.split(name, "."))
  def parse_name([schema, name]), do: parse_name({schema, name})
  def parse_name([name]), do: parse_name({"public", name})
  def parse_name({schema, "\"" <> name}), do: {schema, String.trim(name, "\"")}
  def parse_name(value), do: value

  @spec parse(String.t()) :: {:ok, Map.t()} | {:error, String.t()}
  def parse(sql) do
    case Regex.named_captures(~r/^CREATE\s+TYPE\s+(?<name>[\w\."]+)\s+AS (?<base>[^ ]+)\s+\((?<fields>.*)\);$/i, sql) do
      nil ->
        {:error, "Parse error: #{sql}"}
      data ->
        field_data = Regex.split(~r/\s*,\s*/, data["fields"])
        {schema, name} = parse_name(data["name"])
        {:ok, %{type: :type, sql: sql, schema: schema, name: name, base: data["base"], fields: field_data}}
    end
  end
end
