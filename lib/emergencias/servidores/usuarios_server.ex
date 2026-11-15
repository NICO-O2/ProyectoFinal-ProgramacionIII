defmodule Emergencias.Servidores.UsuariosServer do
  use GenServer
  alias Emergencias.Persistencia
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def conectar(usuario, clave, tipo \\ :ciudadano, zona \\ nil), do: GenServer.call(__MODULE__, {:conectar, usuario, clave, tipo, zona})
  def desconectar(usuario), do: GenServer.call(__MODULE__, {:desconectar, usuario})
  def consultar(usuario), do: GenServer.call(__MODULE__, {:consultar, usuario})
  def listar, do: GenServer.call(__MODULE__, :listar)
  def registrar_actividad(usuario, actividad), do: GenServer.call(__MODULE__, {:actividad, usuario, actividad})
  def autorizar(usuario, roles), do: GenServer.call(__MODULE__, {:autorizar, usuario, List.wrap(roles)})
  @roles [:ciudadano, :voluntario, :coordinador, :administrador]
  @impl true
  def init(_), do: {:ok, %{usuarios: Persistencia.cargar("usuarios", %{}), conectados: MapSet.new()}}
  @impl true
  def handle_call({:conectar, u, p, tipo, zona}, _from, s) when is_binary(u) and u != "" and is_binary(p) and p != "" do
    case Map.fetch(s.usuarios, u) do
      :error when tipo in @roles ->
        usuario = %{username: u, password_hash: hash(p), tipo: tipo, zona: zona, actividades: []}
        usuarios = Map.put(s.usuarios, u, usuario); nuevo = %{s | usuarios: usuarios, conectados: MapSet.put(s.conectados, u)}
        guardar(usuarios); {:reply, {:ok, Map.drop(usuario, [:password_hash])}, nuevo}
      :error -> {:reply, {:error, :rol_invalido}, s}
      {:ok, usuario} ->
        if secure_equal(usuario.password_hash, hash(p)) do
          nuevo = %{s | conectados: MapSet.put(s.conectados, u)}
          {:reply, {:ok, Map.drop(usuario, [:password_hash])}, nuevo}
        else
          {:reply, {:error, :credenciales_invalidas}, s}
        end
    end
  end
  def handle_call({:conectar, _, _, _, _}, _from, s), do: {:reply, {:error, :datos_invalidos}, s}
  def handle_call({:desconectar, u}, _from, s), do: {:reply, :ok, %{s | conectados: MapSet.delete(s.conectados, u)}}
  def handle_call({:consultar, u}, _from, s) do
    respuesta = case Map.fetch(s.usuarios, u) do {:ok, x} -> {:ok, Map.drop(x, [:password_hash])}; :error -> {:error, :no_existe} end
    {:reply, respuesta, s}
  end
  def handle_call(:listar, _from, s), do: {:reply, Enum.map(s.usuarios, fn {_k, v} -> Map.drop(v, [:password_hash]) end), s}
  def handle_call({:autorizar, u, roles}, _from, s) do
    respuesta = case Map.fetch(s.usuarios, u) do
      {:ok, user} -> if MapSet.member?(s.conectados, u) and user.tipo in roles, do: :ok, else: {:error, :no_autorizado}
      :error -> {:error, :usuario_no_existe}
    end
    {:reply, respuesta, s}
  end
  def handle_call({:actividad, u, actividad}, _from, s) do
    case Map.fetch(s.usuarios, u) do
      {:ok, user} -> user = %{user | actividades: [%{detalle: actividad, fecha: DateTime.utc_now()} | user.actividades]}; users = Map.put(s.usuarios, u, user); guardar(users); {:reply, :ok, %{s | usuarios: users}}
      :error -> {:reply, {:error, :no_existe}, s}
    end
  end
  defp hash(p), do: :crypto.hash(:sha256, p) |> Base.encode16(case: :lower)
  defp secure_equal(a, b), do: Plugless.secure_compare(a, b)
  defp guardar(users), do: Persistencia.guardar("usuarios", users)
end

defmodule Plugless do
  def secure_compare(a, b) when byte_size(a) == byte_size(b), do: :crypto.hash_equals(a, b)
  def secure_compare(_, _), do: false
end
