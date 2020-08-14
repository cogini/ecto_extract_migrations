# ecto_extract_migrations

Mix task to generate Ecto migrations from SQL definitions dumped from a
Postgres database.

Supports:

* `ALTER TABLE`
* `ALTER SEQUENCE`
* `CREATE EXTENSION`
* `CREATE FUNCTION`
* `CREATE INDEX`
* `CREATE SCHEMA`
* `CREATE SEQUENCE`
* `CREATE TABLE`
* `CREATE TRIGGER`
* `CREATE TYPE`
* `CREATE VIEW`

The parsers use NimbleParsec, and are based on the SQL grammar, so they are
precise and reasonably complete. They don't support every esoteric option, just
what we needed, but that is quite a bit. Patches are welcome.

## Usage

This was used to migrate a legacy database with hundreds of tables and objects.
The fundamental approach we used is to dump the schema SQL from the existing db,
generate migrations and build a new db. We then exported the new db schema to SQL
and compared it with the original to see what is different.

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
cat dbname.schema.sql | grep -v -E '^--|^$' > old.sql
dropdb dbname_migrations
createdb -Odbname -Eutf8 dbname_migrations
DATABASE_URL=ecto://jake@localhost/dbname_migrations mix ecto.migrate --log-sql --migrations-path priv/repo/migrations/
pg_dump --schema-only --no-owner postgres://jake@localhost/dbname_migrations > dbname_migrations.sql
cat dbname_migrations.sql | grep -v -E '^--|^$' > new.sql
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

## Resources

Here are some useful resources for NimbleParsec:

* https://stefan.lapers.be/posts/elixir-writing-an-expression-parser-with-nimble-parsec/
* https://github.com/slapers/ex_sel
