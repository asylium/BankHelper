-- Global saved variables
if (BanksItems == nil) then
  BanksItems = { };
  BanksContributors = { };
end
-- Global constants:
BANKHELPER_ITEM_SCROLLFRAME_HEIGHT = 37;
local BANKITEMS_TO_DISPLAY = 7;
local BANKITEMS_VAR_VERSION = 2;
local MAILITEMS_TO_DISPLAY = 3;
-- Global variables:
local PlayerName = nil;
local CharactersList = nil;
local CharacterSelectedID = -1;
local SortedItemColumn = 0;
local ItemsFilter = {};
ItemsFilter.count = 0;
ItemsFilter.text = nil;
ItemsFilter.items = {};
ItemsFilter.sortColumn = "name";
ItemsFilter.sortAscendant = true;
local MailFrameOpened = 0;
local MailBoxItems = {};


function BoolToStr(val)
  if (val) then
    return "true";
  else
    return "false";
  end
end
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
  this:RegisterEvent("MAIL_INBOX_UPDATE");
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

  elseif (event == "BANKFRAME_OPENED") then
    BankHelperOnOpenBankFrame();
  elseif (event == "BANKFRAME_CLOSED") then
    BankHelperOnCloseBankFrame();
  elseif (event == "MAIL_SHOW") then
    BankHelperOnOpenMailFrame();
  elseif (event == "MAIL_CLOSED") then
    BankHelperOnCloseMailFrame();
  elseif (event == "MAIL_INBOX_UPDATE") then
    BankHelperOnInboxUpdate();
    BankHelperPopulateMailList();
  end
end -- BankHelperOnEvent()

-- ================================================
-- Bank Items
-- ================================================
--  parsing
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

  -- Update filtering list
  -- BankHelperUpdateItemFilter(nil);

  -- DEBUG:
  OpenAllBags(true);
end -- BankHelperOnOpenBankFrame()

function BankHelperOnCloseBankFrame()
  -- Close all bags
  CloseAllBags();
end -- BankHelperOnCloseBankFrame()

-- Sort function
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

  -- BHPrint("BankHelperCharacterDropDownOnLoad("..level..")");

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
      -- BHPrint("Set CharacterSelectedID=" .. CharacterSelectedID);
    end
    UIDropDownMenu_AddButton(info, 1);
  end

  UIDropDownMenu_SetSelectedID(BankHelperBankItemCharacterDropDown, CharacterSelectedID, nil);
end

-- Item Filtering
function BankHelperUpdateItemFilter(itemNameFilter)
  local index = 1;
  local itemIdStr, itemCount, itemName;
  local pattern;
  local characterKey = CharactersList[CharacterSelectedID]["key"];
  local characterBankItems = BanksItems[characterKey]["items"];

  -- BHPrint("BankHelperUpdateItemFilter");

  if (itemNameFilter == nil) then
    if (ItemsFilter.text == nil) then
      itemNameFilter = "";
    else
      itemNameFilter = ItemsFilter.text;
    end
  end

  if (itemNameFilter == "") then
    ItemsFilter.text  = nil;
    ItemsFilter.count = BanksItems[characterKey]["numItems"];
    ItemsFilter.items = {};
    for itemIdStr, itemCount in characterBankItems do
      local infos = {};
      infos.id = itemIdStr;
      infos.count = itemCount;
      ItemsFilter.items[index] = infos;
      index = index + 1;
    end
  else
    -- BHPrint("Filtering with \"" .. itemNameFilter .. "\"");
    ItemsFilter.text = itemNameFilter;
    ItemsFilter.items = {};
    pattern = ".*" .. string.lower(itemNameFilter) .. ".*";
    for itemIdStr, itemCount in characterBankItems do
      itemName = BanksItems["items"][itemIdStr]["name"];
      if (string.find(string.lower(itemName), pattern)) then
        local infos = {};
        infos.id = itemIdStr;
        infos.count = itemCount;
        ItemsFilter.items[index] = infos;
        index = index + 1;
      end
    end
    ItemsFilter.count = index - 1;
  end

  -- Update UI:
  BankHelperOnItemsDisplayedListChanged();
end

function BankHelperCharacterDropDownOnSelected()
  -- Set the global character selected ID variable
  if (this:GetID() ~= 0) then
    CharacterSelectedID = this:GetID();
  end

  -- BHPrint("BankHelperCharacterDropDownOnSelected");
  -- Update item list with the filter
  BankHelperUpdateItemFilter(nil);
