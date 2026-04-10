# Draw.io Database Diagram Quick Reference

**Version 1.0 | Andrew Reischl**

---

## Shape Styles to Copy

### Server / VM
```
fillColor=#FF5722;strokeColor=#E64A19;strokeWidth=2;rounded=1;arcSize=10;fontSize=12;fontStyle=1;fontColor=#FFFFFF
```

### Database (Cylinder)
```
shape=cylinder3;fillColor=#673AB7;strokeColor=#512DA8;strokeWidth=2;fontSize=11;fontStyle=1;fontColor=#FFFFFF
```

### Cloud Service (Dashed Border)
```
fillColor=#03A9F4;strokeColor=#0288D1;strokeWidth=2;dashed=1;dashPattern=5 3;rounded=1;arcSize=15
```

### Load Balancer (Hexagon)
```
shape=hexagon;fillColor=#2196F3;strokeColor=#1976D2;strokeWidth=2;perimeter=hexagonPerimeter2
```

### Container / Zone
```
fillColor=none;strokeColor=#E0E0E0;strokeWidth=1;dashed=1;dashPattern=8 4;fontStyle=1;fontColor=#757575
```

---

## Connection Styles

| Type | Style String |
|------|-------------|
| Sync | `strokeColor=#2196F3;strokeWidth=2;endArrow=classic` |
| Async | `strokeColor=#009688;strokeWidth=2;dashed=1;dashPattern=6 3;endArrow=classic` |
| DR/Failover | `strokeColor=#F44336;strokeWidth=1.5;dashed=1;dashPattern=3 3;endArrow=classic` |
| Message Queue | `strokeColor=#FFC107;strokeWidth=2;dashed=1;dashPattern=8 4;endArrow=classic` |

---

## Color Palettes

### Light Mode
```
Background:    #FFFFFF
Surface:       #F5F5F5
Primary:       #2196F3
Secondary:     #009688
Database:      #673AB7
Server:        #FF5722
Cloud:         #03A9F4
Warning:       #FFC107
Danger:        #F44336
Text Primary:  #212121
Text Secondary:#757575
Border:        #E0E0E0
```

### Dark Mode
```
Background:    #1E1E1E
Surface:       #2D2D2D
Primary:       #4A9FFF
Secondary:     #00BFA5
Database:      #9C6ADE
Server:        #FF8A50
Cloud:         #00BCD4
Warning:       #FFB300
Danger:        #FF5252
Text Primary:  #FFFFFF
Text Secondary:#B0B0B0
Border:        #404040
```

---

## Text Styles

| Element | Font | Size | Style | Color |
|---------|------|------|-------|-------|
| Component Label | Segoe UI | 11-12pt | Bold | Primary Text |
| Zone Label | Segoe UI | 10pt | Bold, Uppercase | Secondary Text |
| Connection Label | Segoe UI | 9pt | Normal | Secondary Text |
| Metadata | Segoe UI | 9pt | Normal | Secondary Text |

---

## Best Practices

1. **Consistency:** Use the same shape for the same component type
2. **Direction:** Left-to-right for data flow, top-to-bottom for hierarchy
3. **Spacing:** Maintain consistent spacing between components
4. **Labels:** Always label primary connections
5. **Zones:** Use containers to group related infrastructure
6. **Accessibility:** Don't rely solely on color; use shapes/icons

---

## Export Settings

| Use Case | Format | Scale | Notes |
|----------|--------|-------|-------|
| Word/PDF | PNG | 2x | Include background |
| Presentation | PNG/SVG | 2x-4x | Depends on resolution |
| Wiki/Confluence | SVG | 1x | Transparent background |
| GitHub README | PNG | 2x | Max width 1200px |

---

*See also: `drawio_style_guide.md` for full documentation*
