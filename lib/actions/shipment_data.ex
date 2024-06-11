defmodule WorkflowEngine.Actions.IngestShipmentData do
  @moduledoc """
  Sends ("ingests") data for a shipment using the delivery service's API.

  https://deliveries.box-id.com/apidocs/index.html

  ## Example

    %{
      "type" => "ingest_shipment_data",
      "shipment_type" => "some-type",
      "shipment_type_path" =>
      "id_path" => "params.shipment.id",
      "token_path" => "params.token",
      "data" => %{
        "obj" => [
          ["position", %{"var" => "position"}],
          ["finished", true]
        ]
      }
    }
  """
  use OK.Pipe

  @behaviour WorkflowEngine.Action

  alias WorkflowEngine.State

  @impl WorkflowEngine.Action
  def execute(state, step) do
    shipment_type = resolve_value_or_path(state, step, "shipment_type", true)
    client_id = resolve_value_or_path(state, step, "client_id", true)

    shipment_id = resolve_value_or_path(state, step, "shipment_id", false)
    shipment_token = resolve_value_or_path(state, step, "shipment_token", false)

    if shipment_id == nil && shipment_token == nil do
      raise WorkflowEngine.Error,
        message: "Either shipment id or token are required, but none were found."
    end

    data =
      get_data(state, step)
      |> Map.drop(~w(delivery_id _ref_token))
      |> Map.merge(
        if(shipment_id != nil,
          do: %{"delivery_id" => shipment_id},
          else: %{"_ref_token" => shipment_token}
        )
      )

    headers =
      %{
        "accept" => "application/json",
        "content-type" => "application/json"
      }
      |> Map.merge(
        if(shipment_token != nil,
          do: %{"bx-token-path" => "_ref_token"},
          else: %{}
        )
      )

    req =
      Req.new(
        base_url: get_service_host(),
        url: "/api/v1/ingest/:client_id/:shipment_type",
        path_params: [shipment_type: shipment_type, client_id: client_id],
        body: Jason.encode_to_iodata!(data),
        headers: headers
      )

    Req.post(req)
    |> WorkflowEngine.Actions.Http.unwrap_response(req)
    # Yes, this is hacky.
    ~> BXDK.InternalApi.postprocess_result(caller: BXDK.Deliveries.InternalApi)
    ~> then(&{state, &1})
  rescue
    # Wrap all error messages & add current state
    e in WorkflowEngine.Error ->
      reraise WorkflowEngine.Error,
              [message: "IngestShipmentData Action: " <> e.message, state: state],
              __STACKTRACE__
  end

  defp get_service_host(),
    do:
      Application.get_env(
        :workflow_engine,
        IngestShipmentData,
        []
      )
      |> Keyword.get(:api_host, "http://service-deliveries.b-x.info")

  defp resolve_value_or_path(state, step, key, required?) do
    case Map.fetch(step, key) do
      {:ok, value}
      when is_binary(value) and not is_nil(value) and value != "" ->
        value

      _ ->
        path = key <> "_path"

        case Map.fetch(step, path) do
          {:ok, path} when not is_nil(path) ->
            case State.get_var_path(state, path) do
              resolved_value
              when is_binary(resolved_value) and not is_nil(resolved_value) and
                     resolved_value != "" ->
                resolved_value

              other ->
                if required? do
                  raise WorkflowEngine.Error,
                    message:
                      "Required step parameter \"#{path}\" resolved to an illegal value (#{inspect(other)})."
                end
            end

          _ ->
            if required? do
              raise WorkflowEngine.Error,
                message: "Missing required step parameter \"#{key}\" or \"#{path}\"."
            end
        end
    end
  end

  defp get_data(state, step) do
    data_logic = Map.get(step, "data") || %{}

    State.run_json_logic(state, data_logic)
    |> case do
      result when not is_map(result) ->
        raise WorkflowEngine.Error,
          message:
            "Invalid data returned from evaluating logic, expected a map. (Logic #{inspect(data_logic)}, result #{inspect(result)})"

      result ->
        result
    end
  end
end
