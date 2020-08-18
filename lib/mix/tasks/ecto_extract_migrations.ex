defmodule Mix.Tasks.Ecto.Extract.Migrations do
  @moduledoc """
  Mix task to create Ecto migration files from database schema SQL file.

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

    # Group results by type
    by_type = Enum.group_by(results, &(&1.type))
    # Mix.shell().info("types: #{inspect Map.keys(by_type)}")

    # Collect ALTER SEQUENCE statements
    as_objects = Enum.group_by(by_type[:alter_sequence], &alter_sequence_type/1)

    # Collect ALTER TABLE statements
    at_objects = Enum.group_by(by_type[:alter_table], &alter_table_type/1)

    # Collect table primary keys from ALTER TABLE statements
    primary_keys =
      for %{data: data} <- at_objects[:primary_key], into: %{} do
        {data.table, data.primary_key}
      end

    # Collect table defaults from ALTER TABLE statements
    # column_defaults =
    #   for result <- at_objects[:default], reduce: %{} do
    #     acc ->
    #       %{table: table, column: column, default: default} = result.data
    #       value = acc[table] || %{}
    #       Map.put(acc, table, Map.put(value, column, default))
    #   end

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

    # Create sequences, merging multiple into one migration
    statements = for %{data: data, sql: sql} <- by_type[:create_sequence] do
      name = EctoExtractMigrations.object_name(data.name)
      down_sql = "DROP SEQUENCE IF EXISTS #{name}"
      EctoExtractMigrations.eval_template_execute_sql(sql, down_sql)
    end
    call_bindings = Keyword.merge([
      module_name: Enum.join([repo, "Migrations.Sequences"], "."), statements: statements], bindings)
    {:ok, migration} = EctoExtractMigrations.eval_template_file("multi_statement.eex", call_bindings)
    file_name = "sequences.exs"
    Mix.shell().info(file_name)
    create_sequences_migration = [{file_name, migration}]

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
          # |> table_set_default(column_defaults[data.name])

          Mix.shell().info("\nSQL #{line_num} #{object_type}\n#{inspect data}")
          Mix.shell().info(sql)

          {:ok, migration} = module.migration(data, bindings)
          file_name = module.file_name(data, bindings)

          Mix.shell().info(file_name)
          Mix.shell().info(migration)

          {file_name, migration}
      end

    # Create ALTER SEQUENCE OWNED BY associating sequence with table primary key
    # data: %{owned_by: [table: ["chat", "assignment"], column: "id"], sequence: ["chat", "assignment_id_seq"]},
    statements = for %{sql: sql} <- as_objects[:owned_by], do: EctoExtractMigrations.eval_template_execute_sql(sql)
    call_bindings = Keyword.merge([
      module_name: Enum.join([repo, "Migrations.AlterSequences"], "."),
      statements: statements
    ], bindings)
    {:ok, migration} = EctoExtractMigrations.eval_template_file("multi_statement.eex", call_bindings)
    file_name = "alter_sequences_owned_by.exs"
    Mix.shell().info(file_name)
    alter_sequences_owned_by_migration = [{file_name, migration}]

    # Create views, triggers, and indexes
    phase_3 =
      for object_type <- [:create_view, :create_trigger, :create_index], object <- by_type[object_type] do
        %{module: module, sql: sql, data: data, line_num: line_num} = object

        Mix.shell().info("\nSQL #{line_num} #{object_type}\n#{inspect data}")
        Mix.shell().info(sql)

        data = Map.put(data, :sql, sql)
        {:ok, migration} = module.migration(data, bindings)
        file_name = module.file_name(data, bindings)

        Mix.shell().info(file_name)
        Mix.shell().info(migration)

        {file_name, migration}
      end

    # Create foreign keys and unique constraints
    # phase_4 =
    #   for object_type <- [:foreign_key, :unique], object <- at_objects[object_type] do
    #     %{sql: sql, data: data, line_num: line_num} = object
    #
    #     Mix.shell().info("SQL #{line_num} #{object_type}\n#{inspect data}")
    #     Mix.shell().info(sql)
    #
    #     data = Map.put(data, :sql, sql)
    #     module = migration_module(object_type)
    #     {:ok, migration} = module.migration(data, bindings)
    #     file_name = module.file_name(data, bindings)
    #
    #     Mix.shell().info(file_name)
    #     Mix.shell().info(migration)
    #
    #     {file_name, migration}
    #   end

    # Mix.shell().info("alter table types: #{inspect Map.keys(at_objects)}")

    # Create ALTER TABLE
    statements =
      for action <- [:default, :foreign_key, :unique], %{sql: sql} <- at_objects[action] do
        EctoExtractMigrations.eval_template_execute_sql(sql)
      end
    call_bindings = Keyword.merge([statements: statements,
      module_name: Enum.join([repo, "Migrations.AlterTables"], ".")], bindings)
    {:ok, migration} = EctoExtractMigrations.eval_template_file("multi_statement.eex", call_bindings)
    file_name = "alter_tables.exs"
    Mix.shell().info(file_name)
    alter_tables = [{file_name, migration}]

    # Generate ALTER TABLE CHECK constraints from CREATE TABLE constraints
    statements =
      for %{table: table, constraints: constraints} <- Enum.flat_map(results, &get_table_constraints/1),
          %{check: check, name: constraint_name} <- constraints do
        table_name = Enum.join(table, ".")
        sql = "ALTER TABLE #{table_name} ADD CONSTRAINT #{constraint_name} CHECK #{check}"
        # Could also generate for Ecto constraint(table, constraint_name, check: check)
        EctoExtractMigrations.eval_template_execute_sql(sql)
      end
    call_bindings = Keyword.merge([statements: statements,
      module_name: Enum.join([repo, "Migrations.AlterTable.CheckConstraints"], ".")], bindings)
    {:ok, migration} = EctoExtractMigrations.eval_template_file("multi_statement.eex", call_bindings)
    file_name = "alter_table_check_constraints.exs"
    Mix.shell().info(file_name)
    alter_table_check_contraints = [{file_name, migration}]

    # Write migrations to file
    files = List.flatten([
      phase_1,
      create_sequences_migration,
      create_table_migrations,
      alter_sequences_owned_by_migration,
      phase_3,
      alter_tables,
      alter_table_check_contraints,
    ])
    for {{file_name, migration}, index} <- Enum.with_index(files, 1) do
      path = Path.join(migrations_path, "#{to_prefix(index)}_#{file_name}")
      Mix.shell().info("#{path}")
      :ok = File.write(path, migration)
    end
  end

  # def migration_module(:foreign_key), do: EctoExtractMigrations.Migrations.ForeignKey
  # def migration_module(:unique), do: EctoExtractMigrations.Migrations.Unique

  # Get constraint type
  # ALTER TABLE ADD CONSTRAINT PRIMARY KEY
  def alter_table_type(%{data: %{action: :add_table_constraint, type: :primary_key}}), do: :primary_key
  # ALTER TABLE ADD CONSTRAINT FOREIGN KEY
  def alter_table_type(%{data: %{action: :add_table_constraint, type: :foreign_key}}), do: :foreign_key
  # ALTER TABLE ALTER COLUMN id SET DEFAULT
  def alter_table_type(%{data: %{action: :set_default}}), do: :default
  # ALTER TABLE ADD CONSTRAINT UNIQUE
  def alter_table_type(%{data: %{action: :add_table_constraint, type: :unique}}), do: :unique

  # Get alter sequence type
  # ALTER SEQUENCE chat.assignment_id_seq OWNED BY chat.assignment.id;
  def alter_sequence_type(%{data: %{owned_by: _}}), do: :owned_by

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
