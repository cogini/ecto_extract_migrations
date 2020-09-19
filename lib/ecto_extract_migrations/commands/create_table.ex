defmodule EctoExtractMigrations.Commands.CreateTable do
  @moduledoc "CREATE TABLE"

  def type, do: :create_table
  defdelegate parse(sql), to: EctoExtractMigrations.Parsers.CreateTable
  defdelegate parse(sql, state), to: EctoExtractMigrations.Parsers.CreateTable
  defdelegate match(sql), to: EctoExtractMigrations.Parsers.CreateTable

  @spec file_name(map, Keyword.t) :: binary
  def file_name(data, bindings)
  def file_name(%{name: [schema, name]}, _bindings), do: "table_#{schema}_#{name}.exs"
  def file_name(%{name: name}, _bindings), do: "table_#{name}.exs"

  @doc "Create module name based on data"
  def module_name(%{name: name}, bindings) when is_list(name) do
    [bindings[:repo], "migrations", "table"] ++ name
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end

  def migration(data, bindings) do
    module_name = module_name(data, bindings)
    [_schema, table] = data.name

    opts = [
      prefix: table_opt_prefix(data),
      primary_key: table_opt_generate_primary_key(data),
    ]
    |> Enum.reject(fn {_key, value} -> value == nil end)

    # https://elixirforum.com/t/how-can-i-insert-an-ast-as-a-function-body/1227

    columns_ast = Enum.map(data.columns, &column_ast/1)

    ast = quote do
      defmodule unquote(module_name) do
        use Ecto.Migration

        def change do
          create table(unquote(table), unquote(opts)) do
            unquote_splicing(columns_ast)
          end
        end
      end
    end
    {:ok, Macro.to_string(ast)}
  end

  @doc "Set prefix opt if schema is not public"
  def table_opt_prefix(%{name: value}) when is_binary(value), do: nil
  def table_opt_prefix(%{name: ["public", _table]}), do: nil
  def table_opt_prefix(%{name: [schema, _table]}), do: schema

  @doc "Set primary_key opt if migration should generate a primary key id column"
  def table_opt_generate_primary_key(data) do
    if Enum.any?(data.columns, &has_pk/1) do
      false
    else
      # Default is true
      nil
    end
  end

  def column_ast(column) do
    column =  munge_column(column)
    column_name = String.to_atom(column.name)
    column_type = column_type(column.type)

    keys = [:primary_key, :default, :null, :size, :precision, :scale]
    opts = for key <- keys, Map.has_key?(column, key) do
      {key, column[key]}
    end
    |> Enum.reject(fn {_key, value} -> value == nil end)
    |> Enum.map(&column_value/1)

    quote do
      add unquote(column_name), unquote(column_type), unquote(opts)
    end
  end

  def munge_column(%{type: type, is_array: true} = value) do
    value = %{value | type: {:array, type}}
    Map.drop(value, [:is_array])
  end
  def munge_column(value), do: value

  def column_type(value) when is_list(value), do: String.to_atom(Enum.join(value, "."))
  def column_type(value), do: value

  def column_value({key, {:fragment, value}}) do
    ast = quote do
      fragment(unquote(value))
    end
    {key, ast}
  end
  def column_value(value), do: value

  def has_pk(value) when is_list(value), do: Enum.any?(value, &has_pk/1)
  def has_pk(%{name: "id"}), do: true
  def has_pk(%{name: "rowid"}), do: true
  def has_pk(%{primary_key: true}), do: true
  def has_pk(_), do: false

  def starts_with_number(<<first::8, _::binary>>) when first >= ?0 and first <= ?9, do: true
  def starts_with_number(_), do: false
end
