local onItem = 0   -- current item place on the shopping list that's being searched for
local onName = nil -- the name of the current item searched for - only if it was from the list

----------------------------------------------------------------------------------------------------
-- Shopping list GUI
----------------------------------------------------------------------------------------------------
--------------------------------------------------
-- main window
--------------------------------------------------
local listFrame = CreateFrame("frame", "AuctionListFrame", UIParent)
table.insert(UISpecialFrames, listFrame:GetName()) -- make it closable with escape key
listFrame:SetFrameStrata("HIGH")
listFrame:SetBackdrop({
	bgFile="Interface/Tooltips/UI-Tooltip-Background",
	edgeFile="Interface/DialogFrame/UI-DialogBox-Border",
	tile=1, tileSize=32, edgeSize=32,
	insets={left=11, right=12, top=12, bottom=11}
})
listFrame:SetBackdropColor(0,0,0,1)
listFrame:SetPoint("CENTER")
listFrame:SetWidth(300)
listFrame:SetHeight(450)
listFrame:SetMovable(true)
listFrame:EnableMouse(true)
listFrame:RegisterForDrag("LeftButton")
listFrame:SetScript("OnDragStart", listFrame.StartMoving)
listFrame:SetScript("OnDragStop", listFrame.StopMovingOrSizing)
listFrame:SetScript("OnMouseDown", function(self, button)
	if button == "LeftButton" and not self.isMoving then
		self:StartMoving()
		self.isMoving = true
	end
end)
listFrame:SetScript("OnMouseUp", function(self, button)
	if button == "LeftButton" and self.isMoving then
		self:StopMovingOrSizing()
		self.isMoving = false
	end
end)
listFrame:SetScript("OnHide", function(self)
	if self.isMoving then
		self:StopMovingOrSizing()
		self.isMoving = false
	end
end)
listFrame:Hide()

--------------------------------------------------
-- header title
--------------------------------------------------
local textureHeader = listFrame:CreateTexture(nil, "ARTWORK")
textureHeader:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
textureHeader:SetWidth(315)
textureHeader:SetHeight(64)
textureHeader:SetPoint("TOP", 0, 12)
local textHeader = listFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
textHeader:SetPoint("TOP", textureHeader, "TOP", 0, -14)
textHeader:SetText("AuctionList 2.1")

--------------------------------------------------
-- description
--------------------------------------------------
local textDescription = listFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
textDescription:SetPoint("TOP", listFrame, "TOP", 0, -32)
textDescription:SetText("Write each search on a new line.\nYou can add a level range at the end: scroll of 60 70")

--------------------------------------------------
-- edit box and close button
--------------------------------------------------
local editBox = CreateFrame("Frame", "AuctionListEdit", listFrame)
local editBoxInput = CreateFrame("EditBox", "AuctionListEditInput", editBox)
local editBoxScroll = CreateFrame("ScrollFrame", "AuctionListEditScroll", editBox, "UIPanelScrollFrameTemplate")

-- close button - put here to be able to clear focus on the editbox
local buttonClose = CreateFrame("Button", "AuctionListButtonClose", listFrame, "UIPanelCloseButton")
buttonClose:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -8, -8)
buttonClose:SetScript("OnClick", function()
	editBoxInput:ClearFocus()
	listFrame:Hide()
end)

-- editBox - main container
editBox:SetPoint("TOP", textDescription, "BOTTOM", -10, -6)
editBox:SetPoint("BOTTOM", listFrame, "BOTTOM", 0, 12)
editBox:SetWidth(listFrame:GetRight() - listFrame:GetLeft() - 45)
editBox:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
	tile=1, tileSize=32, edgeSize=16,
	insets={left=5, right=5, top=5, bottom=5}})
editBox:SetBackdropColor(0,0,0,1)

-- editBoxInput
editBoxInput:SetMultiLine(true)
editBoxInput:SetAutoFocus(false)
editBoxInput:EnableMouse(true)
editBoxInput:SetFont("Fonts/ARIALN.ttf", 15)
editBoxInput:SetWidth(editBox:GetWidth()-20)
editBoxInput:SetHeight(editBox:GetHeight()-8)
editBoxInput:SetScript("OnEscapePressed", function() editBoxInput:ClearFocus() end)
editBoxInput:SetScript("OnEditFocusLost", function()
	-- save each line
	AuctionListSave = AuctionListSave or {}
	AuctionListSave.list = {}
	for line in string.gmatch(editBoxInput:GetText(), "[^\r\n]+") do
		table.insert(AuctionListSave.list, line)
	end
end)

-- editBoxScroll
editBoxScroll:SetPoint("TOPLEFT", editBox, "TOPLEFT", 8, -8)
editBoxScroll:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", -6, 8)
editBoxScroll:EnableMouse(true)
editBoxScroll:SetScript("OnMouseDown", function() editBoxInput:SetFocus() end)
editBoxScroll:SetScrollChild(editBoxInput)

