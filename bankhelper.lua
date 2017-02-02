-- Global saved variables
if (BanksItems == nil) then
  BanksItems = { };
  BanksContributors = { };
end
-- Global constants:
BANKHELPER_ITEM_SCROLLFRAME_HEIGHT = 37;
local BANKITEMS_TO_DISPLAY = 7;
local BANKITEMS_VAR_VERSION = 2;
local MAILITEMS_TO_DISPLAY = 6;
local MAILITEM_MAX_DAYS = 30.0;
local MAILBOX_CLOSE_NEED_UPDATE = 1;
local MAILBOX_CLOSE    = 0;
local MAILBOX_OPEN     = 1;
local MAILBOX_UPDATING = 2;
local MAILBOX_RECOVER  = 3;
local MAILBOX_RECOVER_ERROR = 4;
-- Global variables:
local PlayerName = nil;
local CharactersList = nil;
local CharacterSelectedID = -1;
local SortedItemColumn = 0;
local LastUpdateMailboxTime = 0;
local ItemsFilter = {};
ItemsFilter.count = 0;
ItemsFilter.text = nil;
ItemsFilter.items = {};
ItemsFilter.sortColumn = "name";
ItemsFilter.sortAscendant = true;
local MailBoxStatus = 0; -- Mail frame current status
local MailBoxItems = {};


local function BoolToStr(val)
  if (val) then
    return "true";
  else
    return "false";
  end
