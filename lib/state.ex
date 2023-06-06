defmodule WorkflowEngine.State do
  defstruct vars: %{},
            json_logic_mod: JsonLogic,
            yield_acc: [],
            current_step: nil,
            instruction_pointer: [],
            instruction_history: [],
            # Internally used to snapshot and later restore vars to that state.
            var_snapshots: %{}

  require Logger

  def get_var(%__MODULE__{} = state, key) when is_binary(key) do
    Map.get(state.vars, key)
  end

  def put_var(%__MODULE__{} = state, key, value) when is_binary(key) do
    update_in(state.vars, &Map.put(&1, key, value))
  end

  def put_var(%__MODULE__{} = state, {:ok, key}, value) when is_binary(key),
    do: put_var(state, key, value)

  def put_var(%__MODULE__{} = state, :error, _value), do: state

  def delete_var(%__MODULE__{} = state, key) when is_binary(key) do
    update_in(state.vars, &Map.delete(&1, key))
  end

  def snapshot_var(%__MODULE__{} = state, key) when is_binary(key) do
    case Map.fetch(state.vars, key) do
      :error ->
        state

      {:ok, value} ->
        put_in(state, [Access.key(:var_snapshots), key], value)
    end
  end

  def snapshot_var(%__MODULE__{} = state, {:ok, key}) when is_binary(key),
    do: snapshot_var(state, key)

  def snapshot_var(state, :error), do: state

  def restore_var(%__MODULE__{} = state, key) when is_binary(key) do
    case pop_in(state, [Access.key(:var_snapshots), Access.key(key, :not_found)]) do
      {:not_found, state} ->
        delete_var(state, key)

      {value, state} ->
        put_var(state, key, value)
    end
  end

  def restore_var(%__MODULE__{} = state, {:ok, key}) when is_binary(key),
    do: restore_var(state, key)

  def restore_var(state, :error), do: state

  def run_json_logic(%__MODULE__{} = state, logic) do
    state.json_logic_mod.apply(logic, state.vars)
  rescue
    e in UndefinedFunctionError ->
      reraise WorkflowEngine.Error,
              [
                message:
                  "Error executing JsonLogic. Maybe the module used to evaluate JsonLogic doesn't exist? Original error: " <>
                    Exception.message(e),
                state: state
              ],
              __STACKTRACE__

    e ->
      reraise WorkflowEngine.Error,
              [
                message: "JsonLogic Error: " <> Exception.message(e),
                state: state
              ],
              __STACKTRACE__
  end

  def finalize(%__MODULE__{} = state) do
    if instruction_depth(state) !== 0 do
      Logger.warn(
        "WorkflowEngine.State: finalize called with instruction_depth = #{instruction_depth(state)}. Instruction pointer: #{inspect(state.instruction_pointer)}"
      )
    end

    update_in(state.yield_acc, &Enum.reverse/1)
  end

  def yield(%__MODULE__{} = state, data) do
    update_in(state.yield_acc, &[data | &1])
  end

  def get_yielded(%__MODULE__{} = state) do
    state.yield_acc
  end

  def set_current_step(%__MODULE__{} = state, step) do
    %{state | current_step: step}
  end

  def push_ip(%__MODULE__{} = state, number) do
    update_in(state.instruction_pointer, &[{number, :unknown_step} | &1])
    |> archive_ip()
  end

  def update_ip(%__MODULE__{} = state, data) do
    update_in(state.instruction_pointer, fn [{idx, _} | tail] ->
      [{idx, data} | tail]
    end)
    |> archive_ip()
  end

  def pop_ip(%__MODULE__{} = state) do
    update_in(state.instruction_pointer, fn [_hd | tail] ->
      tail
    end)
  end

  defp archive_ip(%__MODULE__{} = state) do
    update_in(state.instruction_history, fn history ->
      [Enum.reverse(state.instruction_pointer) | history]
    end)
  end

  def instruction_depth(%__MODULE__{} = state) do
    Enum.count(state.instruction_pointer)
  end
end
