//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <on_audio_query_linux/on_audio_query_linux_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) on_audio_query_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "OnAudioQueryLinuxPlugin");
  on_audio_query_linux_plugin_register_with_registrar(on_audio_query_linux_registrar);
}
