defmodule Emergencias.Servidores.RecursosServer do
  use GenServer
  alias Emergencias.Dominio.Recurso
  alias Emergencias.Persistencia

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def registrar(c, n, cat, cant, u, ub), do: GenServer.call(__MODULE__, {:registrar, c, n, cat, cant, u, ub})
  def retirar(c, cant), do: GenServer.call(__MODULE__, {:retirar, c, cant})
  def agregar(c, cant), do: GenServer.call(__MODULE__, {:agregar, c, cant})
  def consultar(c), do: GenServer.call(__MODULE__, {:consultar, c})
  def listar, do: GenServer.call(__MODULE__, :listar)
  def disponibles(categoria \\ nil, ubicacion \\ nil), do: GenServer.call(__MODULE__, {:disponibles, categoria, ubicacion})
  def transferir(c, destino, cant), do: GenServer.call(__MODULE__, {:transferir, c, destino, cant})

  @impl true
  def init(_), do: {:ok, Persistencia.cargar("recursos", %{})}

  @impl true
  def handle_call({:registrar, c, n, cat, cant, u, ub}, _from, estado) do
    respuesta = cond do
      Map.has_key?(estado, c) -> {:error, :id_repetido}
      true -> Recurso.nuevo(c, n, cat, cant, u, ub)
    end
    case respuesta do
      {:ok, recurso} -> nuevo = Map.put(estado, c, recurso); persistir(nuevo); {:reply, {:ok, recurso}, nuevo}
      error -> {:reply, error, estado}
    end
  end
  def handle_call({:retirar, c, cant}, _from, estado), do: actualizar(estado, c, &Recurso.retirar(&1, cant))
  def handle_call({:agregar, c, cant}, _from, estado), do: actualizar(estado, c, &Recurso.agregar(&1, cant))
  def handle_call({:consultar, c}, _from, estado), do: {:reply, Map.fetch(estado, c) |> normalizar(), estado}
  def handle_call(:listar, _from, estado), do: {:reply, Map.values(estado), estado}
  def handle_call({:disponibles, categoria, ubicacion}, _from, estado) do
    lista = estado |> Map.values() |> Enum.filter(fn r ->
      (is_nil(categoria) or r.categoria == categoria) and
        (is_nil(ubicacion) or r.ubicacion == ubicacion) and r.cantidad > 0
    end)
    {:reply, lista, estado}
  end
  def handle_call({:transferir, c, destino, cant}, _from, estado) do
    with {:ok, origen} <- fetch(estado, c),
         {:ok, origen_actualizado} <- Recurso.retirar(origen, cant) do
      codigo_destino = "#{c}@#{destino}"
      resultado_destino = case Map.fetch(estado, codigo_destino) do
        {:ok, existente} -> Recurso.agregar(existente, cant)
        :error -> Recurso.nuevo(codigo_destino, origen.nombre, origen.categoria, cant,
          origen.unidad, destino)
      end
      case resultado_destino do
        {:ok, destino_actualizado} ->
          nuevo = estado |> Map.put(c, origen_actualizado) |> Map.put(codigo_destino, destino_actualizado)
          persistir(nuevo)
          {:reply, {:ok, %{origen: origen_actualizado, destino: destino_actualizado}}, nuevo}
        error -> {:reply, error, estado}
      end
    else
      error -> {:reply, error, estado}
    end
  end

  defp actualizar(estado, codigo, funcion) do
    case Map.fetch(estado, codigo) do
      {:ok, recurso} ->
        case funcion.(recurso) do
          {:ok, actualizado} -> nuevo = Map.put(estado, codigo, actualizado); persistir(nuevo); {:reply, {:ok, actualizado}, nuevo}
          error -> {:reply, error, estado}
        end
      :error -> {:reply, {:error, :no_existe}, estado}
    end
  end
  defp fetch(estado, codigo) do
    case Map.fetch(estado, codigo) do
      {:ok, recurso} -> {:ok, recurso}
      :error -> {:error, :no_existe}
    end
  end
  defp normalizar({:ok, r}), do: {:ok, r}
  defp normalizar(:error), do: {:error, :no_existe}
  defp persistir(estado), do: Persistencia.guardar("recursos", estado)
end
