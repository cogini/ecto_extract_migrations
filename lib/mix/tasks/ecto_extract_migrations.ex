defmodule Mix.Tasks.Ecto.Extract.Migrations do
  @moduledoc """
  Mix task to create Ecto migration files from database schema.

  ## Command line options

    * `--sql-file`- Schema SQL file
    * `--repo` - Name of Ecto repo, default Repo
    * `--migrations-path` - target dir for migrations, default "priv/repo/migrations".

  ## Usage

      pg_dump --schema-only --no-owner postgres://dbuser:dbpassword@localhost/dbname > dbname.schema.sql
      mix ecto.extract.migrations --sql-file dbname.schema.sql

  """
  @shortdoc "Create Ecto migration files from db schema SQL file"

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

    sql_file = overrides[:sql_file]
    repo = overrides[:repo] || "Repo"
    repo_dir = Macro.underscore(repo)
    default_migrations_path = Path.join(["priv", repo_dir, "migrations"])
    migrations_path = overrides[:migrations_path] || default_migrations_path

    :ok = File.mkdir_p(migrations_path)

    # Parse SQL file
    results =
      sql_file
      |> File.stream!()
      |> Stream.with_index(1)
      |> Stream.transform(nil, &EctoExtractMigrations.parse/2)
      # |> Stream.filter(&(&1.type in [:create_function]))
      |> Stream.reject(&(&1.type in [:whitespace, :comment]))
      |> Enum.to_list()

    # for result <- results do
    #   Mix.shell().info("#{inspect result}")
    # end

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

    # Group results by type
    by_type = Enum.group_by(results, &(&1.type))
    Mix.shell().info("types: #{inspect Map.keys(by_type)}")

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

    # Collect table foreign key constraints from ALTER TABLE statements

    # foreign_keys =
    #   for result <- at_objects[:foreign_key], reduce: %{} do
    #     acc ->
    #       data = result.data
    #       column_reference = Reference.column_reference(data)
    #       Mix.shell().info("foreign_key> #{inspect result}\n#{inspect column_reference}")
    #       %{table: table, columns: columns} = data
    #       value = acc[table] || %{}
    #       column = List.first(columns)
    #       Map.put(acc, table, Map.put(value, column, data))
    #   end

    # Collect table constraints
    # table_constraints = Enum.flat_map(results, &get_table_constraints/1)
    # Mix.shell().info("table_constraints: #{inspect table_constraints}")

    # Base bindings for templates
    bindings = [
      repo: repo,
    ]

    # Create extensions, schemas and types
    phase_1 =
      for object_type <- [:create_extension, :create_schema, :create_type, :create_function],
          object <- by_type[object_type] do
        %{module: module, sql: sql, data: data, line_num: line_num} = object

        Mix.shell().info("SQL #{line_num} #{object_type}\n#{inspect data}")
        Mix.shell().info(sql)

        data = Map.put(data, :sql, sql)
        {:ok, migration} = module.migration(data, bindings)
        file_name = module.file_name(data, bindings)

        Mix.shell().info(file_name)
        Mix.shell().info(migration)

        {file_name, migration}
      end

    # Create sequences, merging multiple sequences into one
    statements = for %{data: data, sql: sql} <- by_type[:create_sequence] do
      [schema, name] = data.name
      EctoExtractMigrations.Commands.CreateSequence.migration_statement(sql, schema, name)
    end
    {:ok, migration} = EctoExtractMigrations.Commands.CreateSequence.migration_combine(statements, bindings)
    file_name = "sequences.exs"
    Mix.shell().info(file_name)
    sequences_migrations = [{file_name, migration}]

    # Create tables
    object_type = :create_table
    create_table_migrations =
      for %{module: module, sql: sql, data: data, line_num: line_num} <- by_type[object_type],
        # Skip schema_migrations table as it is created by ecto.migrate itself
        data.name != ["public", "schema_migrations"] do

        data =
          data
          |> Map.put(:sql, sql)
          |> table_set_pk(primary_keys[data.name])
          |> table_set_default(column_defaults[data.name])

          Mix.shell().info("\nSQL #{line_num} #{object_type}\n#{inspect data}")
          Mix.shell().info(sql)

          {:ok, migration} = module.migration(data, bindings)
          file_name = module.file_name(data, bindings)

          Mix.shell().info(file_name)
          Mix.shell().info(migration)

          {file_name, migration}
      end

    # [:create_view, :create_trigger, :create_index]
    # Create views and indexes
    phase_3 =
      for object_type <- [:create_view, :create_index], object <- by_type[object_type] do
        %{module: module, sql: sql, data: data, line_num: line_num} = object

        Mix.shell().info("SQL #{line_num} #{object_type}\n#{inspect data}")
        Mix.shell().info(sql)

        data = Map.put(data, :sql, sql)
        {:ok, migration} = module.migration(data, bindings)
        file_name = module.file_name(data, bindings)

        Mix.shell().info(file_name)
        Mix.shell().info(migration)

        {file_name, migration}
      end

    # Create foreign keys and unique constraints
    phase_4 =
      for object_type <- [:foreign_key, :unique], object <- at_objects[object_type] do
        %{sql: sql, data: data, line_num: line_num} = object

        Mix.shell().info("SQL #{line_num} #{object_type}\n#{inspect data}")
        Mix.shell().info(sql)

        data = Map.put(data, :sql, sql)
        module = migration_module(object_type)
        {:ok, migration} = module.migration(data, bindings)
        file_name = module.file_name(data, bindings)

        Mix.shell().info(file_name)
        Mix.shell().info(migration)

        {file_name, migration}
      end

    # Write migrations to file
    files = List.flatten([phase_1, sequences_migrations, create_table_migrations, phase_3, phase_4])
    for {{file_name, migration}, index} <- Enum.with_index(files, 1) do
      path = Path.join(migrations_path, "#{to_prefix(index)}_#{file_name}")
      Mix.shell().info("#{path}")
      :ok = File.write(path, migration)
    end
  end

  def migration_module(:foreign_key), do: EctoExtractMigrations.Migrations.ForeignKey
  def migration_module(:unique), do: EctoExtractMigrations.Migrations.Unique

  # Get constraint type
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

  # Format numeric index as string with leading zeroes for filenames
  @spec to_prefix(integer) :: binary
  defp to_prefix(index) do
    to_string(:io_lib.format('~4..0b', [index]))
  end
end
