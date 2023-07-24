import Config

if config_env() == :test do
  config :bxdk, MQTT, enabled: false
end
