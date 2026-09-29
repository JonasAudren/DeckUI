local ADDON, ns = ...
local D = DeckUI

-------------------------------------------------------------------
-- Character bank and warband bank: next step, not built yet.
-------------------------------------------------------------------
-- Listed in the .toc already so adding it later needs no client restart.
--
-- What is known (Blizzard's 12.1.0 source, read 2026-09-29):
-- the bank is one BankFrame with two tabs, Character and Account, and
-- the bank slots are ordinary bag IDs - CharacterBankTab_1..6 (6-11)
-- and AccountBankTab_1..5 (12-16). The old Bank (-1) and BankBag_1..7
-- are gone. The catch: a right click on a bag item while the bank is
-- open deposits into BankFrame:GetActiveBankType(), so Blizzard's bank
-- frame has to stay alive underneath ours, like the bag frames do.
