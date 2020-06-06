defmodule EctoExtractMigrations.Migrations.CreateExtension do

  @app :ecto_extract_migrations

  def file_name(prefix, %{schema: schema, name: name}, _bindings) do
    "#{prefix}_extension_#{schema}_#{name}.exs"
  end

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
    {:ok, migration} = EctoExtractMigrations.eval_template(template_path, bindings)
    migration
  end

end
