defmodule WorkflowEngine.Actions.DocumentAi do
  @doc """
  Executes a request against the Azure Document AI API.
  """

  use OK.Pipe

  @behaviour WorkflowEngine.Action

  require Logger

  @default_document_ai_api_version "2023-07-31"

  def execute(state, %{"type" => "document_ai"} = step) do
    with {:ok, model_id} <- get_property(step, "model_id"),
         {:ok, document_url} <- get_property(step, "document_url"),
         {:ok, api_key} <- get_property(step, "api_key"),
         {:ok, endpoint} <- get_property(step, "endpoint"),
         {:ok, api_version} <-
           get_property(step, "api_version", @default_document_ai_api_version),
         {:ok, request} <-
           request_document_analysis(api_key, endpoint, model_id, document_url, api_version),
         {:ok, operation_location} <- get_operation_location(request),
         {:ok, result} <-
           request_analyzed_results(api_key, operation_location, System.os_time(:millisecond)) do
      # TODO: parse results and update state

      {:ok, state}
    else
      {:error, reason} ->
        Logger.warning("DocumentAiAction: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_property(step, property, default \\ nil) do
    case Map.get(step, property, default) do
      nil -> {:error, "#{property} is required"}
      value when is_binary(value) -> OK.wrap(value)
      _ -> {:error, "#{property} must be a string"}
    end
  end

  defp request_document_analysis(api_key, endpoint, model_id, document_url, api_version) do
    Req.new(
      method: "POST",
      url: endpoint <> "/formrecognizer/documentModels/#{model_id}:analyze",
      json: %{"urlSource" => document_url},
      headers: %{
        "Ocp-Apim-Subscription-Key" => api_key
      },
      params: %{
        "api-version" => api_version
      }
    )
    |> Req.request()
  end

  defp get_operation_location(%{headers: headers}) do
    with {"operation-location", value} <- List.keyfind(headers, "operation-location", 0) do
      {:ok, value}
    else
      _ ->
        {:error, "Operation location not found in headers"}
    end
  end

  defp request_analyzed_results(api_key, operation_location, initial_call_ts) do
    with {:ok, :continue} <- compare_ts(initial_call_ts),
         {:ok, %{status: 200} = result} <-
           Req.get(
             operation_location,
             headers: %{
               "Ocp-Apim-Subscription-Key" => api_key
             }
           ) do
      # INFO: the DocumentAI platform returns a 200 status code even if the operation is not
      # completed but in progress, so we retry until the status is "succeeded" or the operation
      # times out
      # Documentation: https://learn.microsoft.com/en-us/rest/api/aiservices/document-models/get-analyze-result

      if result.body["status"] != "succeeded" do
        Process.sleep(1000)
        request_analyzed_results(api_key, operation_location, initial_call_ts)
      else
        {:ok, result.body}
      end
    else
      error ->
        Logger.error("DocumentAiAction failed: #{inspect(error)}")
        {:error, error}
    end
  end

  defp compare_ts(initial_call_ts) do
    if System.os_time(:millisecond) > initial_call_ts + :timer.seconds(10),
      do: {:error, "Operation timed out"},
      else: {:ok, :continue}
  end
end
