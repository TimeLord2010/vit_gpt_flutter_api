// Platform-specific audio routing configuration
// This file ensures that audio output is routed to the mobile speaker instead of the earpiece
// Uses conditional exports to provide web-specific implementation when available
export 'audio_routing_stub.dart'
  if (dart.library.js_interop) 'audio_routing_web.dart';