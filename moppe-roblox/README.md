# Moppe Garage för Roblox

En Roblox-version av webbspelet i `../moppe/`. Samma motormodell, temperatur, ekonomi, delar och stegringsfysik, omskrivet i Luau.

## Kom igång (utan några verktyg)

1. Öppna **Roblox Studio** och logga in.
2. Arkiv → Öppna från fil → välj `Moppe.rbxlx` i den här mappen.
3. Tryck **Play**. Världen (garage, väg, bana, hus, träd) byggs när spelet startar.
4. Klicka **Åk ut** i panelen till höger.

### Sparning

Pengar och delar sparas med Roblox DataStore. I Studio behöver du slå på det:
Game Settings → Security → **Enable Studio Access to API Services**. Utan det fungerar spelet men inget sparas (det står i spelet).
Publicera spelet (Arkiv → Publish to Roblox) för att spara på riktigt.

### Snyggare ljus (rekommenderas)

Välj Lighting i Explorer och sätt **Technology = Future**. Det kan inte sättas från ett skript.

## Kontroller

| Tangent | Gör |
|---|---|
| W / ↑ | Gas |
| S / ↓ | Broms |
| A / D | Styr |
| Shift | Luta bakåt och rycka (stegring). Balansera med gas och broms |
| K | Starta motorn (startar själv när du sätter dig) |
| X | Stäng av motorn |
| Q / E | Växla (DT 50) |
| R | Tillbaka till garaget |
| G | Visa/dölj panelen |
| B | Butiken |
| Mellanslag | Kliv av mopeden (Roblox standard) |

Bromsen ligger bara på S, eftersom Mellanslag är Robloxs "hoppa av" och inte går att använda som broms.

## Vad som finns

- Tre mopeder byggda av delar: Jogga 50, Aerox 50 och Enduro DT 50. Strålkastaren lyser på riktigt, det kommer avgasrök efter gasen och hjulen snurrar.
- **Världen:**
  - Roblox Terrain med gräs, kullar och en sjö med riktigt vatten.
  - Ett stort garage på 24 × 16 m och 5 m i takhöjd, med tegelväggar, stålbalkar, hängande lampor, rullport, fönster, moppelyft, arbetsbänk, verktygsvagn, hyllor, däck, kompressor, oljefat och ett kontorshörn.
  - Väg med trottoarkant, trottoar och gatlampor, en rundbana med röd-vita kantstenar och svenska hus med skorsten, staket och brevlåda.
- Motormodell, CVT/växlar, temperatur med överhettning och kolvskär, stegring med momentbalans och vurpor. Allt är samma kod som webben, och testat mot den (se nedan).
- Ekonomi: 5 kr per 100 m, 40 kr per 2 km ren körning, stegringsbonus (max 400 kr/min), reparationer, köpa och sälja delar och mopeder.
- Butik med 3D-förhandsvisning av varje del och beräknad hk-skillnad för din moped. Förråd, montering och trimning (munstycke, porttiming, rullvikt), samt lack och startnummer.

## Fusk och säkerhet

- **Pengar:** Servern bestämmer alltid över pengarna.
- **Körsträcka:** Servern mäter den själv från mopedens position, högst 40 m/s och bara när du sitter på mopeden med motorn igång.
- **Köp, montering och trimning:** Servern kontrollerar allt (pris, att delen passar, intervall).
- **Stegringar:** Servern räknar ut belöningen själv och kollar att den faktiskt såg mopeden röra sig under stegringen.
- **Svagheter:** Själva stegringsvinkeln och motorskadan räknas på spelarens dator, eftersom det är den som styr mopedens fysik. En fuskare kan alltså ljuga om en stegring (men inte om mer än 400 kr/min) eller dölja motorskador.

## Testat och inte testat

**Testat utan Roblox** (`tests/`, kör `npm install` och sedan `npm test` i den mappen):

- Alla 11 skriptfiler parsar och använder inga okända globala namn.
- Spellogiken (motor, åkning, temperatur, stegring, ekonomi, sparning) har körts i en Lua-motor med 33 tester:
  - Effekten är samma som webben: 3,4 / 3,9 / 3,9 hk, och race-Jogga 9,9 hk.
  - Accelerationen och toppfarten är samma som webben, till exempel Jogga 0–30 km/h på 4,0 s och topp 58 km/h.
  - Temperaturen är samma som webben: Jogga cirka 176°C efter 10 minuter fullgas, och motorn svalnar när den är avstängd.
  - Köp, montering, sälj, reparation, taket för stegringsbonus och avdrag vid vurpa fungerar.
  - Spara och ladda ger samma profil, och en trasig sparning ger en giltig profil.

**Inte testat:** Ingenting har körts i Roblox Studio.
- **Det kan fortfarande finnas fel** i hur världen, mopederna, gränssnittet och fysiken ser ut och beter sig i Roblox.
- **Mest osäkert är körkänslan.** Mopeden styrs med en LinearVelocity i markplanet och en AlignOrientation för riktning, lutning och stegring.

## Kända begränsningar

- **Mopedernas form:** De är byggda av vanliga Roblox-delar. Aerox-modellen från webben (OBJ) går inte att lägga in från ett skript. Den måste laddas upp som MeshPart i Studio.
- **Ingen daglig utmaning** och ingen import av egen katalog. Det finns i webbversionen men inte här än.
- **Demobutik:** Tillverkare och priser är påhittade och betalas med spelpengar.

## Utveckla vidare

- Källkoden ligger i `src/`: `shared` (moduler), `server` och `client`.
- Med Rojo: `rojo serve` i den här mappen och Rojo-pluginet i Studio.
- Utan Rojo: kör `python3 tools/build_place.py` för att bygga om `Moppe.rbxlx`.
- **Hålla i synk:** Logiken som även finns i webbspelet (motor, ekonomi, åkning) ligger i `src/shared/Engine.lua`, `Economy.lua` och `RideSim.lua`. Ändra båda versionerna samtidigt om du ändrar siffror.
