# Byte n' Bite · UML diagrams

Source files are Mermaid (`.mmd`), so a feature change is a small text edit.
PNG/PDF exports go in `Documents\Byte n' Bite\UML\`. The version number
matches the SRS.

| File | Diagram |
|---|---|
| 1_use_case.mmd | Use case: what the player (and the developer in Admin Runs) can do |
| 2_class_diagram.mmd | Class diagram: main systems and how they connect |
| 3_sequence_run_program.mmd | Sequence: write code → staff cooks and serves → coins/EXP |
| 4_activity_market_delivery.mmd | Activity: Market purchase → delivery → crates → inventory |

To re-export: `mmdc -i 2_class_diagram.mmd -o 2_class_diagram.png -s 3`
(Mermaid CLI), or paste the file into https://mermaid.live.

## Change log
- **v1.8 (Oct 2026):** first version. Covers the C interpreter, staff
  programs, orders (waiter/cook tickets), customers, goals and challenges,
  restaurant/staff upgrades (Lv 10 roles), the Night Market with random stock,
  deliveries and crates, inventory and the fridge window.