-- taken from Blizzard's macro UI XML to handle scrolling
editBoxInput:SetScript("OnTextChanged", function()
	local scrollbar = _G[editBoxScroll:GetName() .. "ScrollBar"]
	local min, max = scrollbar:GetMinMaxValues()
	if max > 0 and this.max ~= max then
	this.max = max
	scrollbar:SetValue(max)
	end
end)
editBoxInput:SetScript("OnUpdate", function(this)
	ScrollingEdit_OnUpdate(editBoxScroll)
end)
editBoxInput:SetScript("OnCursorChanged", function()
	ScrollingEdit_OnCursorChanged(arg1, arg2, arg3, arg4)
end)

--------------------------------------------------
-- help button
--------------------------------------------------
local buttonHelp = CreateFrame("Button", "AuctionListButtonHelp", listFrame)
buttonHelp:SetWidth(16)
buttonHelp:SetHeight(16)
buttonHelp:SetNormalTexture("Interface/GossipFrame/ActiveQuestIcon")
buttonHelp:SetPoint("RIGHT", buttonClose, "LEFT", -3, 0)
buttonHelp:SetScript("OnEnter", function()
	GameTooltip:SetOwner(listFrame, "ANCHOR_NONE")
	GameTooltip:SetPoint("BOTTOM", listFrame, "TOP", 0, 0)
	GameTooltip:SetText(
[[Clicks on [L] button:
|cFF00FF00left:|r |cFFFFFFFFopen/close shopping list
|cFF00FF00other:|r |cFFFFFFFFreset searching to first item|r

Clicks on [>] and [<] buttons:
|cFF00FF00left:|r |cFFFFFFFFnext/previous page (or next item if none left)
|cFF00FF00right:|r |cFFFFFFFFnext/previous item
|cFF00FF00middle:|r |cFFFFFFFFreact to Auctioneer's snatch prompt - Buy
|cFF00FF00button4 or 5:|r |cFFFFFFFFreact to Auctioneer's snatch prompt - Pass|r
]]
	)
	GameTooltip:Show()
end)
buttonHelp:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

----------------------------------------------------------------------------------------------------
-- Handling searches and page navigation
----------------------------------------------------------------------------------------------------
-- check if the auction house is opened and can be searched right now
local function IsAuctionHouseUsable()
	if not AuctionFrame or AuctionFrame:IsVisible() ~= 1 or not CanSendAuctionQuery() then
		return false
	end
	return true
end

-- check if the current auction house item is on the search list
local function IsCurrentItemOnList()
	return BrowseName and BrowseName:GetText() == onName
end

-- search for the current item
local function AuctionListSearch(forward)
	if not IsAuctionHouseUsable() then
		return
	end

	-- turn on auctioneer's bottom scanner if it exists so that it can try to buy items on the list
	if BtmScan then
		BtmScan.BeginScan()
	end

	-- search for the current item
	local item = AuctionListSave.list[onItem]
	if item then
		-- The line format could be like any of these:
		-- scroll of
		-- scroll of 60
		-- scroll of 60 70
		local name, min, max = item:match("^([^%d]-)%s+([%d]+)%s+([%d]+)%s*$")
		if not max then
			name, min = item:match("^([^%d]-)%s+([%d]+)%s*$")
			if not min then
				name = item
			end
		end
		name = name:trim()
		onName = name
		BrowseName:SetText(name)
		BrowseMinLevel:SetText(min or "")
		BrowseMaxLevel:SetText(max or "")
		BrowseSearchButton:Click()
	else
		DEFAULT_CHAT_FRAME:AddMessage("There are no items to search for.")
	end
end

-- search for the next page or item on the list
local function AuctionListSearchNext(skip_pages)
	if not IsAuctionHouseUsable() then
		return
	end

	if onItem == 0 then
		onItem = 1
	elseif not skip_pages and BrowseNextPageButton and BrowseNextPageButton:GetButtonState() == "NORMAL" and IsCurrentItemOnList() then
		BrowseNextPageButton:Click()
		return
	else
		onItem = onItem + 1
		if not AuctionListSave.list[onItem] then
			onItem = 1
		elseif onItem == #AuctionListSave.list then
			DEFAULT_CHAT_FRAME:AddMessage("The last auction list item has been reached.")
		end
	end
	AuctionListSearch(true)
end

-- search for the previous page or item on the list
local function AuctionListSearchPrev(skip_pages)
	if not IsAuctionHouseUsable() then
		return
	end

	if onItem == 0 then
		onItem = #AuctionListSave.list
	elseif not skip_pages and BrowsePrevPageButton and BrowsePrevPageButton:GetButtonState() == "NORMAL" and IsCurrentItemOnList() then
		BrowsePrevPageButton:Click()
		return
	else
		onItem = onItem - 1
		if not AuctionListSave.list[onItem] then
			onItem = #AuctionListSave.list
		elseif onItem == 1 then
			DEFAULT_CHAT_FRAME:AddMessage("The first auction list item has been reached.")
		end
	end
	AuctionListSearch(false)
