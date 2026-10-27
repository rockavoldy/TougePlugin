# Touge Plugin

A plugin for Assetto Corsa servers for **touge** racing with an elo system. Designed for competitive head-to-head driving with a configurable format. Find some live example servers running the plugin [here](https://assetto.scratchedclan.nl/servers).

---

## Features

- **Touge Format**: Race head-to-head in alternating lead/chase roles.
- **Various Rulesets**: Based on KaidoBattleNet rulesets.
- **Fully Configurable**: Tweak rules and behavior through a generated config file.

---
## Installation

- **Download the plugin**  
    _(Download link will be added here soon)_
- **Extract it**  
    Place the contents into your server's `plugins` directory.
- **Run your server once**  
    This will generate configuration files inside the `cfg` folder.
- **Customize your ruleset**  
    Edit the generated `plugin_touge_cfg.yml` and `touge_course_setup.yml` to adjust setting to your liking.

---

## Configuration

---
### `touge_course_setup.yml`
Defines the courses (start positions and optional finish lines) per track. The file is a YAML
map keyed by track, then by course name. On startup the plugin takes your server's current
track name (the last path segment of the full track name) and looks it up under `Tracks`.

- **Positions/headings** — get them with [comfy map](https://www.overtake.gg/downloads/comfy-map.52623/).
- **Finish lines** — use the object inspector app: Alt + click where you want the point in 3D
  space and copy the value labeled `clicked_at`.
- Finish lines are optional if `UseTrackFinish` is set to `true` in `plugin_touge_cfg.yml`;
  otherwise every course must define a `FinishLine` with exactly two points.
- Configurations for different tracks can all live in the same file.
- If the file is missing, the plugin writes a sample file and refuses to start.

```yaml
Tracks:
  pk_gunma_cycle_sports_center-gcsc_full_attack_1:
    Courses:
      "Full Attack 1":
        FinishLine:
          - [-199.7, 467.3, -87.7]
          - [-199.7, 467.3, -87.7]
        StartingSlots:
          - Leader:
              Position: [-199.7, 467.3, -87.7]
              Heading: -16
            Follower:
              Position: [-195.3, 467.0, -83.1]
              Heading: -17
  imola:
    Courses:
      "Imola 1":
        FinishLine:
          - [-199.7, 467.3, -87.7]
          - [-199.7, 467.3, -87.7]
        StartingSlots:
          - Leader:
              Position: [-199.7, 467.3, -87.7]
              Heading: -16
            Follower:
              Position: [-195.3, 467.0, -83.1]
              Heading: -17
```

**Structure notes:**
- `FinishLine` is a list of exactly two `[x, y, z]` points. Only `x` and `z` are used (the
  `y`/height component is discarded) to build the 2D finish line.
- Each `StartingSlots` entry needs a `Leader` and a `Follower`, each with a `Position`
  (`[x, y, z]`) and an integer `Heading`.
- Course names must be at most 32 characters.

---
### `plugin_touge_cfg.yml`
The main plugin configuration. The server generates this file (plus
`plugin_touge_cfg.reference.yml`, the authoritative list of every field with its default) the
first time it runs. Key names are **case-sensitive** and must match the field names below
exactly.

#### Elo

##### `CarPerformanceRatings`
**Type:** `Dictionary<string, int>`  
**Default:** `{ ks_mazda_miata: 125, ks_toyota_ae86: 131 }`  
**Description:** Performance rating per car model (internal model name, e.g.
`ks_mazda_miata`). Each value must be between **1** and **1000**. Used in Elo calculations so
winning in a faster car against a slower car awards less Elo (and vice versa).  
**Example:**
```yaml
CarPerformanceRatings:
  ks_mazda_miata: 125
  ks_toyota_ae86: 131
```

##### `MaxEloGain`
**Type:** `int`  
**Default:** `32`  
**Description:** Maximum Elo gained or lost in a single race. Must be a positive integer.

##### `ProvisionalRaces`
**Type:** `int`  
**Default:** `20`  
**Description:** Number of initial races a player is treated as "provisional". Must be greater
than 0.

##### `MaxEloGainProvisional`
**Type:** `int`  
**Default:** `50`  
**Description:** Maximum Elo gain/loss while a player is still provisional. Must be greater
than 0.

#### Race Setup

##### `IsRollingStart`
**Type:** `bool`  
**Default:** `false`  
**Description:** `true` = rolling start (cars are moving at the start); `false` = stationary
start.

##### `CourseOutrunTime`
**Type:** `float` (seconds)  
**Default:** `1.5`  
**Description:** In **course races**, how long the chase car has to cross the finish line after
the lead car finishes. Must be between **1** and **60** seconds.

##### `UseTrackFinish`
**Type:** `bool`  
**Default:** `true`  
**Description:** `true` = use the track's built-in finish line; `false` = use the finish lines
defined in `touge_course_setup.yml`. When `false`, every course must define a `FinishLine`.

##### `RuleSetType`
**Type:** `enum`  
**Default:** `BattleStage`  
**Description:** The ruleset used for the touge sessions.  
**Valid values:** `BattleStage`, `CatAndMouse`

##### `OutrunLeadTimeout`
**Type:** `int` (seconds)  
**Default:** `120`  
**Description:** In **outrun races**, the leader also wins if they hold the lead for this long.
Must be a positive integer.

##### `OutrunLeadDistance`
**Type:** `int` (meters)  
**Default:** `750`  
**Description:** In **outrun races**, the leader wins by outrunning the chaser by this
distance. Must be a positive integer.

##### `EnableOutrunRace`
**Type:** `bool`  
**Default:** `false`  
**Description:** Allow players to challenge others to outrun races.

##### `EnableCourseRace`
**Type:** `bool`  
**Default:** `true`  
**Description:** Enable course races (races with a defined finish line). At least one of
`EnableCourseRace` / `EnableOutrunRace` must be `true`.

#### HUD & Extras

##### `DiscreteMode`
**Type:** `bool`  
**Default:** `false`  
**Description:** Only show the HUD when necessary; hidden otherwise.

##### `SteamAPIKey`
**Type:** `string` (optional)  
**Default:** none  
**Description:** Steam Web API key used to load player avatars. Do not share it. Leave empty to
disable avatars.

#### Database

##### `IsDbLocalMode`
**Type:** `bool`  
**Default:** `true`  
**Description:** `true` = use a local SQLite database (`plugins/TougePlugin/database.db`); no
external DB needed. `false` = use PostgreSQL via `PostgresqlConnectionString`.

##### `PostgresqlConnectionString`
**Type:** `string` (optional)  
**Default:** none  
**Description:** PostgreSQL connection string. Required only when `IsDbLocalMode` is `false`.
Provides data persistence and multi-server support in non-local setups.  
**Example:**
```yaml
PostgresqlConnectionString: "Host={IP/URL};Port={Port};Username={Username};Password={Password};Database={Database name}"
```

#### Full example

```yaml
CarPerformanceRatings:
  ks_mazda_miata: 125
  ks_toyota_ae86: 131
MaxEloGain: 32
ProvisionalRaces: 20
MaxEloGainProvisional: 50
IsRollingStart: false
CourseOutrunTime: 1.5
UseTrackFinish: true
RuleSetType: BattleStage
OutrunLeadTimeout: 120
OutrunLeadDistance: 750
EnableOutrunRace: false
EnableCourseRace: true
DiscreteMode: false
SteamAPIKey: null
IsDbLocalMode: true
PostgresqlConnectionString: null
```

> The server always writes `plugin_touge_cfg.reference.yml` with every field and its current
> default. For exact serialized defaults, check that file rather than this README.

---

## Notes

- Requires Content Manager with recent version of CSP enabled.
- This is a AssettoServer plugin.
	- Tested on [v0.0.55-pre45](https://github.com/compujuckel/AssettoServer/releases/tag/v0.0.55-pre45)
	- Requires .NET 11 SDK to build (matches the AssettoServer pre45 toolchain).
- UI and other plugin features may evolve — stay tuned for updates.
- See [ARCHITECTURE.md](ARCHITECTURE.md) for a detailed description of the flow and internals.

  ## Planned features
  - More rulesets.
  - Improved lap/course validation to prevent cheating.

