# Moppe Mekaniker (Roblox)

Ett mopedmekanikerspel i Roblox. Du har ett eget garage, beställer delar på datorn, väntar på leveransen, packar upp, bygger motorn själv genom att dra delarna på motorblocket, portar cylindern med din egen hand och lackerar kåporna i lackboxen. Sedan kör du ut och testar.

Motorns fysik (effekt, CVT/växlar, temperatur, stegring) är samma kod som webbspelet i `../moppe/`.

## Kom igång

1. Öppna `Moppe.rbxlx` i **Roblox Studio** och tryck **Play**.
2. För att spara i Studio: Game Settings → Security → **Enable Studio Access to API Services**.
3. För snyggast ljus: välj Lighting och sätt **Technology = Future** (går inte att sätta från ett skript).

Du hamnar i ditt eget garage, och ditt namn står på skylten. Upp till 6 spelare får var sitt garage längs industrigatan och kan gå in och titta på varandras byggen.

## Så spelar du

| Var | Vad |
|---|---|
| Delar | Klicka för att plocka upp, och klicka på bänken, hyllan eller lackboxen för att lägga ner. Delen sitter i handen medan du bär den. |
| Datorn | Moppelagret.se: sök, kategorier, produktbilder, lagerstatus, kundvagn och mina ordrar med nedräkning. |
| Leverans | En låda dyker upp utanför garageporten när tiden är ute: 1 del ≈ 1 min, 3–6 delar ≈ 3–5 min, fler ≈ 10 min, och beställningsvaror +2 min. Klicka på lådan för att öppna den. |
| Motorstativet | Motorläge: dra delar från brickan till motorn. Grön markering betyder att delen passar, röd säger vad som måste sitta först. Delen glider på plats och handen skruvar fast den. Högerklick tar bort en del. |
| Mopeden | Klicka på en del eller kåpa för att få **Demontera / Lackera / Byt ut / Inspektera**. Du bär en del och klickar på mopeden för att montera den. "Lyft ur motorn" flyttar motorn till stativet. |
| Portningsbänken | Lägg en cylinder där. Förstapersonsvy med handen och en rak slipmaskin. Slipa de lysande zonerna jämnt. Det finns ett träningsläge. |
| Lackboxen | Lägg en kåpa där. Välj färg (bibliotek, RGB eller HEX) och lacktyp, och spraya med sprutpistolen. Lacken torkar i 20 s. |
| M | Min moppe: status och vad som saknas, munstycke, reparation, **Kör ut**, designer, köp och sälj mopeder. |
| Styling-läget | Stor 3D-vy av mopeden som går att rotera 360° och zooma, med listan över kåporna och designerna. |
| Kör | W gas · S broms · A/D styr · Shift stegring · K starta · Q/E växla (DT) · R tillbaka till garaget · Mellanslag kliv av |

## Vad som finns

- **Motorbygge:**
  - 33 sorters motordelar, var och en med egen 3D-modell och egen fästpunkt.
  - Monteringsordningen gäller åt båda hållen: vevhus → lager → vevaxel → packboxar → nållager → kolv → kolvbult och ringar → fotpackning → cylinder → topplock → tändstift. Insug, tändning och kraftöverföring har egna kedjor.
  - Kolven måste passa cylindern (50/70 cc).
  - Motorn går bara att montera i mopeden när den är komplett.
- **Mopeden:**
  - Ram, gaffel, hjul, bromsar, dämpare, styre, sadel, tank, avgas, kylare och motor går att ta av och byta.
  - Varje kåpa är en egen del med egen färg, och det finns 6–15 kåpor per modell.
  - Där en kåpa saknas syns skruvar och fästpunkter.
  - Mopeden går bara att köra när allt som behövs sitter på.
- **Portning:** Kvaliteten räknas på jämnhet, precision och överportning. Bra arbete ger upp till cirka +10 % vridmoment och högre avgastiming, slarvigt arbete ger sämre effekt. Proffsslipmaskinen ger stadigare hand.
- **Lack:**
  - Färgbiblioteket har Gloss Black, Midnight Blue, Racing Red, Pearl White, Nardo Grey, Candy Purple, Neon Green, Chrome Silver, Metallic Gold med flera.
  - Lacktyperna är blank, matt, metallic, pärlemor och krom.
  - Kvaliteten räknas på täckning, jämnhet och rinningar.
  - Designer sparas med namn och kan läggas på igen.
- **Ekonomi:** Startkapital 4 000 kr. Pengar kommer från körning, ren körning och stegringar, och går till reparationer, delar, verktyg och mopeder. Allt kontrolleras på servern.
- **Världen:**
  - Sex garage (arbetsbänk, motorstativ, portningsbänk, lackbox, hyllor och dator) längs en industrigata.
  - Dragstrip, testbana, industriområde med lager och containrar.
  - Landsväg med åkrar och lada, parkering, bensinmack, svenska hus, granar och björkar, och en sjö.

## Avsiktliga skillnader mot önskemålen

- **Inga riktiga märken:** Yamaha, Stage6, Malossi, Polini, Yasuni, Doppler och andra riktiga varumärken och logotyper kan få spelet borttaget från Roblox. Därför finns påhittade märken (Fartek, Nordtrim, Vippa, Bruksmek, Kylstad, Snabbo, Origo). Butiken heter Moppelagret.se och liknar inte en riktig butik.
- **3 modeller i stället för 8:** Jogga 50, Aerox 50 och Enduro DT 50. Kåpsystemet är gjort så att en ny modell bara är en lista i `src/shared/Panels.lua` (plus positioner).

## Inte gjort än

- **Dekaler** (placera, flytta, rotera, skala).
- **Uppdrag:** bygga åt andra, reparera, leverera.
- **Garageuppgraderingar.**
- **Motorljud:** Det kräver ljudfiler uppladdade till Roblox.
- **Riktiga 3D-modeller:** Allt är byggt av Roblox-delar (lådor, cylindrar, kilar). Riktiga modeller måste laddas upp som MeshParts i Studio.

## Testat och inte testat

- **Spellogik, testad utan Roblox** (`tests/`, kör `npm install` och sedan `npm test`). 47 tester körs i en Lua-motor. De visar att:
  - en originalmoped är komplett och har samma effekt och acceleration som webbspelet;
  - en motor kan tas isär helt (30 delar) och byggas ihop igen, och att fel ordning och fel kolv nekas;
  - leveranstider och lådor, portnings- och lackkvalitet, designer, ekonomin samt spara och ladda fungerar.
- **Syntax och namn:** Alla skriptfiler är kontrollerade för syntax och okända globala namn.
- **Ingenting har körts i Roblox Studio.** Det gäller interaktionen, kamerorna, handen, gränssnittet, modellerna och fysiken. Det finns med stor sannolikhet saker att justera, framför allt positioner, storlekar och kamerans vinklar.

## Utveckla vidare

- `src/shared`: logik och modeller.
  - Testbara moduler: `Config`, `Catalog`, `Panels`, `Assembly`, `Engine`, `Economy`, `RideSim`, `Porting`, `Paint`, `Delivery`.
  - 3D-modeller: `Builder` och `GarageBuilder`.
- `src/server`: `Main` (profiler, garage, API, validering) och `World` (världen).
- `src/client`: `Interact`, `Shop`, `Porting`, `Paint`, `Ride` och `UI`.
- Bygg om `Moppe.rbxlx` med `python3 tools/build_place.py`, eller använd Rojo (`default.project.json`).
