# Fibu — Projektregeln (AGENTS.md)

> Diese Regeln gelten **immer** — in jeder Phase, für jeden Agenten, bei jeder Änderung.
> Kein Agent darf diese Regeln verletzen, unabhängig von der Aufgabe.

---

## 1. Dart & Flutter

- **Dart Analyzer** muss am Ende jeder Phase fehlerfrei sein (`flutter analyze` → 0 Errors, 0 Warnings).
- Keine impliziten Typisierungen für öffentliche APIs; alle Parameter und Rückgabetypen sind explizit typisiert.
- Keine Typumgehungen (`dynamic` oder explizite Casts mit `as`) ohne begründenden Kommentar.

## 2. Design-Tokens

- **Keine hardcoded Farben oder Abstände** außerhalb von `lib/theme/theme.dart` (oder den dort registrierten Wada-Paletten).
- Alle Farben werden als semantische Tokens referenziert (`canvas`, `surface`, `textPrimary`, `textSecondary`, `accent`, etc.).
- Alle Abstände verwenden die 4pt-Grid-Werte aus `theme.dart` (`xs`, `sm`, `md`, `lg`, `xl`, `xxl`).
- Border Radius: nur `radiusSm: 6` oder `radiusLg: 12`. Keine anderen Werte.

## 3. Datenbank

- **Jeder DB-Write** geht durch eine typisierte Repository-Funktion oder einen entsprechenden Data-Access-Service.
- Kein direktes rohes SQL außerhalb des Database-Service-Layers.

## 4. Screens & UI

- **Jeder Screen** muss korrekt rendern mit:
  - 0 Remotes und 0 Rules (Empty State)
  - Ladevorgang (Loading State)
  - Fehler (Error State)
  - Kein Netzwerk (Offline State)
- Minimum 44pt Touch-Targets für alle interaktiven Elemente.
- WCAG AA Kontrast (≥ 4.5:1) für alle Text-auf-Hintergrund-Kombinationen.
- Alle Icons haben ein `accessibilityLabel`.

## 5. Stubs & Not-Implemented

- Alles was noch nicht implementiert ist, wird als **typisierter Stub** angelegt.
- Stubs werfen `UnimplementedError('NotImplemented: <Methodenname>')`.
- **Niemals** ein stiller No-Op (`() => {}`, `return;`, etc.).

## 6. Destructive Actions

Jede destruktive Aktion **muss** durch einen Bestätigungs-Dialog geschützt sein:
- **Echo-Modus Deletion** — „Dateien, die du lokal löschst, werden auch in der Cloud gelöscht."
- **Remote Disconnect** — „Bereits hochgeladene Dateien bleiben in der Cloud erhalten."
- **Reset Local Index** — „Der lokale Sync-Status wird zurückgesetzt. Beim nächsten Sync werden alle Dateien erneut geprüft."
- Der Dialog nennt die **Konsequenz** in Klartext, bevor der User bestätigt.

## 7. Motion & Animation

- Animationen sind **funktional**, nicht dekorativ.
- Nur für: Progress, State Transitions, Sheet/Modal Presentation.
- Dauer: 150–250ms, Standard-Easing.
- Implementiert mit standardmäßigen Flutter-Animations-Controllern oder implicit Animations (`AnimatedContainer`, `FadeTransition` etc.).

## 8. Bei Unsicherheiten

- **Immer fragen**, statt Annahmen zu treffen.
- Wenn eine Anforderung unklar ist → Frage dokumentieren und warten.
- Wenn ein technischer Trade-off existiert → Optionen auflisten und Empfehlung geben.
- Niemals "was Sinnvolles raten" bei sicherheitsrelevanten Entscheidungen (Encryption, Credentials, Löschungen).

## 9. Dokumentation

- **Arbeitsschritte dokumentieren**: Jeder Fortschritt wird in `task.md` festgehalten.
- **Phasen-Ergebnisse dokumentieren**: Am Ende jeder Phase wird `walkthrough.md` aktualisiert.
- **Code-Kommentare**: Nur wo das "Warum" nicht offensichtlich ist. Kein Kommentar-Spam.

## 10. Qualität

- Linter: 0 Warnings, 0 Errors (`flutter analyze`).
- Kein `print` in Produktionscode — nur über den strukturierten Logger oder `debugPrint` in Debug-Builds.
- Keine Secrets (API Keys, Tokens, Passwörter) in Logs oder Crash Reports.
- Jeder PR muss die CI-Pipeline bestehen (TypeCheck/Analysis + Tests).

## 11. Projektstruktur

- Projektverzeichnis: `d:\code gemini\fibu win\`
- Kein Code außerhalb der definierten Ordnerstruktur (`lib/`, `test/`).
- Imports verwenden Standard-Dart-Package-Imports (`import 'package:fibu/...'`).
- Keine zirkulären Abhängigkeiten.

## 12. Git

- Commits in englischer Sprache, prägnant.
- Konvention: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.
- Kein Commit der die CI-Pipeline bricht (TypeCheck oder Lint Fehler).
- **Direktpush auf `main` und Build-Überwachung:** siehe
  [`GITHUB_MAIN_WORKFLOW.md`](GITHUB_MAIN_WORKFLOW.md). Kurz: Workspace wird
  zwischen Nachrichten neu geklont → erst `git fetch` + `git reset -q
  origin/main`; Workflow-Dateien nie antasten (keine `workflows`-Permission);
  Step-Logs sind aus der Agent-Umgebung nicht lesbar, nur die
  Annotations-Zusammenfassung.
