defmodule Romeo.Transports.TCP do
  @moduledoc false

  @default_port 5222
  @ssl_opts [reuse_sessions: true]
  @socket_opts [packet: :raw, mode: :binary, active: :once]

  @type state :: Romeo.Connection.t

  alias Romeo.JID
  alias Romeo.Auth
  alias Romeo.Stanza
  alias Romeo.Connection.Features
  alias Romeo.Connection, as: Conn

  require Logger

  import Kernel, except: [send: 2]

  @spec connect(Keyword.t) :: {:ok, state} | {:error, any}
  def connect(%Conn{host: host, port: port, socket_opts: socket_opts} = conn) do
    host = (host || default_host(conn.jid)) |> to_char_list
    port = (port || @default_port)

    conn = %{conn | host: host, port: port, socket_opts: socket_opts}

    case :gen_tcp.connect(host, port, socket_opts ++ @socket_opts, conn.timeout) do
      {:ok, socket} ->
        Logger.info fn -> "Connected to server" end
        {:ok, parser} = :exml_stream.new_parser
        start_protocol(%{conn | parser: parser, socket: {:gen_tcp, socket}})
      {:error, _} = error ->
        error
    end
  end

  def disconnect(info, {mod, socket}) do
    :ok = mod.close(socket)
    case info do
      {:close, from} ->
        Connection.reply(from, :ok)
      {:error, :closed} ->
        :error_logger.format("Connection closed~n", [])
      {:error, reason} ->
        reason = :inet.format_error(reason)
        :error_logger.format("Connection error: ~s~n", [reason])
    end
  end

  defp start_protocol(%Conn{} = conn) do
    conn
    |> start_stream
    |> negotiate_features
    |> start_tls
    |> authenticate
    |> bind
    |> session
    |> send_presence
    |> join_rooms
    |> done
  end

  defp start_stream(%Conn{jid: jid} = conn) do
    stanza = JID.parse(jid).server |> Stanza.start_stream()
    conn
    |> send(stanza)
    |> recv(fn conn, _packet ->
      conn
    end)
  end

  defp negotiate_features(conn) do
    recv(conn, fn conn, packet ->
      %Conn{conn | features: Features.parse_stream_features(packet)}
    end)
  end

  defp start_tls(%Conn{features: %Features{tls?: true}} = conn) do
    conn
    |> send(Stanza.start_tls)
    |> recv(fn conn, _packet ->
      conn
    end)
    |> upgrade_to_tls
    |> start_stream
    |> negotiate_features
  end
  defp start_tls(conn), do: conn

  defp upgrade_to_tls(%Conn{socket: {:gen_tcp, socket}} = conn) do
    Logger.info fn -> "Upgrading connection to TLS" end
    {:ok, socket} = :ssl.connect(socket, conn.ssl_opts ++ @ssl_opts)
    {:ok, parser} = :exml_stream.new_parser
    Logger.info fn -> "Connection secured" end
    %Conn{conn | socket: {:ssl, socket}, parser: parser}
  end

  defp authenticate(conn) do
    conn
    |> Auth.authenticate!
    |> reset_parser
    |> start_stream
  end

  defp bind(%Conn{resource: resource} = conn) do
    conn
    |> send(Stanza.bind(resource))
    |> recv(fn conn, _packet ->
      conn
    end)
  end

  defp session(%Conn{} = conn) do
    conn
    |> send(Stanza.session)
    |> recv(fn conn, _packet ->
      conn
    end)
  end

  defp send_presence(%Conn{jid: jid} = conn) do
    conn
    |> send(Stanza.presence)
    |> recv(fn conn, _packet ->
      Logger.info fn -> "#{jid} successfully connected." end
      conn
    end)
  end

  defp join_rooms(%Conn{rooms: rooms, nickname: nickname} = conn) do
    for room <- rooms do
      send(conn, Stanza.join(room, nickname))
    end
    conn
  end

  defp done(conn) do
    {:ok, conn}
  end

  defp reset_parser(%Conn{parser: parser} = conn) do
    {:ok, parser} = :exml_stream.reset_parser(parser)
    %{conn | parser: parser}
  end

  defp parse_stanza(%Conn{parser: parser} = conn, stanza) do
    Logger.debug fn -> "IN > #{inspect stanza}" end
    {:ok, parser, [stanza|_]} = :exml_stream.parse(parser, stanza)
    {:ok, %Conn{conn | parser: parser}, stanza}
  end

  def send(%Conn{socket: {mod, socket}} = conn, stanza) do
    stanza = Stanza.to_xml(stanza)
    Logger.debug fn -> "OUT > #{inspect stanza}" end
    :ok = mod.send(socket, stanza)
    {:ok, conn}
  end

  def recv({:ok, conn}, fun), do: recv(conn, fun)
  def recv(%Conn{socket: {:gen_tcp, socket}, timeout: timeout} = conn, fun) do
    receive do
      {:tcp, ^socket, stanza} ->
        :inet.setopts(socket, active: :once)
        {:ok, conn, stanzas} = parse_stanza(conn, stanza)
        fun.(conn, stanzas)
      {:tcp_closed, ^socket} ->
        {:error, :closed}
      {:tcp_error, ^socket, reason} ->
        {:error, reason}
    after timeout ->
      _ = Kernel.send(self, {:error, :timeout})
      conn
    end
  end
  def recv(%Conn{socket: {:ssl, socket}, timeout: timeout} = conn, fun) do
    receive do
      {:ssl, ^socket, stanza} ->
        :ssl.setopts(socket, active: :once)
        {:ok, conn, stanzas} = parse_stanza(conn, stanza)
        fun.(conn, stanzas)
      {:ssl_closed, ^socket} ->
        {:error, :closed}
      {:ssl_error, ^socket, reason} ->
        {:error, reason}
    after timeout ->
      _ = Kernel.send(self, {:error, :timeout})
      conn
    end
  end

  def handle_message({:tcp, socket, data}, %{socket: {:gen_tcp, socket}} = conn) do
    {:ok, _, _} = handle_data(data, conn)
  end
  def handle_message({:tcp_closed, socket}, %{socket: {:gen_tcp, socket}}) do
    {:error, :closed}
  end
  def handle_message({:tcp_error, socket, reason}, %{socket: {:gen_tcp, socket}}) do
    {:error, reason}
  end
  def handle_message({:ssl, socket, data}, %{socket: {:ssl, socket}} = conn) do
    {:ok, _, _} = handle_data(data, conn)
  end
  def handle_message({:ssl_closed, socket}, %{socket: {:ssl, socket}}) do
    {:error, :closed}
  end
  def handle_message({:ssl_error, socket, reason}, %{socket: {:ssl, socket}}) do
    {:error, reason}
  end
  def handle_message(_, _), do: :unknown

  defp handle_data(msg, %{socket: socket} = conn) do
    :ok = activate(socket)
    {:ok, _conn, _stanza} = parse_stanza(conn, msg)
  end

  defp activate({:gen_tcp, socket}) do
    case :inet.setopts(socket, [active: :once]) do
      :ok ->
        :ok
      {:error, :closed} ->
        _ = Kernel.send(self, {:tcp_closed, socket})
        :ok
      {:error, reason} ->
        _ = Kernel.send(self, {:tcp_error, socket, reason})
        :ok
    end
  end
  defp activate({:ssl, socket}) do
    case :ssl.setopts(socket, [active: :once]) do
      :ok ->
        :ok
      {:error, :closed} ->
        _ = Kernel.send(self, {:ssl_closed, socket})
        :ok
      {:error, reason} ->
        _ = Kernel.send(self, {:ssl_error, socket, reason})
        :ok
    end
  end

  defp default_host(jid) do
    JID.parse(jid).server
  end
end
