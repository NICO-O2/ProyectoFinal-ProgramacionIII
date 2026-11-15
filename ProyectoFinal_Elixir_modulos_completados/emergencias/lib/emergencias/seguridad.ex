defmodule Emergencias.Seguridad do
  @moduledoc "Capa de autorización para ejecutar acciones según el rol de un usuario conectado."
  alias Emergencias.Servidores.UsuariosServer

  def ejecutar(usuario, roles_permitidos, funcion) when is_function(funcion, 0) do
    case UsuariosServer.autorizar(usuario, roles_permitidos) do
      :ok -> funcion.()
      error -> error
    end
  end
end
