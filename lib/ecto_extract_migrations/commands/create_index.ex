defmodule EctoExtractMigrations.Commands.CreateIndex do
  @moduledoc "Handle CREATE INDEX."

  def type, do: :create_index
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateIndex
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateIndex
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateIndex

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, bindings)
  def file_name(%{name: name}, _bindings), do: "index_#{name}.exs"

  # %{key: [:member_id], name: "t_eligibility_member_id_idx", table_name: ["bnd", "t_eligibility"], using: "btree"}
  # CREATE INDEX t_eligibility_member_id_idx ON bnd.t_eligibility USING btree (member_id);

  def migration(data, bindings) do
    module_name = module_name(data, bindings)
    # table_name = table_name(data)
    [_prefix, table_name] = data.table_name

    # :name - the name of the index. Defaults to "#{table}_#{column}_index".
    # :unique - indicates whether the index should be unique. Defaults to false.
    # :concurrently - indicates whether the index should be created/dropped concurrently.
    # :using - configures the index type.
    # :prefix - specify an optional prefix for the index.
    # :where - specify conditions for a partial index.
    # :include - specify fields for a covering index. This is not supported by all databases. For more information on PostgreSQL support, please read the official docs.

    opts = [
      name: data[:name],
      unique: data[:unique],
      concurrently: data[:concurrently],
      using: data[:using],
      prefix: table_opt_prefix(data),
      where: data[:where],
      include: data[:include],
    ]
    |> Enum.reject(fn {_key, value} -> value == nil end)

    ast = quote do
      defmodule unquote(module_name) do
        use Ecto.Migration

        def change do
          create index(unquote(table_name), unquote(data.key), unquote(opts))
        end
      end
    end
    {:ok, Macro.to_string(ast)}
  end

  def module_name(%{name: name}, bindings) do
    [bindings[:repo], "migrations", "index"] ++ [name]
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end
  def module_name(%{table_name: table_name, key: key}, bindings) do
    [bindings[:repo], "migrations", "index"] ++ table_name ++ [key]
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end

  # Get schema prefix if it is not public
  defp table_opt_prefix(%{table_name: ["public", _table]}), do: nil
  defp table_opt_prefix(%{table_name: [schema, _table]}), do: schema
  defp table_opt_prefix(%{table_name: value}) when is_binary(value), do: nil

end
