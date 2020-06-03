defmodule EctoExtractMigrations.Table do
  @app :ecto_extract_migrations

  def create_migration(data, bindings) do
    Mix.shell().info("create_migration> #{inspect data} #{inspect bindings}")
    columns_data = data[:columns]
    Mix.shell().info("create_migration> #{inspect columns_data} #{inspect has_pk(columns_data)}")

    table_name = format_table_name(data.name)
    table_opts = table_name <> format_pk(has_pk(columns_data))
    columns = Enum.map(columns_data, &format_column/1)

    bindings = Keyword.merge(bindings, [
      module_name: EctoExtractMigrations.format_module_name(data.name),
      table_opts: table_opts,
      columns: columns,
    ])

    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "table.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

  def format_table_name(["public", name]), do: ~s|"#{name}"|
  def format_table_name([schema, name]), do: ~s|"#{name}", prefix: "#{schema}"|

  def format_pk(true), do: ", primary_key: false"
  def format_pk(false), do: ""

  def has_pk(value) when is_list(value), do: Enum.any?(value, &has_pk/1)
  def has_pk(%{name: "id"}), do: true
  def has_pk(%{name: "rowid"}), do: true
  def has_pk(%{primary_key: true}), do: true
  def has_pk(_), do: false

  def munge_column(%{type: type, is_array: true} = value) do
    value = %{value | type: {:array, type}}
    Map.drop(value, [:is_array])
  end
  def munge_column(value), do: value

  def starts_with_number(<<first::8, _::binary>>) when first >= ?0 and first <= ?9, do: true
  def starts_with_number(_), do: false

  def format_column(column) do
    column = munge_column(column)
    values = for key <- [:name, :type, :primary_key, :default, :null, :size, :precision, :scale],
      Map.has_key?(column, key), do: format_column(key, column[key])
    "      add #{Enum.join(values, ", ")}\n"
  end

  def format_column(:name, value) when is_atom(value), do: inspect(value)
  def format_column(:name, value) when is_binary(value) do
    if String.contains?(value, " ") or starts_with_number(value) do
      ~s(:"#{value}")
    else
      ":#{value}"
    end
  end

  def format_column(:type, value) when is_list(value), do: ~s(:"#{Enum.join(value, ".")}")
  def format_column(:type, value), do: inspect(value)
  def format_column(:size, [precision, scale]), do: "precision: #{precision}, scale: #{scale}"
  def format_column(:default, {:fragment, value}), do: ~s|default: fragment("#{value}")|
  def format_column(:default, value) when is_integer(value), do: "default: #{value}"
  def format_column(:default, value) when is_float(value), do: "default: #{value}"
  def format_column(:default, value) when is_boolean(value), do: "default: #{value}"
  def format_column(:default, value) when is_binary(value) do
    value = escape(value)
    if String.contains?(value, ~s(")) do
      ~s(default: """\n#{value}\n""")
    else
      ~s(default: "#{value}")
    end
  end
  def format_column(key, value), do: "#{key}: #{value}"

  def escape(value), do: String.replace(value, "\\", "\\\\")

end
