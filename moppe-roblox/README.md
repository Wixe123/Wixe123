# Moppe Mekaniker (Roblox)

Ett mopedmekanikerspel i Roblox, byggt från grunden. Du har ett eget garage. Där beställer du delar på datorn, väntar på leveransen och öppnar paketet. Sedan bygger du motorn genom att dra delarna till rätt plats, portar cylindern med din egen hand och lackerar kåporna. Till sist kör du ut och testar mopeden.

## Kom igång

1. Öppna `Moppe.rbxlx` i **Roblox Studio** och tryck **Play**.
2. Vill du att det sparas i Studio: Game Settings → Security → **Enable Studio Access to API Services**. Utan det går det att spela, men inget sparas och spelet säger det.
3. Lighting är sparad med **Technology = Future** i filen.

## Så spelar du

| Var | Vad |
|---|---|
| Startmenyn | Spela, Garage, Butik, Statistik, Inställningar |
| Garagemenyn (vänster) | Bygg motor, Porta cylinder, Beställ delar, Lackering, Min moppe och Kör ut. Gubben går själv till rätt station. |
| Moped Info (höger) | Hästkrafter, toppfart, 0–45 km/h, varvtal, temperatur och motorstatus. Allt räknas ut från delarna. |
| Delar i garaget | Klicka på en del för att plocka upp den, så att du bär den i handen. Klicka på hyllan, bänken, golvet, skruvstädet eller lackstativet för att lägga ner den. |
| Datorn (E) | Moppelagret.se: startsida, sökning, kategorier, produktbilder i 3D, produktsidor, lagerstatus och kundvagn. Under fliken Mina ordrar syns nedräkningen till leveransen, och under Uppdrag finns jobben. |
| Leverans | En låda dyker upp vid garageporten. Tryck E för att öppna den. Delarna ligger sedan i lådan och kan plockas upp eller användas direkt. |
| Motorstativet (E) | Dra en del från brickan till motorn. Grön markering betyder att delen passar nu. Röd betyder att något annat måste sitta först, och spelet säger vad. Släpp delen så glider den på plats och en hand drar åt den. Högerklicka på en del för att ta bort den. Det som sitter ovanpå följer med: tar du loss cylindern hamnar topplock, tändstift och tändkabel också på bänken. |
| Mopedlyften (E) | Fungerar likadant för ram, gaffel, hjul, bromsar, dämpare, styre, tank, sadel, avgas och kåpor. Klicka på en del för att få Demontera, Lackera, Byt ut och Inspektera. Med **Meka på motorn här** zoomar kameran in på motorn så att du kan jobba på motorblocket direkt i mopeden. **Lyft ur motorn** flyttar motorn till stativet utan att du behöver ta av bakhjul, bakbroms eller avgas. |
| Kameran i arbetslägena | Dra med musen på tom yta för att snurra 360° runt mopeden eller motorn (högerknappen och piltangenterna fungerar också). Rullhjulet zoomar. |
| Portningsbänken (E) | Spänn fast en cylinder i skruvstädet. Du ser handen med den raka slipmaskinen och de fyra portarna, som lyser. Håll vänster musknapp för att slipa. Kvaliteten räknas på jämnhet, precision och överportning. Det finns också ett träningsläge. |
| Lackboxen (E) | Häng en kåpa på stativet och välj färg: från biblioteket, med RGB-reglage eller med HEX-kod. Välj lacktyp (blank, matt, metallic, pärlemor eller krom) och glans, och spraya. Lacken torkar på 20 s. |
| Kör ut (F vid lyften) | W gas, S broms, A och D styr, Mellanslag kliver av och R tar dig tillbaka till garaget. Hastighetsmätaren visar också varv och temperatur, och det finns en minikarta. |

## Vad som finns

- **Motorn har 29 delar som monteras i ordning.**
  - Motorblock: vevhus, vevlager, vevaxel, packboxar, nållager, kolv, kolvbult, kolvringar, fotpackning, cylinder, topplock och tändstift.
  - Transmission: variator, vikter, fläkt, rem, koppling, kopplingsklocka och bakre remskiva.
  - Insug: reedventil, insug, förgasare, luftfilter och bränsleslang.
  - Tändning: CDI, tändspole, svänghjul, stator och tändkabel.
  - Delar går bara att ta bort i omvänd ordning.
  - Kolv, ringar och cylinder måste ha samma diameter.
- **Prestanda:**
  - Cylindern ger grundeffekten. Förgasare, insug, reed, luftfilter, avgas, vevaxel, CDI, portning och munstycke påverkar den.
  - Delar som är för små för cylindern håller tillbaka effekten.
  - Variatorn, vikterna och kopplingen bestämmer var motorn varvar.
  - Originalmopeden är strypt till ca 46 km/h. En racing-70 går ca 99 km/h.
  - Går motorn för varmt slits kolven, och den kan till slut skära.
