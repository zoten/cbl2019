defmodule Cbl2019.Diameter.DiameterRecords do
  @moduledoc """
  https://hexdocs.pm/elixir/Record.html

  Binding module between Erlang and Elixir records
  "General" Diameter records
  """
  require Record  # we need to use minidiadict Erlang records
  import Record, only: [defrecord: 2, extract: 2]

  defrecord :diameter_packet, extract(
    :diameter_packet, from_lib: "diameter/include/diameter.hrl")
  defrecord :diameter_event, extract(
      :diameter_event, from_lib: "diameter/include/diameter.hrl")
  defrecord :diameter_header, extract(
    :diameter_header, from_lib: "diameter/include/diameter.hrl")
  defrecord :diameter_caps, extract(
    :diameter_caps, from_lib: "diameter/include/diameter.hrl")
  defrecord :'diameter_base_Vendor-Specific-Application-Id', extract(
    :'diameter_base_Vendor-Specific-Application-Id', from_lib: "diameter/include/diameter_gen_base_rfc6733.hrl")

  # Here is the only "real" problem: I didn't find a nice way to import
  # Erlang's macros in Elixir :(
  # A lot of compiled constants from .dia files to .hrl headers are defined as macro
  defmacro diameter_base_result_code_success do
    quote do: 2001
  end

  defmacro diameter_base_error_equipment_unknown do
    quote do: 5422
  end

  defmacro diameter_base_auth_session_state_no_state_maintained do
    quote do: 1
  end
end