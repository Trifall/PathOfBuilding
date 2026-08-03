describe("Kinetic Fusillade", function()
	local serverTickTime = 0.033

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

	local function setupSkill(skill, customMods)
		newBuild()
		equipWand()
		build.skillsTab:PasteSocketGroup(skill .. " 20/20  1\n")
		if customMods then
			build.configTab.input.customMods = customMods
			build.configTab:BuildModList()
		end
		runCallback("OnFrame")

		local socketGroup = build.skillsTab.socketGroupList[build.mainSocketGroup]
		local activeSkill = socketGroup.displaySkillList[socketGroup.mainActiveSkill]
		activeSkill.activeEffect.srcInstance.skillPart = 3
		build.modFlag = true
		build.buildFlag = true
		runCallback("OnFrame")
		return activeSkill.activeEffect.srcInstance
	end

	local function expectedCycleTime(output, skillData, attacksRequired)
		local attackInterval = 1 / output.Speed
		local releaseTime = (skillData.duration + skillData.delayPerProjectile * (output.KineticFusilladeAccumulatedProjectiles - 1)) * output.DurationMod
		local roundedReleaseTime = math.ceil(releaseTime / serverTickTime) * serverTickTime
		return (attacksRequired - 1) * attackInterval + math.max(attackInterval, roundedReleaseTime)
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
		assert.are.equals(12, output.KineticFusilladeUsesToAccumulate)
		assert.are.equals(66, output.KineticFusilladeAvgMoreMult)
		assert.is_true(output.KineticFusilladeCanAccumulate)
		assert.are.near(expectedCycleTime(output, activeSkill.skillData, 12), output.KineticFusilladeAccumulationCycleTime, 0.000001)
		assert.are.near(12 / output.KineticFusilladeAccumulationCycleTime, output.KineticFusilladeEffectiveProjectileRate, 0.000001)
		assert.are.near(output.KineticFusilladeEffectiveProjectileRate / output.Speed, activeSkill.skillData.dpsMultiplier, 0.000001)
		assert.are.near(output.MainHand.AverageDamage * output.KineticFusilladeEffectiveProjectileRate, output.MainHand.TotalDPS, 0.000001)
		assert.are.near(output.ManaCost * output.KineticFusilladeUsesToAccumulate / output.KineticFusilladeAccumulationCycleTime, output.ManaPerSecondCost, 0.000001)
	end)

	it("uses and caps a custom accumulated projectile count", function()
		local srcInstance = setupSkill("Kinetic Fusillade")
		srcInstance.skillStageCount = 3
		recalculate()

		assert.are.equals(3, build.calcsTab.mainOutput.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(3, build.calcsTab.mainOutput.KineticFusilladeAttacksToAccumulate)
		assert.are.equals(3, build.calcsTab.mainOutput.KineticFusilladeUsesToAccumulate)
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
		assert.are.equals(5, output.KineticFusilladeUsesToAccumulate)
		assert.are.equals(136, output.KineticFusilladeAvgMoreMult)
		assert.are.near(expectedCycleTime(output, activeSkill.skillData, 5), output.KineticFusilladeAccumulationCycleTime, 0.000001)

		local socketGroup = build.skillsTab.socketGroupList[build.mainSocketGroup]
		local activeSkill = socketGroup.displaySkillList[socketGroup.mainActiveSkill]
		activeSkill.activeEffect.srcInstance.skillStageCount = 5
		recalculate()
		assert.are.equals(8, build.calcsTab.mainOutput.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(2, build.calcsTab.mainOutput.KineticFusilladeAttacksToAccumulate)
		assert.are.equals(2, build.calcsTab.mainOutput.KineticFusilladeUsesToAccumulate)
		assert.are.equals(56, build.calcsTab.mainOutput.KineticFusilladeAvgMoreMult)
	end)

	it("applies accumulated sequence damage to hits and ailments", function()
		local poisonMods = "Adds 1000 to 1000 Fire Damage to Attacks\n100% chance to Poison on Hit\nAll Damage from Hits can Poison"
		local srcInstance = setupSkill("Kinetic Fusillade", poisonMods)
		local accumulatedOutput = build.calcsTab.mainOutput
		local accumulatedHit = accumulatedOutput.MainHand.AverageHit
		local accumulatedPoison = accumulatedOutput.MainHand.PoisonDamage

		srcInstance.skillStageCount = 1
		recalculate()
		local oneProjectileOutput = build.calcsTab.mainOutput

		assert.are.near(1.66, accumulatedHit / oneProjectileOutput.MainHand.AverageHit, 0.001)
		assert.are.near(1.66, accumulatedPoison / oneProjectileOutput.MainHand.PoisonDamage, 0.001)
	end)

	it("uses the effective projectile rate for on-hit recovery and leech", function()
		local recoveryMods = "Gain 10 Life per Enemy Hit with Attacks\n1% of Physical Attack Damage Leeched as Life\nCritical Strikes have Culling Strike"
		setupSkill("Kinetic Fusillade", recoveryMods)

		local output = build.calcsTab.mainOutput
		local handOutput = output.MainHand
		local hitRate = handOutput.HitChance / 100 * output.KineticFusilladeEffectiveProjectileRate
		assert.are.equals(10, handOutput.LifeOnHit)
		assert.are.near(handOutput.LifeOnHit * hitRate, handOutput.LifeOnHitRate, 0.000001)
		assert.are.near(handOutput.LifeLeechDuration * hitRate, handOutput.LifeLeechInstances, 0.000001)
		assert.are.near(10 * (1 - (1 - handOutput.CritChance / 100) ^ hitRate), output.CullPercent, 0.000001)
	end)

	it("uses the sequence range for non-stacking ailments", function()
		local ailmentMods = "Adds 1000 to 1000 Physical Damage to Attacks\nAdds 1000 to 1000 Fire Damage to Attacks\n100% chance to Bleed on Hit\n100% chance to Ignite"
		local srcInstance = setupSkill("Kinetic Fusillade", ailmentMods)
		local accumulatedOutput = build.calcsTab.mainOutput
		local accumulatedBleedMin = accumulatedOutput.MainHand.BleedPhysicalMin
		local accumulatedBleedMax = accumulatedOutput.MainHand.BleedPhysicalMax
		local accumulatedIgniteMin = accumulatedOutput.MainHand.IgniteFireMin
		local accumulatedIgniteMax = accumulatedOutput.MainHand.IgniteFireMax
		local accumulatedBleedDPS = accumulatedOutput.MainHand.BleedDPS
		local accumulatedIgniteDPS = accumulatedOutput.MainHand.IgniteDPS

		srcInstance.skillStageCount = 1
		recalculate()
		local oneProjectileOutput = build.calcsTab.mainOutput

		assert.are.near(1, accumulatedBleedMin / oneProjectileOutput.MainHand.BleedPhysicalMin, 0.01)
		assert.are.near(2.32, accumulatedBleedMax / oneProjectileOutput.MainHand.BleedPhysicalMax, 0.01)
		assert.are.near(1, accumulatedIgniteMin / oneProjectileOutput.MainHand.IgniteFireMin, 0.01)
		assert.are.near(2.32, accumulatedIgniteMax / oneProjectileOutput.MainHand.IgniteFireMax, 0.01)
		assert.is_true(accumulatedBleedDPS > oneProjectileOutput.MainHand.BleedDPS)
		assert.is_true(accumulatedIgniteDPS > oneProjectileOutput.MainHand.IgniteDPS)
	end)

	it("accounts for forced repeats in timing and resource costs", function()
		local srcInstance = setupSkill("Kinetic Fusillade of Detonation", "Non-Travel Attack Skills Repeat an additional Time")

		local output = build.calcsTab.mainOutput
		local activeSkill = build.calcsTab.mainEnv.player.mainSkill
		assert.are.equals(2, output.Repeats)
		assert.are.equals(18, output.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(6, output.KineticFusilladeAttacksToAccumulate)
		assert.are.equals(3, output.KineticFusilladeUsesToAccumulate)
		assert.are.near(expectedCycleTime(output, activeSkill.skillData, 6), output.KineticFusilladeAccumulationCycleTime, 0.000001)
		assert.are.near(18 / output.KineticFusilladeAccumulationCycleTime, output.KineticFusilladeEffectiveProjectileRate, 0.000001)
		assert.are.near(output.ManaCost * 3 / output.KineticFusilladeAccumulationCycleTime, output.ManaPerSecondCost, 0.000001)

		srcInstance.skillStageCount = 9
		recalculate()
		output = build.calcsTab.mainOutput
		assert.are.equals(16, output.KineticFusilladeAccumulatedProjectiles)
		assert.are.equals(4, output.KineticFusilladeAttacksToAccumulate)
		assert.are.equals(2, output.KineticFusilladeUsesToAccumulate)
		assert.are.equals(120, output.KineticFusilladeAvgMoreMult)
		assert.are.near(expectedCycleTime(output, activeSkill.skillData, 4), output.KineticFusilladeAccumulationCycleTime, 0.000001)
		assert.are.near(output.ManaCost * 2 / output.KineticFusilladeAccumulationCycleTime, output.ManaPerSecondCost, 0.000001)
	end)

	it("charges once per paid use when the selected count cannot accumulate", function()
		setupSkill("Kinetic Fusillade", "75% reduced Attack Speed\nNon-Travel Attack Skills Repeat an additional Time")

		local output = build.calcsTab.mainOutput
		assert.is_false(output.KineticFusilladeCanAccumulate)
		assert.are.equals(0, output.KineticFusilladeEffectiveProjectileRate)
		assert.are.near(output.ManaCost * output.Speed / output.Repeats, output.ManaPerSecondCost, 0.000001)
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
