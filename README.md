# espotifai

Clon personal de Spotify conectado a YouTube. App multiplataforma Flutter (Windows, Android, iOS) + backend Node.js.

## Stack

- App: Flutter 3 + Dart + Material 3
- Backend: Node.js + Express
- Descarga/Stream: yt-dlp
- Busqueda: YouTube Data API v3
- Audio: media_kit (libmpv — Windows/Linux/Android/iOS)

## Configuracion

### Backend

    cd server && npm install && node index.js

### App Flutter

    cd app
    flutter pub get
    flutter run -d windows   # Windows (recomendado, requiere Windows)
    flutter run -d android    # Android (requiere emulador o dispositivo)
    # flutter run -d ios      # iOS — requiere Mac con Xcode

> Cambia kBaseUrl en app/lib/services/api_service.dart para apuntar a tu servidor.
