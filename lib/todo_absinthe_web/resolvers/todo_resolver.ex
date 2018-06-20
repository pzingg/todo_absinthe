defmodule TodoAbsintheWeb.Resolvers.TodoResolver do
  alias TodoAbsinthe.Todo

  def list_todos(_args, _info) do
    {:ok, Todo.list_todos }
  end

end
