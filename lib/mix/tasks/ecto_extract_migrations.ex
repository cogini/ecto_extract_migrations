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

  alias EctoExtractMigrations.Table
  alias EctoExtractMigrations.Schema
  alias EctoExtractMigrations.Type

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

    repo = overrides[:repo] || "Repo"
    repo_dir = Macro.underscore(repo)
    default_migrations_path = Path.join(["priv", repo_dir, "migrations"])
    migrations_path = overrides[:migrations_path] || default_migrations_path
    sql_file = overrides[:sql_file]

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

    objects = Enum.with_index(objects)

    for {data, index} <- objects do
      Mix.shell().info("SQL: #{data[:sql]}")
      prefix = to_string(:io_lib.format('~3..0b', [index]))
      case data.type do
        :table ->
          if data.table == "schema_migrations" do
            # schema_migrations is created by ecto.migrate itself
            Mix.shell().info("Skipping schema_migrations")
            :ok
          else
            {:ok, migration} = Table.create_migration(data, bindings)
            Mix.shell().info(migration)
            filename = Path.join(migrations_path, "#{prefix}_table_#{data.schema}_#{data.table}.exs")
            Mix.shell().info(filename)
            :ok = File.write(filename, migration)
          end
        :schema ->
          {:ok, migration} = Schema.create_migration(data, bindings)
          Mix.shell().info(migration)
          filename = Path.join(migrations_path, "#{prefix}_schema_#{data.schema}.exs")
          Mix.shell().info(filename)
          :ok = File.write(filename, migration)
        :type ->
          {:ok, migration} = Type.create_migration(data, bindings)
          Mix.shell().info(migration)
          filename = Path.join(migrations_path, "#{prefix}_type_#{data.schema}.exs")
          Mix.shell().info(filename)
          :ok = File.write(filename, migration)
      end
    end
  end

  def dispatch({line, index}, {nil, _local, global} = state) do
    # Mix.shell().info("dispatch> #{line}")
    cond do
      String.match?(line, ~r/^\s*--/) ->  # skip comments
        state
      String.match?(line, ~r/^\s*$/) ->   # skip blank lines
        state
      # String.match?(line, ~r/^\s*CREATE TABLE/i) ->
      String.match?(line, ~r/^CREATE TABLE/i) ->
        Table.parse_sql_line({line, index}, {nil, nil, global})
      # String.match?(line, ~r/^\s*CREATE SCHEMA/i) ->
      String.match?(line, ~r/^CREATE SCHEMA/i) ->
        Schema.parse_sql_line({line, index}, {nil, nil, global})
      String.match?(line, ~r/^CREATE TYPE/i) ->
        Type.parse_sql_line({line, index}, {nil, nil, global})
      true ->
        state
    end
  end
  def dispatch({line, index}, {fun, _local, _global} = state), do: fun.({line, index}, state)

end
