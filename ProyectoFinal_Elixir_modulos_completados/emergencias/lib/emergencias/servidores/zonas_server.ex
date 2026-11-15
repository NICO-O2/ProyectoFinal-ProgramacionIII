defmodule Emergencias.Servidores.ZonasServer do
  use GenServer
  alias Emergencias.Persistencia
  @niveles [:critico, :alto, :medio, :bajo]
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def registrar(codigo, nombre, nivel, afectados \\ 0), do: GenServer.call(__MODULE__, {:zona, codigo, nombre, nivel, afectados})
  def registrar_sector(zona, codigo, nombre, nivel, afectados \\ 0), do: GenServer.call(__MODULE__, {:sector, zona, codigo, nombre, nivel, afectados})
  def registrar_punto(zona, sector, codigo, nombre, afectados \\ 0), do: GenServer.call(__MODULE__, {:punto, zona, sector, codigo, nombre, afectados})
  def consultar(codigo), do: GenServer.call(__MODULE__, {:consultar, codigo})
  def listar, do: GenServer.call(__MODULE__, :listar)
  def estadisticas(codigo), do: GenServer.call(__MODULE__, {:estadisticas, codigo})
  @impl true
  def init(_), do: {:ok, Persistencia.cargar("zonas", %{})}
  @impl true
  def handle_call({:zona, c, n, nivel, a}, _f, s) when nivel in @niveles and is_integer(a) and a >= 0 do
    if Map.has_key?(s, c), do: {:reply, {:error, :id_repetido}, s}, else: guardar_nuevo(s, c, %{codigo: c, nombre: n, nivel: nivel, afectados: a, sectores: %{}}, {:ok, :zona_registrada})
  end
  def handle_call({:zona, _, _, _, _}, _f, s), do: {:reply, {:error, :datos_invalidos}, s}
  def handle_call({:sector, z, c, n, nivel, a}, _f, s) do
    modificar_anidado(s, z, fn zona ->
      cond do
        nivel not in @niveles or not is_integer(a) or a < 0 -> {:error, :datos_invalidos}
        Map.has_key?(zona.sectores, c) -> {:error, :id_repetido}
        true -> {:ok, put_in(zona.sectores[c], %{codigo: c, nombre: n, nivel: nivel, afectados: a, puntos: %{}})}
      end
    end)
  end
  def handle_call({:punto, z, sec, c, n, a}, _f, s) do
    modificar_anidado(s, z, fn zona ->
      case Map.fetch(zona.sectores, sec) do
        {:ok, sector} when is_integer(a) and a >= 0 ->
          if Map.has_key?(sector.puntos, c), do: {:error, :id_repetido}, else: {:ok, put_in(zona.sectores[sec].puntos[c], %{codigo: c, nombre: n, afectados: a})}
        :error -> {:error, :sector_no_existe}
        _ -> {:error, :datos_invalidos}
      end
    end)
  end
  def handle_call({:consultar, c}, _f, s), do: {:reply, Map.fetch(s, c) |> respuesta(), s}
  def handle_call(:listar, _f, s), do: {:reply, Map.values(s), s}
  def handle_call({:estadisticas, c}, _f, s) do
    r = case Map.fetch(s, c) do {:ok, z} -> {:ok, %{afectados: contar_afectados(z), sectores: map_size(z.sectores)}}; :error -> {:error, :no_existe} end
    {:reply, r, s}
  end
  defp modificar_anidado(s, z, fun) do
    case Map.fetch(s, z) do
      {:ok, zona} -> case fun.(zona) do {:ok, actualizada} -> nuevo = Map.put(s, z, actualizada); guardar(nuevo); {:reply, {:ok, actualizada}, nuevo}; e -> {:reply, e, s} end
      :error -> {:reply, {:error, :zona_no_existe}, s}
    end
  end
  defp guardar_nuevo(s, c, z, respuesta) do
    nuevo = Map.put(s, c, z)
    guardar(nuevo)
    {:reply, respuesta, nuevo}
  end
  defp contar_afectados(%{afectados: a, sectores: sectores}), do: a + contar_sectores(Map.values(sectores))
  defp contar_sectores([]), do: 0
  defp contar_sectores([s | resto]), do: s.afectados + contar_puntos(Map.values(s.puntos)) + contar_sectores(resto)
  defp contar_puntos([]), do: 0
  defp contar_puntos([p | resto]), do: p.afectados + contar_puntos(resto)
  defp respuesta({:ok, x}), do: {:ok, x}
  defp respuesta(:error), do: {:error, :no_existe}
  defp guardar(s), do: Persistencia.guardar("zonas", s)
end
