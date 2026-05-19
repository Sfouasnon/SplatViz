# SplatViz M5.4

Msplat terminal watchdog pass.

- Removes stale `train.log` and `splat.ply` before launching a new run so old `splat_ply=present` markers cannot stop polling a fresh run.
- Writes a boot log synchronously before launching the shell wrapper.
- Tracks the spawned PID with `OS.is_process_running()`.
- Polls while the Msplat window is open, while the process is alive, or during final refresh ticks.
- Extends the log tail to 18k chars.
- Densification progress no longer pins at 45%; the UI keeps showing the latest Gaussian count and PID/log heartbeat.
- Keeps M5.3 projected seed tracks, M5.1 quaternion order, and M4.9 image hierarchy fixes.
