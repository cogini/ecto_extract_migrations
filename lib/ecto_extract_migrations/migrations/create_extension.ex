defmodule EctoExtractMigrations.Migrations.CreateExtension do

  @app :ecto_extract_migrations

  @spec file_name(binary, map, Keyword.t) :: binary
  def file_name(prefix, %{schema: schema, name: name}, _bindings) do
    "#{prefix}_extension_#{schema}_#{name}.exs"
  end

  @spec migration(map, Keyword.t) :: {:ok, binary} | {:error, term}
  def migration(data, bindings) do
    Mix.shell().info("#{inspect data}")

    name = data.name
    schema = data.schema

    bindings = Keyword.merge(bindings, [
      name: name,
      schema: schema,
      module_name: "#{Macro.camelize(schema)}.#{Macro.camelize(name)}",
      sql: data[:sql]
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "extension.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

end
