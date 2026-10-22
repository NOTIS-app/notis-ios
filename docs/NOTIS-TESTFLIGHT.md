# NOTIS iOS: van Windows naar TestFlight

Je hebt geen Mac nodig. De code schrijf je (met Claude) op Windows. GitHub huurt per build een
Mac in de cloud: die bouwt de app, ondertekent hem met jouw Apple-account en stuurt hem naar
TestFlight. Op je iPhone installeer je de build via de TestFlight-app.

```
Windows (code)  ──git push──▶  GitHub Actions (Mac in de cloud)  ──upload──▶  App Store Connect
                                  bouwen + ondertekenen                         │
                                                                                ▼
                                                              TestFlight-app op je iPhone
```

## Hoe de bouwstraat werkt

In `.github/workflows/testflight.yml` staan twee taken:

| Taak | Wanneer | Wat | Apple-account nodig? | Duur |
|---|---|---|---|---|
| **check** | elke push naar een `notis/...`-branch | compileert de app voor de simulator | nee | ~8–12 min |
| **testflight** | push naar de branch `testflight`, of op GitHub *Actions → iOS build & TestFlight → Run workflow* | bouwt, ondertekent en uploadt naar TestFlight | ja | ~15–25 min |

Met **check** zie je snel of de code compileert, zonder dat er al iets bij Apple geregeld hoeft te
zijn. **testflight** gebruik je alleen als je echt een nieuwe testversie op je telefoon wilt.

Het buildnummer is het volgnummer van de GitHub-run, dus dat loopt vanzelf op. Het
versienummer (`0.1.0`) pas je aan in Xcode-instelling `MARKETING_VERSION` (vraag Claude).

## Wat kost het bouwen?

GitHub rekent bouwtijd in minuten. Een minuut op een **Mac**-machine telt **10×** zo zwaar als een
minuut op Linux.

- **Private repo, gratis GitHub-plan**: 2.000 minuten per maand → 200 Mac-minuten. Een
  TestFlight-build kost ~20 Mac-minuten en een check ~10. Reken op ongeveer **6–8 TestFlight-builds
  plus wat checks per maand**.
- **GitHub Team** ($4 per gebruiker per maand): 3.000 minuten → 300 Mac-minuten.
- **Extra minuten**: Mac-minuten kosten ongeveer $0,06–0,08 per minuut, dus een TestFlight-build
  ~€1,50. Stel in GitHub onder *Settings → Billing → Spending limit* een limiet in, dan kan het
  nooit onverwacht duur worden.
- **Publieke repo**: onbeperkt gratis. Dat kan (Foqos is MIT-licentie), maar dan is je code openbaar.
- **Alternatief**: Codemagic geeft 500 gratis Mac-minuten per maand. Dan moet de bouwstraat
  daarheen worden omgezet.

Tip: werk een tijd op een `notis/...`-branch (alleen checks). Zet pas iets op `testflight` als je
het op je telefoon wilt testen.

## Eenmalige setup bij Apple

### 1. Apple Developer Program

Meld je aan op <https://developer.apple.com/programs/enroll/> (€99 per jaar). Op bedrijfsnaam heb
je een D-U-N-S-nummer nodig. Dat is gratis, maar kan een paar dagen duren. Noteer je **Team ID**
(*Membership details*).

### 2. Identifiers registreren

Ga naar <https://developer.apple.com/account/resources/identifiers/list>.

1. **App Group**: maak `group.nl.notisapp.ios` aan.
2. **App IDs** (type *App*), steeds met de capabilities uit de tabel:

| Bundle ID | Capabilities |
|---|---|
| `nl.notisapp.ios` | App Groups, Family Controls (Development), NFC Tag Reading |
| `nl.notisapp.ios.DeviceMonitor` | App Groups, Family Controls (Development) |
| `nl.notisapp.ios.ShieldAction` | App Groups, Family Controls (Development) |
| `nl.notisapp.ios.ShieldConfig` | App Groups, Family Controls (Development) |
| `nl.notisapp.ios.Widget` | App Groups |

Koppel bij elke App ID de groep `group.nl.notisapp.ios` (*App Groups → Configure*).

### 3. Family Controls (Distribution) aanvragen ⚠️ doe dit meteen

Zonder deze toestemming weigert Apple builds die apps blokkeren voor TestFlight.

Vraag hem aan via <https://developer.apple.com/contact/request/family-controls-distribution>, voor
**elk** van deze vier: `nl.notisapp.ios`, `nl.notisapp.ios.DeviceMonitor`,
`nl.notisapp.ios.ShieldAction` en `nl.notisapp.ios.ShieldConfig`.

Leg kort uit wat NOTIS doet, bijvoorbeeld: *"NOTIS helps people put their phone away: holding the
phone to a physical NOTIS stone (NFC) blocks the apps the user picked, until they scan the stone
again."*

Goedkeuring duurt meestal een paar dagen tot een paar weken. Tot die tijd faalt de taak
**testflight** bij het ondertekenen. De taak **check** werkt wel.

### 4. App aanmaken in App Store Connect

Ga naar <https://appstoreconnect.apple.com> → *Apps* → **+** → *New App*:

- Platform: iOS
- Naam: NOTIS (moet uniek zijn in de App Store; is hij bezet, kies dan bv. "NOTIS – focus")
- Taal: Nederlands
- Bundle ID: `nl.notisapp.ios`
- SKU: `notis-ios`

### 5. API-sleutel voor GitHub

Ga in App Store Connect naar *Users and Access* → *Integrations* → *App Store Connect API* →
*Team Keys* → **+**.

- Naam: `GitHub Actions`
- Rol: **Admin**. Die rol is nodig zodat de cloud-Mac zelf certificaten en profielen mag maken.

