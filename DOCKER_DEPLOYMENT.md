# 🐳 Docker Deployment Guide

Komplette Anleitung zur Verwendung des Calendar Sync MCP Servers mit Docker.

## 📋 Voraussetzungen

- Docker installiert (Version 20.10+)
- Docker Compose installiert (Version 2.0+)
- OAuth Credentials von Google Cloud (siehe OAUTH_SETUP.md)

---

## 🚀 Quick Start

### Option 1: Mit Docker Compose (Empfohlen)

```bash
# 1. OAuth Credentials vorbereiten
# Lade oauth-credentials.json von Google Cloud herunter
# Platziere sie im Projektverzeichnis

# 2. Einmalig OAuth Token erstellen (außerhalb Container)
npm install
npm run build
node dist/oauth-helper.js
# Folge den Anweisungen im Browser
# oauth-token.json wird erstellt

# 3. Container starten
docker-compose up -d

# 4. Logs überprüfen
docker-compose logs -f calendar-sync

# 5. Container stoppen
docker-compose down
```

### Option 2: Mit Docker direkt

```bash
# 1. Image bauen
docker build -t calendar-sync-mcp-server .

# 2. Container starten
docker run -d \
  --name calendar-sync \
  -v $(pwd)/oauth-credentials.json:/app/oauth-credentials.json:ro \
  -v $(pwd)/oauth-token.json:/app/oauth-token.json:rw \
  -v $(pwd)/config.json:/app/config.json:ro \
  -e TZ=Europe/Berlin \
  calendar-sync-mcp-server

# 3. Logs anzeigen
docker logs -f calendar-sync

# 4. Container stoppen
docker stop calendar-sync
docker rm calendar-sync
```

---

## 📁 Verzeichnisstruktur

Stelle sicher, dass du folgende Dateien im Projektverzeichnis hast:

```
calendar-sync-agent/
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── package.json
├── tsconfig.json
├── src/
├── oauth-credentials.json    # Von Google Cloud
├── oauth-token.json          # Auto-generiert
└── config.json               # Deine Kalender-Konfiguration
```

---

## ⚙️ Konfiguration

### 1. OAuth Credentials erstellen

Siehe [OAUTH_SETUP.md](./OAUTH_SETUP.md) für detaillierte Anleitung.

**Kurzversion:**
1. Google Cloud Console → OAuth Client ID erstellen
2. Als Desktop-App konfigurieren
3. JSON herunterladen als `oauth-credentials.json`

### 2. OAuth Token generieren

⚠️ **Wichtig**: Das OAuth Token muss **vor** dem Docker Start erstellt werden, da der Browser-Flow im Container nicht funktioniert!

```bash
# Lokal ausführen:
npm install
npm run build
node dist/oauth-helper.js
```

Dies erstellt `oauth-token.json` im Projektverzeichnis.

### 3. Konfigurationsdatei erstellen

Erstelle `config.json`:

```json
{
  "calendars": [
    {
      "id": "work-calendar",
      "name": "Arbeitskalender",
      "type": "google",
      "credentials": {
        "useOAuth": true
      }
    },
    {
      "id": "personal-calendar",
      "name": "Privater Kalender",
      "type": "ical",
      "url": "https://p01-calendars.icloud.com/published/2/xxx"
    }
  ],
  "syncRules": [
    {
      "source": "work-calendar",
      "targets": ["personal-calendar"],
      "description": "Arbeitstermine in privaten Kalender blocken"
    }
  ]
}
```

---

## 🔧 Docker Compose Konfiguration

### Standard-Setup

Die mitgelieferte `docker-compose.yml` ist produktionsbereit:

```yaml
services:
  calendar-sync:
    build: .
    volumes:
      - ./oauth-credentials.json:/app/oauth-credentials.json:ro
      - ./oauth-token.json:/app/oauth-token.json:rw
      - ./config.json:/app/config.json:ro
    environment:
      - TZ=Europe/Berlin
    restart: unless-stopped
```

