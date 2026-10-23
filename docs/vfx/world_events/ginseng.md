PLAN (not built): the Thousand-Year Ginseng's look: a client-drawn jade pillar whose seal shows guarded or free from the peaks. Read when you build the Ginseng look (step 5).

# Thousand-Year Ginseng (world event) — plan

Today (`WorldEvents/GuardedHerb.luau`): clones `ItemTemplates.WorldTreasure` scaled x3 as a
beacon (an 80-stud Neon cylinder, glass shell, orb, 7-stud Neon ring, one emitter,
PointLight, all herb-tinted, plus the giant herb and the guardian). One Neon cylinder, so not
a pillar by the brief's bar, and its top (Y ~250) is under the cloud plane, so nobody on the
peaks sees it. Kit and rules: [../world_events.md](../world_events.md).

Identity: jade and gold life qi, earth, roots. The guarded/free state is the far signal.
- **Server:** GuardedHerb stops cloning `WorldTreasure` as a beacon (the client draws it).
  The framework publishes a small `state` per running event (`run.setState("guarded"|"free")`,
  included in the `WorldEvents` JSON; decision 8).
- **Far:** a jade LightPillar (L) with a SkyCircle of leaf and root patterns. While guarded,
  a vermilion seal ring turns round the pillar's base and the sky circle; when the guardian
  falls the seal shatters and the pillar flares and turns pure jade-gold, so the peaks can see
  it's free.
- **Mid:** a jade-white CloudRing turning slowly at Y 100-200; spiralling jade motes.
- **Close:** a ground circle of leaves and roots on an ink base; pollen motes; falling leaves;
  the herb's glow. Gather: the pillar pulls down into the herb, then a leaf burst.
