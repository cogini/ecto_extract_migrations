defmodule EctoExtractMigrations.Parsers.CheckConstraint do
  @moduledoc "Utility functions for parsers."

  import NimbleParsec

  alias EctoExtractMigrations.Parsers.Common
  import EctoExtractMigrations.Parsers.Common, only: [whitespace: 0, name: 0]

  def lparen, do: ascii_char([?(]) |> label("(")
  def rparen, do: ascii_char([?)]) |> label(")")

  def wrap_parens(_rest, acc, context, _line, _offset) do
    values = Enum.map(acc, &("(" <> &1 <> ")"))
    {values, context}
  end

  def expr_name do
    name()
    |> ascii_char([?(]) |> label("(")
    |> concat(name())
    |> ascii_char([?)]) |> label(")")
    # |> post_traverse(:wrap_parens)
    |> label("expr_name")
  end

  def math_op do
    utf8_string([?=, ?>, ?<, ?-, ?:], min: 1)
    |> label("math_op")
  end

  def expr_value do
    utf8_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?'], min: 1)
    |> label("expr_value")
  end

  def expression do
    choice([expr_name(), name()])
    |> concat(whitespace())
    |> concat(math_op())
    |> concat(whitespace())
    |> concat(expr_value())
    |> map({Common, :to_bin, []})
    |> reduce({Enum, :join, [""]})
    |> label("expression")
  end

  def bool_op do
    choice([
      string("AND"),
      string("OR"),
      string("NOT"),
    ])
    |> label("bool_op")
  end

  def bool_expression do
    ascii_char([?(]) |> label("(")
    |> concat(expr())
    |> concat(whitespace())
    |> concat(bool_op())
    |> concat(whitespace())
    |> concat(expr())
    |> ascii_char([?)]) |> label(")")
    |> map({Common, :to_bin, []})
    |> label("bool_expression")
  end

  def expr do
    ascii_char([?(]) |> label("(")
    |> concat(expression())
    |> ascii_char([?)]) |> label(")")
    |> map({Common, :to_bin, []})
    |> reduce({Enum, :join, [""]})
    |> label("expr")
  end

  def table_constraint_check do
    ignore(whitespace())
    |> ignore(string("CHECK"))
    |> ignore(whitespace())
    |> ignore(lparen())
    |> choice([expr(), bool_expression()])
    |> ignore(rparen())
    |> map({Common, :to_bin, []})
    |> reduce({Enum, :join, [""]})
    |> unwrap_and_tag(:check)
    |> label("CHECK")
  end

  # table_constraint_name =
  #   name |> unwrap_and_tag(:name) |> label("constraint_name")

  # table_constraint =
  #   string("CONSTRAINT") |> replace(:constraint) |> unwrap_and_tag(:type)
  #   |> ignore(whitespace)
  #   |> concat(table_constraint_name)
  #   |> ignore(whitespace)
  #   |> parsec(:table_constraint_check)
end
