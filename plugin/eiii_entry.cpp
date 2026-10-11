// clap_entry for the clap-wrapper builds: compiled into each format (VST3, AU), linked to the eiii-rack-impl library.
#include "clap/clap.h"

bool eiii_entry_init(char const *plugin_path);
void eiii_entry_deinit();
void const *eiii_entry_get_factory(char const *factory_id);

extern "C" CLAP_EXPORT clap_plugin_entry_t const clap_entry = { CLAP_VERSION_INIT, eiii_entry_init, eiii_entry_deinit, eiii_entry_get_factory };
