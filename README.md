# TodoAbsinthe

This is a port of TodoMVC app with an Elm frontend with Elixir/Absinthe/GraphQL backend.

Original Elm frontend code by Evan Czaplicki at https://github.com/evancz/elm-todomvc


## Elm Installation Notes

Since the [elm-phoenix package](https://github.com/saschatimme/elm-phoenix)
is an effect manager it is at the moment (Elm v0.18) not available via
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

and install the package with [elm-github-install](https://github.com/gdotdesign/elm-github-install).


## Ecto Notes

* PostgreSQL database with a todos table.
* Using string UUIDs for ids (configured in config/config.exs).
* The `order` field (part of the TodoMVC spec) is an auto-incremented (`:serial`) integer.
In the Elm TodoMVC implementation, this field was omitted.
* Have to use the `read_after_writes` option (PostgreSQL-specific) to grab DB values
after insert/update operations in order to return the `order` field to the Absinthe
reply correctly.


## Elm - Absinthe Transport over a Phoenix Channel

While GraphQL servers are most commonly accessed by clients over HTTP, the
Elm frontend in this project uses a websocket transport, implemented with functions
in the courtesy of the elm-phoenix project (see Elm Notes section above).

### Server side channel setup

On the server side we set up a `DocChannel` channel module for the topic "\*"
that is largely based on (meaning lots of code copying from) `Absinthe.Phoenix.Channel`.
The DocChannel has pubsub enabled, so that subscriptions can also be subscribed to it
by Elm (and GraphiQL).

See lib/todo_absinthe_web/channels/doc_channel.ex source file for more info.

### Client side channel setup

On the Elm side, the frontend creates and subscribes to a Phoenix channel with the "\*"
topic at startup. When the channel is joined, the frontend then creates and subscribes
to channels for the GraphQL subscriptions. This channel is monitored for status changes.

Following the protocol used by GraphiQL, Elm can subscribe to GraphQL subscription
messages as follows:

1. Push a subscription document (see below), using the subscription name
(e.g. "itemsCreated"), and specifying the fields of interest, to the "\*" topic.
The payload of the reply will contain a `subscriptionId` string, like
"\_\_absinthe\_\_:doc:87829607".
2. Create a new client channel, in addition to the original "\*" channel,
using the `subscriptionId` string as the topic, and listening for `subscription:data` events.
3. Receive and decode incoming `subscription:data` payloads.

The `subscription:data` payloads include two components:

* `subscriptionId` - the same id used for the topic.
* `result` - a JSON value containing the standard GraphQL `data` reply.

More detailed comments can be found in the source file at assets/elm/src/Todo.elm.
The footer in the user interface has a clickable link for exercising the pubsub.
Clicking the link will either subscribe to the subscriptions "itemsCreated",
"itemsUpdated" and "itemsDeleted", or unsubscribe from them.

### Client side GraphQL operations over websockets

To make an Absinthe query, mutation, or subscription request, Elm pushes a "doc" event
to the "\*" channel. The payload is JSON encoded with GraphQL variables and the operation
document. The reply constructed by Absinthe is received as an Elm message
and the payload decoded as necessary.

To unsubscribe from a subscription, Elm pushes an "unsubscribe" event with the
subscription ID encoded in the payload.


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
