# ecto_extract_migrations

Mix task to generate Ecto migrations from a Postgres schema SQL file.

## Usage

Dump database schema:

```shell
pg_dump --schema-only --no-owner postgres://dbuser:dbpassword@localhost/dbname > dbname.schema.sql
```

Generate migrations:

```shell
mix ecto.extract.migrations --sql-file dbname.schema.sql
```

Run migrations on a new db and compare with original:

```shell
cat dbname.schema.sql | grep -v -E '^--|^$' > old.sql
dropdb dbname_migrations
createdb -Odbuser -Eutf8 dbname_migrations
mix ecto.migrate --log-sql
pg_dump --schema-only --no-owner postgres://dbuser@localhost/dbname_migrations > dbname_migrations.sql
cat dbname_migrations.sql | grep -v -E '^--|^$' > new.sql
diff -wu old.sql new.sql
```

## Details

This was written to migrate a legacy database with hundreds of tables and
objects.

The parsers use NimbleParsec, and are based on the SQL grammar, so they are
precise and reasonably complete. They don't support every esoteric option, just
what we needed, but that was quite a lot. Patches are welcome.

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
