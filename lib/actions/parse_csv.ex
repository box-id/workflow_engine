defmodule WorkflowEngine.Actions.ParseCsv do
  @moduledoc """
  Executes a request against the internal API using BXDK.
  """
  use OK.Pipe

  @behaviour WorkflowEngine.Action

  @impl WorkflowEngine.Action

  # "step" => %{"type" => "csv", blob: "data", url: "/url", csv_settings: %{"linebreak" => "\n", "delimiter" => ",", "decimal" => "."}, "fields" => %{"name" , "age" }

  # NimbleCSV.define(CSV,
  #   separator: Map.get(csv_settings, "delimiter"),
  #   escape: Map.get(csv_settings, "linebreak")
  # )

  NimbleCSV.define(CSV,
    separator: ",",
    escape: "\""
  )

  def execute(state, %{"type" => "csv", "csv_settings" => csv_settings} = step) do
    {:ok, data} = get_data(step)

    rows =
      data
      |> List.wrap()
      |> CSV.to_line_stream()
      |> CSV.parse_stream(skip_headers: false)

    header_row = Stream.take(rows, 1) |> Enum.at(0) |> IO.inspect(label: "header_row")

    content_rows =
      Stream.drop(rows, 1)
      |> Stream.map(fn row ->
        Enum.zip(header_row, row)
        |> Map.new()
      end)
      |> Enum.to_list()
      |> IO.inspect(label: "content_rows")

    {:ok, {state, data}}
  end

  # def get_data(%{"url" => url} = step) when is_binary(url) do
  #   data =
  #     {:ok, data}
  # end

  def get_data(%{"blob" => blob} = step) when is_binary(blob) do
    {:ok, blob}
  end

  def get_data(step) do
    {:error, "Missing required step parameter \"url\" or \"blob\"."}
  end
end
