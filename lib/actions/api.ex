defmodule WorkflowEngine.Actions.Api do
  @moduledoc """
  Executes a request against the internal API using BXDK.
  """
  use OK.Pipe

  @behaviour WorkflowEngine.Action

  alias WorkflowEngine.State

  @impl WorkflowEngine.Action
  def execute(state, %{"type" => "api"} = step) do
    module = get_module(step)
    function = get_function(step)
    args = get_args(step, state)

    try do
      Kernel.apply(module, function, args)
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
        arity = Enum.count(args)

        reraise WorkflowEngine.Error,
                [
                  message:
                    "Function #{module}.#{function}/#{arity} doesn't exist. (Arity counted from resolved args: #{Jason.encode!(args)})"
                ],
                __STACKTRACE__
    end
  rescue
    # Wrap all error messages & add current state
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

  defp get_module(step) do
    entity =
      step
      |> get_required("entity")
      |> Macro.camelize()

    try do
      Module.safe_concat(BXDK, entity)
    rescue
      ArgumentError ->
        reraise WorkflowEngine.Error,
                [message: "BXDK entity \"#{entity}\" doesn't exist."],
                __STACKTRACE__
    end
    |> verify_bxdk_api_module()
  end

  defp verify_bxdk_api_module(module) do
    if BXDK.api_module?(module) do
      module
    else
      raise WorkflowEngine.Error,
        message: "Module \"#{module}\" is not a valid BXDK API module."
    end
  end

  defp get_function(step) do
    operation = get_required(step, "operation")

    try do
      String.to_existing_atom(operation)
    rescue
      ArgumentError ->
        reraise WorkflowEngine.Error,
                [message: "Function \"#{operation}\" doesn't exist."],
                __STACKTRACE__
    end
  end

  defp get_args(step, state) do
    args_logic = get_required(step, "args")
    args = State.run_json_logic(state, args_logic)

    unless is_list(args) do
      raise WorkflowEngine.Error,
        message: "Args logic must return a list. Result: #{inspect(args)}",
        state: state
    end

    args
  end
end
