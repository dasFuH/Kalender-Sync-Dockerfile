# Makefile for Calendar Sync MCP Server
# Vereinfacht häufige Docker-Operationen

.PHONY: help build up down restart logs shell test clean oauth-setup

# Farben für Output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Zeige diese Hilfe an
	@echo "$(BLUE)Calendar Sync MCP Server - Docker Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

build: ## Baue Docker Image
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker-compose build

up: ## Starte Container im Hintergrund
	@echo "$(BLUE)Starting containers...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✓ Containers started$(NC)"
	@make logs-tail

down: ## Stoppe und entferne Container
	@echo "$(BLUE)Stopping containers...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ Containers stopped$(NC)"

restart: ## Starte Container neu
	@echo "$(BLUE)Restarting containers...$(NC)"
	docker-compose restart
	@echo "$(GREEN)✓ Containers restarted$(NC)"

logs: ## Zeige alle Logs
	docker-compose logs

logs-tail: ## Zeige Live-Logs
	docker-compose logs -f --tail=100

logs-last: ## Zeige letzte 50 Log-Zeilen
	docker-compose logs --tail=50

shell: ## Öffne Shell im Container
	docker exec -it calendar-sync-mcp-server sh

status: ## Zeige Container-Status
	@echo "$(BLUE)Container Status:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)Resource Usage:$(NC)"
	@docker stats --no-stream calendar-sync-mcp-server 2>/dev/null || echo "Container läuft nicht"

health: ## Prüfe Health Status
	@echo "$(BLUE)Health Check:$(NC)"
	@docker inspect --format='{{.State.Health.Status}}' calendar-sync-mcp-server 2>/dev/null || echo "$(YELLOW)Container läuft nicht oder hat keinen Health Check$(NC)"

rebuild: down build up ## Stoppe, baue neu und starte Container

oauth-setup: ## Erstelle OAuth Token (lokal, nicht in Docker)
	@echo "$(BLUE)OAuth Setup - Erstelle Token lokal...$(NC)"
	@if [ ! -f "oauth-credentials.json" ]; then \
		echo "$(YELLOW)Warnung: oauth-credentials.json nicht gefunden!$(NC)"; \
		echo "Lade zuerst die OAuth Credentials von Google Cloud herunter."; \
		echo "Siehe OAUTH_SETUP.md für Details."; \
		exit 1; \
	fi
	@echo "$(GREEN)Installiere Dependencies...$(NC)"
	npm install
	@echo "$(GREEN)Baue TypeScript...$(NC)"
	npm run build
	@echo "$(GREEN)Starte OAuth Flow...$(NC)"
	node dist/oauth-helper.js
	@echo "$(GREEN)✓ OAuth Token erstellt!$(NC)"

check-credentials: ## Prüfe ob alle Credential-Dateien vorhanden sind
	@echo "$(BLUE)Checking credentials...$(NC)"
	@test -f oauth-credentials.json && echo "$(GREEN)✓ oauth-credentials.json$(NC)" || echo "$(YELLOW)✗ oauth-credentials.json fehlt$(NC)"
	@test -f oauth-token.json && echo "$(GREEN)✓ oauth-token.json$(NC)" || echo "$(YELLOW)✗ oauth-token.json fehlt (erstelle mit 'make oauth-setup')$(NC)"
	@test -f config.json && echo "$(GREEN)✓ config.json$(NC)" || echo "$(YELLOW)✗ config.json fehlt (kopiere von config.example.json)$(NC)"

test: ## Teste das Setup
	@echo "$(BLUE)Testing setup...$(NC)"
	@make check-credentials
	@echo ""
	@if docker-compose ps | grep -q "Up"; then \
		echo "$(GREEN)✓ Container läuft$(NC)"; \
		make logs-last; \
	else \
		echo "$(YELLOW)! Container läuft nicht$(NC)"; \
		echo "Starte mit: make up"; \
	fi

clean: ## Entferne Container, Images und Volumes
	@echo "$(YELLOW)Warnung: Dies entfernt alle Container, Images und Volumes!$(NC)"
	@read -p "Fortfahren? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker-compose down -v; \
		docker image rm calendar-sync-mcp-server 2>/dev/null || true; \
		echo "$(GREEN)✓ Cleanup abgeschlossen$(NC)"; \
	else \
		echo "Abgebrochen"; \
	fi

clean-tokens: ## Lösche OAuth Token (für Neuauthentifizierung)
	@echo "$(YELLOW)Lösche OAuth Token...$(NC)"
	@rm -f oauth-token.json
	@echo "$(GREEN)✓ Token gelöscht$(NC)"
	@echo "Erstelle neues Token mit: make oauth-setup"

backup: ## Erstelle Backup der Credentials
	@echo "$(BLUE)Creating backup...$(NC)"
	@mkdir -p backups
	@BACKUP_DIR=backups/$$(date +%Y%m%d_%H%M%S); \
	mkdir -p $$BACKUP_DIR; \
	test -f oauth-credentials.json && cp oauth-credentials.json $$BACKUP_DIR/ || true; \
	test -f oauth-token.json && cp oauth-token.json $$BACKUP_DIR/ || true; \
	test -f config.json && cp config.json $$BACKUP_DIR/ || true; \
	echo "$(GREEN)✓ Backup erstellt in $$BACKUP_DIR$(NC)"

install: oauth-setup ## Komplettes Setup (OAuth + Config)
	@echo "$(BLUE)Installation wird gestartet...$(NC)"
	@if [ ! -f "config.json" ]; then \
		echo "Erstelle config.json aus config.example.json..."; \
		cp config.example.json config.json; \
		echo "$(YELLOW)⚠ Bitte config.json bearbeiten und deine Kalender eintragen!$(NC)"; \
	fi
	@make check-credentials
	@echo ""
	@echo "$(GREEN)✓ Installation abgeschlossen!$(NC)"
	@echo "Starte Container mit: make up"

# Docker System Commands
prune: ## Entferne ungenutzte Docker-Ressourcen
	@echo "$(YELLOW)Cleaning up unused Docker resources...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ Cleanup abgeschlossen$(NC)"

# Development Commands
dev-install: ## Installiere Node Dependencies
	npm install

dev-build: ## Baue TypeScript lokal
	npm run build

dev-run: ## Führe Server lokal aus (ohne Docker)
	npm run start

dev-watch: ## Entwicklungsmodus mit Auto-Reload
	npm run dev

# Info Commands
info: ## Zeige System-Informationen
	@echo "$(BLUE)=== System Information ===$(NC)"
	@echo "Docker Version: $$(docker --version)"
	@echo "Docker Compose: $$(docker-compose --version)"
	@echo "Node Version: $$(node --version 2>/dev/null || echo 'Not installed')"
	@echo ""
	@echo "$(BLUE)=== Project Files ===$(NC)"
	@make check-credentials
	@echo ""
	@echo "$(BLUE)=== Container Status ===$(NC)"
	@docker-compose ps 2>/dev/null || echo "Keine Container laufen"

version: ## Zeige Version
	@echo "Calendar Sync MCP Server v1.0.0"

# Alias-Befehle für Bequemlichkeit
start: up ## Alias für 'up'
stop: down ## Alias für 'down'