- **Tre mopeder (påhittade):** Vippa Citi 50, Sprint 50 och Klassik 50. Varje kåpa är en egen del med egen färg. Saknas en kåpa syns skruvarna.
- **Ekonomi:**
  - Du startar med 4 000 kr. Under 2 000 kr kostar frakten 99 kr.
  - Delar kan säljas för halva priset. Mopeder går att köpa och sälja.
  - Körningen ger 12 kr/km.
  - Lagret är gemensamt för alla spelare och fylls på med tiden.
- **Uppdrag:**
  - Leverera reservdelar till en plats i världen.
  - Byt kolv och ringar på en kunds motor, som ställs på ditt stativ.
  - Bygg en trimmad motor åt en kund.
- **Multiplayer:** Upp till 6 spelare får var sitt garage längs Garagegatan, med namnet på skylten. Du kan gå in och titta hos andra, men inte arbeta där.
- **Världen:**
  - Stan längs Storgatan och Macken.
  - Stormarknaden med parkering.
  - Industriområdet med containrar och hamnen.
  - Landsvägen till Lindgården.
  - Testbanan med läktare och en dragstrip på 400 m.
- **Designer:** I Min moppe kan du spara färgerna på alla kåpor som en design och lägga på den igen senare.

## Avsiktliga skillnader mot önskemålen

- **Inga riktiga märken eller logotyper.** Yamaha, Malossi, Polini, Stage6, Yasuni, Doppler, Dellorto, Naraku och andra riktiga varumärken kan få spelet borttaget från Roblox, och det står i projektets egna regler att Yamaha-logga inte ska användas. I stället finns påhittade märken: Vippa, Origo, Fartek, Nordtrim, Snabbo, Kylstad, Gasström och Bruksmek. Butiken heter Moppelagret.se.
- **Motorljud saknas.** Ljud kräver ljudfiler som är uppladdade till Roblox.
- **Dekaler saknas.**
- **Garageuppgraderingar saknas.**
- **Hjälp i andras garage saknas.** Andra spelare kan bara titta.
- **Inga importerade modellfiler.** Kåporna är riktiga 3D-mesher med rundade former, men de skapas i spelet med Robloxs EditableMesh (`src/shared/MeshGen.lua` och `src/client/MeshSkin.client.lua`), så inga filer behöver laddas upp. Om Roblox inte tillåter EditableMesh i ditt spel (det kan kräva att kontot är verifierat för publicerade spel) visas de kantiga blocken i stället, och Output säger det. Motor, ram och hjul är fortfarande byggda av Roblox-delar.

## Testat och inte testat

- **Spelregler** (`tests/scenarios/logic.lua`, 62 kontroller, alla godkända):
  - profil, montering och demontering av hela motorn i rätt ordning, fel kolvdiameter;
  - butik och leveranstider;
  - portnings- och lackkvalitet;
  - prestanda: original ca 46 km/h, racing-70 ca 99 km/h;
  - uppdrag och sparning.
- **Hela spelet i en Roblox-emulator** (`tests/emu/`):
  - Alla skript körs mot Robloxs API-lista, så felstavade egenskaper, fel värdetyper, skrivskyddade egenskaper och anrop som inte finns ger fel precis som i Roblox.
  - `tests/scenarios/game.lua` spelar igenom spelet med klick, tangenter, E-knappar och dra-och-släpp (54 kontroller, alla godkända, inga skriptfel):
    - beställer, väntar på leveransen och öppnar lådan;
    - byter kolv, ringar och cylinder genom att dra delarna;
    - portar och lackerar;
    - kör ut och levererar ett paket;
    - loggar ut och in igen och ser att allt är sparat.
  - `tests/emu/render.js` gör bilder av vad emulatorn ser, med three.js.
- **Ingenting har körts i riktiga Roblox Studio.** Emulatorn är en efterbildning:
  - Den har ingen riktig fysik, så hur mopeden känns att köra och om gubben fastnar någonstans är inte provat.
  - Text och ljus ser lite annorlunda ut i Roblox.
  - Det finns säkert saker att justera.

Kör testerna: `cd tests && npm install && npm test`. För bilder: `node emu/render.js`.

## Kod

- `src/shared`:
  - Regler och data: `Config`, `Parts`, `EngineDef`, `MopedDef`, `Performance`, `Profile`, `Porting`, `Paint`, `Map`.
  - 3D: `Models` och `GarageBuilder`.
- `src/server`: `Main` (profiler, garage, API med kontroller, leveranser, körning, sparning) och `World` (världen).
- `src/client`:
  - Gemensamt: `State` och `UIKit`.
  - Lägen och skärmar: `Hud`, `Interact`, `Assembly` (motor- och mopedbygge), `Shop`, `Porting`, `Paint` och `Ride`.
- Bygg om `Moppe.rbxlx` med `python3 tools/build_place.py`, eller använd Rojo (`default.project.json`).
