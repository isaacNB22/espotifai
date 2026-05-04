# espotifai

Clon personal de Spotify conectado a YouTube. Busca canciones, arma tu biblioteca, descarga MP3 y escucha en streaming directamente desde el servidor.

---

## Stack

| Capa            | Tecnología                                       |
|-----------------|--------------------------------------------------|
| Frontend        | HTML · CSS (shadcn/ui tokens) · Vanilla JS (SPA) |
| Backend         | Node.js · Express                                |
| Descarga/Stream | yt-dlp                                           |
| Búsqueda        | YouTube Data API v3                              |
| Base de datos   | JSON local (`server/data/library.json`)          |

---

## Estructura

```
espotifai/
├── index.html
├── .gitignore
├── css/
│   ├── base.css
│   ├── components.css
│   ├── layout.css
│   ├── player.css
│   ├── profile.css
│   └── utils.css
├── js/
│   ├── app.js        ← navegación SPA, toasts, importar URL
│   ├── import.js     ← importar canciones por URL
│   ├── library.js    ← vista biblioteca + descarga con polling
│   ├── player.js     ← reproductor de audio
│   └── search.js     ← vista búsqueda + grid de resultados
├── views/
│   ├── import/
│   ├── library/
│   ├── search/
│   └── stats/
└── server/
    ├── index.js      ← servidor Express
    ├── db.js         ← base de datos JSON
    ├── quota.js      ← control de cuota de API
    ├── .env          ← variables de entorno (no subir al repo)
    ├── .env.example  ← plantilla de variables de entorno
    ├── data/         ← biblioteca y cuotas (generado, no subir)
    ├── downloads/    ← archivos de audio descargados (no subir)
    └── routes/
        ├── search.js    GET  /api/search?q=
        ├── library.js   GET|POST|DELETE /api/library
        ├── download.js  POST /api/download + estado + archivo
        └── stream.js    GET  /api/stream/:videoId
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

Editar `server/.env` y completar los valores:

```env
YOUTUBE_API_KEY=TU_API_KEY_AQUI
PORT=3000
DOWNLOADS_DIR=./downloads
```

> `server/.env` está en `.gitignore` y nunca se sube al repositorio.

---

## Arrancar

```bash
cd server
npm run dev
```

Abrir en el navegador: **http://localhost:3000**

---

## API Reference

| Método   | Ruta                                | Descripción                                             |
|----------|-------------------------------------|---------------------------------------------------------|
| `GET`    | `/api/ping`                         | Health check                                            |
| `GET`    | `/api/search?q=query&maxResults=12` | Buscar videos en YouTube                                |
| `GET`    | `/api/library`                      | Listar biblioteca                                       |
| `POST`   | `/api/library`                      | Agregar track `{ videoId, title, author, thumbnail }`   |
| `DELETE` | `/api/library/:videoId`             | Eliminar track                                          |
| `POST`   | `/api/download`                     | Iniciar descarga `{ videoId, format }` → `{ jobId }`    |
| `GET`    | `/api/download/status/:jobId`       | Estado y progreso de descarga                           |
| `GET`    | `/api/download/file/:videoId`       | Descargar el archivo guardado                           |
| `GET`    | `/api/stream/:videoId`              | Stream de audio (local si está descargado, proxy si no) |

---

## Flujo de uso

```
Buscar → agregar a biblioteca → reproducir / descargar MP3
```

1. **Buscar** — escribe un artista o canción, aparece el grid de resultados
2. **Agregar** — click en *Agregar* → el track se guarda en la biblioteca
3. **Reproducir** — el reproductor hace streaming desde el servidor (no requiere descarga previa)
4. **Descargar** — en *Biblioteca*, click en el ícono de descarga → yt-dlp procesa el audio en background
5. **Guardar** — cuando el estado cambia a *Descargado*, click en guardar para obtener el MP3
6. **Importar URL** — pega un enlace directo de YouTube para agregar sin buscar

---

## Scripts disponibles

```bash
npm start      # producción
npm run dev    # desarrollo con --watch (auto-reload)
```

---

## Variables de entorno

| Variable          | Requerida | Default       | Descripción                          |
|-------------------|-----------|---------------|--------------------------------------|
| `YOUTUBE_API_KEY` | ✅         | —             | Clave de YouTube Data API v3         |
| `PORT`            | ❌         | `3000`        | Puerto del servidor                  |
| `DOWNLOADS_DIR`   | ❌         | `./downloads` | Carpeta donde se guardan los MP3/MP4 |

---
