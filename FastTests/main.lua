OOB_MESSAGE_TYPE_TEST_INITIATION_SUCCESS="TEST_EXT_TEST_INITIATION_SUCCESS"
OOB_MESSAGE_TYPE_TEST_DEFENCE_ROLL_COMPLETED="TEST_EXT_TEST_DEFENCE_ROLL_COMPLETED"
OOB_MESSAGE_TYPE_TEST_TOGGLE_DIS="TEST_EXT_TOGGLE_DIS"
OOB_MESSAGE_TYPE_TEST_TOGGLE_VUL="TEST_EXT_TOGGLE_VUL"
OOB_MESSAGE_TYPE_TEST_NEW_PENDING_TEST="TEST_EXT_NEW_PENDING_TEST"
OOB_MESSAGE_TYPE_TEST_CCTABLE_ROLLED="TEST_EXT_CCTABLE_ROLLED"
OOB_MESSAGE_TYPE_TEST_CCROLL_REQUEST="TEST_EXT_CCROLL_REQUEST"
OOB_MESSAGE_TYPE_TEST_UPDATE_DEFEND_TRAIT="TEST_EXT_UPDATE_DEFEND_TRAIT"
sTestDefence = "testdefence"

function onInit()
    RollsManager.registerResolutionHandler("table", FastTests.onTableRolled)
    RollsManager.registerTraitResolutionSubHandler(nil, testTraitResolutionSubHandler)
    RollsManager.registerTraitResolutionSubHandler("testdefence", testDefenceResolutionSubHandler)
    TraitManager.registerTraitRoll(sTestDefence,testDefenceRollHandler)

    if User.isHost() or User.isLocal() then
        OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_DEFENCE_ROLL_COMPLETED, onTestDefenceRollCompleted)
        OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_TOGGLE_DIS, onToggleDis)
        OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_TOGGLE_VUL, onToggleVul)
        OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_INITIATION_SUCCESS, onSuccessfulTestInitiation)
        OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_CCTABLE_ROLLED, onCCTableRollCompleted)
        OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_UPDATE_DEFEND_TRAIT, onUpdateDefendTrait)
    end
    OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_CCROLL_REQUEST, onCCRollRequest)
    OptionsManager.registerOption2("FTCC", false, "option_header_setting", "option_label_FTCC", "option_entry_cycler",
		{ labels = "option_val_on", values = "on", baselabel = "option_val_off", baseval = "off", default = "off" })
	OptionsManager.registerOption2("FTARTD", false, "option_header_automation", "option_label_FTARTD", "option_entry_cycler",
		{ labels = "option_val_pconly|option_val_npconly|option_val_off", values = "pconly|npconly|off", baselabel = "option_val_all", baseval = "all", default = "all" })
    OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_NEW_PENDING_TEST, onNewPendingTest)
end

function testTraitResolutionSubHandler(rRoll, vRollResult, rSource, vTargets, rContext)
    if (rRoll.rCustom.attacknode ~= nil) then
        return
    end
    if (not rRoll.rCustom.nodename) or (not string.find(rRoll.rCustom.nodename,"skills")) then
        return
    end
    local targets=vTargets
    if(vTargets==nil or next(vTargets)==nil) then
        targets = TargetingManager.getFullTargets(rSource)
    end
    if next(targets)==nil then
        return
    end
    local nodeSkill = DB.findNode(rRoll.rCustom.nodename)
    local sAttribute = ""
    if nodeSkill then
       sAttribute = SkillManager.getLinkedAttribute(nodeSkill)
    end
    aTargetCTNodes = {}
    for _, rTarget in pairs(targets) do
        table.insert(aTargetCTNodes, rTarget.sCTNode)
    end
    targets_stringified = StringManagerSW.convertTableToString(aTargetCTNodes)
    local sendMessage = {}
    rSource.sName = nil

    if vRollResult.nTotalScore>=4 and not vRollResult.bCriticalFailure then 
        sendMessage = { ["type"]=OOB_MESSAGE_TYPE_TEST_INITIATION_SUCCESS,
                         ["nAttackValue"] = vRollResult.nTotalScore,
                         ["sDefendAttribute"] = sAttribute,
                         ["rSource"] = StringManagerSW.convertTableToString(rSource),
                         ["sAttackSkillNode"] = rRoll.rCustom.nodename,
                         ["vTargets"] = targets_stringified
                         }
        Comm.deliverOOBMessage(sendMessage) -- notify GM
    end
