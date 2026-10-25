"""Compare what DeckUI uses from Blizzard against retail 12.1.5 and MoP Classic 5.5.4.

Usage: python -I mopscan.py <scratch dir> <repo dir>
Writes <scratch>/mopscan.json with, per kind (api, enum, event, global, template, cvar, atlas),
every name DeckUI uses, where, and whether retail / MoP know it.
"""
import json, os, re, sys

SCR, REPO = sys.argv[1], sys.argv[2]
RETAIL = os.path.join(SCR, "new", "Interface")
MOP = os.path.join(SCR, "mop", "Interface")

def read(p):
    with open(p, encoding="utf-8", errors="ignore") as f:
        return f.read()

# ------------------------------------------------------------------ Blizzard side
def doc_api(root):
    """functions (Namespace.Func or Func), events (LiteralName), enums (Enum.Name -> fields)"""
    funcs, events, enums = set(), set(), {}
    d = os.path.join(root, "AddOns", "Blizzard_APIDocumentationGenerated")
    for f in os.listdir(d):
        if not f.endswith(".lua"):
            continue
        src = read(os.path.join(d, f))
        ns = re.search(r'\n\tNamespace = "([^"]+)"', src)
        ns = ns.group(1) if ns else None
        for m in re.finditer(r'\{\s*Name = "([^"]+)",\s*Type = "Function"', src):
            funcs.add((ns + "." if ns else "") + m.group(1))
        for m in re.finditer(r'LiteralName = "([^"]+)"', src):
            events.add(m.group(1))
        for m in re.finditer(r'Name = "([^"]+)",\s*Type = "Enumeration",.*?Fields =\s*\{(.*?)\n\t\t\t\},', src, re.S):
            enums.setdefault(m.group(1), set()).update(re.findall(r'Name = "([^"]+)", Type = ', m.group(2)))
    return funcs, events, enums

def code_files(root, listfile=None):
    files = []
    if listfile and os.path.exists(listfile):
        for line in read(listfile).splitlines():
            line = line.strip().replace("\\", "/")
            if line.startswith("Interface/"):
                p = os.path.join(os.path.dirname(root), line)
                if os.path.exists(p):
                    files.append(p)
    else:
        for d, _, fs in os.walk(os.path.join(root, "AddOns")):
            for f in fs:
                if f.endswith((".lua", ".xml")):
                    files.append(os.path.join(d, f))
    return files

def corpus(files):
    tokens, defined, templates, strings = set(), set(), set(), set()
    for p in files:
        if "APIDocumentationGenerated" in p:
            continue
        s = read(p)
        tokens.update(re.findall(r"[A-Za-z_][A-Za-z0-9_]*", s))
        defined.update(re.findall(r"\bfunction\s+([A-Za-z_][A-Za-z0-9_.:]*)", s))
        defined.update(re.findall(r"^\s*([A-Z][A-Za-z0-9_]*)\s*=", s, re.M))
        defined.update(re.findall(r'name="([A-Za-z_][A-Za-z0-9_$]*)"', s))
        templates.update(re.findall(r'<\w+ [^>]*name="([A-Za-z0-9_]+)"[^>]*virtual="true"', s))
        strings.update(re.findall(r'"([A-Za-z0-9_\-]{3,})"', s))
    return tokens, defined, templates, strings

retail_files = code_files(RETAIL, os.path.join(RETAIL, "ui-code-list.txt"))
mop_files = code_files(MOP, os.path.join(MOP, "ui-effective-list.txt"))
R_funcs, R_events, R_enums = doc_api(RETAIL)
M_funcs, M_events, M_enums = doc_api(MOP)
R_tok, R_def, R_tpl, R_str = corpus(retail_files)
M_tok, M_def, M_tpl, M_str = corpus(mop_files)

# ------------------------------------------------------------------ DeckUI side
ours = []
for d, _, fs in os.walk(REPO):
    if "/.git" in d.replace("\\", "/") or "\\.git" in d:
        continue
    for f in fs:
        if f.endswith(".lua") or f.endswith(".xml"):
            ours.append(os.path.join(d, f))

def rel(p):
    return os.path.relpath(p, REPO).replace("\\", "/")

our_defined = set()
for p in ours:
    s = read(p)
    our_defined.update(re.findall(r"\bfunction\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", s))
    our_defined.update(re.findall(r"\blocal\s+([A-Za-z_][A-Za-z0-9_]*)", s))
    our_defined.update(re.findall(r"\blocal\s+function\s+([A-Za-z_][A-Za-z0-9_]*)", s))
    for m in re.finditer(r"\blocal\s+([A-Za-z_][A-Za-z0-9_, ]*)=", s):
        our_defined.update(x.strip() for x in m.group(1).split(","))
    our_defined.update(re.findall(r"^([A-Z][A-Za-z0-9_]*)\s*=", s, re.M))   # our own globals

