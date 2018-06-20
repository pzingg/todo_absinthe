defmodule TodoAbsinthe.TodoTest do
  use TodoAbsinthe.DataCase

  alias TodoAbsinthe.Todo

  describe "todos" do
    alias TodoAbsinthe.Todo.Item

    @valid_attrs %{completed: true, order: 42, title: "some title"}
    @update_attrs %{completed: false, order: 43, title: "some updated title"}
    @invalid_attrs %{completed: nil, order: nil, title: nil}

    def item_fixture(attrs \\ %{}) do
      {:ok, item} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Todo.create_item()

      item
    end

    test "list_todos/0 returns all todos" do
      item = item_fixture()
      assert Todo.list_todos() == [item]
    end

    test "get_item!/1 returns the item with given id" do
      item = item_fixture()
      assert Todo.get_item!(item.id) == item
    end

    test "create_item/1 with valid data creates a item" do
      assert {:ok, %Item{} = item} = Todo.create_item(@valid_attrs)
      assert item.completed == true
      assert item.order == 42
      assert item.title == "some title"
    end

    test "create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Todo.create_item(@invalid_attrs)
    end

    test "update_item/2 with valid data updates the item" do
      item = item_fixture()
      assert {:ok, item} = Todo.update_item(item, @update_attrs)
      assert %Item{} = item
      assert item.completed == false
      assert item.order == 43
      assert item.title == "some updated title"
    end

    test "update_item/2 with invalid data returns error changeset" do
      item = item_fixture()
      assert {:error, %Ecto.Changeset{}} = Todo.update_item(item, @invalid_attrs)
      assert item == Todo.get_item!(item.id)
    end

    test "delete_item/1 deletes the item" do
      item = item_fixture()
      assert {:ok, %Item{}} = Todo.delete_item(item)
      assert_raise Ecto.NoResultsError, fn -> Todo.get_item!(item.id) end
    end

    test "change_item/1 returns a item changeset" do
      item = item_fixture()
      assert %Ecto.Changeset{} = Todo.change_item(item)
    end
  end
end
