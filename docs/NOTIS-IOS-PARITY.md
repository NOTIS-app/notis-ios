# iOS vs Android: verschillenlijst

Uitgangspunt: de iOS-app werkt en ziet eruit als de Android-app (`apps/notis-android`).
Afwijken mag alleen waar iOS geen keus laat. ✅ = aangepast in iOS, 🍎 = kan niet anders op iOS.

## Uiterlijk

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 1 | Lettertype Satoshi overal | systeemlettertype | ✅ Satoshi meegeleverd en overal gebruikt |
| 2 | Alleen licht thema | volgde donkere modus van iOS | ✅ altijd licht |
| 3 | Steen als op de website: gradiënt (bone), woord "NOTIS", mandarijn stip, zachte schaduw, zweeft zachtjes | platte steen met NFC-icoon | ✅ zelfde tekening |
| 4 | Vergrendeld: mandarijn gloed achter de steen, stip krijgt een halo | knop werd oranje met slotje | ✅ |
| 5 | Tik op steen: oranje ringen die uitdijen + hint | niets | ✅ |
| 6 | Grote status: VRIJ / OP SLOT / PAUZE (44pt, vet) | kleine zin | ✅ |
| 7 | "met <steen>" in mandarijn, timer dun en 70% | "Vergrendeld met …" + timer | ✅ |
| 8 | Zwevende pilvormige navigatiebalk onderaan: Mijn NOTIS · Home · Instellingen; verborgen tijdens slot (zichtbaar bij noodpauze) | knopjes rechtsboven, schermen als pop-up | ✅ |
| 9 | Vergrendeld: hele scherm inkt (#2B2A27), statusbalk licht | idem, maar kleuren anders | ✅ zelfde palet (DarkLockColors) |
| 10 | Kleuren: primary #C4612B, kaarten #FBFAF7 met dunne rand, radius 18/28 | systeemlijsten | ✅ |

## Beginscherm

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 11 | Noodontgrendeling via ronde knop onderaan (72pt, slot-open-icoon, "nog N"), 1 s ingedrukt houden met trillingen | lang drukken op de steen | ✅ |
| 12 | Bevestigen in onderblad: "Je hebt 5 minuten toegang … / Nog N noodontgrendelingen over" + "Ontgrendelen bevestigen" | systeemdialoog | ✅ |
| 13 | Noodpauze: achtergrond #DEDACE, "PAUZE", "Terug over m:ss", knop "Blokkeren hervatten" | ander kleurschema | ✅ |
| 14 | Geen toestemming: kaart "Toestemmingen aanzetten" i.p.v. status | eigen kaart boven de steen | ✅ |
| 15 | Teksten vrij: "Tik op de steen om te zien hoe het werkt" / "Koppel je NOTIS om te kunnen blokkeren" | eigen teksten | ✅ (🍎 op iOS start tikken ook de scan, dus de hint zegt dat) |
| 16 | Na scannen een melding "Apps op slot" / "Apps weer vrij" | niets | ✅ in het NFC-venster van iOS |
| 16a | Bedenktijd: 30 seconden na vergrendelen een ronde knop "Annuleren" met aflopende ring, op de plek van de noodknop | – | ✅ |
| 16b | Steen ingedrukt houden → onderblad "Op slot met welk profiel?" met je profielen (en klassen; alleen als je een steen hebt), hint "Of houd de steen ingedrukt om een profiel te kiezen"; ontgrendelen alleen met een steen | – | ✅ (klassen pas als `schoolLive` aan staat) |
| 17 | Onbekende steen: "Deze steen is niet gekoppeld" | eigen tekst | ✅ |

## Mijn NOTIS

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 18 | Tab met kop "Mijn NOTIS" + "Je profielen en stenen" + (i)-knop met uitleg "Hoe werken de stenen?" ("Elke steen start een profiel") | pop-up met lijst | ✅ |
| 19 | Kopje **Profielen**: kaart per profiel (apps-icoon, naam, "3 apps toegestaan" / "Alles geblokkeerd" / "Nu op slot", ⋮-menu Hernoemen, Verwijderen; tik = apps wijzigen), knop "Nieuw profiel" (naam, dan meteen de apps). Kopje **Stenen**: kaart per steen (kleine steen, naam, "Start <profiel>", ⋮-menu Hernoemen, Verwijderen; tik = onderblad "Profiel voor <steen>") | lijst → detailscherm | ✅ |
| 19b | Profiel verwijderen: vraag "<naam> verwijderen?"; de stenen ervan starten voortaan het bovenste profiel; het laatste profiel blijft; niet tijdens een slot. Een steen verwijderen laat zijn profiel staan | – | ✅ |
| 20 | Grote knop "Nieuwe NOTIS koppelen", geen maximum aantal stenen | klein knopje, geen max | ✅ |
| 21 | Scankaart "Wachten op je NOTIS…" → "NOTIS gekoppeld!" | alleen iOS-venster | ✅ succeskaart na het scannen |
| 22 | Nieuwe steen: onderblad "Je nieuwe NOTIS", naam, "Welk profiel start deze steen?" met de profielen, knop "Koppelen". Zonder profiel: "Deze steen krijgt een nieuw profiel", knop "Apps kiezen" (nieuw profiel "Standaard") | formulier | ✅ |
| 23 | Lege staat: kaart met grote steen, "Nog geen NOTIS gekoppeld" | tekstregel | ✅ |
| 24 | Voettekst "Tik op een profiel om de apps te wijzigen, of op een steen om te kiezen welk profiel hij start. Met elke steen kun je het slot weer openen." | ontbrak | ✅ |
| 25 | Steen "herschrijven" (NFC-gegevens opnieuw op de steen zetten) | – | 🍎 niet nodig: iOS leest alleen het chip-ID |

## App-keuze

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 26 | Eigen lijst met app-namen, zoeken, populair | Apple's keuzescherm | 🍎 Apple geeft geen app-namen; alleen hun keuzescherm kan |
| 27 | Geen maximum | teller "x / 50" + waarschuwing | ✅ teller en waarschuwing weg |
| 28 | Titel "Toegestane apps" | geen titel | ✅ |

## Instellingen

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 29 | Kop "Instellingen" (28pt) | navigatietitel | ✅ |
| 30 | Kaart "Meldingen" met schakelaar (melding tijdens sessie) | ontbrak | ✅ schakelaar = melding op het toegangsscherm (Live Activity) |
| 31 | SYSTEEM: "Toestemmingen" ("Alles aan" / "… ontbreekt"), "Privacybeleid", "Over NOTIS v…" | eigen secties | ✅ |
| 32 | Geen sectie noodontgrendeling (zit in sessie-instellingen, verborgen) | wel een sectie | ✅ weg |
| 33 | SCHOOL & OUDERS: school, gekoppelde ouders (ontkoppelen), "Ouder koppelen" (code) | placeholders | ✅ (`parentControls`). Klassen blijven uit (`schoolLive`): lokalen vervangen ze |
| 33a | "Ik ben docent" / "Ik ben ouder"; ouder: inloggen of account aanmaken, kind toevoegen met code, live status, kind verwijderen, apps van het kind kiezen | alleen docent | ✅ 🍎 een iPhone kan geen app-lijst doorgeven: de ouder ziet bij een iPhone-kind alleen de status, en de tekst op de iPhone zegt dat |
| 33b | Verborgen beheerderslogin (7× op "Over NOTIS"), "Stenen voorbereiden" (zegel schrijven, omzetten persoonlijk ↔ school, vergrendelen optioneel), "Stenen koppelen" | – | ✅ 🍎 iOS opent per scan een NFC-venster, dus stenen gaan één voor één met een knop in plaats van in een doorlopende reeks |

## Onboarding

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 34 | 4 stappen: Welkom ("Tik. Focus. Klaar.") → Toestemmingen → "Zo stel je je NOTIS in" (1 Maak bij Mijn NOTIS een profiel met de apps die je mag gebruiken, 2 Tik op Nieuwe NOTIS koppelen en houd je telefoon (iOS: iPhone) tegen je steen, 3 Kies welk profiel je steen start; knop "Aan de slag" naar Home). Er wordt geen leeg profiel vooraf gemaakt. De stappen Apps en scannen staan uit achter `onboardingApps` en `onboardingPairing` | geen onboarding | ✅ |
| 35 | Toestemmingen: 3 Android-rechten | – | 🍎 iOS heeft er één: Schermtijd |
| 36 | Eerste steen krijgt de apps van de app-stap (alleen als die stap aan staat) | – | ✅ (bewaard tot je de eerste steen koppelt) |

## Blokkeerscherm

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 37 | "Blijf gefocust!" / "<app> staat nu op slot. Tik met je telefoon op je NOTIS om hem weer vrij te geven." / "Oké" | "Even niet" / eigen tekst / "Terug" | ✅ |
| 38 | Achtergrond inkt, knop mandarijn | idem | ✅ |
| 39 | Melding tijdens sessie | Live Activity met Foqos-naam en -logo | ✅ NOTIS-naam, -logo en -kleur |

## Profielen los van stenen (schakelaar `stoneProfiles`, Android `STONE_PROFILES`)

Een profiel is een lijst toegestane apps met een naam; elke steen start het profiel dat je ervoor kiest.

- **Opslag.** Een profiel is een `BlockedProfiles` met `NotisStoneBlockingStrategy` (het verborgen schoolprofiel niet meegeteld). De stenen van een profiel zijn zijn NFC-items (`physicalUnblockItems`, naam + chip-ID), dus een steen hoort altijd bij precies één profiel: het profiel dat hij start. Een andere keuze verplaatst het item. Zie `Foqos/Notis/BlockedProfiles+NotisProfiles.swift`. Android bewaart hetzelfde als `nfc_tags.profileId`.
- **Scannen.** `findNotisStone(withTag:)` zoekt het profiel waar de steen in zit; de melding noemt de steen ("Apps op slot · met Bureau").
- **Bestaande stenen.** Vroeger was elke steen een profiel met één item en dezelfde naam. Dat is nu een profiel met de naam van de steen en dezelfde apps, zonder migratie. Android geeft zijn verborgen lijsten bij de eerste start eenmalig de naam van hun steen, zodat beide er hetzelfde uitzien.
- **Verschillen.** Geen: alleen de app-keuze gaat via Apple's eigen scherm. Op iOS is "Mijn NOTIS" tijdens een slot alleen-lezen (op Android is het tabblad dan verborgen). Schakelaar uit: het oude `MijnNotisView` met een lijst per steen.

### Profiel kiezen op Home (schakelaar `homeProfilePicker`, Android `HOME_PROFILE_PICKER`)

- Bovenaan Home een balk in de stijl van de navigatiebalk met het gekozen profiel (icoon, "Profiel", naam, pijltje); tik = lijst van profielen. 🍎 Op iOS een systeemmenu, op Android een uitklaplijst.
- Elke gekoppelde steen gaat op slot met het gekozen profiel; elke steen ontgrendelt. Lang indrukken op de steen: "Handmatig op slot" met het gekozen profiel.
- Stenen hebben geen eigen profiel meer: bij koppelen alleen een naam, op de kaart "Gekoppeld", tik = hernoemen.
- De keuze staat in UserDefaults (`notis.selectedProfileId`); is dat profiel weg, dan geldt het bovenste.
- Profielen hebben een icoon (12 vaste iconen, zelfde volgorde als Android), te kiezen in het blad "Nieuw profiel" / "Profiel bewerken". 🍎 Op iOS in UserDefaults (`notis.profileIcons`), omdat het Foqos-model er geen veld voor heeft; Android heeft de kolom `profiles.icon`.

### Geen koppelen (schakelaar `anyNotisStone`, Android `ANY_NOTIS_STONE`)

- Elke steen met een geldig zegel "persoonlijk" (`StoneSeal`) zet op slot met het gekozen profiel en weer vrij, zonder koppelen. Het tabblad heet "Profielen" (was Mijn NOTIS) en toont alleen de profielen; "Nieuw profiel" is de hoofdknop (mandarijn).
- Een schoolsteen gaat nooit op slot met je eigen profiel ("Dit is een schoolsteen: die zet je niet op slot met je eigen profiel"); een gewone NFC-chip geeft "Dit is geen NOTIS-steen". Eerder gekoppelde stenen blijven werken.
- Productie blijft gelijk: "Stenen voorbereiden" schrijft het zegel, "Stenen koppelen" koppelt schoolstenen aan een lokaal.

## Instellingen: ouder, docent, gegevens wissen

- Uitgelogd: eerst "Ik ben ouder", dan "Ik ben docent".
- "Ouder koppelen" toont de koppelcode ook als QR-code (`ParentLinkQR`, tekst `NOTIS-OUDER:<code>`, gelijk aan Android); "Kind toevoegen" heeft "QR-code scannen" (de bestaande QR-scanner van de app). Android en iPhone scannen elkaars code.
- "Kind toevoegen" vraagt ook de naam van de ouder ("Mama"); het kind ziet die bij Instellingen (`guardian_name`, migratie `20261105000000_guardian_name.sql`; zonder migratie koppelt het zonder naam).
- 🍎 Op Android is de lijst van een gekoppelde ouder het enige profiel van het kind, met de naam van de ouder. Op een iPhone kan een ouder geen app-lijst zetten (een iPhone geeft zijn apps niet door), dus houdt het kind zijn eigen profielen en ziet de ouder alleen de status.
- Eén rode knop "Mijn gegevens wissen" onderaan. Met een ingelogde ouder verwijdert die ook het ouderaccount, na het typen van WISSEN. Docenten en NOTIS-beheerders zien de knop niet; een beheerder verwijdert hen. De aparte knop "Account verwijderen" staat achter `separateAccountDelete` (uit).

## Avondslot (schakelaar `bedtimeLock`, Android `BEDTIME_LOCK`)

- Instellingen → Avondslot (onder Meldingen): een lijst tijden als Apple's wekkers (grote tijd, dagen en profiel, schakelaar), "+" voor een nieuwe, zoveel als je wilt. Per dag staat er één tijd aan: een tijd aanzetten of bewaren zet andere tijden op dezelfde dag uit (die blijven bewaard); een stip onder een dag toont dat er al een tijd aan staat. Op die tijd gaat de telefoon op slot met het profiel; alleen een steen haalt hem eraf.
- 🍎 iOS: de tijdkiezer is Apple's eigen draaiwiel (Android heeft er een nagebouwd). Het slot start via de Schermtijd-monitor (`NotisBedtimeActivity`, één apparaatactiviteit per weekdag, ook met de app dicht); Android gebruikt een exacte systeemwekker. Beide draaien alleen op de telefoon.
- Een tijd die je instelt nadat hij vandaag al voorbij is, slaat vandaag over. Het einde van de activiteit (16 minuten later, iOS wil minstens 15) doet niets.

## Kan niet anders op iOS

- Scannen kan alleen nadat je in de app op de steen tikt (Android scant altijd op de achtergrond).
- App-keuze gaat via Apple's eigen scherm, zonder app-namen voor NOTIS.
- Eén toestemming (Schermtijd) in plaats van drie.

## Lokalen (stappenplan-lokalen.md, schakelaar `rooms`)

| # | Android | iOS | Status |
|---|---|---|---|
| 40 | Eerste tik op een schoolsteen: "Je zit op … Wat is je naam?", daarna op slot in dat lokaal | zelfde vraag als onderblad | ✅ (8b) |
| 41 | Lokaalsteen: lock + inchecken; ander lokaal = verhuizen; zelfde lokaal = ontgrendelen; eigen steen ontgrendelt geen schoolslot | zelfde regels | ✅ (8b) |
| 42 | Scannen met de app dicht (NDEF op de steen) | eerst op de steen in de app tikken | 🍎 iOS laat apps geen tags lezen op de achtergrond |
| 43 | Status melden bij elke wijziging, met wachtrij en hartslag elke 15 min (WorkManager) | melden bij lock, unlock, verhuizen en elke keer dat de app opent | 🍎 geen betrouwbare achtergrondtaak; docent ziet sneller ❓ (nog te beslissen) |
| 44 | Eindtijd: sessiewekker beëindigt het schoolslot | Schermtijd-planning (strategie-timer) beëindigt het | ✅ (8b), minimaal 15 minuten vooruit |
| 45 | Schoollijst: Android-pakketten, leerling kan alleen uitzetten | leerling kiest zelf in Apples keuzescherm met de lijst ernaast; aantal en categorie gaan mee | 🍎 (8c) |