end

function onSuccessfulTestInitiation(rMessage)
    if (User.isHost() or User.isLocal()) then -- Host takes care of this, clients: No Touching
        vTargets={}
        vTargets = StringManager.convertStringToTable(rMessage.vTargets)
        rSource=StringManager.convertStringToTable(rMessage.rSource)
        for _,sTargetCTNode in pairs(vTargets) do
            local nodeTargetCTNode = DB.findNode(sTargetCTNode)
            if (nodeTargetCTNode) then
                local nodePendingTests = DB.createChild(nodeTargetCTNode,"pendingtests")
                local nodeNewPendingTest = DB.createChild(nodePendingTests)

                local nodeAttackDie = DB.findNode(rMessage.sAttackSkillNode)
                local nodeAttack = nodeAttackDie and nodeAttackDie.getParent() or nil

                local bAgressorIsWc = false
                if rSource.sCTNode then
                    local nodeCTNode = DB.findNode(rSource.sCTNode)
                    bAgressorIsWC = DB.getValue(nodeCTNode,"wildcard",0)==1
                elseif rSource.sCreatureNode then
                    local nodeCreature = DB.findNode(rSource.sCreatureNode)
                    bAgressorIsWC = DB.getValue(nodeCreature, "wildcard", 0)==1
                end
                DB.setValue(nodeNewPendingTest, "targetvalue","number",rMessage.nAttackValue)
                DB.setValue(nodeNewPendingTest, "defendattribute","string",rMessage.sDefendAttribute)
                DB.setValue(nodeNewPendingTest, "attackertype","string",rSource.sType)
                DB.setValue(nodeNewPendingTest, "attackernodename","string",rSource.sCreatureNode)
                DB.setValue(nodeNewPendingTest, "attackerWC", "number", bAgressorIsWC and 1 or 0)
                DB.setValue(nodeNewPendingTest, "attacknodename","string", nodeAttack and nodeAttack.getPath() or "")
                DB.setValue(nodeNewPendingTest, "resultVulnerable","number",0)
                DB.setValue(nodeNewPendingTest, "resultDistracted","number",0)
                DB.setValue(nodeNewPendingTest, "ccresultkeyword","string","")
                DB.setValue(nodeNewPendingTest, "maybeshaken", "number", 0)
                DB.setPublic(nodeNewPendingTest, true)

                notifyUsersOfNewTest(nodeNewPendingTest)
            end
        end
    end
    return true
end

function testDefenceRollHandler(sActorType, nodeActor, sTraitType, rUserData, draginfo)
    local _,nodeChar = CharacterManager.asCharActor(sActorType, nodeActor)
    ModifierManagerSW.applyEffectModifierOnEntity(sActorType, nodeActor, "testdefence")
    local sDescPrefix = "Test Defence Roll"
    local sAttr = DB.getValue(DB.findNode(rUserData.sPendingTest),"defendattribute","agility")
    if rUserData.sDefendTraitOverride then
        sAttr = rUserData.sDefendTraitOverride
    end
    sAttr = StringManager.simplify(sAttr)
    local nodeTrait = nil
    if AttributeManager.isAttribute(sAttr) then
        nodeTrait = AttributeManager.getAttributeNode(nodeChar, sAttr)
    else
        nodeTrait = SkillManager.getSkillNode(nodeChar, sAttr, false)
    end
    TraitManager.rollPreDefinedRoll(sActorType, nodeActor, nodeTrait, sDescPrefix, sTraitType, rUserData, draginfo)
end

function isUserAllowedToRollForThisCharacter(nodeCT)
    return isUserBossOfCTEntry(nodeCT)
end

function isUserAgressorForThisTest(nodePendingTest)
    local nodeAgressor = DB.findNode(DB.getValue(nodePendingTest,"attackernodename"))
    return isUserBossOfCTEntry(nodeAgressor)
end

