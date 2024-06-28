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
        "model_id" => "rekord-fenster-delivery-note",
        "document_url" =>
          "https://images.box-id.com/insecure/w:0/h:0/el:t/rt:fit/g:ce:0:0/aHR0cHM6Ly9zMy5ldS1jZW50cmFsLTEuYW1hem9uYXdzLmNvbTo0NDMvbWVkaWFib3hpZC9iMjM2NzYxY2IyODM3Y2M0ZWU2YzU1NzdhNDA1MWI3OQ==.jpg",
        "api_key" => api_key,
        "endpoint" => endpoint
      })
    end
  end
end
