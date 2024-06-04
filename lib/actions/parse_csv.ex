defmodule WorkflowEngine.Actions.ParseCsv do
  @moduledoc """
  Executes a request against the internal API using BXDK.
  """
  use OK.Pipe

  @behaviour WorkflowEngine.Action

  @impl WorkflowEngine.Action

  # "step" => %{"type" => "csv", data: "data", url: "/url", csv_settings: %{"linebreak" => "\n", "delimiter" => ",", "decimal" => "."}, "fields" => %{"name" , "age" }

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

  def execute(state, %{"type" => "parse_csv", "csv_settings" => csv_settings} = step) do
    {:ok, data} = get_data(step, state)

    csv_module = get_csv_module(csv_settings)

    rows =
      data
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

  def get_csv_module(csv_settings) do
    separator = Map.get(csv_settings, "separator")

    case separator do
      ";" -> CSVSemiColon
      "\t" -> CSVTab
      _ -> CSVComma
    end
  end

  def get_data(%{"data" => jsonLogic} = _step, state) when is_map(jsonLogic) do
    {:ok, WorkflowEngine.State.run_json_logic(state, jsonLogic)}
  end

  def get_data(%{"data" => data} = _step, _state) when is_binary(data) do
    {:ok, data}
  end

  def get_data(_step, _state) do
    {:error, "Missing required step parameter \"url\" or \"data\"."}
  end
end
