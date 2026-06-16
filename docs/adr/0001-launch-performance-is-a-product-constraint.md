# Launch performance is a product constraint

Artisan exists to support short agent-assisted editing sessions, so launch speed is part of the product definition rather than an optimization pass. The MVP target is under 300ms from cold launch to editable cursor, under 100ms from warm launch to editable cursor, and under 50ms of CLI overhead before app handoff; launch should avoid background indexing, language servers, extension loading, network calls, and any other startup work not required to read the requested files.
