-- Global saved variables
if (BanksItems == nil) then
  BanksItems = { };
  BanksContributors = { };
end
-- Global constants:
BANKHELPER_ITEM_SCROLLFRAME_HEIGHT = 37;
local BANKITEMS_TO_DISPLAY = 7;
local BANKITEMS_VAR_VERSION = 2;
-- Global variables:
local PlayerName = nil;
local CharactersList = nil;
local CharacterSelectedID = -1;
local SortedItemColumn = 0;

-- Print function based on CTMod (CT_Master.lua)
function BHPrint(msg, r, g, b, frame)
  if (msg == nil) then
    msg = "[BankHelper] nil";
  else
    msg = "[BankHelper] " .. msg;
  end
  if ( not r ) then r=1.0; end;
  if ( not g ) then g=1.0; end;
  if ( not b ) then b=1.0; end;
  if ( frame ) then
    frame:AddMessage(msg,r,g,b);
  else
    DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b);
  end
end

-- Return the item ID from the item link
function GetItemID(itemLink)
  local id, itemId;
  itemId = 0;

  if (itemLink) then
    _,_,id = string.find(itemLink, "(item:%d+:%d+:%d+:%d+)");
    _,_,itemId = string.find(id or "","item:(%d+):%d+:%d+:%d+");
  end
  return itemId;
end -- GetItemID()

function BankHelperOnLoad()
  this:RegisterEvent("PLAYER_ENTERING_WORLD");
  this:RegisterEvent("BANKFRAME_OPENED");
  this:RegisterEvent("BANKFRAME_CLOSED");
  this:RegisterEvent("MAIL_SHOW");
  this:RegisterEvent("MAIL_CLOSED");
  BHPrint("BankHelper loaded");
end -- BankHelperOnLoad()

-- Process registered events in BankHelperOnLoad()
function BankHelperOnEvent(event)
  -- BHPrint("BankHelperOnEvent: " .. event);
  if (event == "PLAYER_ENTERING_WORLD") then
    local money = GetMoney();
    PlayerName = UnitName("player") .. "@" .. GetRealmName();

    -- Init
    if (not BanksItems or not BanksItems["version"] or BanksItems["version"] ~= BANKITEMS_VAR_VERSION) then
      BanksItems = {};
      BanksItems["version"] = BANKITEMS_VAR_VERSION;
    end
    if (not BanksItems[PlayerName]) then
      BanksItems[PlayerName] = {};
    end
    if (not BanksItems["items"]) then
      BanksItems["items"] = {};
    end
    if (not BanksItems[PlayerName]["money"]) then
      BanksItems[PlayerName]["money"] = 0;
    end
    if (not BanksItems[PlayerName]["name"]) then
      BanksItems[PlayerName]["name"] = UnitName("player");
    end
    if (not BanksItems[PlayerName]["numItems"]) then
      BanksItems[PlayerName]["numItems"] = 0;
    end
    if (not BanksItems[PlayerName]["items"]) then
      BanksItems[PlayerName]["items"] = {};
    end

    -- Check money change
    if (BanksItems[PlayerName]["money"] ~= money) then
      local moneyPrev = BanksItems[PlayerName]["money"];
      BHPrint(string.format("Player money changed since last connection: %d -> %d (difference = %d)", moneyPrev, money, (money - moneyPrev)));
      BanksItems[PlayerName]["money"] = money;
    end

    -- Populate UI:
    UIDropDownMenu_Initialize(BankHelperBankItemCharacterDropDown, BankHelperCharacterDropDownOnLoad);

  elseif (event == "MAIL_INBOX_UPDATE") then
    BankHelperOnInboxUpdate();
  elseif (event == "BANKFRAME_OPENED") then
    BankHelperOnOpenBankFrame();
  elseif (event == "BANKFRAME_CLOSED") then
    BankHelperOnCloseBankFrame();
  elseif (event == "MAIL_SHOW") then
    BankHelperOnOpenMailFrame();
  elseif (event == "MAIL_CLOSED") then
    BankHelperOnCloseMailFrame();
  end
