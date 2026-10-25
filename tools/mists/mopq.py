"""Answer yes/no questions about the MoP client: is a name defined, documented or used?
usage: python -I mopq.py <scratch> name1 name2 ...  (prints docs / defined / used counts and a sample file)"""
import os, re, sys
SCR = sys.argv[1]
root = os.path.join(SCR, "mop")
files = []
for l in open(os.path.join(root, "Interface", "ui-effective-list.txt")):
    l = l.strip().replace("\\", "/")
    p = os.path.join(root, l)
    if l and os.path.exists(p):
        files.append((l.replace("Interface/AddOns/", ""), open(p, encoding="utf-8", errors="ignore").read()))
for name in sys.argv[2:]:
    pat = re.compile(r"(?<![\w])" + re.escape(name) + r"(?![\w])")
    docs = [f for f, s in files if "APIDocumentationGenerated" in f and pat.search(s)]
    defs = [f for f, s in files if "APIDocumentationGenerated" not in f and re.search(
        r'(function\s+' + re.escape(name) + r'\b|^\s*' + re.escape(name) + r'\s*=|name="' + re.escape(name) + r'")', s, re.M)]
    used = [f for f, s in files if "APIDocumentationGenerated" not in f and pat.search(re.sub(r"--[^\n]*", "", s))]
    print(f"{name:45} docs {len(docs):2}  def {len(defs):2}  used {len(used):3}  " + (defs[:1] or used[:2] or [""])[0])
