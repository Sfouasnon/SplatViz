# SplatViz M3.9

Targeted UI reliability pass.

- Fixed left dock overflow by placing the controls inside a vertical ScrollContainer.
- Reduced left-panel button height/font size so laptop-height windows remain usable.
- Repaired the Msplat Terminal layout by removing the long training note from the row that collapsed into vertical text.
- Expanded the Msplat window and terminal log area.
- Terminal log now uses horizontal scrolling/no wrap so command output does not render as single-character columns.

The Msplat training behavior is unchanged from M3.8: higher iteration runs retrain from the chosen dataset because msplat-train does not currently expose a resume/checkpoint flag in the installed CLI.
