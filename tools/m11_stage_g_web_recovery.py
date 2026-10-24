"""Lose and restore WebGL in a live exported game, then verify the recovery action."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import threading

from PIL import Image, ImageStat
from playwright.sync_api import sync_playwright


BUILD = Path("build/stage_g/web").resolve()
OUT = Path("build/stage_g/recovery").resolve()


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_args):
        pass


def main() -> int:
    if not (BUILD / "index.html").is_file():
        raise SystemExit(f"missing Web export: {BUILD / 'index.html'}")
    OUT.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer(("127.0.0.1", 0), partial(QuietHandler, directory=str(BUILD)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    url = f"http://127.0.0.1:{server.server_port}/index.html?smoke=m11-immersive"
    result = {
        "build": str(BUILD), "profile": "phone_portrait", "viewport": [390, 844],
        "qualification": "Actual release Web export in Chromium software WebGL with the opt-in game probe. This tests the shell notice and reload continuity; it does not certify phone hardware.",
    }
    try:
        with sync_playwright() as playwright:
            chromium_path = os.environ.get("M11_CHROMIUM_PATH", "/usr/bin/chromium")
            browser = playwright.chromium.launch(
                executable_path=chromium_path if Path(chromium_path).is_file() else None,
                args=["--no-sandbox", "--disable-dev-shm-usage", "--use-angle=swiftshader",
                      "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"],
            )
            context = browser.new_context(viewport={"width": 390, "height": 844}, device_scale_factor=1, is_mobile=True, has_touch=True)
            page = context.new_page()
            errors_before = []
            errors_after = []
            page.on("pageerror", lambda error: errors_after.append(str(error)))
            page.on("console", lambda message: errors_after.append(message.text) if message.type == "error" else None)
            page.goto(url, wait_until="load", timeout=180000)
            page.wait_for_function("window.__m11StageF?.phase === 'ready'", timeout=240000)
            page.wait_for_function("document.getElementById('status') === null", timeout=60000)

            def data():
                return page.evaluate("window.__m11StageF")

            def action(value: str):
                before = data()["serial"]
                page.evaluate("value => { window.__m11StageFAction = value; }", value)
                page.wait_for_function(f"window.__m11StageF?.serial > {before}", timeout=15000)

            action("system")
            page.wait_for_function("window.__m11StageF?.space?.ids?.length > 5", timeout=120000)
            action("reveal:WorldMount")
            page.wait_for_function("window.__m11StageF?.space?.ids?.length > 5 && window.__m11StageF?.wall_frames_ms?.length > 8", timeout=30000)
            page.wait_for_timeout(1500)
            before = data()
            if before["view"] != "system" or len(before["space"]["ids"]) < 6:
                raise AssertionError(f"live System view was not ready before context loss: {before.get('space')}")
            if before.get("scheduler", {}).get("suspended", False):
                raise AssertionError("generation scheduler was already suspended during healthy gameplay")
            if not before["wall_frames_ms"] or len(before["wall_frames_ms"]) < 8:
                raise AssertionError("live game process did not publish frame samples before context loss")
            if errors_after:
                errors_before.extend(errors_after)
                raise AssertionError(f"browser errors appeared before context loss: {errors_before}")
            (OUT / "healthy_live_system.png").parent.mkdir(parents=True, exist_ok=True)
            page.screenshot(path=str(OUT / "healthy_live_system.png"), timeout=30000)

            action("save")
            page.wait_for_function("window.__m11StageF?.error === '0'", timeout=15000)
            saved = data()
            events = page.evaluate("""() => {
                const canvas = document.getElementById('canvas');
                const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
                const extension = gl?.getExtension('WEBGL_lose_context');
                if (!extension) return {webgl: !!gl, extension: false};
                window.__m11StageGContext = {extension, lost: false, restored: false};
                canvas.addEventListener('webglcontextlost', () => { window.__m11StageGContext.lost = true; }, {once: true});
                canvas.addEventListener('webglcontextrestored', () => { window.__m11StageGContext.restored = true; }, {once: true});
                return {webgl: true, extension: true};
            }""")
            if not events.get("extension"):
                raise AssertionError(f"WEBGL_lose_context unavailable on the live game renderer: {events}")

            page.evaluate("""() => {
                const gl = document.getElementById('canvas').getContext('webgl2') || document.getElementById('canvas').getContext('webgl');
                gl.getExtension('WEBGL_lose_context').loseContext();
            }""")
            page.wait_for_function("window.__m11StageGContext?.lost === true", timeout=10000)
            page.wait_for_function(
                "window.__m11StageF?.scheduler?.suspended === true && "
                "window.__m11StageF?.scheduler?.pending === 0 && "
                "window.__m11StageF?.scheduler?.retiring === 0 && "
                "window.__m11StageF?.scheduler?.processing === false",
                timeout=30000,
            )
            lost_state = data()
            if lost_state.get("state_hash") != saved.get("state_hash"):
                raise AssertionError("context loss changed the simulation state hash before reload")
            page.wait_for_function(
                "!document.querySelector('#webgl-recovery-notice').hidden && "
                "document.activeElement?.textContent === 'Reload page'",
                timeout=10000,
            )
            notice = page.locator("#webgl-recovery-notice")
            message = page.locator("#webgl-recovery-notice span")
            reload = page.get_by_role("button", name="Reload the game to recover from a graphics failure")
            box = notice.bounding_box()
            button_box = reload.bounding_box()
            text = message.inner_text()
            if "latest autosave" not in text or "Unsaved orders may be lost" not in text:
                raise AssertionError(f"recovery guidance is incomplete: {text!r}")
            if box is None or box["x"] < 0 or box["x"] + box["width"] > 390 + 1:
                raise AssertionError(f"phone notice overflows the viewport: {box}")
            if button_box is None or button_box["height"] < 48 or button_box["x"] < 0 or button_box["x"] + button_box["width"] > 390 + 1:
                raise AssertionError(f"reload control is not reachable / touch sized: {button_box}")
            page.screenshot(path=str(OUT / "phone_context_lost_notice.png"), timeout=30000)
            notice_visible_after_loss = not page.evaluate("document.querySelector('#webgl-recovery-notice').hidden")
            canvas_blocked_after_loss = page.evaluate("""() => {
                const canvas = document.getElementById('canvas');
                return canvas.inert && getComputedStyle(canvas).pointerEvents === 'none' && document.activeElement !== canvas;
            }""")
            if not canvas_blocked_after_loss:
                raise AssertionError("lost renderer still accepts canvas input")

            samples_immediately_before_restore = data()["wall_frames_ms"][-5:]
            page.evaluate("window.__m11StageGContext.extension.restoreContext()")
            try:
                page.wait_for_function("window.__m11StageGContext?.restored === true", timeout=6000)
                context_restored_event = True
            except Exception:
                context_restored_event = False
            restored_ticks = False
            if context_restored_event:
                try:
                    page.wait_for_function(
                        "old => JSON.stringify(window.__m11StageF?.wall_frames_ms?.slice(-5)) !== JSON.stringify(old)",
                        arg=samples_immediately_before_restore, timeout=6000,
                    )
                    restored_ticks = True
                except Exception:
                    pass
            page.wait_for_function(
                "window.__m11StageF?.scheduler?.suspended === true && "
                "window.__m11StageF?.scheduler?.pending === 0 && "
                "window.__m11StageF?.scheduler?.retiring === 0 && "
                "window.__m11StageF?.scheduler?.processing === false",
                timeout=10000,
            )
            restored = data()
            restore_state = page.evaluate("""() => {
                const canvas = document.getElementById('canvas');
                const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
                return {context_lost: gl?.isContextLost() ?? true, notice_visible: !document.querySelector('#webgl-recovery-notice').hidden};
            }""")
            page.screenshot(path=str(OUT / "phone_context_restored_notice.png"), timeout=30000)
            system_rect = before["space"]["rect"]
            def map_pixel_deviation(path: Path) -> list[float]:
                image = Image.open(path).convert("RGB")
                crop = image.crop((
                    int(system_rect["x"]) + 4,
                    int(system_rect["y"]) + 4,
                    int(system_rect["x"] + system_rect["width"]) - 4,
                    int(system_rect["y"] + system_rect["height"]) - 4,
                ))
                return [round(v, 3) for v in ImageStat.Stat(crop).stddev]
            healthy_deviation = map_pixel_deviation(OUT / "healthy_live_system.png")
            restored_deviation = map_pixel_deviation(OUT / "phone_context_restored_notice.png")
            scene_pixels_rendered = max(restored_deviation, default=0.0) > 8.0

            # The probe saves to an isolated manual slot before failure. Clicking the shipped
            # reload action must restart the exported game and restore that same checked save.
            reload.click(timeout=15000)
            page.wait_for_function("window.__m11StageF?.phase === 'ready'", timeout=240000)
            page.wait_for_function("document.getElementById('status') === null", timeout=60000)
            action("system")
            page.wait_for_function("window.__m11StageF?.view === 'system' && window.__m11StageF?.space?.ids?.length > 5", timeout=120000)
            reopened = data()
            for key in ["state_hash", "graphics_hash", "anchor", "prepared"]:
                if reopened[key] != saved[key]:
                    raise AssertionError(f"reload did not retain {key}: saved={saved[key]!r}, reopened={reopened[key]!r}")
            if errors_before:
                raise AssertionError(f"unexpected pre-loss browser errors: {errors_before}")
            page.screenshot(path=str(OUT / "phone_reloaded_saved_system.png"), timeout=30000)
            result.update({
                "healthy_game_before_loss": True,
                "healthy_view": "System with six or more permitted bodies and live frame samples",
                "errors_before_loss": errors_before,
                "context_loss_event": True,
                "notice_hidden_before_loss": True,
                "notice_visible_after_loss": notice_visible_after_loss,
                "canvas_input_blocked_after_loss": canvas_blocked_after_loss,
                "generation_suspended_after_loss": bool(lost_state["scheduler"].get("suspended")),
                "generation_jobs_drained_after_loss": int(lost_state["scheduler"].get("pending", -1)) == 0 and int(lost_state["scheduler"].get("retiring", -1)) == 0,
                "generation_remains_suspended_after_restore": bool(restored["scheduler"].get("suspended")) and int(restored["scheduler"].get("pending", -1)) == 0 and int(restored["scheduler"].get("retiring", -1)) == 0 and not bool(restored["scheduler"].get("processing")),
                "simulation_hash_unchanged_before_reload": lost_state.get("state_hash") == saved.get("state_hash"),
                "reload_button_height": button_box["height"],
                "notice_bounds": box,
                "notice_text": text,
                "context_restored_event": context_restored_event,
                "frame_samples_advanced_after_restore_event": restored_ticks,
                "webgl_context_lost_after_restore": restore_state["context_lost"],
                "rendered_scene_pixel_stddev_rgb": restored_deviation,
                "healthy_scene_pixel_stddev_rgb": healthy_deviation,
                "scene_pixels_rendered_after_restore": scene_pixels_rendered,
                "engine_context_restoration_verified": bool(context_restored_event and restored_ticks and not restore_state["context_lost"] and scene_pixels_rendered and not errors_after),
                "saved": {key: saved[key] for key in ["state_hash", "graphics_hash", "anchor", "prepared"]},
                "reloaded": {key: reopened[key] for key in ["state_hash", "graphics_hash", "anchor", "prepared"]},
                "reload_action_restored_saved_state": True,
                "browser_errors_after_loss": errors_after,
                "screenshots": ["healthy_live_system.png", "phone_context_lost_notice.png", "phone_context_restored_notice.png", "phone_reloaded_saved_system.png"],
            })
            browser.close()
    finally:
        server.shutdown()
    (OUT / "verification.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({"context_loss": result.get("context_loss_event"), "restore_event": result.get("context_restored_event"), "engine_restored": result.get("engine_context_restoration_verified"), "reload_saved_state": result.get("reload_action_restored_saved_state")}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
