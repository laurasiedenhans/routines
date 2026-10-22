# Routinen-App – Projektplan & Kontext

> Diese Datei ist die zentrale Referenz für das Projekt. Sie dient als Kontext für KI-Assistenten (Claude, Xcode-KI) und als Dokumentation. Bei Änderungen an Anforderungen oder Architektur bitte hier aktualisieren.

Arbeitsname: **Routines** (Platzhalter)

---

## 1. Vision

Eine To-do-App für **wiederkehrende Routinen**. Nutzer legen mehrere Listen an (z. B. „Morgenroutine“, „Wochenputz“), füllen sie mit To-dos und haken diese ab. Nach Ablauf des eingestellten Wiederholungszeitraums sind alle To-dos automatisch wieder offen. Listen mit Startzeit lösen eine **Live Activity** aus, in der man die To-dos der Reihe nach abhakt.

---

## 2. Plattformen & Voraussetzungen

| Punkt | Entscheidung |
|---|---|
| Plattformen | iOS, iPadOS, macOS – **eine native SwiftUI-Multiplatform-App** (kein Mac Catalyst) |
| Mindestversion | **iOS 26 / iPadOS 26 / macOS 26** (nötig für geplante Live Activities) |
| UI | SwiftUI |
| Persistenz | SwiftData (lokal), später Sync über CloudKit (private Datenbank) |
| Externe Dienste | **keine** (kein eigener Server, keine Drittanbieter-DB) |
| Sprache der App | Deutsch (Strings über String Catalog, damit später übersetzbar) |
| Developer-Account | Start mit kostenlosem Account; bezahlter Account erst ab Phase 6 (iCloud-Sync) |

**Kostenloser Account:** Lokale Mitteilungen, Live Activities und App Groups funktionieren. iCloud/CloudKit nicht. Installation auf dem iPhone muss alle 7 Tage aus Xcode erneuert werden.

---

## 3. Funktionsumfang

### MVP
- Mehrere Listen mit Name, Emoji, Farbe
- Wiederholung pro Liste: keine, täglich, wöchentlich, monatlich, jährlich – jeweils mit Intervall n („alle n Tage/Wochen/Monate/Jahre“) und Starttag
- Optionale Startzeit pro Liste
- To-dos hinzufügen (einmalig oder dauerhaft), abhaken, zurücknehmen, löschen (nur heute / alle zukünftigen)
- Startbildschirm mit Tages-Progress-Ring und Listenübersicht mit Fortschrittsbalken
- Lokale Mitteilung zur Startzeit
- Live Activity zur Startzeit mit sequenziellem Abhaken

### Später
- iCloud-Sync (Phase 6)
- Statistiken / Streaks / mehrere Analysen (Historie wird bereits gespeichert)
- Überfällige „alle n Tage“-Listen im Tagesring bis zum nächsten Zeitraum weiter anzeigen
- Papierkorb („Zuletzt gelöscht“), danach ggf. Löschen ganzer Listen per Wischen
- Archiv für abgeschlossene einmalige Listen (für Statistiken)
- Homescreen-Widgets (Progress Ring), interaktive Widgets
- Siri / Kurzbefehle über App Intents, Control-Center-Steuerelement
- SF Symbols zusätzlich zu Emojis
- Apple Watch

---

## 4. Wiederholungslogik (Kernlogik)

### Grundprinzip: Es wird nichts „zurückgesetzt“
Die App setzt um 0 Uhr **keine Daten zurück**. Stattdessen gibt es:
- **Aufgaben-Vorlagen** (`RoutineTask`): das dauerhafte To-do
- **Zeitraum-Einträge** (`TaskRecord`): „erledigt“ oder „übersprungen“ für einen bestimmten Zeitraum

Ein To-do gilt als erledigt, wenn für den **aktuellen Zeitraum** ein Erledigt-Eintrag existiert. Beginnt ein neuer Zeitraum, gibt es dafür noch keinen Eintrag → das To-do ist automatisch wieder offen. Kein Hintergrundprozess nötig, keine Konflikte zwischen Geräten, Historie inklusive.

### Zeitraum
Jede Liste hat zu jedem Zeitpunkt genau einen aktuellen Zeitraum `[periodStart, periodEnd)`. Grenzen liegen immer auf **0:00 Uhr lokaler Zeit**. Der Zeitraum wird als `periodKey` im Format `yyyy-MM-dd` (Datum von `periodStart`) gespeichert, damit er geräte- und zeitzonenstabil ist.

Jede Liste mit Wiederholung hat einen **Starttag** (`anchorDate`, Standard: Erstellungstag).

### Regeln

Jede Wiederholungsart hat ein **Intervall n ≥ 1** (Standard 1). Gezählt wird immer vom Starttag aus.

