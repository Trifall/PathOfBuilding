describe("Kinetic Fusillade", function()
	local function equipWand()
		build.itemsTab:CreateDisplayItemFromRaw([[Elemental Wand
			Imbued Wand
			Crafted: true
			Prefix: None
			Prefix: None
			Prefix: None
			Suffix: None
			Suffix: None
			Suffix: None
			Quality: 0
			Sockets: B-B-B
			LevelReq: 59
			Implicits: 0]])
		build.itemsTab:AddDisplayItem()
	end

	local function setupSkill(skill)
		newBuild()
		equipWand()
		build.skillsTab:PasteSocketGroup(skill .. " 20/20  1\n")
		runCallback("OnFrame")

		local socketGroup = build.skillsTab.socketGroupList[build.mainSocketGroup]
		local activeSkill = socketGroup.displaySkillList[socketGroup.mainActiveSkill]
		activeSkill.activeEffect.srcInstance.skillPart = 3
		build.modFlag = true
		build.buildFlag = true
		runCallback("OnFrame")
		return activeSkill.activeEffect.srcInstance
	end

	local function recalculate()
		build.modFlag = true
		build.buildFlag = true
		runCallback("OnFrame")
	end

	it("defaults accumulated projectiles to the maximum", function()
		setupSkill("Kinetic Fusillade")

		local output = build.calcsTab.mainOutput
		local activeSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.are.equals(12, activeSkill.skillData.stagesMax)
		assert.are.equals("12", build.controls.mainSkillStageCount.buf)
		assert.are.equals(12, output.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(12, output.KineticFusilladeAttacksToAccumulate)
		assert.are.equals(66, output.KineticFusilladeAvgMoreMult)
		assert.is_true(output.KineticFusilladeCanAccumulate)
		assert.are.near(12 / output.KineticFusilladeAccumulationCycleTime, output.KineticFusilladeEffectiveProjectileRate, 0.000001)
		assert.are.near(output.KineticFusilladeEffectiveProjectileRate / output.Speed, activeSkill.skillData.dpsMultiplier, 0.000001)
		assert.are.near(output.ManaCost * output.KineticFusilladeAttacksToAccumulate / output.KineticFusilladeAccumulationCycleTime, output.ManaPerSecondCost, 0.000001)
	end)

	it("uses and caps a custom accumulated projectile count", function()
		local srcInstance = setupSkill("Kinetic Fusillade")
		srcInstance.skillStageCount = 3
		recalculate()

		assert.are.equals(3, build.calcsTab.mainOutput.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(3, build.calcsTab.mainOutput.KineticFusilladeAttacksToAccumulate)
		assert.are.equals(12, build.calcsTab.mainOutput.KineticFusilladeAvgMoreMult)

		srcInstance.skillStageCount = 20
		recalculate()
		assert.are.equals(12, build.calcsTab.mainOutput.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(66, build.calcsTab.mainOutput.KineticFusilladeAvgMoreMult)
	end)

	it("uses the transfigured gem projectile maximum", function()
		setupSkill("Kinetic Fusillade of Detonation")

		local output = build.calcsTab.mainOutput
		local activeSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.are.equals(18, activeSkill.skillData.stagesMax)
		assert.are.equals(18, output.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(5, output.KineticFusilladeAttacksToAccumulate)
		assert.are.equals(136, output.KineticFusilladeAvgMoreMult)

		local socketGroup = build.skillsTab.socketGroupList[build.mainSocketGroup]
		local activeSkill = socketGroup.displaySkillList[socketGroup.mainActiveSkill]
		activeSkill.activeEffect.srcInstance.skillStageCount = 5
		recalculate()
		assert.are.equals(8, build.calcsTab.mainOutput.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(2, build.calcsTab.mainOutput.KineticFusilladeAttacksToAccumulate)
	end)

	it("applies the accumulation timing once while dual wielding", function()
		setupSkill("Kinetic Fusillade")
		equipWand()
		recalculate()

		local output = build.calcsTab.mainOutput
		local activeSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.is_true(activeSkill.skillFlags.bothWeaponAttack)
		assert.are.near(output.KineticFusilladeEffectiveProjectileRate / output.Speed, activeSkill.skillData.dpsMultiplier, 0.000001)
	end)

	it("includes only the selected part in Full DPS", function()
		local srcInstance = setupSkill("Kinetic Fusillade")
		srcInstance.skillPartCalcs = 1
		build.skillsTab.socketGroupList[build.mainSocketGroup].includeInFullDPS = true
		recalculate()

		local function getKineticFusilladeRows()
			local rows = {}
			for _, skillDPS in ipairs(build.calcsTab.mainOutput.SkillDPS) do
				if skillDPS.name == "Kinetic Fusillade" then
					table.insert(rows, skillDPS)
				end
			end
			return rows
		end

		local rows = getKineticFusilladeRows()
		assert.are.equals(1, #rows)
		assert.are.equals("Accumulated Projectiles", rows[1].skillPart)

		srcInstance.skillPart = 1
		recalculate()
		rows = getKineticFusilladeRows()
		assert.are.equals(1, #rows)
		assert.are.equals("All Projectiles", rows[1].skillPart)
	end)
end)
