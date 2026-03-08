//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <sono_query/sono_query_desktop.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) sono_query_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "SonoQueryDesktop");
  sono_query_desktop_register_with_registrar(sono_query_registrar);
}