| Art | Zeitraum beginnt | Beispiel |
|---|---|---|
| Keine | einmalig am Starttag, endet nie | Umzugs-Checkliste |
| Täglich (alle n Tage) | Starttag + k·n Tage, 0:00 | n = 1: jeden Tag; n = 3, Start 1.10. → 1.10., 4.10., 7.10. … |
| Wöchentlich (alle n Wochen) | am gewählten Wochentag 0:00, alle n Wochen | Do, n = 2 → jeden zweiten Do 0:00 |
| Monatlich (alle n Monate) | am Ankertag, alle n Monate; existiert der Tag nicht, am letzten Tag des Monats | Start 13.01., n = 1 → jeden 13.; Start 30.01. → 28./29.02., dann 30.03.; n = 3 → 30.01., 30.04., 30.07. … |
| Jährlich (alle n Jahre) | am Datum des Starttags, alle n Jahre; 29.02. → in Nicht-Schaltjahren 28.02. | Start 29.02.2028 → 28.02.2029 |

Hinweise:
- **Ankertag bleibt immer erhalten (entschieden):** Das ursprüngliche Datum wird eingehalten, wann immer der Monat es hergibt. Die Verschiebung auf den Monatsletzten gilt nur für den betroffenen Monat.
- **Wöchentlich:** Der Wochentag wird separat gespeichert (`weekday`). Der erste Zeitraum beginnt am letzten gewählten Wochentag am oder vor dem Starttag; ab dort zählen die n Wochen.
- **Keine Wiederholung:** genau ein Zeitraum vom Starttag an, ohne Ende. Erledigte To-dos bleiben dauerhaft erledigt. Optionen „nur heute / immer“ (Hinzufügen) und „nur heute / alle zukünftigen“ (Löschen) entfallen – es wird einfach hinzugefügt bzw. gelöscht. Startzeit löst einmalig am Starttag aus. Zählt nie zum Tagesring.
- **Tagesring:** zählt Listen der Art „täglich“ mit beliebigem n, aber nur an Tagen, an denen ihr Zeitraum beginnt (siehe 7.1).
- Vor dem Starttag ist die Liste nicht aktiv und zeigt „Startet am …“.

### Berechnung (Pseudocode)
```
func currentPeriod(for list, at date) -> (start, end):
  n = list.interval
  switch list.recurrence:
    none:    start = anchor; end = nil (offen)
    daily:   k = floor(daysBetween(anchor, date) / n); start = anchor + k·n Tage
    weekly:  first = letzter Tag ≤ anchor mit weekday == list.weekday
             k = floor(daysBetween(first, date) / (7·n)); start = first + k·7·n Tage
    monthly: k = floor(monthsBetween(anchor, date) / n)  // Kandidat = anchorMonat + k·n,
             start = clamp(anchorDay, Monatslänge)       // Tag geclampt; falls > date → k − 1
    yearly:  analog mit Jahren, 29.02. geclampt
  end = nextPeriodStart(after: start)   // Datum immer aus Anker + (k+1)·n neu berechnen, nie aus dem geclampten Vorgänger
```
Diese Logik lebt in `RoutineKit` als reine, synchron testbare Funktionen (`RecurrenceEngine`) mit umfangreichen Unit-Tests (Monatsenden, Schaltjahre, Sommer-/Winterzeit, Zeitzonenwechsel).

### Aktionen auf To-dos
| Aktion | Umsetzung |
|---|---|
| Abhaken | `TaskRecord(kind: .completed, periodKey: aktuell)` anlegen |
| Abhaken zurücknehmen | alle `.completed`-Records des aktuellen `periodKey` dieses To-dos löschen |
| Löschen „nur heute“ | `TaskRecord(kind: .skipped, periodKey: aktuell)` anlegen |
| Löschen „alle zukünftigen“ | `RoutineTask.deletedAt = now` (Soft Delete, Historie bleibt) |
| Hinzufügen „einmalig“ | `RoutineTask.oneOffPeriodKey = aktueller periodKey` |
| Hinzufügen „immer“ | `RoutineTask` ohne `oneOffPeriodKey` |

### Verhalten abgehakter To-dos (bewusst anders als Erinnerungen)
- **Anforderung:** Ein abgehaktes To-do bleibt bis zum Ende des aktuellen Zeitraums erledigt und taucht **nicht** sofort wieder als offen auf (anders als in der Erinnerungen-App, wo wiederkehrende Einträge beim Abhaken sofort auf den nächsten Termin springen).
- Umsetzung: Abhaken ändert die `RoutineTask` nicht, sondern legt nur einen `TaskRecord` für den aktuellen `periodKey` an. Offen wird das To-do erst wieder, wenn ein neuer Zeitraum beginnt.
- Bei Wochen-/Monats-/Jahreslisten bleibt ein To-do entsprechend für den ganzen Zeitraum erledigt.
- **Zeitraumwechsel:** Daten werden nie zurückgesetzt, nur die **Anzeige** muss neu berechnet werden (SwiftUI rendert nicht von selbst neu, nur weil die Uhrzeit fortschreitet). Keine Hintergrundprozesse nötig.
  - Umsetzung als ein gemeinsamer `@Observable`-Baustein `AppClock` in `RoutineKit`, auf **allen Plattformen** gleich. Views lesen `now` nur von dort. `AppClock` aktualisiert `now`:
    1. beim Aktivwerden der App (`scenePhase == .active`) – nötig, da Timer in eingefrorenen Apps nicht laufen,
    2. per einmaligem Timer zum nächsten `periodEnd` aller Listen (danach neu stellen, kein Polling),
    3. bei Systemereignissen: Tageswechsel, Uhrzeit- oder Zeitzonenänderung (`significantTimeChangeNotification` / `NSCalendarDayChanged` / `NSSystemClockDidChange`).
  - Widgets/Live Activity: Timeline-Eintrag bzw. `staleDate` auf das Zeitraumende setzen.