end -- BankHelperOnEvent()

-- ================================================
-- Bank parsing
-- ================================================
function BankHelperAddItem(itemId, itemsCount, count)
  local itemLink, itemName, itemQuality, itemLevel, itemType, itemSubtype, itemTexture;
  local itemIdStr;

  itemName, itemLink, itemQuality, itemLevel, itemType, itemSubtype, _, _, itemTexture = GetItemInfo(itemId);
  itemIdStr = string.format("%d", itemId);
  -- BHPrint(string.format(" Slot %d: %s = %sx%d - lvl %d - Texture %s", slot, itemId, itemLink, itemCount, itemLevel, itemTexture));

  if (not itemsCount[itemIdStr]) then
    itemsCount[itemIdStr] = 0;
    BanksItems[PlayerName]["numItems"] = BanksItems[PlayerName]["numItems"] + 1;
  end

  if (not BanksItems["items"][itemIdStr]) then
    BanksItems["items"][itemIdStr] = {};
    BanksItems["items"][itemIdStr]["name"] = itemName;
    BanksItems["items"][itemIdStr]["db_link"] = string.format("https://www.nostalgeek-serveur.com/db/?item=%s", itemIdStr);
    BanksItems["items"][itemIdStr]["wow_link"] = itemLink;
    BanksItems["items"][itemIdStr]["texture"] = itemTexture;
    BanksItems["items"][itemIdStr]["level"] = itemLevel;
    BanksItems["items"][itemIdStr]["quality"] = itemQuality;
    BanksItems["items"][itemIdStr]["type"] = itemType;
    BanksItems["items"][itemIdStr]["subtype"] = itemSubtype;
    -- BanksItems["items"][itemIdStr]["count"] = 0;
  end
  if (not BanksItems[PlayerName]["items"][itemIdStr]) then
    BanksItems[PlayerName]["items"][itemIdStr] = 0;
  end

  itemsCount[itemIdStr] = itemsCount[itemIdStr] + count;
  BanksItems[PlayerName]["items"][itemIdStr] = itemsCount[itemIdStr];
end

function BankHelperOnOpenBankFrame()
  local itemLink, itemId, itemCount, nSlots;
  local itemIdStr;
  local itemsCount = {};
  local itemSlots = {"BACKSLOT", "CHESTSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "HANDSSLOT", "HEADSLOT", "LEGSSLOT",
    "MAINHANDSLOT", "NECKSLOT", "RANGEDSLOT", "SECONDARYHANDSLOT", "SHIRTSLOT", "SHOULDERSLOT", "TABARDSLOT",
    "TRINKET0SLOT", "TRINKET1SLOT", "WAISTSLOT", "WRISTSLOT"};

  BanksItems[PlayerName]["numItems"] = 0;
  BanksItems[PlayerName]["old_items"] = BanksItems[PlayerName]["items"];
  BanksItems[PlayerName]["items"] = {};

  -- BANK_CONTAINER = -1; -- Global variable already set in WoW API
  --Take the items in the bags:
  for bagID = BANK_CONTAINER, NUM_BAG_SLOTS+NUM_BANKBAGSLOTS, 1 do
    for slot = 1, GetContainerNumSlots(bagID) do
      itemLink = GetContainerItemLink(bagID, slot);
      if (itemLink) then
        _, itemCount = GetContainerItemInfo(bagID, slot);
        itemId = GetItemID(itemLink);
        BankHelperAddItem(itemId, itemsCount, itemCount);
      end
    end
  end

  -- Take the equip items too:
  nSlots = table.getn(itemSlots);
  for i = 1, nSlots, 1 do
    local slotId, textureName;
    slotId, textureName = GetInventorySlotInfo(itemSlots[i]);
    itemLink = GetInventoryItemLink("player", slotId);
    itemId = GetItemID(itemLink);
    if (itemId ~= 0) then
      BankHelperAddItem(itemId, itemsCount, 1);
    end
  end

  -- DEBUG:
  OpenAllBags(true);
