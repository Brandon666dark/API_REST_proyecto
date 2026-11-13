# Proyecto Naruto (2do Parcial)

App Flutter que consume la API REST Dattebayo (https://dattebayo-api.onrender.com) usando solo GET.

## Ejecutar
1. Dentro de esta carpeta: `flutter create .`
2. `flutter pub get`
3. `flutter run`

Android: agrega `<uses-permission android:name="android.permission.INTERNET"/>`
en `android/app/src/main/AndroidManifest.xml` (arriba de `<application>`).

Nota: la API está en un servidor gratuito; la primera petición puede tardar ~30 s en "despertar".
