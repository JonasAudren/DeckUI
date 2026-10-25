"""Dump documented functions (Namespace.Func / Func), events and enums of a client's docs."""
import os, re, sys
root, out = sys.argv[1], sys.argv[2]
d = os.path.join(root, "Interface", "AddOns", "Blizzard_APIDocumentationGenerated")
lines = []
for f in sorted(os.listdir(d)):
    if not f.endswith(".lua"):
        continue
    src = open(os.path.join(d, f), encoding="utf-8", errors="ignore").read()
    ns = re.search(r'\n\tNamespace = "([^"]+)"', src)
    ns = ns.group(1) if ns else None
    typ = re.search(r'\n\tType = "([^"]+)"', src)
    typ = typ.group(1) if typ else ""
    for m in re.finditer(r'\{\s*Name = "([^"]+)",\s*Type = "Function"', src):
        prefix = ns + "." if ns else ("method " if typ == "ScriptObject" else "")
        lines.append("fn " + prefix + m.group(1))
    for m in re.finditer(r'LiteralName = "([^"]+)"', src):
        lines.append("event " + m.group(1))
    for m in re.finditer(r'Name = "([^"]+)",\s*Type = "Enumeration"', src):
        lines.append("enum " + m.group(1))
open(out, "w").write("\n".join(sorted(set(lines))))
print(len(lines), "entries ->", out)
