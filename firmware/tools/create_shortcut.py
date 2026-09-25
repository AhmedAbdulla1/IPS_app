import os
from pathlib import Path
import subprocess

desktop_dir = Path(r"D:\onedrive\Desktop")
shortcut_path = desktop_dir / "IPS Provisioning Studio.lnk"
bat_path = Path(r"d:\IPS_app\IPS_app\firmware\tools\launch_desktop_admin.bat").resolve()
tools_dir = bat_path.parent

vbs_content = f'''Set oWS = CreateObject("WScript.Shell")
sLink = "{str(shortcut_path)}"
Set oLink = oWS.CreateShortcut(sLink)
oLink.TargetPath = "{str(bat_path)}"
oLink.WorkingDirectory = "{str(tools_dir)}"
oLink.Description = "IPS Beacon Provisioning and Flasher Studio (Super Administrator)"
oLink.IconLocation = "shell32.dll,238"
oLink.Save
'''

vbs_file = tools_dir / "create_shortcut.vbs"
with open(vbs_file, "w", encoding="utf-8") as f:
    f.write(vbs_content)

res = subprocess.run(["cscript", "//nologo", str(vbs_file)], capture_output=True, text=True)
print("CSCRIPT STDOUT:", res.stdout)
print("CSCRIPT STDERR:", res.stderr)
print("Shortcut exists:", shortcut_path.exists())

try:
    vbs_file.unlink()
except Exception:
    pass
