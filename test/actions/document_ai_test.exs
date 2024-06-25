defmodule WorkflowEngine.Actions.DocumentAiTest do
  use ExUnit.Case, async: true
  use OK.Pipe

  alias WorkflowEngine.Actions.DocumentAi

  setup do
    api_key =
      Application.get_env(:workflow_engine, WorkflowEngine.Actions.DocumentAi)
      |> Keyword.fetch!(:api_key)

    endpoint =
      Application.get_env(:workflow_engine, WorkflowEngine.Actions.DocumentAi)
      |> Keyword.fetch!(:endpoint)

    {:ok, api_key: api_key, endpoint: endpoint}
  end

  describe "test" do
    test "test", %{api_key: api_key, endpoint: endpoint} do
      DocumentAi.execute(%{}, %{
        "type" => "document_ai",
        "model_id" => "model_id",
        "document_url" => "document_url",
        "api_key" => api_key,
        "endpoint" => endpoint
      })
    end
  end
end
