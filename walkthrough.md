# Walkthrough — CI- und Expo-Build-Stabilisierung

Stand: 2026-08-08

## Reproduzierte Ursachen

1. `npm ci` stoppte vor TypeScript und ESLint, weil `expo-build-properties` in `package.json`, aber nicht im Lockfile stand.
2. `expo-build-properties@0.14.x` gehörte nicht zu Expo SDK 57. Erwartet wird `~57.0.9`.
3. Reanimated 4 hatte ohne `react-native-worklets` eine fehlende native Peer-Dependency.
4. `tsconfig.test.json` schloss `nativewind-env.d.ts` aus und konnte den CSS-Side-Effect-Import in `App.tsx` nicht auflösen.
5. Die RcloneService-Tests erwarteten noch `NotImplemented`, obwohl der Service bereits RPC-Aufrufe ausführte.
6. `expo-module.config.json` nannte nur Plattformen, aber keine nativen Modulklassen. Das rclone-Modul wurde deshalb weder unter Android noch Apple registriert.
7. Für iOS fehlte ein Podspec. Zusätzlich nutzte die Swift-Datei `Foundation.Process` mit einem macOS-Binary — beides ist auf iOS nicht lauffähig.
8. 119 generierte Dateien aus `modules/rclone/android/build/` waren trotz `.gitignore` versioniert.

## Umgesetzte Korrekturen

- Expo-/React-Native-Versionen an `expo/bundledNativeModules.json` ausgerichtet und das nicht benötigte, inkompatible `expo-build-properties` entfernt.
- Lockfile repariert und mit `npm ci --dry-run` geprüft.
- Nicht verwendetes `react-native-worklets-core` entfernt; erforderliches `react-native-worklets` ergänzt.
- Den doppelten/veralteten Reanimated-Babel-Plugin-Eintrag entfernt. Expo SDK 57 bindet den Worklets-Plugin selbst ein.
- App- und Test-Typecheck in einem Quality Gate zusammengeführt.
- RcloneService initialisiert das native Modul nun genau einmal, wiederholt einen fehlgeschlagenen Start und normalisiert Remote-Namen.
- Tests auf das aktuelle RPC-Verhalten umgestellt.
- Expo-Autolinking für `RcloneModule` auf Android und Apple vollständig konfiguriert.
- Android-Gradle-Datei auf das aktuelle lokale Expo-Modul-Template aktualisiert.
- iOS-Podspec ergänzt. Die nicht mobilefähigen Prozessansätze wurden auf Android und iOS durch klar fehlschlagende typisierte Stubs ersetzt.
- Ungültige Build-Properties und nicht benötigte manuelle Android-Berechtigungen entfernt.
- Doppelte Medienberechtigungen entfernt; Expo Media Library verwaltet Foto-/Video-Permissions.
- Eine CI-Erweiterung für Typecheck, Lint, Jest, Expo Prebuild und Android-Debug-Build wurde vorbereitet. `ci.yml` bleibt wegen der GitHub-Workflow-Berechtigung bewusst außerhalb des PRs und wird manuell übernommen.

## Validierung

| Prüfung                                                     | Ergebnis                                     |
| ----------------------------------------------------------- | -------------------------------------------- |
| `npm ci --dry-run`                                          | erfolgreich                                  |
| `npm run typecheck`                                         | erfolgreich (App + Tests)                    |
| `npm run lint`                                              | erfolgreich, 0 Warnungen                     |
| `npm test -- --runInBand`                                   | 7 Suites / 36 Tests erfolgreich              |
| `npx expo export --platform android`                        | Hermes-Bundle erfolgreich                    |
| `npx expo prebuild --platform android --clean --no-install` | erfolgreich                                  |
| `npx expo prebuild --platform ios --clean --no-install`     | erfolgreich                                  |
| Android Expo-Autolinking                                    | `expo.modules.rclone.RcloneModule` aufgelöst |
| Apple Expo-Autolinking                                      | Pod `Rclone` und `RcloneModule` aufgelöst    |
| Expo Doctor (lokale Checks)                                 | 18/18 lokale Checks erfolgreich              |

Die vollständige lokale Gradle-Kompilierung war in der Arena-Laufzeit nicht möglich, weil dort weder Java noch ein Android SDK installiert sind. Der Versuch endet ausschließlich mit `JAVA_HOME is not set`. Der echte Gradle-Build ist deshalb in der separat bereitgestellten `ci.yml` als verpflichtender Schritt vorgesehen.

## Verbleibender Architektur-Blocker

Die App-Shell ist für Android und iOS buildbar, die rclone-Engine selbst ist aber noch nicht releasefähig:

- Der vorherige Android-Ansatz kopierte ein ausführbares Programm in beschreibbaren App-Speicher. Moderne Android-Versionen verbieten diesen W^X-Verstoß.
- Der vorherige iOS-Ansatz konnte weder `Foundation.Process` verwenden noch ein macOS-Binary starten.
- Der entfernte Download-Workflow verwendete zudem einen nicht existierenden Android-Release-Artefaktnamen.

Die korrekte Folgearbeit ist rclones `librclone/gomobile`: als AAR für Android und als XCFramework für iOS, jeweils in-process über das bereits typisierte RPC-Interface. Bis dahin lehnen beide nativen Stubs rclone-Aufrufe mit `NotImplemented` ab, statt einen nicht funktionierenden Build oder stillen No-op auszuliefern.
