# Draw.io Diagram Style Guide

**Author:** Andrew Reischl  
**Purpose:** Standardized architecture diagrams for database and infrastructure documentation

---

## Overview

This template system ensures consistent, professional diagrams across all documentation. It supports both light and dark modes with carefully selected color palettes that maintain accessibility and visual hierarchy.

## Quick Start

1. **Import Template:** Open draw.io → File → Open → select `drawio_template_light.xml` or `drawio_template_dark.xml`
2. **Start Fresh:** Use the blank canvas with pre-configured styles
3. **Use Common Shapes:** Drag shapes from the left panel using the standard library

---

## Color Palettes

### Dark Mode Palette

| Purpose | Color | Hex | Usage |
|---------|-------|-----|-------|
| Background | Dark Slate | `#1E1E1E` | Canvas background |
| Surface | Charcoal | `#2D2D2D` | Container backgrounds |
| Primary | Azure Blue | `#4A9FFF` | Primary connections, highlights |
| Secondary | Teal | `#00BFA5` | Secondary elements, success states |
| Database | Purple | `#9C6ADE` | Database components |
| Server | Orange | `#FF8A50` | Server/infrastructure elements |
| Cloud | Cyan | `#00BCD4` | Cloud services |
| Warning | Amber | `#FFB300` | Alerts, warnings |
| Danger | Red | `#FF5252` | Errors, critical issues |
| Text Primary | White | `#FFFFFF` | Main text |
| Text Secondary | Gray | `#B0B0B0` | Secondary text, labels |
| Border | Dark Gray | `#404040` | Component borders |

### Light Mode Palette

| Purpose | Color | Hex | Usage |
|---------|-------|-----|-------|
| Background | White | `#FFFFFF` | Canvas background |
| Surface | Light Gray | `#F5F5F5` | Container backgrounds |
| Primary | Azure Blue | `#2196F3` | Primary connections, highlights |
| Secondary | Teal | `#009688` | Secondary elements, success states |
| Database | Deep Purple | `#673AB7` | Database components |
| Server | Deep Orange | `#FF5722` | Server/infrastructure elements |
| Cloud | Light Blue | `#03A9F4` | Cloud services |
| Warning | Amber | `#FFC107` | Alerts, warnings |
| Danger | Red | `#F44336` | Errors, critical issues |
| Text Primary | Dark Gray | `#212121` | Main text |
| Text Secondary | Medium Gray | `#757575` | Secondary text, labels |
| Border | Light Border | `#E0E0E0` | Component borders |

---

## Shape Standards

### Servers & Infrastructure

```
┌─────────────────────────────────────────────────────────────┐
│ Shape: Rounded Rectangle                                     │
│ Size: 120 x 80                                               │
│ Style: Fill=#FF8A50 (dark) / #FF5722 (light), rounded=10    │
│ Font: Segoe UI, 12pt, Bold                                   │
│ Border: 2pt, rounded=10                                       │
└─────────────────────────────────────────────────────────────┘
```

**Usage:** Physical servers, VMs, containers, application servers

### Databases

```
┌─────────────────────────────────────────────────────────────┐
│ Shape: Cylinder                                              │
│ Size: 80 x 100                                               │
│ Style: Fill=#9C6ADE (dark) / #673AB7 (light)                 │
│ Font: Segoe UI, 11pt, Bold                                   │
│ Border: 2pt                                                   │
└─────────────────────────────────────────────────────────────┘
```

**Usage:** SQL Server, Oracle, PostgreSQL, MySQL, MongoDB, any data store

### Cloud Services

```
┌─────────────────────────────────────────────────────────────┐
│ Shape: Rounded Rectangle with cloud icon                    │
│ Size: 100 x 70                                               │
│ Style: Fill=#00BCD4 (dark) / #03A9F4 (light), rounded=15     │
│ Font: Segoe UI, 11pt, Bold                                   │
│ Border: 2pt, dashed=5                                        │
└─────────────────────────────────────────────────────────────┘
```

**Usage:** AWS, Azure, GCP services, SaaS applications

### Load Balancers / Proxies

```
┌─────────────────────────────────────────────────────────────┐
│ Shape: Hexagon                                               │
│ Size: 80 x 70                                               │
│ Style: Fill=#4A9FFF (dark) / #2196F3 (light)                 │
│ Font: Segoe UI, 10pt, Bold                                   │
│ Border: 2pt                                                   │
└─────────────────────────────────────────────────────────────┘
```

**Usage:** Load balancers, API gateways, reverse proxies, firewalls

### Clients / Users

```
┌─────────────────────────────────────────────────────────────┐
│ Shape: Circle / Person icon                                 │
│ Size: 60 x 60                                               │
│ Style: Fill=#B0B0B0 (dark) / #9E9E9E (light)                 │
│ Font: Segoe UI, 10pt                                        │
│ Border: 1pt, rounded=50%                                    │
└─────────────────────────────────────────────────────────────┘
```

**Usage:** End users, client applications, mobile apps

### Containers / Zones

```
┌─────────────────────────────────────────────────────────────┐
│ Shape: Rectangle (dashed border)                            │
│ Size: Variable                                               │
│ Style: Fill=transparent, Stroke=#404040 (dark) / #E0E0E0    │
│ Font: Segoe UI, 10pt, Bold, uppercase                        │
│ Border: 1pt, dashed=8                                       │
└─────────────────────────────────────────────────────────────┘
```

**Usage:** Network zones, security boundaries, availability zones, VPCs

---

## Connection Styles

### Synchronous Connection (solid line)
```
Style: straight, endArrow=classic, strokeWidth=2
Color: #4A9FFF (dark) / #2196F3 (light)
Label: None or "sync" in small text
```
**Usage:** Direct data flow, synchronous replication

