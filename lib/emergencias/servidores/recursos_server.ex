defmodule Emergencias.Servidores.RecursosServer do
  use GenServer
  alias Emergencias.Dominio.Recurso

  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def registrar(codigo, nombre, categoria, cantidad, unidad, ubicacion) do
    GenServer.call(
      __MODULE__,
      {:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion}
    )
  end

  def retirar(codigo, cantidad), do: GenServer.call(__MODULE__, {:retirar, codigo, cantidad})

  def consultar(codigo), do: GenServer.call(__MODULE__, {:consultar, codigo})

  @impl true
  def init(recursos), do: {:ok, recursos}

  @impl true
  def handle_call(
        {:registrar, codigo, nombre, categoria, cantidad, unidad, ubicacion},
        _from,
        recursos
      ) do
    if Map.has_key?(recursos, codigo) do
      {:reply, {:error, :id_repetido}, recursos}
    else
      case Recurso.nuevo(codigo, nombre, categoria, cantidad, unidad, ubicacion) do
        {:ok, recurso} -> {:reply, {:ok, recurso}, Map.put(recursos, codigo, recurso)}
        {:error, motivo} -> {:reply, {:error, motivo}, recursos}
      end
    end
  end

  def handle_call({:retirar, codigo, cantidad}, _from, recursos) do
    with {:ok, recurso} <- buscar(recursos, codigo),
         {:ok, actualizado} <- Recurso.retirar(recurso, cantidad) do
      {:reply, {:ok, actualizado}, Map.put(recursos, codigo, actualizado)}
    else
      {:error, motivo} -> {:reply, {:error, motivo}, recursos}
    end
  end

  def handle_call({:consultar, codigo}, _from, recursos) do
    {:reply, buscar(recursos, codigo), recursos}
  end

  defp buscar(recursos, codigo) do
    case Map.fetch(recursos, codigo) do
      {:ok, recurso} -> {:ok, recurso}
      :error -> {:error, :no_existe}
    end
  end
end
