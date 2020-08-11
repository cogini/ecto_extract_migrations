defmodule EctoExtractMigrations.Migrations.CreateIndex do
  @app :ecto_extract_migrations

  def file_name(prefix, %{name: name}, _bindings) do
    "#{prefix}_index_#{name}.exs"
  end

  def migration(data, bindings) do
    [schema, table] = data.table_name

    table_name = ~s|"#{table}"|

    opts = [
      name: data[:name],
      unique: data[:unique],
      concurrently: data[:concurrently],
      using: data[:using],
      prefix: table_opt_prefix(data),
      where: data[:where],
      include: data[:include],
    ]

   opts = opts
      |> Enum.reject(fn {_key, value} -> value == nil end)
      |> Enum.map(&format_opt/1)
      |> Enum.join(", ")

    index_args = Enum.join([table_name, format_key(data.key)] ++ [opts], ", ")

    # :name - the name of the index. Defaults to "#{table}_#{column}_index".
    # :unique - indicates whether the index should be unique. Defaults to false.
    # :concurrently - indicates whether the index should be created/dropped concurrently.
    # :using - configures the index type.
    # :prefix - specify an optional prefix for the index.
    # :where - specify conditions for a partial index.
    # :include - specify fields for a covering index. This is not supported by all databases. For more information on PostgreSQL support, please read the official docs.

    bindings = Keyword.merge(bindings, [
      module_name: module_name(data, bindings),
      index_args: index_args,
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "index.eex")
    {:ok, migration} = EctoExtractMigrations.eval_template(template_path, bindings)
    migration
  end

  @doc "Set prefix opt if schema is not public"
  def table_opt_prefix(%{name: value}) when is_binary(value), do: nil
  def table_opt_prefix(%{name: ["public", _table]}), do: nil
  def table_opt_prefix(%{name: [schema, _table]}), do: schema

  def module_name(%{name: name}, bindings) do
    [bindings[:repo], "migrations", "create_index"] ++ [name]
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end

  def format_opt({key, value}) when is_binary(value) do
    value = escape(value)
    if String.contains?(value, ~s(")) do
      ~s|#{key}: """\n#{value}\n"""|
    else
      ~s|#{key}: "#{value}"|
    end
  end
  def format_opt({key, value}), do: "#{key}: #{value}"

  def format_key(values) do
    value =
      values
      |> Enum.map(&format_column/1)
      |> Enum.join(", ")
    "[" <> value <> "]"
  end

  def escape(value), do: String.replace(value, "\\", "\\\\")

  def format_column(value) when is_atom(value), do: ~s|:#{value}|
  def format_column(value) when is_binary(value), do: ~s|"#{value}"|
end
