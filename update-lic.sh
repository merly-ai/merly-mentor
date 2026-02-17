git filter-repo --force --file-info-callback "$(cat <<'PY'
import atexit, sys, os

START_LINE = b"// a written agreement between you and Merly."
END_LINE   = b"// The above copyright notice and this permission notice shall be included in"

ALLOWED_EXTS = {b".h", b".hpp", b".hh", b".hxx",
                b".c", b".cc", b".cpp", b".cxx",
                b".m", b".mm"}

g = globals()
if "_merly_inited" not in g:
    g["_merly_inited"] = True
    g["_merly_stats"] = {}  # filename(str) -> {"blocks":int,"lines":int}
    atexit.register(lambda: (
        (lambda stats: (
            None if not stats else
            print(
                "[filter-repo] Summary: modified %d file(s), removed %d block(s), removed %d line(s)."
                % (len(stats),
                   sum(v["blocks"] for v in stats.values()),
                   sum(v["lines"] for v in stats.values())),
                file=sys.stderr
            )
        ))(g.get("_merly_stats", {}))
    ))

def _nl(data: bytes) -> bytes:
    return b"\r\n" if b"\r\n" in data else b"\n"

# ---- callback body: filename, mode, blob_id are in scope ----
_, ext = os.path.splitext(filename)
if ext.lower() not in ALLOWED_EXTS:
    return (filename, mode, blob_id)

data = value.get_contents_by_identifier(blob_id)
if START_LINE not in data or END_LINE not in data:
    return (filename, mode, blob_id)

nl = _nl(data)
lines = data.splitlines(keepends=True)

out = []
i = 0
blocks = 0
removed_lines = 0
changed = False

while i < len(lines):
    if START_LINE in lines[i]:
        out.append(lines[i])   # keep START line
        i += 1
        start_skip = i

        # skip until END line
        while i < len(lines) and END_LINE not in lines[i]:
            i += 1

        if i >= len(lines):
            # no END after START; restore remainder
            out.extend(lines[start_skip:])
            break

        removed_lines += (i - start_skip)
        blocks += 1
        changed = True

        out.append(b"//" + nl)  # exactly one blank comment line
        out.append(lines[i])    # keep END line
        i += 1
        continue

    out.append(lines[i])
    i += 1

if not changed:
    return (filename, mode, blob_id)

new_data = b"".join(out)
new_blob_id = value.insert_file_with_contents(new_data)

path = filename.decode("utf-8", "replace") if isinstance(filename, (bytes, bytearray)) else str(filename)
st = g["_merly_stats"].get(path, {"blocks": 0, "lines": 0})
st["blocks"] += blocks
st["lines"] += removed_lines
g["_merly_stats"][path] = st

print(f"[filter-repo] {path}: removed {blocks} block(s), {removed_lines} line(s).", file=sys.stderr)
return (filename, mode, new_blob_id)
PY
)"