- Zeiträume werden in lokaler Zeit berechnet; ein Zeitzonenwechsel kann den Wechsel verschieben (akzeptiert).

Ein To-do ist im aktuellen Zeitraum **sichtbar**, wenn: nicht gelöscht (oder `deletedAt` nach Zeitraumbeginn) **und** kein `.skipped`-Record **und** (`oneOffPeriodKey == nil` oder `== aktueller periodKey`).

---

## 5. Datenmodell (SwiftData, CloudKit-kompatibel)

CloudKit-Regeln, die **von Anfang an** eingehalten werden:
- keine `@Attribute(.unique)`
- jedes Attribut optional oder mit Standardwert
- alle Beziehungen optional, mit Inverse
- Duplikate nach Sync sind möglich → Logik muss tolerant sein (z. B. zwei Erledigt-Records = erledigt)

```swift
@Model final class RoutineList {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "✅"
    var colorRaw: String = "blue"         // ListColor (Apple-Systemfarbe, passt sich Hell/Dunkel an)
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    // Wiederholung
    var recurrenceRaw: String = "daily"   // none | daily | weekly | monthly | yearly
    var interval: Int = 1                  // alle n Tage/Wochen/Monate/Jahre (≥ 1)
    var weekday: Int = 2                   // 1 = So … 7 = Sa (Calendar), nur für weekly
    var anchorDate: Date = Date()          // Starttag

    // Startzeit & Erinnerung
    var startTimeMinutes: Int? = nil       // Minuten seit 0:00, nil = keine Startzeit
    var notificationEnabled: Bool = false
    var liveActivityEnabled: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \RoutineTask.list)
    var tasks: [RoutineTask]? = []
}

@Model final class RoutineTask {
    var id: UUID = UUID()
    var title: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var deletedAt: Date? = nil             // Soft Delete („alle zukünftigen“)
    var oneOffPeriodKey: String? = nil     // gesetzt = nur in diesem Zeitraum
    var list: RoutineList?

    @Relationship(deleteRule: .cascade, inverse: \TaskRecord.task)
    var records: [TaskRecord]? = []
}

@Model final class TaskRecord {
    var id: UUID = UUID()
    var periodKey: String = ""             // yyyy-MM-dd des Zeitraumbeginns
    var kindRaw: String = "completed"      // completed | skipped
    var createdAt: Date = Date()
    var task: RoutineTask?
}
```

Farben: Preset-Palette ähnlich der Erinnerungen-App (Rot, Orange, Gelb, Grün, Mint, Blau, Indigo, Lila, Pink, Braun, Grau) plus optional nativer `ColorPicker`.

---

## 6. Architektur

**Projektdaten:** App „Routines“, Bundle-ID `de.laurasiedenhans.Routines`, Widget `de.laurasiedenhans.Routines.RoutinesWidget`, App Group (ab Phase 5) `group.de.laurasiedenhans.routines`. Erstellt mit Xcode 27, Mindestversion iOS/macOS 26.6. Synchronisierte Ordner: Dateien in `Routines/Routines/` erscheinen automatisch in Xcode.

```
routines/                              Git-Repository
├── Docs/PROJECT.md                    diese Datei
└── Routines/
    ├── Routines.xcodeproj
    ├── RoutineKit/                    Lokales Swift Package („Backend“)
    │   ├── Sources/RoutineKit/
    │   │   ├── Models/                SwiftData-Modelle
    │   │   ├── Recurrence/            RecurrenceEngine (reine Logik)
    │   │   ├── Services/              ListStatus, TaskVisibility, Aktionen (ModelContext-Extension)
    │   │   ├── DayRing/               RingStyle, RingSelectionPolicy, DayRingSummary
    │   │   ├── Settings/              AppSettings (UserDefaults)
    │   │   ├── Clock/                 AppClock (inkl. Zeitreise für Tests)
    │   │   ├── Persistence/           ModelContainer für App, Testdaten, Previews
    │   │   ├── SampleData/            Testdatensatz
    │   │   └── Theme/                 Theme, ListColor, EmojiInput
    │   │   (später: Scheduling/, Intents/, LiveActivity/)
    │   └── Tests/RoutineKitTests/     Swift Testing
    ├── Routines/                      Multiplatform-App-Target (iOS, iPadOS, macOS)
    │   ├── RoutinesApp.swift, ContentView.swift
    │   ├── Support/                   RecurrenceFormatting (Texte), PreviewSupport
    │   └── Views/                     Home, ListDetail, ListSettings, Settings, Components
    └── RoutinesWidget/                Widget-Extension (noch Xcode-Vorlage, Live Activity in Phase 5)
```

