defmodule EctoExtractMigrations.Parsers.CreateExtension do
  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  # https://www.postgresql.org/docs/current/sql-createextension.html
  # https://www.postgresql.org/docs/current/sql-dropextension.html

  whitespace = Common.whitespace()
  name = Common.name()

  if_not_exists =
    ignore(optional(whitespace))
    |> string("IF NOT EXISTS")

  with_ =
    ignore(optional(whitespace))
    |> ignore(string("WITH"))
    |> label("WITH")

  schema =
    ignore(optional(whitespace))
    |> ignore(string("SCHEMA"))
    |> ignore(whitespace)
    |> concat(name) |> unwrap_and_tag(:schema)
    |> label("SCHEMA")

  version =
    ignore(optional(whitespace))
    |> ignore(string("VERSION"))
    |> ignore(whitespace)
    |> concat(name) |> unwrap_and_tag(:version)
    |> label("VERSION")

  old_version =
    ignore(optional(whitespace))
    |> ignore(string("FROM"))
    |> ignore(whitespace)
    |> concat(name) |> unwrap_and_tag(:old_version)
    |> label("FROM")

  cascade =
    ignore(optional(whitespace))
    |> ignore(string("CASCADE"))
    |> label("CASCADE")

  create_extension =
    ignore(string("CREATE EXTENSION"))
    |> ignore(optional(if_not_exists))
    |> ignore(whitespace)
    |> concat(name) |> unwrap_and_tag(:name)
    |> optional(with_)
    |> optional(schema)
    |> optional(version)
    |> optional(old_version)
    |> optional(cascade)
    |> ignore(ascii_char([?;]))
    |> ignore(optional(whitespace))
    |> reduce({Enum, :into, [%{}]})

  defparsec :parsec_create_extension, create_extension

  def parse(sql) do
    case parsec_create_extension(sql) do
      {:ok, [value], _, _, _, _} -> {:ok, value}
      error -> error
    end
  end

  def match(line), do: parse(line)

  def tag, do: :create_extension
end
