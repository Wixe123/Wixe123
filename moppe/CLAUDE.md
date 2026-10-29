# MOPPE GARAGE – projektöversikt för Claude Code

Svenskspråkigt 3D-spel i webbläsaren (en enda HTML-fil, Three.js r128 från cdnjs, ingen build). Kör: öppna `index.html` i en webbläsare. Användaren heter Love, skriver svenska och vill ha ärlighet om vad som faktiskt är **verifierat** att fungera. Spelet är nu kört i headless Chromium (Playwright, SwiftShader-WebGL, three r128 från npm i stället för cdnjs). Se "Verifierat" nedan.

## Vad som finns
- Tre mopeder (`MOP`): Jogga 50 (skoter, CVT, procedurell modell i `buildScooter`), Aerox 50 (CVT, riktig OBJ-modell inbäddad, `buildAero`), Enduro DT 50 (växlad, 4 steg, enkel boxmodell i `build`).
- Garage (studiobakgrund, golvrutnät, skuggor) och utomhusbana (rundbana, dragstrip, hus, träd, sjö). Tab växlar läge.
- Trimning: cylinderkit, avgassystem, förgasare (mm), huvudmunstycke, avgasportens timing, rollervikt. Dynograf med referenskurva.
- Stil: färg på kaross/sadel/fälgar, finish, startnummer, speglar (bara Jogga).
- Körning: A vänster, D höger, W gas, S/Mellanslag broms, Q/E växla (DT), Ctrl/Shift wheelie, K kicka igång, X stäng av motorn, R återställ, M ljud, Tab garage/körning.
- Spara/ladda i `localStorage` (nyckel `moppe_v1`).

## Kodstruktur (allt i `index.html`)
- Data: `KITS`, `EXH`, `CARB`, `GEARS`, `MOP`, `def()` (standardkonfig per moped). Konfig per moped ligger i `cfgs[id]`, aktuell i `cfg`.
- Motormodell (används av både dyno och körning): `calc(cfg)` -> `P`, `torque(P,rpm)`. Avgasportens timing ger ett naturligt toppvarv, avgasen ett inställt varv, och `match` mäter hur väl de passar. `fuelF` kommer från munstycke mot optimum, `restr/over` från förgasarens storlek, `resp` är gasrespons. `P.hp` = toppeffekt (från kurvan, oberoende av fart).
- CVT: målvarv = `5200+780*(14-roller)` (`target()`), utväxling klampas mellan 0.85 och 2.9. Växlad moped använder `GEARS`.
- Fysik: `step(dt)`. Framåt är **+z**, höger sväng = minskande `S.h`. Wheelie vrids kring bakaxeln via kompenserande offset `S.off`. Självlyft (gas-wheelie) styrs av `S.acc` över tröskel 2 m/s².
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
- Gas-wheelien lyfter även standardmopeder något vid fullgas från stillastående (Jogga ≈0,1 rad, DT i 1:an ≈0,2 rad efter växelrättningen) eftersom tröskeln 2 m/s² är låg. Inte ändrad, Loves beslut.
- Startnummerplattorna på Aerox kan ligga fel. Gruppklassningen kan vara fel (avgas, aluminium).
- Aerox-avgasen byter bara färg, inte form. Speglarkryssrutan påverkar inte Aerox.
- DT 50 är fortfarande enkla boxar.
- Gas-wheelien är en förenklad approximation med egen tröskel.

## Nästa steg (Loves prioritering)
Följande kommer från hans "Moppe Garage 2.0"-prompt, i denna ordning: (1) detaljerade modeller, (2) ljus, material, kamera, garage, (3) flikar: GARAGE, ENGINE, PORTING, CARBURETOR, TRANSMISSION, EXHAUST, DYNO, CUSTOMIZATION, PARTS SHOP, TEST RIDE med riktiga funktioner, (4) visuell portningsverkstad (tvärsnitt, timingdiagram, port bredd/höjd, squish, före/efter-kurva), (5) bättre svensk miljö och körning, (6) fler modeller (Slider, BW's, DT50, Ciao) med egen delkompatibilitet, (7) dyno, flera sparade byggen (med JSON export/import), delbutik med kompatibilitet och byggkostnad.
Regler: ta inte bort fungerande funktioner, inga döda knappar eller påhittade siffror, skilj mätt (dyno/testkörning) från beräknat, ingen Yamaha-logotyp.