- **Trennung:** Alle Logik, Modelle und Intents in `RoutineKit`. App und Extension sind dünne UI-Schichten. Texte für die Oberfläche liegen in der App (String Catalog).
- **App Group:** erst ab Phase 5 eintragen. `ModelConfiguration(groupContainer: .automatic)` nutzt sie dann automatisch; `AppSettings.sharedDefaults` auf die Group-Suite umstellen.
- **ModelContainer:** `RoutinePersistence.makeContainer()` mit `groupContainer: .automatic, cloudKitDatabase: .none` (Phase 6: `.private("iCloud.de.laurasiedenhans.Routines")`).
- Muster: `@Query` in Views, Logik in `RoutineKit` (`ListStatus`, `DayRingSummary`, `ModelContext`-Aktionen).
- Zeit: Views lesen nur `AppClock.now` aus der Environment.

---

## 7. Benutzeroberfläche

### 7.0 Designansatz & Theme
- **Vorgehen:** erst funktionaler Prototyp, dann Design-Überarbeitung nach Alltagstest. Kein Figma; Gestaltung direkt in Xcode mit Previews.
- **Grundstil:** Standard-Apple-Design (iOS 26 / Liquid Glass, System-Schriften, Systemfarben, Standardkomponenten).
- **Alle Stilwerte zentral als Standardparameter** in einem `Theme` (in `RoutineKit` oder einem eigenen UI-Modul), die später an einer Stelle geändert werden können. Views verwenden **nie** hart codierte Werte. Mindestens:
  - Farben: Listen-Palette, Akzent, Hintergründe, Ring-Track, Erledigt-Zustand
  - Abstände (`spacing.xs … xl`), Eckenradien, Zeilenhöhen
  - Typografie (Text-Styles, Gewichte)
  - Progress Ring: Durchmesser, Linienstärke, Linienende, Farbe/Verlauf, Track-Deckkraft, Animationsdauer
  - Fortschrittsbalken: Höhe, Radius
  - Toggle: Größe, Linienstärke
  - Animationen (Dauer/Feder für Abhaken, Verschieben)
- Komponenten wie `ProgressRing`, `ListProgressBar`, `CheckToggle` bekommen ihre Standardwerte aus dem `Theme`, können aber pro Aufruf überschrieben werden.

### 7.0a Navigation (iPhone)
- **Navigationsleiste unten** im iOS-26-Stil, keine durchgehende Leiste: zwei Liquid-Glass-Container (`GlassEffectContainer`), am Rand ausgerichtet, wachsen zur Mitte.
  - **Links:** Gruppe mit drei Bereichen (Symbol + Text, Symbole sind Platzhalter): **Heute** (Daily Dashboard, Standard), **Routinen**, **Listen**. Aktiver Bereich hervorgehoben.
  - **Rechts:** separater runder **„+“**-Button. Legt an, was zum Bereich passt: Heute/Routinen → „Neue Routine“, Listen → „Neue Liste“. Immer dasselbe Formular, nur passend vorausgewählt (Wiederholung täglich bzw. keine).
  - Leiste wird bei eingeblendeter Tastatur ausgeblendet.
- **Routine vs. Liste:** kein eigenes Feld. Routine = Wiederholung ≠ keine, Liste = ohne Wiederholung. Durch Ändern der Wiederholung wandert ein Eintrag zwischen den Bereichen.
- **Heute (Daily Dashboard):** Tageskarte mit Ring, darunter „Heute fällig“ = genau die Routinen, die heute im Ring zählen. Später personalisierbar.
- **Routinen / Listen:** aktuelle Einträge, darunter einklappbar „Geplant (n)“ (nächste zuerst); bei Listen zusätzlich einklappbar „Abgeschlossen (n)“ (alle To-dos erledigt).
- **Einstellungen:** Zahnrad oben rechts in allen drei Bereichen.
- **iPad/Mac:** vorerst unverändert (Seitenleiste mit allen Listen, `HomeView`), wird später überarbeitet.

