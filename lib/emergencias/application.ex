defmodule Emergencias.Application do
  use Application
  @impl true
  def start(_type, _args) do
    children = [
      Emergencias.Servidores.RecursosServer,
      Emergencias.Servidores.UsuariosServer,
      Emergencias.Servidores.ZonasServer,
      Emergencias.Servidores.NecesidadesServer,
      Emergencias.Servidores.PersonasServer,
      Emergencias.Servidores.MascotasServer,
      Emergencias.Servidores.AlberguesServer
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: Emergencias.Supervisor)
  end
end