end

-- if a BtmScan snatch prompt is up, click Yes to pass the item
local function BtmScanClickYes()
	if BtmScan and BtmScan.Prompt and BtmScan.Prompt.Yes and BtmScan.Prompt.Yes:IsVisible() then
		BtmScan.Prompt.Yes:Click()
	end
end

-- if a BtmScan snatch prompt is up, click No to pass on the item
local function BtmScanClickNo()
	if BtmScan and BtmScan.Prompt and BtmScan.Prompt.No and BtmScan.Prompt.No:IsVisible() then
		BtmScan.Prompt.No:Click()
	end
end

----------------------------------------------------------------------------------------------------
-- Initializing auction frame buttons and shopping list text
----------------------------------------------------------------------------------------------------
local function AuctionList_OnEvent(self, event, addon_name)
	if event == "AUCTION_HOUSE_SHOW" then
		-- reset current search item
		onItem = 0
		onName = nil

		-- create buttons if needed
		if _G["AuctionListBack"] == nil then
			-- back button
			local buttonBack = CreateFrame("Button", "AuctionListButtonBack", AuctionFrameBrowse, "UIPanelButtonTemplate2")
			buttonBack:SetWidth(20)
			buttonBack:SetHeight(20)
			_G[buttonBack:GetName().."Text"]:SetText("<")
			buttonBack:SetPoint("RIGHT", BrowseResetButton, "LEFT", -41, 0)
			buttonBack:RegisterForClicks("AnyUp")
			buttonBack:SetScript("OnClick", function(self, button)
				editBoxInput:ClearFocus()
				if button == "LeftButton" then
					AuctionListSearchPrev(false)
				elseif button == "RightButton" then
					AuctionListSearchPrev(true)
				elseif button == "MiddleButton" then
					BtmScanClickYes()
				else
					BtmScanClickNo()
				end
			end)

			-- L (List) button
			local buttonList = CreateFrame("Button", "AuctionButtonList", AuctionFrameBrowse, "UIPanelButtonTemplate2")
			buttonList:SetWidth(20)
			buttonList:SetHeight(20)
			_G[buttonList:GetName().."Text"]:SetText("L")
			editBoxInput:ClearFocus()
			buttonList:SetPoint("LEFT", buttonBack, "RIGHT", 0, 0)
			buttonList:RegisterForClicks("AnyUp")
			buttonList:SetScript("OnClick", function(self, button)
				if button == "LeftButton" then
					if listFrame:IsVisible() then
						listFrame:Hide()
					else
						listFrame:Show()
					end
				else
					onItem = 0
					DEFAULT_CHAT_FRAME:AddMessage("You'll now start from the beginning of the shopping list.")
				end
			end)

			-- forward button
			local buttonForward = CreateFrame("Button", "AuctionButtonForward", AuctionFrameBrowse, "UIPanelButtonTemplate2")
			buttonForward:SetWidth(20)
			buttonForward:SetHeight(20)
			_G[buttonForward:GetName().."Text"]:SetText(">")
			buttonForward:SetPoint("LEFT", buttonList, "RIGHT", 0, 0)
			buttonForward:RegisterForClicks("AnyUp")
			buttonForward:SetScript("OnClick", function(self, button)
				editBoxInput:ClearFocus()
				if button == "LeftButton" then
					AuctionListSearchNext(false)
				elseif button == "RightButton" then
					AuctionListSearchNext(true)
				elseif button == "MiddleButton" then
					BtmScanClickYes()
				else
					BtmScanClickNo()
				end
			end)
		end -- if _G["AuctionListBack"] == nil
		return
	end -- if event == "AUCTION_HOUSE_SHOW"

	if event == "ADDON_LOADED" and addon_name == "AuctionList" then
		listFrame:UnregisterEvent(event)
		AuctionListSave = AuctionListSave or {}
		AuctionListSave.list = AuctionListSave.list or {}
		if next(AuctionListSave.list) ~= nil then
			editBoxInput:SetText(table.concat(AuctionListSave.list, "\n"))
		end
	end
end

listFrame:SetScript("OnEvent", AuctionList_OnEvent)
listFrame:RegisterEvent("ADDON_LOADED")       -- temporary - to set shopping list text
listFrame:RegisterEvent("AUCTION_HOUSE_SHOW") -- set current item and add buttons to frame

----------------------------------------------------------------------------------------------------
-- slash command
----------------------------------------------------------------------------------------------------
_G.SLASH_AUCTIONLIST1 = "/auctionlist"
function SlashCmdList.AUCTIONLIST(input)
	listFrame:Show()
end
