"""Read DeckUIProbeDB from a client's SavedVariables and say, per DeckUI file, what is missing.

python -I readprobe.py <scratch> [<WTF dir>]   (default: C:/Spiele/World of Warcraft/_classic_/WTF)
Writes <scratch>/probe_result.json and prints the report.
"""
import glob, json, os, re, sys
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
SCR = sys.argv[1]
WTF = sys.argv[2] if len(sys.argv) > 2 else "C:/Spiele/World of Warcraft/_classic_/WTF"
files = glob.glob(os.path.join(WTF, "Account", "*", "SavedVariables", "DeckUI_Probe.lua"))
if not files:
    sys.exit("no DeckUI_Probe.lua under " + WTF)
src = open(max(files, key=os.path.getmtime), encoding="utf-8", errors="ignore").read()

# the saved file is nested tables of ["key"] = "value"; read section by section
def section(name):
    m = re.search(r'\["' + name + r'"\] = \{(.*?)\n\t\},', src, re.S)
    if not m:
        return {}
    return dict(re.findall(r'\["([^"]+)"\] = "?([^"\n]*?)"?,\n', m.group(1) + "\n"))

res = {k: section(k) for k in ("meta", "errors", "api", "globals", "events", "enums", "cvars", "atlases",
                               "templates", "methods", "bindings", "values", "cnamespaces")}
json.dump(res, open(os.path.join(SCR, "probe_result.json"), "w"), indent=1)
print("client:", res["meta"].get("version"), "build", res["meta"].get("build"), "interface", res["meta"].get("interface"),
      "project", res["meta"].get("project"))

missing = {
    "api": {n for n, v in res["api"].items() if v != "function"},
    "global": {n for n, v in res["globals"].items() if v == "nil"},
    "event": {n for n, v in res["events"].items() if v != "ok"},
    "enum": {n for n, v in res["enums"].items() if v == "nil"},
    "cvar": {n for n, v in res["cvars"].items() if v == "nil"},
    "atlas": {n for n, v in res["atlases"].items() if v == "nil"},
    "template": {n for n, v in res["templates"].items() if v == "nil"},
}
scan = json.load(open(os.path.join(SCR, "mopscan.json")))
byfile = {}
for kind, rows in scan.items():
    for x in rows:
        if x["name"] in missing.get(kind, ()):
            for f in x["files"]:
                byfile.setdefault(f, []).append(kind + " " + x["name"])
for f in sorted(byfile):
    print("##", f)
    print("   " + ", ".join(sorted(byfile[f])))
print("\nmethods missing:", ", ".join(sorted(n for n, v in res["methods"].items() if v == "nil")))
print("bindings missing:", ", ".join(sorted(n for n, v in res["bindings"].items() if v == "nil")))
print("cvars missing:", ", ".join(sorted(missing["cvar"])))
print("\nprobe errors:", res["errors"] or "none")
print("\nvalues:")
for k, v in sorted(res["values"].items()):
    print("  ", k, "=", v)
