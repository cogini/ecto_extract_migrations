# ecto_extract_migrations

[![Module Version](https://img.shields.io/hexpm/v/ecto_extract_migrations.svg)](https://hex.pm/packages/ecto_extract_migrations)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ecto_extract_migrations/)
[![Total Download](https://img.shields.io/hexpm/dt/ecto_extract_migrations.svg)](https://hex.pm/packages/ecto_extract_migrations)
[![License](https://img.shields.io/hexpm/l/ecto_extract_migrations.svg)](https://hex.pm/packages/ecto_extract_migrations)
[![Last Updated](https://img.shields.io/github/last-commit/cogini/ecto_extract_migrations.svg)](https://github.com/cogini/ecto_extract_migrations/commits/master)

Mix task to generate Ecto migrations from a Postgres schema SQL file.

This lets you take an existing project and move it into Elixir
with a proper development workflow.

## Usage

1. Generate a schema-only dump of the database to SQL:

   ```shell
   pg_dump --schema-only --no-owner postgres://dbuser:dbpassword@localhost/dbname > dbname.schema.sql
   ```

2. Generate migrations from the SQL file:

   ```shell
   mix ecto.extract.migrations --sql-file dbname.schema.sql
   ```

   or, from outside the target project:

   ```shell
   mix ecto.extract.migrations --sql-file dbname.schema.sql --repo "MyProject.Repo" --migrations-path ../myproject/priv/repo/migrations
   ```

3. Create a test database, run migrations to create the schema, then
export it and verify that it matches the original database:

   ```shell
   createuser --encrypted --pwprompt dbuser
   dropdb dbname_migrations
   createdb -Odbuser -Eutf8 dbname_migrations

   mix ecto.migrate --log-sql

   pg_dump --schema-only --no-owner postgres://dbuser@localhost/dbname_migrations > dbname_migrations.sql

   cat dbname.schema.sql | grep -v -E '^--|^$' > old.sql
   cat dbname_migrations.sql | grep -v -E '^--|^$' > new.sql
   diff -wu old.sql new.sql
   ```

## Details

This was written to migrate a legacy database with hundreds of tables and
objects.

The parser uses NimbleParsec, and is based on the SQL grammar, so it is
precise (unlike regex) and reasonably complete. It doesn't support every
esoteric option, just what we needed, but that was quite a lot. Patches are
welcome.

Supports:

* `ALTER SEQUENCE`
* `ALTER TABLE`
* `CREATE EXTENSION`
* `CREATE FUNCTION`
* `CREATE INDEX`
* `CREATE SCHEMA`
* `CREATE SEQUENCE`
* `CREATE TABLE`
* `CREATE TRIGGER`
* `CREATE TYPE`
* `CREATE VIEW`

## Installation

Add `ecto_extract_migrations` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ecto_extract_migrations, "~> 0.1.0"}
  ]
end
```

## Resources

Here are some useful resources for NimbleParsec:

* https://stefan.lapers.be/posts/elixir-writing-an-expression-parser-with-nimble-parsec/
* https://github.com/slapers/ex_sel
