defmodule EctoExtractMigrations.Reference do

  @doc "Convert alter table data structure into Ecto migration references() args"
  def references_args(data) do
    name = data[:constraint_name]
    opts =
      [:references_column, :references_table, :on_delete, :on_update]
      |> Enum.map(&(map_reference({&1, data[&1]})))
      |> Enum.reject(fn {_key, value} -> value == nil end)
      |> Enum.map(&stringify/1)

    Enum.join([stringify(name)] ++ opts, ", ")
  end

  def map_reference({:references_column, [value]}), do: {:column, value}
  def map_reference({:references_table, ["public", _table]}), do: {:prefix, nil}
  def map_reference({:references_table, [schema, _table]}), do: {:prefix, schema}
  def map_reference({:on_delete, :cascade}), do: {:on_delete, :delete_all}
  def map_reference({:on_delete, :restrict}), do: {:on_delete, :restrict}
  def map_reference({:on_delete, :set_null}), do: {:on_delete, :nilify_all}
  def map_reference({:on_update, :cascade}), do: {:on_update, :delete_all}
  def map_reference({:on_update, :restrict}), do: {:on_update, :restrict}
  def map_reference({:on_update, :set_null}), do: {:on_update, :nilify_all}

  def stringify({key, value}) when is_atom(value), do: ~s|#{key}: #{inspect(value)}|
  def stringify({key, value}) when is_binary(value), do: ~s|#{key}: "#{value}"|
  def stringify(value) when is_binary(value), do: ~s|"#{value}"|
end
