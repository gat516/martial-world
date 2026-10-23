# Bloodline

> **Planned change (2026-10-22, [progression](../progression.md)):** bloodlines replace
> races, with cosmetic traits (horns, tails, wings, see-through spirits), found or
> bought, earlier than FE. Heaven-defying bloodlines and roots trigger a tribulation at
> every major breakthrough. A demon bloodline can get the player expelled from the sect.
> The text below is the old plan until this is built.

Covers the bloodline layer (design only, not built): what it is, finding and intake, what it gives, swapping, data; read it before building bloodlines.

**What it is:** a special power in your body, awakened from a found essence.
For kids, bloodlines are mythical creatures; the classic special bodies are rare
bloodlines in the same slot, so there is **one slot and one idea**:

- Beasts: Azure Dragon, Vermilion Phoenix, White Tiger, Black Tortoise, Qilin.
- Rare bodies: Pure Yang Body, Pure Yin Body, Heavenly Demon Body.

**Finding and intake:** an essence is an item (`Items`) that drops from the
Auspicious Clouds relic, bosses or rare events. Using it while meditating starts
a short **awakening trial**: a circulation-minigame variant, or surviving a
wave of the creature's echoes. Passing it awakens the bloodline. Failing costs
time, never the essence (the same rule as the tribulation).

**What it gives:**
- **One bloodline skill**, an extra hotbar ability with a long cooldown that
  feels big (Dragon roar knockback, Phoenix flame dash with self-revive at
  higher stages, Tortoise shell). Exactly one, so the hotbar doesn't bloat.
- **One passive** in that creature's theme.
- **A visible mark:** eye glow, a faint aura, a tattoo-like marking.
- **Awakening stages (1-3):** more essences of the same bloodline strengthen
  it. Duplicates are never wasted.

**Swapping:** taking in a different essence replaces your bloodline, with a
confirmation. You keep the old one's stage if you ever return to it.

**Data:** `data.bloodline = { id: string, stages: { [id]: number } }`.
