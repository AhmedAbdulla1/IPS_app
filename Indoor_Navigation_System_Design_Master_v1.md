# Indoor Navigation System - Engineering Design Document

**Version:** 1.0

------------------------------------------------------------------------

# 1. Project Goal

Develop an Indoor Navigation System (INS) that guides users to offices,
classrooms, elevators, stairs and restrooms using a BLE infrastructure.

The objective is **wayfinding**, not high-precision indoor positioning.

------------------------------------------------------------------------

# 2. Project Philosophy

Instead of calculating the user's exact coordinates, the system only
needs to know:

-   Which corridor is the user in?
-   Which decision point has the user reached?
-   What is the next navigation instruction?

This significantly reduces complexity while keeping navigation reliable.

------------------------------------------------------------------------

# 3. System Components

## BLE Network

BLE Nodes distributed only inside corridors.

## Mobile Application

Responsible for: - BLE scanning - Position estimation - Route
calculation - Indoor map visualization - Voice/Text navigation

## Indoor Map

Represented as a graph.

## Maintenance System

Monitors node health and reports failures.

------------------------------------------------------------------------

# 4. BLE Node Design

Each node broadcasts only:

-   UUID
-   Major
-   Minor
-   Tx Power

The application maps these IDs to:

-   Floor
-   Zone
-   Description
-   Voice hint
-   Neighbor nodes

This allows updating maps without reprogramming nodes.

------------------------------------------------------------------------

# 5. Node Deployment Strategy

Nodes are **not** installed everywhere.

Install them at:

-   Building entrances
-   Corridor intersections
-   Long corridor midpoints
-   Elevators
-   Staircases
-   Corridor ends
-   Important destinations

Deployment is based on **decision points**, not room locations.

------------------------------------------------------------------------

# 6. Indoor Graph

The building is modeled as a graph.

Node = BLE Landmark

Edge = Walkable corridor

Each edge stores:

-   Direction
-   Estimated walking distance
-   Walking cost

Routing algorithms:

-   Dijkstra
-   A\*

------------------------------------------------------------------------

# 7. Position Estimation

Priority order:

1.  BLE available
    -   Synchronize user position.
2.  BLE unavailable
    -   Continue tracking using Pedestrian Dead Reckoning (PDR).
3.  BLE detected again
    -   Correct accumulated drift.

------------------------------------------------------------------------

# 8. Blind Zone Handling

Blind zones may exist between nodes.

Mitigation:

-   BLE Landmarks
-   PDR using phone sensors
-   Corridor constraint
-   Map matching
-   Confidence score

The application never immediately loses the user after leaving BLE
coverage.

------------------------------------------------------------------------

# 9. Mobile Application Modules

-   BLE Scanner
-   RSSI Filter
-   Position Estimator
-   Indoor Graph Manager
-   Routing Engine
-   Navigation Engine
-   Voice Guidance
-   Settings

------------------------------------------------------------------------

# 10. Database

## Nodes

-   id
-   uuid
-   major
-   minor
-   floor
-   zone
-   description
-   voice_hint

## Edges

-   from_node
-   to_node
-   direction
-   distance

## Destinations

-   destination_name
-   nearest_node

------------------------------------------------------------------------

# 11. Node Health Monitoring

Goals:

-   Detect offline nodes
-   Detect weak coverage
-   Predict failures

Possible methods:

### Heartbeat

Each node periodically reports its status.

### Neighbor Monitoring

Nearby nodes detect missing neighbors.

### Crowdsourced Monitoring

Mobile apps report missing expected nodes.

### Coverage Analysis

Detect coverage gaps.

### RSSI Trend Analysis

Predict failures before complete outage.

------------------------------------------------------------------------

# 12. Recommended Hardware

BLE Node

-   ESP32
-   BLE Advertising
-   Stable power supply

Gateway

-   ESP32 or Raspberry Pi

------------------------------------------------------------------------

# 13. Recommended Communication

Navigation

-   BLE Advertising

Maintenance

-   ESP-NOW + Gateway

This separates user navigation traffic from maintenance traffic.

------------------------------------------------------------------------

# 14. Future Enhancements

-   Multi-floor navigation
-   Dynamic rerouting
-   Accessibility mode
-   OTA firmware updates
-   Analytics dashboard
-   Battery prediction
-   Admin dashboard

------------------------------------------------------------------------

# 15. Engineering Decisions

Accepted decisions:

-   BLE nodes only in corridors.
-   Navigation instead of precise positioning.
-   Graph-based indoor map.
-   Hybrid BLE + PDR localization.
-   Separate Navigation and Maintenance layers.
-   BLE nodes broadcast IDs only.
-   Health monitoring should be built into the system from the
    beginning.

------------------------------------------------------------------------

# 16. Current Open Questions

-   Optimal BLE advertising interval.
-   Required node density.
-   Gateway placement.
-   Battery vs wired power.
-   Android/iOS background BLE limitations.

------------------------------------------------------------------------

This document is a living design document and should be updated after
every technical discussion.
