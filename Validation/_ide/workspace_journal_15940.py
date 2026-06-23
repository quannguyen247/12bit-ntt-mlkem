# 2026-06-21T21:36:10.646831600
import vitis

client = vitis.create_client()
client.set_workspace(path="Validation")

platform = client.get_component(name="ntt_platform")
status = platform.build()

comp = client.create_app_component(name="hello_world",platform = "$COMPONENT_LOCATION/../ntt_platform/export/ntt_platform/ntt_platform.xpfm",domain = "standalone_psu_cortexa53_0",template = "hello_world")

status = platform.build()

comp = client.get_component(name="hello_world")
comp.build()

comp = client.create_app_component(name="MAX30102",platform = "$COMPONENT_LOCATION/../ntt_platform/export/ntt_platform/ntt_platform.xpfm",domain = "standalone_psu_cortexa53_0")

client.delete_component(name="hello_world")

client.delete_component(name="componentName")

comp = client.create_app_component(name="app_component",platform = "$COMPONENT_LOCATION/../ntt_platform/export/ntt_platform/ntt_platform.xpfm",domain = "standalone_psu_cortexa53_0")

client.delete_component(name="app_component")

client.delete_component(name="componentName")

vitis.dispose()

