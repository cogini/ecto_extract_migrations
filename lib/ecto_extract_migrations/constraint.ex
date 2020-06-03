defmodule EctoExtractMigrations.Constraint do
  @app :ecto_extract_migrations

  def create_migration(data, bindings) do
    bindings = Keyword.merge(bindings, [
      module_name: EctoExtractMigrations.format_module_name(data.table),
      constraints: format_constraints(data)
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "constraint.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

  def format_constraints(data) do
    Enum.map(Map.get(data, :constraints, []), &(format_constraint(&1, data.table)))
  end

  def format_constraint(opts, table) do
    table_name = format_table_name(table)
    ~s|constraint(#{table_name}, :#{opts.name}, check: "#{opts.check}")|
  end

  def format_table_name(table) when is_binary(table), do: ~s|"#{table}"|
  def format_table_name([schema, table]), do: ~s|"#{schema}.#{table}"|
end
