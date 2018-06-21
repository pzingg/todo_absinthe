defmodule TodoAbsintheWeb.Resolvers.TodoResolver do
  alias TodoAbsinthe.Todo

  def list_todos(_args, _info) do
    {:ok, Todo.list_todos}
  end

  def create_item(%{input: attrs}, _info) do
    with {:ok, item} <- Todo.create_item(attrs) do
      Absinthe.Subscription.publish(TodoAbsintheWeb.Endpoint, item, added_item: "*")
      {:ok, item}
    end
  end

  def update_item(%{input: attrs}, _info) do
    with %{id: id} <- attrs, item = Todo.get_item!(id),
      {:ok, updated_item} <- Todo.update_item(item, attrs) do
      Absinthe.Subscription.publish(TodoAbsintheWeb.Endpoint, updated_item, updated_item: "*")
      {:ok, updated_item}
    end
  end

  def delete_item(%{id: id}, _info) do
    with item = Todo.get_item!(id),
      {:ok, deleted_item} <- Todo.delete_item(item) do
      Absinthe.Subscription.publish(TodoAbsintheWeb.Endpoint, deleted_item, deleted_item: "*")
      {:ok, deleted_item}
    end
  end
end
