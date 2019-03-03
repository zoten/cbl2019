defmodule Cbl2019.Provision.ImsiStatus do
 
    def status_to_number(status) do
      case status do
        :whitelisted -> 0
        :blacklisted -> 1
        :greylisted -> 2
        _ -> :unknown
      end
    end
  end