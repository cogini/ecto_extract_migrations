defmodule EctoExtractMigrations.Migrations.CreateTable do
  # @app :ecto_extract_migrations

  def file_name(prefix, %{name: [schema, table]}, _bindings) do
    "#{prefix}_table_#{schema}_#{table}.exs"
  end

  @doc "Create module name based on data"
  def module_name(%{name: name}, bindings) when is_list(name) do
    [bindings[:repo], "migrations", "table"] ++ name
    |> Enum.map(&Macro.camelize/1)
    |> Module.concat()
  end

  # def create_migration(data, bindings) do
  #   columns_data = data[:columns]
  #
  #   table_name = format_table_name(data.name)
  #   table_opts = table_name <> format_pk(has_pk(columns_data))
  #   columns = Enum.map(columns_data, &format_column/1)
  #
  #   bindings = Keyword.merge(bindings, [
  #     module_name: EctoExtractMigrations.format_module_name(data.name),
  #     table_opts: table_opts,
  #     columns: columns,
  #   ])
  #
  #   template_dir = Application.app_dir(@app, ["priv", "templates"])
  #   template_path = Path.join(template_dir, "table.eex")
  #   EctoExtractMigrations.eval_template(template_path, bindings)
  # end

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

  # defp nil_value({_, nil}), do: true
  # defp nil_value(_), do: false

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

  # def format_table_name(["public", name]), do: ~s|"#{name}"|
  # def format_table_name([schema, name]), do: ~s|"#{name}", prefix: "#{schema}"|

  # def format_pk(true), do: ", primary_key: false"
  # def format_pk(false), do: ""


  # def format_column(column) do
  #   column = munge_column(column)
  #   values = for key <- [:name, :type, :primary_key, :default, :null, :size, :precision, :scale],
  #     Map.has_key?(column, key), do: format_column(key, column[key])
  #   "      add #{Enum.join(values, ", ")}\n"
  # end

  # def format_column(:name, value) when is_atom(value), do: inspect(value)
  # def format_column(:name, value) when is_binary(value) do
  #   if String.contains?(value, " ") or starts_with_number(value) do
  #     ~s(:"#{value}")
  #   else
  #     ":#{value}"
  #   end
  # end

  # def format_column(:type, value) when is_list(value), do: ~s(:"#{Enum.join(value, ".")}")
  # def format_column(:type, value), do: inspect(value)
  # def format_column(:size, [precision, scale]), do: "precision: #{precision}, scale: #{scale}"
  # def format_column(:default, {:fragment, value}), do: ~s|default: fragment("#{value}")|
  # def format_column(:default, value) when is_integer(value), do: "default: #{value}"
  # def format_column(:default, value) when is_float(value), do: "default: #{value}"
  # def format_column(:default, value) when is_boolean(value), do: "default: #{value}"
  # def format_column(:default, value) when is_binary(value) do
  #   value = escape(value)
  #   if String.contains?(value, ~s(")) do
  #     ~s(default: """\n#{value}\n""")
  #   else
  #     ~s(default: "#{value}")
  #   end
  # end
  # def format_column(key, value), do: "#{key}: #{value}"

  # def escape(value), do: String.replace(value, "\\", "\\\\")

end
