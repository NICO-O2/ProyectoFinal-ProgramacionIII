defmodule Emergencias.Servidores.AlberguesServer do
  use GenServer
  alias Emergencias.Persistencia

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def registrar(codigo, nombre, zona, capacidad), do: GenServer.call(__MODULE__, {:registrar, codigo, nombre, zona, capacidad})
  def ingresar(codigo, documento), do: GenServer.call(__MODULE__, {:ingresar, codigo, documento})
  def salir(codigo, documento), do: GenServer.call(__MODULE__, {:salir, codigo, documento})
  def asociar_recurso(codigo, recurso_codigo), do: GenServer.call(__MODULE__, {:asociar_recurso, codigo, recurso_codigo})
  def asociar_necesidad(codigo, necesidad_id), do: GenServer.call(__MODULE__, {:asociar_necesidad, codigo, necesidad_id})
  def consultar(codigo), do: GenServer.call(__MODULE__, {:consultar, codigo})
  def listar, do: GenServer.call(__MODULE__, :listar)
  def mas_ocupados, do: GenServer.call(__MODULE__, :mas_ocupados)

  @impl true
  def init(_opts), do: {:ok, Persistencia.cargar("albergues", %{})}

  @impl true
  def handle_call({:registrar, codigo, nombre, zona, capacidad}, _from, estado)
      when is_integer(capacidad) and capacidad > 0 do
    if Map.has_key?(estado, codigo) do
      {:reply, {:error, :id_repetido}, estado}
    else
      albergue = %{codigo: codigo, nombre: nombre, zona: zona, capacidad: capacidad,
        ocupantes: MapSet.new(), recursos: [], necesidades: []}
      nuevo = Map.put(estado, codigo, albergue)
      guardar(nuevo)
      {:reply, {:ok, albergue}, nuevo}
    end
  end

  def handle_call({:registrar, _, _, _, _}, _from, estado),
    do: {:reply, {:error, :capacidad_invalida}, estado}

  def handle_call({:ingresar, codigo, documento}, _from, estado) do
    modificar(estado, codigo, fn albergue ->
      cond do
        MapSet.member?(albergue.ocupantes, documento) -> {:error, :persona_ya_ingresada}
        MapSet.size(albergue.ocupantes) >= albergue.capacidad -> {:error, :sin_cupos}
        true -> {:ok, %{albergue | ocupantes: MapSet.put(albergue.ocupantes, documento)}}
      end
    end)
  end

  def handle_call({:salir, codigo, documento}, _from, estado) do
    modificar(estado, codigo, fn albergue ->
      if MapSet.member?(albergue.ocupantes, documento) do
        {:ok, %{albergue | ocupantes: MapSet.delete(albergue.ocupantes, documento)}}
      else
        {:error, :persona_no_ingresada}
      end
    end)
  end

  def handle_call({:asociar_recurso, codigo, recurso}, _from, estado) do
    modificar(estado, codigo, fn albergue ->
      {:ok, %{albergue | recursos: Enum.uniq([recurso | albergue.recursos])}}
    end)
  end

  def handle_call({:asociar_necesidad, codigo, necesidad}, _from, estado) do
    modificar(estado, codigo, fn albergue ->
      {:ok, %{albergue | necesidades: Enum.uniq([necesidad | albergue.necesidades])}}
    end)
  end

  def handle_call({:consultar, codigo}, _from, estado) do
    respuesta = case Map.fetch(estado, codigo) do
      {:ok, albergue} -> {:ok, resumen(albergue)}
      :error -> {:error, :no_existe}
    end
    {:reply, respuesta, estado}
  end

  def handle_call(:listar, _from, estado),
    do: {:reply, Enum.map(Map.values(estado), &resumen/1), estado}

  def handle_call(:mas_ocupados, _from, estado) do
    lista = estado |> Map.values() |> Enum.map(&resumen/1) |> Enum.sort_by(& &1.porcentaje_ocupacion, :desc)
    {:reply, lista, estado}
  end

  defp modificar(estado, codigo, funcion) do
    case Map.fetch(estado, codigo) do
      {:ok, albergue} ->
        case funcion.(albergue) do
          {:ok, actualizado} ->
            nuevo = Map.put(estado, codigo, actualizado)
            guardar(nuevo)
            {:reply, {:ok, resumen(actualizado)}, nuevo}
          error -> {:reply, error, estado}
        end
      :error -> {:reply, {:error, :no_existe}, estado}
    end
  end

  defp resumen(albergue) do
    ocupados = MapSet.size(albergue.ocupantes)
    Map.merge(albergue, %{ocupacion_actual: ocupados,
      cupos_disponibles: albergue.capacidad - ocupados,
      porcentaje_ocupacion: ocupados / albergue.capacidad * 100})
  end

  defp guardar(estado), do: Persistencia.guardar("albergues", estado)
end
