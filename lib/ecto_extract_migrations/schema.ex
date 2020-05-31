defmodule EctoExtractMigrations.Schema do

  alias EctoExtractMigrations.ParseError
  alias EctoExtractMigrations.CreateSchema

  @app :ecto_extract_migrations

  def create_migration(data, bindings) do
    Mix.shell().info("#{data[:type]} #{data[:name]}")

    schema = data.schema
    bindings = Keyword.merge(bindings, [
      schema: schema,
      module_name: Macro.camelize(schema)
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "schema.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

  @doc "Parse line of SQL"
  @spec parse_sql_line({String.t(), non_neg_integer}, {fun() | nil, list() | nil, list()}) :: {fun(), list(), list()}
  def parse_sql_line({line, _index}, {_fun, _local, global}) do
    sql = String.trim(line)

    case CreateSchema.parse(sql) do
      {:ok, [{:name, name}], _, _, _, _} ->
        {nil, nil, [%{type: :schema, sql: sql, schema: name} | global]}
      {:error, reason, _, _, _, _} ->
        raise ParseError, message: "Parse error: #{reason}"
    end
  end

end
