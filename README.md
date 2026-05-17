# infrax

Production-grade infrastructure blueprints for real-world applications.

`infrax` is a practical collection of deployment architectures for monolithic apps, Dockerized systems, Kubernetes workloads, and microservices platforms.

## Goal

Build a clear infrastructure reference for moving any project from a simple server setup to modern containerized and distributed deployments.

## Blueprints

```txt
├── monolith/
└── microservices/
```

### Monolith

Single-server production setup.

Typical stack:

* Nginx
* SSL
* UFW
* Fail2ban
* PHP / Node / Python / Rust apps
* MySQL / PostgreSQL
* Redis
* Queue workers
* Scheduler
* Backups

### Monolith Docker

Docker Compose based deployment for production-like environments.

Typical services:

* App
* Web server
* Database
* Cache
* Queue worker
* Scheduler
* Admin tools

### Monolith K8s

Kubernetes deployment for scalable monolithic applications.

Typical resources:

* Deployment
* Service
* Ingress
* ConfigMap
* Secret
* PersistentVolume
* Job
* CronJob
* HPA

### Microservices

Distributed architecture for large-scale systems.

Typical components:

* API Gateway
* Auth Service
* User Service
* Billing Service
* Notification Service
* Message Broker
* Observability
* Service discovery

## Philosophy

Start simple.
Scale cleanly.
Automate everything.
Keep infrastructure understandable.

## Status

Experimental but production-minded.

This repository is intended to evolve into a practical infrastructure lab for real-world deployment patterns.
