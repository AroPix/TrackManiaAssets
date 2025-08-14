import os
import re
import subprocess
from pathlib import Path
import wget

class WinePrefixNotFoundError(Exception):
    def __init(self, message = "WINEPREFIX env variable is not set!"):
        self.message = message
        super().__init__(self.message)
class WineNotFoundError(Exception):
    def __init(self, message = "WINE env variable is not set!"):
        self.message = message
        super().__init__(self.message)

def run_wine(exe_path: Path, args=None) -> int:
    if args is None:
        args = []
    env = os.environ.copy()
    wine = env.get("WINE")
    if not wine or not Path(wine).is_file():
        raise WineNotFoundError()
    wp = env.get("WINEPREFIX")
    if wp and not Path(wp).exists():
        raise WinePrefixNotFoundError()
    return subprocess.call([wine, str(exe_path)] + args, env=env, cwd=os.path.dirname(exe_path))

def run_windows(exe_path: str) -> int:
    if exe_path[:2] == "C:\\":
        print("Not C:\\")
        return 1
    else:
        exe_path = "/drive_c/" + exe_path[2:].replace("\\", "/")
    pfx = os.environ.get("WINEPREFIX")
    if not pfx:
        raise WinePrefixNotFoundError()
    return run_wine(Path(pfx + exe_path))

def find_registry_value(reg_file_path, key_pattern, value_name):
    key_regex = re.compile(r'^\[' + re.escape(key_pattern) + r'\]')
    value_regex = re.compile(rf'^"{re.escape(value_name)}"="(.+)"')

    in_target_key = False
    with open(reg_file_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if key_regex.match(line):
                in_target_key = True
                continue
            if in_target_key:
                if line.startswith("["):
                    in_target_key = False
                    continue
                match = value_regex.match(line)
                if match:
                    return match.group(1)
    return None

def path_reg_drive_c(file_name):
    return os.environ.get("WINEPREFIX") + "/" + file_name

def find_value_system_registry(key_pattern, value_name):
    return find_registry_value(path_reg_drive_c("system.reg"), key_pattern.replace("\\", "\\\\"), value_name)

def find_through_uninstaller(key_name, value_name):
    return find_value_system_registry("Software\\Wow6432Node\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\" + key_name, value_name)

def windows_path_to_linux_path(windows_path):
    if windows_path is None:
        return None
    windows_path = windows_path.replace('\\\"', "")
    path = windows_path[2:].replace("\\\\", "/")
    return os.environ.get("WINEPREFIX") + "/drive_c" + path

def get_wine_prefix():
    return os.environ.get("WINEPREFIX")

def get_wine_executable():
    return os.environ.get("WINE")

def get_drive_c():
    return get_wine_prefix() + "/drive_c"

def download_file(url, folder=None):
    if folder is None:
        folder = get_drive_c()
    return wget.download(url, folder)

def get_home_path(pfx=None):
    if pfx is None:
        pfx = get_wine_prefix()
    return pfx + "/drive_c/users/" + os.environ.get("USER")