### Erweiterte Konfiguration

**Resource Limits anpassen:**

```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'      # Max 1 CPU
      memory: 1G       # Max 1GB RAM
    reservations:
      cpus: '0.5'      # Min 0.5 CPU
      memory: 512M     # Min 512MB RAM
```

**Logging anpassen:**

```yaml
logging:
  driver: "json-file"
  options:
    max-size: "50m"    # Maximale Log-Datei-Größe
    max-file: "5"      # Anzahl rotierter Log-Dateien
```

**Zeitzone ändern:**

```yaml
environment:
  - TZ=America/New_York  # Oder deine Zeitzone
```

---

## 🔄 Container-Management

### Container starten

```bash
# Im Hintergrund starten
docker-compose up -d

# Im Vordergrund (mit Logs)
docker-compose up
```

### Logs anzeigen

```bash
# Alle Logs
docker-compose logs

# Live-Logs (follow)
docker-compose logs -f

# Nur letzte 100 Zeilen
docker-compose logs --tail=100
```

### Container neu starten

```bash
# Sanfter Neustart
docker-compose restart

# Stoppen und neu starten
docker-compose down
docker-compose up -d
```

### Container neu bauen

```bash
# Nach Code-Änderungen
docker-compose build

# Rebuild und starten
docker-compose up -d --build
```

### Container Status prüfen

```bash
# Status aller Services
docker-compose ps

# Detaillierte Infos
docker inspect calendar-sync-mcp-server
```

---

## 🔐 Sicherheit

### Dateiberechtigungen

Der Container läuft als non-root User (`nodejs:1001`). Stelle sicher, dass die Dateien lesbar sind:

```bash
# Berechtigungen setzen
chmod 600 oauth-credentials.json
chmod 644 oauth-token.json
chmod 644 config.json
```

### Sensible Dateien schützen

```bash
# Füge zu .gitignore hinzu:
echo "oauth-credentials.json" >> .gitignore
echo "oauth-token.json" >> .gitignore
echo "config.json" >> .gitignore
```

### Docker Secrets (für Produktion)

Für sensible Produktionsumgebungen verwende Docker Secrets:

```yaml
services:
  calendar-sync:
    secrets:
      - oauth_credentials
      - oauth_token

secrets:
  oauth_credentials:
    file: ./oauth-credentials.json
  oauth_token:
    file: ./oauth-token.json
```

---

## 📊 Monitoring

### Health Check

Der Container hat einen integrierten Health Check:

```bash
# Status prüfen
docker inspect --format='{{.State.Health.Status}}' calendar-sync-mcp-server
```

**Mögliche Status:**
- `starting` - Container startet gerade
- `healthy` - Container läuft normal
- `unhealthy` - Container hat Probleme

### Resource Usage

```bash
# CPU und RAM Verbrauch
docker stats calendar-sync-mcp-server

# Einmalige Ansicht
docker stats --no-stream calendar-sync-mcp-server
```

---

## 🔄 Updates und Wartung

### Image Update

```bash
# 1. Neuen Code pullen
git pull

# 2. Container stoppen
docker-compose down

# 3. Neu bauen
docker-compose build

# 4. Starten
docker-compose up -d
```

### Token erneuern

OAuth Token laufen nicht ab, solange der Refresh Token gültig ist. Falls doch:

```bash
# 1. Container stoppen
docker-compose down

# 2. Token löschen
rm oauth-token.json

# 3. Neu generieren (lokal)
node dist/oauth-helper.js

# 4. Container starten
docker-compose up -d
```

### Cleanup

```bash
# Alte Images entfernen
docker image prune

# Alte Container entfernen
docker container prune

# Alles auf einmal (Vorsicht!)
docker system prune -a
```

---

## 🌐 Multi-Container Setup

### Mehrere Kalender-Sync-Instanzen

