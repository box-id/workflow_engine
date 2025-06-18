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

### HTTPAction

Executes a generic HTTP action.

```ts
interface HTTPAction extends Action {
  type: "http";
  url: string;
  method?: string;
  path?: string | JsonLogic[];
  query?: JsonLogic;
  headers?: Record<string, string>;
  body?: string | JsonLogic;
  auth_token?: string | JsonLogic;
}
```

#### `url`

Mandatory request target, including schema (http/https), hostname, path and query.

If the `WORKFLOW_ALLOWED_HTTP_HOSTS` environment variable is set to a comma-separated list of host
names in the [minimatch](https://github.com/isaacs/minimatch) syntax, only these hosts are allowed
to be contacted.

#### `method`

HTTP request method to use. Supports `get` (the default), `post`, `put`, `patch`, and `delete`.

#### `path`

An optional, additional argument for path which can be a list of JsonLogic segments that will be
joined by `/`.

Example:

```json
"path": ["api", "v1", %{"var": "params.entityType"}]
```

If `url` already contains a path, the value of this argument is appended to `url`'s path:

- If `path` is absolute (starts with `/`), it fully replaces the `url`'s path.
- If `path` is relative (starts with a segment or `./`), it is appended. If `url` doesn't end in
  `/`, `path` replaces the last segment (or multiple if `path` starts with `../..`)

#### `query`

JsonLogic that resolves to an object that will be encoded to query string, values can be strings,
numbers, booleans, or arrays of these types.

Binary values will be passed through as-is.

If `url` already contains a query string, `query` will be appended to it.

#### `headers`

Customize headers by specifying a map of key-value-pairs. Does not support JsonLogic.
All header names will be downcased before sending to allow overriding the default headers.

By default, `accept: application/json` will be sent (and a `content-type` header depending on `body`).

#### `body`

Request body. Supported for all methods, but only recommended for POST, PUT and PATCH.

Can be a (pre-encoded) binary or a JsonLogic that resolves to either a map or a list. In the later
case, `content-type: application/json` will be added to the request headers.

#### `auth_token`

String or JsonLogic. If set to/resolves to a string, it will be used as token in an `Authorization:
Bearer <TOKEN>` header.

Example:

```json
"auth_token": {"var": "params.user_token"}
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
