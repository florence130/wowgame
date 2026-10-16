"""Wait for the actual GUI Godot executable; retain logs and bound test runs."""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ENGINE = Path('F:/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--log', required=True)
    parser.add_argument('--timeout', type=int, default=180)
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    arguments = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
    path = ROOT / args.log
    path.parent.mkdir(parents=True, exist_ok=True)
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startup.wShowWindow = subprocess.SW_HIDE
    with path.open('w', encoding='utf-8') as log:
        process = subprocess.Popen([str(ENGINE), '--path', str(ROOT), *arguments],
            stdout=log, stderr=subprocess.STDOUT, startupinfo=startup)
        print(f'Godot PID {process.pid}; log {path}', flush=True)
        try:
            code = process.wait(timeout=args.timeout)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            code = 124
    print(path.read_text(encoding='utf-8', errors='replace')[-10000:])
    raise SystemExit(code)

if __name__ == '__main__':
    main()