Falls du mehrere unabhängige Sync-Agenten benötigst:

```yaml
services:
  calendar-sync-work:
    build: .
    container_name: calendar-sync-work
    volumes:
      - ./work/oauth-credentials.json:/app/oauth-credentials.json:ro
      - ./work/oauth-token.json:/app/oauth-token.json:rw
      - ./work/config.json:/app/config.json:ro

  calendar-sync-personal:
    build: .
    container_name: calendar-sync-personal
    volumes:
      - ./personal/oauth-credentials.json:/app/oauth-credentials.json:ro
      - ./personal/oauth-token.json:/app/oauth-token.json:rw
      - ./personal/config.json:/app/config.json:ro
```

---

## 🐛 Troubleshooting

### Container startet nicht

```bash
# Logs prüfen
docker-compose logs calendar-sync

# Häufige Ursachen:
# - oauth-token.json fehlt
# - oauth-credentials.json fehlt oder ungültig
# - config.json hat Syntax-Fehler
```

### "Permission denied" Fehler

```bash
# Berechtigungen anpassen
chmod 644 oauth-token.json
chown $(id -u):$(id -g) oauth-token.json
```

### OAuth Token ungültig

```bash
# Token neu generieren (siehe oben)
docker-compose down
rm oauth-token.json
node dist/oauth-helper.js
docker-compose up -d
```

### Container läuft, aber Sync funktioniert nicht

```bash
# 1. Container Shell öffnen
docker exec -it calendar-sync-mcp-server sh

# 2. Dateien prüfen
ls -la /app/oauth-*.json

# 3. Test ausführen (wenn möglich)
node dist/oauth-helper.js
```

### Port-Konflikte (bei HTTP Transport)

Falls Port 3000 bereits belegt:

```yaml
ports:
  - "3001:3000"  # Host:Container
```

---

## 🚀 Produktions-Deployment

### Empfohlene Konfiguration

```yaml
version: '3.8'

services:
  calendar-sync:
    build: .
    container_name: calendar-sync-prod
    restart: always  # Automatischer Neustart
    
    volumes:
      - ./oauth-credentials.json:/app/oauth-credentials.json:ro
      - oauth-tokens:/app/tokens:rw  # Named volume
      - ./config.json:/app/config.json:ro
    
    environment:
      - NODE_ENV=production
      - TZ=Europe/Berlin
      - LOG_LEVEL=warn  # Weniger Logs in Produktion
    
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
    
    logging:
      driver: "json-file"
      options:
        max-size: "50m"
        max-file: "5"
    
    healthcheck:
      test: ["CMD", "node", "-e", "console.log('healthy')"]
      interval: 60s
      timeout: 10s
      retries: 5
      start_period: 10s

volumes:
  oauth-tokens:
    driver: local
```

### Backup Strategy

```bash
# Backup wichtiger Dateien
#!/bin/bash
BACKUP_DIR="./backups/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

cp oauth-credentials.json $BACKUP_DIR/
cp oauth-token.json $BACKUP_DIR/
cp config.json $BACKUP_DIR/

echo "Backup erstellt in $BACKUP_DIR"
```

---

## 📝 Best Practices

1. ✅ **Verwende Docker Compose** für einfacheres Management
2. ✅ **Setze Resource Limits** um Ressourcen-Erschöpfung zu vermeinden
3. ✅ **Konfiguriere Logging** mit Rotation
4. ✅ **Verwende Named Volumes** für Token-Persistenz
5. ✅ **Implementiere Health Checks** für Monitoring
6. ✅ **Backup deine Credentials** regelmäßig
7. ✅ **Verwende restart: unless-stopped** für Produktion
8. ✅ **Monitore Container-Logs** regelmäßig

---

## 🔗 Weiterführende Links

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Best Practices für Node.js in Docker](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)

---

Bei Fragen oder Problemen öffne ein Issue im Repository! 🚀
