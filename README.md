# TodoAbsinthe

This is a port of TodoMVC app with an Elm frontend with Elixir/Absinthe/GraphQL backend.


## Elm Installation Notes

Since the elm-phoenix package is an effect manager it is at the moment not available via
elm-package. Thus the recommended way to install the package is to use
elm-github-install. Simply add saschatimme/elm-phoenix to the dependencies in the
elm-package.json file:

```
# elm-package.json
{
  ...
  "dependencies": {
    ...
    "saschatimme/elm-phoenix": "0.3.0 <= v < 1.0.0",
    ...
  }
  ...
}
```

and install the package with elm-github-install.


## Ecto Notes

* PostgreSQL database with a todos table.
* Using string UUIDs for ids (configured in config/config.exs).
* The `order` field is an auto-incremented (`:serial`) integer.


## Sending GraphQL Documents on Websockets

```
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

    ... send reply
```


## Phoenix/Absinthe Info

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).
