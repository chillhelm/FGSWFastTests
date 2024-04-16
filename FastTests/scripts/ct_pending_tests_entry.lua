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

    defendattribute.getDatabaseNode().onUpdate = updateDefenceDescription
    updateDefenceDescription()

    hideShakenIcon()
    updateDisVulChoice()
    hideDisVulChoice()
    hideNoEffectIndicator()

	targetvalue.getDatabaseNode().onUpdate = updateAttackResult
	defencescore.getDatabaseNode().onUpdate = updateAttackResult
    ccresultkeyword.getDatabaseNode().onUpdate = updateAttackResult
	updateAttackResult()

    maybeshaken.getDatabaseNode().onUpdate = updateMaybeShakenIcon
    updateMaybeShakenIcon()

	attackresult.getDatabaseNode().onUpdate = updateAttackVisibility
	updateAttackVisibility()

	updateMenuItems()

    if not(Session.IsHost or Session.IsLocal) then
        apply.setVisible(false)
        targetvalue.setReadOnly(true)
        defencescore.setReadOnly(true)
        defendbutton.setVisible(false)
        deletebutton.setVisible(false)
        ccresultkeyword.setReadOnly(true)
    else
    end
    getDatabaseNode().getChild("resultDistracted").onUpdate = updateDisVulChoice
    getDatabaseNode().getChild("resultVulnerable").onUpdate = updateDisVulChoice
    if FastTests.isUserAllowedToRollForThisCharacter(getDatabaseNode().getParent().getParent()) then
        defendbutton.setVisible(true)
    end
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
    if (DB.getValue(getDatabaseNode(),"defencerolled",0)==0 and DB.getValue(getDatabaseNode(),"defencescore",0)==0 ) then
        hideShakenIcon()
        hideDisVulChoice()
        hideNoEffectIndicator()
        hideCCResultKeyword()
        hideMaybeShakenIcon()
        return
    end

    local nAttackScore = DB.getValue(getDatabaseNode(), "targetvalue",4)
    local nDefenceScore = DB.getValue(getDatabaseNode(), "defencescore",0)
    local nResult = nAttackScore - nDefenceScore
    if nResult >= 4 then
        local sFTCC = OptionsManager.getOption("FTCC")
        if sFTCC and sFTCC == "on" and FastTests.isAgressorWC(getDatabaseNode()) then
            showCCResultKeyword()
            local sCCResultKeyword = DB.getValue(getDatabaseNode(),"ccresultkeyword")
            if (not sCCResultKeyword) or sCCResultKeyword=="" then
            else
                if sCCResultKeyword == "Shaken" then
                    showShakenIcon()
                elseif sCCResultKeyword == "Second Wind" then
                    showMaybeShakenIcon()
                    hideShakenIcon()
                elseif sCCResultKeyword == "Insight" then
                    showMaybeShakenIcon()
                    hideShakenIcon()
                else
                    hideShakenIcon()
                end
            end
        else
            showShakenIcon()
            hideCCResultKeyword()
            hideMaybeShakenIcon()
        end
    else
        hideShakenIcon()
        hideCCResultKeyword()
        hideMaybeShakenIcon()
    end
    if nResult >= 1 then
        showDisVulChoice()
    else
        hideDisVulChoice()
    end
    if nResult <= 0 then
        showNoEffectIndicator()
    else
        hideNoEffectIndicator()
    end
    updateDisVulChoice()
end

function isAttackResultVisible()
	return true
end

function showCCResultKeyword()
    ccresultkeyword.setVisible(true)
end

function hideCCResultKeyword()
    ccresultkeyword.setVisible(false)
end

function showMaybeShakenIcon()
    maybeshaken_icon.setVisible(true)
end

function hideMaybeShakenIcon()
    maybeshaken_icon.setVisible(false)
end

function showShakenIcon()
    shaken.setVisible(true)
end

function hideShakenIcon()
    shaken.setVisible(false)
end

function showDisVulChoice()
    dischoice.setVisible(true)
    vulchoice.setVisible(true)
    vul_label.setVisible(true)
    dis_label.setVisible(true)
end

function hideDisVulChoice()
    dischoice.setVisible(false)
    vulchoice.setVisible(false)
    vul_label.setVisible(false)
    dis_label.setVisible(false)
end