end -- BankHelperOnOpenBankFrame()

function BankHelperOnCloseBankFrame()
  -- Close all bags
  CloseAllBags();
end -- BankHelperOnCloseBankFrame()

-- ================================================
-- Populate UI
-- ================================================
function BankHelperCharacterSort(a, b)
  return a["name"] < b["name"];
end
function BankHelperCharacterDropDownOnLoad(level)
  local id = 1;
  local index = 1;
  local info = nil;
  local nCharacters = 0;
  local pattern = ".*@" .. GetRealmName() .. "$";

  if (level == nil) then
    level = 0;
  end

  if (level == 0) then
    UIDropDownMenu_SetWidth(120, BankHelperBankItemCharacterDropDown);
  end

  -- Create the sorted character list
  if (CharactersList == nil) then
    CharactersList = {};
    nCharacters = 1;
    for key, val in BanksItems do
      if (string.find(key, pattern) ~= nil) then
        CharactersList[nCharacters] = {};
        CharactersList[nCharacters]["key"] = key;
        CharactersList[nCharacters]["name"] = val["name"];
        nCharacters = nCharacters + 1;
      end
    end
    table.sort(CharactersList, BankHelperCharacterSort);
  end

  nCharacters = table.getn(CharactersList);
  for index = 1, nCharacters, 1 do
    info         = {};
    info.text    = CharactersList[index]["name"];
    info.value   = CharactersList[index]["key"];
    info.func    = BankHelperCharacterDropDownOnSelected;
    info.checked = nil;
    if (CharacterSelectedID == -1 and info.value == PlayerName) then
      CharacterSelectedID = index;
      info.checked = true;
      BHPrint("Set CharacterSelectedID=" .. CharacterSelectedID);
    end
    UIDropDownMenu_AddButton(info, 1);
  end

  UIDropDownMenu_SetSelectedID(BankHelperBankItemCharacterDropDown, CharacterSelectedID, nil);
end

function BankHelperCharacterDropDownOnSelected()
  local characterKey;

  -- Set the global character selected ID variable
  if (this:GetID() ~= 0) then
    CharacterSelectedID = this:GetID();
  end
  characterKey = CharactersList[CharacterSelectedID]["key"];

  -- Change the UI to display the new character
  UIDropDownMenu_SetSelectedID(BankHelperBankItemCharacterDropDown, CharacterSelectedID);
  -- Reset the items scrolling
  FauxScrollFrame_SetOffset(BankHelperBankScrollFrame, 0);
  FauxScrollFrame_Update(BankHelperBankScrollFrame, 0, BANKITEMS_TO_DISPLAY, BANKHELPER_ITEM_SCROLLFRAME_HEIGHT);
  -- Update the values of scrolling bar
  FauxScrollFrame_Update(BankHelperBankScrollFrame, BanksItems[characterKey]["numItems"], BANKITEMS_TO_DISPLAY, BANKHELPER_ITEM_SCROLLFRAME_HEIGHT);
  -- Update displayed bank items
  BankHelperPopulateBankList();
end

