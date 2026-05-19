# SplatViz M2.6

Targeted runtime cleanup after M2.5 feedback.

Changes:
- Loads SplatVizRobot.glb via GLTFDocument runtime importer instead of ResourceLoader PackedScene import.
- Larger UI and inspector text.
- Top toolbar buttons now call real app actions.
- Adds Compare Layouts / Analysis panel for 16 vs 24 vs 36 hypotheses.
- Reduces Focus and Splat Viability overlay opacity.
- Keeps clean export outside the project repo.

Notes:
- Conclusions remain prediction-only until gsplat validation.
- If GLB runtime import fails, the app still uses a fallback robot proxy and prints a warning.
