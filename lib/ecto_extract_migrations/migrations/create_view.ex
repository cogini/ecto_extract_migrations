defmodule EctoExtractMigrations.Migrations.CreateView do

  @app :ecto_extract_migrations

  def file_name(prefix, %{name: name}, _bindings) do
    "#{prefix}_view_#{name}.exs"
  end

  def migration(data, bindings) do
    Mix.shell().info("view #{data[:name]}")

    [schema, name] = data.name
    bindings = Keyword.merge(bindings, [
      name: name,
      schema: schema,
      module_name: "#{Macro.camelize(schema)}.#{Macro.camelize(name)}",
      sql: data[:sql]
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "view.eex")
    {:ok, migration} = EctoExtractMigrations.eval_template(template_path, bindings)
    migration
  end
end
