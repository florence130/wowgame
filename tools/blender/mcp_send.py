# Send a Blender Python file to the running Blender (MCP for Blender add-on, localhost:9876) and print the result.
# Usage: py tools/blender/mcp_send.py <script.py>
import socket, json, sys

code = open(sys.argv[1], encoding="utf-8").read()
s = socket.create_connection(("localhost", 9876), timeout=300)
s.sendall(json.dumps({"type": "execute_code", "params": {"code": code}}).encode("utf-8"))
buf = b""
while True:
    chunk = s.recv(65536)
    if not chunk:
        break
    buf += chunk
    try:
        r = json.loads(buf.decode("utf-8"))
        break
    except ValueError:
        continue
res = r.get("result", r)
print(res.get("result", res) if isinstance(res, dict) else res)
