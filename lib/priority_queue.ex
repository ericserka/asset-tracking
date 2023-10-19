defmodule PriorityQueue do
  defstruct ~w(mapper sorter queue)a

  @doc """
    Creates a empty PriorityQueue with a mapper and sorter defined.
  """
  @spec new(function(), module() | {:asc | :desc, module()}) :: %__MODULE__{}
  def new(mapper, sorter), do: %__MODULE__{mapper: mapper, sorter: sorter, queue: []}

  @doc """
    Inserts an item at the end of the PriorityQueue.
  """
  @spec push_in(%__MODULE__{}, any()) :: %__MODULE__{}
  def push_in(%__MODULE__{mapper: mapper, sorter: sorter, queue: queue} = pq, item) do
    new_queue = queue |> Kernel.++([item]) |> Enum.sort_by(mapper, sorter)

    %__MODULE__{pq | queue: new_queue}
  end

  @doc """
    Returns the head and tail of the PriorityQueue.
  """
  @spec out(%__MODULE__{}) :: {:ok, {any(), %__MODULE__{}}} | {:error, :empty}
  def out(%__MODULE__{queue: []}), do: {:error, :empty}

  def out(%__MODULE__{queue: [head | tail]} = pq) do
    new_pq = %__MODULE__{pq | queue: tail}
    {:ok, {head, new_pq}}
  end

  @doc """
    Returns the head of the PriorityQueue.
  """
  @spec peek(%__MODULE__{}) :: {:ok, any()} | {:error, :empty}
  def peek(%__MODULE__{queue: []}), do: {:error, :empty}

  def peek(%__MODULE__{queue: [head | _tail]}), do: {:ok, head}

  @doc """
    Returns the length of the PriorityQueue.
  """
  @spec len(%__MODULE__{}) :: non_neg_integer()
  def len(%__MODULE__{queue: queue}), do: length(queue)

  @doc """
    Returns `true` if (and only if) the Priority Queue is empty.
  """
  @spec is_empty?(%__MODULE__{}) :: boolean()
  def is_empty?(%__MODULE__{queue: queue}), do: length(queue) == 0

  @doc """
    Custom implementation of reducing algorithm using recursion and tail-call optimization instead of just using `Enum.reduce/3`
  """
  @spec fold(%__MODULE__{}, any(), function()) :: any()
  def fold(%__MODULE__{queue: []}, acc, _fun), do: acc

  def fold(%__MODULE__{queue: [head | tail]} = pq, acc, fun) do
    new_acc = fun.(head, acc)
    new_pq = %__MODULE__{pq | queue: tail}
    fold(new_pq, new_acc, fun)
  end

  @doc """
    Replaces the head of the PriorityQueue.
  """
  @spec replace_head(%__MODULE__{}, any()) :: %__MODULE__{}
  def replace_head(%__MODULE__{queue: queue} = pq, item) do
    new_queue = List.replace_at(queue, 0, item)
    %__MODULE__{pq | queue: new_queue}
  end
end