end

function BankHelperOnItemsDisplayedListChanged()
  -- BHPrint("BankHelperOnItemsDisplayedListChanged");
  -- Change the UI to display the new character
  UIDropDownMenu_SetSelectedID(BankHelperBankItemCharacterDropDown, CharacterSelectedID);
  -- Reset the items scrolling
  FauxScrollFrame_SetOffset(BankHelperBankScrollFrame, 0);
  getglobal(BankHelperBankScrollFrame:GetName() .. "ScrollBar"):SetValue(0);

  -- Update displayed bank items
  BankHelperOnSortBankItem(nil);
end

-- Sort items:
function BankHelperCompareBankItem(a, b)
  local itemIdStrA, itemIdStrB, cmp;

  itemIdStrA = a.id;
  itemIdStrB = b.id;

  cmp = false;

  -- For some reason, if I do "cmp = not cmp" for descending sort, there is an LUA error.
  if (ItemsFilter.sortAscendant) then
    if (ItemsFilter.sortColumn == "name") then
      cmp = BanksItems["items"][itemIdStrA]["name"] < BanksItems["items"][itemIdStrB]["name"];
    elseif (ItemsFilter.sortColumn == "quality") then
      cmp = BanksItems["items"][itemIdStrA]["quality"] < BanksItems["items"][itemIdStrB]["quality"];
    elseif (ItemsFilter.sortColumn == "level") then
      cmp = BanksItems["items"][itemIdStrA]["level"] < BanksItems["items"][itemIdStrB]["level"];
    elseif (ItemsFilter.sortColumn == "quantity") then
      cmp = a.count < b.count;
    else
      BHPrint("Unknown sort column: " .. ItemsFilter.sortColumn);
    end
  else
    if (ItemsFilter.sortColumn == "name") then
      cmp = BanksItems["items"][itemIdStrA]["name"] > BanksItems["items"][itemIdStrB]["name"];
    elseif (ItemsFilter.sortColumn == "quality") then
      cmp = BanksItems["items"][itemIdStrA]["quality"] > BanksItems["items"][itemIdStrB]["quality"];
    elseif (ItemsFilter.sortColumn == "level") then
      cmp = BanksItems["items"][itemIdStrA]["level"] > BanksItems["items"][itemIdStrB]["level"];
    elseif (ItemsFilter.sortColumn == "quantity") then
      cmp = a.count > b.count;
    else
      BHPrint("Unknown sort column: " .. ItemsFilter.sortColumn);
    end
  end

  return cmp;
end
function BankHelperOnSortBankItem(sortColumn)
  if (not sortColumn) then
    sortColumn = ItemsFilter.sortColumn;
    ItemsFilter.sortAscendant = not ItemsFilter.sortAscendant;
  end

  if (sortColumn == "name" or sortColumn == "quality" or sortColumn == "level" or sortColumn == "quantity") then
    if (sortColumn == ItemsFilter.sortColumn) then
      ItemsFilter.sortAscendant = not ItemsFilter.sortAscendant;
    else
      ItemsFilter.sortAscendant = true;
    end
    ItemsFilter.sortColumn = sortColumn;
    table.sort(ItemsFilter.items, BankHelperCompareBankItem);
  end

  BankHelperPopulateBankList();
end

