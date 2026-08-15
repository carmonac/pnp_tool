# Changelog

## 2.0.0 - 2026-08-15

### Added

- **PnP Studio**: aplicación de escritorio Flutter (macOS/Windows/Linux) con
  modo rejilla (cartas de tamaño uniforme con trasera global o por carta) y
  modo forma libre (imágenes de cualquier tamaño posicionadas a mano con
  snapping; traseras espejadas automáticamente en la página siguiente).
  Previsualización en vivo por página, proyectos guardables `.pnp.json`,
  exportación a PDF con progreso, deshacer/rehacer y arrastrar y soltar.
- CLI con opciones: `--page` y `--card` (presets o mm), `--bleed`,
  `--spacing`, `--jpeg-quality`, `--[no-]cut-lines`, `--[no-]calibration` y
  `--project` para renderizar proyectos guardados.
- Número de copias por carta.
- Orden natural de archivos (card2 antes que card10).
- Presets de página (A4, A3, A5, Carta, Legal) y de carta (póker, bridge,
  tarot, mini US/EU, euro estándar, cuadrada) más tamaños personalizados.

### Changed

- Reestructurado como workspace de Dart: `packages/pnp_core` (motor
  compartido), `packages/pnp_cli` (CLI) y `app` (Flutter).
- Los PDF ahora embeben JPEG (calidad 90 por defecto) en vez de PNG: el PDF
  de ejemplo pasa de 27 MB a ~1.4 MB. El sangrado se calcula desde la
  resolución real de cada imagen y se genera con operaciones en bloque
  (mucho más rápido).
- La rejilla se calcula según página y carta (antes fija 3×3) y se centra,
  eliminando el desbordamiento horizontal de 0.14 mm en A4.
- El espejado de traseras es genérico para cualquier número de columnas.
- Recursos (logo, marcas de calibración) embebidos en el binario: la CLI ya
  no necesita una carpeta `resources/` junto al ejecutable.

### Fixed

- Los binarios publicados fallaban al cargar recursos con rutas relativas.
- Nombres con `_front` repetido generaban claves incorrectas.
- Orden lexicográfico de cartas.
- Suite de tests rota y workflows de CI con actions retiradas.

## 1.0.0

- Versión inicial (CLI: rejilla 3×3 tamaño póker sobre A4).
