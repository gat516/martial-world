--!nocheck
-- Joint poses for the quadruped roster previews and QA (preview_quadrupeds.luau,
-- qa_quadrupeds.luau). Each pose maps a Motor6D name to its Transform. Rotation about X
-- is pitch on every joint (+ swings a hanging leg forward), translation is in model space.
--   WINDUP  each beast's attack windup (rough procedural poses for the animator pass)
--   STRETCH a leap: front legs reached forward, hind legs kicked back, head up, jaw open,
--           tail streaming, ears pinned (the fox's tails swept back)
--   CROUCH  a coil: everything tucked, head turned, tail curled (the fox's tails fanned
--           out to the widest the animator should use)

local function pitch(a)
	return CFrame.Angles(a, 0, 0)
end
local function yaw(a)
	return CFrame.Angles(0, a, 0)
end

local POSES = { WINDUP = {}, STRETCH = {}, CROUCH = {} }

-- Stone Boar ---------------------------------------------------------------------------------
-- charge: head dropped to aim the tusks, a front hoof pawing, haunches loaded
POSES.WINDUP.StoneBoar_R = {
	JointRoot = CFrame.new(0, -0.35, 0) * pitch(-0.12), JointChest = pitch(0.05),
	JointNeck = pitch(-0.2), JointHead = pitch(-0.12), JointJaw = pitch(-0.15),
	JointLegFL = pitch(1.0), JointLowerLegFL = pitch(-1.35), JointHoofFL = pitch(0.6), -- pawing, hoof up
	JointLegFR = pitch(0), JointLowerLegFR = pitch(-0.99), JointHoofFR = pitch(1.06),
	JointLegBL = pitch(-0.25), JointLowerLegBL = pitch(0.73), JointHoofBL = pitch(-0.36),
	JointLegBR = pitch(-0.25), JointLowerLegBR = pitch(0.73), JointHoofBR = pitch(-0.36),
	JointTail = pitch(0.9), JointEarL = pitch(-0.5), JointEarR = pitch(-0.5),
}
POSES.STRETCH.StoneBoar_R = {
	JointRoot = CFrame.new(0, 0.6, 0) * pitch(0.08), JointChest = pitch(-0.08),
	JointNeck = pitch(0.25), JointHead = pitch(0.15), JointJaw = pitch(-0.5),
	JointLegFL = pitch(0.85), JointLowerLegFL = pitch(-0.3), JointHoofFL = pitch(0.3),
	JointLegFR = pitch(0.7), JointLowerLegFR = pitch(-0.2), JointHoofFR = pitch(0.3),
	JointLegBL = pitch(-0.85), JointLowerLegBL = pitch(0.3), JointHoofBL = pitch(-0.4),
	JointLegBR = pitch(-0.7), JointLowerLegBR = pitch(0.3), JointHoofBR = pitch(-0.4),
	JointTail = pitch(-0.9), JointTailTip = pitch(-0.5), JointEarL = pitch(-0.6), JointEarR = pitch(-0.6),
}
POSES.CROUCH.StoneBoar_R = {
	JointRoot = CFrame.new(0, -0.45, 0), JointChest = pitch(0.12),
	JointNeck = pitch(-0.3) * yaw(0.45), JointHead = pitch(-0.2) * yaw(0.25), JointJaw = pitch(-0.4),
	JointLegFL = pitch(-0.5), JointLowerLegFL = pitch(0.74), JointHoofFL = pitch(-0.36),
	JointLegFR = pitch(-0.5), JointLowerLegFR = pitch(0.74), JointHoofFR = pitch(-0.36),
	JointLegBL = pitch(0.8), JointLowerLegBL = pitch(-1.35), JointHoofBL = pitch(0.55),
	JointLegBR = pitch(0.8), JointLowerLegBR = pitch(-1.35), JointHoofBR = pitch(0.55),
	JointTail = pitch(0.6) * yaw(0.5), JointTailTip = pitch(0.6) * yaw(0.4),
	JointEarL = pitch(0.4), JointEarR = pitch(0.4),
}

-- Stone-Shell Tortoise ------------------------------------------------------------------------
-- quake stomp: rears up on the hind legs, front feet lifted, head pulled half in
POSES.WINDUP.StoneTortoise_R = {
	JointRoot = CFrame.new(0, 0.55, 0) * pitch(0.32),
	JointNeck = CFrame.new(0, 0, 0.6) * pitch(0.15), JointHead = pitch(-0.35), JointJaw = pitch(-0.45),
	JointLegFL = pitch(0.25), JointFootFL = pitch(-0.6), JointLegFR = pitch(0.25), JointFootFR = pitch(-0.6),
	JointLegBL = CFrame.new(0, 0.34, 0) * pitch(-0.32), JointFootBL = pitch(0),
	JointLegBR = CFrame.new(0, 0.34, 0) * pitch(-0.32), JointFootBR = pitch(0),
	JointTail = pitch(-0.3),
}
POSES.STRETCH.StoneTortoise_R = {
	JointRoot = CFrame.new(0, 0.3, 0),
	JointNeck = CFrame.new(0, 0, -0.4) * pitch(0.25), JointHead = pitch(0.2) * yaw(0.5), JointJaw = pitch(-0.55),
	JointLegFL = pitch(0.6), JointFootFL = pitch(-0.4), JointLegFR = pitch(0.6), JointFootFR = pitch(-0.4),
	JointLegBL = pitch(-0.6), JointFootBL = pitch(0.4), JointLegBR = pitch(-0.6), JointFootBR = pitch(0.4),
	JointTail = pitch(-0.4),
}
-- the head pulled fully in (the shell-up defence), legs tucked, tail curled aside
POSES.CROUCH.StoneTortoise_R = {
	JointRoot = CFrame.new(0, -0.5, 0),
	JointNeck = CFrame.new(0, 0, 2.3), JointHead = pitch(-0.1), JointJaw = pitch(-0.12),
	JointLegFL = CFrame.new(0, 0.5, 0), JointLegFR = CFrame.new(0, 0.5, 0),
	JointLegBL = CFrame.new(0, 0.5, 0), JointLegBR = CFrame.new(0, 0.5, 0),
	JointTail = pitch(0.3) * yaw(0.6),
}

-- Nine-Tail Fox ---------------------------------------------------------------------------------
-- foxfire volley: crouched low, head forward, every tail fanned out wide and raised
POSES.WINDUP.NineTailFox_R = {
	JointRoot = CFrame.new(0, -0.3, 0) * pitch(-0.05), JointChest = pitch(0.06),
	JointNeck = pitch(-0.35), JointHead = pitch(0.3), JointJaw = pitch(-0.3),
	JointEarL = pitch(-0.2) * CFrame.Angles(0, 0, 0.3), JointEarR = pitch(-0.2) * CFrame.Angles(0, 0, -0.3),
	JointLegFL = pitch(0.45), JointLowerLegFL = pitch(-1.01), JointPawFL = pitch(0.55),
	JointLegFR = pitch(-0.1), JointLowerLegFR = pitch(-0.63), JointPawFR = pitch(0.72),
	JointLegBL = pitch(-0.35), JointLowerLegBL = pitch(0.03), JointPawBL = pitch(0.37),
	JointLegBR = pitch(-0.25), JointLowerLegBR = pitch(-0.1), JointPawBR = pitch(0.4),
	JointTail = pitch(-0.35),
}
POSES.STRETCH.NineTailFox_R = {
	JointRoot = CFrame.new(0, 0.7, 0) * pitch(0.1), JointChest = pitch(-0.1),
	JointNeck = pitch(-0.3), JointHead = pitch(0.25), JointJaw = pitch(-0.5),
	JointEarL = pitch(-0.6), JointEarR = pitch(-0.6),
	JointLegFL = pitch(1.0), JointLowerLegFL = pitch(-0.2), JointPawFL = pitch(0.3),
	JointLegFR = pitch(0.85), JointLowerLegFR = pitch(-0.3), JointPawFR = pitch(0.3),
	JointLegBL = pitch(-0.9), JointLowerLegBL = pitch(0.3), JointPawBL = pitch(-0.3),
	JointLegBR = pitch(-0.8), JointLowerLegBR = pitch(0.3), JointPawBR = pitch(-0.3),
	JointTail = pitch(0.6),
}
POSES.CROUCH.NineTailFox_R = {
	JointRoot = CFrame.new(0, -0.55, 0), JointChest = pitch(0.1),
	JointNeck = pitch(-0.2) * yaw(0.5), JointHead = pitch(0.1) * yaw(0.3), JointJaw = pitch(-0.45),
	JointEarL = pitch(0.3), JointEarR = pitch(0.3),
	JointLegFL = pitch(-0.4), JointLowerLegFL = pitch(1.02), JointPawFL = pitch(-0.72),
	JointLegFR = pitch(-0.4), JointLowerLegFR = pitch(1.02), JointPawFR = pitch(-0.72),
	JointLegBL = pitch(0.7), JointLowerLegBL = pitch(-0.88), JointPawBL = pitch(0.18),
	JointLegBR = pitch(0.7), JointLowerLegBR = pitch(-0.88), JointPawBR = pitch(0.18),
	JointTail = pitch(-0.2) * yaw(0.3),
}
-- The fox's nine tails fan out by roll about Z: outer tails spread most.
for i = 1, 9 do
	local t = (i - 5) / 4
	POSES.WINDUP.NineTailFox_R["JointTail" .. i] = CFrame.Angles(0.05, 0, -t * 0.3)
	POSES.WINDUP.NineTailFox_R["JointTail" .. i .. "Tip"] = CFrame.Angles(0.2, 0, -t * 0.15)
	POSES.STRETCH.NineTailFox_R["JointTail" .. i] = CFrame.Angles(0.5, 0, t * 0.2)
	POSES.STRETCH.NineTailFox_R["JointTail" .. i .. "Tip"] = CFrame.Angles(0.3, 0, 0)
	POSES.CROUCH.NineTailFox_R["JointTail" .. i] = CFrame.Angles(-0.25, 0, -t * 0.55)
	POSES.CROUCH.NineTailFox_R["JointTail" .. i .. "Tip"] = CFrame.Angles(-0.6, 0, -t * 0.3)
end

return POSES
