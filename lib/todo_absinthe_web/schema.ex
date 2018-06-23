defmodule TodoAbsintheWeb.Schema do
  use Absinthe.Schema
  import_types TodoAbsintheWeb.Schema.ContentTypes

  alias TodoAbsintheWeb.Resolvers.TodoResolver
  alias TodoAbsintheWeb.Schema.Middleware

  query do
    @desc "Get all todos"
    field :todos, list_of(:todo) do
      resolve &TodoResolver.list_todos/2
    end
  end

  mutation do
    field :create_item, :todo do
      arg :input, non_null(:todo_input)
      resolve &TodoResolver.create_item/2
      middleware Middleware.ChangesetErrors
    end

    field :update_item, :todo do
      arg :input, non_null(:todo_input)
      resolve &TodoResolver.update_item/2
      middleware Middleware.ChangesetErrors
    end

    field :delete_item, :todo do
      arg :id, non_null(:string)
      resolve &TodoResolver.delete_item/2
      middleware Middleware.ChangesetErrors
    end

    field :update_batch, list_of(:todo) do
      arg :input, non_null(list_of(non_null(:todo_input)))
      resolve &TodoResolver.update_batch/2
      middleware Middleware.ChangesetErrors
    end

    field :delete_batch, list_of(:todo) do
      arg :ids, non_null(list_of(non_null(:string)))
      resolve &TodoResolver.delete_batch/2
      middleware Middleware.ChangesetErrors
    end
  end

  subscription do
    field :items_created, list_of(:todo) do
      config fn _args, _info ->
        {:ok, topic: "*"}
      end
    end

    field :items_updated, list_of(:todo) do
      config fn _args, _info ->
        {:ok, topic: "*"}
      end
    end

    field :items_deleted, list_of(:todo) do
      config fn _args, _info ->
        {:ok, topic: "*"}
      end
    end
  end
end
