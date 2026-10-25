import json, os, sys
SCR = sys.argv[1]
kind = sys.argv[2]
d = json.load(open(os.path.join(SCR, "mopscan.json")))
codefile = os.path.join(SCR, "mopcode.txt")
if not os.path.exists(codefile):
    parts = []
    for l in open(os.path.join(SCR, "mop", "Interface", "ui-code-list.txt")):
        l = l.strip().replace("\\", "/")
        if not l or "APIDocumentationGenerated" in l:
            continue
        p = os.path.join(SCR, "mop", l)
        if os.path.exists(p):
            parts.append(open(p, encoding="utf-8", errors="ignore").read())
    open(codefile, "w", encoding="utf-8").write("\n".join(parts))
mopcode = open(codefile, encoding="utf-8").read()

def mods(files):
    out = set()
    for f in files:
        top = f.split("/")[0]
        out.add(top + ("(lib)" if "/libs/" in f else ""))
    return sorted(out)

for x in d[kind]:
    if x["mop"] is False:
        tag = "MOPCODE " if x["name"] in mopcode else ""
        print(tag + x["name"], "|", ", ".join(mods(x["files"])), "|", " ".join(f.split("/", 1)[-1] for f in x["files"])[:160])
