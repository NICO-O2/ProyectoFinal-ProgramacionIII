defmodule Emergencias.Servidores.NecesidadesServer do
  use GenServer
  alias Emergencias.Dominio.Necesidad
  alias Emergencias.Persistencia
  alias Emergencias.Servidores.RecursosServer
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def registrar(id, tipo, descripcion, cantidad, zona, prioridad, responsable), do: GenServer.call(__MODULE__, {:registrar, id, tipo, descripcion, cantidad, zona, prioridad, responsable})
  def listar(filtros \\ %{}), do: GenServer.call(__MODULE__, {:listar, filtros})
  def cambiar_estado(id, estado), do: GenServer.call(__MODULE__, {:estado, id, estado})
  def asignar_recurso(id, codigo_recurso, cantidad), do: GenServer.call(__MODULE__, {:asignar, id, codigo_recurso, cantidad}, :infinity)
  def pendientes_priorizadas, do: GenServer.call(__MODULE__, :priorizadas)
  @impl true
  def init(_), do: {:ok, Persistencia.cargar("necesidades", %{})}
  @impl true
  def handle_call({:registrar, id, tipo, desc, cant, zona, prioridad, responsable}, _f, s) do
    r = if Map.has_key?(s, id), do: {:error, :id_repetido}, else: Necesidad.nueva(id, tipo, desc, cant, zona, prioridad, responsable)
    case r do {:ok, n} -> nuevo = Map.put(s, id, n); guardar(nuevo); {:reply, {:ok, n}, nuevo}; e -> {:reply, e, s} end
  end
  def handle_call({:listar, filtros}, _f, s) do
    lista = s |> Map.values() |> Enum.filter(fn n -> Enum.all?(filtros, fn {k, v} -> Map.get(n, k) == v end) end) |> Necesidad.ordenar_por_prioridad()
    {:reply, lista, s}
  end
  def handle_call(:priorizadas, _f, s), do: {:reply, s |> Map.values() |> Enum.filter(&(&1.estado == :pendiente)) |> Necesidad.ordenar_por_prioridad(), s}
  def handle_call({:estado, id, estado}, _f, s) do
    actualizar_necesidad(s, id, fn n -> Necesidad.cambiar_estado(n, estado) end)
  end
  def handle_call({:asignar, id, codigo, cantidad}, _f, s) do
    case Map.fetch(s, id) do
      {:ok, %{estado: :pendiente, tipo: tipo, cantidad: requerida} = n} when cantidad == requerida and cantidad > 0 ->
        with {:ok, recurso} <- RecursosServer.consultar(codigo),
             true <- recurso.categoria == tipo,
             {:ok, _recurso_actualizado} <- RecursosServer.retirar(codigo, cantidad),
             {:ok, asignada} <- Necesidad.cambiar_estado(n, :asignada) do
          asignada = %{asignada | recurso_codigo: codigo}
          nuevo = Map.put(s, id, asignada)
          guardar(nuevo)
          {:reply, {:ok, asignada}, nuevo}
        else
          false -> {:reply, {:error, :tipo_recurso_no_coincide}, s}
          error -> {:reply, error, s}
        end
      {:ok, %{estado: estado}} when estado != :pendiente -> {:reply, {:error, :necesidad_no_pendiente}, s}
      {:ok, _} -> {:reply, {:error, :cantidad_invalida}, s}
      :error -> {:reply, {:error, :no_existe}, s}
    end
  end
  defp actualizar_necesidad(s, id, fun) do
    case Map.fetch(s, id) do {:ok, n} -> case fun.(n) do {:ok, actualizado} -> nuevo = Map.put(s, id, actualizado); guardar(nuevo); {:reply, {:ok, actualizado}, nuevo}; e -> {:reply, e, s} end; :error -> {:reply, {:error, :no_existe}, s} end
  end
  defp guardar(s), do: Persistencia.guardar("necesidades", s)
end
