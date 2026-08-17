/// UI strings (Spanish). Full localization is deferred; keeping every string
/// here makes that switch mechanical.
abstract final class Strings {
  static const appTitle = 'PnP Studio';

  // Home
  static const newGridProject = 'Nuevo proyecto de cartas';
  static const newGridProjectSubtitle =
      'Rejilla automática: todas las cartas con el mismo tamaño';
  static const newFreeformProject = 'Nuevo proyecto de forma libre';
  static const newFreeformProjectSubtitle =
      'Imágenes de cualquier tamaño, posicionadas a mano';
  static const openProject = 'Abrir proyecto…';
  static const recentProjects = 'Proyectos recientes';

  // New project dialog
  static const projectName = 'Nombre del proyecto';
  static const pageSize = 'Tamaño de página';
  static const cardSize = 'Tamaño de carta';
  static const widthMm = 'Ancho (mm)';
  static const heightMm = 'Alto (mm)';
  static const create = 'Crear';
  static const cancel = 'Cancelar';
  static const invalidSize = 'Introduce un tamaño válido en mm';
  static const cardDoesNotFit = 'La carta no cabe en la página elegida';

  // Editor
  static const addCards = 'Añadir cartas';
  static const importFolder = 'Importar carpeta';
  static const globalBack = 'Trasera global';
  static const globalBacks = 'Traseras globales';
  static const addGlobalBack = 'Añadir trasera global…';
  static const removeGlobalBack = 'Eliminar trasera global';
  static const useGlobalBack = 'Usar trasera global';
  static const useDefaultBack = 'Usar trasera por defecto';
  static const defaultBackSuffix = '(por defecto)';
  static const selectedCount = 'seleccionadas';
  static const detail = 'Detalle';
  static const selectGlobalBackCheck = 'Seleccionar trasera global';
  static const addNewGlobalBack = 'Añadir nueva carta global';
  static const dropImageHint = 'Suelta una imagen aquí o haz clic para elegirla';
  static const dropImagesHint =
      'Suelta imágenes aquí o haz clic para elegirlas';
  static const noBack = 'Sin trasera';
  static const close = 'Cerrar';
  static const assignGlobalBack = 'Asignar trasera global';
  static const removeSelected = 'Eliminar seleccionadas';
  static const selectAll = 'Seleccionar todas';
  static const clearSelection = 'Quitar selección';
  static const setBack = 'Elegir trasera…';
  static const clearBack = 'Quitar trasera';
  static const removeCard = 'Eliminar carta';
  static const copies = 'Copias';
  static const cards = 'Cartas';
  static const pages = 'Páginas';
  static const items = 'Imágenes';
  static const addImage = 'Añadir imagen';
  static const addPage = 'Añadir página';
  static const removePage = 'Eliminar página';
  static const removeItem = 'Eliminar imagen';
  static const backPageReadOnly =
      'Página de traseras: se genera automáticamente espejada';
  static const save = 'Guardar';
  static const saveAs = 'Guardar como…';
  static const exportPdf = 'Exportar PDF';
  static const undo = 'Deshacer';
  static const redo = 'Rehacer';
  static const settings = 'Ajustes del proyecto';
  static const unsavedChanges = 'Cambios sin guardar';
  static const unsavedChangesBody =
      'Hay cambios sin guardar. ¿Quieres guardarlos antes de salir?';
  static const discard = 'Descartar';
  static const emptyProjectHint =
      'Añade cartas con el botón «Añadir cartas» o arrastra imágenes aquí';
  static const emptyFreeformHint =
      'Añade imágenes con el botón «Añadir imagen» o arrastra imágenes aquí';

  // Settings dialog
  static const bleedMm = 'Sangrado (mm)';
  static const spacingMm = 'Separación entre cartas (mm)';
  static const cutLines = 'Marcas de corte';
  static const calibrationMarks = 'Marcas de calibración y registro';
  static const jpegQuality = 'Calidad JPEG';
  static const losslessPng = 'PNG sin pérdida';
  static const fitMode = 'Ajuste de imagen';
  static const fitCover = 'Cubrir (recorta)';
  static const fitContain = 'Contener (deja bordes)';
  static const fitStretch = 'Estirar';
  static const accept = 'Aceptar';

  // Export
  static const exporting = 'Generando PDF…';
  static const exportDone = 'PDF exportado';
  static const exportFailed = 'Error al exportar';
  static const page = 'Página';

  // Misc
  static const front = 'Frontal';
  static const back = 'Trasera';
  static const error = 'Error';
}
