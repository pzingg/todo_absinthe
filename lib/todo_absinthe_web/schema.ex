defmodule TodoAbsintheWeb.Schema do
  use Absinthe.Schema
  import_types TodoAbsintheWeb.Schema.ContentTypes

  alias TodoAbsintheWeb.Resolvers.TodoResolver

  query do
    @desc "Get all todos"
    field :todos, list_of(:todo) do
      resolve &TodoResolver.list_todos/2
    end
  end
end