Download het `.p8`-bestand. **Dat kan maar één keer**, dus bewaar het veilig. Noteer de **Key ID**
en de **Issuer ID** (die staat boven de lijst).

## Eenmalige setup bij GitHub

Ga in de repo `notisappinfo-design/notis-ios` naar *Settings* → *Secrets and variables* →
*Actions* → *New repository secret* en maak er vier aan:

| Naam | Waarde |
|---|---|
| `ASC_KEY_ID` | Key ID uit stap 5 |
| `ASC_ISSUER_ID` | Issuer ID uit stap 5 |
| `ASC_KEY_P8` | de **hele inhoud** van het `.p8`-bestand (open het in Kladblok en plak alles, inclusief de `-----BEGIN PRIVATE KEY-----`-regels) |
| `APPLE_TEAM_ID` | Team ID uit stap 1 |

Plak deze waarden zelf in GitHub. Zet ze nooit in de code of in een chat.

## Een testversie maken

1. Laat Claude de wijzigingen op een `notis/...`-branch zetten en pushen. Wacht tot **check** groen is.
2. Zet de code op de `testflight`-branch:
   ```bash
   git push origin HEAD:testflight
   ```
   Of kies op GitHub *Actions* → *iOS build & TestFlight* → *Run workflow*.
3. Na ~20 minuten is de taak klaar. Apple verwerkt de build daarna nog 10–30 minuten.
4. Ga in App Store Connect naar *TestFlight* → *Internal Testing* → **+**. Maak een groep (bv.
   "Team") en voeg jezelf en de andere testers toe. Ze moeten in *Users and Access* staan.
5. Installeer op de iPhone de app **TestFlight** uit de App Store, open de uitnodiging en tik op
   *Installeren*.

Interne testers (max. 100, uit je eigen team) krijgen elke nieuwe build meteen. Externe testers
(bv. leerlingen en ouders) kunnen later via een openbare link. Daarvoor doet Apple eerst een korte
beta-review.

## Wat zit er in deze eerste testversie

- Beginscherm met de grote NOTIS-steen. Tik erop, houd je iPhone bij een gekoppelde steen en je
  apps gaan op slot. Elke gekoppelde steen ontgrendelt weer.
- *Mijn NOTIS*: stenen koppelen, hernoemen en verwijderen. Per steen kies je de apps die bruikbaar
  blijven, en je kunt de selectie van een andere steen kopiëren.
- Noodontgrendeling zoals op Android: houd de steen lang ingedrukt en je krijgt 5 minuten
  toegang, 2× per sessie. Daarna gaat alles vanzelf weer op slot, ook als de app dicht is.
  Met *Blokkeren hervatten* stop je eerder.
- Stenen worden herkend aan hun chip-ID, net als op Android, dus dezelfde steen werkt op beide.

### Bewust nog niet in deze versie

- **Scannen zonder eerst op de knop te tikken.** iOS laat een app nooit stil op de achtergrond
  NFC lezen, zoals Android wel doet. Er zijn twee manieren die er het dichtst bij komen:
  1. *Web-link op de steen.* Houd je iPhone (ontgrendeld) bij de steen, dan verschijnt een melding
     "Open in NOTIS". Eén tik daarop en de app wisselt het slot. Hiervoor moet de steen een link
     als `https://notisapp.nl/s/...` bevatten en moet `notisapp.nl` live staan met een
     *apple-app-site-association*-bestand.
  2. *Opdrachten-automatisering.* In de app Opdrachten (Shortcuts) kun je per steen instellen
     "bij scannen van deze NFC-tag → NOTIS wisselen". Dat gaat helemaal zonder tikken, maar elke
     gebruiker moet het zelf eenmalig instellen.
- **Ouders en docenten.** Die staan uit in `Foqos/Notis/FeatureFlags.swift`
  (`schoolLive` en `parentControls`). Op iOS werkt het kiezen van apps anders dan op Android: Apple
  geeft geen app-namen, alleen versleutelde tokens per toestel. Een ouder- of klaslijst moet
  daarom op het toestel zelf gekozen worden. Dat bouwen we als aparte stap.

## De app bekijken op Windows (zonder iPhone)

Een echte iOS-emulator voor Windows bestaat niet: Apple's simulator draait alleen op een Mac.
Wat wel kan, is de simulator in je browser via **appetize.io**:

1. Open op GitHub de laatste groene **check**-run (*Actions*) en download onderaan
   `NOTIS-simulator`. Daarin zit `NOTIS-simulator.zip`.
2. Maak een gratis account op <https://appetize.io>, kies *Upload* en upload de zip.
3. Je krijgt een iPhone in je browser met NOTIS erop.

In de simulator is er geen NFC en geen Schermtijd. Tikken op de steen doet daarom alsof er een
steen gescand is, en apps gaan niet echt op slot. Gebruik dit om schermen en teksten te bekijken.
Of het blokkeren echt werkt, test je met TestFlight op een iPhone.

## Features aan- en uitzetten

Alle schakelaars staan in `Foqos/Notis/FeatureFlags.swift`, net als `FeatureFlags.kt` op Android:

| Vlag | Standaard | Wat |
|---|---|---|
| `notisHome` | aan | NOTIS-schermen. Uit: het oorspronkelijke Foqos-dashboard |
| `allowList` | aan | per steen de apps die **bruikbaar blijven** (uit: de apps die op slot gaan) |
| `emergencyUnlock` | aan | noodontgrendeling met lang indrukken |
| `schoolLive` | **uit** | functies voor docenten en klassen |
| `parentControls` | **uit** | functies voor ouders |

Een vlag omzetten betekent: nieuwe build en nieuwe TestFlight-versie.