function BankHelperPopulateBankList()
  local characterKey = CharactersList[CharacterSelectedID]["key"];
  local characterBankItems = BanksItems[characterKey]["items"];
  local numItems = BanksItems[characterKey]["numItems"];
  local numButtons = 0;
  local itemsCount = 1;
  local itemsOffset = FauxScrollFrame_GetOffset(BankHelperBankScrollFrame);
  if (numItems == nil) then
    BHPrint("Warning: no item found!");
    numItems = 0;
  end

  if (numItems == 0) then
    return;
  end

  if (numItems > BANKITEMS_TO_DISPLAY) then
    numButtons = BANKITEMS_TO_DISPLAY;
  else
    numButtons = numItems;
    -- Hide buttons if there is less items type:
    for i = (numItems + 1), BANKITEMS_TO_DISPLAY, 1 do
      getglobal("BankHelperBankItemButton" .. i):Hide();
    end
  end

  for itemIdStr, itemCount in characterBankItems do
    local itemName, itemLevel, itemTexture, itemColor, itemQuality;
    local buttonIndex = itemsCount - itemsOffset;

    if (itemsCount > itemsOffset) then
      itemName = BanksItems["items"][itemIdStr]["name"];
      -- itemCount = BanksItems["items"][itemIdStr]["count"];
      itemLevel = BanksItems["items"][itemIdStr]["level"];
      itemTexture = BanksItems["items"][itemIdStr]["texture"];
      itemQuality = BanksItems["items"][itemIdStr]["quality"];
      if (not itemQuality) then
        BHPrint("Error on item " .. itemIdStr .. " Quality is nil");
      end

      _, _, _, itemColor = GetItemQualityColor(itemQuality);
      itemName = itemColor .. itemName;

      if (not itemLevel) then
        itemLevel = 0;
      end

      -- Be sure the button is displayed:
      getglobal("BankHelperBankItemButton" .. buttonIndex):Show();

      if (itemTexture) then
        local textureName = "BankHelperBankItemButton" .. buttonIndex .. "IconTexture";
        getglobal(textureName):Show();
        getglobal(textureName):SetTexture(itemTexture);
      else
        local textureName = "BankHelperBankItemButton" .. buttonIndex .. "IconTexture";
        getglobal(textureName):Hide();
        getglobal(textureName):SetTexture(itemTexture);
      end

      getglobal("BankHelperBankItemButton" .. buttonIndex .. "Name"):SetText(itemName);
      getglobal("BankHelperBankItemButton" .. buttonIndex .. "Quality"):SetText(BH_QUALITY[itemQuality]);
      getglobal("BankHelperBankItemButton" .. buttonIndex .. "Count"):SetText(itemCount);
      getglobal("BankHelperBankItemButton" .. buttonIndex .. "Level"):SetText(itemLevel);

    end

    itemsCount = itemsCount + 1;
    if (buttonIndex >= numButtons) then
      break;
    end
  end
end

-- ================================================
-- Mail parsing
-- ================================================
function BankHelperOnOpenMailFrame()
  -- Unregistered in BankHelperOnInboxUpdate()
  BankHelperMain:RegisterEvent("MAIL_INBOX_UPDATE");
  CheckInbox();
end -- BankHelperOnOpenMailFrame()

function BankHelperOnCloseMailFrame()
  local numItems;

  numItems = GetInboxNumItems();
  BHPrint("BankHelperOnCloseMailFrame: " .. numItems .. " mails left");
end -- BankHelperOnCloseMailFrame()

function BankHelperOnInboxUpdate()
  local numItems;

  BankHelperMain:UnregisterEvent("MAIL_INBOX_UPDATE");

  numItems = GetInboxNumItems();
  if (numItems > 0) then
    BHPrint(string.format("Number of mail items: %d", numItems));
  else
    BHPrint("No items in your mailbox");
    return;
  end

  -- Get list
  for i = 1, numItems, 1 do
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i);

    if (money == 0 and not hasItem) then
      -- Ignore this mail.
      return
    end

    if (not sender) then
      sender = "Inconnu";
    end
    if (not subject) then
      subject = "Aucun sujet";
    end
    BHPrint(string.format("Mail %d/%d: from %s: %s ", i, numItems, sender, subject));

    if (money > 0) then
      BHPrint(string.format("  Money: %d", money));
    end
    if (hasItem) then
      local itemName, itemTexture, itemCount, itemQuality, itemCanUse = GetInboxItem(i, itemIndex)
      BHPrint(string.format("  Item: [%s]x%d", itemName, itemCount));
    end
  end
end -- BankHelperOnInboxUpdate()
