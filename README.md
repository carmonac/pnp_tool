# pnp_tool

Herramientas para preparar cartas *print and play*: coloca tus imágenes en
páginas listas para imprimir a doble cara, con las traseras espejadas para que
coincidan al voltear la hoja, marcas de corte, sangrado y marcas de
calibración.

Incluye:

- **PnP Studio** (`app/`): aplicación de escritorio (macOS, Windows, Linux)
  con dos modos de proyecto:
  - **Rejilla**: todas las cartas con el mismo tamaño (póker, bridge, tarot…
    o personalizado) colocadas automáticamente en la página elegida (A4, A3,
    Carta… o personalizada). Trasera por carta o trasera global compartida.
  - **Forma libre**: imágenes de cualquier tamaño posicionadas a mano con
    arrastre, snapping y guías; la página siguiente muestra las traseras
    espejadas automáticamente.
  - Previsualización en vivo de cada página (lo que ves es exactamente lo que
    se imprime), proyectos guardables (`.pnp.json`) y exportación a PDF.
  - **Compartir proyectos**: exporta un archivo `.pnp` autocontenido (un ZIP
    con el proyecto y todas sus imágenes) que cualquiera puede abrir desde
    "Abrir proyecto" sin depender de rutas locales.
- **pnp_tool CLI** (`packages/pnp_cli/`): generación de PDF desde la terminal.
- **pnp_core** (`packages/pnp_core/`): motor de maquetación y generación de
  PDF compartido por ambos.

## Descargas

Binarios para cada sistema en la página de
[releases](https://github.com/carmonac/pnp_tool/releases/latest):

- `pnp_studio_<os>.zip` — la aplicación de escritorio.
- `pnp_tool_<os>` — la CLI.

En macOS los binarios no están firmados: la primera vez, abre la app con clic
derecho → Abrir, o ejecuta:

```bash
xattr -d com.apple.quarantine pnp_tool_macos
```

## CLI

```bash
pnp_tool <directorio_de_imagenes> <salida.pdf>
```

El directorio debe contener imágenes llamadas `<nombre>_front.<ext>` y
opcionalmente `<nombre>_back.<ext>`. Las cartas sin trasera propia usan
`global_back.<ext>` si existe.

Opciones:

```text
--page       Tamaño de página: a4, a3, a5, letter, legal o AnchoxAlto en mm (por defecto a4)
--card       Tamaño de carta: poker, bridge, tarot, miniUs, miniEuro, stdEuro, square o AnchoxAlto en mm (por defecto poker)
--bleed      Sangrado en mm (por defecto 1.0)
--spacing    Separación entre cartas en mm (por defecto 4.0)
--jpeg-quality  Calidad JPEG 1-100, o "png" para sin pérdida (por defecto 90)
--[no-]cut-lines     Marcas de corte (activadas por defecto)
--[no-]calibration   Marcas de calibración y registro (activadas por defecto)
--project    Renderizar un proyecto guardado desde PnP Studio (.pnp.json o paquete .pnp)
```

Ejemplos:

```bash
pnp_tool --page a3 --card tarot ./mis_cartas cartas.pdf
```

```bash
pnp_tool --project mi_mazo.pnp.json mazo.pdf
```

## Impresión

1. Imprime el PDF a doble cara con volteo por el **borde largo**.
2. Comprueba con la regla de calibración de la primera página que la impresora
   no ha escalado el documento (imprime al 100%, sin "ajustar a página").
3. Corta siguiendo las marcas de los márgenes.

## Desarrollo

Es un workspace de Dart (SDK ≥ 3.9) con tres paquetes: `packages/pnp_core`,
`packages/pnp_cli` y `app` (Flutter).

```bash
dart pub get
dart test packages/pnp_core
dart run packages/pnp_cli/bin/pnp_tool.dart example/input salida.pdf
```

```bash
cd app && flutter run -d macos   # o -d windows / -d linux
```

Los PNG de `resources/` van embebidos en el código generado
(`packages/pnp_core/lib/src/pdf/resources.g.dart`). Si cambias esos archivos,
regenera con:

```bash
dart run packages/pnp_core/tool/generate_resources.dart
```
