# Lightning Talisman visuals

Covers the `LightningTalisman` technique effect (templates `LightningTalisman_T1..T4`, spec `tools/vfx_specs/LightningTalisman.luau`, `TechniqueFX.LightningTalisman`); read it when changing that effect, with the shared pipeline in [technique visuals](../technique-visuals.md).

Templates `LightningTalisman_T1..T4`;
`TechniqueFX.LightningTalisman`. At Hit a paper talisman card leaves the
left hand (Fists.2) and tumbles to a point above the first target in
`chain`, where it flares and burns while a jagged bolt strikes down. Bolts
then hop along `chain` every `HopDelay` (0.04 to 0.028 s by tier), bowing over
the bodies. Each target gets an impact (flash, Neon impact torus, ground
shock, crackle; II+ scorch and seals); the last gets a heavier finale with an
electric ring, a ground splash and a shake (III+ Craters rocks). With no
target the card flies to max range or the first wall or ground and bursts
there. II adds forks, release sparks and an air ring; III a double strand,
seals under every target and impact bubbles; IV two forks and a sky strike on
the first target with the move's one light and a quake. Bolts are Beams on
a jittered attachment chain; with the Game Module the main core is the
LightningBeams add-on. Tuning lives in root attributes (`HopDelay`,
`Strands`, `Forks`, `BoltWidth`, `BoltLife`, `Segments`, `Jitter`,
`Flickers`, `CardSpeed`, `SealTargets`, `SkyStrike`). Damage lands at Hit;
the hops are only a visual stagger. When `chain` is nil (Edit previews) the
module predicts it with Combat.chainTargets' rule. Remade 2026-10-21 for the
Hit window (bare hand, so the anchor stays on the live left palm): the card
now crosses in 0.05-0.12 s (`CardSpeed` 200-245 studs/s, was 110-125 and up
to 0.22 s) and the hops are 0.04-0.028 s apart (were 0.12-0.09 s), so the
first strike lands ~0.05 s after the release and the whole chain within
~0.15 s instead of up to ~0.5 s after the damage number (a sandbox run
landed the first impact 0.03 s and the finale 0.1 s after the release); the
windup is a stream through 0.25 s; the release on the hand gets the shared
flare (violet cross glint, star-burst flipbook over ink, sparks); every
impact carries the shared ink splat and star-burst flipbook. Layers T1 / T4:
windup 4 / 6, hand release 7 / 9, card 5, impact 9 / 17, finale 15 / 20,
fizzle 11 / 17.
