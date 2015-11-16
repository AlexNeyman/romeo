defmodule Romeo.Stanza.Presence do
  use Romeo.XML

  @type jid :: Romeo.JID.t

  @type t :: %__MODULE__{
    id: binary,
    to: jid,
    from: jid,
    type: binary,
    show: binary | nil,
    status: binary | nil,
    payload: list,
    client: pid,
    matches: list | %{} | nil
  }

  defstruct [
    id: nil,
    to: nil,
    from: nil,
    type: nil,
    show: nil,
    status: nil,
    payload: [],
    client: nil,
    matches: nil
  ]
end
