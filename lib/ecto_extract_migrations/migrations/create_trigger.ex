defmodule EctoExtractMigrations.Migrations.CreateTrigger do
  alias EctoExtractMigrations.Execute

  # https://www.postgresql.org/docs/current/sql-droptrigger.html

  # %{name: "chat_message_update"}
  # CREATE TRIGGER chat_message_update BEFORE UPDATE ON chat.message FOR EACH ROW EXECUTE PROCEDURE public.chat_update_timestamp();

  def file_name(prefix, %{name: name}, _bindings) do
    "#{prefix}_create_trigger_#{name}.exs"
  end

  def migration(data, bindings) do
    module_name = module_name(data, bindings)
    Execute.create_migration(module_name, data.sql)
  end

  @doc "Create module name based on data"
  def module_name(%{name: name}, bindings) do
    [bindings[:repo], "migrations", "create_trigger"] ++ [name]
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end
end
