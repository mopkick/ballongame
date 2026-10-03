# Ballonalarm

Ballons platzen lassen im Browser: 90 Sekunden, 8 Schuss, Bestenliste nach Treffern pro Minute.
Läuft auf Handy, Tablet und Laptop, lässt sich als App auf den Home-Bildschirm legen und funktioniert offline.

## Was in diesem Ordner liegt

| Datei / Ordner | Wofür |
| --- | --- |
| `index.html` | Das komplette Spiel |
| `config.js` | Einstellungen für den Online-Modus (leer = Einzelspieler) |
| `manifest.webmanifest` | Name, Farben und Symbole für „Als App installieren“ |
| `sw.js` | Service Worker: macht das Spiel offline spielbar |
| `icons/` | App-Symbole (Android, iPhone, Browser-Tab) |
| `fonts/` | Schriften, lokal eingebunden (keine Verbindung zu Google) |
| `vendor/supabase.js` | Bibliothek für den Online-Modus (wird nur geladen, wenn er eingeschaltet ist) |
| `supabase/schema.sql` | Datenbank für die gemeinsame Bestenliste |
| `impressum.html`, `datenschutz.html`, `legal.css` | Vorlagen, **bitte ausfüllen** |
| `_headers` | Cache-Regeln für Netlify und Cloudflare Pages |
| `.nojekyll` | Sorgt dafür, dass GitHub Pages alle Dateien ausliefert |
| `.github/workflows/deploy.yml` | Automatisches Veröffentlichen auf GitHub Pages bei jedem Push |
| `netlify.toml` | Automatisches Veröffentlichen über Netlify, wenn das Repository verbunden ist |

## 1. Lokal ausprobieren

Service Worker laufen nur über `http://localhost` oder `https://`, nicht per Doppelklick auf die Datei.

```bash
cd ballongame
python3 -m http.server 8080
# dann http://localhost:8080 öffnen
```

## 2. Online stellen (eine Variante aussuchen)

Alle drei Varianten sind kostenlos und liefern automatisch HTTPS, was für die App-Installation nötig ist.

**A. Netlify Drop (am schnellsten, ohne Konto-Setup)**
1. https://app.netlify.com/drop öffnen.
2. Den ganzen Ordner `ballonalarm` ins Fenster ziehen.
3. Fertig, du bekommst sofort eine Adresse. Mit einem kostenlosen Konto bleibt sie dauerhaft und du kannst eine eigene Domain verbinden.

**B. Cloudflare Pages**
1. Im Cloudflare-Dashboard: *Workers & Pages* → *Create* → *Pages* → *Upload assets*.
2. Ordner hochladen, Projektname z. B. `ballonalarm` → Adresse `ballonalarm.pages.dev`.

**C. GitHub Pages, vollautomatisch (empfohlen)**
1. Repository anlegen (hier: `ballongame`) und den Inhalt dieses Ordners hochladen (inklusive des versteckten Ordners `.github`).
2. *Settings* → *Pages* → *Source*: **GitHub Actions** auswählen.
3. Ab jetzt veröffentlicht jeder Push auf `main` die Seite automatisch unter `https://mopkick.github.io/ballongame/`. Den Fortschritt siehst du im Tab *Actions*.
4. Hinweis: Mit einem kostenlosen GitHub-Konto muss das Repository dafür öffentlich sein. Für private Repositories nimm Variante D.

**D. Netlify mit GitHub verbunden (auch für private Repositories)**
1. Repository wie in C anlegen.
2. In Netlify: *Add new site* → *Import an existing project* → GitHub → Repository wählen. Die Einstellungen kommen automatisch aus `netlify.toml`.
3. Jeder Push veröffentlicht automatisch, für Pull Requests gibt es Vorschau-Adressen.

**Eigene Domain** (z. B. `ballonalarm.de`): beim Domain-Anbieter kaufen und in Netlify, Cloudflare oder GitHub als *Custom Domain* eintragen. Die Anleitung dazu zeigt der jeweilige Anbieter direkt an.

## 3. Online-Modus einschalten (optional)

Ohne Online-Modus ist Ballonalarm ein Einzelspieler-Spiel mit einer Bestenliste der eigenen Runden auf dem Gerät.
Mit Online-Modus gibt es eine gemeinsame Bestenliste und eine Live-Lobby: Alle sehen, wer gerade spielt, und bekommen Meldungen wie „Lena hat einen Goldballon erwischt!“.

> **Status:** Für dieses Repository ist der Online-Modus bereits eingerichtet (Supabase-Projekt `biwjtdoozzglimhbkveq`, Region eu-west-1). Die Schritte unten brauchst du nur für ein neues Projekt.

