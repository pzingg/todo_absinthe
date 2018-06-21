defmodule TodoAbsintheWeb.Router do
  use TodoAbsintheWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api" do
    pipe_through :api

    forward "/", Absinthe.Plug,
      schema: TodoAbsintheWeb.Schema
  end

  scope "/graphiql" do
    pipe_through :api

    forward "/", Absinthe.Plug.GraphiQL,
      schema: TodoAbsintheWeb.Schema,
      interface: :simple,
      socket: TodoAbsintheWeb.UserSocket
  end

  # Main route to render Elm frontend
  # Use the default browser stack
  scope "/", TodoAbsintheWeb do
    pipe_through :browser

    get "/", PageController, :index
  end
end