function isUserBossOfCTEntry(nodeCT)
    local nodeCombatantGroup = nodeCT.getParent()
    for _, nodeCombatant in pairs(nodeCombatantGroup.getChildren()) do
        local sRecordType, sRecordName = DB.getValue(nodeCombatant,"link")
        local nodeLinked = nil
        if (sRecordName) then
            nodeLinked = DB.findNode(sRecordName)
        end
        if nodeCombatant.isOwner() or (nodeLinked and nodeLinked.isOwner())  then
            return true
        end
    end
    return false
end

function makeDefendRoll(pendingTestNode, sDefendTrait, bReroll)
    local nodeCharacterCT= pendingTestNode.getParent().getParent()
    if not isUserAllowedToRollForThisCharacter(nodeCharacterCT) then
        return
    end
    local rUserData = {sPendingTest=pendingTestNode.getPath()}
    if sDefendTrait then
        rUserData.sDefendTraitOverride = sDefendTrait
    end
    if bReroll then
        rUserData.reroll = true
        ModifierManagerSW.applyTraitModifiers("ct", nodeCharacterCT, "reroll")
    end
    TraitManager.makeTraitRoll("ct", nodeCharacterCT, sTestDefence, rUserData)
end

function testDefenceResolutionSubHandler(rRoll, rRollResult, rSource, vTargets, rContext)
    local rUserData = StringManager.convertStringToTable(rRoll.rCustom.userdata)

    local sendMessage = {["type"]=OOB_MESSAGE_TYPE_TEST_DEFENCE_ROLL_COMPLETED, 
                        nDefenceResult=rRollResult.nTotalScore,
                        sPendingTest = rUserData.sPendingTest}

    sendMessage.bCritFail = tostring(rRollResult.bCriticalFailure or false)
    sendMessage.bReroll = tostring(rRoll.rCustom.reroll or false)
    Comm.deliverOOBMessage(sendMessage)
end

function onTestDefenceRollCompleted(data)
    if not (User.isHost() or User.isLocal()) then -- Host takes care of this, clients: No Touching
        return
    end
    nodePendingTest = DB.findNode(data.sPendingTest)
    if nodePendingTest then
        local nOldResult = DB.getValue(nodePendingTest, "defencescore",0)
        local bOldCritFail = DB.getValue(nodePendingTest, "defencecritfail",0) == 1
        if (data.bCritFail=="true" or ((not bOldCritFail) and nOldResult<tonumber(data.nDefenceResult))) then
            DB.setValue(nodePendingTest, "defencescore", "number", data.nDefenceResult)
            DB.setValue(nodePendingTest, "defencecritfail", "number", data.bCritFail=="true" and 1 or 0)
            DB.setValue(nodePendingTest, "defencerolled", "number", 1)
        end
    end
end

function makeTargetShaken(nodeTarget)
    DB.setValue(nodeTarget,"shaken","number",1)
end

