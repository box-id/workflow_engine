# Workflow Language

## Goal

The Workflow Language (WL) defines a data format that expresses actionable steps and control flow instructions to act as
a data-driven scripting language for solving simple tasks in our platform.

## General Format

A workflow is an object that has an array of `steps` and possibly other information about how to handle execution (TBD).

```typescript
type Step = Action | Control;

interface Workflow {
  steps: Step | Step[];
  // TBD: options...
  timeout?: number;
}
```

## Actions

Actions are used to modify external state as part of a workflow. The available actions and their respective
configuration are not necessarily part of the WL specification. The only required field is `type` s.t. the evaluation
engine can dispatch accordingly.

```typescript
interface Action {
  type: string;
  result?: ResultDescription;
}
```

If the result of the action should be available to later steps, `result` describes how to transform the data and under
what name to store it.

Within the `transform` logic, the action's immediate result (e.g. a response body) is available under `action.result`.

```typescript
interface ResultDescription {
  as: string;
  transform?: JsonLogic;
}
```

### ApiAction

Executes an action using the BXDK/Internal API SDK. Operations are encoded using `entity`, `operation` and a list of
`args` (arguments to the function described by entity and operation). The concrete values must be looked up using the [BXDK documentation](https://intern-docs.box-id.com/sdk_internal_api_elixir/api-reference.html).

```typescript
interface ApiAction extends Action {
  type: "api";
  entity: string;
  operation: string;
  // should result in type: (string | number | boolean | Record<string, string | number | boolean>)[];
  args: JsonLogic;
}
```

Currently, no special attention is being paid to authentication, neither:

1. That the correct client_id is used in the correct place in the action's args
2. That the user who created the batch operation has the required permissions to execute the modification

### HTTPAction

Executes a generic HTTP action.

```typescript
interface HTTPAction extends Action {
  type: "http";
  url: string;
  method: string;
  // should result in type: [string, string][];
  query?: JsonLogic;
  // should result in type: Record<string, any>;
  headers?: JsonLogic;
  // should result in type: Record<string, any>;
  body?: JsonLogic;
}
```

## Controls

Since linear execution of a series of actions is not sufficient to complete even moderately complex tasks, control
elements can be used to dynamically customize the workflow.

```typescript
type Control = If | Loop | Yield;
```

### If

The conditional executes the `then` steps/workflow if the `if` condition is true, or the optional `else` steps/workflow
otherwise. If a workflow is given for `then` or `else` branch, its options might be ignored by the engine (TBD).

```typescript
interface If {
  if: JsonLogic;
  then: Workflow | Step | Step[];
  else?: Workflow | Step | Step[];
}
```

### Loop

The loop control executes the sub-workflow (`do`) for every item of the list extracted using the `loop` expression.

```typescript
interface Loop {
  loop: JsonLogic;
  element?: string;
  do: Workflow | Step | Step[];
}
```

#### Context Data

To sub-workflows, the current loop element is available as variable `loop.element` and, if given, under the name defined by `element`. Additionally, the current element's index is available as `loop.element_index` and optionally `<element>_index`.

```typescript
interface LoopContext {
  "loop.element": any;
  "loop.element_index": number;
  "<element>"?: any;
  "<element>_index"?: any;
}
```

When nesting loops, the inner loop's element will be available under `loop.element`. To keep access to the outer loop's current element, its `element` option needs to be used to create a named binding.

### Yield

The yield control _emits_ data to the caller of the workflow. The _meaning_ of yielded data depends entirely on the
caller and might even change throughout the workflow.

For example, a workflow could yield items that need to be worked on later (and the caller would collect them in a list)
or it could yield metadata about the current workflow which gets collected in an object.

```typescript
interface Yield {
  yield: JsonLogic;
}
```

## Context & Variables

Context values and variables can be used by steps and controls through the use of the JsonLogic `{ var: "path" }`
operator.

The workflow's caller might give a predefined set of params to the workflow. These are available under the `params` key
(e.g. `params.client_id`).

Any (intermediately) stored values, e.g. from action results or loop bindings are directly stored under the given name
(e.g. `updateTag.updated_at` or `currentTag`).
