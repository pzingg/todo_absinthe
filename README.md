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
* The `order` field (part of the TodoMVC spec) is an auto-incremented (`:serial`) integer.
In the Elm TodoMVC implementation, this field was omitted.
* Have to use the `read_after_writes` option (PostgreSQL-specific) to grab DB values
after insert/update operations in order to return the `order` field to the Absinthe
reply correctly.


## Elm - Absinthe Transport over a Phoenix Channel

The Phoenix side sets up a `DocChannel` channel module for the topic "\*"
that is largely based on (meaning lots of code copying from) `Absinthe.Phoenix.Channel`.

Using the elm-phoenix client package, the Elm frontend joins this "\*" topic at startup.

Elm sends a "doc" event to the channel to make an Absinthe query or mutation, and
receives the data or error reply as constructed by Absinthe.

Elm should be able to handle the "itemsCreated", etc. GraphQL subscription messages
published or triggered by Absinthe on the "\*" topic, but these are apparently not
happening automatically as events on the "\*" topic.

The "\*" channel has pubsub, so that subscriptions can also be subscribed to it
by GraphiQL "on the fly". Following the protocol used by GraphiQL, we subscribe to
subscription messsages in Elm as follows:

1. Push a subscription document, using the subscription name (e.g. "itemsCreated"), and
specifying the fields of interest, to the "\*" topic. The payload of the reply
will contain a `subscriptionId` string, like "\_\_absinthe\_\_:doc:87829607".
2. Create a new client channel, in addition to the original "\*" channel,
using the `subscriptionId` string as the topic, and listening for `subscription:data` events.
3. Receive and decode incoming `subscription:data` payloads.

The `subscription:data` payloads include two components:

* `subscriptionId` - the same id used for the topic.
* `result` - a JSON value containing the standard GraphQL `data` reply.

More detailed comments can be found in the Todo.elm source file.


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
