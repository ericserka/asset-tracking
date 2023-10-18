defmodule AssetTracking do
  @moduledoc """
  This project aims to track assets and calculate capital gains or losses
  """

  def pipeline do
    quote do
      import AssetTracking.Utils.Pipeline
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
