defmodule TodoAbsintheWeb.Schema.ContentTypes do
  use Absinthe.Schema.Notation
  import_types Absinthe.Type.Custom

  object :todo do
    field :id, non_null(:string)
    field :title, non_null(:string)
    field :order, non_null(:integer)
    field :completed, non_null(:boolean)
    field :inserted_at, non_null(:datetime)
    field :updated_at, non_null(:datetime)
  end

  input_object :todo_input do
    field :id, :string
    field :title, non_null(:string)
    field :completed, non_null(:boolean)
  end

end
