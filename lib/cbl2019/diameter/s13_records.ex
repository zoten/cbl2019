defmodule Cbl2019.Diameter.S13Records do
  @moduledoc """
  https://hexdocs.pm/elixir/Record.html

  Binding module between Erlang and Elixir records
  "General" Diameter records
  """
  require Record  # we need to use minidiadict Erlang records
  import Record, only: [defrecord: 2, extract: 2]

  defrecord :'ts29272_s13_Experimental-Result', extract(
    :'ts29272_s13_Experimental-Result', from_lib: "minidiadict/include/ts29272_s13.hrl")
  defrecord :ts29272_s13_ECR, extract(
    :ts29272_s13_ECR, from_lib: "minidiadict/include/ts29272_s13.hrl")
  defrecord :ts29272_s13_ECA, extract(
    :ts29272_s13_ECA, from_lib: "minidiadict/include/ts29272_s13.hrl")
  defrecord :'ts29272_s13_Vendor-Specific-Application-Id', extract(
    :'ts29272_s13_Vendor-Specific-Application-Id', from_lib: "minidiadict/include/ts29272_s13.hrl")

  defrecord :'ts29272_s13_Terminal-Information', extract(
    :'ts29272_s13_Terminal-Information', from_lib: "minidiadict/include/ts29272_s13.hrl")
  # defrecord :'3gpp_Terminal-Information', extract(
  #   :'3gpp_Terminal-Information', from_lib: "minidiadict/include/3gpp.hrl")

  # Macros
  # Here is the only "real" problem: I didn't find a nice way to import
  # Erlang's macros in Elixir :(
  # A lot of compiled constants from .dia files to .hrl headers are defined as macro
  defmacro ts29272_s13_equipment_status_whitelisted do
    quote do: 0
  end
  defmacro ts29272_s13_equipment_status_blacklisted do
    quote do: 1
  end
  defmacro ts29272_s13_equipment_status_greylisted do
    quote do: 2
  end

end