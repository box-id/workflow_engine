defmodule WorkflowEngine.Actions.DocumentAi do
  @doc """
  Executes a request against the Azure Document AI API.
  """

  @behaviour WorkflowEngine.Action

  require Logger

  def execute(state, %{"type" => "document_ai"} = step) do
    # Example: curl -v -i POST "{endpoint}/documentintelligence/documentModels/{modelId}:analyze?api-version=2024-02-29-preview" -H "Content-Type: application/json" -H "Ocp-Apim-Subscription-Key: {key}" --data-ascii "{'urlSource': '{your-document-url}'}"

    with {:ok, model_id} <- get_model_id(step),
         {:ok, document_url} <- get_document_url(step),
         {:ok, api_key} <- get_api_key(step),
         {:ok, endpoint} <- get_endpoint(step) do
      IO.inspect(model_id, label: "model_id")
      IO.inspect(document_url, label: "document_url")
      IO.inspect(api_key, label: "api_key")
      IO.inspect(endpoint, label: "endpoint")
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
end
