defmodule Mix.Tasks.Ecto.Extract.Migrations do
  @moduledoc """
  Create Ecto migration files from database schema.

  ## Command line options

    * `--migrations-path` - target dir for migrations, defaults to "priv/repo/migrations".
    * `--sql-file` - target dir for migrations, defaults to "priv/repo/migrations".
    * `--repo` - Name of repo

  ## Usage

      # Copy default templates into your project
      mix systemd.init
  """
  @shortdoc "Initialize template files"

  alias Mix.Tasks.Ecto.Extract.Migrations.CreateTable

  # Directory where output migration files go
  # TODO: this should be generated from repo name
  @migrations_path "priv/repo/migrations"

  @app :ecto_extract_migrations

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    opts = [
      strict: [
        migrations_path: :string,
        sql_file: :string,
        repo: :string,
        verbose: :boolean
      ]
    ]
    {overrides, _} = OptionParser.parse!(args, opts)

    migrations_path = overrides[:migrations_path] || @migrations_path
    sql_file = overrides[:sql_file]
    repo = overrides[:repo] || "Repo"

    :ok = File.mkdir_p(migrations_path)

    {_, _, results} =
      sql_file
      |> File.stream!
      |> Stream.with_index
      |> Enum.reduce({nil, nil, []}, &dispatch/2)

    objects = Enum.reverse(results)
    Mix.shell().info("#{inspect List.first(objects)}")

    for data <- objects do
      Mix.shell().info("SQL: #{data[:sql]}}")
      Mix.shell().info("#{data[:type]} #{data[:table]} #{inspect data[:fields]}")
      {schema, name} = parse_name(data[:table])
      module_name = "#{Macro.camelize(schema)}.#{Macro.camelize(name)}"

      bindings = [
        repo: repo,
        module_name: module_name,
        table: name,
        prefix: format_prefix(schema),
        primary_key: format_primary_key(data[:fields]),
        fields: Enum.map(data[:fields], &format_field/1)
      ]

      template_dir = Application.app_dir(@app, ["priv", "templates"])
      template_path = Path.join(template_dir, "create_table.eex")
      {:ok, migration} = eval_template(template_path, bindings)

      Mix.shell().info(migration)
    end

  end

  def dispatch({line, index}, {nil, _local, global} = state) do
    # Mix.shell().info("dispatch> #{line}")
    cond do
      String.match?(line, ~r/^\s*--/) ->  # skip comments
        state
      String.match?(line, ~r/^\s*$/) ->   # skip blank lines
        state
      String.match?(line, ~r/^\s*CREATE TABLE/i) ->
        CreateTable.parse_sql_line({line, index}, {nil, [], global})
      true ->
        state
    end
  end
  def dispatch({line, index}, {fun, _local, _global} = state), do: fun.({line, index}, state)


  @doc "Evaluate template file with bindings"
  @spec eval_template(Path.t(), Keyword.t()) :: {:ok, binary} | {:error, term}
  def eval_template(template_file, bindings \\ []) do
    {:ok, EEx.eval_file(template_file, bindings, trim: true)}
  rescue
    e ->
      {:error, {:template, e}}
  end

  def parse_name(name) when is_binary(name), do: parse_name(String.split(name, "."))
  def parse_name([schema, name]), do: {schema, name}
  def parse_name([name]), do: {"public", name}

  def format_prefix("public"), do: ""
  def format_prefix(name), do: ", prefix: \"#{name}\""

  def format_primary_key(fields) do
    if Enum.any?(fields, &has_primary_key/1) do
      ""
    else
      ", primary_key: false"
    end
  end

  def has_primary_key(%{primary_key: true}), do: true
  def has_primary_key(%{name: "id"}), do: true
  def has_primary_key(_), do: false

  def format_field(field) do
    values = for key <- [:name, :type, :size, :precision, :scale, :default, :null],
      Map.has_key?(field, key), do: format_field(key, field[key])
    "      add #{Enum.join(values, ", ")}\n"
  end

  def format_field(:name, value), do: ":#{value}"
  def format_field(:type, value), do: ":#{value}"
  def format_field(:default, value) when is_integer(value), do: "default: #{value}"
  def format_field(:default, value) when is_float(value), do: "default: #{value}"
  def format_field(:default, value) when is_boolean(value), do: "default: #{value}"
  def format_field(:default, value) when value in ["", "{}", "[]"] do
    ~s(default: "#{value}")
  end
  def format_field(:default, value) when is_binary(value) do
    ~s|default: fragment("#{value}")|
  end
  def format_field(key, value), do: "#{key}: #{value}"

  defmodule ParseError do
    defexception message: "default message"
  end
end
