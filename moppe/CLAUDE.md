# MOPPE GARAGE – projektöversikt för Claude Code

Svenskspråkigt 3D-spel i webbläsaren (en enda HTML-fil, Three.js r128 från cdnjs, ingen build). Kör: öppna `index.html` i en webbläsare. Användaren heter Love, skriver svenska och vill ha ärlighet om vad som faktiskt är **verifierat** att fungera. Spelet är nu kört i headless Chromium (Playwright, SwiftShader-WebGL, three r128 från npm i stället för cdnjs). Se "Verifierat" nedan.

## Vad som finns
- Tre mopeder (`MOP`): Jogga 50 (skoter, CVT, procedurell modell i `buildScooter`), Aerox 50 (CVT, riktig OBJ-modell inbäddad, `buildAero`), Enduro DT 50 (växlad, 4 steg, enkel boxmodell i `build`).
- Garage (studiobakgrund, golvrutnät, skuggor) och utomhusbana (rundbana, dragstrip, hus, träd, sjö). Tab växlar läge.
- Trimning: delar köps i butiken och monteras i Förrådet (cylinder, avgas, förgasare m.fl.). Reglage för huvudmunstycke, avgasportens timing och rullvikt (intervallen styrs av monterad munstyckes-/rullsats). Dynograf med referenskurva, sparas automatiskt som "före bytet" vid montering.
- Stil: färg på kaross/sadel/fälgar, finish, startnummer. Speglar, skärm, tank, styre, fälgtyp och lyktglas är delar (se Delar).
- Körning: A vänster, D höger, W gas, S/Mellanslag broms, Q/E växla (DT), Ctrl/Shift luta bakåt + ryck (stegring), K kicka igång, X stäng av motorn, R återställ/res upp, M ljud, Tab garage/körning. Esc stänger butiken.
- Panel (förenklad): Åk ut och Butik överst, moped, flikarna Garage / Förråd / Pengar. Garage visar effekt, temp och motorskick, trimningsreglagen, ETT tips åt gången (`#hint`, beräknat i `stats`) och dynon. Detaljer, lack och kameravinklar ligger i hopfällda `<details>`. Ingen Spara-knapp (allt sparas automatiskt).
- HUD: pengar, fart, varvmätare, temp. Hjälpraden är kort, H (eller klick) visar alla tangenter. "Åk ut" startar motorn automatiskt (upp till 3 kickförsök).
- Butik: kategorichips (Motor / Kraftöverföring / Utseende), sök, "Visar delar för min moped", varje kort visar beräknad hk-skillnad för din moped (`effect`, `hpWith`), "Köp och montera" (motorn stängs av automatiskt). Varukorg och fler filter (källa, tillverkare, motor, pris, JSON-import) finns kvar.
- Produktbilder: `partModel` bygger en 3D-modell per deltyp och variant och `renderThumb` renderar den i en egen WebGL-canvas till en data-URL (cache per typ+värden, kö via `fillThumbs`/`thumbRun`). Det är illustrationer, inte produktfoton, och det står i butiken.
- Sparning: automatiskt i `localStorage` `moppe_v2` (validerad, `moppe_v1` förs över, trasig sparning kopieras till `moppe_v2_trasig`).

