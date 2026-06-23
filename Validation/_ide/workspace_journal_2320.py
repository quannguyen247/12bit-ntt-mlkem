# 2026-06-22T23:10:57.065924237
import vitis

client = vitis.create_client()
client.set_workspace(path="Validation")

platform = client.get_component(name="ntt_platform")
status = platform.build()

comp = client.get_component(name="MAX30102")
comp.build()

proj = client.create_sys_project(name="ntt_sysprj", platform="$COMPONENT_LOCATION/../ntt_platform/export/ntt_platform/ntt_platform.xpfm", template="empty_accelerated_application" , build_output_type="xsa")

proj = client.get_sys_project(name="ntt_sysprj")

proj = proj.add_component(name="MAX30102")

vitis.dispose()