### 7.0b Aufräumen einmaliger Listen
- **Detailansicht einer einmaligen Liste:** im Kopf von „Erledigt (n)“ **„Alle löschen“** (mit Rückfrage) – löscht alle erledigten To-dos endgültig. Bei Routinen gibt es den Button nicht.
- **„Wiederverwenden“** (nur wenn die einmalige Liste komplett erledigt ist): löscht alle To-dos, die Liste ist danach leer und wieder bei den aktuellen Listen. Name, Symbol, Farbe bleiben.
- **Bereich Listen:** im Kopf von „Abgeschlossen (n)“ **„Alle löschen“** (mit Rückfrage).
- **Automatisch:** Einstellung „Abgeschlossene löschen“: Nie (Standard) / 1 Tag / 3 Tage / 1 Woche / 2 Wochen / 1 Monat. Frist ab dem letzten abgehakten To-do (`CompletedListCleanup`, keine Modelländerung). Aufgeräumt wird beim Öffnen der App, beim Tageswechsel und beim Ändern der Einstellung. Abgeschlossene Listen zeigen „Wird in n Tagen gelöscht“.
- Ganze Listen lassen sich **nicht** per Wischen löschen (kein Papierkorb, Schutz vor versehentlichem Löschen).
- Gelöscht wird endgültig. Ein Archiv für Statistiken über einmalige Listen ist nachrüstbar (optionales Feld `archivedAt`), erfasst aber erst Listen ab Einführung.

### 7.1 Startbildschirm
- **Oben:** kompakte **Tageskarte** (Liquid Glass): kleiner Ring links (~92 pt), Text rechts („Heute“, „x von y täglichen To-dos“, „Als Nächstes: <Liste> · <Startzeit>“).
  - **Wählbar für den Ring:** alle Listen der Art „täglich“, also täglich (n = 1) **und** alle n Tage. Wochen-, Monats-, Jahreslisten und Listen ohne Wiederholung nie.
  - **Auswahl vs. heute fällig:**
    - *Ausgewählt* = in den Einstellungen für den Stil angehakt. Das Maximum gilt für die Auswahl.
    - *Heute fällig* = heute beginnt ein neuer Zeitraum der Liste (bei n = 1 immer, bei n = 2 jeden zweiten Tag usw.).
    - Im Ring erscheinen nur Listen, die **ausgewählt und heute fällig** sind. An anderen Tagen fehlt ihr Segment bzw. Ring, und **es rückt keine andere Liste nach**.
    - **Prozentwert, „x von y“ und „Als Nächstes“** beziehen sich nur auf die heute sichtbaren Listen, damit Ring und Zahlen übereinstimmen.
    - E: Die Segmentlängen verteilen sich auf die heute sichtbaren Listen.
    - F: Die heute sichtbaren Ringe liegen **immer so weit außen wie möglich** (in `sortOrder`-Reihenfolge, keine Lücken). Fehlt eine Liste heute, rücken die übrigen Ringe nach außen. Identifikation über die Listenfarbe.
    - „Heute fällig“ gilt nur am ersten Tag des Zeitraums (entschieden). Später möglich: Überfällige „alle n Tage“-Listen bis zum nächsten Zeitraum im Ring weiter anzeigen (z. B. als Einstellung). Abhaken in der Liste selbst ist im ganzen Zeitraum ohnehin schon möglich.
    - Ist heute keine ausgewählte Liste fällig → Karte zeigt „Heute keine Routinen fällig“.
  - **Auswahl pro Stil:** Jeder Stil merkt sich seine eigene Auswahl (Wechsel des Stils verliert nichts).
    - Maximum: D unbegrenzt, E max. 5, F max. 3.
    - Reihenfolge im Ring = Reihenfolge der Listen (`sortOrder`); bei F ist die erste Liste der äußere Ring.
    - **Standardbefüllung:** zuerst Listen mit n = 1 (nach `sortOrder`), danach, falls noch Platz ist, Listen mit n > 1.
    - Neue wählbare Liste wird automatisch aufgenommen, solange das Maximum des Stils nicht erreicht ist.
    - **Nie automatisch verdrängen:** Eine ausgewählte Liste (auch mit n > 1) wird nicht automatisch entfernt, um einer neuen täglichen Liste Platz zu machen. Das geschieht nur manuell.
    - Liste gelöscht oder auf eine nicht wählbare Art umgestellt → fällt automatisch aus der Auswahl.
    - Keine Liste ausgewählt → Karte zeigt leeren Ring und Hinweis „Listen in den Einstellungen auswählen“.
  - **Ringstil ist in den allgemeinen Einstellungen wählbar** (siehe 7.5). Alle drei Stile werden umgesetzt (Prototyp im Canvas „Progress Ring Varianten“):
    - **D · Einfacher Ring:** ein Ring in Akzentfarbe, Prozent im Ring.
    - **E · Segmente:** ein Segment pro täglicher Liste in Listenfarbe, Länge nach Anzahl To-dos, runde Enden (dürfen optisch leicht überlappen bzw. nicht perfekt anschließen), keine Legende – die Zuordnung ergibt sich über die Listenfarben darunter.
    - **F · Ringe ineinander:** wie die Fitness-Bewegungsringe, nur die ersten 3 täglichen Listen (nach `sortOrder`), außen beginnend. Prozent dann im Text statt im Ring.
  - Kein Fortschritt (0) → Füllung ausblenden (runde Enden würden sonst einen Punkt zeichnen).
