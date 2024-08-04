defmodule WorkflowEngine.Actions.ParseCsv do
  @moduledoc """
  Executes a request against the internal API using BXDK.
  """
  use OK.Pipe

  @behaviour WorkflowEngine.Action

  @impl WorkflowEngine.Action

  NimbleCSV.define(CSVComma,
    separator: ",",
    escape: "\""
  )

  NimbleCSV.define(CSVSemiColon,
    separator: ";",
    escape: "\""
  )

  NimbleCSV.define(CSVTab,
    separator: "\t",
    escape: "\""
  )

  def execute(state, %{"type" => "parse_csv"} = step) do
    with {:ok, data} <- get_data(step, state) do
      csv_settings = Map.get(step, "csv_settings", %{})
      csv_module = get_csv_module(csv_settings)

      rows =
        data
        |> trim_bom()
        |> List.wrap()
        |> csv_module.to_line_stream()
        |> csv_module.parse_stream(skip_headers: false)

      {header_fields, content_rows} = get_header_and_rows(rows, step)

      content_rows =
        Stream.map(content_rows, fn row ->
          # Fill in missing field values with nils.
          fields_and_nils = Stream.concat(row, Stream.cycle([nil]))

          header_fields
          |> Enum.zip(fields_and_nils)
          |> Map.new()
        end)

      {:ok, {state, content_rows}}
    end
  end

  def get_csv_module(csv_settings) do
    case csv_settings["separator"] do
      ";" -> CSVSemiColon
      "\t" -> CSVTab
      _ -> CSVComma
    end
  end

  @spec get_data(map(), WorkflowEngine.State.t()) :: {:ok, any()} | {:error, String.t()}
  defp get_data(%{"data" => json_logic}, state) when is_map(json_logic) do
    {:ok, WorkflowEngine.State.run_json_logic(state, json_logic)}
  end

  defp get_data(%{"data" => data}, _state) when is_binary(data) do
    {:ok, data}
  end

  defp get_data(_step, _state) do
    {:error, "Missing required step parameter \"data\"."}
  end

  defp trim_bom(<<239, 187, 191, rest::binary>>) do
    rest
  end

  defp trim_bom([<<239, 187, 191, first_row::binary>> | rest]) do
    [first_row | rest]
  end

  defp trim_bom(data) do
    data
  end

  defp get_header_and_rows(rows, step) do
    case Map.get(step, "columns") || [] do
      # Empty or nil columns means that the first row is the header.
      [] ->
        header_fields = Stream.take(rows, 1) |> Enum.at(0)
        content_rows = Stream.drop(rows, 1)

        {header_fields, content_rows}

      # Manual columns are provided. `csv_settings.skip_header` can be used to skip original
      # header row.
      columns when is_list(columns) ->
        header_fields = columns

        content_rows =
          if get_in(step, ["csv_settings", "skip_header"]) do
            Stream.drop(rows, 1)
          else
            rows
          end

        {header_fields, content_rows}
    end
  end
end
