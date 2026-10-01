# binclean – hemsida med bokning och dashboard

- `index.html` – kundsidan där man bokar en dag.
- `admin.html` – din dashboard (bokningar, körlista, ekonomi). Kräver inloggning.
- `supabase.sql` – databasen. Körs en gång i Supabase.
- `config.js` – här klistrar du in dina Supabase-nycklar.

Allt är gratis att komma igång med. Det tar ungefär 15 minuter och går att göra i Safari.

## 1. Skapa databasen (Supabase)

1. Gå till <https://supabase.com>, skapa ett konto och klicka **New project**.
   Välj region **Stockholm (eu-north-1)** om den finns. Spara databaslösenordet.
2. När projektet är klart: öppna **SQL Editor → New query**, klistra in hela
   innehållet i `supabase.sql` och tryck **Run**.
3. Skapa ditt eget inloggningskonto: **Authentication → Users → Add user → Create new user**.
   Skriv din e-post och ett starkt lösenord och bocka i **Auto Confirm User**.
4. Gör kontot till administratör. I **SQL Editor**, kör (byt till din e-post):

   ```sql
   insert into public.admins (user_id)
   select id from auth.users where email = 'din@epost.se';
   ```
5. Stäng av att andra kan skapa konton: **Authentication → Sign In / Providers →**
   slå av **Allow new users to sign up**.
6. Hämta nycklarna: **Project Settings → API**. Kopiera **Project URL** och
   **anon public**-nyckeln och klistra in dem i `config.js`.
   Använd aldrig nyckeln som heter `service_role`.

## 2. Lägg upp sidan (Netlify)

1. Gå till <https://app.netlify.com>, skapa konto och logga in med GitHub.
2. **Add new site → Import an existing project → GitHub** och välj repot `wixe123/wixe123`.
3. Ställ in:
   - **Branch to deploy:** den gren som innehåller mappen `binclean`
   - **Base directory:** `binclean`
   - **Build command:** lämna tomt
   - **Publish directory:** `binclean`
4. Klicka **Deploy**. Du får en adress som `https://något.netlify.app`.
5. Byt namn under **Site configuration → Change site name**, t.ex. `binclean`
   → `https://binclean.netlify.app`.
6. Egen domän (valfritt): köp t.ex. `binclean.se` hos Loopia eller One.com och lägg till den
   under **Domain management** i Netlify.

Kundsidan: `https://binclean.netlify.app`
Dashboard: `https://binclean.netlify.app/admin.html`

## 3. Lägg dashboarden på hemskärmen (iPhone)

Öppna `…/admin.html` i Safari → dela-knappen → **Lägg till på hemskärmen**.

## Bra att veta

- Priset räknas ut i databasen (125 kr/tunna, 240 kr för två, −15 % för abonnemang).
  Ändrar du priset: uppdatera både `shared.js` och funktionen `bokning_fore_insert` i `supabase.sql`
  och kör om den delen i SQL Editor.
- Kunder får ingen bekräftelse via e-post automatiskt. Du ser bokningen i dashboarden.
- Gratisplanen i Supabase pausar projekt efter en veckas inaktivitet. Så länge sidan används
  händer det inte, och du kan starta det igen med ett klick.
