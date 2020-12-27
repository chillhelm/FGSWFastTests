--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

local bResultRaise = false

local bResultShaken = false

function onInit()

	attackernodename.getDatabaseNode().onUpdate = updateAttackDescription
	attacknodename.getDatabaseNode().onUpdate = updateAttackDescription
	updateAttackDescription()

    updateDefenseDescription()

	targetvalue.getDatabaseNode().onUpdate = updateAttackResult
	defensescore.getDatabaseNode().onUpdate = updateAttackResult
	updateAttackResult()

	attackresult.getDatabaseNode().onUpdate = updateAttackVisibility
	updateAttackVisibility()

	updateMenuItems()

end

function updateMenuItems()
	resetMenuItems()
end

function onMenuSelection(nOption)
end

function getCombatantNode()
	return windowlist.getDatabaseNode().getParent()
end

--
-- Attacker description
--

function updateAttackDescription()
	local sAttackerNodeName = DB.getValue(getDatabaseNode(), "attackernodename")
	local sAttackNodeName = DB.getValue(getDatabaseNode(), "attacknodename")

	local sDesc = ""
	if StringManager.isNotBlank(sAttackerNodeName) then
		local nodeAttacker = DB.findNode(sAttackerNodeName)
		sDesc = nodeAttacker and StringManager.append(sDesc, DB.getValue(nodeAttacker, "name", "")) or ""
	end
	if StringManager.isNotBlank(sAttackNodeName) then
		local nodeAttack = DB.findNode(sAttackNodeName)
		sDesc = nodeAttack and StringManager.append(sDesc, DB.getValue(nodeAttack, "name", ""), ": ") or ""
	end

	attackdescription.setValue(sDesc)

	local bVisible = StringManager.isNotBlank(sDesc)
	descriptionrow.setVisible(bVisible) 
	attackdescription.setVisible(bVisible) 
end

--
-- Attack results
--

function updateAttackResult()
	--[[local rAttackResult = AttackManager.attackResultFromPendingResult(getDatabaseNode())
	setRaise(false)
	if rAttackResult.bCriticalFailure then
		setAttackNote(Interface.getString("attack_result_critical_failure"))
		setHit("roll_attack_miss")
	elseif rAttackResult.bMiss then
		setAttackNote(Interface.getString("attack_result_miss"))
		setHit("roll_attack_miss")
	elseif rAttackResult.bHit then
		setAttackNote(Interface.getString("attack_result_hit"))
		setHit("roll_attack_hit")
	elseif rAttackResult.bRaise then
		setRaise(true)
		setAttackNote(Interface.getString("attack_result_raise"))
		setHit("roll_attack_crit")
	end]]--
end

function isAttackResultVisible()
	return true
end

function updateAttackVisibility()
	local bVisible = isAttackResultVisible()
	attackrow.setVisible(bVisible)
	targetvalue.setVisible(bVisible)
	attackscore_label.setVisible(bVisible)
	defensescore.setVisible(bVisible)
	defensescore_label.setVisible(bVisible)
end

--
-- Setup attack result
--

function setHit(sIcon)
	hiticon.setIcon(sIcon)
	hiticon.setVisible(StringManager.isNotBlank(sIcon) and isAttackResultVisible())
end

function setRaise(bRaise)
	bResultRaise = bRaise
	raiseicon.setVisible(bRaise and isAttackResultVisible())
end

function setAttackNote(sText)
	attacknote.setValue(sText)
	attacknote.setVisible(StringManager.isNotBlank(sText) and isAttackResultVisible())
end

--
-- Setup damage result
--

function setShaken(bShaken)
	bResultShaken = bShaken
	shaken.setVisible(bShaken and isDamageResultVisible())
end

function setWounds(nWounds)
	nResultWounds = nWounds
	wounds.widget.setText(nWounds)
	wounds.setVisible(nWounds > 0 and isDamageResultVisible())
end

function setGrittyDamage(bGrittyDamage)
	bResultGrittyDamage = bGrittyDamage
end

function setSoaked(bSoaked)
	bResultSoaked = bSoaked
end

function setIncapacitated(bInc)
	bResultIncapacitated = bInc
	inc.setVisible(bInc and isDamageResultVisible())
end

function setDamageNote(sText)
	damagenote.setValue(sText)
	damagenote.setVisible(StringManager.isNotBlank(sText) and isDamageResultVisible())
end

function getWounds()
	return nResultWounds
end

--
-- Actions
--

function applyDamage()
	if nResultWounds > 0 or bResultShaken then
		ActionDamage.applyWounds("ct", getCombatantNode(), nResultWounds, isNonLethal(), bResultGrittyDamage)
	elseif bResultSoaked then
		DB.setValue(getCombatantNode(), "shaken", "number", 0)
	end
	removeEntry()
end

function removeEntry()
	getDatabaseNode().delete()
end

function updateDefenseDescription()
    sAttr = getDatabaseNode().getChild("defendattribute").getValue()
    Debug.chat("Att: ", sAttr)
    if sAttr then
        sDesc = sAttr
    end
    rActor = ActorManager.getActorFromCT(getCombatantNode())
    sDie = AttributeManager.getAttributeNode(DB.findNode(rActor.sCreatureNode),sAttr).getValue()[1]
    Debug.chat(sDie)
    sDesc = sDesc .. " [" .. sDie .."]"
    Debug.chat(sDesc)
    defendbutton.setText(sDesc)
end
