# 13. Edit Profile Screen

## Cél

A felhasználó szerkeszthető profiladatainak módosítása, valamint profilkép kiválasztása a galériából vagy webes fájlválasztóból.

## UI Elemek

- **AppBar:** "Edit profile" cím és vissza gomb.
- **Profilkép:** Kattintható kör alakú avatar, galéria ikon és előnézet.
- **Choose from gallery:** Mobilon megnyitja a galériát, weben fájlválasztót nyit.
- **Remove profile picture:** Törli a kiválasztott vagy korábban mentett profilképet.
- **Email address:** Csak olvasható mező.
- **Username:** Szerkeszthető felhasználónév, legfeljebb 30 karakter.
- **Annual reading goal:** Egész számként megadható éves könyvcél.
- **Save changes:** Elmenti a módosításokat és visszatér a Profile képernyőre.

## Működés / Logika

- **Adatbetöltés:** A `users/{uid}` dokumentumból tölti be az `email`, `username`, `readingGoal` és `profileImage` mezőket.
- **Képkiválasztás:** Az `image_picker` csomag `ImageSource.gallery` forrását használja.
- **Előnézet:** A kiválasztott kép `MemoryImage` segítségével azonnal megjelenik mentés előtt.
- **Képfeltöltés:** Mentéskor a `ProfileImageService` feltölti a képet a Cloudinary `libris_profile_images` unsigned presetjével.
- **Méretkorlát:** Legfeljebb 5 MB-os kép tölthető fel.
- **Képtárolás:** A Cloudinary által visszaadott HTTPS URL a meglévő `profileImage` String mezőbe kerül.
- **Mentett mezők:** Csak a `username`, `readingGoal` és `profileImage` mezők frissülnek.
- **Adatmodell:** A képernyő nem hoz létre `displayName`, `bio` vagy `updatedAt` mezőt.

## Validáció

- **Username:** Legalább 3 karakter; csak betű, szám, pont, aláhúzás és kötőjel használható.
- **Reading goal:** Egész szám, 0 és 1000 között.
- **Profile image:** A kiválasztott fájl nem lehet üres és legfeljebb 5 MB lehet.

## Állapotok

- **Loading:** Profiladatok betöltése alatt `CircularProgressIndicator`.
- **Selecting image:** A profilképen kis folyamatjelző jelenik meg.
- **Saving:** A Save gomb letiltódik és folyamatjelzőt mutat.
- **Error:** Kiválasztási, Cloudinary- vagy Firebase-hiba esetén `SnackBar`.

## Screenshotok

![Edit Profile Screen](../screenshots/16_edit_profile.jpg)
