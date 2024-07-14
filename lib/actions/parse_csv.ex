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

      header_row = Stream.take(rows, 1) |> Enum.at(0)

      content_rows =
        Stream.drop(rows, 1)
        |> Stream.map(fn row ->
          Enum.zip(header_row, row)
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
end