function applyPendingTest(nodePendingTest)
    local nAttackScore = DB.getValue(nodePendingTest, "targetvalue",4)
    local nDefenceScore = DB.getValue(nodePendingTest, "defencescore",0)
    local nResult = nAttackScore - nDefenceScore
    local nodeVictim=nodePendingTest.getParent().getParent()
    local nodeAgressor = DB.findNode(DB.getValue(nodePendingTest,"attackernodename"))
    local rAgressor = ActorManager.resolveActor(nodeAgressor)
    if nResult >= 4 then
        local sFTCC = OptionsManager.getOption("FTCC")
        if not sFTCC or (sFTCC and sFTCC=="off") then
            makeTargetShaken(nodeVictim)
        else
            local sCCResultKeyword = DB.getValue(nodePendingTest,"ccresultkeyword")
            if sCCResultKeyword then
                if sCCResultKeyword == "Shaken" then
                    makeTargetShaken(nodeVictim)
                elseif sCCResultKeyword == "Second Wind" then
                    if DB.getValue(nodePendingTest,"maybeshaken",0) == 1 then
                        makeTargetShaken(nodeVictim)
                    else
                        sendSecondWindMessage(nodePendingTest)
                    end
                elseif sCCResultKeyword == "Inspiration" then
                    local nodeBennyPool, sConsumerName = getAgressorBennyPool(nodePendingTest)
                    if nodeBennyPool then
                        BennyManager.giveBenny("",nodeBennyPool,"",sConsumerName,1)
                    end
                elseif sCCResultKeyword == "Insight" then
                    if DB.getValue(nodePendingTest,"maybeshaken",0) == 1 then
                        makeTargetShaken(nodeVictim)
                    else
                        sendInsightMessage(nodePendingTest)
                    end
                elseif sCCResultKeyword == "Seize the Moment" then
                    sendSeizeTheMomentMessage(nodePendingTest)
                elseif sCCResultKeyword == "Setback" then
                    sendSetbackMessage(nodePendingTest)
                end
            end
        end
    end
    if nResult >= 1 then
        local bDistracted = DB.getValue(nodePendingTest, "resultDistracted", 0)==1
        local bVulnerable = DB.getValue(nodePendingTest, "resultVulnerable", 0)==1
        local rActor = ActorManager.resolveActor(nodeVictim)
        if(bDistracted) then
            local rEffect = ActionEffect.distractedEffect()
            ActionEffect.applyEffect(rActor, rActor, rEffect)
        end
        if (bVulnerable) then
            local rEffect = ActionEffect.vulnerableEffect()
            ActionEffect.applyEffect(rActor, rActor, rEffect)
        end
    end
end

function onToggleDis(data)
    nodePendingTest = DB.findNode(data.sPendingTestPath)
    local bDistracted = DB.getValue(nodePendingTest, "resultDistracted", 0)==1
    if bDistracted then
        DB.setValue(nodePendingTest, "resultDistracted", "number", 0)
    else
        DB.setValue(nodePendingTest, "resultDistracted", "number", 1)
        if not isDoubleWhammy(nodePendingTest) then
            DB.setValue(nodePendingTest, "resultVulnerable", "number", 0)
        end
    end
end

function onToggleVul(data)
    nodePendingTest = DB.findNode(data.sPendingTestPath)

    local bVulnerable = DB.getValue(nodePendingTest, "resultVulnerable", 0)==1
    if bVulnerable then
        DB.setValue(nodePendingTest, "resultVulnerable", "number", 0)
    else
        if not isDoubleWhammy(nodePendingTest) then
            DB.setValue(nodePendingTest, "resultDistracted", "number", 0)
        end
        DB.setValue(nodePendingTest, "resultVulnerable", "number", 1)
    end
end

function notifyUsersOfNewTest(nodePendingTest)
    Comm.deliverOOBMessage({["type"]=OOB_MESSAGE_TYPE_TEST_NEW_PENDING_TEST,
                            sNodePendingTest = nodePendingTest.getPath()})
end

function onNewPendingTest(rData)
    local sFTARTD = OptionsManager.getOption("FTARTD")
    if sFTARTD == "off" then
        return
    end
    local nodeNewPendingTest = DB.findNode(rData.sNodePendingTest)
    if not nodeNewPendingTest then
        return
    end
    local nodeCTVictim = nodeNewPendingTest.getParent().getParent()
    local sType, sRecordName = DB.getValue(nodeCTVictim,"link")
    if sType == "npc" then -- GM should roll
        if not (sFTARTD == "npconly" or sFTARTD == "all") then -- roll automation is off for NPCs
            return
        end
        if User.isHost() or User.isLocal() then -- GM only section
            makeDefendRoll(nodeNewPendingTest)
        end
    end
    if sType == "charsheet" then
        if not (sFTARTD == "pconly" or sFTARTD == "all") then -- roll automation is off for PCs
            return
        end
        local nodeCharsheet = DB.findNode(sRecordName)
        if not nodeCharsheet then -- Who is this guy?
            return
        end
        if not (User.isLocal() or User.isHost()) then -- clients roll only for their own PCs
            if nodeCharsheet.isOwner() then
                makeDefendRoll(nodeNewPendingTest)
            end
            return
        end
        -- GM only section
        local bOwnerPresent = false
        local sOwner = DB.getOwner(nodeCharsheet)
        if sOwner and sOwner ~= "" then
            -- an owner exists, but is he here?
            local aUsers = User.getActiveUsers()
            if aUsers then
                for _, sUsername in pairs(aUsers) do
                    if sUsername == sOwner then
                        bOwnerPresent = true
                    end
                end
            end
        end
        if not bOwnerPresent then -- guess we gotta do it
            makeDefendRoll(nodeNewPendingTest)
        end
    end
