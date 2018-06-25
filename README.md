# TodoAbsinthe

This is a port of TodoMVC app with an Elm frontend with Elixir/Absinthe/GraphQL backend.

Original Elm frontend code by Evan Czaplicki at https://github.com/evancz/elm-todomvc


## Building the Elm Frontend

To compile the Elm frontend, you will obviously need to
(install the Elm system tools)[https://guide.elm-lang.org/install.html] on your machine
and install the package dependencies specified in `assets/elm/elm-package.json`.

Since the [elm-phoenix package](https://github.com/saschatimme/elm-phoenix)
is an effect manager it is at the moment (Elm v0.18) not available via
elm-package. Thus the recommended way to install the elm-phoenix package is to use the
[elm-github-install package manager](https://github.com/gdotdesign/elm-github-install).

Then, to rebuild the Elm frontend manually:

```bash
cd assets/elm
elm-github-install
elm-make --debug --warn --output=../js/elm-main.js src/Todo.elm
```

Or just use the Elixir project's brunch build tool (which is automatically invoked when
starting the dev server--see the next section of this README file). The brunch configuration at
`assets/brunch-config.js` will require installation of the
[npm elm-brunch plugin](https://github.com/madsflensted/elm-brunch). After installation,
verify that there is an `elm-brunch` line in the `devDependencies` of `assets/package.json`.
If `elm-brunch` is missing from the package.json file, running brunch will ignore
the `elmBrunch` plugin configuration silently and will not compile the `elm/src/Todo.elm`
source file.


## Building and Starting the Server

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please
[check the Phoenix deployment guides](http://www.phoenixframework.org/docs/deployment).


## Ecto / Database Notes

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

See the `lib/todo_absinthe_web/channels/doc_channel.ex` source file for more information.

### Client side channel setup

On the Elm side, the frontend creates and subscribes to a Phoenix channel with the "\*"
topic at startup. This channel is configured with callbacks that monitor status changes
and errors.

When the "\*" channel is joined, the Elm frontend then creates and subscribes
to additional channels for the GraphQL subscriptions.

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

More detailed comments can be found in the single Elm source file located in
the repository at `assets/elm/src/Todo.elm`.

A clickable link was added to the original footer in the Elm user interface in order
to exercise pubsub operations. Clicking the link will either subscribe to the
subscriptions "itemsCreated", "itemsUpdated" and "itemsDeleted", or unsubscribe from them.

### Client side GraphQL operations over websockets

To make an Absinthe query, mutation, or subscription request, Elm pushes a "doc" event
to the "\*" channel. The payload is JSON encoded with GraphQL variables and the operation
document. The reply constructed by Absinthe is received as an Elm message
and the payload decoded as necessary.

To unsubscribe from a subscription, Elm pushes an "unsubscribe" event with the
subscription ID encoded in the payload.


## TODO: Syncing Offline Edits

The original Elm TodoMVC persisted updates in browser local storage, which is
nice for persistence between browser sessions.  What is the best strategy for
an offline app that can go back online?  First, load from local storage, then
query the backend for more recent changes, and finally keep things in sync
by using Absinthe subscriptions if the backend store is modified by other users.

Hoping to find a clean implementation of this kind of syncing somewhere.

Currently, the code does monitor for changes using GraphQL subscriptions and
updates the frontend model state if backend changes (adds, updates and deletes)
from other clients are detected, but does not detect network disconnects, nor does
it attempt to sync items modified when offline back to the server.
