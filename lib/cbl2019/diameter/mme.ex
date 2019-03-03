defmodule Cbl2019.Diameter.Mme do
  use GenServer
  require Logger
  require Record
  require Cbl2019.Configuration.Store
  require Cbl2019.Diameter.DiameterRecords
  require Cbl2019.Diameter.S13Records
  require Cbl2019.Provision.ImsiStore

  alias Cbl2019.Configuration.Store
  # alias Cbl2019.Diameter.Mme
  alias Cbl2019.Diameter.DiameterRecords
  alias Cbl2019.Diameter.S13Records

  @name __MODULE__

  def start_link(_args) do
    Logger.debug "Starting Mme Module"
    GenServer.start_link(__MODULE__, %{}, name: @name)
  end

  def init(_) do
    Logger.debug "Init Mme"
    :diameter.subscribe(@name)
    :diameter.stop_service(@name)
    :ok = :diameter.start_service(@name, service())
    {:ok, refs} = apply_transport(@name, transports())
    state = %{transports: refs}
    {:ok, state}
  end

  def handle_call(_request, _from, state) do
    reply = :ok
    {:reply, reply, state}
  end

  def handle_cast(:test, state) do
    Logger.debug "(MME) (cast) Sending test message"
    msg = ecr("001010010100101", "012345678901231")
    case :diameter.call(@name, :s13, msg) do
      {:error, reason} ->
        Logger.error "Error sending message: #{inspect reason}"
      {:ok, answer} ->
        Logger.debug fn -> "Got answer :)" end
    end
    {:noreply, state}
  end

  def handle_cast(:test_unknown, state) do
    Logger.debug "(MME) (cast) Sending test message (unknown imsi/imei)"
    msg = ecr("999999999999999", "999999999999999")
    case :diameter.call(@name, :s13, msg) do
      {:error, reason} ->
        Logger.error "Error sending message: #{inspect reason}"
      {:ok, answer} ->
        Logger.debug fn -> "Got answer :)" end
    end
    {:noreply, state}
  end

  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  def handle_info(DiameterRecords.diameter_event() = evt, state) do
    Logger.debug fn -> "(Mme) Diameter evt #{inspect evt}" end
    {:noreply, state}
  end

  def handle_info(:test, state) do
    Logger.debug "(MME) Sending test message"
    msg = ecr("001010010100101", "012345678901231")
    case :diameter.call(@name, :s13, msg) do
      {:error, reason} ->
        Logger.error "Error sending message: #{inspect reason}"
    end
    {:noreply, state}
  end

  def handle_info(_info, state) do
    {:noreply, state}
  end

  def terminate(_reason, _state), do:
    :diameter.stop_service(@name)

  def code_change(_oldVsn, state, _extra), do:
    {:ok, state}

  # Diameter Callbacks
  def peer_up(_svcName, _peer, state), do:
    state

  def peer_down(_svcName, _peer, state), do:
    state

  def pick_peer(localCandidates, _remoteCandidates, _svcName, _state) do
    [peer | _] = localCandidates
    {:ok, peer}
  end

  def prepare_request(DiameterRecords.diameter_packet(msg: req), _svcName, {_peerRef, peerCaps}) do
    # capabilities() = #diameter_caps{}
    # A record containing the identities of the local Diameter node and
    # the remote Diameter peer having an established transport connection,
    # as well as the capabilities as determined by capabilities exchange.
    # Each field of the record is a 2-tuple consisting of values for the
    # (local) host and (remote) peer. Optional or possibly multiple values
    # are encoded as lists of values, mandatory values as the bare value.

    DiameterRecords.diameter_caps(
        origin_host: {ohost, dhost},
        origin_realm: {orealm, drealm}) = peerCaps
    Logger.debug fn -> "Sending (1): #{inspect req}" end
    rreq = case req do
      # Let's pattern match on the request Record type
      # https://hexdocs.pm/elixir/Record.html
      S13Records.ts29272_s13_ECR() ->
        Logger.debug fn -> "ECR" end
        session_id = :diameter.session_id(ohost)
        Logger.debug fn -> "Prepare request Session-Id: #{inspect session_id}" end
        S13Records.ts29272_s13_ECR(req,
          'Session-Id': session_id,
          'Origin-Host': ohost,
          'Origin-Realm': orealm,
          'Destination-Realm': drealm,
          'Destination-Host': dhost,
          # 'Supported-Features': [avp_supported_feature()],
          # 'Vendor-Specific-Application-Id': [s13_vsaid()],
          'Auth-Session-State': DiameterRecords.diameter_base_auth_session_state_no_state_maintained
        )
      _ -> Logger.error "Unhandled req type"
    end
    Logger.debug "Complete: #{inspect rreq}"
    {:send, rreq}
  end

  def prepare_request(packet, _svcName, _peer) do
    Logger.info "Sending (2): #{inspect packet}"
    {:send, packet}
  end

  def handle_request(packet, svcName, peer) do
    Logger.info "(MME) got request: #{inspect packet}"
    action = case msgname(packet) do
        'ECA' -> s13_handle_eca(packet, svcName, peer)
    end
    action
  end

  def handle_answer(DiameterRecords.diameter_packet(msg: msg) = packet, request, svcName, peer) do
    # Invoked when an answer message is received from a peer. The return value
    # is returned from diameter:call/4 unless the detach option was specified.
    # The decoded answer record and undecoded binary are in the msg and bin
    # fields of the argument packet() respectively. Request is the outgoing
    # request message as was returned from prepare_request/3 or prepare_retransmit/3.
    # For any given call to diameter:call/4 there is at most one handle_answer/4
    # callback: any duplicate answer (due to retransmission or otherwise) is discarded.
    # Similarly, only one of handle_answer/4 or handle_error/4 is called.
    Logger.info "handle_answer"
    Logger.info "msg: #{inspect msg}"

    action = case msgname(packet) do
    :'ECA' -> s13_handle_eca(msg, svcName, peer)
      _ -> {:error, :unknown}
    end

    action
  end

  # Privates
  defp s13_handle_eca(msg, svcName, peer) do
    Logger.info fn -> "s13_handle_eca" end

    [rc] = S13Records.ts29272_s13_ECA(msg, :'Result-Code')

    case rc do
      DiameterRecords.diameter_base_result_code_success ->
        Logger.info fn -> "Got success RC #{inspect rc}!" end
      _ ->
        Logger.info fn -> "Got failure RC #{inspect rc}!" end
    end
    

    {:ok, msg}
  end

  defp ecr(imsi, imei) do
    S13Records.ts29272_s13_ECR(
      'Terminal-Information': terminal_information(imei),
      'User-Name': imsi
    )
  end

  defp terminal_information(imei) do
    S13Records.'ts29272_s13_Terminal-Information'(IMEI: imei)
    # S13Records.'3gpp_Terminal-Information'('IMEI': imei)
  end

  defp vendor_id(:etsi) do
    13019
  end

  defp vendor_id(:'3gpp') do
    10415
  end

  defp service() do
    mme = Application.get_application(__MODULE__)

    originhost = Application.get_env(mme, :origin_host, 'mme.mnc001mcc001.3gppnetworks.org')
    originrealm = Application.get_env(mme, :origin_realm, 'mnc001mcc001.3gppnetworks.org')

    [{:string_decode, false},
     {:'Origin-Host', originhost},
     {:'Origin-Realm', originrealm},
     {:'Origin-State-Id', :diameter.origin_state_id()},
     {:'Host-IP-Address', [{127, 0, 0, 131}]},
     {:'Vendor-Id', vendor_id(:'3gpp')},
     {:'Product-Name', "Mme"},
     {:'Vendor-Specific-Application-Id', [vendor_spec_app_id(:auth, :ts29272_s13.vendor_id, [:ts29272_s13.id])]},
     {:'Supported-Vendor-Id', [vendor_id(:'3gpp'), vendor_id(:etsi)]},
     {:application, s13_application()}]
  end

  def vendor_spec_app_id(:auth, vendor, ids) do
    DiameterRecords.'diameter_base_Vendor-Specific-Application-Id'('Vendor-Id': vendor, 'Auth-Application-Id': ids)
  end
  def vendor_spec_app_id(:acct, vendor, ids) do
    DiameterRecords.'diameter_base_Vendor-Specific-Application-Id'('Vendor-Id': vendor, 'Acct-Application-Id': ids)
  end

  defp s13_application do
    [{:dictionary, :ts29272_s13},
     {:alias, :s13},
     {:module, @name}]
  end

  defp apply_transport(service, tlist) do
    Logger.debug "Applying transport (1)"
    Logger.debug "Transports: #{inspect tlist}"
    apply_transport(service, tlist, [])
  end

  defp apply_transport(service, [transport | tail], acc) do
    Logger.debug "Applying transport (2)"
    Logger.debug "Transport: #{inspect service}"
    {:ok, ref} = :diameter.add_transport(service, transport)
    apply_transport(service, tail, [ref | acc])
  end

  defp apply_transport(_service, [], acc) do
    {:ok, acc}
  end

  defp transports() do
    # transports = Store.get(:test_peers)
    transports = [
        {:connect,
        [{:capabilities, [
            {:'Origin-Host', "mme-test.epc.mnc001mcc001.3gppnetworks.org"},
            {:'Origin-Realm', "epc.mnc001mcc001.3gppnetworks.org"}]},
            {:transport_module, :diameter_tcp},
            {:transport_config, [
            {:ip, {127, 0, 0, 128}},
            {:port, 3868},
            {:raddr, {127, 0, 0, 118}},
            {:rport, 3868},
            ]}]
        },
        {:connect,
        [{:capabilities, [
            {:'Origin-Host', "mme-test.epc.mnc001mcc001.3gppnetworks.org"},
            {:'Origin-Realm', "epc.mnc001mcc001.3gppnetworks.org"}]},
            {:transport_module, :diameter_sctp},
            {:transport_config, [
            {:ip, {127, 0, 0, 129}},
            {:port, 3869},
            {:raddr, {127, 0, 0, 119}},
            {:rport, 3869},
            ]}]
        }]
    Logger.debug "Got transports: #{inspect transports}"
    transports
  end

  # Duplicated from dia.ex
  defp msgname(packet) do
    DiameterRecords.diameter_packet(header: diameter_header) = packet
    DiameterRecords.diameter_header(cmd_code: cmd_code) = diameter_header
    DiameterRecords.diameter_header(is_request: is_request) = diameter_header
    :ts29272_s13.msg_name(cmd_code, is_request)
  end

  # Message handlers
  defp s13_handle_eca(_packet, _svcName, _peer) do
    Logger.debug "Called s13_handle_eca"
    {:noreply, %{}}
  end
end