function BankHelperPopulateBankList()
  local itemIdStr, itemCount;
  local numButtons = 0;
  local itemsIndex = 1;
  local buttonIndex = 1;
  local itemsCountMax;
  local itemsOffset = FauxScrollFrame_GetOffset(BankHelperBankScrollFrame);

  if (ItemsFilter.count > BANKITEMS_TO_DISPLAY) then
    numButtons = BANKITEMS_TO_DISPLAY;
  else
    local i;
    numButtons = ItemsFilter.count;
    -- Hide buttons if there is less items type:
    for i = (ItemsFilter.count + 1), BANKITEMS_TO_DISPLAY, 1 do
      getglobal("BankHelperBankItemButton" .. i):Hide();
    end
  end

  FauxScrollFrame_Update(BankHelperBankScrollFrame, ItemsFilter.count, BANKITEMS_TO_DISPLAY, BANKHELPER_ITEM_SCROLLFRAME_HEIGHT);

  if (ItemsFilter.count == 0) then
    return;
  end

  itemsCountMax = itemsOffset + numButtons;
  if (itemsCountMax > (itemsOffset + numButtons)) then
    itemsCountMax = itemsOffset + numButtons - 1;
  end

  -- BHPrint("itemsOffset=" .. itemsOffset .. " itemsCountMax=" .. itemsCountMax);

  for itemIndex = itemsOffset + 1, itemsCountMax, 1 do
    local buttonName;
    local itemName, itemLevel, itemTexture, itemColor, itemQuality;

    -- BHPrint("itemIndex=" .. itemIndex .. " buttonIndex=" .. buttonIndex);
    itemIdStr = ItemsFilter.items[itemIndex].id;
    itemCount = ItemsFilter.items[itemIndex].count;
    itemName = BanksItems["items"][itemIdStr]["name"];
    itemLevel = BanksItems["items"][itemIdStr]["level"];
    itemTexture = BanksItems["items"][itemIdStr]["texture"];
    itemQuality = BanksItems["items"][itemIdStr]["quality"];

    if (not itemQuality) then
      BHPrint("Error on item " .. itemIdStr .. " Quality is nil");
      itemColor = "";
    else
      _, _, _, itemColor = GetItemQualityColor(itemQuality);
      itemName = itemColor .. itemName;
    end

    if (not itemLevel) then
      itemLevel = 0;
    end

    -- Be sure the button is displayed:
    buttonName = "BankHelperBankItemButton" .. buttonIndex;
    getglobal(buttonName):Show();
    getglobal(buttonName):SetID(tonumber(itemIdStr));

    if (itemTexture) then
      local textureName = buttonName .. "IconTexture";
      getglobal(textureName):Show();
      getglobal(textureName):SetTexture(itemTexture);
    else
      local textureName = buttonName .. "IconTexture";
      getglobal(textureName):Hide();
      getglobal(textureName):SetTexture(itemTexture);
    end

    getglobal(buttonName .. "Name"):SetText(itemName);
    getglobal(buttonName .. "Quality"):SetText(BH_QUALITY[itemQuality]);
    getglobal(buttonName .. "Count"):SetText(itemCount);
    getglobal(buttonName .. "Level"):SetText(itemLevel);

    buttonIndex = buttonIndex + 1;
  end
end

-- Display item tooltip
function BankHelperBankItemButtonOnEnter()
  local itemLink = string.format("item:%d:0:0:0", this:GetID());
  GameTooltip:SetOwner(this, "ANCHOR_LEFT");
  GameTooltip:SetHyperlink(itemLink);
  GameTooltip:Show();
end
-- Hide item tooltip
function BankHelperBankItemButtonOnLeave()
  GameTooltip:Hide();
  ResetCursor();
end

-- ================================================
-- Mail parsing
-- ================================================
function BankHelperOnOpenMailFrame()
  -- CheckInbox();
  if (MailFrameOpened == 0) then
    MailFrameOpened = 1;
    -- BHPrint("BankHelperOnOpenMailFrame");
  else
    BHPrint("BankHelperOnOpenMailFrame: Mail frame already opened!");
  end
end -- BankHelperOnOpenMailFrame()

function BankHelperOnCloseMailFrame()
  local numItems;
  if (MailFrameOpened >= 1) then
    numItems = GetInboxNumItems();
    BHPrint("BankHelperOnCloseMailFrame: " .. numItems .. " mails left");
    MailFrameOpened = 0;
  else
    -- BHPrint("BankHelperOnCloseMailFrame: Mail frame already closed!");
  end
end -- BankHelperOnCloseMailFrame()

