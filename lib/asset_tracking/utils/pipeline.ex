defmodule AssetTracking.Utils.Pipeline do
  @moduledoc """
    This module contains utilities for pipelines
  """

  @doc """
  Validates an input according to its schema using the external dependency Tarams
  """
  @spec validate_input(map(), map()) :: {:ok, map()} | {:error, map()}
  def validate_input(input, input_schema), do: Tarams.cast(input, input_schema)

  @doc """
  Validates if a Decimal is positive
  """
  @spec must_be_positive(%Decimal{}) :: :ok | {:error, String.t()}
  def must_be_positive(decimal) do
    decimal
    |> Decimal.positive?()
    |> if(do: :ok, else: {:error, "must be positive"})
  end

  @doc """
    Custom implementation of reducing algorithm using recursion and tail-call optimization instead of just using `Enum.reduce/3`
  """
  @spec reduce(list(any()), any(), function()) :: any()

  def reduce([], acc, _fun), do: acc

  def reduce([head | tail], acc, fun) do
    new_acc = fun.(head, acc)
    reduce(tail, new_acc, fun)
  end
end
