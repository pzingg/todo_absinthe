defmodule TodoAbsinthe.Todo.Item do
  use Ecto.Schema
  import Ecto.Changeset


  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "todos" do
    field :completed, :boolean, default: false
    field :order, :integer
    field :title, :string

    timestamps()
  end

  @doc false
  def changeset(item, attrs) do
    item
    |> cast(attrs, [:title, :order, :completed])
    |> validate_required([:title, :order, :completed])
  end
end
