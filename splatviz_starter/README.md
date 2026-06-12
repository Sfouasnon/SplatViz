# SplatViz Starter M1.5

M1.5 adds the first explicit gsplat-aligned intelligence layer: angle sufficiency hypotheses, clearer contribution overlays, weak/dead-zone hatching, and verification manifests.

## What changed in M1.5

- Stronger Splat Viability visual palette.
- Selected camera, previous neighbor, and next neighbor use distinct colors.
- Weak/dead contribution zones now appear when angular gaps exceed the full-body performer hypothesis threshold.
- Angle Sufficiency panel explains why 16 cameras can look visually covered but remain weak for full-body performer 4DGS.
- gsplat verification manifests now include train/holdout policy and render targets.
- Msplat is marked as optional local smoke test only.

Run:

```zsh
/usr/local/share/dotnet/dotnet test
/usr/local/share/dotnet/dotnet run --project src/SplatViz.Cli
open splatviz_sample_export/app/index.html
```
