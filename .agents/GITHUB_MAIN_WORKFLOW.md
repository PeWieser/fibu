# Direkt auf `main` pushen und den Build überwachen

> Gilt für alle Agenten in diesem Repo. Ergänzt `AGENTS.md` (Regel 12).

## Warum direkt auf `main`

Der Workflow `build-ios.yml` triggert **nur** auf `push` nach `main` (plus
`workflow_dispatch`, das für die GitHub-App gesperrt ist). Ein PR würde also
gar keinen Build auslösen. Deshalb: committen und direkt auf `main` pushen,
dann den Lauf überwachen.

## 1. Vor jeder Änderung: Stand holen

Der Workspace wird **zwischen Nachrichten neu geklont** (shallow, Tiefe 1).
Lokale Commits früherer Runden sind dann weg, der Working Tree kann aber noch
alte Inhalte aus früheren Ständen enthalten. Deshalb immer zuerst:

```bash
git fetch origin main -q
git reset -q origin/main          # Working Tree bleibt, HEAD/Index auf main
git checkout origin/main -- .github/workflows/build-ios.yml   # s. u.
git status --short                # muss NUR die eigenen Änderungen zeigen
```

**Wichtig:** Erscheint `.github/workflows/build-ios.yml` als geändert, ist das
eine veraltete lokale Kopie. Unbedingt mit dem Befehl oben zurücksetzen —
sonst enthält der Commit eine Workflow-Änderung und der Push wird abgelehnt
(siehe „Grenzen").

Kontrollieren, dass nichts Fremdes mitwandert:

```bash
git status --short        # nur erwartete Dateien
git diff --stat           # Umfang plausibel?
```

## 2. Committen und pushen

```bash
git add -A
git -c user.name="Arena Agent" -c user.email="agent@arena.ai" commit -m "fix: ..."
git rev-parse --short HEAD^        # muss der alte main-Tip sein
git push origin HEAD:main
```

`HEAD^` vorher prüfen: Zeigt es nicht den aktuellen `origin/main`-Tip, ist der
Commit auf einem veralteten Stand entstanden und der Push schlägt mit
`non-fast-forward` fehl. Dann Schritt 1 wiederholen.

Commit-Konvention nach `AGENTS.md` Regel 12: `feat:`, `fix:`, `chore:`,
`docs:`, `test:`, `refactor:` — englisch, prägnant.

## 3. Build überwachen

```bash
RUN=$(gh run list --branch main --limit 1 --json databaseId -q '.[0].databaseId')
gh run watch $RUN --exit-status --interval 30
```

Einzelne Steps:

```bash
gh run view $RUN --json jobs -q '.jobs[0].steps[] | "\(.conclusion // .status)  \(.name)"'
```

Reihenfolge im Workflow: `Analyze` → `Set up Go` → `gomobile` →
`Build librclone` → `Build iOS App` → `Package IPA` → `Upload IPA Artifact` →
`Unit- und Widget-Tests`.

**Die Tests laufen bewusst hinter dem Build**, damit ein roter Test nicht die
IPA blockiert.

## 4. Testergebnis auslesen

Die Test-Zusammenfassung steht in den Annotations:

```bash
JOB=$(gh run view $RUN --json jobs -q '.jobs[0].databaseId')
gh api repos/PeWieser/fibu/check-runs/$JOB/annotations -q '.[] | .message'
```

Liefert z. B. `65 tests passed, 1 failed.`

## 5. Grenzen — und was dann

### Step-Logs sind nicht lesbar

`gh run view --log` und `--log-failed` schlagen fehl: Die Logs liegen auf
`results-receiver.actions.githubusercontent.com`, und der Host ist aus der
Agent-Umgebung nicht erreichbar (`curl` → SSL-Fehler 35, `gh` → `EOF`,
Proxy → HTTP 500). Die Annotations-API liefert nur die Zusammenfassung, keine
einzelnen Fehlermeldungen.

**Konsequenz:** Detaillierte Fehlerausgaben müssen beim Menschen erfragt
werden. Konkret nachfragen: die `❌`-Zeile plus `Expected:`/`Actual:` bzw. der
Block `EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK`. Das sind wenige Zeilen.

**Nicht raten.** Ohne Meldung kostet jeder Rateversuch einen vollen CI-Zyklus
(`Analyze` ~15 s, kompletter Lauf ~11 min). Lieber einmal gezielt nachfragen.

### Workflow-Dateien sind tabu

Die GitHub-App hat keine `workflows`-Permission:

```
remote rejected (refusing to allow a GitHub App to create or update workflow
`.github/workflows/build-ios.yml` without `workflows` permission)
```

Änderungen am Workflow müssen vom Menschen übernommen werden. Nie versuchen,
sie mitzupushen — der gesamte Push wird abgelehnt.

### `flutter analyze` / `flutter test` laufen lokal nicht

In der Agent-Umgebung ist kein Flutter-SDK installiert und
`storage.googleapis.com` nicht erreichbar. Verifikation läuft deshalb über CI.

Als lokale Vorprüfung haben sich bewährt:

- **Klammer-Balance gegen `HEAD`** — fängt die häufigsten Editierfehler:

  ```bash
  python3 - << 'PY'
  import subprocess
  files = subprocess.run(['git','diff','--name-only','HEAD'],
                         capture_output=True, text=True).stdout.split()
  for p in [f for f in files if f.endswith('.dart')]:
      cur  = open(p, encoding='utf-8').read()
      head = subprocess.run(['git','show',f'HEAD:{p}'],
                            capture_output=True, text=True).stdout
      for a,b in (('(',')'),('{','}'),('[',']')):
          d1, d2 = cur.count(a)-cur.count(b), head.count(a)-head.count(b)
          if d1 != d2: print(f"!! {p} {a}{b}: {d1:+d} statt {d2:+d}")
  print("fertig")
  PY
  ```

- **Skriptbasierte Edits danach gegenlesen.** Massen-Ersetzungen haben hier
  wiederholt Analyzer-Fehler erzeugt, etwa `const` vor einem Ausdruck, der
  durch die Ersetzung nicht mehr konstant war, oder `sharedWarning!` innerhalb
  eines Blocks, der bereits promoted.

## 6. Typische Analyzer-Fallen in diesem Repo

| Fehler | Ursache |
|---|---|
| `unnecessary_non_null_assertion` | `x!` innerhalb von `if (x != null)` — Promotion greift bereits |
| `use_build_context_synchronously` | `context` ist Methoden-Parameter; dann `context.mounted` prüfen, **nicht** `mounted` vom State |
| `unnecessary_import` | Symbole kommen bereits aus einem anderen Import |
| `unused_element` | Private Methode nach dem Entfernen ihres letzten Aufrufs |
| `prefer_const_declarations` | `final x = <konstanter Ausdruck>` |

Infos zählen als Fehlschlag: `flutter analyze` bricht auch bei `info` ab.

## 7. Test-Fallen

| Fehler | Ursache |
|---|---|
| `A Timer is still pending` | Offene Timer am Test-Ende. In diesem Repo: die 2 s Mindestanzeigedauer in `_syncTaskToRemote` (entsteht erst **nach** der Mock-Simulation, ~1,5 s) und rekursive Provider wie `remoteFibuUsageProvider`. Letztere überriden, statt Timer abzupumpen |
| Texte nicht gefunden | Die App folgt der Systemsprache, CI läuft `en_US`. `localeProvider` auf `de` overriden |
| `pumpAndSettle timed out` | Unbestimmte Spinner animieren endlos. Begrenzt pumpen statt `pumpAndSettle` |
| Widget nicht gefunden | Liegt unterhalb des 800×600-Test-Viewports. `tester.view.physicalSize` vergrößern |
| Registry-leer | `remotesProvider` liest die **Registry-Datei**, nicht `listRemotes()`. `remoteEntriesProvider` overriden |
