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

    {_, results} =
      sql_file
      |> File.stream!
      |> Stream.with_index
      |> Enum.reduce({nil, []}, &extract_sql/2)

    sql = Enum.reverse(results)

    # Enum.each(sql, fn {type, idx, lines} -> Mix.shell().info("SQL #{idx}\n#{Enum.join(lines)}") end)
    Enum.each(sql, &parse_sql/1)

    # bindings = [
    #   repo: repo,
    # ]

    # objects = Enum.with_index(objects)

    # for {data, index} <- objects do
    #   Mix.shell().info("SQL: #{data[:sql]}")
    #   prefix = to_string(:io_lib.format('~3..0b', [index]))
    #   case data.type do
    #     :table ->
    #       if data.table == "schema_migrations" do
    #         # schema_migrations is created by ecto.migrate itself
    #         Mix.shell().info("Skipping schema_migrations")
    #         :ok
    #       else
    #         {:ok, migration} = Table.create_migration(data, bindings)
    #         Mix.shell().info(migration)
    #         filename = Path.join(migrations_path, "#{prefix}_table_#{data.schema}_#{data.table}.exs")
    #         Mix.shell().info(filename)
    #         :ok = File.write(filename, migration)
    #       end
    #     :schema ->
    #       {:ok, migration} = Schema.create_migration(data, bindings)
    #       Mix.shell().info(migration)
    #       filename = Path.join(migrations_path, "#{prefix}_schema_#{data.schema}.exs")
    #       Mix.shell().info(filename)
    #       :ok = File.write(filename, migration)
    #     :type ->
    #       {:ok, migration} = Type.create_migration(data, bindings)
    #       Mix.shell().info(migration)
    #       filename = Path.join(migrations_path, "#{prefix}_type_#{data.schema}.exs")
    #       Mix.shell().info(filename)
    #       :ok = File.write(filename, migration)
    #   end
    # end
  end

  @spec extract_sql({String.t(), non_neg_integer},
    {nil | {atom(), non_neg_integer, list(String.t())}, list(String.t())}) :: {term(), list(String.t())}
  def extract_sql({line, idx}, {nil, sql} = state) do
    cond do
      String.match?(line, ~r/^CREATE TABLE/i) ->
        {{:create_table, idx, ~r/;$/i, [line]}, sql}
      String.match?(line, ~r/^CREATE SCHEMA/i) ->
        {nil, [{:create_schema, idx, [line]} | sql]}
      String.match?(line, ~r/^CREATE TYPE/i) ->
        {{:create_type, idx, ~r/;$/, [line]}, sql}
      String.match?(line, ~r/^ALTER TABLE/i) ->
        if String.match?(line, ~r/;$/) do
          {nil, [{:alter_table, idx, [line]} | sql]}
        else
          {{:alter_table, idx, ~r/;$/, [line]}, sql}
        end
      true ->
        state
    end
  end
  def extract_sql({line, _idx}, {{type, start_idx, stop, lines}, sql}) do
    if String.match?(line, stop) do
      {nil, [{type, start_idx, Enum.reverse([line | lines])} | sql]}
    else
      {{type, start_idx, stop, [line | lines]}, sql}
    end
  end

  def parse_sql({type, idx, lines}) do
    sql = Enum.join(lines)
    # Mix.shell().info("SQL #{idx}\n#{sql}")

    {:ok, data} = apply(sql_parser(type), [sql])
    %{type: type, line: idx, sql: sql, data: data}
  end

  def sql_parser(:create_table), do: &EctoExtractMigrations.CreateTable.parse/1
  def sql_parser(:create_schema), do: &EctoExtractMigrations.CreateSchema.parse/1
  def sql_parser(:create_type), do: &EctoExtractMigrations.CreateType.parse/1
  def sql_parser(:alter_table), do: &EctoExtractMigrations.AlterTable.parse/1

end
