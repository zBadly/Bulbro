class_name RunStatsConfig
extends Resource
## Run-Statistik und Run-Historie (Phase 15, Paket 5).

## So viele Runs merkt sich der Spielstand (neueste zuerst).
@export var history_size: int = 20
## Stärkste Quellen je Run in der Historie.
@export var history_top_sources: int = 3
## DPS teilt durch mindestens so viele Sekunden Kampfzeit, damit ein einzelner später Treffer keinen Ausreißer ergibt.
@export var min_dps_time: float = 1.0
