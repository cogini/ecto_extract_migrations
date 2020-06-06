defmodule EctoExtractMigrations.Migrations.Default do
  alias EctoExtractMigrations.Execute
  # %{
  #   action: :set_default,
  #   table: ["chat", "assignment"],
  #   column: "id",
  #   default: {:fragment, "nextval('chat.assignment_id_seq'::regclass)"}
  # }
  #
  # ALTER TABLE ONLY chat.assignment
  #     ALTER COLUMN id SET DEFAULT nextval('chat.assignment_id_seq'::regclass);

  def file_name(prefix, %{table: [schema, table], column: column}, _bindings) do
    "#{prefix}_alter_table_default_#{schema}_#{table}_#{column}.exs"
  end

  def migration(data, bindings) do
    module_name = module_name(data, bindings)
    Execute.create_migration(module_name, data.sql)
  end

  @doc "Create module name based on data"
  def module_name(%{table: [schema, table], column: column}, bindings) do
    [bindings[:repo], "migrations", "alter_table", "default"] ++ [schema, table, column]
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end
end