1. Kostenloses Projekt auf https://supabase.com anlegen. **Region in der EU wählen**.
2. *SQL Editor* → Inhalt von `supabase/schema.sql` einfügen → *Run*.
3. Projekt-URL und **Publishable Key** kopieren. Beide findest du über den Button *Connect* oder unter *Project Settings → API Keys*.
4. Beide Werte in `config.js` eintragen und pushen.

Ein Login ist nicht nötig: Jedes Gerät erzeugt beim ersten Start eine zufällige Spieler-ID und einen geheimen Spieler-Schlüssel. Der Server speichert davon nur einen Hash, sodass niemand fremde Einträge verändern kann.
   Bei Variante C kannst du `config.js` leer lassen und die Werte stattdessen im Repository unter *Settings → Secrets and variables → Actions → Variables* als `SUPABASE_URL` und `SUPABASE_KEY` hinterlegen. Der Workflow trägt sie beim Veröffentlichen ein.

```js
window.BALLONALARM_CONFIG = {
  supabaseUrl: 'https://abcdefghijkl.supabase.co',
  supabaseKey: 'sb_publishable_...'
};
```

Der Publishable/anon Key ist dafür gedacht, öffentlich im Browser zu stehen. Die Datenbank ist so abgesichert, dass jeder nur lesen und Ergebnisse ausschließlich über die Prüf-Funktion `submit_result` eintragen kann, höchstens eins alle 15 Sekunden pro Spieler.
**Den `secret`- oder `service_role`-Key niemals in `config.js` eintragen.**

Gut zu wissen:
- Gewertet wird die beste Runde pro Person nach Treffern pro Minute. Runden unter 20 Sekunden zählen nicht.
- Die Werte rechnet der Server aus und lehnt unmögliche Ergebnisse ab. Weil das Spiel im Browser läuft, kann jemand mit technischem Wissen trotzdem schummeln. Für ein Spiel unter Freunden reicht der Schutz. Einzelne Einträge löschst du im Supabase-Dashboard unter *Table Editor → players* (der Bestenlisten-Eintrag verschwindet automatisch mit).
- Wenn die Live-Lobby nicht erscheint, prüfe in Supabase unter *Realtime → Settings*, ob öffentliche Kanäle erlaubt sind.

## 4. Updates veröffentlichen

**Mit Variante C oder D:** Änderung committen und pushen, fertig. Die Cache-Version in `sw.js` wird bei jedem Deploy automatisch aus dem Commit gesetzt, installierte Apps holen sich das Update beim nächsten Öffnen.

**Mit Drag & Drop (A oder B):**
1. Dateien ändern.
2. In `sw.js` die Zeile `const VERSION = 'ballonalarm-v1';` hochzählen (`v2`, `v3`, …).
3. Ordner erneut hochladen.

## 5. Vor dem Veröffentlichen

- [ ] `impressum.html` und `datenschutz.html` mit deinen Angaben ausfüllen (gelb markierte Felder)
- [ ] Im Datenschutz den Hosting-Anbieter eintragen und den Supabase-Abschnitt löschen, falls du keinen Online-Modus nutzt
- [ ] Auf einem iPhone (Safari → Teilen → „Zum Home-Bildschirm“) und einem Android-Handy (Chrome → „App installieren“) testen
- [ ] Prüfen, ob der Name „Ballonalarm“ für deine Domain und später den App Store frei ist

## 6. Später: App Store und Google Play

Der Ordner ist so aufgebaut, dass er ohne Änderungen als `webDir` in [Capacitor](https://capacitorjs.com) passt:

```bash
npm init -y
npm install @capacitor/core @capacitor/cli @capacitor/ios @capacitor/android
npx cap init Ballonalarm de.deinedomain.ballonalarm --web-dir ballonalarm
npx cap add ios && npx cap add android
npx cap open ios   # öffnet Xcode (Mac nötig)
```

Für die Einreichung brauchst du das Apple Developer Program (99 €/Jahr) bzw. ein Google-Play-Konto (25 $ einmalig) und eine öffentlich erreichbare Datenschutzerklärung. Damit Apple die App nicht als „nur eine Webseite“ ablehnt, lohnen sich native Extras wie Vibration bei Treffern und eine Game-Center-Bestenliste.

## Lizenzen

- Schriften „Lilita One“ und „Nunito“: SIL Open Font License 1.1, siehe `fonts/OFL-*.txt`
- `vendor/supabase.js`: MIT-Lizenz, siehe `vendor/supabase-LICENSE.txt`
