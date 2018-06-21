# TodoAbsinthe

This is a port of TodoMVC app with an Elm frontend with Elixir/Absinthe/GraphQL backend.

Original Elm frontend code by Evan Czaplicki at https://github.com/evancz/elm-todomvc


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


## Elm - Absinthe Transport over a Phoenix Channel

The Phoenix side sets up a `DocChannel` channel module for the topic "\*"
that is largely based on (meaning lots of code copying from) `Absinthe.Phoenix.Channel`.

Using the elm-phoenix client package, the Elm frontend joins this "\*" topic at startup.

Elm sends a "doc" event to the channel to make an Absinthe query or mutation, and
receives the data or error reply as constructed by Absinthe.

Elm also handles the "addedItem", etc events on the channel that are put there by
the Absinthe subscriptions and triggers or explicit calls to `Absinthe.Subscription.publish`
in the resolver code.

Also, this "\*" channel has pubsub, so that subscriptions can also be subscribed to it
by GraphiQL "on the fly".


## Bugs / TODO

The original Elm TodoMVC persisted updates in browser local storage, which is
nice for persistence between browser sessions.  What is the best strategy for
an offline app that can go back online?  First, load from local storage, then
query the backend for more recent changes, and finally keep things in sync
by using Absinthe subscriptions if the backend store is modified by other users.

Hoping to find a clean implementation of this kind of syncing somewhere.


## Phoenix / Absinthe Info

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).
