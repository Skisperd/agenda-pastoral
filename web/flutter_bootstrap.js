{{flutter_js}}
{{flutter_build_config}}

// Carrega o CanvasKit do próprio app em vez da CDN do Google:
// funciona offline e em redes que bloqueiam a CDN.
_flutter.loader.load({
  config: { canvasKitBaseUrl: "canvaskit/" },
});
