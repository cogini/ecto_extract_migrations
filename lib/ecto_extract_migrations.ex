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

  # def format_table_name(table) when is_binary(table), do: ~s|"#{table}"|
  # def format_table_name(["public", table]), do: ~s|"#{table}"|
  # def format_table_name([schema, table]), do: ~s|"#{schema}.#{table}"|

  def format_module_name(table) when is_binary(table), do: Macro.camelize(table)
  def format_module_name(["public", table]), do: Macro.camelize(table)
  def format_module_name([schema, table]) do
    "#{Macro.camelize(schema)}.#{Macro.camelize(table)}"
  end

  def unwrap_result(result) do
    case result do
      {:ok, [acc], "", _, _line, _offset} ->
        {:ok, acc}

      {:ok, _, rest, _, _line, _offset} ->
        {:error, "could not parse: " <> rest}

      {:error, reason, _rest, _context, _line, _offset} ->
        {:error, reason}
    end
  end
end
