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

## Error Handling

Since workflows are dynamic (and potentially user-provided), Workflow Engine and its actions need
to take great care of handling errors in a transparent way.

Workflow Engine uses the `{:error, %WorkflowEngine.Error{}}` return type if something unexpected
ocurred. Workflow Engine should never return an error tuple with another data type at the second
position.

Also, no exceptions should be raised during workflow evaluation. However, due to the manifold ways
invalid configuration or data could be supplied, it can't be fully ruled out. These cases are
considered a bug, though, and are worth fixing by expanding input validation and error handling.

##### `message`.

Errors contain a `message` binary, which is a human-readable description of the error, including
the formatted instruction pointer (to hint to the position in the workflow that likely caused the
error) and the configuration of the workflow step that failed.

Depending on the actions and configuration of a workflow, `message` could contain
sensitive information and might thus not be suitable for displaying to users.

##### `state`

The `state` field allows introspecting the state of the Workflow Engine at the time the error
occurred.

##### `recoverable`

The boolean `recoverable` field gives a best-effort estimation about whether retrying the workflow
could lead to a positive/error-free outcome or not. The decision is made based on the reason for
the error.

For example, retrying workflows with invalid configuration such as an invalid step descriptions,
unknown action names, malformed JsonLogic etc., will never lead to a successful result. In such
cases, errors are tagged with `recoverable: false`.

Softer errors, that typically originate from an external system such as a failed HTTP request or a
syntax error in a CSV file, are marked with `recoverable: true`. For these errors, the caller can
decide whether it wants to automatically or manually retry running the workflow.

## Tests

Run tests using `mix test` or, during development, `mix test.watch`.

Tests touching external systems should be tagged with `@tag :external_service` s.t.
they are (by default) skipped, which keeps the execution of the test suite fast and reliable.

To include those tests as well, use `mix test.including_external` or the `--include
external_service` flag.
