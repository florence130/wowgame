"""Python port of the Funplay Godot MCP stdio bridge (original: stdio-wrapper/bin/funplay-godot-mcp.js, MIT).

Claude Desktop / Cowork only launch stdio MCP servers and this machine has no Node.js, so this forwards each
JSON-RPC line from stdin to the Funplay addon's local HTTP endpoint and writes the reply to stdout.

Token: taken from FUNPLAY_GODOT_MCP_TOKEN, else read on every request from the addon's settings file
(user://funplay_mcp_settings.cfg of the project, i.e. %APPDATA%\\Godot\\app_userdata\\<project>\\funplay_mcp_settings.cfg),
so regenerating the token in the editor dock needs no config change.
Endpoint: FUNPLAY_GODOT_MCP_URL, default http://127.0.0.1:8765/ (also tries the port saved in the settings file).
"""
import glob
import json
import os
import re
import sys
import urllib.error
import urllib.request

DEFAULT_URL = "http://127.0.0.1:8765/"
PROJECT_NAME = "以太纪元 Aetherlands"


def _settings_text():
    base = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata")
    cands = [os.path.join(base, PROJECT_NAME, "funplay_mcp_settings.cfg")] + glob.glob(os.path.join(base, "*", "funplay_mcp_settings.cfg"))
    for c in cands:
        if os.path.exists(c):
            with open(c, encoding="utf-8", errors="replace") as fh:
                return fh.read()
    return ""


def _cfg_value(text, key):
    m = re.search(r'^\s*%s\s*=\s*"?([^"\r\n]*)"?' % re.escape(key), text, re.M)
    return m.group(1).strip() if m else ""


def _endpoint_and_token():
    text = _settings_text()
    token = os.environ.get("FUNPLAY_GODOT_MCP_TOKEN", "").strip() or _cfg_value(text, "server_auth_token") or _cfg_value(text, "auth_token")
    url = os.environ.get("FUNPLAY_GODOT_MCP_URL", "").strip()
    if not url:
        port = _cfg_value(text, "server_port") or _cfg_value(text, "port")
        url = "http://127.0.0.1:%s/" % port if port.isdigit() else DEFAULT_URL
    return url, token


def _err(msg, code, text):
    if isinstance(msg, dict) and "id" in msg:
        return {"jsonrpc": "2.0", "id": msg["id"], "error": {"code": code, "message": text}}
    sys.stderr.write("[funplay-bridge] %s\n" % text)
    return None


def forward(msg):
    url, token = _endpoint_and_token()
    headers = {"accept": "application/json", "content-type": "application/json"}
    if token:
        headers["x-funplay-mcp-token"] = token
    req = urllib.request.Request(url, data=json.dumps(msg).encode("utf-8"), headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            if r.status == 204:
                return None
            body = r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")
        if not body.strip():
            return _err(msg, -32603, "Godot MCP returned HTTP %d with an empty body" % e.code)
    except Exception as e:  # noqa: BLE001
        return _err(msg, -32000, "Failed to reach Godot MCP at %s (is the Godot editor open with the Funplay MCP plugin enabled?): %s" % (url, e))
    if not body.strip():
        return None
    try:
        return json.loads(body)
    except ValueError:
        return _err(msg, -32603, "Godot MCP returned invalid JSON")


def main():
    stdin = sys.stdin.buffer
    out = sys.stdout
    for raw in stdin:
        line = raw.decode("utf-8-sig", "replace").strip().lstrip("\ufeff")
        if not line:
            continue
        try:
            msg = json.loads(line)
        except ValueError:
            out.write(json.dumps({"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Parse error"}}) + "\n")
            out.flush()
            continue
        if isinstance(msg, list):
            res = [r for r in (forward(m) for m in msg) if r is not None]
            if res:
                out.write(json.dumps(res, ensure_ascii=False) + "\n")
        else:
            r = forward(msg)
            if r is not None:
                out.write(json.dumps(r, ensure_ascii=False) + "\n")
        out.flush()


if __name__ == "__main__":
    main()
