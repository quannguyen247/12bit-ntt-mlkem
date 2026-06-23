# 2026-06-21T18:21:58.667426
import vitis

client = vitis.create_client()
client.set_workspace(path="Validation")

platform = client.create_platform_component(name = "ntt_platform",hw_design = "$COMPONENT_LOCATION/../NTT_wrapper.xsa",os = "standalone",cpu = "psu_cortexa53_0",domain_name = "standalone_psu_cortexa53_0",is_pmufw_req = True,architecture = "64-bit",compiler = "gcc")

platform = client.get_component(name="ntt_platform")
status = platform.update_hw(hw_design = "$COMPONENT_LOCATION/../NTT_wrapper.xsa")

client.delete_component(name="ntt_platform")

client.delete_component(name="ntt_platform")

platform = client.create_platform_component(name = "ntt_platform",hw_design = "$COMPONENT_LOCATION/../NTT_wrapper.xsa",os = "standalone",cpu = "psu_cortexa53_0",domain_name = "standalone_psu_cortexa53_0",is_pmufw_req = True,architecture = "64-bit",compiler = "gcc")

comp = client.create_app_component(name="hello_world",platform = "$COMPONENT_LOCATION/../ntt_platform/export/ntt_platform/ntt_platform.xpfm",domain = "standalone_psu_cortexa53_0",template = "hello_world")

status = platform.build()

comp = client.get_component(name="hello_world")
comp.build()

vitis.dispose()

