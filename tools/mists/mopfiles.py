"""Work out which Blizzard files the MoP Classic 5.5.4 client really loads.

Per AddOn folder the client picks one toc: <Name>_Mists.toc, else <Name>_Classic.toc, else
<Name>.toc (never _Mainline, _Vanilla, _TBC, _Wrath, _Cata). A toc whose header says
AllowLoadGameType must name classic or mists. Each line may carry [AllowLoadGameType a, b];
the line counts when "mists" or "classic" is among them. [Game] / [Family] in a path are tried
as Mists, then Cata, Wrath, TBC, Vanilla, Classic. XML files are followed through their
<Include file="..."/> and <Script file="..."/>.
Writes <scratch>/mop_effective.txt (one path per line, relative to Interface/AddOns)."""
import os, re, sys
SCR = sys.argv[1]
ADD = os.path.join(SCR, "mop", "Interface", "AddOns")
GAMES = ["Mists", "Cata", "Wrath", "TBC", "Vanilla", "Classic"]

def allowed(spec):
    names = [x.strip().lower() for x in spec.split(",")]
    return "mists" in names or "classic" in names

def pick_toc(folder):
    name = os.path.basename(folder)
    for suffix in ("_Mists", "_Classic", ""):
        p = os.path.join(folder, name + suffix + ".toc")
        if os.path.exists(p):
            return p
    return None

effective = []
seen = set()

def add_file(path):
    path = os.path.normpath(path)
    if path in seen or not os.path.exists(path):
        return
    seen.add(path)
    effective.append(path)
    if path.endswith(".xml"):
        src = open(path, encoding="utf-8", errors="ignore").read()
        for m in re.finditer(r'<(?:Include|Script)\s+file="([^"]+)"', src):
            add_file(os.path.join(os.path.dirname(path), m.group(1).replace("\\", os.sep)))

def resolve(folder, rel):
    rel = rel.replace("\\", os.sep)
    if "[Game]" in rel or "[Family]" in rel:
        for g in GAMES:
            p = os.path.join(folder, rel.replace("[Game]", g).replace("[Family]", g))
            if os.path.exists(p):
                return p
        return None
    return os.path.join(folder, rel)

skipped = []
for name in sorted(os.listdir(ADD)):
    folder = os.path.join(ADD, name)
    if not os.path.isdir(folder):
        continue
    toc = pick_toc(folder)
    if not toc:
        skipped.append(name)
        continue
    lines = open(toc, encoding="utf-8", errors="ignore").read().splitlines()
    header = "\n".join(l for l in lines if l.startswith("##"))
    m = re.search(r"## AllowLoadGameType:\s*(.+)", header)
    if m and not allowed(m.group(1)):
        skipped.append(name)
        continue
    for l in lines:
        l = l.strip()
        if not l or l.startswith("#"):
            continue
        cond = re.search(r"\[AllowLoadGameType ([^\]]+)\]", l)
        if cond and not allowed(cond.group(1)):
            continue
        rel = re.sub(r"\s*\[AllowLoad[^\]]*\]", "", l).strip()
        p = resolve(folder, rel)
        if p:
            add_file(p)

with open(os.path.join(SCR, "mop_effective.txt"), "w") as f:
    for p in effective:
        f.write(os.path.relpath(p, ADD).replace(os.sep, "/") + "\n")
print(len(effective), "files loaded by MoP;", len(skipped), "folders without a MoP toc:", ", ".join(skipped[:40]))
