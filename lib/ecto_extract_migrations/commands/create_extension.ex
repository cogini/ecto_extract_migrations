defmodule EctoExtractMigrations.Commands.CreateExtension do
  @app :ecto_extract_migrations

  def type, do: :create_extension

  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateExtension
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateExtension
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateExtension

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, bindings)
  def file_name(%{name: [schema, name]}, _bindings), do: "extension_#{schema}_#{name}.exs"
  def file_name(%{name: name}, _bindings), do: "extension_#{name}.exs"

  @spec migration(map, Keyword.t) :: {:ok, binary} | {:error, term}
  def migration(data, bindings) do
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
