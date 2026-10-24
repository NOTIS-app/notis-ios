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
| 16b | Knop "Op slot zonder tikken" → onderblad "Op slot met welke steen?" met je stenen (en klassen); ontgrendelen alleen met een steen | – | ✅ (klassen pas als `schoolLive` aan staat) |
| 17 | Onbekende steen: "Deze steen is niet gekoppeld" | eigen tekst | ✅ |

## Mijn NOTIS

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 18 | Tab met kop "Mijn NOTIS" + "Elke NOTIS blokkeert zijn eigen apps" + (i)-knop met uitleg "Hoe werken de stenen?" | pop-up met lijst | ✅ |
| 19 | Kaart per steen: kleine steen, naam, "3 apps toegestaan" / "Alles geblokkeerd", ⋮-menu (Hernoemen, Verwijderen); tik = apps wijzigen | lijst → detailscherm | ✅ |
| 20 | Grote knop "Nieuwe NOTIS koppelen", geen maximum aantal stenen | klein knopje, geen max | ✅ |
| 21 | Scankaart "Wachten op je NOTIS…" → "NOTIS gekoppeld!" | alleen iOS-venster | ✅ succeskaart na het scannen |
| 22 | Nieuwe steen: onderblad "Je nieuwe NOTIS", naam, keuze "Nieuwe apps kiezen" / "Zelfde als X", knop "Apps kiezen" | formulier | ✅ |
| 23 | Lege staat: kaart met grote steen, "Nog geen NOTIS gekoppeld" | tekstregel | ✅ |
| 24 | Voettekst "Tik op een steen om de apps te wijzigen. Met elke steen kun je het slot weer openen." | ontbrak | ✅ |
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
| 33 | Klas & ouders (SCHOOL_LIVE) | placeholders | ⏸ staat bewust uit op iOS (schakelaar `schoolLive` / `parentControls`) |

## Onboarding

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 34 | 4 stappen: Welkom ("Tik. Focus. Klaar.") → Toestemmingen, daarna meteen de app. Stenen koppelen en apps kiezen gebeurt bij Mijn NOTIS (de stappen Apps, "Koppel je NOTIS straks" en scannen staan achter `onboardingApps`, `onboardingPairLater` en `onboardingPairing`) | geen onboarding | ✅ |
| 35 | Toestemmingen: 3 Android-rechten | – | 🍎 iOS heeft er één: Schermtijd |
| 36 | Eerste steen krijgt de apps van de app-stap (alleen als die stap aan staat) | – | ✅ (bewaard tot je de eerste steen koppelt) |

## Blokkeerscherm

| # | Android | iOS (was) | Status |
|---|---|---|---|
| 37 | "Blijf gefocust!" / "<app> staat nu op slot. Tik met je telefoon op je NOTIS om hem weer vrij te geven." / "Oké" | "Even niet" / eigen tekst / "Terug" | ✅ |
| 38 | Achtergrond inkt, knop mandarijn | idem | ✅ |
| 39 | Melding tijdens sessie | Live Activity met Foqos-naam en -logo | ✅ NOTIS-naam, -logo en -kleur |

## Kan niet anders op iOS

- Scannen kan alleen nadat je in de app op de steen tikt (Android scant altijd op de achtergrond).
- App-keuze gaat via Apple's eigen scherm, zonder app-namen voor NOTIS.
- Eén toestemming (Schermtijd) in plaats van drie.
