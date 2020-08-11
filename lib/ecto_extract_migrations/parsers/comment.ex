defmodule EctoExtractMigrations.Parsers.Comment do
  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common

  whitespace = Common.whitespace()

  empty_comment =
    string("--\n")
    |> replace("")
    |> unwrap_and_tag(:comment)

  comment_text =
    ignore(string("--"))
    utf8_string([{:not, ?\n}], min: 1)
    |> unwrap_and_tag(:comment)

  comment =
    ignore(optional(whitespace))
    |> choice([empty_comment, comment_text])
    |> reduce({Enum, :into, [%{}]})

  defparsec :parsec_comment, comment

  def parse(line) do
    case parsec_comment(line) do
      {:ok, [value], _, _, _, _} -> {:ok, value}
      error -> error
    end
  end

  def match(line), do: parse(line)
end
