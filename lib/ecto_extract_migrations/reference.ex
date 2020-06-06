defmodule EctoExtractMigrations.Reference do

  # %{action: :add_table_constraint, column: ["user_id"],
  #   constraint_name: "assignment_care_taker_id_fkey",
  #   references_column: ["id"], references_table: ["chat", "user"], table: ["chat", "assignment"], type: :foreign_key}

  @doc "Convert alter table data structure into Ecto migration references()"
  def column_reference(data) do
    [_schema, table] = data[:references_table]

    keys = [:constraint_name, :references_column, :references_table, :on_delete, :on_update]
    opts = for key <- keys, Map.has_key?(data, key), do: {key, data[key]}
    opts =
      opts
      |> Enum.map(&map_value/1)
      |> Enum.reject(fn {_key, value} -> value == nil end)

    ast = quote do
      references(unquote(table), unquote(opts))
    end
    Macro.to_string(ast)
  end

  defp map_value({:constraint_name, value}), do: {:name, value}
  defp map_value({:references_column, [value]}), do: {:column, value}
  defp map_value({:references_table, ["public", _table]}), do: {:prefix, nil}
  defp map_value({:references_table, [schema, _table]}), do: {:prefix, schema}
  defp map_value({:on_delete, :cascade}), do: {:on_delete, :delete_all}
  defp map_value({:on_delete, :restrict}), do: {:on_delete, :restrict}
  defp map_value({:on_delete, :set_null}), do: {:on_delete, :nilify_all}
  defp map_value({:on_delete, _}), do: {:on_delete, nil}
  defp map_value({:on_update, :cascade}), do: {:on_update, :delete_all}
  defp map_value({:on_update, :restrict}), do: {:on_update, :restrict}
  defp map_value({:on_update, :set_null}), do: {:on_update, :nilify_all}
  defp map_value({:on_update, _}), do: {:on_update, nil}
end
