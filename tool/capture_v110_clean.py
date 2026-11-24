import os, signal, socket, subprocess, sys, threading, time

def capture_device(udid: str, prefix: str):
    print(f"\n📱 Booting {prefix} ({udid})...")
    subprocess.run(["xcrun", "simctl", "boot", udid], stderr=subprocess.DEVNULL)
    time.sleep(3)

    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 18765))
    srv.listen(1)
    srv.settimeout(180)

    proc = subprocess.Popen(
        ["flutter", "run", "-d", udid, "-t", "tool/capture_app_screens.dart"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )

    def pump_logs():
        if proc.stdout is None:
            return
        for line in proc.stdout:
            t = line.strip()
            if any(k in t for k in ["Launching", "Xcode build", "Error", "error:", "Failed"]):
                print(f"  [{prefix}] {t}")

    threading.Thread(target=pump_logs, daemon=True).start()

    try:
        conn, _ = srv.accept()
        conn.settimeout(30)
        f = conn.makefile("r")
        while True:
            line = f.readline()
            if not line:
                break
            msg = line.strip()
            if msg.startswith("SNAP:"):
                name = msg.split(":", 1)[1]
                out_path = f"tool/screenshots/v110_{prefix}_{name}.png"
                subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", out_path], check=True)
                kb = os.path.getsize(out_path) // 1024
                print(f"  🟢 Captured {out_path} ({kb}KB)")
                conn.sendall(b"OK\n")
            elif msg == "DONE":
                print(f"🟢 {prefix} capture complete!")
                break
        conn.close()
    finally:
        srv.close()
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except Exception:
            pass
        time.sleep(1)

if __name__ == "__main__":
    os.makedirs("tool/screenshots", exist_ok=True)
    capture_device("E58EB368-F417-463F-8348-10B0A4D93EF9", "iphone")
    capture_device("D5D9146B-1BE1-4803-960D-4DFF67335255", "ipad")
