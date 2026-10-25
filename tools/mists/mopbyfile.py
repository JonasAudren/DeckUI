import json, os, sys
SCR = sys.argv[1]
d = json.load(open(os.path.join(SCR, "mopscan.json")))
v = json.load(open(os.path.join(SCR, "mopverify.json")))
used = {(k, r["name"]): r["nuse"] for k, rows in v.items() for r in rows}
byfile = {}
for kind in ("api", "event", "enum", "global", "template", "cvar", "atlas"):
    for x in d[kind]:
        if x["mop"] is False:
            mark = "*" if used.get((kind, x["name"])) else ""
            for f in x["files"]:
                byfile.setdefault(f, {}).setdefault(kind, []).append(x["name"] + mark)
for f in sorted(byfile):
    print("##", f)
    for kind, names in byfile[f].items():
        print("  ", kind + ":", ", ".join(sorted(set(names))))