function showNoEffectIndicator()
    noeffectindicator.setVisible(true)
end

function hideNoEffectIndicator()
    noeffectindicator.setVisible(false)
end

function updateAttackVisibility()
	local bVisible = isAttackResultVisible()
	attackrow.setVisible(bVisible)
	targetvalue.setVisible(bVisible)
	attackscore_label.setVisible(bVisible)
	defencescore.setVisible(bVisible)
	defencescore_label.setVisible(bVisible)
end

--
-- Setup damage result
--

function setShaken(bShaken)
	bResultShaken = bShaken
	shaken.setVisible(bShaken and isDamageResultVisible())
end

--
-- Actions
--

function applyTestResult()
    FastTests.applyPendingTest(getDatabaseNode())
	removeEntry()
end

function removeEntry()
	getDatabaseNode().delete()
end

function updateDefenceDescription()
    if not FastTests.isUserAllowedToRollForThisCharacter(getDatabaseNode().getParent().getParent()) then
        return
    end
    local sAttr = DB.getValue(getDatabaseNode(),"defendattribute",nil)
    if sAttr then
        sDesc = sAttr
    else
        return
    end
    local _,nodeChar = CharacterManager.asCharActor("ct", getDatabaseNode().getParent().getParent())
    local nodeTraitNode = nil
    if AttributeManager.isAttribute(sAttr) then
        nodeTraitNode = AttributeManager.getAttributeNode(nodeChar, sAttr)
    else
        nodeTraitNode = SkillManager.getSkillNode(nodeChar, sAttr, false)
    end
    local aDie = nodeTraitNode.getValue()
    if not aDie then
        defendbutton.setText(sDesc)
    else
        sDesc = sDesc .. " [" .. aDie[1] .."]"
        defendbutton.setText(sDesc)
    end
end

function toggleDisChoice()
    if FastTests.isUserAgressorForThisTest(getDatabaseNode()) then
        sendOOBMessage = {["type"] = FastTests.OOB_MESSAGE_TYPE_TEST_TOGGLE_DIS,
                          ["sPendingTestPath"] = getDatabaseNode().getPath()}
        Comm.deliverOOBMessage(sendOOBMessage)
    end
end

function toggleVulChoice()
    if FastTests.isUserAgressorForThisTest(getDatabaseNode()) then
        sendOOBMessage = {["type"] = FastTests.OOB_MESSAGE_TYPE_TEST_TOGGLE_VUL,
                          ["sPendingTestPath"] = getDatabaseNode().getPath()}
        Comm.deliverOOBMessage(sendOOBMessage)
    end
end

function updateDisVulChoice()
    local bDistracted = DB.getValue(getDatabaseNode(), "resultDistracted", 0)==1
    local bVulnerable = DB.getValue(getDatabaseNode(), "resultVulnerable", 0)==1
    if bDistracted then
        dischoice.setIcon("poll_check")
    else
        dischoice.setIcon("poll_empty")
    end
    if bVulnerable then
        vulchoice.setIcon("poll_check")
    else
        vulchoice.setIcon("poll_empty")
    end
end

function updateMaybeShakenIcon()
    local bMaybeShaken = DB.getValue(getDatabaseNode(), "maybeshaken",0)==1
    if bMaybeShaken then
        maybeshaken_icon.setIcon("state_shaken")
    else
        maybeshaken_icon.setIcon("state_shaken_off")
    end
end

function toggleMaybeShaken()
    if Session.IsLocal or Session.IsHost then
        DB.setValue(getDatabaseNode(),"maybeshaken","number",
            1 - DB.getValue(getDatabaseNode(),"maybeshaken",0))
    end
end

function updateDefendTrait(sTrait)
    if Session.IsHost or Session.IsLocal then
        if sTrait then
            DB.setValue(getDatabaseNode(),"defendattribute","string",sTrait)
        end
    else
        if FastTests.isUserAgressorForThisTest(getDatabaseNode()) then
            sendOOBMessage = {["type"] = FastTests.OOB_MESSAGE_TYPE_TEST_UPDATE_DEFEND_TRAIT,
                              ["sPendingTestPath"] = getDatabaseNode().getPath(),
                              ["sTrait"] = sTrait}
            Comm.deliverOOBMessage(sendOOBMessage)
        end
    end
    updateDefenceDescription()
end
