# espotifai

Clon personal de Spotify conectado a YouTube. Busca canciones, arma tu biblioteca y descarga MP3 directamente a tu servidor.

---

## Stack

| Capa          | Tecnología                                       |
|---------------|--------------------------------------------------|
| Frontend      | HTML · CSS (shadcn/ui tokens) · Vanilla JS (SPA) |
| Backend       | Node.js · Express                                |
| Descarga      | yt-dlp                                           |
| Búsqueda      | YouTube Data API v3                              |
| Base de datos | JSON local (`server/data/library.json`)          |

---

## Estructura

```
espotifai/
├── index.html
├── css/
│   └── styles.css
├── js/
│   ├── app.js        ← navegación SPA, toasts, importar URL
│   ├── search.js     ← vista búsqueda + grid de resultados
│   └── library.js    ← vista biblioteca + descarga con polling
└── server/
    ├── index.js      ← servidor Express
    ├── db.js         ← base de datos JSON
    ├── .env          ← variables de entorno (no commitear)
    └── routes/
        ├── search.js    GET  /api/search?q=
        ├── library.js   GET|POST|DELETE /api/library
        └── download.js  POST /api/download + estado + archivo
```

---

## Requisitos

- **Node.js** v18 o superior → [nodejs.org](https://nodejs.org)
- **yt-dlp** → [github.com/yt-dlp/yt-dlp](https://github.com/yt-dlp/yt-dlp#installation)
- **YouTube Data API v3 Key** → [console.cloud.google.com](https://console.cloud.google.com)

### Instalar yt-dlp (Windows)

```bash
winget install yt-dlp
```

### Obtener API Key de YouTube

1. Ir a [console.cloud.google.com](https://console.cloud.google.com)
2. Crear un proyecto nuevo
3. Habilitar **YouTube Data API v3**
4. Crear credencial → **API Key**
5. Copiar la clave

---

## Instalación

```bash
# 1. Clonar / descargar el proyecto
cd espotifai/server

# 2. Instalar dependencias
npm install

# 3. Crear el archivo de entorno
cp .env.example .env
```

Editar `server/.env` y poner la API Key:

```env
YOUTUBE_API_KEY=TU_API_KEY_AQUI
PORT=3000
DOWNLOADS_DIR=./downloads
```

---

## Arrancar

```bash
cd server
npm run dev
```

Abrir en el navegador: **http://localhost:3000**

---

## API Reference

| Método   | Ruta                                | Descripción                                           |
|----------|-------------------------------------|-------------------------------------------------------|
| `GET`    | `/api/ping`                         | Health check                                          |
| `GET`    | `/api/search?q=query&maxResults=12` | Buscar videos en YouTube                              |
| `GET`    | `/api/library`                      | Listar biblioteca                                     |
| `POST`   | `/api/library`                      | Agregar track `{ videoId, title, author, thumbnail }` |
| `DELETE` | `/api/library/:videoId`             | Eliminar track                                        |
| `POST`   | `/api/download`                     | Iniciar descarga `{ videoId, format }` → `{ jobId }`  |
| `GET`    | `/api/download/status/:jobId`       | Estado y progreso de descarga                         |
| `GET`    | `/api/download/file/:videoId`       | Descargar el archivo guardado                         |

---

## Flujo de uso

```
Buscar → agregar a biblioteca → descargar MP3 → guardar en /server/downloads/
```

1. **Buscar** — escribe un artista o canción, aparece el grid de resultados
2. **Agregar** — click en *Agregar* → el track se guarda en la biblioteca
3. **Descargar** — en *Biblioteca*, click en el ícono de descarga → yt-dlp procesa el audio
4. **Guardar** — cuando el estado cambia a *Descargado*, click en guardar para obtener el MP3
5. **Importar URL** — pega un enlace directo de YouTube para agregar sin buscar

---

## Scripts disponibles

```bash
npm start      # producción
npm run dev    # desarrollo con --watch (auto-reload)
```

---

## Variables de entorno

| Variable          | Requerida | Default       | Descripción                     |
|-------------------|-----------|---------------|---------------------------------|
| `YOUTUBE_API_KEY` | ✅         | —             | Clave de YouTube Data API v3    |
| `PORT`            | ❌         | `3000`        | Puerto del servidor             |
| `DOWNLOADS_DIR`   | ❌         | `./downloads` | Carpeta de archivos descargados |
