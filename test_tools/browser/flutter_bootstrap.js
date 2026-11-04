{{flutter_js}}
{{flutter_build_config}}
// The versioned SSS public-asset worker owns offline caching. Do not register
// Flutter's second worker at the same scope: competing workers cause reloads.
_flutter.loader.load();
