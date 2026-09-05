# Fibu — Vereinfachungs-Durchgang

Stand: `main` @ `3bf96e1` plus die Entscheidungen aus der Rücksprache.
Frage: Was kann weg, was kann einfacher werden?

Maßstab: nicht „ist es falsch?", sondern „verdient es seinen Platz?". Ein
Feature, das niemand vermissen würde, ist Ballast — auch wenn es funktioniert.

Legende: ✅ umgesetzt · ⬜ bewusst behalten

---

## ✅ Umgesetzt

### 1. Sektion mit genau einem Eintrag

Die Einstellungen hatten eine Sektion „Sprache" mit **einer einzigen Zeile**.
Eine Sektion mit einem Eintrag kostet Überschrift und Rahmen für nichts und
zwingt zum Scrollen, wo eine Zeile gereicht hätte. Sprache ist außerdem eine
Erscheinungsbild-Präferenz, keine eigene Kategorie.

**Jetzt:** Sprache liegt bei den anderen Erscheinungsbild-Einstellungen.
Einstellungsbildschirm liest sich auf allen drei Plattformen gleich:
Cloud-Laufwerke · Netzwerk · Erscheinungsbild (inkl. Sprache) · Über · Rechtliches.

Von sechs Sektionen auf fünf, ohne dass eine Einstellung verschwunden ist.

### 2. 16 Farbwähler → eine Reihe

Vorher: zwei Reihen (Hell-Palette, Dunkel-Palette) mit je 8 Paletten plus
zwei Modus-Schalter. Dieselben acht Paletten zweimal — und wer beide gleich
wollte, musste zweimal dasselbe tippen.

**Jetzt:** eine Reihe, eine Wahl. Jede Sanzo-Wada-Palette bringt ihr Hell- und
ihr Dunkel-Set mit; welcher Modus gilt, entscheidet das System
(`appThemeProvider` liest nur noch `systemBrightnessProvider`). Die Vorschau
zeigt das Farbset des Modus, der gerade aktiv ist — schaltet das System um,
zeigt dieselbe Reihe die andere Seite derselben Palette.

Weggefallen: `syncWithSystem`, `forceDarkMode`, `selectedLightPalette`,
`selectedDarkPalette`, `setSyncWithSystem`, `setForceDarkMode`,
`setLightPalette`, `setDarkPalette`, `lightPalettes`, `darkPalettes` und acht
Lokalisierungs-Strings. Dazu: `ThemeNotifier.paletteFromSettings` wandert alte
`settings.json`-Dateien (und alte Geräte bei der Konfig-Übertragung) mit —
Hell-Wahl gewinnt, sonst Dunkel-Wahl.

Alle acht Paletten bleiben. Gekürzt wurde die Entscheidung, nicht die Auswahl.

### 3. Kopplung: drei Wege → einer

Vorher: automatische Erkennung, QR-Code, Adresseingabe.

**Jetzt:** nur die Erkennung. QR-Code und Adresseingabe sind raus,
`qr_flutter` ist aus `pubspec.yaml` raus.

**Dabei gefunden — die Erkennung war kaputt.** Der UDP-Beacon enthielt nur
Name, IP und Port. `send()` verlangt aber den Sitzungsschlüssel aus dem
URL-Fragment und lehnt ohne ihn ab (`Adresse enthält keinen Schlüssel`).
`_sendTo` baute die URL ohne Fragment — **ein Tipp auf ein gefundenes Gerät
schlug damit immer fehl.** Der Schlüssel steht jetzt im Beacon
(`'v': 2`), `DiscoveredDevice` transportiert ihn, und
`DevicePairingService.targetUrlFor` baut daraus die Zieladresse. Ein Test
nagelt das fest (`test/unit/device_pairing_test.dart`).

**Und: Bestätigung vor dem Überschreiben.** Da der Schlüssel jetzt im lokalen
Netz lesbar ist, kann jeder im Netz ein Bundle schicken. Geschrieben wird
deshalb nichts ohne Antippen: Der Empfänger sieht Gerätename, Anzahl Laufwerke
und Anzahl Aufgaben und wählt „Übernehmen" oder „Ablehnen"
(`_PairingPhase.confirm`, `_confirmBox`). Ablehnen schreibt nichts und geht
zurück auf „Empfangen starten".

**iOS-Pflichteintrag:** Ohne `NSLocalNetworkUsageDescription` zeigt iOS den
Freigabe-Dialog für das lokale Netz nie an und blockiert Broadcast still —
die Erkennung fände dann nie ein Gerät. Der Eintrag ist in `Info.plist`
ergänzt. **Auf einem echten Gerät zu prüfen** (Testmatrix D11).

### 4. Elf Plattform-Weichen → eine

Jede Navigation baute ihre Route selbst: `defaultTargetPlatform` prüfen, dann
`FluentPageRoute`, `CupertinoPageRoute` oder `MaterialPageRoute`. Dieselben
fünf Zeilen standen **elf Mal** im Projekt.

**Jetzt:** `lib/core/navigation/app_nav.dart` — `AppNav.push(context, screen)`.
Die Übergänge bleiben plattformeigen, die Entscheidung dafür steht an einer
Stelle. Das ist der erste Baustein des Musters aus Punkt 5.

---

## Die Frage: Lassen sich die drei Implementierungen zusammenfassen?

