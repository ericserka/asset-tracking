defmodule AssetTracking.Utils.PipelineTest do
  use ExUnit.Case, async: true

  alias AssetTracking.Utils.Pipeline, as: PipelineUtils

  @input_schema %{
    string_key: [type: :string, required: true],
    decimal_key: [type: :decimal, required: true]
  }

  describe "validate_input/2" do
    test "should return {:ok, validated_input} if input conforms to the specification of input_schema" do
      assert {:ok, %{decimal_key: decimal_value}} =
               PipelineUtils.validate_input(
                 %{string_key: "string_value", decimal_key: 0.1},
                 @input_schema
               )

      assert decimal_value == Decimal.new("0.1")
    end

    test "should return {:error, errors} if input does not conforms to the specification of input_schema" do
      assert {:error, %{decimal_key: ["is required"]}} =
               PipelineUtils.validate_input(
                 %{string_key: "string_value", decimal_key: nil},
                 @input_schema
               )
    end
  end

  describe "must_be_positive/1" do
    test "should return :ok if decimal is positive" do
      Decimal.new("1.1") |> PipelineUtils.must_be_positive() |> Kernel.==(:ok) |> assert()
    end

    test "should return {:error, 'must be positive'} if decimal is not positive" do
      Decimal.new("-1.1")
      |> PipelineUtils.must_be_positive()
      |> Kernel.==({:error, "must be positive"})
      |> assert()
    end
  end
end
