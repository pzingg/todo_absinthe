defmodule TodoAbsintheWeb.Resolvers.TodoResolver do
  alias TodoAbsinthe.Todo

  def list_todos(_args, _info) do
    {:ok, Todo.list_todos}
  end

  def create_item(%{input: attrs}, _info) do
    with {:ok, created_item} <- Todo.create_item(attrs) do
      Absinthe.Subscription.publish(TodoAbsintheWeb.Endpoint, [created_item], items_created: "*")
      {:ok, created_item}
    end
  end

  def update_item(%{input: attrs}, _info) do
    with %{id: id} <- attrs, item = Todo.get_item!(id),
      {:ok, updated_item} <- Todo.update_item(item, attrs) do
      Absinthe.Subscription.publish(TodoAbsintheWeb.Endpoint, [updated_item], items_updated: "*")
      {:ok, updated_item}
    end
  end

  def delete_item(%{id: id}, _info) do
    with item = Todo.get_item!(id),
      {:ok, deleted_item} <- Todo.delete_item(item) do
      Absinthe.Subscription.publish(TodoAbsintheWeb.Endpoint, [deleted_item], items_deleted: "*")
      {:ok, deleted_item}
    end
  end

  def update_batch(%{input: items}, _info) do
    {updated_items, errors} = List.foldr(items, {[], []}, fn (attrs, {updated, errored}) ->
      with %{id: id} <- attrs, item = Todo.get_item!(id),
        {:ok, updated_item} <- Todo.update_item(item, attrs) do
        {[updated_item | updated], errored}
      else
        error ->
          {updated, [error | errored]}
      end
    end)
    case {updated_items, errors} do
      {[], []} ->
        {:ok, []}
      {[], _} ->
        {:error, errors}
      _ ->
        Absinthe.Subscription.publish(TodoAbsintheWeb.Endpoint, updated_items, items_updated: "*")
        {:ok, updated_items}
    end
  end

  def delete_batch(%{ids: ids}, _info) do
    {deleted_items, errors} = List.foldr(ids, {[], []}, fn (id, {deleted, errored}) ->
      with item = Todo.get_item!(id),
        {:ok, deleted_item} <- Todo.delete_item(item) do
        {[deleted_item | deleted], errored}
      else
        error ->
          {deleted, [error | errored]}
      end
    end)
    case {deleted_items, errors} do
      {[], []} ->
        {:ok, []}
      {[], _} ->
        {:error, errors}
      _ ->
        Absinthe.Subscription.publish(TodoAbsintheWeb.Endpoint, deleted_items, items_deleted: "*")
        {:ok, deleted_items}
    end
  end
end
