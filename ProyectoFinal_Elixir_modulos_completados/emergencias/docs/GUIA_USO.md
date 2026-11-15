# Guía rápida de uso desde IEx

Inicia la aplicación desde la carpeta del proyecto:

```bash
iex -S mix
```

## Usuarios

```elixir
alias Emergencias.Servidores.UsuariosServer, as: Usuarios
Usuarios.conectar("laura", "clave123", :coordinador, "centro")
Usuarios.autorizar("laura", [:coordinador, :administrador])
Usuarios.registrar_actividad("laura", "registró una necesidad")
Usuarios.desconectar("laura")
```

Si el usuario no existe, `conectar/4` lo registra. Si ya existe, verifica la contraseña. Los roles válidos son `:ciudadano`, `:voluntario`, `:coordinador` y `:administrador`.

## Zonas, sectores y puntos

```elixir
alias Emergencias.Servidores.ZonasServer, as: Zonas
Zonas.registrar("Z01", "Centro", :alto, 120)
Zonas.registrar_sector("Z01", "S01", "Sector 1", :critico, 50)
Zonas.registrar_punto("Z01", "S01", "P01", "Puesto de atención", 10)
Zonas.estadisticas("Z01")
```

## Recursos y necesidades

```elixir
alias Emergencias.Servidores.RecursosServer, as: Recursos
alias Emergencias.Servidores.NecesidadesServer, as: Necesidades
Recursos.registrar("R001", "Agua", :agua, 50, "litros", "centro_acopio_1")
Necesidades.registrar("N001", :agua, "Agua para sector 3", 30, "centro", :critica, "laura")
Necesidades.asignar_recurso("N001", "R001", 30)
Recursos.consultar("R001")
Necesidades.pendientes_priorizadas()
```

La asignación exige que la cantidad coincida con la necesidad y que la categoría del recurso coincida con el tipo solicitado. El GenServer de recursos protege el inventario frente a llamadas simultáneas.

## Transferir recursos entre centros

```elixir
Recursos.transferir("R001", "albergue_2", 5)
Recursos.disponibles(:agua, "albergue_2")
```

El recurso transferido se registra en destino con un código derivado `R001@albergue_2`.

## Personas y mensajes

```elixir
alias Emergencias.Servidores.PersonasServer, as: Personas
Personas.registrar("12345", "Andres", 25, "norte", :reportada)
Personas.cambiar_estado("12345", :localizada)
Personas.enviar_mensaje("12345", "familia", "Andres", "Estamos buscandote")
Personas.mensajes("12345")
```

Para marcar un mensaje como entregado, usa `Personas.marcar_mensaje("12345", id_mensaje, :entregado)`.

## Mascotas

```elixir
alias Emergencias.Servidores.MascotasServer, as: Mascotas
Mascotas.reportar(:perdida, "perro", "Luna", "mancha en oreja", "negra", "mediana", "norte", "300123")
Mascotas.reportar(:encontrada, "perro", nil, "mancha en oreja", "negra", "mediana", "norte", "300456")
Mascotas.coincidencias()
```

El puntaje considera especie (2 puntos), color, tamaño, zona y nombre (1 punto cada uno). El umbral de sugerencia es 2 puntos. Una coincidencia no se cierra hasta confirmar ambos identificadores.

## Albergues

```elixir
alias Emergencias.Servidores.AlberguesServer, as: Albergues
Albergues.registrar("A01", "Albergue Norte", "norte", 150)
Albergues.ingresar("A01", "12345")
Albergues.consultar("A01")
Albergues.salir("A01", "12345")
Albergues.mas_ocupados()
```

## Resumen general

```elixir
Emergencias.Resumen.general()
```

## Pruebas

```bash
mix format
mix test
```

Los estados se guardan en archivos de texto dentro de `data/`. No borres esos archivos si necesitas conservar la información registrada.

## Ejecutar operaciones con autorización por rol

La capa `Emergencias.Seguridad` comprueba que el usuario esté conectado y tenga uno de los roles permitidos antes de ejecutar una función:

```elixir
Emergencias.Seguridad.ejecutar("laura", [:coordinador, :administrador], fn ->
  Emergencias.Servidores.ZonasServer.registrar("Z02", "Norte", :critico, 300)
end)
```

En la interfaz o módulo de comandos del equipo, las operaciones restringidas deben invocarse a través de esta capa y no directamente desde la entrada del usuario.
