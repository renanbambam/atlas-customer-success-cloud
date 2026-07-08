# Enterprise Salesforce Architecture Specification

This document defines the authoritative enterprise architecture...

(See body below)

## Principles

- Native Salesforce first
- SOLID
- Clean Code
- Apex Enterprise Patterns
- DDD adapted
- Repository, Selector, Service, Factory, Strategy, DTO, Trigger Handler
- Security by default
- Bulkification
- Metadata-driven

## Layers

Presentation (LWC)
Controller
Service
Domain
Selector
Repository
Integration
Infrastructure

## Security

OWD, Sharing Rules, Permission Sets, CRUD/FLS, stripInaccessible, WITH SECURITY_ENFORCED.

## Async

Queueable, Batch, Scheduled Apex, Platform Events.

## Integrations

REST, Named Credentials, External Credentials.

## Testing

90%+ coverage, TestDataFactory, HttpCalloutMock, async, bulk, permissions.

## DevOps

SFDX, GitHub Actions, PMD, Salesforce Code Analyzer.

## Rule

Generate architecture first, then implementation. Do not hallucinate. Never invent unsupported Salesforce features. Validate every architectural decision against official Salesforce capabilities.
