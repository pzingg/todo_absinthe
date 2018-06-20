defmodule TodoAbsintheWeb.PageController do
  use TodoAbsintheWeb, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
