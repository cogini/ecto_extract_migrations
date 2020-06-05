defmodule EctoExtractMigrations.Reference do

  # %{action: :add_table_constraint, column: ["user_id"],
  #   constraint_name: "assignment_care_taker_id_fkey",
  #   references_column: ["id"], references_table: ["chat", "user"], table: ["chat", "assignment"], type: :foreign_key}

  @doc "Convert alter table data structure into Ecto migration references() args"
  def references_args(data) do
    Mix.shell().info("data: #{inspect data}")

    [_schema, table] = data[:table]
    opts =
      [:constraint_name, :references_column, :references_table, :on_delete, :on_update]
      |> Enum.map(&(map_reference({&1, data[&1]})))
      |> Enum.reject(fn {_key, value} -> value == nil end)
      # |> Enum.map(&stringify/1)
    # Enum.join([stringify(table)] ++ opts, ", ")

    ast = quote do
      references(unquote(table), unquote(opts))
    end
    Macro.to_string(ast)
  end

  def map_reference({:constraint_name, value}), do: {:name, value}
  def map_reference({:references_column, [value]}), do: {:column, value}
  def map_reference({:references_table, ["public", _table]}), do: {:prefix, nil}
  def map_reference({:references_table, [schema, _table]}), do: {:prefix, schema}
  def map_reference({:on_delete, :cascade}), do: {:on_delete, :delete_all}
  def map_reference({:on_delete, :restrict}), do: {:on_delete, :restrict}
  def map_reference({:on_delete, :set_null}), do: {:on_delete, :nilify_all}
  def map_reference({:on_delete, _}), do: {:on_delete, nil}
  def map_reference({:on_update, :cascade}), do: {:on_update, :delete_all}
  def map_reference({:on_update, :restrict}), do: {:on_update, :restrict}
  def map_reference({:on_update, :set_null}), do: {:on_update, :nilify_all}
  def map_reference({:on_update, _}), do: {:on_update, nil}

  # def stringify({key, value}) when is_atom(value), do: ~s|#{key}: #{inspect(value)}|
  # def stringify({key, value}) when is_binary(value), do: ~s|#{key}: "#{value}"|
  # def stringify(value) when is_binary(value), do: ~s|"#{value}"|
end
