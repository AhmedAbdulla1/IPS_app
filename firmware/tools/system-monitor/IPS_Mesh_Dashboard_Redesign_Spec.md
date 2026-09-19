# IPS Mesh Monitoring Dashboard — UI/Architecture Redesign Specification

## 1. Purpose

This document is an implementation specification for redesigning the existing **IPS Mesh + OTA Monitoring Dashboard**.

The goal is to evolve the current page from a basic monitoring/OTA screen into a professional **Network Operations Dashboard** for the IPS ESP32 Mesh infrastructure.

The implementation will be done inside the existing project:

```text
D:\IPS_app\IPS_app
```

This document is intended to be given directly to **Antigravity IDE** as the implementation brief.

---

# 2. Important Reference Image

The reference image for the proposed dashboard direction is stored beside this Markdown file.

Use it as a **visual reference for layout, information hierarchy, topology concept, cards, tables, alerts, charts, OTA section, and overall dashboard density**.

It is NOT a requirement to copy the exact visual style of the topology map.

The final topology/map must use the project's existing map style and visual language once that style is identified in the current codebase.

Reference image:

![IPS Mesh Dashboard Reference](./image.png)

### Critical clarification

The topology shown in the reference image is a **concept only**.

Do NOT replace the existing project map design with the generated topology-map style.

The requirement is:

> Keep the user's existing map appearance and adapt the topology/network-monitoring concept to it.

The map visual design is intentionally **not finalized yet**.

Therefore, structure the implementation so the topology rendering can be changed later without rewriting the network-monitoring data/model layer.

---

# 3. Current Architecture Context

The monitoring system is based around:

```text
                    Root / Gateway
                         │
                    Serial / USB
                         │
                      Laptop
                         │
                    Monitoring UI
                         │
                  ESP-NOW Mesh
              ┌──────────┼──────────┐
              │          │          │
             Node       Node       Node
              │
             Node
              │
             Node
```

The Root is the gateway connected to the monitoring application.

Other ESP32 nodes communicate through the ESP-NOW mesh and may be multiple hops away from the Root.

Therefore the dashboard must understand:

- Node
- Root
- Parent node
- Hop count
- Network path
- Node status
- Last seen
- RSSI / link quality when available
- Firmware version
- Network events
- OTA state

The dashboard must be designed for the future scale of the project, including potentially hundreds or 1000+ nodes.

---

# 4. Most Important Requirement: Node Status Must NOT Depend on First Connection

## Current problem

The current dashboard appears to wait until a node actually connects/reports through the live monitoring channel before it can show that node as online/offline.

This is not acceptable for the final dashboard.

Example:

If the database already contains:

```text
Node A
Node B
Node C
Node D
```

and the monitoring application starts while only Node A has reported live data, the dashboard should NOT behave as if:

```text
Total Nodes = 1
```

Instead, it should know that the infrastructure contains:

```text
Total Nodes = 4
```

and determine the current state of each node from the available database/infrastructure data.

---

# 5. Supabase Must Be Used as the Initial Infrastructure Source

The project already contains a Supabase navigation datasource:

```text
D:\IPS_app\IPS_app\lib\features\navigation\data\datasources\supabase_navigation_datasource.dart
```

## IMPORTANT

Before implementing a new Supabase access layer, inspect this file and the models/repositories/services it uses.

Reuse the existing project's:

- Supabase client setup
- table access patterns
- models
- field names
- error handling
- dependency injection
- existing data access conventions

Do NOT create a second unrelated Supabase architecture if the required infrastructure data can be accessed through the existing architecture.

---

# 6. Node Coordinates Already Exist in the Database

Every node has:

```text
x
y
```

coordinates stored in the database.

This is important for the monitoring dashboard.

These coordinates can be used to place the nodes on the monitoring map/topology visualization.

However:

## Do NOT assume the database schema

The implementation must first inspect:

```text
supabase_navigation_datasource.dart
```

