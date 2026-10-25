"""For every name the scan marked missing in MoP, look for real (non-comment) uses in the
MoP client's own Lua, and say in which file. Output: mopverify.json + a readable table."""
import json, os, re, sys
SCR = sys.argv[1]
d = json.load(open(os.path.join(SCR, "mopscan.json")))
files = []
for l in open(os.path.join(SCR, "mop", "Interface", "ui-effective-list.txt")):
    l = l.strip().replace("\\", "/")
    if l.endswith(".lua") and "APIDocumentationGenerated" not in l:
        p = os.path.join(SCR, "mop", l)
        if os.path.exists(p):
            files.append((l, open(p, encoding="utf-8", errors="ignore").read()))
clean = []
for name, src in files:
    src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
    src = re.sub(r"--[^\n]*", "", src)
    clean.append((name, src))

def uses(token):
    hits = []
    pat = re.compile(r"(?<![\w.])" + re.escape(token) + r"(?![\w])")
    for name, src in clean:
        if pat.search(src):
            hits.append(name.replace("Interface/AddOns/", ""))
    return hits

result = {}
for kind in ("api", "global", "event", "enum", "template"):
    result[kind] = []
    for x in d[kind]:
        if x["mop"] is False:
            h = uses(x["name"]) if kind != "event" else uses('"' + x["name"] + '"') if False else [n for n, s in clean if '"' + x["name"] + '"' in s]
            result[kind].append({"name": x["name"], "mopuse": h[:3], "nuse": len(h), "files": x["files"]})
json.dump(result, open(os.path.join(SCR, "mopverify.json"), "w"), indent=1)
for kind, rows in result.items():
    yes = [r for r in rows if r["nuse"]]
    print(f"== {kind}: {len(rows)} not in MoP docs/defs, {len(yes)} of them used by MoP code")
    for r in yes:
        print("   USED", r["name"], "<-", r["mopuse"][:2])
