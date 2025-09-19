# PiSignage - Digital Signage Solution for Raspberry Pi
# Makefile for automation and development

.PHONY: help install uninstall test clean build deploy start stop status logs

# Default target
help:
	@echo "PiSignage - Digital Signage Solution"
	@echo "Available targets:"
	@echo "  install     - Install PiSignage on the system"
	@echo "  uninstall   - Remove PiSignage from the system"
	@echo "  test        - Run tests"
	@echo "  clean       - Clean temporary files and logs"
	@echo "  build       - Build docker images for development"
	@echo "  deploy      - Deploy to production"
	@echo "  start       - Start PiSignage services"
	@echo "  stop        - Stop PiSignage services"
	@echo "  status      - Show service status"
	@echo "  logs        - Show service logs"

# Installation
install:
	@echo "Installing PiSignage..."
	sudo ./deploy/install.sh

uninstall:
	@echo "Uninstalling PiSignage..."
	sudo ./deploy/uninstall.sh

# Testing
test:
	@echo "Running tests..."
	./tests/run-tests.sh

# Cleanup
clean:
	@echo "Cleaning temporary files..."
	rm -rf logs/*.log
	rm -rf media/temp/*
	find . -name "*.tmp" -delete
	find . -name "*.pid" -delete

# Docker development
build:
	@echo "Building Docker images..."
	docker-compose build

# Production deployment
deploy:
	@echo "Deploying to production..."
	./deploy/deploy-web-server.sh

# Service management
start:
	@echo "Starting PiSignage services..."
	sudo systemctl start vlc-signage
	sudo systemctl start nginx
	sudo systemctl start php8.2-fpm

stop:
	@echo "Stopping PiSignage services..."
	sudo systemctl stop vlc-signage
	sudo systemctl stop nginx
	sudo systemctl stop php8.2-fpm

status:
	@echo "PiSignage Service Status:"
	@echo "========================"
	@sudo systemctl status vlc-signage --no-pager -l || true
	@echo ""
	@sudo systemctl status nginx --no-pager -l || true
	@echo ""
	@sudo systemctl status php8.2-fpm --no-pager -l || true

logs:
	@echo "PiSignage Logs:"
	@echo "==============="
	@echo "VLC Service:"
	@sudo journalctl -u vlc-signage --no-pager -n 20 || true
	@echo ""
	@echo "Application Logs:"
	@tail -n 20 logs/*.log 2>/dev/null || echo "No application logs found"

# Development helpers
dev-start: build
	docker-compose up -d

dev-stop:
	docker-compose down

dev-logs:
	docker-compose logs -f