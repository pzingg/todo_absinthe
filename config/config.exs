# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :todo_absinthe,
  ecto_repos: [TodoAbsinthe.Repo]

config :todo_absinthe, TodoAbsinthe.Repo,
  migration_primary_key: [id: :uuid, type: :binary_id]

# Configures the endpoint
config :todo_absinthe, TodoAbsintheWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "bKuXnxtobV6+vfXetsdwmuehT1HOif5cEiMAkCziYtsVA0OoScp+Uc+diatYxqH+",
  render_errors: [view: TodoAbsintheWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: TodoAbsinthe.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
