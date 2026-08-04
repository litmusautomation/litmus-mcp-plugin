---
description: List Docker containers running on the Litmus Edge instance.
---

Call `get_all_containers_on_litmusedge`. Present as a markdown table: Name, Image, State, Status, Ports.

Records come back in raw Docker shape with capitalised keys: `Names` (a list, so take the first and strip the leading slash), `Image`, `ImageID`, `State`, `Status`, `Ports`, `Command`, `Created`, `Labels`, `Mounts`, `NetworkSettings`, `HostConfig`.

Verified against a live Edge: there is **no CPU or memory usage field**, so do not promise resource usage. `State` is the machine-readable value (`running`, `exited`); `Status` is the human string (`Up 3 hours`). Image names are often long registry paths, so truncate them in the table rather than letting one column dominate.

These containers run on the **Edge device**, not on the machine hosting this MCP server. A container missing here is missing on the Edge.

After the table, one line with how many are running versus stopped or exited.

If the user asks to deploy something, that is `run_docker_container_on_litmusedge`, which takes a complete `docker run` command. Confirm the image and command with the user before calling it: it executes on the Edge, and an untrusted image or a bad port mapping there is not a local mistake.

No prose beyond the table and the count line.
