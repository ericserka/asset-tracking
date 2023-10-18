defmodule AssetTracking.Pipelines.AssetTracker.AddPurchase do
  @moduledoc """
    Pipeline for adding a purchase to the AssetTracker.
  """

  use AssetTracking, :pipeline
  alias AssetTracking.Asset
  alias AssetTracking.AssetTracker
  alias AssetTracking.Purchase

  @doc """
    Pipeline function
  """
  @spec call(map()) :: %AssetTracker{inventory: map()} | {:error, map()}
  def call(input) do
    input_schema = %{
      asset_tracker: [type: %{inventory: [type: :map, required: true]}, required: true],
      asset_symbol: [type: :string, required: true],
      settle_date: [type: :date, required: true],
      quantity: [type: :decimal, required: true, func: &must_be_positive/1],
      unit_price: [type: :decimal, required: true, func: &must_be_positive/1]
    }

    Duct.Multi.new()
    |> Duct.Multi.run(:validated_input, fn _ -> validate_input(input, input_schema) end)
    |> Duct.Multi.run(:asset_data, &get_asset_data/1)
    |> Duct.Multi.run(:updated_asset_purchase_queue, &update_asset_purchase_queue/1)
    |> Duct.Multi.run(:updated_asset_tracker, &update_asset_tracker/1)
    |> Duct.run()
    |> output()
  end

  defp get_asset_data(%{
         validated_input: %{asset_tracker: asset_tracker, asset_symbol: asset_symbol}
       }),
       do: Map.get(asset_tracker.inventory, asset_symbol, Asset.new())

  defp update_asset_purchase_queue(%{
         asset_data: %Asset{purchases: purchases},
         validated_input: %{unit_price: unit_price, quantity: quantity, settle_date: settle_date}
       }) do
    Prioqueue.insert(purchases, %Purchase{
      unit_price: unit_price,
      quantity: quantity,
      settle_date: settle_date
    })
  end

  defp update_asset_tracker(%{
         validated_input: %{asset_tracker: asset_tracker, asset_symbol: asset_symbol},
         updated_asset_purchase_queue: updated_asset_purchase_queue,
         asset_data: %Asset{} = asset_data
       }) do
    new_asset_data = %Asset{asset_data | purchases: updated_asset_purchase_queue}
    new_inventory = Map.put(asset_tracker.inventory, asset_symbol, new_asset_data)
    %AssetTracker{inventory: new_inventory}
  end

  defp output({:error, _, reason, _input}), do: {:error, reason}

  defp output({:ok, %{updated_asset_tracker: updated_asset_tracker}}), do: updated_asset_tracker
end