- **Darunter:** alle aktiven Listen als Zeilen:
  - Emoji in farbigem Kreis, Name, Wiederholungsinfo
  - **Wiederholungsinfo einheitlich:** `Rhythmus · Detail · Uhrzeit`, z. B. `Täglich · 06:30`, `Alle 2 Wochen · Do · 09:00`, `Monatlich · am 30.`, `Einmalig`. Detail nur bei wöchentlich (Wochentag), monatlich (Tag), jährlich (Datum); Uhrzeit nur mit Startzeit. Bei Platzmangel stufenweise gekürzt (`ViewThatFits`): erst ohne Detail, dann nur Rhythmus.
  - Fortschrittsbalken in Listenfarbe (erledigt / gesamt im aktuellen Zeitraum)
- **Ganz unten: „Geplant (n)“**, einklappbar (standardmäßig zu), nur wenn vorhanden: Listen, deren Starttag in der Zukunft liegt, sortiert nach Startdatum (nächste zuerst). Statt Fortschrittsbalken „Startet am 26. Okt.“. Am Starttag wandert die Liste automatisch zu den aktiven Listen.
- Toolbar (nur iPad/Mac, `HomeView`): **links Zahnrad** (`gearshape`) → allgemeine Einstellungen; **rechts „+“** zum Anlegen einer neuen Liste. Auf dem iPhone siehe 7.0a.
- iPad/Mac: `NavigationSplitView` (Listen links, Detail rechts). iPhone: `NavigationStack`.

### 7.2 Listen-Detail
- Titel mit Emoji, Listenfarbe als Akzent.
- Offene To-dos oben, jeweils mit **rundem Toggle rechts** (leerer Kreis).
- Abhaken → Toggle wird ausgefüllt, To-do wandert animiert in den eingeklappten Bereich **„Erledigt (n)“** am Ende (ausklappbar, standardmäßig zu).
- Erneutes Tippen auf einen ausgefüllten Toggle → To-do wird wieder offen und rutscht nach oben.
- **Swipe nach links** → „Löschen“ → `confirmationDialog`: „Nur heute löschen“ / „Alle zukünftigen löschen“ / „Abbrechen“.
- Am Listenende: **„+ Aufgabe hinzufügen“** → Textfeld + Auswahl **„Immer / Einmalig“** (Segmented Control), **ohne Buttons** wie in der Erinnerungen-App: Return fügt hinzu und bleibt offen für das nächste To-do; Tippen außerhalb des Felds oder Scrollen übernimmt getippten Text und schließt die Eingabe; leeres Feld schließt einfach.
- Reihenfolge per Drag & Drop änderbar (`sortOrder`).
- **Oben rechts: Zahnrad** → Listen-Einstellungen.

### 7.3 Listen-Einstellungen (Sheet)
- Name
- Emoji (Textfeld auf ein Emoji begrenzt + Raster mit Vorschlägen; SwiftUI hat keinen nativen Emoji-Picker)
- Farbe (Preset-Palette wie Erinnerungen)
- Wiederholung: Keine / Täglich / Wöchentlich (+ Wochentag) / Monatlich / Jährlich, jeweils mit Stepper „alle n …“ (ausgeblendet bei „Keine“)
- Starttag (DatePicker)
- Startzeit an/aus + Uhrzeit
- Mitteilung an/aus
- Live Activity an/aus (nur iOS sichtbar)
- Liste löschen (mit Bestätigung)

### 7.4 Neue Liste
Gleiches Formular wie Einstellungen, als Sheet vom Startbildschirm.

### 7.5 Allgemeine Einstellungen
- **Zugang:** Zahnrad-Symbol (SF Symbol `gearshape`) oben links auf dem Startbildschirm, öffnet ein Sheet mit Standard-`Form`. Auf dem Mac zusätzlich über das App-Menü bzw. ⌘, (SwiftUI-`Settings`-Scene).
- **Zum Start:**
  - **Ringstil:** Einfacher Ring / Segmente / Ringe ineinander (Picker mit kleiner Vorschau). Standard: Segmente.
  - **Listen im Ring:** darunter alle wählbaren Listen (täglich und alle n Tage, mit Rhythmus-Angabe) mit Häkchen für den gewählten Stil, Hinweis „x von max. 5 ausgewählt“; weitere Häkchen sind deaktiviert, sobald das Maximum erreicht ist.
  - Gespeichert als `ringSelection: [RingStyle: [UUID]]` (Listen-IDs) in `AppSettings`.
- **Kandidaten für später:** Erscheinungsbild (System/Hell/Dunkel), Standardwerte für neue Listen (Farbe, Wiederholung), Mitteilungen global an/aus, Statistiken, Über die App.
- **Speicherung:** `AppSettings` (`@Observable`) in `RoutineKit`, gespeichert in den `UserDefaults` der App Group (damit Widget/Live Activity den Ringstil lesen können). Ab Phase 6 optional über iCloud Key-Value Store zwischen Geräten synchronisieren.
- Einstellungen gehören **nicht** in SwiftData: Sie sind gerätenah, klein und brauchen keine Historie.

