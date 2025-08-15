import threading
import flet as ft
import argparse

from dotenv import load_dotenv

from trackmania import TrackMania
import configparser


load_dotenv()

class EnvironmentDropDown(ft.Dropdown):
    def __init__(self, environments=None):
        super().__init__()
        if environments is None:
            environments = ["CarCommon", "StadiumCar", "DesertCar", "RallyCar", "BayCar", "CoastCar", "IslandCar",
                            "SnowCar"]
        for env in environments:
            self.options.append(ft.DropdownOption(key=env, content=ft.Text(value=env)))
        self.value = "CarCommon"
        self.label = "Environment"

class DownloadModal(ft.AlertDialog):
    def __init__(self, page: ft.Page, title: str):
        super().__init__()
        self.page = page
        self.column = ft.Column(controls=[ft.Text(title)])
        self.dropdown = None
        self.content = self.column

        self.actions= [ft.ElevatedButton("Download", icon=ft.Icons.SAVE, on_click=lambda e: self.save())]

    def save(self):
        self.open = False
        self.page.update()

class DownloadTrack(DownloadModal):
    def __init__(self, page: ft.Page):
        super().__init__(page, "Paste the ID from either TrackMania Nations Exchange or TrackMania United Exchange")
        self.title = "Download Track"
        self.url = ft.TextField(label="TrackMania Exchange ID")
        self.dropdown = ft.Dropdown(value="Nations", options=[ft.DropdownOption(key="Nations", content=ft.Text(value="TrackMania Nations Forever Exchange")), ft.DropdownOption(key="United", content=ft.Text(value="TrackMania United Forever Exchange"))])
        self.column.controls.append(self.dropdown)
        self.column.controls.append(self.url)

    def save(self):
        united = False
        if self.dropdown.value == "United":
            united = True
        tm.download_track(self.url.value, united)
        super().save()

class ManiaParkDownload(DownloadModal):
    def __init__(self, page: ft.Page, title: str, description: str = "Use a direct link to the file. Click the copy link button on ManiaPark as example"):
        super().__init__(page, description)
        self.title = title
        self.url = ft.TextField(label="Direct Link")
        self.create_locator = ft.Checkbox(label="Create Locator (So others can see your Skin/Mod)", value=True)
        self.dropdown = None

        if tm.united:
            self.dropdown = self.get_dropdown()
            self.column.controls.append(self.dropdown)
        self.column.controls.append(self.url)
        self.column.controls.append(self.create_locator)

    def save(self):
        super().save()

    def get_dropdown(self):
        return EnvironmentDropDown()

    def get_environment(self):
        if self.dropdown is None:
            return "StadiumCar"
        return self.dropdown.value

class TextureModDownload(ManiaParkDownload):
    def save(self):
        tm.download_texture_mod(self.url.value, self.get_environment())
        super().save()

    def get_environment(self):
        if self.dropdown is None:
            return "Stadium"
        return self.dropdown.value

    def get_dropdown(self):
        return EnvironmentDropDown(["Stadium", "Alpine", "Bay", "Island", "Rally", "Speed", "Coast"])

class SkinDownload(ManiaParkDownload):
    def save(self):
        tm.download_car_skin(self.url.value, self.get_environment())
        super().save()


def log(line: str, log_view: ft.Text):
    log_view.value += ("" if log_view.value.endswith("\n") or log_view.value == "" else "\n") + line
    if len(log_view.value) > 10_000:
        log_view.value = log_view.value[-10_000:]  # truncate
    log_view.update()


