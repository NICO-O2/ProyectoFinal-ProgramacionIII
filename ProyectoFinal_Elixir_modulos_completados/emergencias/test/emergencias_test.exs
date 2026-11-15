defmodule EmergenciasTest do
  use ExUnit.Case, async: false
  alias Emergencias.Servidores.{RecursosServer, NecesidadesServer, AlberguesServer, MascotasServer}

  test "el inventario no permite retiros concurrentes superiores a las existencias" do
    codigo = "TEST-" <> Base.encode16(:crypto.strong_rand_bytes(6))
    assert {:ok, _} = RecursosServer.registrar(codigo, "Agua", :agua, 50, "litros", "Bodega")
    resultados = 1..2 |> Task.async_stream(fn _ -> RecursosServer.retirar(codigo, 30) end, max_concurrency: 2) |> Enum.to_list()
    assert Enum.count(resultados, fn {:ok, {:ok, _}} -> true; _ -> false end) == 1
    assert {:ok, recurso} = RecursosServer.consultar(codigo)
    assert recurso.cantidad == 20
  end

  test "registra y ordena necesidades por prioridad" do
    id1 = "N-" <> Base.encode16(:crypto.strong_rand_bytes(6))
    id2 = "N-" <> Base.encode16(:crypto.strong_rand_bytes(6))
    assert {:ok, _} = NecesidadesServer.registrar(id1, :agua, "Agua para sector", 10, "centro", :baja, "ana")
    assert {:ok, _} = NecesidadesServer.registrar(id2, :agua, "Agua urgente", 5, "centro", :critica, "ana")
    [primera | _] = NecesidadesServer.pendientes_priorizadas()
    assert primera.id == id2
  end

  test "un albergue no supera su capacidad" do
    codigo = "A-" <> Base.encode16(:crypto.strong_rand_bytes(6))
    assert {:ok, _} = AlberguesServer.registrar(codigo, "Albergue Norte", "norte", 1)
    assert {:ok, _} = AlberguesServer.ingresar(codigo, "DOC-1")
    assert {:error, :sin_cupos} = AlberguesServer.ingresar(codigo, "DOC-2")
  end

  test "calcula coincidencias de mascotas por varios atributos" do
    assert {:ok, perdida} = MascotasServer.reportar(:perdida, "perro", "Luna", "oreja blanca", "negro", "mediano", "norte", "300")
    assert {:ok, _encontrada} = MascotasServer.reportar(:encontrada, "perro", "Luna", "oreja blanca", "negro", "mediano", "norte", "301")
    assert Enum.any?(MascotasServer.coincidencias(), &(&1.perdida == perdida.id and &1.puntaje >= 2))
  end
end
