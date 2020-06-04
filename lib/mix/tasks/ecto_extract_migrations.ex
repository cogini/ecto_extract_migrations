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

  alias EctoExtractMigrations.Index
  alias EctoExtractMigrations.Schema
  alias EctoExtractMigrations.Sequence
  alias EctoExtractMigrations.Table
  alias EctoExtractMigrations.Type
  alias EctoExtractMigrations.View
  # alias EctoExtractMigrations.Constraint

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
      |> Stream.transform(nil, &extract_sql/2)
      |> Stream.map(&parse_sql/1)
      |> Enum.to_list

    bindings = [
      repo: repo,
    ]

    # TODO
    # merge alter table with table
    # constraints
    # create index
    # unique constraints
    # CREATE TABLE column options are not in order, use choice
    # Handle column constraints
    # Handle ALTER TABLE SET DEFAULT
    # Handle ALTER TABLE UNIQUE CONSTRAINT
    # Handle ALTER TABLE FOREIGN KEY CONSTRAINT
    # Consolidate CREATE INDEX statements for performance
    # Handle CREATE FUNCTION
    # Handle CREATE TRIGGER

    primary_keys =
      for result <- results, is_pk_constraint(result), into: %{} do
        {result.data.table, result.data.primary_key}
      end

    table_constraints =
      Enum.flat_map(results, &get_table_constraints/1)
    Mix.shell().info("table_constraints: #{inspect table_constraints}")

    for {%{type: type, sql: sql, data: data, idx: idx}, index} <- Enum.with_index(results) do
      Mix.shell().info("SQL #{type} #{idx} \n#{sql}\n#{inspect data}")
      prefix = to_string(:io_lib.format('~4..0b', [index]))
      data = Map.put(data, :sql, sql)
      case type do
        :create_table ->
          if data.name == ["public", "schema_migrations"] do
            # schema_migrations is created by ecto.migrate itself
            Mix.shell().info("Skipping schema_migrations")
            :ok
          else
            [schema, name] = data.name
            data = table_set_pk(data, primary_keys[data.name])
            {:ok, migration} = Table.create_migration(data, bindings)
            filename = Path.join(migrations_path, "#{prefix}_table_#{schema}_#{name}.exs")
            Mix.shell().info(filename)
            Mix.shell().info(migration)
            :ok = File.write(filename, migration)

            # constraints = data[:constraints] || []
            # if not Enum.empty?(constraints) do
            #   constraint_data = %{table: data.name, constraints: constraints}
            #   {:ok, migration} = Constraint.create_migration(constraint_data, bindings)
            #   filename = Path.join(migrations_path, "#{prefix}1_constraint_#{schema}_#{name}.exs")
            #   Mix.shell().info(filename)
            #   Mix.shell().info(migration)
            #   :ok = File.write(filename, migration)
            # end
          end
        :create_schema ->
          :ok = create_migration(Schema, data, bindings,
            Path.join(migrations_path, "#{prefix}_schema_#{data.name}.exs"))
        :create_type ->
          name = Enum.join(data.name, "_")
          :ok = create_migration(Type, data, bindings,
            Path.join(migrations_path, "#{prefix}_type_#{name}.exs"))
        :create_view ->
          name = Enum.join(data.name, "_")
          :ok = create_migration(View, data, bindings,
            Path.join(migrations_path, "#{prefix}_index_#{name}.exs"))

          # {:ok, migration} = View.create_migration(Map.put(data, :sql, sql), bindings)
          # [schema, name] = data.name
          # filename = Path.join(migrations_path, "#{prefix}_view_#{schema}_#{name}.exs")
          # Mix.shell().info(filename)
          # Mix.shell().info(migration)
          # :ok = File.write(filename, migration)
        :create_index ->
          :ok = create_migration(Index, data, bindings,
            Path.join(migrations_path, "#{prefix}_index_#{data.name}.exs"))
        :create_sequence ->
          :ok = create_migration(Sequence, data, bindings,
            Path.join(migrations_path, "#{prefix}_sequence_#{data.name}.exs"))
        :alter_table ->
          :ok
      end
    end

  end

  def create_migration(module, data, bindings, filename) do
    {:ok, migration} = apply(module, :create_migration, [data, bindings])
    Mix.shell().info(filename)
    Mix.shell().info(migration)
    :ok = File.write(filename, migration)
  end

  @doc "Extract SQL for statements from file"
  def extract_sql({line, idx}, nil = acc) do
    cond do
      String.match?(line, ~r/^CREATE TABLE/i) ->
        {[], {:create_table, idx, ~r/;$/i, [line]}}
      String.match?(line, ~r/^CREATE SCHEMA/i) ->
        {[{:create_schema, idx, [line]}], nil}
      String.match?(line, ~r/^CREATE (UNIQUE)?\s*INDEX/i) ->
        {[{:create_index, idx, [line]}], nil}
      String.match?(line, ~r/^CREATE TYPE/i) ->
        {[], {:create_type, idx, ~r/;$/i, [line]}}
      String.match?(line, ~r/^CREATE (TEMP|TEMPORARY)?\s*SEQUENCE/i) ->
        {[], {:create_sequence, idx, ~r/;$/i, [line]}}
      String.match?(line, ~r/^CREATE VIEW/i) ->
        {[], {:create_view, idx, ~r/;$/i, [line]}}
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
  def extract_sql({line, _idx}, {type, start_idx, stop, lines}) do
    if String.match?(line, stop) do
      {[{type, start_idx, Enum.reverse([line | lines])}], nil}
    else
      {[], {type, start_idx, stop, [line | lines]}}
    end
  end

  @doc "Run parser matching type"
  def parse_sql({type, idx, lines}) do
    sql = Enum.join(lines)
    # Mix.shell().info("SQL #{idx}\n#{sql}")

    {:ok, data} = apply(sql_parser(type), [sql])
    %{type: type, idx: idx, sql: sql, data: data}
  end

  def sql_parser(:alter_table), do: &EctoExtractMigrations.Parsers.AlterTable.parse/1
  def sql_parser(:create_index), do: &EctoExtractMigrations.Parsers.CreateIndex.parse/1
  def sql_parser(:create_schema), do: &EctoExtractMigrations.Parsers.CreateSchema.parse/1
  def sql_parser(:create_sequence), do: &EctoExtractMigrations.Parsers.CreateSequence.parse/1
  def sql_parser(:create_table), do: &EctoExtractMigrations.Parsers.CreateTable.parse/1
  def sql_parser(:create_type), do: &EctoExtractMigrations.Parsers.CreateType.parse/1
  def sql_parser(:create_view), do: &EctoExtractMigrations.Parsers.CreateView.parse/1

  # %{action: :add_constraint, constraint_name: "message_pkey", primary_key: ["id"], table: ["chat", "message"]}
  def is_pk_constraint(%{type: :alter_table, data: %{action: :add_constraint, primary_key: _pk}}), do: true
  def is_pk_constraint(_), do: false

  # Set primary_key: true on column if it is part of table primary key
  def table_set_pk(data, nil), do: data
  def table_set_pk(data, pk) do
    Mix.shell().info("setting pk: #{inspect data.name} #{inspect pk}")
    columns = data[:columns]
    # Mix.shell().info("setting pk columns: #{inspect columns}")
    columns = Enum.map(columns, &(column_set_pk(&1, pk)))
    # Mix.shell().info("setting pk columns: #{inspect columns}")
    %{data | columns: columns}
  end

  def column_set_pk(column, pk) do
    if column.name in pk do
      Mix.shell().info("setting pk column: #{inspect column}")
      Map.put(column, :primary_key, true)
    else
      column
    end
  end

  def get_table_constraints(%{type: :create_table, data: %{name: name, constraints: constraints}}) do
    [%{table: name, constraints: constraints}]
  end
  def get_table_constraints(_), do: []

end
