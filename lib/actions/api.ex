defmodule WorkflowEngine.Actions.Api do
  @moduledoc """
  Executes a request against the internal API using BXDK.
  """
  use OK.Pipe

  @behaviour WorkflowEngine.Action

  alias WorkflowEngine.State

  @impl WorkflowEngine.Action
  def execute(state, %{"type" => "api"} = step) do
    entity = get_required(step, "entity")
    operation = get_required(step, "operation")
    params_logic = get_required(step, "params")

    module =
      entity
      |> build_module()
      |> verify_module()

    function = build_function(operation)

    params = State.run_json_logic(state, params_logic)

    unless is_list(params) do
      raise WorkflowEngine.Error,
        message: "Params logic must return a list. Result: #{inspect(params)}",
        state: state
    end

    try do
      Kernel.apply(module, function, params)
      |> case do
        {:error, reason} ->
          {:error, reason}

        {:ok, result} ->
          {:ok, {state, result}}

        # Streams aren't returned as result types by BXDK
        stream when is_function(stream, 2) or is_struct(stream, Stream) ->
          {:ok, {state, stream}}
      end
    rescue
      UndefinedFunctionError ->
        arity = Enum.count(params)

        reraise WorkflowEngine.Error,
                [
                  message:
                    "Function #{module}.#{function}/#{arity} doesn't exist. (Arity counted from resolved params: #{Jason.encode!(params)})"
                ],
                __STACKTRACE__
    end
  rescue
    e in WorkflowEngine.Error ->
      reraise WorkflowEngine.Error,
              [message: "ApiAction: " <> e.message, state: state],
              __STACKTRACE__
  end

  defp get_required(step, key) do
    case Map.fetch(step, key) do
      {:ok, value} when not is_nil(value) ->
        value

      _ ->
        raise WorkflowEngine.Error,
          message: "ApiAction: Missing required step parameter \"#{key}\"."
    end
  end

  defp build_module(entity) when is_binary(entity) do
    entity = Macro.camelize(entity)

    try do
      String.to_existing_atom("Elixir.BXDK.#{entity}")
    rescue
      ArgumentError ->
        reraise WorkflowEngine.Error,
                [message: "BXDK entity \"#{entity}\" doesn't exist."],
                __STACKTRACE__
    end
  end

  defp verify_module(module) do
    if BXDK.api_module?(module) do
      module
    else
      raise WorkflowEngine.Error,
        message: "Module \"#{module}\" is not a valid BXDK API module."
    end
  end

  defp build_function(operation) when is_binary(operation) do
    String.to_existing_atom(operation)
  rescue
    ArgumentError ->
      reraise WorkflowEngine.Error,
              [message: "Function \"#{operation}\" doesn't exist."],
              __STACKTRACE__
  end
end