### Asynchronous Connection (dashed line)
```
Style: straight, endArrow=classic, strokeWidth=2, dashed=6-3
Color: #00BFA5 (dark) / #009688 (light)
```
**Usage:** Async replication, eventual consistency, message queues

### Bidirectional (double arrows)
```
Style: straight, endArrow=both, strokeWidth=2
Color: #9C6ADE (dark) / #673AB7 (light)
```
**Usage:** Bidirectional sync, cluster communication

### Read/Write Split (label required)
```
Style: straight, endArrow=classic, strokeWidth=2
Color: #4A9FFF (dark) / #2196F3 (light)
Label: "W" near write path, "R" near read path
```
**Usage:** Read replicas, write masters

### Failover/DR Connection (dotted, red)
```
Style: straight, endArrow=classic, strokeWidth=1.5, dashed=3-3
Color: #FF5252 (dark) / #F44336 (light)
```
**Usage:** DR replication, failover links, backup paths

### Message Queue / Event Bus
```
Style: straight, endArrow=classic, strokeWidth=2, dashed=8-4
Color: #FFB300 (dark) / #FFC107 (light)
Label: "events" or queue name
```
**Usage:** Kafka, RabbitMQ, Event Hubs, SQS

---

## Text & Labeling Conventions

### Component Labels
- **Font:** Segoe UI (Windows) / SF Pro (Mac) / Roboto (Linux)
- **Size:** 11-12pt for main labels, 9-10pt for details
- **Weight:** Bold for primary, Regular for secondary
- **Color:** Text Primary for main, Text Secondary for metadata
- **Alignment:** Center, middle

### Connection Labels
- **Font:** Segoe UI, 9pt
- **Position:** Along the line, centered
- **Color:** Text Secondary
- **Background:** Transparent with slight padding

### Zone Labels
- **Font:** Segoe UI, 10pt
- **Weight:** Bold, uppercase
- **Color:** Text Secondary
- **Position:** Top-left of zone, inside boundary

### Metadata Format
```
[component_name]
Version: x.x.x
Region: us-east-1
IP: xxx.xxx.xxx.xxx
```

---

## Common Architecture Patterns

### Three-Tier Architecture
```
┌──────────────────────────────────────────────────────────────┐
│                      PRESENTATION TIER                        │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐                      │
│  │ Client 1│  │ Client 2│  │ Client 3│  ...                 │
│  └─────────┘  └─────────┘  └─────────┘                      │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│                       APPLICATION TIER                         │
│  ┌─────────────────┐    ┌─────────────────┐                  │
│  │  Load Balancer  │───▶│  App Server 1   │                  │
│  └─────────────────┘    └────────┬────────┘                  │
│       ┌─────────────────┐        │                           │
│       │  Load Balancer  │◀───────┘                           │
│       └─────────────────┘                                    │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│                         DATA TIER                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Primary DB  │──│ Replica DB  │──│ Replica DB  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└──────────────────────────────────────────────────────────────┘
```

### Database Replication Topology
```
┌──────────────────────────────────────────────────────────────┐
│                     PRIMARY DATA CENTER                       │
│  ┌────────────────┐                                          │
│  │  Primary DB    │───────sync──────▶┌────────────────┐     │
│  │  (Write)       │                  │  Sync Replica   │     │
│  └────────────────┘                  └────────┬───────┘     │
│                                                │             │
│                                    ┌───────────▼───────┐     │
│                                    │  Sync Replica 2   │     │
│                                    └───────────────────┘     │
└──────────────────────────────────────────────────────────────┘
                           │
                     async (DR)
                           │
┌──────────────────────────▼───────────────────────────────────┐
│                   SECONDARY DATA CENTER                       │
│  ┌────────────────┐                                          │
│  │  Async Replica  │                                          │
│  │  (Read/DR)     │                                          │
│  └────────────────┘                                          │
└──────────────────────────────────────────────────────────────┘
```

### High Availability Cluster
```
┌──────────────────────────────────────────────────────────────┐
│                    AVAILABILITY ZONE 1                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Node 1     │◀─│   Quorum     │─▶│   Node 2     │       │
│  │  (Primary)   │  │   Witness    │  │  (Secondary) │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└──────────────────────────────────────────────────────────────┘
                           │
                      Shared Storage
                           │
                    ┌───────▼───────┐
                    │  SAN / Shared │
                    │    Storage    │
                    └───────────────┘
```

---

## Export Settings

### For Internal Documents (Word, PDF)
- **Format:** PNG or SVG
- **Scale:** 2x for retina clarity
- **Background:** Include background color
- **Size:** As displayed

### For Presentations (PowerPoint, Slides)
- **Format:** PNG or SVG
- **Scale:** 2x or 4x depending on screen resolution
- **Transparent:** Optional, use based on slide design

### For Wiki/Confluence
- **Format:** SVG (scalable, searchable)
- **Transparent:** Yes
- **Embed:** Direct embed when possible

### For Code Repositories (GitHub README)
- **Format:** PNG (best compatibility)
- **Scale:** 2x
- **Max Width:** 1200px
- **File Name:** descriptive-name-diagram.png

---

## Accessibility Considerations

1. **Contrast Ratio:** Maintain 4.5:1 minimum for text
2. **Color Blindness:** Don't rely solely on color; use shapes/icons
3. **Patterns:** Use dashed/solid lines in addition to colors
4. **Labels:** Always include text labels, don't rely on tooltips

---

## Template File Reference

| File | Description |
|------|-------------|
| `drawio_template_light.xml` | Importable draw.io template for light mode |
| `drawio_template_dark.xml` | Importable draw.io template for dark mode |
| `drawio_template_common.xml` | Common shapes and patterns library |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-10 | Initial version |

---

*For questions or suggestions, contact: reischl.andrew@outlook.com*
