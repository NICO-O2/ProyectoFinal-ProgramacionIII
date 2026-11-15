# Sistema de Coordinación y Gestión de Emergencias

Proyecto académico en Elixir. Los servidores OTP se inician automáticamente desde `Emergencias.Application`.

## Ejecutar

```bash
mix format
mix test
iex -S mix
```

## Módulos principales

- `UsuariosServer`: registro automático, autenticación, roles, sesiones y actividad.
- `ZonasServer`: zonas, sectores, puntos de atención y estadísticas recursivas.
- `NecesidadesServer`: registro, filtros, prioridad, estados y asignación de recursos.
- `RecursosServer`: inventario serializado por GenServer e historial de movimientos.
- `PersonasServer`: personas afectadas, historial de estados y mensajes familiares.
- `MascotasServer`: reportes y puntaje de coincidencia por atributos.
- `AlberguesServer`: ingresos, salidas, cupos y ocupación.
- `Persistencia`: guarda los estados en archivos de texto en `data/`.

Los archivos de datos se crean automáticamente al realizar cambios. Para reiniciar los datos de prueba, detén la aplicación y elimina los archivos de `data/`.
