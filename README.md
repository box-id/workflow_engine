# WorkflowEngine

Workflow Engine evaluates a series of actions and control instructions to perform requests against our internal API (using the BXDK package), tag data API, external HTTP APIs etc. using a JSON based [Workflow Language](./workflow_language.md).

```elixir
result_state =
  WorkflowEngine.evaluate(workflow,
    params: %{
      context: %{}
    },
    json_logic: MyService.JsonLogic,
    actions: %{
      "foo" => MyApp.FooAction
    }
  )
```

## Installation

This package can be installed by adding `workflow_engine` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:workflow_engine, github: "box-id/workflow_engine", tag: "0.1.0"}
  ]
end
```

## Tests

Run tests using `mix test` or, during development, `mix test.watch`.

Tests touching external systems should be tagged with `@tag :external_service` s.t.
they are (by default) skipped, which keeps the execution of the test suite fast and reliable.

To include those tests as well, use `mix test.including_external` or the `--include
external_service` flag.
