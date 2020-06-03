defmodule EctoExtractMigrations do
  @moduledoc """
  Documentation for `EctoExtractMigrations`.
  """

  defmodule ParseError do
    defexception message: "default message"
  end

  @doc "Evaluate template file with bindings"
  @spec eval_template(Path.t(), Keyword.t()) :: {:ok, binary} | {:error, term}
  def eval_template(template_file, bindings \\ []) do
    {:ok, EEx.eval_file(template_file, bindings, trim: true)}
  rescue
    e ->
      {:error, {:template, e}}
  end

  def format_table_name(table) when is_binary(table), do: table
  def format_table_name(["public", table]), do: table
  def format_table_name([schema, table]), do: "#{schema}.#{table}"

  def format_module_name(table) when is_binary(table), do: Macro.camelize(table)
  def format_module_name(["public", table]), do: Macro.camelize(table)
  def format_module_name([schema, table]) do
    "#{Macro.camelize(schema)}.#{Macro.camelize(table)}"
  end

end
