defmodule Cbl2019.Diameter.Dia do
  @moduledoc """
  This is the module that defines how the application
  will manage incoming Diameter requests.

  It loads records from the generic Diameter application,
  and from the proxy module for the s13 interface
  """
  use GenServer
  
  require Logger
  require Cbl2019.Configuration.Store
  require Cbl2019.Diameter.DiameterRecords
  require Cbl2019.Diameter.S13Records
  require Cbl2019.Provision.ImsiStatus
  require Cbl2019.Provision.ImsiStore
  
  alias Cbl2019.Configuration.Store
  alias Cbl2019.Diameter.Dia
  alias Cbl2019.Diameter.DiameterRecords
  alias Cbl2019.Diameter.S13Records
  alias Cbl2019.Provision.ImsiStatus
  alias Cbl2019.Provision.ImsiStore
  
  @name __MODULE__
  
  # Nothing really useful, just to put something in the state
  defstruct transports: []
  
  def start_link([%{idx: _idx, name: _name, pname: pname} = state]) do
    Logger.debug "Starting Dia Module"

    #GenServer.start_link(@name, state, name: nil)
    GenServer.start_link(__MODULE__, state, [name: pname])
  end
  
  def init(%{idx: idx, name: name}) do
    Logger.debug "Init Dia Module"
    setname(name)

    # http://erlang.org/doc/man/diameter.html#subscribe-1
    # It is not an error to subscribe to events from a service that does not
    # yet exist. Doing so before adding transports is required to guarantee
    # the reception of all transport-related events.
    :diameter.subscribe(name)
    :diameter.stop_service(name)

    {:ok, trans} = Store.get(:diameter_transports) |> Enum.fetch(idx)
    {:ok, servs} = Store.get(:diameter_services) |> Enum.fetch(idx)

    :ok = :diameter.start_service(name, service(servs, idx))
    {:ok, refs} = apply_transport(name, transports(trans))
    Logger.debug "Transport initialized: #{inspect refs}"

    state = %Dia{transports: refs}
    {:ok, state}
  end
  
  def handle_call(_request, _from, state) do
    Logger.debug "handle_call"
    reply = :ok
    {:reply, reply, state}
  end
  
  def handle_cast(_msg, state) do
    Logger.debug "handle_cast"
    {:noreply, state}
  end
  
  def handle_info(_info, state) do
    # Logger.debug "handle_info info #{inspect info}"
    # Logger.debug "handle_info state #{inspect state}"
    {:noreply, state}
  end
  
  def terminate(_reason, _state) do
    :diameter.stop_service(getname())
  end
  
  def code_change(_oldVsn, state, _extra), do:
    {:ok, state}
  
  
  # Diameter Callbacks
  @doc """
  http://erlang.org/doc/man/diameter_app.html#Mod:peer_up-3

  Note 1
  There is no requirement that a callback return before incoming
  requests are received

  Note 2
  A watchdog state machine can reach state OKAY from state
  SUSPECT without a new capabilities exchange taking place.
  A new transport connection (and capabilities exchange)
  results in a new peer_ref().
  """
  def peer_up(svcName, peer, state) do
    Logger.debug "Peer up #{inspect svcName} #{inspect peer}"
    state
  end
  
  @doc """
  http://erlang.org/doc/man/diameter_app.html#Mod:peer_down-3
  """
  def peer_down(svcName, peer, state) do
      Logger.debug "Peer down #{inspect svcName} #{inspect peer}"
      state
  end
  
  @doc """
  http://erlang.org/doc/man/diameter_app.html#Mod:pick_peer-4

  Invoked as a consequence of a call to diameter:call/4 to select
  a destination peer for an outgoing request. The return value
  indicates the selected peer.
  The candidate lists contain only those peers that have advertised
  support for the Diameter application in question during
  capabilities exchange, that have not be excluded by a filter
  option in the call to diameter:call/4 and whose watchdog state
  machine is in the OKAY state.
  """
  def pick_peer(localCandidates, _remoteCandidates, _svcName, _state) do
    Logger.debug fn -> "pick_peer" end
    [peer | _] = localCandidates
    Logger.debug fn -> "Picked peer: #{inspect peer}" end
    {:ok, peer}
  end
  
  @doc """
  http://erlang.org/doc/man/diameter_app.html#Mod:handle_request-3

  Invoked when a request message is received from a peer. The application
  in which the callback takes place (that is, the callback module as
  configured with diameter:start_service/2) is determined by the Application
  Identifier in the header of the incoming request message, the selected
  module being the one whose corresponding dictionary declares itself as
  defining either the application in question or the Relay application.
  """
  def handle_request(packet, svcName, peer) do
    # #diameter_packet{header = #diameter_header{},
    #     avps   = [#diameter_avp{}],
    #     msg    = record() | undefined,
    #     errors = [Unsigned32() | {Unsigned32(), #diameter_avp{}}],
    #     bin    = binary(),
    #     transport_data = term()}
    Logger.info "Arrived Diameter #{msgname(packet)} message"
    action = case msgname(packet) do
        :'ECR' -> s13_handle_ecr(packet, svcName, peer)
    end
    Logger.info "Gonna send #{inspect action}"
    action
  end
  
  # Privates
  defp getname do
    # hack to avoid passing state in all functions
    name = :erlang.get(:svcname)
    name
  end
  
  defp setname(name) do
    # hack to avoid passing state in all functions
    :erlang.put(:svcname, name)
  end

  defp vendor_id(:etsi) do
    # Just an example of another vendor id
    13019
  end

  defp vendor_id(:'3gpp') do
    # could have used :'3gpp'.vendor_id here
    10415
  end

  defp service(servs, idx) do
    originhost = servs |> Map.get(:host)
    originrealm = servs |> Map.get(:realm)
    Logger.debug "host #{originhost} realm #{originrealm}"

    [{:string_decode, false},
    {:'Origin-Host', originhost},
    {:'Origin-Realm', originrealm},
    {:'Origin-State-Id', :diameter.origin_state_id()},
    # should be the vendor id registered at IETF
    {:'Vendor-Id', vendor_id(:'3gpp')},
    {:'Product-Name', "EIR" <> Integer.to_string(idx)},
    {:'Vendor-Specific-Application-Id', 
        [vendor_spec_app_id(
            :auth, :ts29272_s13.vendor_id, [:ts29272_s13.id])]},
    {:'Supported-Vendor-Id', [vendor_id(:'3gpp'), vendor_id(:etsi)]},
    {:application, s13_application()}]
  end
  
  def vendor_spec_app_id(:auth, vendor, ids) do
    DiameterRecords.'diameter_base_Vendor-Specific-Application-Id'(
    'Vendor-Id': vendor,
    'Acct-Application-Id': [],
    'Auth-Application-Id': ids)
  end

  def vendor_spec_app_id(:acct, vendor, ids) do
    DiameterRecords.'diameter_base_Vendor-Specific-Application-Id'(
    'Vendor-Id': vendor,
    'Auth-Application-Id': [],
    'Acct-Application-Id': ids)
  end
  
  defp s13_application do
    [{:dictionary, :ts29272_s13},
      {:alias, :s13},
      {:module, @name}]
  end
  
  defp apply_transport(service, tlist) do
    Logger.debug "Applying transports for service: #{service}"
    apply_transport(service, tlist, [])
  end
  
  defp apply_transport(service, [transport | tail], acc) do
    Logger.debug "Transport: #{inspect transport}"
    {:ok, ref} = :diameter.add_transport(service, transport)
    apply_transport(service, tail, [ref | acc])
  end
  
  defp apply_transport(_service, [], acc) do
    {:ok, acc}
  end
  
  defp transports(trans) do
    # Logger.debug "Got transports: #{inspect trans}"
    trans
  end
  
  defp msgname(packet) do
    DiameterRecords.diameter_packet(header: diameter_header) = packet
    DiameterRecords.diameter_header(cmd_code: cmd_code) = diameter_header
    DiameterRecords.diameter_header(is_request: is_request) = diameter_header
    :ts29272_s13.msg_name(cmd_code, is_request)
  end

  defp get_eca_params(imsi_data) do
    case imsi_data do
      {:ok, data} ->
        {
          :ok,
          # DIAMETER_SUCCESS
          DiameterRecords.diameter_base_result_code_success,
          [],
          Map.get(data, :status) |> ImsiStatus.status_to_number
        }
      {:error, :not_found} ->
        {
          :ok,
          # DIAMETER_ERROR_EQUIPMENT_UNKNOWN
          DiameterRecords.diameter_base_error_equipment_unknown,
          [],
          []
        }
    end
  end
  
  defp experimental_result(value) do
    S13Records.'ts29272_s13_Experimental-Result'(
      'Vendor-Id': :ts29272_s13.vendor_id(),
      'Experimental-Result-Code': value
    )
  end
  
  # Message handlers
  # Real application logic goes here.

  # < ME-Identity-Check-Request > ::= < Diameter Header: 324, REQ, PXY, 16777252 >
  #   < Session-Id >
  #   [ DRMP ]
  #   [ Vendor-Specific-Application-Id ]
  #   { Auth-Session-State }
  #   { Origin-Host }
  #   { Origin-Realm }
  #   [ Destination-Host ]
  #   { Destination-Realm }
  #   { Terminal-Information }
  #   [ User-Name ]
  #   *[ AVP ]
  #   *[ Proxy-Info ]
  #   *[ Route-Record ]
  defp s13_handle_ecr(packet, svcName, _peer) do
    Logger.debug fn -> "s13_handle_ecr svcName #{inspect svcName}" end
    ecr = DiameterRecords.diameter_packet(packet, :msg)

    # Get the IMSI from AVP IMSI
    imsi =
      S13Records.ts29272_s13_ECR(ecr, :'User-Name')
      |> Enum.at(0)

    # Get IMEI from Grouped AVP Terminal-Information
    # Terminal-Information ::= <AVP header: 1401 10415>
    #     [ IMEI ]
    #     [ 3GPP2-MEID ]
    #     [ Software-Version ]
    #     *[ AVP ]
    terminal_information =
      S13Records.ts29272_s13_ECR(ecr, :'Terminal-Information')
    imei =
      S13Records.'ts29272_s13_Terminal-Information'(terminal_information, :'IMEI')
      |> Enum.at(0)

    # Blocking call, just not to overcomplicate things :)
    imsi_data = GenServer.call(ImsiStore, {:get, imsi, imei})
    {:ok, result, expResult, equipment_status} = get_eca_params(imsi_data)

    # Let's reuse service information
    ohost = :diameter.service_info(svcName, :'Origin-Host')
    orealm = :diameter.service_info(svcName, :'Origin-Realm')

    Logger.debug "ohost #{inspect ohost} orealm #{orealm}"

    # Let's build the real ECA
    # < ME-Identity-Check-Answer> ::= < Diameter Header: 324, PXY, 16777252 >
    #     < Session-Id >
    #     [ DRMP ]
    #     [ Vendor-Specific-Application-Id ]
    #     [ Result-Code ]
    #     [ Experimental-Result ]
    #     { Auth-Session-State }
    #     { Origin-Host }
    #     { Origin-Realm }
    #     [ Equipment-Status ]
    #     *[ AVP ]
    #     [ Failed-AVP ]
    #     *[ Proxy-Info ]
    #     *[ Route-Record ]
    eca = S13Records.ts29272_s13_ECA(
      'Origin-Host': ohost,
      'Origin-Realm': orealm,
      'Session-Id': S13Records.ts29272_s13_ECR(ecr, :'Session-Id'),
      'Auth-Session-State': S13Records.ts29272_s13_ECR(ecr, :'Auth-Session-State'),
      'Result-Code': result,
      'Experimental-Result': expResult,
      'Equipment-Status': equipment_status,
      # 'Supported-Features': [avp_supported_feature()],
      'Proxy-Info': S13Records.ts29272_s13_ECR(ecr, :'Proxy-Info'))
    Logger.debug "Msg: #{inspect eca}"
    {:reply, eca}
  end
end