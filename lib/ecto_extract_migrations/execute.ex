defmodule EctoExtractMigrations.Execute do
  @moduledoc "Create migration which uses execute to run raw SQL"

  def create_migration(module_name, up_sql, down_sql) do
    ast = quote do
      defmodule unquote(module_name) do
        use Ecto.Migration

        def change do
          execute(unquote(up_sql), unquote(down_sql))
        end
      end
    end
    Macro.to_string(ast)
  end

  def create_migration(module_name, up_sql) do
    ast = quote do
      defmodule unquote(module_name) do
        use Ecto.Migration

        def up do
          execute(unquote(up_sql))
        end
      end
    end
    Macro.to_string(ast)
  end
end
