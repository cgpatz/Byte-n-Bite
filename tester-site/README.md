# Byte n' Bite — Tester build

Play: **https://cgpatz.github.io/Byte-n-Bite-Tester/** (Chrome or Edge on a computer)

This is the testing version of Byte n' Bite. It is the same game as the normal
web version, plus **Admin Run** on the main menu:

- **Admin Run** starts a test game that is never saved.
- In game, press **F10** or click the red **ADMIN RUN** tag (top left) to open the admin panel:
  coins, restaurant and manager levels, Market tools, quest progress, the World tab
  (day/evening) and ready-to-copy code for every quest and challenge.
- **Start / New Game** play the normal game with saving, like a real player.

## Reporting a bug
Write down the restaurant level, what you did, what you expected and what happened.
A screenshot helps.

## How this site is built
The workflow in `.github/workflows/tester.yml` builds the game from the main repo
(cgpatz/Byte-n-Bite) with the "Web Tester" export preset and publishes it here.
It runs by hand, every day at 18:00, and after each push to the main repo
(when the main repo has the `TESTER_DISPATCH_TOKEN` secret).
