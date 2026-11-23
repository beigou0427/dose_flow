import os, signal, socket, subprocess, threading, time

DUO_ID = "88781AD1-3938-4F19-8EBC-42C56651A14A"
subprocess.run(["xcrun", "simctl", "boot", DUO_ID], stderr=subprocess.DEVNULL)
subprocess.run(["open", "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app"])
time.sleep(2)

srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", 18765))
srv.listen(1)
srv.settimeout(240)

print("🚀 正在把真實 DoseFlow App 編譯並啟動到 iPhone Duo (7.6\" / 5.4\") 模擬器...")
proc = subprocess.Popen(
    ["flutter", "run", "-d", DUO_ID, "-t", "tool/capture_app_screens.dart"],
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
        if any(k in t for k in ["Launching", "Running Xcode", "Xcode build", "Syncing", "Error", "error:", "Failed"]):
            print("  [Flutter]", t)

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
            inner_path = f"tool/screenshots/raw_inner_{name}.png"
            outer_path = f"tool/screenshots/raw_outer_{name}.png"
            subprocess.run(["xcrun", "simctl", "io", DUO_ID, "screenshot", "--display=3", inner_path], check=True)
            subprocess.run(["xcrun", "simctl", "io", DUO_ID, "screenshot", "--display=1", outer_path], check=True)
            in_kb = os.path.getsize(inner_path) // 1024
            out_kb = os.path.getsize(outer_path) // 1024
            print(f"  🟢 擷取完成 {name}: 內屏(2007x2853)={in_kb}KB | 外屏(1398x2034)={out_kb}KB")
            conn.sendall(b"OK\n")
        elif msg == "DONE":
            print("🟢 iPhone Duo 雙屏真實 UI 畫面全部擷取完成！")
            break
    conn.close()
finally:
    srv.close()
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
    except Exception:
        pass
