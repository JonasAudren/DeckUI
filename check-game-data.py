"""check-game-data.py - checks the game IDs DeckUI keeps by hand against the game's own data.

Some things the game has no API for ("which currencies are this season's crests", "which
quest flags a profession treasure"), so a few files keep IDs. This script compares every one
of them with Blizzard's client tables as wago.tools publishes them (DB2 exports, the same
data the game ships), so the numbers rest on the game itself rather than on another addon:

  currencies    CurrencyTypes   -> the name of each currency ID
  achievements  Achievement     -> the title of each achievement ID
  quests        QuestV2         -> the quest exists at all
                QuestV2CliTask  -> its title, where the game keeps one (hidden tracking
                                   quests - treasures, hunts - have none; those are checked
                                   in game with /week record)
  items         ItemSparse      -> the item's name (slow; only with --items)

Run it at every patch:   python check-game-data.py   [--items] [--refresh]
The tables are cached in %TEMP%\\deckui-gamedata for a day; --refresh fetches them again.
Exit code 1 when an ID is unknown to the game or a name does not match.
"""
import csv
import io
import os
import re
import sys
import tempfile
import time
import urllib.request

ROOT = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(tempfile.gettempdir(), "deckui-gamedata")
WAGO = "https://wago.tools/db2/{}/csv"
problems = []


def table(name, query=""):
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name + (re.sub(r"\W", "_", query) if query else "") + ".csv")
    fresh = os.path.exists(path) and time.time() - os.path.getmtime(path) < 86400
    if "--refresh" in sys.argv or not fresh:
        print("fetching", name, query)
        # without a user agent wago.tools answers 403
        request = urllib.request.Request(WAGO.format(name) + query, headers={"User-Agent": "DeckUI check-game-data"})
        with urllib.request.urlopen(request, timeout=300) as r:
            data = r.read()
        with open(path, "wb") as f:
            f.write(data)
    with open(path, encoding="utf-8") as f:
        return list(csv.DictReader(f))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def block(src, start):
    """the text of a Lua table constructor that begins at `start = {`"""
    i = src.index(start)
    i = src.index("{", i)
    depth = 0
    for j in range(i, len(src)):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                return src[i:j + 1]
    raise ValueError(start)


def numbers(text):
    # drop comments first, so numbers in them do not count
    text = re.sub(r"--[^\n]*", "", text)
    return [int(n) for n in re.findall(r"(?<![\w.])(\d{3,})(?![\w.])", text)]


def report(kind, id_, ok, text, where):
    mark = "ok " if ok else "!! "
    print(f"  {mark}{kind} {id_}: {text}   ({where})")
    if not ok:
        problems.append(f"{kind} {id_} ({where}): {text}")


# ---------------------------------------------------------------- what we keep
week = read("DeckUI_Week/data.lua")
currencies = {}   # id -> where
for name in ("ns.SEASONS", "ns.CURRENCIES"):
    for n in numbers(block(week, name)):
        if n > 100:   # season numbers (17, 18) are keys, not currencies
            currencies[n] = "Week " + name
m = re.search(r"NEMESIS_LEFT, NEMESIS_TOTAL = (\d+), (\d+)", read("DeckUI_Quests/scenario.lua"))
currencies[int(m.group(1))] = currencies[int(m.group(2))] = "Quests scenario.lua (Nemesis)"
extras = read("DeckUI_Tooltip/extras.lua")
m = re.search(r"CHEST_ITEM, KEY_CURRENCY = (\d+), (\d+)", extras)
chest_item, key_currency = int(m.group(1)), int(m.group(2))
currencies.setdefault(key_currency, "Tooltip extras.lua (chest key)")

achievements = {int(n): "Quests hunt.lua" for n in re.findall(r"\{ id = (\d+)", read("DeckUI_Quests/hunt.lua"))}

quests = {}       # id -> (where, expected name or None)
delves = block(week, "ns.DELVES")
weekly = int(re.search(r"weeklyQuest = (\d+)", delves).group(1))
quests[weekly] = ("Week delves weekly", re.search(r'weeklyName = "([^"]+)"', delves).group(1))
quests[int(re.search(r"bountyQuest = (\d+)", delves).group(1))] = ("Week delve bounty", None)
items = {int(n): "Week bounty item" for n in numbers(re.search(r"bountyItems = \{[^}]*\}", delves).group(0))}
items[chest_item] = "Tooltip extras.lua (delve chest)"

prey = week[week.index("ns.PREY = {}"):week.index("ns.WEEKLIES")]
for first, last, difficulty, step in re.findall(r'add\((\d+), (\d+), "(\w+)"(?:, (\d+))?\)', prey):
    for q in range(int(first), int(last) + 1, int(step or 1)):
        quests[q] = ("Week prey " + difficulty, None)
for ids, name in re.findall(r'\{ ids = \{([^}]*)\}, name = "([^"]+)" \}', block(week, "ns.WEEKLIES")):
    for q in numbers(ids):
        quests[q] = ("Week weekly", name)
profs = block(week, "ns.PROFESSIONS")
for line in profs.splitlines():
    kind = re.search(r'kind = "(\w+)"', line)
    if kind:
        for q in numbers(re.search(r"ids = \{([^}]*)\}", line).group(1)):
            quests[q] = ("Week profession " + kind.group(1), None)

# ---------------------------------------------------------------- the game's data
print("Currencies")
names = {int(r["ID"]): r["Name_lang"] for r in table("CurrencyTypes")}
for c, where in sorted(currencies.items()):
    report("currency", c, c in names, names.get(c, "unknown to the game"), where)

print("Achievements")
titles = {int(r["ID"]): r["Title_lang"] for r in table("Achievement")}
for a, where in sorted(achievements.items()):
    report("achievement", a, a in titles, titles.get(a, "unknown to the game"), where)

print("Quests")
exists = {int(r["ID"]) for r in table("QuestV2")}
task = {int(r["ID"]): r["QuestTitle_lang"] for r in table("QuestV2CliTask")}
for q, (where, expected) in sorted(quests.items()):
    if q not in exists:
        report("quest", q, False, "unknown to the game", where)
        continue
    title = task.get(q)
    if expected and title and title.lower() != expected.lower() and expected.lower() not in title.lower():
        report("quest", q, False, f'game says "{title}", we say "{expected}"', where)
    else:
        report("quest", q, True, title or "exists (no title in the client data)", where)

if "--items" in sys.argv:
    print("Items")
    for i, where in sorted(items.items()):
        rows = table("ItemSparse", "?filter%5BID%5D=" + str(i))
        name = rows[0].get("Display_lang") if rows else None
        report("item", i, bool(name), name or "unknown to the game", where)
else:
    print(f"Items: {len(items)} skipped (slow) - add --items")

print()
if problems:
    print(f"{len(problems)} problem(s):")
    for p in problems:
        print("  " + p)
    sys.exit(1)
print("All IDs are known to the game.")