end

function makeCreativeCombatTableRoll(rActor, nodePendingTest)
	local nodeTable = TableManager.findTable("Creative Combat")
	local rRoll = {};
	rRoll.sType = "table";
	--rRoll.sType = MassBattles.sBattleEffectTableRoll
	rRoll.sDesc = "[" .. Interface.getString("table_tag") .. "] " .. DB.getValue(nodeTable, "name", "");
	rRoll.aDice = DB.getValue(nodeTable,"dice", {})
	rRoll.nMod = 0
	rRoll.bApplyModifiersStack = false
    rRoll.nColumn = 0
	rRoll.sNodeTable = nodeTable.getNodeName()
    rRoll.nodeTable = nodeTable
	rRoll.sPendingTest = nodePendingTest.getPath()
    rActor.sPendingTest = nodePendingTest.getPath()
	ActionsManager.performAction(nil, rActor, rRoll);
    --TableManager.performRoll(nil, rActor,rRoll, false)
end

function onCreativeCombatTableRolled(rRoll, rSource, rTargets)
    local rRollResult = RollsManager.buildRollResult(rRoll)
    local nodeTable = DB.findNode(rRoll.sNodeTable)
    local table_result = TableManager.getResults(nodeTable, rRollResult.nTotalScore)
    local sResultKeyword = string.sub(table_result[1].sText, 0, table_result[1].sText:find(":")-1)

    local rOOBMessage = {["type"]=OOB_MESSAGE_TYPE_TEST_CCTABLE_ROLLED,
                         ["sResultKeyword"]=sResultKeyword,
                         ["sPendingTest"]=rRoll.sPendingTest
                     }
    Comm.deliverOOBMessage(rOOBMessage)
end

function onCCTableRollCompleted(rMessage)
    if User.isHost() or User.isLocal() then
        local nodePendingTest = DB.findNode(rMessage.sPendingTest)
        if not nodePendingTest then
            return
        end
        DB.setValue(nodePendingTest,"ccresultkeyword","string",rMessage.sResultKeyword)
        if rMessage.sResultKeyword == "Double Whammy" then
            DB.setValue(nodePendingTest,"resultVulnerable","number",1)
            DB.setValue(nodePendingTest,"resultDistracted","number",1)
        end
    end
end

function onTableRolled(rRoll, rSource, rTargets)
    if(rSource and rRoll.sPendingTest) then
        onCreativeCombatTableRolled(rRoll, rSource, rTargets)
    end
end

function isAgressorWC(nodePendingTest)
    local bAgressorIsWC = DB.getValue(nodePendingTest, "attackerWC", 0) == 1
    return bAgressorIsWC
end

function getAgressorBennyPool(nodePendingTest)
    local nodeAgressor = DB.findNode(DB.getValue(nodePendingTest,"attackernodename"))
    local rAgressor = ActorManager.resolveActor(nodeAgressor)
    if rAgressor.sType == "pc" then
        local rBennySource, sConsumerName = BennyManager.getBennySource(nodeAgressor)
        return rBennySource, sConsumerName
    elseif rAgressor.sType == "npc" then
        if rAgressor.sCTNode then
            local nodeCTNode = DB.findNode(rAgressor.sCTNode)
            return DB.getChild(nodeCTNode,"bennies"), DB.getValue(nodeCTNode.getName())
        end
    end
end

function isDoubleWhammy(nodePendingTest)
    local sCCResultKeyword = DB.getValue(nodePendingTest,"ccresultkeyword")
    if sCCResultKeyword and sCCResultKeyword == "Double Whammy" then
        return true
    end
    return false
end

function getAgressorName(nodePendingTest)
    local nodeAgressor = DB.findNode(DB.getValue(nodePendingTest, "attackernodename"))
    if nodeAgressor then
        return DB.getValue(nodeAgressor,"name")
    end
    return ""
