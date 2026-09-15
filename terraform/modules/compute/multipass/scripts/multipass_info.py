#!/usr/bin/env python3

import json
import subprocess
import sys

query = json.load(sys.stdin)
name = query["name"]

try:
    result = subprocess.run(
        ["multipass", "info", name, "--format", "json"],
        check=True,
        capture_output=True,
        text=True,
    )

    payload = json.loads(result.stdout)

    instances = payload.get("info", {})
    instance = instances.get(name)

    if not instance:
        raise RuntimeError(f"Instance {name} not found")

    addresses = instance.get("ipv4", [])

    if not addresses:
        raise RuntimeError(f"Instance {name} has no IPv4 address")

    print(json.dumps({
        "host": addresses[0]
    }))

except Exception as exc:
    print(str(exc), file=sys.stderr)
    sys.exit(1)