--
-- Please see the license.html file included with this distribution for
-- attribution and copyright information.
--

function onInit()
	if User.isHost() then
		registerMenuItem(Interface.getString("ct_menu_pendingentries_delete_all"), "logoff", 4)
	end
	getDatabaseNode().onChildUpdate = update
	update()
end

function onMenuSelection(nOption)
	if nOption == 4 then
		for _,node in pairs(getDatabaseNode().getChildren()) do
			node.delete()
		end
	end
end

function update()
	local bVisible = getDatabaseNode().getChildCount() > 0
	setVisible(bVisible)
	window.pendingtestsection.setVisible(bVisible)
end

