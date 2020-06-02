# ecto_extract_migrations

Mix task to generate Ecto migrations from SQL definitions dumped from a Postgres database.

Supports `CREATE TABLE`, `CREATE SCHEMA`, `CREATE TYPE`, `ALTER TABLE` to get
primary key and defaults.

## Usage

Dump database schema:

```shell
pg_dump --schema-only  --no-owner postgres://dbuser:dbpassword@localhost/dbname > dbname.schema.sql
```

Generate migrations:

```shell
mix ecto.extract.migrations --sql-file dbname.schema.sql
```

Run migrations on a new db and compare with original:

```shell
dropdb dbname_migrations
createdb -Odbuser -Eutf8 dbname
DATABASE_URL=ecto://dbuser@localhost/dbname_migrations mix ecto.migrate --log-sql --migrations-path priv/repo/migrations/
pg_dump --schema-only --no-owner postgres://dbuser:dbpassword@localhost/dbname_migrations > migrations.dbname.schema.sql
cat migrations.dbname.schema.sql | ./strip_stuff.pl | grep -v -E '^--|^$|^ALTER SEQUENCE' > new.sql
diff -wu dbname.schema.sql new.sql
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ecto_extract_migrations` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_extract_migrations, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ecto_extract_migrations](https://hexdocs.pm/ecto_extract_migrations).
