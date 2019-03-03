defmodule Cbl2019.Misc.Time do
  @moduledoc """
  Mini-module with time functions
  """

  @doc """
  Return the current UTC timestamp
  """
  def now do
    :os.system_time(:millisecond)
  end
end