**Ja — und zwar ohne dass die Plattformen gleich aussehen.** Der Einwand
(„jede Plattform soll individuell aussehen, und manche Optionen gibt es nur
auf iOS") trifft die *Darstellung*, nicht den *Inhalt*. Beides kann getrennt
werden:

```
        ┌──────────────────────────────┐
        │  Was steht auf dem Schirm?   │   ← einmal
        │  Liste von Einträgen:        │
        │  Titel, Untertitel, Aktion,  │
        │  Zustand, Plattform-Filter   │
        └──────────────────────────────┘
                       │
     ┌─────────────────┼─────────────────┐
     ▼                 ▼                 ▼
  Fluent-Renderer  Cupertino-Renderer  Material-Renderer
  (Win.tile, …)    (CupertinoListTile) (ListTile, …)
```

Konkret heißt das:

* **Ein Eintrag ist Daten, kein Widget.** `{ title, subtitle, trailing, onTap,
  platforms }`. `platforms: {iOS}` bedeutet: auf Windows und Android erscheint
  er gar nicht — die iOS-spezifischen Optionen bleiben iOS-spezifisch, sie
  stehen nur nicht mehr dreimal im Quelltext.
* **Drei Renderer bleiben.** Sie sind dünn (~50 Zeilen jeder) und wissen nur,
  wie aus einem Eintrag ein `fluent.ListTile`, ein `CupertinoListTile` oder ein
  `material.ListTile` wird. Aussehen, Fokus-Ring, Haptik, Trennlinien: weiter
  plattformeigen.
* **Sonderfälle bleiben Sonderfälle.** Wo ein Bildschirm wirklich etwas
  Eigenes hat (der Wizard, die Mediathek-Ansicht), darf er plattformspezifisch
  bleiben. Zusammengeführt wird, was dreimal dasselbe sagt.

**Erster Beweis, dass das Muster trägt:** `AppNav` (Punkt 4) und die
`Win.*`-Bausteine in `core/widgets/windows_controls.dart`. Beides sind
geteilte Logik mit plattformeigener Darstellung — nur bisher auf jeweils eine
Plattform beschränkt.

**Reihenfolge (kleinster Nutzen-zu-Risiko zuerst):**

| # | Datei | Zeilen | Warum zuerst |
|---|---|---|---|
| 1 | `settings_screen.dart` | 1082 | reine Listen, kaum Sonderfälle, Widget-Test vorhanden |
| 2 | `cloud_drives_screen.dart` | 1172 | ebenfalls Listen |
| 3 | `task_detail_screen.dart` | 1807 | Formulare, mehr Sonderfälle |
| 4 | `tasks_screen.dart` | 3472 | zuletzt — größter Gewinn, größtes Risiko |
| 5 | `dashboard_screen.dart` | 1199 | Karten-Layout, am wenigsten listenartig |

**Nicht in einem Rutsch.** Jeder Bildschirm einzeln, jeder mit grünem CI-Lauf
dazwischen. Der Einstellungsbildschirm ist der Probelauf: Wenn das Muster dort
trägt, trägt es überall.

---

## ⬜ Bewusst behalten

### Alle 53 Provider

Entscheidung: Die Auswahl bleibt vollständig. Die Suchfunktion im Wizard ist
der Weg durch die Liste — Kuratieren würde Anbieter verstecken, die jemand
braucht, und die Registry ist Daten, kein Code.

### Der Papierkorb

Lokales Löschen geht in einen Papierkorb mit 30 Tagen Aufbewahrung statt hart
zu löschen. Das ist nicht Ballast, sondern die einzige Sicherheit gegen einen
Fehlgriff. Auf dem Desktop gibt es keinen Systemdialog wie bei der
iOS-Fotos-App, der einen Fehler abfangen könnte.

### Die Anomalie-Bremse

20 % relative Grenze plus absolute Obergrenze von 25 Dateien. Sieht aus wie
Over-Engineering, ist aber der Unterschied zwischen „ein Album weg" und
„die Mediathek weg".

### Die Konflikt-Erkennung

3-Way-Abgleich gegen die Basis. Sieht aus wie Over-Engineering, ist aber der
Unterschied zwischen „eine Fassung still überschrieben" und „beide Fassungen
behalten".

---

## Was ich nicht angefasst habe

**Die Statusleiste.** Drei Zustände, kein Prozentsatz, Restdauer statt
Fortschrittsbalken-Zahl. Das ist schon reduziert. Nichts zum Wegnehmen.

**Die Aufgaben-Liste.** Eine Liste, ein Button. Nichts zum Wegnehmen.

**Das Dashboard.** Eine Karte, ein Status, ein Button. Nichts zum Wegnehmen.

---

## Zusammenfassung

| Befund | Status |
|---|---|
| Sektion mit einem Eintrag | ✅ zusammengeführt |
| 16 Farbwähler | ✅ eine Reihe, Hell/Dunkel automatisch |
| Drei Wege zur Kopplung | ✅ einer — und der funktionierende |
| Elf Plattform-Weichen beim Navigieren | ✅ `AppNav.push` |
| Drei Implementierungen pro Bildschirm | 🔶 Muster steht, Bildschirm für Bildschirm |
| 53 Provider in der Hauptauswahl | ⬜ bleiben, Suche ist der Weg |
| Papierkorb, Bremse, Konflikt-Erkennung | ⬜ bewusst behalten |
| Statusleiste, Aufgaben, Dashboard | ⬜ schon reduziert |