LUA = set("""and break do else elseif end false for function goto if in local nil not or repeat return then true until while
self math string table pairs ipairs next select type tostring tonumber print error assert pcall xpcall unpack setmetatable
getmetatable rawget rawset rawequal require coroutine os io bit date time wipe tinsert tremove strsplit strjoin strtrim
format floor ceil min max abs random sqrt sin cos atan2 pi huge sort concat insert remove sub gsub match gmatch find len
upper lower rep byte char""".split())

found = {k: {} for k in ("api", "enum", "event", "global", "template", "cvar", "atlas", "texture")}
def add(kind, name, where):
    found[kind].setdefault(name, set()).add(where)

for p in ours:
    s = read(p)
    r = rel(p)
    lib = "/libs/" in r
    code = re.sub(r"--\[\[.*?\]\]", "", s, flags=re.S)
    code = re.sub(r"--[^\n]*", "", code)
    for m in re.finditer(r"\b(C_[A-Za-z]+)\.([A-Za-z0-9_]+)", code):
        add("api", m.group(1) + "." + m.group(2), r)
    for m in re.finditer(r"\bEnum\.([A-Za-z0-9_]+)(?:\.([A-Za-z0-9_]+))?", code):
        add("enum", m.group(1) + ("." + m.group(2) if m.group(2) else ""), r)
    for m in re.finditer(r'"([A-Z][A-Z0-9_]{3,})"', code):
        if m.group(1) in R_events or m.group(1) in M_events:
            add("event", m.group(1), r)
    for m in re.finditer(r'(?:GetCVar|GetCVarBool|SetCVar|GetCVarDefault|C_CVar\.\w+)\(\s*"([A-Za-z0-9_]+)"', code):
        add("cvar", m.group(1), r)
    for m in re.finditer(r'SetAtlas\(\s*"([^"]+)"', code):
        add("atlas", m.group(1), r)
    for m in re.finditer(r'"(Interface\\\\[^"]+)"', code):
        add("texture", m.group(1), r)
    for m in re.finditer(r'CreateFrame\(\s*"\w+"\s*,[^,)]*,[^,)]*,\s*"([^"]+)"', code):
        for t in m.group(1).split(","):
            add("template", t.strip(), r)
    for m in re.finditer(r'inherits="([^"]+)"', code):
        for t in m.group(1).split(","):
            add("template", t.strip(), r)
    # bare globals: identifiers not preceded by . or :, not ours, not Lua, known to Blizzard somewhere
    for m in re.finditer(r"(?<![.:\w])([A-Za-z_][A-Za-z0-9_]*)\b", code):
        n = m.group(1)
        if n in LUA or n in our_defined or n.startswith("C_") or n == "Enum" or len(n) < 4:
            continue
        if n in R_def or n in M_def or n in R_funcs or n in M_funcs or n[0].isupper() and (n in R_tok or n in M_tok):
            add("global", n, r)

def status(kind, name):
    if kind == "api":
        return name in R_funcs, name in M_funcs
    if kind == "enum":
        parts = name.split(".")
        r = parts[0] in R_enums and (len(parts) == 1 or parts[1] in R_enums[parts[0]])
        m = parts[0] in M_enums and (len(parts) == 1 or parts[1] in M_enums[parts[0]])
        return r, m
    if kind == "event":
        return name in R_events, name in M_events
    if kind == "global":
        return (name in R_def or name in R_funcs or name in R_tok), (name in M_def or name in M_funcs or name in M_tok)
    if kind == "template":
        return (name in R_def or name in R_tpl), (name in M_def or name in M_tpl)
    if kind in ("cvar", "atlas"):
        return (name in R_str or name in R_tok), (name in M_str or name in M_tok)
    if kind == "texture":
        return None, None
    return None, None

out = {}
for kind, names in found.items():
    out[kind] = []
    for n, where in sorted(names.items()):
        r, m = status(kind, n)
        out[kind].append({"name": n, "retail": r, "mop": m, "files": sorted(where)})
json.dump(out, open(os.path.join(SCR, "mopscan.json"), "w"), indent=1)
for kind, rows in out.items():
    miss = [x for x in rows if x["mop"] is False]
    print(f"{kind:9} used {len(rows):4}  missing in MoP {len(miss):4}")
print("retail files", len(retail_files), "mop files", len(mop_files), "retail api", len(R_funcs), "mop api", len(M_funcs))
