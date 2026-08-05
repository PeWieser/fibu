# EchoVault — Projektregeln (AGENTS.md)

> Diese Regeln gelten **immer** — in jeder Phase, für jeden Agenten, bei jeder Änderung.
> Kein Agent darf diese Regeln verletzen, unabhängig von der Aufgabe.

---

## 1. TypeScript

- **TypeScript strict** muss am Ende jeder Phase bestehen (`npx tsc --noEmit` → 0 Errors).
- Kein `any` ohne expliziten Kommentar, warum es nötig ist.
- Alle Funktions-Signaturen sind vollständig typisiert — keine impliziten Rückgabetypen.

## 2. Design-Tokens

- **Keine hardcoded Farben oder Abstände** außerhalb von `src/theme/theme.ts`.
- Alle Farben werden als semantische Tokens referenziert (`bg.canvas`, `text.primary`, `accent`, etc.).
- Alle Abstände verwenden die 4pt-Grid-Werte aus `theme.ts` (`xs`, `sm`, `md`, `lg`, `xl`, `2xl`).
- Border Radius: nur `sm: 6` oder `lg: 12`. Keine anderen Werte.

## 3. Datenbank

- **Jeder DB-Write** geht durch eine typisierte Repository-Funktion in `src/db/repositories/`.
- Kein rohes SQL (`db.run()`, `db.exec()`, etc.) außerhalb von `src/db/`.
- Alle Migrationen sind idempotent und versioniert über `user_version` Pragma.

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
- Stubs werfen `new Error('NotImplemented: <Methodenname>')`.
- **Niemals** ein stiller No-Op (`() => {}`, `return undefined`, etc.).

## 6. Destructive Actions

Jede destruktive Aktion **muss** durch einen Bestätigungs-Dialog geschützt sein:
- **Echo-Modus Deletion** — „Dateien, die du lokal löschst, werden auch in der Cloud gelöscht."
- **Remote Disconnect** — „Bereits hochgeladene Dateien bleiben in der Cloud erhalten."
- **Reset Local Index** — „Der lokale Sync-Status wird zurückgesetzt. Beim nächsten Sync werden alle Dateien erneut geprüft."
- Der Dialog nennt die **Konsequenz** in Klartext, bevor der User bestätigt.

## 7. Motion & Animation

- Animationen sind **funktional**, nicht dekorativ.
- Nur für: Progress, State Transitions, Sheet Presentation.
- Dauer: 150–250ms, Standard-Easing.
- Bibliothek: `react-native-reanimated`.

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

- ESLint: 0 Warnings, 0 Errors (`npx eslint . --max-warnings 0`).
- Kein `console.log` in Produktionscode — nur über den strukturierten Logger.
- Keine Secrets (API Keys, Tokens, Passwörter) in Logs oder Crash Reports.
- Jeder PR muss die CI-Pipeline bestehen (TypeCheck + Lint + Tests).

## 11. Projektstruktur

- Projektverzeichnis: `d:\code gemini\fibu\`
- Kein Code außerhalb der definierten Ordnerstruktur (`src/`, `modules/`, `__tests__/`).
- Imports verwenden Path Aliases (`@/` → `src/`).
- Keine zirkulären Abhängigkeiten.

## 12. Git

- Commits in englischer Sprache, prägnant.
- Konvention: `feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`.
- Kein Commit der die CI-Pipeline bricht (TypeCheck oder Lint Fehler).
