"""TrackMania Specific functions"""
import os
import shutil
import zipfile
from pathlib import Path

from tools import find_through_uninstaller, windows_path_to_linux_path, get_wine_prefix, get_wine_executable, run_wine, \
    download_file, get_home_path
from urllib.parse import quote
import yaml


class TrackManiaForeverNotFoundError(Exception):
    def __init(self, message = "Neither Nations Forever nor United Forever was found!"):
        self.message = message

class TrackManiaUndefinedGameVersionError(Exception):
    def __init(self, message = "Neither Nations Forever nor United Forever was found!"):
        self.message = message

def get_path_united(pfx: str = None):
    return windows_path_to_linux_path(find_through_uninstaller("TmUnitedForever_is1", "InstallLocation", pfx), pfx)

def get_path_nations(pfx: str = None):
    return windows_path_to_linux_path(find_through_uninstaller("TmNationsForever_is1", "InstallLocation", pfx), pfx)

def determine_united(pfx: str)-> tuple[bool, str, str]:
    united = get_path_united(pfx)
    if united:
        return True, united, get_home_path(pfx) + "/Documents/TmForever"
    else:
        nations = get_path_nations(pfx)
        if nations:
            return False, nations, get_home_path(pfx) + "/Documents/TmForever"
        raise TrackManiaForeverNotFoundError()