function BankHelperOnInboxUpdate()
  local numItems;

  if (MailFrameOpened == 0) then
    BHPrint("BankHelperOnInboxUpdate: Mail frame not opened!");
  elseif (MailFrameOpened == 2) then
    return;
  end

  MailFrameOpened = 2;

  numItems = GetInboxNumItems();
  if (numItems > 0) then
    BHPrint(string.format("Number of mail items: %d", numItems));
  else
    BHPrint("No items in your mailbox");
    return;
  end

  -- file = io.open("asyl_bank_mail.txt", "a");
  -- io.output(file);
  -- io.write(string.format("Date: %d\n"), os.time());
  -- io.write(string.format("Number of mail items: %d\n", numItems));

  BHPrint(string.format("Date: %d\n", time()));

  MailBoxItems = {};

  -- Get list
  for i = 1, numItems, 1 do
    local bodyText, texture, isTakeable, isInvoice;
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i);
    local mailBoxItem = {};

    mailBoxItem.packageIcon = packageIcon;
    mailBoxItem.stationeryIcon = stationeryIcon;
    mailBoxItem.sender = sender;
    mailBoxItem.subject = subject;
    mailBoxItem.CODAmount = CODAmount;
    mailBoxItem.daysLeft = daysLeft;
    mailBoxItem.hasItem = hasItem;
    mailBoxItem.wasReturned = wasReturned;
    mailBoxItem.textCreated = textCreated;
    mailBoxItem.canReply = canReply;
    mailBoxItem.isGM = isGM;

    -- TakeInboxItem(i);
    -- Read message content:
    bodyText, texture, isTakeable, isInvoice = GetInboxText(i);

    mailBoxItem.text = bodyText;
    mailBoxItem.texture = texture;
    mailBoxItem.isTakeable = isTakeable;
    mailBoxItem.isInvoice = isInvoice;

    if (not wasRead) then
      table.insert(MailBoxItems, mailBoxItem);
    else
      BHPrint(string.format("Mail %d/%d: Already read", i, numItems));
      table.insert(MailBoxItems, mailBoxItem);
    end

    if (not sender) then
      sender = "Inconnu";
    end
    if (not subject) then
      subject = "Aucun sujet";
    end

    BHPrint(string.format("Mail %d/%d: from %s: %s (%s;%s;%s)", i, numItems, sender, subject, texture, BoolToStr(isTakeable), BoolToStr(isInvoice)));
    if (bodyText) then
      BHPrint(string.format("  Text: %s", bodyText));
    else
      BHPrint("  No text message");
    end

    if (not isGM and (money > 0 or hasItem)) then

      if (money > 0) then
        -- BHPrint(string.format("  Money: %d", money));
      end
      if (hasItem) then
        local itemName, itemTexture, itemCount, itemQuality, itemCanUse = GetInboxItem(i);

        if (itemName) then
          -- local itemLink = GetInboxItemLink(i);
          -- io.write(string.format("Mail %d/%d: from %s: %s [money=%d item='%s' count='%d']\n", i, numItems, sender, subject, money, itemName, itemCount));
          if (itemCount == nil) then
            itemCount = -1;
          end
          if (itemQuality == nil) then
            itemQuality = -1;
          end
          BHPrint(string.format("  Item: [%s]x%d quality=%d can use:%s", itemName, itemCount, itemQuality, BoolToStr(itemCanUse)));
        else
          -- io.write(string.format("Mail %d/%d: from %s: %s [money=%d] WoW Error!\n", i, numItems, sender, subject, money));
          -- BHPrint("  Item: [??]x?? -> WoW Error");
        end
      else
        -- io.write(string.format("Mail %d/%d: from %s: %s [money=%d]\n", i, numItems, sender, subject, money));
      end
    end
  end
  -- BHPrint("BankHelperOnInboxUpdate: end");
  -- io.close(file);
end -- BankHelperOnInboxUpdate()

function BankHelperPopulateMailList()
  BHPrint("BankHelperPopulateMailList");

  local nMails = table.getn(MailBoxItems);
  if (nMails > MAILITEMS_TO_DISPLAY) then
    nMails = MAILITEMS_TO_DISPLAY;
  end

  BHPrint(string.format("Number of saved mail info: %d", nMails));

  for i = 1, nMails, 1 do
    local buttonName = string.format("BankHelperMailEntry%d", i);
    local icon;
    if (packageIcon) then
      icon = MailBoxItems[i].packageIcon;
    else
      icon = MailBoxItems[i].stationeryIcon;
    end
    getglobal(buttonName):Show();
    if (icon) then
      getglobal(buttonName .. "IconTexture"):Show();
      getglobal(buttonName .. "IconTexture"):SetTexture(icon);
    else
      getglobal(buttonName .. "IconTexture"):Hide();
      getglobal(buttonName .. "IconTexture"):SetTexture();
    end
    getglobal(buttonName .. "Sender"):SetText(MailBoxItems[i].sender);
    getglobal(buttonName .. "Subject"):SetText(MailBoxItems[i].subject);
  end
end
