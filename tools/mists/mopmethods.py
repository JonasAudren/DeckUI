"""Widget methods (:Method( calls) DeckUI uses, checked against the Simple*API documentation of
retail and MoP. A method retail documents and MoP does not is a candidate for trouble."""
import json, os, re, sys
SCR, REPO = sys.argv[1], sys.argv[2]

def methods(root):
    out = set()
    d = os.path.join(root, "Interface", "AddOns", "Blizzard_APIDocumentationGenerated")
    for f in os.listdir(d):
        if not f.endswith(".lua"):
            continue
        src = open(os.path.join(d, f), encoding="utf-8", errors="ignore").read()
        if 'Type = "ScriptObject"' not in src and "API" not in f and "FrameAPI" not in f:
            continue
        for m in re.finditer(r'\{\s*Name = "([^"]+)",\s*Type = "Function"', src):
            out.add(m.group(1))
    return out

R = methods(os.path.join(SCR, "new"))
M = methods(os.path.join(SCR, "mop"))
mopcode = open(os.path.join(SCR, "mopcode.txt"), encoding="utf-8").read()

used = {}
for d, _, fs in os.walk(REPO):
    if ".git" in d:
        continue
    for f in fs:
        if f.endswith(".lua"):
            p = os.path.join(d, f)
            src = open(p, encoding="utf-8", errors="ignore").read()
            src = re.sub(r"--\[\[.*?\]\]", "", src, flags=re.S)
            src = re.sub(r"--[^\n]*", "", src)
            rel = os.path.relpath(p, REPO).replace("\\", "/")
            for m in re.finditer(r":([A-Z][A-Za-z0-9_]+)\(", src):
                used.setdefault(m.group(1), set()).add(rel)

rows = []
for name, files in sorted(used.items()):
    if name in R and name not in M:
        inmop = (":" + name + "(") in mopcode
        rows.append((name, inmop, sorted(files)))
for name, inmop, files in rows:
    print(("MOPCODE " if inmop else "") + name, "|", " ".join(files)[:200])
print(len(rows), "methods retail documents and MoP does not")