## Version 2 (Loves prioriteringar 1–7, 2026-10-29)
- **Temperatur** (`TH`, `BAND`, `therm`, `heat`, `tinfo`): luftkylda (Jogga: fläkt, kylning följer varv; DT: fartvind) visar topptemp CHT, vätskekylda Aerox visar kylvätska + beräknad cylindertemp. Start vid utetemp 15°C, svalnar avstängd, kylvätska kokar vid 120°C (kylaren tappar), effekt sjunker över 225°C cylinder, kolvskada över 240°C, kolvskär vid 100 % skada. Alla konstanter är trimvärden.
- **Ekonomi** (`ST`, `book/earn/spend/fine`, `rideTick`): start 2 000 kr, 5 kr/100 m, 40 kr per 2 km ren körning, dagens utmaningar (3 per datum), reparationer (100+900×skada, kolvskär 1 500, gratis nödlagning till 50 % om man inte har råd), köp/sälj mopeder (säljer för 60 %). Betalning per helt block/händelse, aldrig per bildruta. Saldot kan inte bli negativt.
- **Delar** (`PR`, `OEM`, `SLOTS`, `ST.items`, `ST.inst`, `ecfg`): en sanning. Motor- och modellvärden räknas alltid fram ur monterade delar + inställningar (`E=ecfg(cur.id)`). Nya delar med verklig effekt i modellen: insug (stryper förgasare), luftfilter, tändning (varvspärr 11 000 original), variator (högsta utväxling), kopplingsfjädrar (slirvarv), kontrafjäder, rem (slirar över X hk), kylning, munstyckes- och rullsatser (låser upp reglagens intervall), samt synliga skärm/tank/speglar/styre/fälgar/lyktglas.
- **Butik** (`search`, `checkout`, `importCat`): demokatalog med påhittade tillverkare och priser, tydligt märkt. Ingen koppling till moppedelar.se, inga riktiga köp. Egen katalog kan importeras som JSON (`same_as` ger spelkoppling). Köp är allt-eller-inget.
- **Stegring** (`WH`, `wheelie`, `land`, `whValue`): momentbalans kring bakaxeln, föraren lutar bakåt 0,2 m och rycker 400 Nm i 0,3 s, balanspunkt atan(b/h), +8° = vurpa. Bonus = 200×(1−e^(−t/5)) × fart/stabilitet × landning, max 400 kr/min, kräver ≥ 8 km/h och ≥ 0,5 s. Vurpa −50 kr. 0–60-timern mäts i simuleringstid.

## Verifierat version 2 (headless Chromium, Playwright, fast tidssteg)
Testskripten ligger inte i repot. Alla acceptanstester i Loves prioriteringar 1–7 körda och godkända, inga konsolfel. Standardmopedernas acceleration oförändrad (Jogga 0–30 4,0 s). Inte testat: ljud, mus, mobil/touch, andra webbläsare, känslan att balansera en stegring med riktigt tangentbord.


## Kodstruktur (allt i `index.html`)
- Data: `KITS`, `EXH`, `CARB`, `GEARS`, `MOP`, `def()` (standardkonfig per moped). Konfig per moped ligger i `cfgs[id]`, aktuell i `cfg`.
- Motormodell (används av både dyno och körning): `calc(cfg)` -> `P`, `torque(P,rpm)`. Avgasportens timing ger ett naturligt toppvarv, avgasen ett inställt varv, och `match` mäter hur väl de passar. `fuelF` kommer från munstycke mot optimum, `restr/over` från förgasarens storlek, `resp` är gasrespons. `P.hp` = toppeffekt (från kurvan, oberoende av fart).
- CVT: målvarv = `5200+780*(14-roller)+kontrafjäder` (`target()`), utväxling klampas mellan variatorns `rmin` och 2.9, slirvarv vid start = min(målvarv, kopplingsfjädrarnas `slip`). Växlad moped använder `GEARS`.
- Fysik: `step(dt)`. Framåt är **+z**, höger sväng = minskande `S.h`. Stegringen vrids kring bakaxeln via kompenserande offset `S.off`, vinkeln kommer från `wheelie()`.
- Motor av/på: `S.on`, `kick()` (chans beror på `P.fuelF`), `X` stänger av.
- Modeller: `buildScooter` (procedurell), `buildAero` + `initAx()` (läser inbäddad blob i `<script id="axd">`, gzip+base64, avkodas med `DecompressionStream`).
- Kamera: orbit/zoom/pan i garaget (`az/el/dist`, `taz/tel/tdist`, `pan`), jagande kamera vid körning. Förinställda vyer via knappar `[data-cam]`.

## Aerox-modellen
Källa: `aerox.obj` (3ds Max-export, 269 grupper, ~107k punkter, **negativa relativa face-index**, inga material). `tools/embed_aerox.py` tolkar OBJ, sorterar grupper i klasser (paint/seat/dark/metal/ex/hjuldelar), kvantiserar till int16, gzippar och skriver in blobben i `index.html`. Klassningen av grupper är en **gissning från form och placering**, se `CLASSES` i skriptet. Framhjul = grupperna 1530/1529/1528, bakhjul = 1467/1466/1441. Skala = 1.30 m hjulbas / 6.02 modellenheter.

