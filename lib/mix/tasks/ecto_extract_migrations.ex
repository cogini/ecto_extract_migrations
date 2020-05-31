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

  alias EctoExtractMigrations.Schema
  alias EctoExtractMigrations.Type
  alias EctoExtractMigrations.Table

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

    results =
      sql_file
      |> File.stream!
      |> Stream.with_index
      |> Stream.transform(nil, &collect_sql/2)
      |> Stream.map(&parse_sql/1)
      |> Enum.to_list

     bindings = [
       repo: repo,
     ]

     # TODO
     # merge alter table with table
     # constraints
     # CREATE VIEW

       # %{action: :add_constraint, constraint_name: "message_pkey", primary_key: ["id"], table: ["chat", "message"]}
     primary_keys =
       for {%{type: type, data: data}} <- results, type == :alter_table, data.action == :add_constraint, into: %{} do
         {data.table, data.primary_key}
       end

    for {%{type: type, sql: sql, data: data, idx: idx}, index} <- Enum.with_index(results) do
      Mix.shell().info("SQL #{type} #{idx} \n#{sql}\n#{inspect data}")
      prefix = to_string(:io_lib.format('~3..0b', [index]))
      case type do
        :create_table ->
          if data.name == ["public", "schema_migrations"] do
            # schema_migrations is created by ecto.migrate itself
            Mix.shell().info("Skipping schema_migrations")
            :ok
          else
            [schema, name] = data.name
            {:ok, migration} = Table.create_migration(data, bindings)
            filename = Path.join(migrations_path, "#{prefix}_table_#{schema}_#{name}.exs")
            Mix.shell().info(filename)
            Mix.shell().info(migration)
            :ok = File.write(filename, migration)
          end
        :create_schema ->
          {:ok, migration} = Schema.create_migration(data, bindings)
          filename = Path.join(migrations_path, "#{prefix}_schema_#{data.name}.exs")
          Mix.shell().info(filename)
          Mix.shell().info(migration)
          :ok = File.write(filename, migration)
        :create_type ->
          {:ok, migration} = Type.create_migration(Map.put(data, :sql, sql), bindings)
          [schema, name] = data.name
          filename = Path.join(migrations_path, "#{prefix}_type_#{schema}_#{name}.exs")
          Mix.shell().info(filename)
          Mix.shell().info(migration)
          :ok = File.write(filename, migration)
        :alter_table ->
          :ok
      end
    end

  end

  def collect_sql({line, idx}, nil = acc) do
    cond do
      String.match?(line, ~r/^CREATE TABLE/i) ->
        {[], {:create_table, idx, ~r/;$/i, [line]}}
      String.match?(line, ~r/^CREATE SCHEMA/i) ->
        {[{:create_schema, idx, [line]}], nil}
      String.match?(line, ~r/^CREATE TYPE/i) ->
        {[], {:create_type, idx, ~r/;$/i, [line]}}
      String.match?(line, ~r/^ALTER TABLE/i) ->
        if String.match?(line, ~r/;$/) do
          {[{:alter_table, idx, [line]}], nil}
        else
          {[], {:alter_table, idx, ~r/;$/i, [line]}}
        end
      true ->
        {[], acc}
    end
  end
  def collect_sql({line, _idx}, {type, start_idx, stop, lines}) do
    if String.match?(line, stop) do
      {[{type, start_idx, Enum.reverse([line | lines])}], nil}
    else
      {[], {type, start_idx, stop, [line | lines]}}
    end
  end

  def parse_sql({type, idx, lines}) do
    sql = Enum.join(lines)
    # Mix.shell().info("SQL #{idx}\n#{sql}")

    {:ok, data} = apply(sql_parser(type), [sql])
    %{type: type, idx: idx, sql: sql, data: data}
  end

  def sql_parser(:create_table), do: &EctoExtractMigrations.CreateTable.parse/1
  def sql_parser(:create_schema), do: &EctoExtractMigrations.CreateSchema.parse/1
  def sql_parser(:create_type), do: &EctoExtractMigrations.CreateType.parse/1
  def sql_parser(:alter_table), do: &EctoExtractMigrations.AlterTable.parse/1


end
