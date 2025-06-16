import Config
import ConfigHelpers

if config_env() == :test do
  config :bxdk, MQTT, enabled: false
end