and the related models/schema usage to determine:

- table name
- node identifier field
- x field
- y field
- floor/building relationship
- node name/label
- any existing status fields
- any existing last-seen fields
- any other infrastructure metadata

Use the actual existing project schema.

Do not invent duplicate columns or rename existing fields unless there is a real requirement.

---

# 7. Separate Infrastructure Data from Live Mesh Data

The dashboard should conceptually combine two types of information.

## A. Infrastructure / Static Data

Source:

```text
Supabase
```

Examples:

- Node ID
- Node name
- X coordinate
- Y coordinate
- Building
- Floor
- Zone
- Room / location
- Other existing node metadata

This tells the dashboard:

> What nodes are supposed to exist?

## B. Live Mesh Data

Source:

```text
Root → Serial → Monitoring Application
```

Examples:

- Online/offline state
- Last seen
- RSSI
- Hop count
- Parent
- Firmware version
- Mesh events
- OTA progress
- Network diagnostics

This tells the dashboard:

> What is happening to those nodes right now?

---

# 8. Required Status Model

The UI should NOT equate:

```text
Node exists in live data
```

with:

```text
Node exists in the infrastructure
```

Instead, conceptually:

```text
Infrastructure Nodes
        +
Live Mesh State
        ↓
Unified Node Monitoring Model
        ↓
Dashboard
```

For example:

```text
Node exists in Supabase
+
No live heartbeat yet
=
Known Node / status determined from available database state
```

If the database contains a reliable status/last-seen field, use it.

If the database does not contain such a field, do not invent a fake status. Inspect the current project data model and define the live-state fallback explicitly in code.

The important architectural requirement is:

> The dashboard must know the complete infrastructure population before live packets begin arriving.

---

# 9. Recommended Data Flow

Implement the dashboard around a unified monitoring state.

Conceptually:

```text
                 Supabase
                    │
                    │
          Infrastructure Nodes
                    │
                    ▼
            Node Repository
                    │
                    │
Root ── Serial ── Live Mesh Data
                    │
                    ▼
          Mesh Monitoring Service
                    │
                    ▼
            Unified Node State
                    │
          ┌─────────┼─────────┐
          ▼         ▼         ▼
       Dashboard  Map       Alerts
```

The UI should consume the unified state rather than directly reading serial packets everywhere.

---

# 10. Dashboard Main Layout

The main dashboard should have this hierarchy:

```text
┌──────────────────────────────────────────────────────────┐
│ HEADER                                                   │
│ Network Status | Root | COM | Time | Firmware           │
├──────────────────────────────────────────────────────────┤
│ KPI │ KPI │ KPI │ KPI │ KPI │ KPI                        │
├──────────────────────────────────────┬───────────────────┤
│                                      │                   │
│          MESH / NETWORK MAP          │ ALERTS / EVENTS   │
│                                      │                   │
│                                      │                   │
├──────────────────────────────────────┴───────────────────┤
│                    NODE HEALTH TABLE                     │
├──────────────────────────────────────┬───────────────────┤
│                                      │                   │
│       NETWORK PERFORMANCE            │ OTA DEPLOYMENT    │
│       Charts                         │                   │
│                                      │                   │
├──────────────────────────────────────┴───────────────────┤
│                    SERIAL / JSON LOG                     │
└──────────────────────────────────────────────────────────┘
```

The actual proportions should be responsive.

---

# 11. Header

The header should clearly show:

- Overall network connection status
- Root connection status
- Serial/COM connection
- Current time / last update
- Current firmware
- Building/site if available
- Dashboard title

Example:

```text
● Connected     Root Connected     COM9     Last Update 17:32:45
```

The header should make it immediately obvious whether the monitoring application itself is connected to the Root.

---

# 12. KPI Cards

The first row should summarize the network.

Required cards:

### Total Nodes

Number of infrastructure nodes known from the database.

