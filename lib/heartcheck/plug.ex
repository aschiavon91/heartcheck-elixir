defmodule HeartCheck.Plug do
  @moduledoc """
  Plug to mount heartcheck in your plug-compatible app.

  Add to your router:

  ```elixir
  def MyApp.Router
    use Plug.Router
    # (...)
    forward "/monitoring", to: HeartCheck.Plug, heartcheck: MyHeart
  end
  ```

  Or phoenix pipeline (note the different syntax):

  ```elixir
  def MyApp.Router
    use MyApp.Web, :router

    # (...)

    scope "/", MyApp do
      pipe_through :browser

      # (...)

      forward "/monitoring", HeartCheck.Plug, heartcheck: MyHeart
    end
  end
  ```

  In any of the cases above, if you wish to cache the HeartCheck results for a
  time, mount the `HeartCheck.CachingPlug` instead of `HeartCheck.Plug`:

  ```elixir
  def MyApp.Router
    use Plug.Router

    require HeartCheck

    # (...)

    forward "/monitoring", to: HeartCheck.CachingPlug, heartcheck: MyHeart
  end
  ```

  or on Phoenix:

  ```elixir
  def MyApp.Router
    use MyApp.Web, :router

    require HeartCheck

    # (...)

    scope "/", MyApp do
      pipe_through :browser

      # (...)

      forward "/monitoring", HeartCheck.CachingPlug, heartcheck: MyHeart
    end
  end
  ```

  """

  @behaviour Plug

  require Logger

  import Plug.Conn

  alias HeartCheck.{Environment, Executor, Formatter}

  @impl Plug
  @spec init(term) :: term
  def init(options), do: Enum.into(options, %{})

  @impl Plug
  @spec call(Plug.Conn.t(), term) :: Plug.Conn.t()
  def call(conn = %Plug.Conn{path_info: ["health_check"]}, _params) do
    %{status: :ok}
    |> encode!()
    |> send_as_json(conn)
  end

  def call(conn = %Plug.Conn{path_info: ["environment"]}, _params) do
    get_env_info()
    |> encode!()
    |> send_as_json(conn)
  end

  def call(conn = %Plug.Conn{path_info: ["functional"]}, %{functional: heartcheck}) do
    heartcheck
    |> execute
    |> send_as_json(conn)
  end

  def call(conn = %Plug.Conn{path_info: []}, %{heartcheck: heartcheck}) do
    heartcheck
    |> execute
    |> send_as_json(conn)
  end

  def call(conn, _options) do
    conn |> send_resp(404, "not found") |> halt
  end

  @doc false
  @spec send_as_json(String.t(), Plug.Conn.t()) :: Plug.Conn.t()
  def send_as_json(body, conn) do
    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(200, body)
    |> halt
  end

  @doc false
  @spec execute(atom) :: String.t()
  def execute(heartcheck) do
    heartcheck
    |> Executor.execute()
    |> Enum.map(&Formatter.format/1)
    |> encode!()
  end

  @doc false
  @spec get_env_info :: Map.t()
  defp get_env_info do
    Environment.info()
  end

  @spec encode!(term()) :: String.t()
  defp encode!(payload) do
    encoder = Application.get_env(:heartcheck, :json_encoder, Jason)

    encoder.encode!(payload)
  end
end
