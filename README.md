# NOTIS voor iPhone

NOTIS helpt leerlingen focussen in de les. Bij binnenkomst tikt een leerling met de telefoon
op de NOTIS-steen van het lokaal; de telefoon gaat dan op slot, met alleen de apps die de school
toestaat. Na de les ontgrendelt de leerling op dezelfde steen. De docent ziet wie er in het lokaal
gelocked is.

Meer informatie: [notisapp.nl](https://notisapp.nl) · contact: info@notisapp.nl ·
[privacyverklaring](https://notisapp.nl/privacy.html)

## Hoe het werkt

- Blokkeren gebeurt met Apples Schermtijd-API (Family Controls). NOTIS ziet niet welke apps de
  leerling heeft of kiest; dat blijft op de telefoon.
- De stenen zijn NFC-tags (NTAG213/215/216). De app leest alleen de unieke code van de steen.
- School, lokalen en status lopen via Supabase. Leerlingen hebben een anoniem account en kiezen
  zelf de naam die hun docent ziet.
- Iedere gebruiker kan zijn gegevens wissen in Instellingen.

## Bouwen

Het project bouwt met Xcode 26 (`foqos.xcodeproj`, scheme `foqos`). Builds naar TestFlight lopen
via GitHub Actions; zie [docs/NOTIS-TESTFLIGHT.md](docs/NOTIS-TESTFLIGHT.md). De gelijkschakeling
met de Android-app staat in [docs/NOTIS-IOS-PARITY.md](docs/NOTIS-IOS-PARITY.md).

## Herkomst en licentie

NOTIS voor iPhone is gebaseerd op [Foqos](https://github.com/awaseem/foqos) van Ali Waseem,
uitgebracht onder de MIT-licentie. Mappen en bestandsnamen heten daarom nog `Foqos…`. De
oorspronkelijke licentie staat in [LICENSE](LICENSE) en blijft van toepassing; de app toont hem
onder Instellingen → Open-sourcelicenties.