This MUST NOT depend on the number of nodes that have already reported live packets.

### Online Nodes

Number currently considered online according to the unified monitoring state.

### Offline Nodes

Number currently considered offline/unreachable according to the project's status/timeout logic.

### Warnings

Nodes with degraded conditions.

### Maximum Hop

Highest hop count currently observed.

### Current Firmware

Current/deployed firmware version.

Additional useful KPI:

### Network Health

A percentage derived from actual monitoring metrics.

Do not hardcode a fake health score.

### Average RSSI

Average RSSI of currently reporting nodes when RSSI data is available.

If RSSI is not available, show an explicit unavailable state rather than a fabricated value.

---

# 13. Mesh Topology / Monitoring Map

This is one of the most important sections.

The dashboard needs a visual representation of the network.

However:

## DO NOT COPY THE EXACT MAP STYLE FROM THE REFERENCE IMAGE

The reference image only demonstrates the concept.

The existing project already has a map/design language.

Use the existing project map style.

The monitoring layer should add network information on top of that map.

---

# 14. Node Positioning on the Map

Since every node already has X/Y coordinates in Supabase:

```text
Node
 ├── x
 └── y
```

use those coordinates to position the node visually.

The map layer should conceptually be:

```text
Existing Map
      +
Node Coordinates
      +
Mesh State
      +
Network Links
      ↓
Monitoring Map
```

This allows the dashboard to show the actual physical arrangement of nodes instead of generating an arbitrary graph layout.

---

# 15. Important Map Architecture Rule

Separate:

### Physical Position

```text
x
y
floor
building
```

from:

### Network Relationship

```text
parent
hop
RSSI
link quality
```

This is critical.

A node can be physically close to another node but still use another parent.

Therefore:

```text
Node position ≠ Network topology
```

The renderer should support both layers.

---

# 16. Map Layers

The monitoring map should support at least:

### Layer 1 — Base Map

The existing project map.

### Layer 2 — Nodes

Nodes positioned using their database coordinates.

### Layer 3 — Status

Visual state:

```text
Online
Warning
Offline
Unknown / Not yet observed
```

### Layer 4 — Mesh Links

Draw parent/child relationships when live topology information is available.

### Layer 5 — Hop Count

Show hop count visually or in the node detail.

### Layer 6 — Alerts

Allow problematic nodes to be visually highlighted.

---

# 17. Topology Link Representation

The link visualization should communicate link quality.

Conceptually:

```text
Strong      ━━━━━
Medium      ─────
Weak        - - - -
Lost        × × ×
```

The exact colors/style should follow the project's existing UI theme.

Do not hardcode the reference image's visual style.

---

# 18. Map Interactions

The monitoring map should support:

- Zoom
- Pan
- Node selection
- Node hover where supported
- Fit-to-floor / fit-to-network
- Optional floor filtering
- Optional status filtering

When selecting a node, open a node-details panel/drawer instead of navigating away from the dashboard.

---

# 19. Node Details Drawer

Selecting a node should open a details panel.

Example structure:

```text
Node: N-021

Status: Warning

RSSI: -89 dBm
Hop: 4
Parent: N-012
Last Seen: 4.2 sec
Firmware: v1.0.0
Uptime: 3d 14h
Packet Loss: 2.4%

[ RSSI History ]

[ Recent Events ]

Actions:
[ Restart ]
[ Update ]
```

Only show metrics that actually exist in the current data source.

Do not create fake values.

---

# 20. Parent Node Is Important

Because the mesh can be multi-hop, the node table/details must expose the parent node when the mesh protocol provides it.

The question during troubleshooting is not only:

> Is node N-046 offline?

It is also:

> Which node was N-046 using as its parent?

Therefore parent information should be first-class monitoring data.

---

# 21. Node Health Table

The main table should contain:

```text
Node ID
Status
RSSI
Hop
Parent
Last Seen
Uptime
Firmware
Packet Loss
```

Add:

