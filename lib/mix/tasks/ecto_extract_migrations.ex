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

    bindings = [
      repo: repo,
    ]

    for data <- objects do
      Mix.shell().info("SQL: #{data[:sql]}")
      {:ok, migration} = CreateTable.create_migration(data, bindings)
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
        CreateTable.parse_sql_line({line, index}, {nil, nil, global})
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

  defmodule ParseError do
    defexception message: "default message"
  end
end
