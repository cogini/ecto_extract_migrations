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

  @app :ecto_extract_migrations

  alias EctoExtractMigrations.Reference

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
    sql_file = overrides[:sql_file]

    migrations_path = get_migrations_path(overrides)
    :ok = File.mkdir_p(migrations_path)

    results =
      sql_file
      |> File.stream!
      |> Stream.with_index
      |> Stream.transform(nil, &extract_sql/2)
      |> Stream.map(&parse_sql/1)
      |> Enum.to_list

    # TODO
    # CREATE TABLE
    #   Parse CONSTRAINTS with new expression parser
    #   Column options are not in order, use choice
    #     e.g. public.login_log
    #   Handle column constraints
    #
    # ALTER TABLE
    #   ALTER TABLE ONLY chat.assignment ALTER COLUMN id SET DEFAULT nextval
    #   ALTER TABLE ONLY chat.session ADD CONSTRAINT session_token_key UNIQUE (token);
    #   ALTER TABLE ONLY chat.assignment ADD CONSTRAINT assignment_care_taker_id_fkey FOREIGN KEY (user_id) REFERENCES chat."user"(id);
    #
    #   Merge with create table
    #
    # CREATE INDEX
    #   Consolidate statements for performance
    #
    # CREATE FUNCTION
    # CREATE TRIGGER
    # CREATE EXTENSION
    #   CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;
    #   COMMENT ON EXTENSION pg_stat_statements IS 'track execution statistics of all SQL statements executed';

    index = 1

    bindings = [
      repo: repo,
    ]

    by_type = Enum.group_by(results, &(&1.type))
    Mix.shell().info("types: #{inspect Map.keys(by_type)}")

    object_types = [:create_extension, :create_schema, :create_type]
    index =
      for object_type <- object_types, reduce: index do
        acc ->
          objects = by_type[object_type]
          for {%{sql: sql, data: data, idx: line}, index} <- Enum.with_index(objects, acc) do
            Mix.shell().info("SQL #{object_type} #{line} \n#{sql}\n#{inspect data}")
            prefix = to_string(:io_lib.format('~4..0b', [index]))
            data = Map.put(data, :sql, sql)

            module = migration_module(object_type)
            migration = apply(module, :migration, [data, bindings])
            file_name = apply(module, :file_name, [prefix, data, bindings])
            path = Path.join(migrations_path, file_name)
            write_migration_file(migration, path)
          end
          acc + length(objects)
      end

    # Create sequences
    # {sequences, results} = Enum.split_with(results, &(&1.type == :create_sequence))
    sequences = by_type[:create_sequence]
    statements = for %{data: data, sql: sql} <- sequences do
      [schema, name] = data.name
      EctoExtractMigrations.Migrations.CreateSequence.create_migration_statement(sql, schema, name)
    end
    {:ok, migration} = create_sequences_migration(statements, bindings)
    prefix = to_string(:io_lib.format('~4..0b', [index]))
    filename = Path.join(migrations_path, "#{prefix}_sequences.exs")
    write_migration_file(migration, filename)
    index = index + 1

    # Collect ALTER TABLE statements
    at_objects = Enum.group_by(by_type[:alter_table], &alter_table_type/1)

    # Collect table primary_keys from ALTER TABLE statements
    primary_keys =
      for %{data: data} <- at_objects[:primary_key], into: %{} do
        {data.table, data.primary_key}
      end

    # Collect table defaults from ALTER TABLE statements
    column_defaults =
      for result <- at_objects[:default], reduce: %{} do
        acc ->
          %{table: table, column: column, default: default} = result.data
          value = acc[table] || %{}
          Map.put(acc, table, Map.put(value, column, default))
      end

    # Collect table foreegn key constraints from ALTER TABLE statements

    foreign_keys =
      for result <- at_objects[:foreign_key], reduce: %{} do
        acc ->
          data = result.data
          column_reference = Reference.column_reference(data)
          Mix.shell().info("foreign_key> #{inspect result}\n#{inspect column_reference}")
          %{table: table, columns: columns} = data
          value = acc[table] || %{}
          column = List.first(columns)
          Map.put(acc, table, Map.put(value, column, data))
      end

    # Collect table constraints
    table_constraints = Enum.flat_map(results, &get_table_constraints/1)
    Mix.shell().info("table_constraints: #{inspect table_constraints}")


    object_type = :create_table
    objects = by_type[object_type]
    for {%{sql: sql, data: data, idx: line}, index} <- Enum.with_index(objects, index) do
      Mix.shell().info("SQL #{object_type} #{line} \n#{sql}\n#{inspect data}")
      prefix = to_string(:io_lib.format('~4..0b', [index]))
      data = Map.put(data, :sql, sql)

      if data.name == ["public", "schema_migrations"] do
        # schema_migrations is created by ecto.migrate itself
        Mix.shell().info("Skipping schema_migrations")
        :ok
      else
        data =
          data
          |> table_set_pk(primary_keys[data.name])
          |> table_set_default(column_defaults[data.name])

        module = migration_module(object_type)
        migration = apply(module, :migration, [data, bindings])
        file_name = apply(module, :file_name, [prefix, data, bindings])
        path = Path.join(migrations_path, file_name)
        write_migration_file(migration, path)
      end
    end
    index = index + length(objects)


    object_types = [:create_view, :create_index]
    index =
      for object_type <- object_types, reduce: index do
        acc ->
          objects = by_type[object_type]
          for {%{sql: sql, data: data, idx: line}, index} <- Enum.with_index(objects, acc) do
            Mix.shell().info("SQL #{object_type} #{line} \n#{sql}\n#{inspect data}")
            prefix = to_string(:io_lib.format('~4..0b', [index]))
            data = Map.put(data, :sql, sql)

            module = migration_module(object_type)
            migration = apply(module, :migration, [data, bindings])
            file_name = apply(module, :file_name, [prefix, data, bindings])
            path = Path.join(migrations_path, file_name)
            write_migration_file(migration, path)
          end
          acc + length(objects)
      end

    # object_types = [:default, :foreign_key, :unique]
    object_types = [:foreign_key, :unique]
    index =
      for object_type <- object_types, reduce: index do
        acc ->
          objects = at_objects[object_type]
          for {%{sql: sql, data: data, idx: line}, index} <- Enum.with_index(objects, acc) do
            Mix.shell().info("SQL #{object_type} #{line} \n#{sql}\n#{inspect data}")
            prefix = to_string(:io_lib.format('~4..0b', [index]))
            data = Map.put(data, :sql, sql)

            module = migration_module(object_type)
            migration = apply(module, :migration, [data, bindings])
            file_name = apply(module, :file_name, [prefix, data, bindings])
            path = Path.join(migrations_path, file_name)
            write_migration_file(migration, path)
          end
          acc + length(objects)
      end
  end

  @doc "Extract SQL for statements from file"
  def extract_sql({line, idx}, nil = acc) do
    cond do
      String.match?(line, ~r/^CREATE EXTENSION/i) ->
        {[{:create_extension, idx, [line]}], nil}
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
  def sql_parser(:create_extension), do: &EctoExtractMigrations.Parsers.CreateExtension.parse/1
  def sql_parser(:create_index), do: &EctoExtractMigrations.Parsers.CreateIndex.parse/1
  def sql_parser(:create_schema), do: &EctoExtractMigrations.Parsers.CreateSchema.parse/1
  def sql_parser(:create_sequence), do: &EctoExtractMigrations.Parsers.CreateSequence.parse/1
  def sql_parser(:create_table), do: &EctoExtractMigrations.Parsers.CreateTable.parse/1
  def sql_parser(:create_type), do: &EctoExtractMigrations.Parsers.CreateType.parse/1
  def sql_parser(:create_view), do: &EctoExtractMigrations.Parsers.CreateView.parse/1


  def migration_module(:create_extension), do: EctoExtractMigrations.Migrations.CreateExtension
  def migration_module(:create_index), do: EctoExtractMigrations.Migrations.CreateIndex
  def migration_module(:create_schema), do: EctoExtractMigrations.Migrations.CreateSchema
  def migration_module(:create_table), do: EctoExtractMigrations.Migrations.CreateTable
  def migration_module(:create_type), do: EctoExtractMigrations.Migrations.CreateType
  def migration_module(:create_view), do: EctoExtractMigrations.Migrations.CreateView
  def migration_module(:default), do: EctoExtractMigrations.Migrations.Default
  def migration_module(:foreign_key), do: EctoExtractMigrations.Migrations.ForeignKey
  def migration_module(:unique), do: EctoExtractMigrations.Migrations.Unique

  def get_migrations_path(overrides) do
    repo = overrides[:repo] || "Repo"
    repo_dir = Macro.underscore(repo)
    default_migrations_path = Path.join(["priv", repo_dir, "migrations"])
    overrides[:migrations_path] || default_migrations_path
  end

  def write_migration_file(migration, filename) do
    Mix.shell().info(filename)
    Mix.shell().info(migration)
    :ok = File.write(filename, migration)
  end

  def get_sequence_statements(results) do
    for result <- results, result.type == :create_sequence do
      [schema, name] = result.data.name
      EctoExtractMigrations.Migrations.CreateSequence.create_migration_statement(result.sql, schema, name)
    end
  end

  def create_sequences_migration(statements, bindings) do
    bindings = Keyword.merge([module_name: "Sequences", sequences: statements], bindings)
    template_dir = Application.app_dir(@app, ["priv", "templates"])
    template_path = Path.join(template_dir, "sequences.eex")
    EctoExtractMigrations.eval_template(template_path, bindings)
  end

  # ALTER TABLE ADD CONSTRAINT PRIMARY KEY
  def alter_table_type(%{data: %{action: :add_table_constraint, type: :primary_key}}), do: :primary_key
  # ALTER TABLE ADD CONSTRAINT FOREIGN KEY
  def alter_table_type(%{data: %{action: :add_table_constraint, type: :foreign_key}}), do: :foreign_key
  # ALTER TABLE ALTER COLUMN id SET DEFAULT
  def alter_table_type(%{data: %{action: :set_default}}), do: :default
  # ALTER TABLE ADD CONSTRAINT UNIQUE
  def alter_table_type(%{data: %{action: :add_table_constraint, type: :unique}}), do: :unique

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


  # Set default on column based on alter table
  def table_set_default(data, nil), do: data
  def table_set_default(data, defaults) do
    Mix.shell().info("setting default: #{inspect data.name} #{inspect defaults}")
    columns = Enum.map(data[:columns], &(column_set_default(&1, defaults)))
    %{data | columns: columns}
  end

  def column_set_default(data, defaults) do
    case Map.fetch(defaults, data.name) do
      {:ok, default} ->
        Map.put(data, :default, default)
      :error ->
        data
    end
  end


  def get_table_constraints(%{type: :create_table, data: %{name: name, constraints: constraints}}) do
    [%{table: name, constraints: constraints}]
  end
  def get_table_constraints(_), do: []

end