- Search
- Sort
- Filtering
- Status filtering
- Floor filtering if available
- Firmware filtering

For a large deployment, this table must remain usable with hundreds or 1000+ nodes.

---

# 22. Search and Filters

The table should provide:

```text
Search Node ID...
```

Filters:

```text
[All]
[Online]
[Offline]
[Warning]
```

Additional filters where the existing data supports them:

```text
Floor
Zone
Firmware
Hop
```

Do not add filters that require data the current backend does not contain.

---

# 23. Alerts & Events

Create a dedicated alerts/events panel.

Examples:

```text
17:30  N-046 became Offline
17:28  RSSI degraded on N-037
17:20  OTA completed successfully
17:15  N-043 reached high Hop Count
17:10  New node detected
```

Categories:

```text
Critical
Warning
Info
```

The alerts system should be driven by actual events/state changes.

Do not generate fake historical events.

---

# 24. Network Performance

The dashboard should provide historical/short-term trends when sufficient data exists.

Useful metrics:

### Online Node Count

Shows network availability over time.

### Average RSSI

Shows signal quality trend.

### Average Hop Count

Shows topology depth trend.

### Packet Loss

Shows reliability.

### Response / Latency

Only if the current protocol provides a reliable measurement.

Charts must reflect real collected data.

If historical data is not currently persisted, design the chart component so it can consume a future history source without redesigning the entire dashboard.

---

# 25. OTA Deployment

OTA remains an important section, but it should not dominate the dashboard.

The current OTA functionality should be redesigned into a deployment panel.

Example:

```text
Firmware Deployment

Current Version
v1.0.0

Target Version
v1.1.0

Target:
[ All Nodes ]
[ Selected Nodes ]
[ Floor ]
[ Zone ]

Deployment:
████████████████░░░ 87%

Success     Failed     Pending
42          3          3
```

Only expose target selectors that can actually be supported by the current infrastructure data.

---

# 26. OTA History

Include deployment history when data exists:

```text
Date
Version
Target
Total
Success
Failed
```

The history should not be fabricated if the project currently does not persist it.

---

# 27. Serial / JSON Log

Keep the current Serial JSON Log.

It is useful for debugging and engineering.

However, it should occupy a smaller portion of the primary dashboard.

Controls:

```text
[Clear]
[Pause]
[Search]
[Filter]
[Export]
```

Allow filtering by:

- Node
- Event type
- Severity

The raw log should remain available because it is valuable during firmware/network debugging.

---

# 28. Network Diagnostics

Add a diagnostics capability.

For a selected node, show the network path when the mesh provides the information.

Example:

```text
ROOT
 ↓
N-003
 ↓
N-010
 ↓
N-021

Hop Count: 3

RSSI:
Root → N-003
N-003 → N-010
N-010 → N-021
```

This can later become a proper route/trace diagnostic.

Do not implement a fake route if the protocol does not expose enough information.

---

# 29. Dashboard Information Priority

The dashboard should prioritize:

1. Network health
2. Node availability
3. Mesh topology
4. Problematic nodes
5. Network performance
6. OTA
7. Raw serial logs

The OTA panel should no longer visually dominate the entire page.

---

# 30. Suggested Application Structure

Keep the monitoring UI modular.

Conceptually:

```text
Monitoring
│
├── Dashboard
│
├── Network
│   ├── Topology
│   ├── Nodes
│   └── Diagnostics
│
├── Infrastructure
│   ├── Buildings
│   ├── Floors
│   ├── Zones
│   └── Nodes
│
├── OTA
│   ├── Firmware
│   ├── Deployment
│   └── History
│
├── Monitoring
│   ├── Metrics
│   ├── Alerts
│   └── Logs
│
└── Settings
```

Do not perform a large architectural refactor just for visual redesign.

Reuse existing project structure where appropriate.

---

# 31. Data Architecture

Prefer a separation similar to:

