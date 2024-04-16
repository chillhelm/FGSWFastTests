function onButtonPress()
    FastTests.makeDefendRoll(window.getDatabaseNode())
end

function onDrop(x, y, dragdata)
    if dragdata.getType() == "traitdice" then
        window.updateDefendTrait(dragdata.getStringData())
        FastTests.makeDefendRoll(window.getDatabaseNode(), dragdata.getStringData())
        return true
    end
    if dragdata.getType() == "benny" then
        local bennySource = dragdata.getStringData()
        local actor = dragdata.getDescription()
        rActor = {}
        if actor == "GM" then
            rActor["recordname"] = "GM"
        else
            rActor["recordname"] = DB.findNode(bennySource).getParent().getParent().getPath()
        end
        BennyManager.rerollTraitDrop(rActor, dragdata.getStringData())
        FastTests.makeDefendRoll(window.getDatabaseNode(), nil, true)
        return true
    end
end
