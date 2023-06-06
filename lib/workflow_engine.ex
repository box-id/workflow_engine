defmodule WorkflowEngine do
  use OK.Pipe

  alias WorkflowEngine.Actions
  alias WorkflowEngine.State

  @spec evaluate(map(), keyword()) :: {:error, any} | {:ok, State.t()}
  def evaluate(workflow, opts_or_state \\ [])

  def evaluate(%State{} = state, %{"steps" => steps}) do
    steps_with_index = steps |> List.wrap() |> Enum.with_index()
    eval_steps(state, steps_with_index)
  end

  def evaluate(%State{} = state, steps) when is_list(steps) do
    steps_with_index = steps |> Enum.with_index()
    eval_steps(state, steps_with_index)
  end

  def evaluate(%State{} = state, step) when is_map(step) do
    steps_with_index = step |> List.wrap() |> Enum.with_index()
    eval_steps(state, steps_with_index)
  end

  def evaluate(%State{} = state, _workflow) do
    raise WorkflowEngine.Error,
      message: "Unable to get steps from workflow",
      state: state
  end

  def evaluate(workflow, opts) when is_list(opts) do
    state = %State{
      vars: %{
        "params" => Keyword.get(opts, :params, %{})
      },
      json_logic_mod: Keyword.get(opts, :json_logic, JsonLogic)
    }

    evaluate(state, workflow)
  end

  defp eval_steps(state, [{step, idx} | rest]) do
    state
    |> State.push_ip(idx)
    |> State.set_current_step(step)
    |> eval_step(step)
    ~> State.pop_ip()
    ~>> eval_steps(rest)
  end

  defp eval_steps(state, []) do
    # Just because we're out of steps doesn't mean that we're finished with the whole workflow (could be a sub-workflow)
    if State.instruction_depth(state) == 0 do
      State.finalize(state)
    else
      state
    end
    |> OK.wrap()
  end

  defp eval_step(state, %{"if" => condition, "then" => then_flow} = control) do
    state
    |> State.update_ip(:if)
    |> State.run_json_logic(condition)
    |> if do
      state
      |> State.update_ip({:if, :then})
      |> evaluate(then_flow)
    else
      if else_flow = Map.get(control, "else") do
        state
        |> State.update_ip({:if, :else})
        |> evaluate(else_flow)
      else
        state
        |> OK.wrap()
      end
    end
  end

  defp eval_step(state, %{"loop" => loop_logic, "do" => do_flow} = control) do
    binding_name = Map.fetch(control, "element")

    binding_index_name =
      case binding_name do
        :error -> :error
        {:ok, name} -> "#{name}_index"
      end

    state =
      state
      |> State.update_ip(:loop)
      |> State.snapshot_var(binding_name)
      |> State.snapshot_var(binding_index_name)
      |> State.snapshot_var("loop")

    iterable = State.run_json_logic(state, loop_logic)

    # provide descriptive error if the logic's result is not iterable.
    if Enumerable.impl_for(iterable) == nil do
      raise WorkflowEngine.Error,
        message: "Loop value not iterable.\n\nValue:\n#{inspect(iterable)}",
        state: state
    end

    iterable
    |> Stream.with_index()
    |> Enum.reduce_while(state, fn {iter_item, idx}, state ->
      state
      |> State.update_ip({:loop, idx})
      |> State.put_var(binding_name, iter_item)
      |> State.put_var(binding_index_name, idx)
      |> State.put_var("loop", %{"element" => iter_item, "element_index" => idx})
      |> evaluate(do_flow)
      |> case do
        {:ok, state} -> {:cont, state}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> OK.wrap()
    ~> State.restore_var(binding_name)
    ~> State.restore_var(binding_index_name)
    ~> State.restore_var("loop")
  end

  defp eval_step(state, %{"yield" => yield_logic}) do
    state = State.update_ip(state, :yield)

    data = State.run_json_logic(state, yield_logic)

    State.yield(state, data)
    |> OK.wrap()
  end

  defp eval_step(state, %{"type" => action_type} = step) do
    state = State.update_ip(state, :action)

    case action_type do
      "api" ->
        state
        |> State.update_ip({:action, :api})
        |> Actions.Api.execute(step)

      "_dummy" ->
        {:ok, Map.fetch!(step, "value")}

      unknown ->
        raise WorkflowEngine.Error,
          message: "Unknown action type #{inspect(unknown)}",
          state: state
    end
    |> case do
      {:ok, {state, result}} ->
        case Map.fetch(step, "result") do
          {:ok, result_description} ->
            state
            |> State.update_ip({:action, :store_result})
            |> store_result(result, result_description)
            |> OK.wrap()

          :error ->
            {:ok, state}
        end

      {:error, reason} ->
        # IDEA: Some errors/error types might be allowed in the future

        # Reuse WorkflowEngine.Error's state-to-string behavior
        message =
          %WorkflowEngine.Error{
            message: "Workflow action failed with reason:\n#{inspect(reason)}",
            state: state
          }
          |> Exception.message()

        {:error, message}
    end
  end

  defp eval_step(state, step) do
    raise WorkflowEngine.Error,
      message: "Step instructions not recognized:\n#{inspect(step)}",
      state: state
  end

  defp store_result(state, result, %{"transform" => transform_logic} = description) do
    transformed_result =
      state
      |> State.put_var("action", %{"result" => result})
      |> State.run_json_logic(transform_logic)

    store_result(state, transformed_result, Map.delete(description, "transform"))
  end

  defp store_result(state, result, %{"as" => binding_name}) when is_binary(binding_name) do
    State.put_var(state, binding_name, result)
  end

  defp store_result(state, _result, _description) do
    raise WorkflowEngine.Error,
      message: "Result description missing or invalid 'as'.",
      state: state
  end
end