```text
Supabase
    │
    ▼
Infrastructure Repository
    │
    ├── Node Definitions
    ├── Coordinates
    ├── Floors
    └── Zones

Root / Serial
    │
    ▼
Mesh Monitoring Repository / Service
    │
    ├── Live State
    ├── RSSI
    ├── Hop
    ├── Parent
    ├── Firmware
    └── Events

             ↓

       Unified Monitoring State

             ↓

        Dashboard UI
```

The UI should not directly parse raw serial JSON in every widget.

---

# 32. Unified Node Model

The exact model should follow the existing project architecture.

Conceptually, the monitoring state needs to be able to represent:

```text
Node
├── identity
├── infrastructure position
│   ├── x
│   ├── y
│   ├── floor
│   └── building
│
└── live mesh state
    ├── status
    ├── lastSeen
    ├── rssi
    ├── hop
    ├── parent
    ├── firmware
    └── other available metrics
```

Do not invent fields that are not available.

---

# 33. Unknown State

The system must distinguish:

```text
Online
Offline
Warning
Unknown / Not yet observed
```

This is important because:

```text
Node exists in Supabase
```

does not automatically mean:

```text
Node is online
```

And:

```text
Node has not yet reported
```

does not automatically mean:

```text
Node is offline
```

unless the project's backend/protocol provides enough information to make that determination.

The UI should communicate this distinction clearly.

---

# 34. Do Not Fake Network Health

No hardcoded values.

Avoid code such as:

```text
online = true
health = 95
rssi = -65
```

The dashboard must derive displayed values from actual data.

This is especially important because the dashboard will eventually be used for a real physical ESP32 deployment.

---

# 35. Responsive Design

The dashboard should work on the intended monitoring screen sizes.

It should remain usable when:

- the browser is resized
- the node count increases
- the table becomes large
- the map contains many nodes
- alerts increase

Do not make every panel fixed-height unless there is a clear reason.

---

# 36. Performance Requirements

The implementation should be designed for potentially:

```text
100+
500+
1000+ nodes
```

Avoid:

- rebuilding the entire dashboard for every incoming serial message
- recreating all map nodes unnecessarily
- querying Supabase repeatedly for every widget
- opening separate subscriptions for the same data
- storing duplicate copies of the same infrastructure data

Prefer:

```text
One source of infrastructure truth
+
One live monitoring state
+
Selective UI updates
```

---

# 37. Supabase Query Strategy

Before writing queries:

1. Open:

```text
D:\IPS_app\IPS_app\lib\features\navigation\data\datasources\supabase_navigation_datasource.dart
```

2. Identify the existing node/infrastructure queries.
3. Identify the actual table names.
4. Identify the actual coordinate fields.
5. Identify how building/floor/node relationships are represented.
6. Reuse existing models where possible.
7. Reuse the existing Supabase client/configuration.
8. Only add new queries for information that is genuinely missing.

Do not create a second parallel schema.

---

# 38. Important Implementation Constraint

The dashboard redesign must not force a final topology visualization design now.

The architecture must allow:

```text
Monitoring Data
       │
       ▼
Topology/Map Data
       │
       ▼
Renderer
```

The renderer can later change without changing:

- Supabase integration
- node model
- live mesh service
- alerts
- OTA
- monitoring logic

This is intentional because the exact visual topology/map style is not finalized yet.

---

# 39. Reference Image Interpretation

The provided reference image demonstrates the desired information architecture:

- professional dark dashboard
- network KPI cards
- topology visualization
- alerts
- node health table
- network charts
- OTA deployment
- live JSON log
- node detail interaction

It does NOT mandate:

- exact colors
- exact map appearance
- exact topology geometry
- exact icons
- exact node shapes
- exact typography
- exact panel dimensions

The project's existing UI/map language takes precedence.

---

# 40. Implementation Order

Do not implement everything at once.

Recommended order:

## Phase 1 — Data foundation

