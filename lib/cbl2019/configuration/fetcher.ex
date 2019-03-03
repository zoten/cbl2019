defmodule Cbl2019.Configuration.Fetcher do
    @name __MODULE__
    require Logger
    use GenServer
    alias Cbl2019.Configuration.Store

    def start_link (_args) do
      GenServer.start_link(__MODULE__, %{}, name: @name)
    end

    # GenServer callbacks

    # init the server sending a :start order
    def init(state) do
      GenServer.cast(@name, :start)
      {:ok, state}
    end

    def handle_cast(:start, state) do
      Logger.debug fn -> "Init configuration fetcher" end
      Logger.debug fn -> "(Yep, it is hardcoded for the sake of readability)" end

      # diameter configurations is a list of tuples, every
      # spawned tas will take an index
      Store.put(:diameter_services, [
          # host, realm
          %{
              host: "eir.epc.mnc001.mcc001.3gppnetwork.org",
              realm: "epc.mnc001.mcc001.3gppnetwork.org"
            },
      ])
      Store.put(:diameter_transports, [
          # id 0
          [
            # TCP connect/listener
            # We don't really need a connector here, since we never act as a
            # server, but let's use this as example
            {:connect,
                [
                    {:capabilities, [
                        {:'Origin-Host', "eir.epc.mnc001.mcc001.3gppnetwork.org"},
                        {:'Origin-Realm', "epc.mnc001.mcc001.3gppnetwork.org"},
                    ]},
                    {:transport_module, :diameter_tcp},
                    {:transport_config, [
                        {:ip, {127, 0, 0, 118}},
                        {:port, 3868},
                        {:raddr, {127, 0, 0, 128}},  # MME IP (TCP)
                        {:rport, 3868},
                        {:reuseaddr, true},
                    ]}
                ]
            },
            {:listen,
                [
                    {:capabilities, [
                        {:'Origin-Host', "eir.epc.mnc001.mcc001.3gppnetwork.org"},
                        {:'Origin-Realm', "epc.mnc001.mcc001.3gppnetwork.org"}
                    ]},
                    {:transport_module, :diameter_tcp},
                    {:transport_config, [
                        {:ip, {127, 0, 0, 118}},
                        {:port, 3868},
                        {:reuseaddr, true},
                    ]}
                ]
            },
            # SCTP connect/listener
            {:connect,
                [
                    {:capabilities, [
                        {:'Origin-Host', "eir.epc.mnc001.mcc001.3gppnetwork.org"},
                        {:'Origin-Realm', "epc.mnc001.mcc001.3gppnetwork.org"},
                    ]},
                    {:transport_module, :diameter_sctp},
                    {:transport_config, [
                        {:ip, {127, 0, 0, 119}},
                        {:port, 3869},
                        {:raddr, {127, 0, 0, 129}},  # MME IP (TCP)
                        {:rport, 3869},
                        {:reuseaddr, true},
                    ]}
                ]
            },
            {:listen,
                [
                    {:capabilities, [
                        {:'Origin-Host', "eir.epc.mnc001.mcc001.3gppnetwork.org"},
                        {:'Origin-Realm', "epc.mnc001.mcc001.3gppnetwork.org"}
                    ]},
                    {:transport_module, :diameter_sctp},
                    {:transport_config, [
                        {:ip, {127, 0, 0, 119}},
                        {:port, 3869},
                        {:reuseaddr, true},
                    ]}
                ]
            },
          ],
        ])
      # GenServer.cast(@name, :readfile)
      {:noreply, state}
    end

    # def handle_cast(:readfile, state) do
    #   Logger.debug fn -> "Fetching data" end
    #   {:noreply, state}
    # end

  end