## Verifierat (headless Chromium, 2026-10-29)
- Inga fel i konsolen vid start eller under testkörningen nedan.
- Alla tre mopeder byggs; Aerox-blobben avkodas och modellen visas.
- Kick-start, varvning i garaget, Tab till körning, gas, sväng, Shift-wheelie, broms, X stäng av.
- DT 50 växlar 1–4 och varvet följer farten (≈15/28/37/43 km/h efter 2,5 s per växel, ej stoppur-exakt eftersom headless har låg fps).
- Spara → ladda om sidan → samma moped och konfig. Återställ moped. Färg, finish, startnummer, speglar.
- Inte testat: ljud (headless), mus-orbit/zoom/pan, mobil/touch, Safari/Firefox.

## Rättat
- DT 50: slutväxeln `fd` var 7.2, vilket gav så låg utväxling att kopplingen aldrig greppade och motorn stod på 5500 varv i alla växlar. Nu 12.8 (vald så att 4:an vid 9500 varv ≈ 55 km/h; en speltrimning, inte ett mätt värde).
- Färger: r128 tolkade hex/CSS-färger som linjära med sRGB-utdata, så allt blev blekt och färgväljaren stämde inte (rött blev rosa). `Color.setHex/setStyle` omvandlar nu från sRGB; bakgrunden och startnummertexturen hanteras separat.
- Tangenter: efter att man rört en reglage/lista ignorerades K, W, Tab osv. tills man klickade i 3D-vyn. Nu sväljer bara textfält tangenterna.
- Starten: under slirningen från stillastående låstes varvet till max 8000 (skotrar) och 5500 (DT), oavsett motor. Trimmade motorer med effekt vid 11–12k drog därför SÄMRE från start än standard (race-Jogga 0–20 km/h 3,5 s mot standard 2,4 s). Nu slirar skotrarna på variatorns målvarv (rullvikten) och DT:n på effekttoppen. Simulerat vid 60 fps: race-Jogga 0–20/30/40 = 1,3/1,9/2,6 s, standard oförändrat ≈2,5/4,1/6,8 s.
- Garaget: utomhusmiljön (träd, hus, grön markkant) syntes bakom studion. Den döljs nu i garageläget.

## Kända brister / att verifiera
- Startnummerplattorna på Aerox kan ligga fel. Gruppklassningen kan vara fel (avgas, aluminium).
- Aerox-avgasen byter bara färg, inte form. Aerox har inga löstagbara speglar/kåpor (OBJ-grupperna är sammanslagna).
- Aerox lyfter knappt i stegring ens som racebygge (tyngre, längre hjulbas).
- Spelet räknar i varje bildruta med dt ≤ 0,05 s: under 20 fps går det i slowmotion (syns i headless).
- Racebyggen blir varma (race-Jogga ≈250°C vid fullgas): fetare munstycke eller storflänsat topplock behövs.
- DT 50 är fortfarande enkla boxar.

## Nästa steg (Loves prioritering)
Följande kommer från Loves "Moppe Garage 2.0"-prompt, i denna ordning: (1) detaljerade modeller, (2) ljus, material, kamera, garage, (3) flikar: GARAGE, ENGINE, PORTING, CARBURETOR, TRANSMISSION, EXHAUST, DYNO, CUSTOMIZATION, PARTS SHOP, TEST RIDE med riktiga funktioner, (4) visuell portningsverkstad (tvärsnitt, timingdiagram, port bredd/höjd, squish, före/efter-kurva), (5) bättre svensk miljö och körning, (6) fler modeller (Slider, BW's, DT50, Ciao) med egen delkompatibilitet, (7) dyno, flera sparade byggen (med JSON export/import), delbutik med kompatibilitet och byggkostnad.
Regler: ta inte bort fungerande funktioner, inga döda knappar eller påhittade siffror, skilj mätt (dyno/testkörning) från beräknat, ingen Yamaha-logotyp.