end
-- Convert EPOCH time (in seconds since 01/01/1970 to a human readable format)
-- Thanks to MINIX2 source code !
local function TimeToStr(val)
  local YEAR0 = 1970;
  local SECS_DAY = 24 * 60 * 60;
  local YTAB = {
    { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 },
    { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
  };

  local t_sec, t_min, t_hour, t_mday, t_wday, t_month, t_year;
  local dayclock, dayno;
  local year = YEAR0;

  local function leapyear(_year)
    if (mod(_year, 4) ~= 0) then
      return 0;
    elseif (mod(_year, 100) ~= 0) then
      return 1;
    elseif (mod(_year, 400) ~= 0) then
      return 0;
    else
      return 1;
    end
  end
  local function yearsize(_year)
    if (leapyear(_year) == 1) then
      return 366
    else
      return 365;
    end
  end

  dayclock = mod(val, SECS_DAY);
  dayno = math.floor(val / SECS_DAY);

  t_sec = mod(dayclock, 60);
  t_min = mod(dayclock, 3600) / 60;
  t_hour = math.floor(dayclock / 3600);
  t_wday = mod((dayno + BH_WEEK_THURSDAY), 7) + 1; -- Day 0 was a thursday

  while (dayno >= yearsize(year)) do
    dayno = dayno - yearsize(year);
    year = year + 1;
  end

  t_year = year;
  t_month = 1;
  -- BHPrint(string.format("leapyear(%d)=%s", year, leapyear(year)));
  while (dayno >= YTAB[leapyear(year) + 1][t_month]) do
    dayno = dayno - YTAB[leapyear(year) + 1][t_month];
    t_month = t_month + 1;
  end
  t_mday = dayno + 1;

  return string.format(BH_UI_MAIL_RECV_DATE, BH_DAYS_NAME[t_wday], t_mday, t_month, t_year, t_hour, t_min);
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
  this:RegisterEvent("UI_ERROR_MESSAGE");
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
    BHPrint("MAIL_SHOW");
    BankHelperOnOpenMailFrame();
  elseif (event == "MAIL_CLOSED") then
    BHPrint("MAIL_CLOSED");
    BankHelperOnCloseMailFrame();
  elseif (event == "MAIL_INBOX_UPDATE") then
      local currentTime = time();
      -- Prevent too many update when opening the mail box
      if (currentTime > LastUpdateMailboxTime) then
        BHPrint(string.format("MAIL_INBOX_UPDATE: %d -> %d", LastUpdateMailboxTime, currentTime));
        BankHelperOnInboxUpdate();
        LastUpdateMailboxTime = currentTime;
      end
  elseif (event == "UI_ERROR_MESSAGE") then
    BHPrint("UI_ERROR_MESSAGE - TODO");
    if (MailBoxStatus == MAILBOX_RECOVER) then
      MailBoxStatus = MAILBOX_RECOVER_ERROR;
      BankHelperFetchMails("EVENT");
    end
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
  ShowUIPanel(BankHelperUIFrame);
  BankHelperTabBarTab2:Click();
  if (MailBoxStatus == MAILBOX_CLOSE) then
    MailBoxStatus = MAILBOX_OPEN;
  elseif (MailBoxStatus == MAILBOX_CLOSE_NEED_UPDATE) then
    MailBoxStatus = MAILBOX_OPEN;
    BankHelperOnInboxUpdate();
  end

end -- BankHelperOnOpenMailFrame()

function BankHelperOnCloseMailFrame()
  local numItems;
  if (MailBoxStatus >= MAILBOX_OPEN) then
    numItems = GetInboxNumItems();
    BHPrint("BankHelperOnCloseMailFrame: " .. numItems .. " mails left");
    MailBoxStatus = MAILBOX_CLOSE;
    HideUIPanel(BankHelperUIFrame);
  end
end -- BankHelperOnCloseMailFrame()

-- @brief Fetch available mails items
function BankHelperOnInboxUpdate()
  local numItems;

  if (MailBoxStatus ~= MAILBOX_OPEN) then
    BHPrint(string.format("BankHelperOnInboxUpdate: Invalid MailBoxStatus(%d) ~= MAILBOX_OPEN(%d)", MailBoxStatus, MAILBOX_OPEN));
    if (MailBoxStatus == MAILBOX_CLOSE) then
      MailBoxStatus = MAILBOX_CLOSE_NEED_UPDATE;
    end
    return;
  end

  MailBoxStatus = MAILBOX_UPDATING;
  MailBoxItems = {};

  numItems = GetInboxNumItems();
  if (numItems > 0) then
    BHPrint(string.format("Number of mail items: %d", numItems));
    BankHelperFetchMailButton:Enable();
  else
    BHPrint("No items in your mailbox");
    BankHelperPopulateMailList();
    MailBoxStatus = MAILBOX_OPEN;
    BankHelperFetchMailButton:Disable();
    return;
  end

  -- Get list
  for i = 1, numItems, 1 do
    local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i);
    local mailBoxItem = {};

    -- if (sender == "") then
    --   BHPrint("sender is empty");
    --   LastUpdateMailboxTime = 0;
    -- end

    mailBoxItem.index = i;
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
    -- Estimate the send/receive date:
    mailBoxItem.receiveDate = time() + math.floor((daysLeft-MAILITEM_MAX_DAYS)*24.0*60.0*60.0);

    -- Inbox text
    mailBoxItem.text = nil;
    mailBoxItem.texture = nil;
    mailBoxItem.isTakeable = nil;
    mailBoxItem.isInvoice = nil;
    -- Inbox item
    mailBoxItem.itemName = nil;
    mailBoxItem.itemTexture = nil;
    mailBoxItem.itemCount = nil;
    mailBoxItem.itemQuality = nil;
    mailBoxItem.itemCanUse = nil;

    --[[
    if (hasItem) then
      local itemName, itemTexture, itemCount, itemQuality, itemCanUse = GetInboxItem(i);

      if (itemName) then
        -- local itemLink = GetInboxItemLink(i);
        if (itemCount == nil) then
          itemCount = -1;
        end
        if (itemQuality == nil) then
          itemQuality = -1;
        end
        mailBoxItem.itemName = itemName;
        mailBoxItem.itemTexture = itemTexture;
        mailBoxItem.itemCount = itemCount;
        mailBoxItem.itemQuality = itemQuality;
        mailBoxItem.itemCanUse = itemCanUse;
      end
    end
    ]]

    table.insert(MailBoxItems, mailBoxItem);
  end

  BankHelperPopulateMailList();
  -- BHPrint("BankHelperOnInboxUpdate: end");
  MailBoxStatus = MAILBOX_OPEN;
end -- BankHelperOnInboxUpdate()

