# 2026-06-22T23:48:39.572673845
import vitis

client = vitis.create_client()
client.set_workspace(path="Validation")

status = client.delete_sys_project(name="ntt_sysprj")

proj = client.create_sys_project(name="system_project", platform="$COMPONENT_LOCATION/../ntt_platform/export/ntt_platform/ntt_platform.xpfm", template="empty_accelerated_application" , build_output_type="xsa")

proj = client.get_sys_project(name="system_project")

proj = proj.add_component(name="MAX30102")