class TrackMania:
    def __init__(self, path=None, united=None, wine_path=None, pfx=None):
        self.path = path
        self.united = united
        self.pfx = pfx
        self.wine_path = wine_path


        if self.pfx is None:
            self.pfx = get_wine_prefix()
        if self.wine_path is None:
            self.wine_path = get_wine_executable()
        if self.path is None:
            self.united, self.path, self.documents_folder = determine_united(self.pfx)
        if self.united is None:
            raise TrackManiaUndefinedGameVersionError

        self.tmloader_path = None
        self._check_for_tmloader()

        self.uvme_uninstaller = None
        self.is_uvme_installed()


    def install_modloader(self):
        modloader_download = download_file("https://tomashu.pages.dev/modloader/modloader/TMLoader-1.0.1-win32.zip", self.pfx)

        self.tmloader_path = self.pfx + "/drive_c/Program Files/TMLoader/"
        with zipfile.ZipFile(modloader_download, "r") as zip:
            zip.extractall(self.tmloader_path)

        settings_path = self.tmloader_path + "database/TmForever/products/TmForever"
        Path(settings_path).mkdir(parents=True, exist_ok=True)

        with open(settings_path + "/settings.yaml", "w") as f:
            yaml.safe_dump({"install": "C:/Program Files (x86)/TmUnitedForever"}, f)

        os.remove(modloader_download)

        Path(self.tmloader_path + "database/TmForever/profiles").mkdir(parents=True, exist_ok=True)
        self.create_tmloader_profile("default", ["TMUnlimiter", "Competition Patch", "CoreMod"], description="Default (TMUnlimiter, Competition Patch")
        self.create_tmloader_profile("comp", ["Competition Patch", "CoreMod"], description="Competition Patch (No TMUnlimiter")
        self.create_tmloader_profile("tminterface", ["TMUnlimiter", "TMInterface", "CoreMod"], description="TwinkieTweaks (+TMUnlimiter, Competition Patch, Coremod)")

        os.rename(self.path + "TmForever.exe", self.path + "TmForever.bak.exe")
        shutil.copy(self.tmloader_path + "ShimRun.exe", self.path + "TmForever.exe")

    def _check_for_tmloader(self):
        path = self.pfx + "/drive_c/Program Files/TMLoader/"
        if os.path.exists(path):
            self.tmloader_path = path
            self.tmloader_config = self.tmloader_path + "config.yaml"

    def start_tmloader_profile(self, profile_name: str):
        self.start_tmloader(["run", "TmForever", profile_name])

    def start_tmloader(self, args: list = None):
        run_wine(Path(self.tmloader_path + "TMLoader.exe"), args)

    def start_trackmania(self):
        run_wine(Path(self.path + "TmForever.exe"))

    def start_launcher(self):
        run_wine(Path(self.path + "TmForeverLauncher.exe"))

    def start_vanilla(self):
        run_wine(Path(self.path + "TmForever.bak.exe"))

    def download_uvme(self):
        url = "https://github.com/AroPix/TrackManiaAssets/releases/download/1.0.0/TmNationsForever_UVME_v3.1.exe"
        if self.united:
            url = "https://github.com/AroPix/TrackManiaAssets/releases/download/1.0.0/TmUnitedForever_UVME_v3.1.exe"

        path = download_file(url)
        print(path)
        run_wine(Path(path))
        os.remove(path)

    def is_uvme_installed(self):
        self.uvme_uninstaller = windows_path_to_linux_path(find_through_uninstaller("TmNationsForever - UVME_is1", "UninstallString", self.pfx), self.pfx)

    def uninstall_uvme(self):
        if self.uvme_uninstaller:
            run_wine(Path(self.uvme_uninstaller), ["/SILENT"])

    def download_car_skin(self, url: str, car_type = "CarCommon"):
        skins_folder = self.documents_folder + "/Skins/Vehicles/" +  car_type
        Path(skins_folder).mkdir(parents=True, exist_ok=True)
        download = download_file(quote(url, safe=":/?=&"), skins_folder)

        file_name = os.path.dirname(download) + "/" + os.path.basename(download) + ".loc"
        with open(file_name, "w", encoding="utf-8") as f:
            f.write(url.replace("https", "http"))

    def download_track(self, track_id: str, united=False):
        tracks_folder = self.documents_folder + "/Tracks/Challenges/Downloaded/"
        Path(tracks_folder).mkdir(parents=True, exist_ok=True)

        url = "https://nations.tm-exchange.com/trackgbx/" + track_id
        if united:
            url = "https://tmuf.exchange/trackgbx/" + track_id
        download_file(quote(url, safe=":/?=&"), tracks_folder)

    def download_texture_mod(self, url: str, environment = "Stadium"):
        texture_mods_folder = self.documents_folder + "/Skins/" +  environment + "/Mod/"
        Path(texture_mods_folder).mkdir(parents=True, exist_ok=True)
        download = download_file(quote(url, safe=":/?=&"), texture_mods_folder)

        file_name = os.path.dirname(download) + "/" + os.path.basename(download) + ".loc"
        with open(file_name, "w", encoding="utf-8") as f:
            f.write(url.replace("https", "http"))

    def install_twinkietweaks(self):
        twinkie_path = get_home_path() + "/Documents/Twinkie/Fonts"
        Path(twinkie_path).mkdir(parents=True, exist_ok=True)

        twinkie_font_url = "https://github.com/TwinkieTweaks/TwinkieNSIS/raw/refs/heads/main/Twinkie.ttf"
        maniaicons_font_url = "https://github.com/TwinkieTweaks/TwinkieNSIS/raw/refs/heads/main/ManiaIcons.ttf"

        if not (os.path.exists(twinkie_path + "/ManiaIcons.ttf") and os.path.exists(twinkie_path + "/Twinkie.ttf")):
            download_file(twinkie_font_url, twinkie_path)
            download_file(maniaicons_font_url, twinkie_path)
        else:
            print("TwinkieTweaks fonts already installed!")


        with open(self.tmloader_config, "r+") as f:
            data = yaml.safe_load(f)
            if "https://twinkietweaks.github.io/tmloader/" not in data.get("servers"):
                data.get("servers").append("https://twinkietweaks.github.io/tmloader/")
                f.seek(0)
                yaml.safe_dump(data, f, sort_keys=False)
                f.truncate()
            else:
                print("TwinkieTweaks Repository already installed!")

        Path(self.tmloader_path + "database/TmForever/profiles/twinkie.yaml").mkdir(parents=True, exist_ok=True)
        self.create_tmloader_profile("twinkietweaks", ["TMUnlimiter", "Twinkie", "Competition Patch", "CoreMod"], description="TwinkieTweaks (+TMUnlimiter, Competition Patch, Coremod)")

        self.start_tmloader()

    def create_tmloader_profile(self, name, mods: list, args: str = None, description = ""):
        empty_profile = {"program": {"id": "TmForever"}, "mods": [], "description": description}

        if args is not None:
            empty_profile["args"] = args

        for i in mods:
            empty_profile["mods"].append({"id": i})

        path = self.tmloader_path + f"database/TmForever/profiles/{name}.yaml"
        with open(path, "w") as f:
            yaml.safe_dump(empty_profile, f)

    def get_profiles(self):
        folder_path = self.tmloader_path + "database/TmForever/profiles/"
        data_list = {}

        for filename in os.listdir(folder_path):
            if filename.endswith((".yaml", ".yml")):
                file_path = os.path.join(folder_path, filename)
                with open(file_path, "r", encoding="utf-8") as f:
                    data = yaml.safe_load(f)
                    data_list[filename] = data

        return data_list