def main(page: ft.Page):
    config = configparser.ConfigParser()
    page.title = "TrackMania Toolkit"
    page.theme_mode = "dark"
    page.padding = 16
    page.horizontal_alignment = "stretch"

    options = tm.get_profiles()


    config_profile = config.read("config.ini")
    if config_profile:
        launch_profile = config["general"]["profile"]
        print(launch_profile)
    else:
        launch_profile = "default"

    selected_label = ft.Text(f"Selected: " + launch_profile, weight=ft.FontWeight.W_600)

    def on_radio_change(e: ft.ControlEvent):
        selected_label.value = f"Selected: {radio_group.value}"
        nonlocal launch_profile
        launch_profile = radio_group.value

        config["general"] = {"profile": radio_group.value}

        with open("config.ini", "w") as f:
            config.write(f)

        page.update()


    radio_column = ft.Column([], tight=True, spacing=6)

    for key in options:
        description = options[key].get("description")
        if not description:
            description = "TMLoader Profile: " + key.split(".")[0]
        radio_column.controls.append(ft.Radio(value=key.split(".")[0], label=description, data=options[key]))

    radio_group = ft.RadioGroup(
        value=launch_profile,
        content=radio_column,
        on_change=on_radio_change,
    )


    def launch():
        page.window.destroy()
        tm.start_tmloader_profile(launch_profile)
    left_panel = ft.Container(
        ft.Column([ft.Text("Select one", weight=ft.FontWeight.BOLD), radio_group, selected_label, ft.ElevatedButton("Start", icon=ft.Icons.START, on_click=lambda e: launch())], spacing=10),
        padding=12, border_radius=12, bgcolor=ft.Colors.SURFACE, expand=True
    )

    log_view = ft.Text("", selectable=True, size=12)
    log_card = ft.Container(
        ft.Column([ft.Text("Log", weight=ft.FontWeight.BOLD), log_view], spacing=8),
        padding=12, border_radius=12, bgcolor=ft.Colors.SURFACE, expand=True
    )

    uvme = ft.ElevatedButton("Install UVME", icon=ft.Icons.DOWNLOAD,
                             on_click=lambda e: tm.download_uvme())
    if tm.uvme_uninstaller:
        uvme = ft.ElevatedButton("Uninstall UVME", icon=ft.Icons.REMOVE,
                          on_click=lambda e: tm.uninstall_uvme())


    actions_col = ft.Column(
        controls=[
            uvme,
            ft.ElevatedButton("Start Vanilla Game", icon=ft.Icons.BUILD, on_click=lambda e: tm.start_vanilla()),
            ft.ElevatedButton("Start Launcher", icon=ft.Icons.REFRESH, on_click=lambda e: tm.start_launcher()),
            ft.ElevatedButton("Install TwinkieTweaks", icon=ft.Icons.REFRESH, on_click=lambda e: tm.install_twinkietweaks()),
            ft.ElevatedButton("Download Skin", icon=ft.Icons.DOWNLOAD, on_click=lambda e: page.open(SkinDownload(page, "Download Car Skin"))),
            ft.ElevatedButton("Download Texture Mod", icon=ft.Icons.DOWNLOAD, on_click=lambda e: page.open(TextureModDownload(page, "Download Texture Mod"))),
            ft.ElevatedButton("Download Track", icon=ft.Icons.DOWNLOAD, on_click=lambda e: page.open(DownloadTrack(page))),
        ],
        spacing=10,
        horizontal_alignment=ft.CrossAxisAlignment.STRETCH,
        alignment=ft.MainAxisAlignment.START,
    )

    if tm.tmloader_path:
        actions_col.controls.append(ft.ElevatedButton("Start TMLoader", icon=ft.Icons.LAUNCH, on_click=lambda e: tm.start_tmloader()))

    right_panel = ft.Container(
        ft.Column([ft.Text("Actions", weight=ft.FontWeight.BOLD), actions_col], spacing=10),
        padding=12, border_radius=12, bgcolor=ft.Colors.SURFACE, expand=True
    )

    main_row = ft.Row([left_panel, right_panel, log_card], spacing=16, alignment=ft.MainAxisAlignment.SPACE_BETWEEN)

    # --- Countdown
    remaining_text = ft.Text("5 s", weight=ft.FontWeight.W_600)
    progress = ft.ProgressBar(value=0)
    pause_btn = ft.OutlinedButton("Pause", icon=ft.Icons.PAUSE, disabled=True)

    state = {"running": False, "remaining": 5, "total": 5}

    def _update_ui():
        total = max(state["total"], 1)
        progress.value = 1 - (state["remaining"] / total)
        remaining_text.value = f"{state['remaining']} s" if not state["running"] else f"{state['remaining']} s remaining"
        pause_btn.disabled = not state["running"]

        page.update()
        if state["remaining"] <= 0:
            page.window.destroy()
            tm.start_tmloader_profile(launch_profile)

    def start_clicked(e):
        if state["remaining"] <= 0:
            return
        state["running"] = True
        _update_ui()

        def tick():
            while state["running"] and state["remaining"] > 0:
                import time
                time.sleep(1)
                state["remaining"] = max(0, state["remaining"] - 1)
                _update_ui()
            if state["remaining"] <= 0:
                state["running"] = False
                _update_ui()
                log("Countdown finished.", log_view)

        threading.Thread(target=tick, daemon=True).start()

    def pause_clicked(e):
        state["running"] = False
        _update_ui()

    start_clicked("")
    pause_btn.on_click = pause_clicked

    bottom_bar = ft.Container(
        content=ft.Column(
            [
                ft.Row([ft.Container(expand=True), remaining_text]),
                progress,
                ft.Row([pause_btn],
                       alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            ],
            spacing=10,
        ),
        padding=12,
        border=ft.border.all(1, ft.Colors.OUTLINE_VARIANT),
        border_radius=12,
        bgcolor=ft.Colors.SURFACE,
    )

    page.add(ft.Column([main_row, bottom_bar, ft.Container(expand=True), ft.Text("Made with ❤️ by AroPix")], spacing=16, expand=True))
    _update_ui()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="TrackMania helper")
    parser.add_argument(
        "--install",
        metavar="PATH",
        help="Install the modloader and exit",
    )
    parser.add_argument(
        "--script",
        action="store_true",
        help="Test things",
    )
    args = parser.parse_args()

    if args.install:
        tm = TrackMania(pfx=args.install)
        tm.install_modloader()
    elif args.script:
        print("!!!!")
    else:
        tm = TrackMania()
        ft.app(target=main)
