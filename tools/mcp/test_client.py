# Smoke-test the wowgame Godot MCP server through a real MCP stdio client.
# Usage: python tools/mcp/test_client.py [tool] [json-args]
import asyncio, json, sys
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

PY = sys.executable
SERVER = r"E:\wowgame\tools\mcp\godot_mcp_server.py"


async def main():
    tool = sys.argv[1] if len(sys.argv) > 1 else ""
    args = json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}
    async with stdio_client(StdioServerParameters(command=PY, args=[SERVER])) as (r, w):
        async with ClientSession(r, w) as s:
            await s.initialize()
            tools = await s.list_tools()
            print("TOOLS:", ", ".join(t.name for t in tools.tools))
            if tool:
                res = await s.call_tool(tool, args)
                for c in res.content:
                    if c.type == "text":
                        print(c.text[-3000:])
                    else:
                        print("[%s %s, %d bytes b64]" % (c.type, getattr(c, "mimeType", ""), len(getattr(c, "data", ""))))


asyncio.run(main())
