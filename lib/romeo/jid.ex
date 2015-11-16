defmodule Romeo.JID do
  @moduledoc """
  Jabber Identifiers (JIDs) uniquely identify individual entities in an XMPP
  network.

  A JID often resembles an email address with a user@host form, but there's
  a bit more to it. JIDs consist of three main parts:

  A JID can be composed of a local part, a server part, and a resource part.
  The server part is mandatory for all JIDs, and can even stand alone
  (e.g., as the address for a server).

  The combination of a local (user) part and a server is called a "bare JID",
  and it is used to identitfy a particular account on a server.

  A JID that includes a resource is called a "full JID", and it is used to
  identify a particular client connection (i.e., a specific connection for the
  associated "bare JID" account).
  """

  alias Romeo.JID

  @type t :: %__MODULE__{}
  defstruct user: "", server: "", resource: ""


  @doc """
  Returns a string representation from a JID struct.

  ## Examples
      iex> to_string(%Romeo.JID{user: "romeo", server: "montague.lit", resource: "chamber"})
      "romeo@montague.lit/chamber"

      iex> to_string(%Romeo.JID{user: "romeo", server: "montague.lit"})
      "romeo@montague.lit"

      iex> to_string(%Romeo.JID{server: "montague.lit"})
      "montague.lit"
  """
  defimpl String.Chars, for: JID do
    def to_string(%JID{user: "", server: server, resource: ""}), do: server
    def to_string(%JID{user: user, server: server, resource: ""}) do
      user <> "@" <> server
    end
    def to_string(%JID{user: user, server: server, resource: resource}) do
      user <> "@" <> server <> "/" <> resource
    end
  end

  @doc """
  Returns a binary JID without a resource.

  ## Examples
      iex> Romeo.JID.bare(%Romeo.JID{user: "romeo", server: "montague.lit", resource: "chamber"})
      "romeo@montague.lit"

      iex> Romeo.JID.bare("romeo@montague.lit/chamber")
      "romeo@montague.lit"
  """
  @spec bare(jid :: binary | JID.t) :: binary
  def bare(jid) when is_binary(jid), do: parse(jid) |> bare
  def bare(%JID{} = jid), do: to_string(%JID{jid | resource: ""})


  @doc """
  Parses a binary string JID into a JID struct.

  ## Examples
      iex> Romeo.JID.parse("romeo@montague.lit/chamber")
      %Romeo.JID{user: "romeo", server: "montague.lit", resource: "chamber"}

      iex> Romeo.JID.parse("romeo@montague.lit")
      %Romeo.JID{user: "romeo", server: "montague.lit", resource: ""}
  """
  @spec parse(jid :: binary) :: JID.t
  def parse(string) do
    case String.split(string, ["@", "/"], parts: 3) do
      [user, server, resource] ->
        %JID{user: user, server: server, resource: resource}
      [user, server] ->
        %JID{user: user, server: server}
      [server] ->
        %JID{server: server}
    end
  end
end