- Inspect existing Supabase datasource
- Identify infrastructure node data
- Build/reuse node repository
- Load all known nodes before live monitoring starts
- Map database coordinates into the unified node model

## Phase 2 — Unified monitoring state

- Merge infrastructure data with live Root/Serial data
- Implement Online/Offline/Warning/Unknown state
- Track last seen
- Track RSSI
- Track hop
- Track parent
- Track firmware where available

## Phase 3 — Dashboard shell

Implement:

- Header
- KPI cards
- Alerts
- Node table
- Node details drawer

## Phase 4 — Existing map integration

Use the project's current map style.

Add:

- nodes
- x/y positioning
- status
- selection
- network links where available

Do not replace the map design.

## Phase 5 — Performance

Add:

- RSSI chart
- online/offline trend
- hop trend
- packet loss if available

## Phase 6 — OTA

Integrate:

- target firmware
- deployment progress
- result counters
- deployment history if available

## Phase 7 — Logs and diagnostics

Improve:

- Serial JSON log
- filtering
- search
- pause
- node diagnostics
- route/path visualization

---

# 41. Acceptance Criteria

The redesign is considered successful when:

### Infrastructure

- [ ] Dashboard knows all nodes stored in Supabase immediately after startup.
- [ ] Total Node count does not depend on receiving the first live packet.
- [ ] Existing Supabase datasource patterns are reused.
- [ ] Node X/Y coordinates are loaded from the database.
- [ ] Nodes can be positioned using their actual coordinates.

### Monitoring

- [ ] Live Root/Serial data updates the corresponding node.
- [ ] Node status can change without rebuilding unrelated UI.
- [ ] Parent and Hop information are displayed when available.
- [ ] Last Seen is displayed when available.
- [ ] RSSI is displayed when available.
- [ ] Firmware version is displayed when available.

### Map

- [ ] Existing map visual design is preserved.
- [ ] Nodes are rendered at database coordinates.
- [ ] Node status is visually distinguishable.
- [ ] Node selection opens details.
- [ ] Mesh links can be displayed independently from physical node coordinates.

### Dashboard

- [ ] KPI section exists.
- [ ] Alerts section exists.
- [ ] Node health table exists.
- [ ] Performance section exists.
- [ ] OTA section exists.
- [ ] Serial JSON log remains available.

### Scalability

- [ ] UI does not depend on one widget per node.
- [ ] Dashboard architecture can support hundreds/1000+ nodes.
- [ ] Infrastructure data is not repeatedly fetched by individual widgets.
- [ ] Live packets do not trigger unnecessary full-dashboard rebuilds.

---

# 42. Important Development Rule for Antigravity

Before modifying code:

1. Inspect the existing monitoring dashboard implementation.
2. Inspect:

```text
D:\IPS_app\IPS_app\lib\features\navigation\data\datasources\supabase_navigation_datasource.dart
```

3. Find the existing node/infrastructure models.
4. Find the current map implementation.
5. Find the current serial/mesh data model.
6. Understand the current OTA implementation.
7. Identify reusable components.

Then implement the redesign incrementally.

Do NOT replace working systems simply to make the code look cleaner.

Do NOT invent database schema.

Do NOT invent network metrics.

Do NOT replace the current map style.

Do NOT make OTA the visual center of the dashboard.

---

# 43. Final Design Principle

The dashboard should answer these questions immediately:

```text
1. Is the monitoring system connected?

2. How many nodes should exist?

3. How many are online?

4. Which nodes have problems?

5. Where are those nodes physically?

6. How are they connected through the Mesh?

7. What is the network quality?

8. Which node is the parent of a problematic node?

9. What firmware is deployed?

10. Is an OTA deployment currently running?

11. What happened recently?

12. Can I inspect the raw technical log?
```

The dashboard is therefore not just an OTA screen.

It is the **operations and diagnostics interface for the IPS ESP32 Mesh infrastructure**.