---

## 8. Mitteilungen & Live Activity

### Auslösezeitpunkt
Liste mit Startzeit: Auslösung **am ersten Tag jedes Zeitraums zur Startzeit** (täglich jeden Tag; wöchentlich am Wochentag; monatlich am Ankertag usw.; bei „Keine“ einmalig am Starttag). Bis zum nächsten Zeitraum bleibt der Stand erhalten, es gibt keine weiteren Auslösungen dazwischen. (entschieden)

### Lokale Mitteilung (Fallback & Mac/iPad)
- `UNUserNotificationCenter`, keine Push-Infrastruktur nötig.
- Täglich/wöchentlich mit n = 1: wiederkehrender `UNCalendarNotificationTrigger`.
- Intervall n > 1, monatlich (wegen Clamping), jährlich, keine Wiederholung: nächste Termine einzeln einplanen; iOS erlaubt max. 64 ausstehende Mitteilungen → rollierend bei jedem App-Start neu planen.
- Tippen auf die Mitteilung öffnet die Liste.

### Live Activity (iOS)
- **Zeitpunkt:** wird erst gebaut, wenn die App steht (Phase 5). Gestaltung bis dahin offen.
- **Platzhalter-Layout:** eine Box im System-Standardstil (Liquid Glass): oben Emoji + Listenname, darunter das aktuelle To-do mit rundem Toggle rechts. Abhaken → nächstes To-do erscheint.
- **Geplanter Start** über `Activity.request(…, start: Date)` (iOS 26+). Das System startet sie zum Termin, auch wenn die App im Hintergrund ist.
- Die App plant den **nächsten** Termin pro Liste bei: App-Start, Rückkehr in den Vordergrund, Änderung der Liste, Ende einer Activity.
- Wurde die App lange nicht geöffnet, greift die Mitteilung als Fallback (beide parallel aktivierbar).
- **Inhalt:** Listenname, Emoji, Farbe, Fortschritt (z. B. 2/6), **das nächste offene To-do** mit Abhak-Button.
- **Abhaken:** Button löst `CompleteTaskIntent` (`LiveActivityIntent`) aus → schreibt `TaskRecord` in den geteilten Store → aktualisiert die Activity mit dem nächsten offenen To-do.
- Zusätzlich Button „Beenden“ (`EndActivityIntent`).
- **Endet:**
  1. wenn alle To-dos erledigt sind (kurze „Geschafft“-Anzeige, dann `dismissalPolicy: .after(…)`),
  2. nach 8 Stunden (entspricht auch dem Systemlimit),
  3. wenn der Zeitraum der Liste endet,
  4. bei manuellem Beenden.
- **Technischer Hinweis zu 3.:** Die App läuft beim Zeitraumwechsel meist nicht. Lösung: `staleDate = periodEnd` setzen (Activity zeigt „abgelaufen“) und beim nächsten App-Start bzw. nächsten Intent beenden. Spätestens das 8-Stunden-Limit greift.
- Wird die Liste in der App geändert, während eine Activity läuft, wird sie aktualisiert.
- Dynamic Island: kompakt = Emoji + Fortschritt; erweitert = nächstes To-do + Abhak-Button.
- Mit macOS 26 erscheinen iPhone-Live-Activities auch in der Menüleiste eines gekoppelten Macs.

---

## 9. Synchronisation (Phase 6)

- SwiftData mit CloudKit (`cloudKitDatabase: .private(...)`), private Datenbank des Nutzers.
- Lokal-first: Die App funktioniert vollständig offline; Sync läuft im Hintergrund.
- Voraussetzungen: bezahlter Developer-Account, iCloud-Capability (CloudKit-Container), Background Mode „Remote notifications“.
- Konflikte: durch das Record-Modell kaum relevant (Einträge werden nur angelegt/gelöscht). Duplikate werden in Abfragen toleriert, optional periodisch bereinigt.
- Optionale Ergänzung: iCloud Key-Value Store für kleine Einstellungen.

---

## 10. Umsetzungsphasen

| Phase | Inhalt | Ergebnis |
|---|---|---|
| 0 | Xcode-Projekt (Multiplatform), `RoutineKit`-Package, Widget-Extension, App Group | baut auf allen Plattformen |
| 1 | `RecurrenceEngine` + Modelle + `RoutineStore` + Unit-Tests | Kernlogik verifiziert |
| 2 | UI: Startbildschirm, Listen-Detail, Einstellungen, Hinzufügen/Löschen | App lokal benutzbar |
| 3 | Lokale Mitteilungen | Erinnerung zur Startzeit |
| 4 | Alltagstest, Features nachschärfen, Design-Überarbeitung über `Theme`, Feinschliff iPad/Mac | stabile App |
| 5 | Live Activity (zunächst Platzhalter-Layout, siehe 8), geplanter Start, interaktives Abhaken | Kernfeature fertig = MVP |
| 6 | iCloud-Sync (bezahlter Account) | Geräteübergreifend |
| 7 | Widgets, Statistiken, Siri/Kurzbefehle, SF Symbols | Ausbau |

