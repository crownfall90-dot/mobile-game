from pathlib import Path
import re


project = Path("project.godot").read_text(encoding="utf-8")
preset = Path("export_presets.cfg").read_text(encoding="utf-8")
project_version = re.search(r'^config/version="([^"]+)"$', project, re.MULTILINE).group(1)
preset_versions = re.findall(r'^version/name="([^"]+)"$', preset, re.MULTILINE)
preset_codes = re.findall(r'^version/code=(\d+)$', preset, re.MULTILINE)
assert len(preset_versions) == 2 and set(preset_versions) == {project_version}, (
    project_version,
    preset_versions,
)
assert len(preset_codes) == 2 and len(set(preset_codes)) == 1, preset_codes
print(f"RELEASE VERSION OK: {project_version}, code {preset_codes[0]}")
