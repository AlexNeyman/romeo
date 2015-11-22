defmodule Romeo.Auth do
  @moduledoc """
  Handles XMPP authentication mechanisms.
  """

  use Romeo.XML
  require Logger

  defmodule Error do
    defexception [:message]

    def exception(mechanism) do
      msg = "Failed to authenticate using mechanism: #{inspect mechanism}"
      %Romeo.Auth.Error{message: msg}
    end
  end

  @doc """
  Authenticates the client using the configured preferred mechanism.

  If the preferred mechanism is not supported it will choose PLAIN.
  """
  def authenticate!(conn) do
    preferred  = conn.preferred_auth_mechanisms
    mechanisms = conn.features.mechanisms
    preferred_mechanism(preferred, mechanisms) |> do_authenticate(conn)
  end

  defp do_authenticate(mechanism, conn) do
    Logger.info fn -> "Authenticating with #{mechanism}" end
    authenticate_with(mechanism, conn)
    case success?(conn) do
      {:ok, conn} -> conn
      {:error, _conn} -> raise Romeo.Auth.Error, mechanism
    end
  end

  defp authenticate_with("PLAIN", %{transport: mod} = conn) do
    [username, password] = get_client_credentials(conn)
    payload = <<0>> <> username <> <<0>> <> password
    mod.send(conn, Romeo.Stanza.auth("PLAIN", Romeo.Stanza.base64_cdata(payload)))
  end

  defp authenticate_with("DIGEST-MD5", _conn) do
    raise "Not implemented"
  end

  defp authenticate_with("SCRAM-SHA-1", _conn) do
    raise "Not implemented"
  end

  defp authenticate_with("ANONYMOUS", %{transport: mod} = conn) do
    conn |> mod.send(Romeo.Stanza.auth("ANONYMOUS"))
  end

  defp authenticate_with("EXTERNAL", _conn) do
    raise "Not implemented"
  end

  defp success?(%{transport: mod} = conn) do
    mod.recv(conn, fn conn, [xmlel(name: name) | []] ->
      case name do
        "success" ->
          Logger.info fn -> "Authenticated successfully" end
          {:ok, conn}
        "failure" ->
          {:error, conn}
      end
    end)
  end

  defp get_client_credentials(%{jid: jid, password: password}) do
    [Romeo.JID.parse(jid).user, password]
  end

  defp preferred_mechanism([], _), do: "PLAIN"
  defp preferred_mechanism([h|t], mechanisms) do
    case Enum.member?(mechanisms, h) do
      true  -> h
      false -> preferred_mechanism(t, mechanisms)
    end
  end
end
