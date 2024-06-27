defmodule WorkflowEngine.Actions.DocumentAi do
  @doc """
  Executes a request against the Azure Document AI API.
  """

  use OK.Pipe

  @behaviour WorkflowEngine.Action

  require Logger

  @default_document_ai_api_version "2023-07-31"

  def execute(state, %{"type" => "document_ai"} = step) do
    with {:ok, model_id} <- get_model_id(step),
         {:ok, document_url} <- get_document_url(step),
         {:ok, api_key} <- get_api_key(step),
         {:ok, endpoint} <- get_endpoint(step),
         {:ok, request} <- request_document_analysis(api_key, endpoint, model_id, document_url),
         {:ok, operation_location} <- get_operation_location(request),
         {:ok, result} <- request_analyzed_results(api_key, operation_location) do
      # step = %{
      #   "url" => endpoint,
      #   "path" => "/formrecognizer/documentModels/#{model_id}:analyze",
      #   "type" => "http",
      #   "method" => "POST",
      #   "params" => "api-version=#{@default_document_ai_api_version}",
      #   # "params" => %{
      #   #   "api-version" => Map.get(step, "api_version", @default_document_ai_api_version)
      #   # },
      #   "headers" => %{
      #     "Ocp-Apim-Subscription-Key" => api_key
      #   },
      #   # "body" => ["urlSource", document_url]
      #   "body" => %{"urlSource" => document_url},
      #   "result" => %{"as" => "result"}
      # }

      IO.inspect(result)
      {:ok, state}
    else
      {:error, reason} ->
        Logger.warning("DocumentAiAction: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp get_model_id(%{"model_id" => model_id}) when is_binary(model_id), do: OK.wrap(model_id)
  defp get_model_id(_), do: {:error, "model_id is required"}

  defp get_document_url(%{"document_url" => document_url}) when is_binary(document_url),
    do: OK.wrap(document_url)

  defp get_document_url(_), do: {:error, "document_url is required"}

  defp get_api_key(%{"api_key" => api_key}) when is_binary(api_key), do: OK.wrap(api_key)
  defp get_api_key(_), do: {:error, "api_key is required"}

  defp get_endpoint(%{"endpoint" => endpoint}) when is_binary(endpoint), do: OK.wrap(endpoint)
  defp get_endpoint(_), do: {:error, "endpoint is required"}

  defp request_document_analysis(api_key, endpoint, model_id, document_url) do
    Req.new(
      method: "POST",
      url: endpoint <> "/formrecognizer/documentModels/#{model_id}:analyze",
      json: %{"urlSource" => document_url},
      headers: %{
        "Ocp-Apim-Subscription-Key" => api_key
      },
      params: %{
        # FIXME: do dynamic api-version
        "api-version" => @default_document_ai_api_version
      }
    )
    |> Req.request()
  end

  defp get_operation_location(%{headers: headers}) do
    with {_, value} <- List.keyfind(headers, "operation-location", 0) do
      {:ok, value}
    else
      _ ->
        {:error, "Operation location not found in headers"}
    end
  end

  defp get_operation_location(_), do: {:error, "Request did not return any headers"}

  defp request_analyzed_results(api_key, operation_location) do
    IO.inspect("requesting analyzed results")
    Process.sleep(1000)

    {:ok, result} =
      Req.new(
        method: "GET",
        url: operation_location,
        headers: %{
          "Ocp-Apim-Subscription-Key" => api_key
        }
      )
      |> Req.request()

    if result.body["status"] != "succeeded",
      do: request_analyzed_results(api_key, operation_location),
      else: result
  end
end
