defmodule TodoAbsintheWeb.DocChannel do
  use Phoenix.Channel
  require Logger

  @moduledoc """
  DocChannel defines a Phoenix channel that we use to transport GraphQL operations
  from a client over WebSockets rather than over HTTP.  Code in this module liberally
  copied from the Absinthe.Phoenix.Channel module.  We hardcode our Schema module
  and the "default pipeline" into absinthe_config.
  """

  @doc false
  def join(_topic, _, socket) do
    absinthe_config = Map.get(socket.assigns, :absinthe, %{})

    opts =
      absinthe_config
      |> Map.get(:opts, [])
      |> Keyword.update(:context, %{pubsub: socket.endpoint}, fn context ->
        Map.put(context, :pubsub, socket.endpoint)
      end)

    absinthe_config =
      put_in(absinthe_config[:opts], opts)
      |> Map.put(:schema, TodoAbsintheWeb.Schema)
      |> Map.put(:pipeline, {__MODULE__, :default_pipeline})

    socket = socket |> assign(:absinthe, absinthe_config)
    {:ok, socket}
  end

  @doc false
  def handle_in("doc", payload, socket) do
    config = socket.assigns[:absinthe]

    opts =
      config.opts
      |> Keyword.put(:variables, Map.get(payload, "variables", %{}))

    query = Map.get(payload, "query", "")

    Absinthe.Logger.log_run(:debug, {
      query,
      config.schema,
      [],
      opts,
    })

    pipeline = Map.get(config, :pipeline)

    {reply, socket} = case run(query, config.schema, pipeline, opts) do
      {:ok, %{"subscribed" => topic}, context} ->
        :ok = Phoenix.PubSub.subscribe(socket.pubsub_server, topic, [
          fastlane: {socket.transport_pid, socket.serializer, []},
          link: true,
        ])
        socket = Absinthe.Phoenix.Socket.put_options(socket, context: context)
        {{:ok, %{subscriptionId: topic}}, socket}

      {:ok, %{data: _} = reply, context} ->
        socket = Absinthe.Phoenix.Socket.put_options(socket, context: context)
        {{:ok, reply}, socket}

      {:ok, %{errors: _} = reply, context} ->
        socket = Absinthe.Phoenix.Socket.put_options(socket, context: context)
        {{:error, reply}, socket}

      {:error, reply} ->
        {reply, socket}
    end

    Logger.debug("DocChannel reply #{inspect(reply)}")
    {:reply, reply, socket}
  end

  def handle_in("unsubscribe", %{"subscriptionId" => doc_id}, socket) do
    Phoenix.PubSub.unsubscribe(socket.pubsub_server, doc_id)
    Absinthe.Subscription.unsubscribe(socket.endpoint, doc_id)
    {:reply, {:ok, %{subscriptionId: doc_id}}, socket}
  end

  defp run(document, schema, pipeline, options) do
    {module, fun} = pipeline
    case Absinthe.Pipeline.run(document, apply(module, fun, [schema, options])) do
      {:ok, %{result: result, execution: res}, _phases} ->
        {:ok, result, res.context}
      {:error, msg, _phases} ->
        {:error, msg}
    end
  end

  @doc false
  def default_pipeline(schema, options) do
    schema
    |> Absinthe.Pipeline.for_document(options)
  end
end
