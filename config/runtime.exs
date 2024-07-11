import Config
import ConfigHelpers

if config_env() == :test do
  config :bxdk, MQTT, enabled: false

  config :workflow_engine, WorkflowEngine.Actions.DocumentAi,
    api_key: get_env("WORKFLOW_DOCUMENT_AI_API_KEY", ""),
    endpoint: get_env("WORKFLOW_DOCUMENT_AI_API_ENDPOINT", "")
end
