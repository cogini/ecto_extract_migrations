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
    table_name = EctoExtractMigrations.format_table_name(data.table)
    Enum.map(Map.get(data, :constraints, []), &(format_constraint(&1, table_name)))
  end

  def format_constraint(opts, table) do
    ~s|constraint("#{table}", :#{opts.name}, check: "#{opts.check}")|
  end

end
