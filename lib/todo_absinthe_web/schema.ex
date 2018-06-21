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
  end

  subscription do
    field :added_item, :todo do
      config fn _args, _info ->
        {:ok, topic: "*"}
      end
    end

    field :updated_item, :todo do
      config fn _args, _info ->
        {:ok, topic: "*"}
      end
    end

    field :deleted_item, :todo do
      config fn _args, _info ->
        {:ok, topic: "*"}
      end
    end
  end
end