end
function getVictimName(nodePendingTest)
    local nodeVictim = nodePendingTest.getParent().getParent()
    if nodeVictim then
        return DB.getValue(nodeVictim,"name")
    end
    return ""
end

function sendSecondWindMessage(nodePendingTest)
    sAgressorName = getAgressorName(nodePendingTest)
    rMessage = {}
    rMessage.text = string.format("Second Wind: %s may remove a level of Fatigue or a Wound (their choice).", sAgressorName)
    rMessage.sender = "FastTests"
    rMessage.icon = "indicator_wounds"
    Comm.deliverChatMessage(rMessage)
end

function sendSeizeTheMomentMessage(nodePendingTest)
    sAgressorName = getAgressorName(nodePendingTest)
    rMessage = {}
    rMessage.text = string.format("Seize the Moment: After %s resolves this turn, they immediately get another entire turn (including movement). They may use the turn to go on hold.", sAgressorName)
    rMessage.sender = "FastTests"
    rMessage.icon = "powerbutton_normal"
    Comm.deliverChatMessage(rMessage)
end

function sendInsightMessage(nodePendingTest)
    sAgressorName = getAgressorName(nodePendingTest)
    sVictimName = getVictimName(nodePendingTest)
    rMessage = {}
    rMessage.text = string.format("Insight: %s has new Insight into %s's nature. Once during this encounter, they may add +d6 to any Trait roll made to directly attack, affect or damage %s.", sAgressorName, sVictimName, sVictimName)
    rMessage.sender = "FastTests"
    rMessage.icon = "d6icon"
    Comm.deliverChatMessage(rMessage)
end

function sendSetbackMessage(nodePendingTest)
    sVictimName = getVictimName(nodePendingTest)
    rMessage = {}
    rMessage.text = string.format("Setback: %s suffers a setback of some sort. She might fall off a ledge, lose the confidence of her minions (who then desert her), take a rash but foolish action, or simply lose her next turn as she attempts to recover from whatever situation she finds herself in.", sVictimName)
    rMessage.sender = "FastTests"
    rMessage.icon = "indicator_vehicle_out_of_control"
    Comm.deliverChatMessage(rMessage)
end

function requestCCRoll(nodePendingTest)
    local sAgressorNode = DB.getValue(nodePendingTest, "attackernodename")
    local nodeAgressor = DB.findNode(sAgressorNode)
    local sAgressorType = DB.getValue(nodePendingTest, "attackertype")
    local rActor = ActorManager.resolveActor(nodeAgressor)

    if sAgressorType == "pc" then
        local aUsers = User.getActiveUsers()
        if not nodeAgressor then -- Who is this guy?
            FastTests.makeCreativeCombatTableRoll(rActor, nodePendingTest) -- we cant try I guess?
            return
        end
        local sOwner = DB.getOwner(nodeAgressor)
        local bOwnerPresent = false
        if aUsers then
            for _, sUsername in pairs(aUsers) do
                if sUsername == sOwner then
                    bOwnerPresent = true
                end
            end
        end
        if not bOwnerPresent then
            FastTests.makeCreativeCombatTableRoll(rActor, nodePendingTest)
        else
            local rOOBMessage = {["type"]=OOB_MESSAGE_TYPE_TEST_CCROLL_REQUEST,
                                 ["sPendingTest"]=nodePendingTest.getPath()}
            Comm.deliverOOBMessage(rOOBMessage,sOwner)
        end
    else
        FastTests.makeCreativeCombatTableRoll(rActor, nodePendingTest)
    end
end

function onCCRollRequest(rData)
    local nodePendingTest = DB.findNode(rData.sPendingTest)
    local sAgressorNode = DB.getValue(nodePendingTest, "attackernodename")
    local nodeAgressor = DB.findNode(sAgressorNode)
    local rActor = ActorManager.resolveActor(nodeAgressor)
    FastTests.makeCreativeCombatTableRoll(rActor, nodePendingTest)
end

function onUpdateDefendTrait(rData)
    local nodePendingTest = DB.findNode(rData.sPendingTestPath)
    local sTrait = rData.sTrait
    DB.setValue(nodePendingTest,"defendattribute","string",sTrait)
end
