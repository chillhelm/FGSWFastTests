OOB_MESSAGE_TYPE_TEST_INITIATION_SUCCESS="TEST_EXT_TEST_INITIATION_SUCCESS"

function onInit()
    RollsManager.registerTraitResolutionSubHandler(nil, testTraitResolutionSubHandler)
    if User.isHost() or User.isLocal() then
        OOBManager.registerOOBMsgHandler(OOB_MESSAGE_TYPE_TEST_INITIATION_SUCCESS, onSuccessfulTestInititation)
    end
end

function testTraitResolutionSubHandler(rRoll, vRollResult, rSource, vTargets, rContext)
    if (rRoll.rCustom.attacknode ~= nil) then
        return
    end
    if not string.find(rRoll.rCustom.nodename,"skills") then
        return
    end
    targets=vTargets
    if(vTargets==nil or next(vTargets)==nil) then
        targets = TargetingManager.getFullTargets(rSource)
    end
    if next(targets)==nil then
        return
    end
    nodeSkill = DB.findNode(rRoll.rCustom.nodename)
    sAttribute = ""
    if nodeSkill then
       sAttribute = SkillManager.getLinkedAttribute(nodeSkill)
    end


    if vRollResult.nTotalScore>=4 and not vRollResult.bCriticalFailure then 
        Debug.chat("Successfull initiation")
        sendOOBMessage = { ["type"]=OOB_MESSAGE_TYPE_TEST_INITIATION_SUCCESS,
                         ["nAttackValue"] = vRollResult.nTotalScore,
                         ["sDefendAttribute"] = sAttribute,
                         ["rSource"] = rSource,
                         ["sAttackSkillNode"] = rRoll.rCustom.nodename,
                         ["vTargets"] = targets }
        Comm.deliverOOBMessage(sendOOBMessage) -- notify GM
        onSuccessfulTestInitiation(sendOOBMessage) -- even if the GM is myself 
    end
end

function onSuccessfulTestInitiation(rMessage)
    Debug.chat("onSuccessfulTestInititation")
    Debug.chat("rMessage:", rMessage)
    for _,rTarget in pairs(rMessage.vTargets) do
        nodeTarget = DB.findNode(rTarget.sCreatureNode)
        sOwnerName = nil
        if nodeTarget then
            Debug.chat(nodeTarget,"'s owner",nodeTarget.getOwner())
            sOwnerName = nodeTarget.getOwner()
        end
        aUsers = User.getActiveUsers()
        bIsOwnerPresent = false
        for _,sUser in pairs(aUsers) do
            if sUser == sOwnerName then
                bIsOwnerPresent = true
                break
            end
        end
        nodeTargetCTNode = DB.findNode(rTarget.sCTNode)
        if (nodeTargetCTNode) then
            Debug.chat("Found",nodeTarget," CT Node", nodeTargetCTNode)
            nodePendingTests = DB.createChild(nodeTargetCTNode,"pendingtests")
            nodeNewPendingTest = DB.createChild(nodePendingTests)

            nodeAttackDie = DB.findNode(rMessage.sAttackSkillNode)
            nodeAttack = nodeAttackDie and nodeAttackDie.getParent() or nil

            DB.setValue(nodeNewPendingTest, "targetvalue","number",rMessage.nAttackValue)
            DB.setValue(nodeNewPendingTest, "defendattribute","string",rMessage.sDefendAttribute)
            DB.setValue(nodeNewPendingTest, "attackertype","string",rMessage.rSource.sType)
            DB.setValue(nodeNewPendingTest, "attackernodename","string",rMessage.rSource.sCreatureNode)
            DB.setValue(nodeNewPendingTest, "attacknodename","string", nodeAttack and nodeAttack.getPath() or "")
            DB.setPublic(nodeNewPendingTest, true)
        end
    end
    return true
end