-- @brief Display available mails items
function BankHelperPopulateMailList()
  -- BHPrint("BankHelperPopulateMailList");

  local itemsOffset;
  local nMails = table.getn(MailBoxItems);
  local nMailsDisplay = nMails;
  -- Hide mail item if needed
  if (nMails > MAILITEMS_TO_DISPLAY) then
    nMailsDisplay = MAILITEMS_TO_DISPLAY;
  else
    for i = nMails+1, MAILITEMS_TO_DISPLAY, 1 do
      local buttonMailItem = getglobal(string.format("BankHelperMailEntry%d", i));
      -- BHPrint(string.format("BankHelperMailEntry%d", i));
      buttonMailItem:Hide();
      buttonMailItem.mailItem = nil;
    end
  end
  --
  FauxScrollFrame_Update(BankHelperMailScrollFrame, nMails, MAILITEMS_TO_DISPLAY, BANKHELPER_ITEM_SCROLLFRAME_HEIGHT);
  itemsOffset = FauxScrollFrame_GetOffset(BankHelperMailScrollFrame);

  -- BHPrint(string.format("Number of saved mail info: %d", nMails));

  for i = 1, nMailsDisplay, 1 do
    local buttonName = string.format("BankHelperMailEntry%d", i);
    local buttonMailItem = getglobal(buttonName);
    local icon, mailIdx;
    local mailBoxItem;

    mailIdx = i + itemsOffset;
    mailBoxItem = MailBoxItems[mailIdx];
    if (mailBoxItem.packageIcon) then
      icon = mailBoxItem.packageIcon;
    else
      icon = mailBoxItem.stationeryIcon;
    end
    buttonMailItem:Show();
    buttonMailItem.mailItem = mailBoxItem;
    if (icon) then
      getglobal(buttonName .. "IconTexture"):SetTexture(icon);
    else
      getglobal(buttonName .. "IconTexture"):SetTexture();
    end
    getglobal(buttonName .. "Sender"):SetText(mailBoxItem.sender);
    getglobal(buttonName .. "Subject"):SetText(mailBoxItem.subject);
    getglobal(buttonName .. "ExpireTime"):SetText(string.format(BH_UI_MAIL_DAYS_LEFT, math.floor(mailBoxItem.daysLeft)));
    getglobal(buttonName .. "ReceiveDate"):SetText(TimeToStr(mailBoxItem.receiveDate));
  end
end

function BankHelperFetchMailButtonOnClick()
  if (MailBoxStatus == MAILBOX_OPEN) then
    MailBoxStatus = MAILBOX_RECOVER;
    BankHelperFetchMailButton:Disable();
    BankHelperFetchMails("BUTTON");
  end
end

-- @brief Recovers all item received
-- @par Since TakeInboxItem() is an async function, we can't simply do a loop with all mail items
-- BankHelperFetchMailButtonOnClick() -> BankHelperFetchMails("BUTTON")
--    TakeInboxItem() -> Generate event MAIL_INBOX_UPDATE
--      BankHelperOnEvent(MAIL_INBOX_UPDATE) -> BankHelperFetchMails("EVENT")
function BankHelperFetchMails(source)
  local bodyText, texture, isTakeable, isInvoice;
  if (MailBoxStatus == MAILBOX_RECOVER and source == "BUTTON") then
    local nMails = table.getn(MailBoxItems);
    for i = 1, nMails, 1 do
      mailBoxItem = MailBoxItems[i];
      if (mailBoxItem.hasItem and mailBoxItem.CODAmount == 0 and not mailBoxItem.isGM) then
        BHPrint(string.format("Mail %d/%d: Get [%s]x%d", i, nMails, mailBoxItem.itemName, mailBoxItem.itemCount));

        -- Read message content (will generate an MAIL_INBOX_UPDATE):
        mailBoxItem.bodyText, mailBoxItem.texture, mailBoxItem.isTakeable, mailBoxItem.isInvoice = GetInboxText(i);
        -- TakeInboxItem will generate an MAIL_INBOX_UPDATE or UI_ERROR_MESSAGE event
        TakeInboxItem(mailBoxItem.index);
        -- TakeInboxMoney
        table.insert(BanksContributors, mailBoxItem);
        return; -- end here, wait for the MAIL_INBOX_UPDATE event
      end
    end
    -- No item to recover
    MailBoxStatus = MAILBOX_OPEN;
    BankHelperFetchMailButton:Enable();
    BankHelperOnInboxUpdate();
  elseif (MailBoxStatus == MAILBOX_RECOVER_ERROR) then
    BHPrint("Error recovering all mails items");
    MailBoxStatus = MAILBOX_OPEN;
    BankHelperFetchMailButton:Enable();
    BankHelperOnInboxUpdate();
  else
    BHPrint(string.format("Call to BankHelperFetchMails(%s) invalid: MailBoxStatus=%d", source, MailBoxStatus), 1.0, 0.3, 0.3);
  end
end