---

## 11. Offene Punkte / Annahmen (bitte bestätigen)

- [x] Monatlich: Ankertag bleibt nach Clamping erhalten (30.01. → 28.02. → 30.03.) (entschieden)
- [x] Progress Ring: zählt nur tägliche Listen (entschieden)
- [x] Ringstil: alle drei (D, E, F), wählbar in den allgemeinen Einstellungen (entschieden)
- [x] Listen im Ring: Auswahl pro Stil, Maximum D frei / E 5 / F 3, Zahlen nur aus Auswahl (entschieden)
- [x] Startzeit löst am ersten Tag jedes Zeitraums aus (entschieden)
- [x] Listen ohne Wiederholung möglich (entschieden)
- [x] Intervall n für Tage, Wochen, Monate und Jahre (entschieden)
- [x] App-Name „Routines“, Bundle-ID `de.laurasiedenhans.Routines` (entschieden)
- [ ] Reihenfolge ändern (Drag & Drop) auf dem iPhone: braucht ggf. einen Bearbeiten-Modus
- [ ] Wird Wiederholung oder Starttag einer bestehenden Liste geändert, passen alte Erledigt-Einträge evtl. nicht mehr zum neuen Zeitraum (aktuell akzeptiert)

---

## 12. Testen

| Ebene | Wo | Wie |
|---|---|---|
| Unit-Tests | `RoutineKit/Tests` (Swift Testing) | Scheme „RoutineKit“, Ziel „My Mac“, ⌘U. Feste Zeitzone Europe/Berlin. Abgedeckt: Wiederholungslogik (Monatsanker, Schaltjahr, Sommerzeit, Intervalle), Ringauswahl, Sichtbarkeit, Emoji-Eingabe. |
| Previews | jede View | `previewEnvironment()` mit In-Memory-Testdaten |
| Simulator mit Testdaten | Scheme „Routines (Testdaten)“ | Startargument `-sampleData`: frische In-Memory-Datenbank + eigene Einstellungen bei jedem Start, echte Daten unberührt |
| Entwicklerbereich | Einstellungen (nur Debug) | Zeitreise (+1 Std., +1 Tag, 23:59, zurücksetzen), Testdaten hinzufügen, alle Daten löschen |

**Testdatensatz (`SampleData`)**, relativ zum aktuellen Datum erzeugt:

| Liste | Wiederholung | testet |
|---|---|---|
| ☀️ Morgenroutine | täglich, 06:30, Mitteilung + Live Activity | teils erledigt, einmaliges To-do „Paket abholen“, Verlauf der letzten 6 Tage |
| 🌙 Abendroutine | täglich, 21:30 | nichts erledigt, „Lesen“ heute übersprungen, „Tagebuch“ alle zukünftigen gelöscht (mit Historie) |
| 🏃 Training | alle 2 Tage, heute fällig | Ring mit n-Tage-Liste |
| 🧘 Meditation | alle 2 Tage, heute nicht fällig | fehlt im Ring, rückt nicht nach |
| 💊 Vitamine | täglich | 100 %, Erledigt-Bereich |
| 🧺 Haushalt | wöchentlich, Zeitraum begann vor 2 Tagen | nicht im Ring |
| 🪴 Pflanzen gießen | alle 2 Wochen, heute neuer Zeitraum | Intervall bei Wochen |
| 💳 Finanzen | monatlich ab 30.01. | Monatsanker |
| 📊 Quartalsbericht | alle 3 Monate | Intervall bei Monaten |
| 🦷 Zahnarzt | jährlich ab 29.02.2024 | Schaltjahr |
| 📦 Umzug | ohne Wiederholung | einmalige Liste, Löschen ohne Rückfrage |
| 🇪🇸 Spanischkurs | täglich, Start in 5 Tagen | „Startet am …“, nicht abhakbar |

---

## 13. Konventionen für KI-Assistenten

- Sprache im Code: Englisch (Typen, Variablen, Kommentare). UI-Texte: Deutsch über String Catalog.
- Swift 6, Strict Concurrency; SwiftUI + SwiftData + Observation (`@Observable`), kein Combine wo vermeidbar.
- Keine Drittanbieter-Abhängigkeiten ohne Rücksprache.
- Logik gehört in `RoutineKit`, nicht in Views. Neue Logik immer mit Unit-Tests (Swift Testing).
- CloudKit-Regeln aus Abschnitt 5 nie verletzen.
- Datum/Zeit nur über `RecurrenceEngine` und den injizierten Zeit-Provider berechnen, nie `Date()` direkt in Views.
- Keine hart codierten Farben, Abstände, Radien oder Größen in Views – immer über `Theme` (siehe 7.0).
- Jede View bekommt eine `#Preview` mit In-Memory-Container und Beispieldaten.
- Diese Datei bei Architektur- oder Anforderungsänderungen aktualisieren.
