import threading
import flet as ft
import argparse
from trackmania import TrackMania


OPTIONS = ["Alpha2", "Beta", "Gamma", "Delta", "Epsilon"]


def log(line: str, log_view: ft.Text):
    log_view.value += ("" if log_view.value.endswith("\n") or log_view.value == "" else "\n") + line
    if len(log_view.value) > 10_000:
        log_view.value = log_view.value[-10_000:]  # truncate
    log_view.update()


def main(page: ft.Page):
    page.title = "TrackMania Toolkit"
    page.theme_mode = "dark"
    page.padding = 16
    page.horizontal_alignment = "stretch"


    selected_label = ft.Text(f"Selected: {OPTIONS[0]}", weight=ft.FontWeight.W_600)

    def on_radio_change(e: ft.ControlEvent):
        selected_label.value = f"Selected: {radio_group.value}"
        page.update()

    radio_group = ft.RadioGroup(
        value=OPTIONS[0],
        content=ft.Column([ft.Radio(value=o, label=o) for o in OPTIONS], tight=True, spacing=6),
        on_change=on_radio_change,
    )
    left_panel = ft.Container(
        ft.Column([ft.Text("Select one", weight=ft.FontWeight.BOLD), radio_group, selected_label], spacing=10),
        padding=12, border_radius=12, bgcolor=ft.Colors.SURFACE, expand=True
    )

    log_view = ft.Text("", selectable=True, size=12)
    log_card = ft.Container(
        ft.Column([ft.Text("Log", weight=ft.FontWeight.BOLD), log_view], spacing=8),
        padding=12, border_radius=12, bgcolor=ft.Colors.SURFACE, expand=True
    )

    actions_col = ft.Column(
        controls=[
            ft.ElevatedButton("Install UVME", icon=ft.Icons.DOWNLOAD,
                              on_click=lambda e: tm.download_uvme()),
            ft.ElevatedButton("Start TrackMania", icon=ft.Icons.BUILD, on_click=lambda e: tm.start_trackmania()),
            ft.ElevatedButton("Start Launcher", icon=ft.Icons.REFRESH, on_click=lambda e: tm.start_launcher()),
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
            tm.start_launcher()

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

    page.add(ft.Column([main_row, bottom_bar], spacing=16, expand=True))
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
