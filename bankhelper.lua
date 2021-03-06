-- Global saved variables
if (BankHelperDatas == nil) then
  BankHelperDatas = { };
end
-- Global constants:
BANKHELPER_ITEM_SCROLLFRAME_HEIGHT = 37;

local BANKHELPER_VAR_VERSION = 6;
local BANKHELPER_DEBUG = false;
local MAIL_ACTION_DELAY = 0.3;
local MAIL_ACTION_TIMEOUT_DELAY = 5.0;

local BANKITEMS_TO_DISPLAY = 7;
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
local BankHelperSendMailInfos = {};

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

  while (dayno >= YTAB[leapyear(year) + 1][t_month]) do
    dayno = dayno - YTAB[leapyear(year) + 1][t_month];
    t_month = t_month + 1;
  end
  t_mday = dayno + 1;

  return string.format(BH_UI_MAIL_RECV_DATE, BH_DAYS_NAME[t_wday], t_mday, t_month, t_year, t_hour, t_min);
end

function MoneyToStr(money)
  local neg = "";
  if (money < 0) then
    neg = "-";
    money = -money;
  end
  local gold = floor(money / (COPPER_PER_SILVER * SILVER_PER_GOLD));
  local silver = floor((money - (gold * COPPER_PER_SILVER * SILVER_PER_GOLD)) / COPPER_PER_SILVER);
  local copper = mod(money, COPPER_PER_SILVER);
  return string.format("%s%dg %ds %dc", neg, gold, silver, copper);
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

local function LogDebug(msg, r, g, b)
  if (BankHelperDatas and BankHelperDatas["options"] and BankHelperDatas["options"]["debug"]) then
    msg = "[BankHelper] DEBUG: " .. msg;
    if ( not r ) then r=1.0; end;
    if ( not g ) then g=1.0; end;
    if ( not b ) then b=1.0; end;
    DEFAULT_CHAT_FRAME:AddMessage(msg, r, g, b);
  end
end

-- Return the item ID from the item link
local function GetItemID(itemLink)
  local id, itemId;
  itemId = 0;

  if (itemLink) then
    _,_,id = string.find(itemLink, "(item:%d+:%d+:%d+:%d+)");
    _,_,itemId = string.find(id or "","item:(%d+):%d+:%d+:%d+");
  end
  return itemId;
end -- GetItemID()

-- @brief Migration / Init of preferences
local function BHInitData()
  local money = GetMoney();
  local playerData = nil;

  if (not BankHelperDatas or not BankHelperDatas["version"]) then
    BankHelperDatas = {};
    BankHelperDatas["version"] = 0;
  end

  if (BankHelperDatas["version"] < 1) then
    BankHelperDatas["items"] = {};
    BankHelperDatas["players"] = {};
    BankHelperDatas["version"] = 1;
  end

  if (BankHelperDatas["version"] < 2) then
    BankHelperDatas["locale"] = GetLocale();
    BankHelperDatas["compte"] = "";
    BankHelperDatas["guilde"] = "";
    BankHelperDatas["save_equip_items"] = false;
    BankHelperDatas["version"] = 2;
  end

  if (BankHelperDatas["version"] < 3) then
    BankHelperDatas["options"] = {};
    BankHelperDatas["options"]["compte"] = BankHelperDatas["compte"];
    BankHelperDatas["options"]["guilde"] = BankHelperDatas["guilde"];
    BankHelperDatas["options"]["save_equip_items"] = BankHelperDatas["save_equip_items"];
    BankHelperDatas["options"]["save_contrib"] = true;
    BankHelperDatas["options"]["contrib_send"] = false;
    BankHelperDatas["compte"]  = nil;
    BankHelperDatas["guilde"]  = nil;
    BankHelperDatas["save_equip_items"]  = nil;
    BankHelperDatas["version"] = 3;
  end

  if (BankHelperDatas["version"] < 4) then
    BankHelperDatas["options"]["debug"] = false;
    BankHelperDatas["options"]["mail_action_delay"] = 0.3;
    BankHelperDatas["all_mails"] = {};
    BankHelperDatas["contribs"] = {};
    BankHelperDatas["version"] = 4;
  end

  if (BankHelperDatas["version"] < 5) then
    BankHelperDatas["options"]["ignore_contributors"] = {};
    table.insert(BankHelperDatas["options"]["ignore_contributors"], "Hôtel des ventes de Stormwind");
    table.insert(BankHelperDatas["options"]["ignore_contributors"], "Stormwind Auction House");
    BankHelperDatas["mouvements"] = BankHelperDatas["contribs"];
    BankHelperDatas["options"]["mouvements_sent"] = BankHelperDatas["options"]["contrib_send"];
    BankHelperDatas["all_mails"] = nil;
    BankHelperDatas["contribs"] = nil;
    BankHelperDatas["prev_contribs"] = nil;
    BankHelperDatas["options"]["contrib_send"] = nil;
    BankHelperDatas["version"] = 5;
  end

  -- Version 6: Add Mail C.O.D. Infos.
  if (BankHelperDatas["version"] < 6) then
    BankHelperDatas["version"] = 6;
  end

  if (BANKHELPER_VAR_VERSION ~= BankHelperDatas["version"]) then
    BHPrint("Error in BankHelperDatas version", 1.0, 0.0, 0.0);
  end

  if (BankHelperDatas["options"]["compte"] == "" or BankHelperDatas["options"]["guilde"] == "") then
    BHPrint("Please configure your account and guilde name", 1.0, 0.2, 0.2);
  end

  if (not BankHelperDatas["players"][PlayerName]) then
    playerData = {};
  else
    playerData = BankHelperDatas["players"][PlayerName];
  end

  if (not playerData["name"]) then
    playerData["name"] = UnitName("player");
  end
  if (not playerData["money"]) then
    playerData["money"] = 0;
  end
  if (not playerData["numItems"]) then
    playerData["numItems"] = 0;
  end
  if (not playerData["last_update"]) then
    playerData["last_update"] = 0;
  end
  if (not playerData["items"]) then
    playerData["items"] = {};
  end

  -- Check money change
  if (playerData["money"] ~= money) then
    local moneyPrev = playerData["money"];
    BHPrint(string.format("Player money changed since last connection: %s -> %s (difference = %s)",
      MoneyToStr(moneyPrev), MoneyToStr(money), MoneyToStr(money - moneyPrev)));
    playerData["money"] = money;
  end

  BankHelperDatas["players"][PlayerName] = playerData;

  if (BankHelperDatas["options"]["mouvements_sent"]) then
    BankHelperDatas["old_mouvements"] = BankHelperDatas["mouvements"];
    BankHelperDatas["options"]["mouvements_sent"] = false;
    BankHelperDatas["mouvements"] = {};
  end

  MAIL_ACTION_DELAY = BankHelperDatas["options"]["mail_action_delay"];
end

function BankHelperOnLoad()
  this:RegisterEvent("PLAYER_ENTERING_WORLD");
  this:RegisterEvent("VARIABLES_LOADED");
  this:RegisterEvent("BANKFRAME_OPENED");
  this:RegisterEvent("BANKFRAME_CLOSED");
  this:RegisterEvent("MAIL_SHOW");
  this:RegisterEvent("MAIL_INBOX_UPDATE");
  this:RegisterEvent("MAIL_CLOSED");
  this:RegisterEvent("UI_ERROR_MESSAGE");
  this:RegisterEvent("BAG_UPDATE");
  this:RegisterEvent("MAIL_SEND_SUCCESS");
  this:RegisterEvent("MAIL_FAILED");
  BHPrint("Add-on loaded", 1.0, 0.8, 0.0);
end -- BankHelperOnLoad()

-- Process registered events in BankHelperOnLoad()
local eventStack = 0;
function BankHelperOnEvent(event)
  -- LogDebug(string.format("BankHelperOnEvent(%s): %d BEGIN", event, eventStack), 0.1, 0.1, 0.8);
  eventStack = eventStack + 1;

  if (event == "PLAYER_ENTERING_WORLD") then
    PlayerName = UnitName("player") .. "@" .. GetRealmName();
    BHInitData();
  elseif (event == "VARIABLES_LOADED") then
    if (BankHelperDatas["options"]) then
      BankHelperOptionSaveEquip:SetChecked(BankHelperDatas["options"]["save_equip_items"]);
      BankHelperOptionSaveContrib:SetChecked(BankHelperDatas["options"]["save_contrib"]);
      BankHelperOptionShowDebug:SetChecked(BankHelperDatas["options"]["debug"]);
      BankHelperOptionAccount:SetText(BankHelperDatas["options"]["compte"]);
      BankHelperOptionGuild:SetText(BankHelperDatas["options"]["guilde"]);
    end
  elseif (event == "BANKFRAME_OPENED") then
    BankHelperOnOpenBankFrame();
  elseif (event == "BANKFRAME_CLOSED") then
    BankHelperOnCloseBankFrame();
  elseif (event == "BAG_UPDATE") then
    if (MailBoxStatus == MAILBOX_RECOVER) then
      BankHelperFetchMails(event);
    end
  elseif (event == "MAIL_SHOW") then
    BankHelperOnOpenMailFrame();
  elseif (event == "MAIL_CLOSED") then
    BankHelperOnCloseMailFrame();
  elseif (event == "MAIL_INBOX_UPDATE") then
    if (MailBoxStatus == MAILBOX_RECOVER) then
      BankHelperFetchMails(event);
    else
      local currentTime = time();
      -- Prevent too many update when opening the mail box
      if (currentTime > LastUpdateMailboxTime) then
        BankHelperOnInboxUpdate();
        LastUpdateMailboxTime = currentTime;
      end
    end
  elseif (MailBoxStatus == MAILBOX_RECOVER and event == "UI_ERROR_MESSAGE") then
    BankHelperFetchMails(event);
  elseif (MailBoxStatus == MAILBOX_OPEN and event == "MAIL_SEND_SUCCESS") then
    BankHelperOnSendMailEvent(true);
  elseif (MailBoxStatus == MAILBOX_OPEN and event == "MAIL_FAILED") then
    BankHelperOnSendMailEvent(false);
  end

  eventStack = eventStack - 1;
  -- LogDebug(string.format("BankHelperOnEvent(%s): %d END", event, eventStack), 0.1, 0.1, 0.8);
end -- BankHelperOnEvent()

-- ================================================
-- Bank Items
-- ================================================
local function BankHelperAddItemDescription(itemId)
  local itemLink, itemName, itemQuality, itemLevel, itemType, itemSubtype, itemTexture;
  itemName, itemLink, itemQuality, itemLevel, itemType, itemSubtype, _, _, itemTexture = GetItemInfo(itemId);

  if (not BankHelperDatas["items"][itemId]) then
    BankHelperDatas["items"][itemId] = {};
    BankHelperDatas["items"][itemId]["name"] = itemName;
    BankHelperDatas["items"][itemId]["wow_link"] = itemLink;
    BankHelperDatas["items"][itemId]["texture"] = itemTexture;
    BankHelperDatas["items"][itemId]["level"] = itemLevel;
    BankHelperDatas["items"][itemId]["quality"] = itemQuality;
    BankHelperDatas["items"][itemId]["type"] = itemType;
    BankHelperDatas["items"][itemId]["subtype"] = itemSubtype;
  end
end

--  parsing
local function BankHelperAddItem(itemId, itemsCount, count)

  if (not itemsCount[itemId]) then
    itemsCount[itemId] = 0;
    BankHelperDatas["players"][PlayerName]["numItems"] = BankHelperDatas["players"][PlayerName]["numItems"] + 1;
  end

  BankHelperAddItemDescription(itemId);

  if (not BankHelperDatas["players"][PlayerName]["items"][itemId]) then
    BankHelperDatas["players"][PlayerName]["items"][itemId] = 0;
  end

  itemsCount[itemId] = itemsCount[itemId] + count;
  BankHelperDatas["players"][PlayerName]["items"][itemId] = itemsCount[itemId];
end

function BankHelperOnOpenBankFrame()
  local itemLink, itemId, itemCount, slot, nSlots;
  local itemsCount = {};
  local itemSlots = {"BACKSLOT", "CHESTSLOT", "FEETSLOT", "FINGER0SLOT", "FINGER1SLOT", "HANDSSLOT", "HEADSLOT", "LEGSSLOT",
    "MAINHANDSLOT", "NECKSLOT", "RANGEDSLOT", "SECONDARYHANDSLOT", "SHIRTSLOT", "SHOULDERSLOT", "TABARDSLOT",
    "TRINKET0SLOT", "TRINKET1SLOT", "WAISTSLOT", "WRISTSLOT"};

  BankHelperDatas["players"][PlayerName]["numItems"] = 0;
  BankHelperDatas["players"][PlayerName]["last_update"] = time();
  BankHelperDatas["players"][PlayerName]["old_items"] = BankHelperDatas["players"][PlayerName]["items"];
  BankHelperDatas["players"][PlayerName]["items"] = {};

  -- BANK_CONTAINER = -1; -- Global variable already set in WoW API
  --Take the items in the bags:
  for bagID = BANK_CONTAINER, NUM_BAG_SLOTS+NUM_BANKBAGSLOTS, 1 do
    nSlots = GetContainerNumSlots(bagID);
    for slot = 1, nSlots, 1 do
      itemLink = GetContainerItemLink(bagID, slot);
      if (itemLink) then
        _, itemCount = GetContainerItemInfo(bagID, slot);
        itemId = GetItemID(itemLink);
        BankHelperAddItem(itemId, itemsCount, itemCount);
      end
    end
  end

  -- Take the equip items too:
  if (BankHelperDatas["options"]["save_equip_items"]) then
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
local function BankHelperCharacterSort(a, b)
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
    for key, val in BankHelperDatas["players"] do
      if (string.find(key, pattern) ~= nil) then
        CharactersList[nCharacters] = {};
        CharactersList[nCharacters]["key"] = key;
        CharactersList[nCharacters]["name"] = val["name"];
        nCharacters = nCharacters + 1;
      end
    end
    table.sort(CharactersList, BankHelperCharacterSort);
  end

  -- Create the "All Characters"
  info         = {};
  info.text    = BH_ALL_CHAR;
  info.value   = "all";
  info.func    = BankHelperCharacterDropDownOnSelected;
  info.checked = false;
  UIDropDownMenu_AddButton(info, 1);

  nCharacters = table.getn(CharactersList);
  for index = 1, nCharacters, 1 do
    info         = {};
    info.text    = CharactersList[index]["name"];
    info.value   = CharactersList[index]["key"];
    info.func    = BankHelperCharacterDropDownOnSelected;
    info.checked = false;
    if (CharacterSelectedID == -1 and info.value == PlayerName) then
      CharacterSelectedID = index + 1;
      info.checked = true;
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
  local characterKey, characterData, characterBankItems, characterNumBankItems;
  local itemsOwners = nil;

  if (CharacterSelectedID > 1) then
    -- Specific character selected
    characterKey = CharactersList[CharacterSelectedID - 1]["key"];
    characterBankItems = BankHelperDatas["players"][characterKey]["items"];
    characterNumBankItems = BankHelperDatas["players"][characterKey]["numItems"];
  else
    -- Display all characters items
    itemsOwners = {};
    characterBankItems = {};
    characterNumBankItems = 0;
    for characterKey, characterData in BankHelperDatas["players"] do
      for itemIdStr, itemCount in characterData["items"] do
        if (characterBankItems[itemIdStr]) then
          characterBankItems[itemIdStr] = characterBankItems[itemIdStr] + itemCount;
          itemsOwners[itemIdStr] = itemsOwners[itemIdStr] .. ", " .. characterData["name"];
        else
          characterBankItems[itemIdStr] = itemCount;
          characterNumBankItems = characterNumBankItems + 1;
          itemsOwners[itemIdStr] = characterData["name"];
        end
      end
    end
  end

  if (itemNameFilter == nil) then
    if (ItemsFilter.text == nil) then
      itemNameFilter = "";
    else
      itemNameFilter = ItemsFilter.text;
    end
  end

  if (itemNameFilter == "") then
    ItemsFilter.text  = nil;
    ItemsFilter.count = characterNumBankItems;
    ItemsFilter.items = {};
    for itemIdStr, itemCount in characterBankItems do
      local infos = {};
      infos.id = itemIdStr;
      infos.count = itemCount;
      if (itemsOwners) then
        infos.owners = itemsOwners[itemIdStr];
      end
      ItemsFilter.items[index] = infos;
      index = index + 1;
    end
  else
    ItemsFilter.text = itemNameFilter;
    ItemsFilter.items = {};
    pattern = ".*" .. string.lower(itemNameFilter) .. ".*";
    for itemIdStr, itemCount in characterBankItems do
      itemName = BankHelperDatas["items"][itemIdStr]["name"];
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
  -- Update item list with the filter
  BankHelperUpdateItemFilter(nil);
end

function BankHelperOnItemsDisplayedListChanged()
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
      cmp = BankHelperDatas["items"][itemIdStrA]["name"] < BankHelperDatas["items"][itemIdStrB]["name"];
    elseif (ItemsFilter.sortColumn == "quality") then
      cmp = BankHelperDatas["items"][itemIdStrA]["quality"] < BankHelperDatas["items"][itemIdStrB]["quality"];
    elseif (ItemsFilter.sortColumn == "level") then
      cmp = BankHelperDatas["items"][itemIdStrA]["level"] < BankHelperDatas["items"][itemIdStrB]["level"];
    elseif (ItemsFilter.sortColumn == "quantity") then
      cmp = a.count < b.count;
    else
      BHPrint("Unknown sort column: " .. ItemsFilter.sortColumn);
    end
  else
    if (ItemsFilter.sortColumn == "name") then
      cmp = BankHelperDatas["items"][itemIdStrA]["name"] > BankHelperDatas["items"][itemIdStrB]["name"];
    elseif (ItemsFilter.sortColumn == "quality") then
      cmp = BankHelperDatas["items"][itemIdStrA]["quality"] > BankHelperDatas["items"][itemIdStrB]["quality"];
    elseif (ItemsFilter.sortColumn == "level") then
      cmp = BankHelperDatas["items"][itemIdStrA]["level"] > BankHelperDatas["items"][itemIdStrB]["level"];
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
  local itemIdStr, itemCount, itemOwners;
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

  for itemIndex = itemsOffset + 1, itemsCountMax, 1 do
    local buttonName;
    local itemName, itemLevel, itemTexture, itemColor, itemQuality;

    itemIdStr = ItemsFilter.items[itemIndex].id;
    itemCount = ItemsFilter.items[itemIndex].count;
    itemOwners = ItemsFilter.items[itemIndex].owners;
    itemName = BankHelperDatas["items"][itemIdStr]["name"];
    itemLevel = BankHelperDatas["items"][itemIdStr]["level"];
    itemTexture = BankHelperDatas["items"][itemIdStr]["texture"];
    itemQuality = BankHelperDatas["items"][itemIdStr]["quality"];

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

    if (CharacterSelectedID > 1) then
      getglobal(buttonName .. "Owners"):SetText("");
    else
      getglobal(buttonName .. "Owners"):SetText(itemOwners);
    end

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
    HideUIPanel(BankHelperUIFrame);
  end
  MailBoxStatus = MAILBOX_CLOSE;
  BankHelperSendMailInfos = {};
end -- BankHelperOnCloseMailFrame()

local function BankHelperGetHeaderInfo(index)
  local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, hasItem, wasRead, wasReturned, noMessage, canReply, isGM = GetInboxHeaderInfo(index);
  local mailBoxItem = {};

  -- If no sender set it to "Unknown"
  if (not sender) then
    sender = UNKNOWN;
  end

  mailBoxItem.index = index;

  mailBoxItem.packageIcon = packageIcon;
  mailBoxItem.stationeryIcon = stationeryIcon;
  mailBoxItem.sender = sender;
  mailBoxItem.to = UnitName("player");
  mailBoxItem.subject = subject;
  mailBoxItem.money = money;
  mailBoxItem.CODAmount = CODAmount;
  mailBoxItem.daysLeft = daysLeft;
  mailBoxItem.hasItem = hasItem;
  mailBoxItem.wasRead = wasRead;
  mailBoxItem.wasReturned = wasReturned;
  mailBoxItem.noMessage = noMessage;
  mailBoxItem.canReply = canReply;
  mailBoxItem.isGM = isGM;
  mailBoxItem.canDelete = InboxItemCanDelete(index);
  -- Estimate the send/receive date:
  mailBoxItem.receiveDate = time() + math.floor((daysLeft-MAILITEM_MAX_DAYS)*24.0*60.0*60.0);

  -- Inbox text
  mailBoxItem.bodyText = nil;
  mailBoxItem.texture = nil;
  mailBoxItem.isTakeable = nil;
  mailBoxItem.isInvoice = nil;
  -- Inbox item
  mailBoxItem.itemName = nil;
  mailBoxItem.itemTexture = nil;
  mailBoxItem.itemCount = nil;
  mailBoxItem.itemQuality = nil;
  mailBoxItem.itemCanUse = nil;

  return mailBoxItem;
end

-- @brief Fetch available mails items
function BankHelperOnInboxUpdate()
  local numItems;
  local mailBoxItems = {};

  if (MailBoxStatus ~= MAILBOX_OPEN) then
    LogDebug(string.format("BankHelperOnInboxUpdate: Invalid MailBoxStatus(%d) ~= MAILBOX_OPEN(%d)", MailBoxStatus, MAILBOX_OPEN));
    if (MailBoxStatus == MAILBOX_CLOSE) then
      MailBoxStatus = MAILBOX_CLOSE_NEED_UPDATE;
    end
    return mailBoxItems;
  end

  MailBoxStatus = MAILBOX_UPDATING;

  numItems = GetInboxNumItems();
  if (numItems > 0) then
    local i;
    BankHelperFetchMailButton:Enable();
    for i = 1, numItems, 1 do
      table.insert(mailBoxItems, BankHelperGetHeaderInfo(i));
    end
  else
    BankHelperFetchMailButton:Disable();
  end

  BankHelperPopulateMailList(mailBoxItems);
  MailBoxStatus = MAILBOX_OPEN;
  return mailBoxItems;
end -- BankHelperOnInboxUpdate()

local bhpmlMailBoxItems = nil;
-- @brief Display available mails items
function BankHelperPopulateMailList(mailBoxItems)
  if (mailBoxItems) then
    bhpmlMailBoxItems = mailBoxItems;
  end

  local i, itemsOffset;
  local nMails = table.getn(bhpmlMailBoxItems);
  local nMailsDisplay = nMails;
  -- Hide mail item if needed
  if (nMails > MAILITEMS_TO_DISPLAY) then
    nMailsDisplay = MAILITEMS_TO_DISPLAY;
  else
    for i = nMails+1, MAILITEMS_TO_DISPLAY, 1 do
      local buttonMailItem = getglobal(string.format("BankHelperMailEntry%d", i));
      buttonMailItem:Hide();
      buttonMailItem.mailItem = nil;
    end
  end
  --
  FauxScrollFrame_Update(BankHelperMailScrollFrame, nMails, MAILITEMS_TO_DISPLAY, BANKHELPER_ITEM_SCROLLFRAME_HEIGHT);
  itemsOffset = FauxScrollFrame_GetOffset(BankHelperMailScrollFrame);

  for i = 1, nMailsDisplay, 1 do
    local buttonName = string.format("BankHelperMailEntry%d", i);
    local buttonMailItem = getglobal(buttonName);
    local icon, mailIdx;
    local mailBoxItem;

    mailIdx = i + itemsOffset;
    mailBoxItem = bhpmlMailBoxItems[mailIdx];
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

function BankHelperGetBagsItemsList()
  local itemLink, itemCount, itemId, bagID, slot, nSlots;
  local itemLink, itemName, itemQuality, itemLevel, itemType, itemSubtype, itemTexture;
  local itemsList = {};

  for bagID = 0, NUM_BAG_SLOTS, 1 do
    nSlots = GetContainerNumSlots(bagID);
    for slot = 1, nSlots, 1 do
      itemLink = GetContainerItemLink(bagID, slot);
      if (itemLink) then
        _, itemCount = GetContainerItemInfo(bagID, slot);
        itemId = GetItemID(itemLink);
        itemName, itemLink, itemQuality, itemLevel, itemType, itemSubtype, _, _, itemTexture = GetItemInfo(itemId);
        if (itemsList[itemId]) then
          itemsList[itemId].count = itemsList[itemId].count + itemCount;
        else
          itemsList[itemId] = {}
          itemsList[itemId].id = itemId;
          itemsList[itemId].name = itemName;
          itemsList[itemId].type = itemType;
          itemsList[itemId].subtype = itemSubtype;
          itemsList[itemId].count = itemCount;
        end
      end
    end
  end

  return itemsList;
end

function BankHelperGetAddItemId(listA, listB)
  if (not listA or not listB) then
    LogDebug("BankHelperGetAddItemId(): Parameter error");
    return 0;
  end

  local idA, itemInfoA;
  local idB, itemInfoB;

  for idB in pairs(listB) do
    itemInfoB = listB[idB];
    LogDebug(string.format("BankHelperGetAddItemId(): Search for [%s]x%d", idB, itemInfoB.count));
    if (not listA[idB]) then
      -- found, new item
      return idB;
    end

    for idA in pairs(listA) do
      itemInfoA = listA[idA];
      if (idA == idB and itemInfoA.name == itemInfoB.name and itemInfoA.type == itemInfoB.type and itemInfoA.count ~= itemInfoB.count) then
        -- found, existing item
        return idB;
      end
    end
  end

  LogDebug("BankHelperGetAddItemId(): ItemId not found");
  return 0;
end

function BankHelperAddMouvement(mailBoxItem)

  if (not BankHelperDatas["options"]["save_contrib"]) then
    -- Do not save contributions on this account
    return;
  end

  -- Check the ignore list
  local nIgnore = table.getn(BankHelperDatas["options"]["ignore_contributors"]);
  local i;
  for i = 1, nIgnore, 1 do
    if (mailBoxItem.sender == BankHelperDatas["options"]["ignore_contributors"][i]) then
      -- Contributor is in the ignore list, so do nothing
      return;
    end
  end

  local mouvement = {};
  mouvement.sender = mailBoxItem.sender;
  mouvement.to = mailBoxItem.to;
  mouvement.receiveDate = mailBoxItem.receiveDate;
  mouvement.sendDate = mailBoxItem.sendDate;
  mouvement.subject = mailBoxItem.subject;
  mouvement.bodyText = mailBoxItem.bodyText;
  mouvement.cod = mailBoxItem.cod;
  mouvement.itemName = mailBoxItem.itemName;
  mouvement.itemCount = mailBoxItem.itemCount;
  -- mouvement.itemQuality = mailBoxItem.itemQuality;
  mouvement.wasReturned = mailBoxItem.wasReturned;
  -- mouvement.itemTexture = mailBoxItem.itemTexture;
  -- mouvement.texture = mailBoxItem.texture;
  -- mouvement.isInvoice = mailBoxItem.isInvoice;
  -- mouvement.mailIndex = mailBoxItem.index;
  -- mouvement.itemTaken = mailBoxItem.itemTaken;
  mouvement.itemId = mailBoxItem.itemId;
  mouvement.money = mailBoxItem.money;
  -- mouvement.mailBoxItem = mailBoxItem;
  table.insert(BankHelperDatas["mouvements"], mouvement);

  local msgInfo = "";

  if (mouvement.receiveDate) then
    msgInfo = string.format("Add contribution from %s:", mouvement.sender);
  else
    msgInfo = string.format("Send to %s:", mouvement.to);
  end

  if (mouvement.itemName) then
    msgInfo = string.format("%s [%d][%s]x%d", msgInfo, mouvement.itemId, mouvement.itemName, mouvement.itemCount);
  end
  if (mouvement.money) then
    msgInfo = string.format("%s [%s]", msgInfo, MoneyToStr(mouvement.money));
  end
  if (mouvement.cod) then
    msgInfo = string.format("%s (cod)", msgInfo);
  end

  BHPrint(msgInfo);

  if (mouvement.bodyText and mouvement.bodyText ~= "") then
    BHPrint(mouvement.subject, 0.0, 0.7, 0.1);
    BHPrint(mouvement.bodyText, 0.1, 0.9, 0.3);
  end

  return mouvement;
end

local bhfmAction = "NONE"; -- WAIT_READ / NEXT_MAIL / DELETE / GET_ITEM
local bhfmMailBoxItem = nil;
local bhfmWaitDelay = 0;
function BankHelperFetchMails(source)
  local function isContribMail(mbi)
    return ((mbi.hasItem or mbi.money > 0) and ((not mbi.CODAmount) or mbi.CODAmount == 0) and (not mbi.isGM) and (not mbi.isInvoice));
  end

  LogDebug(string.format("BankHelperFetchMails(%s): BEGIN action=%s", source, bhfmAction), 0.8, 0.8, 0.0);

  if (MailBoxStatus ~= MAILBOX_RECOVER) then
    LogDebug(string.format("BankHelperFetchMails(%s): invalid MailBoxStatus %d ~= %d", source, MailBoxStatus, MAILBOX_RECOVER), 1.0, 0.3, 0.3);
    return;
  end

  if (source == "BUTTON" or source == "DO_NEXT_MAIL") then

    if (source == "BUTTON") then
      bhfmMailBoxItem = nil;
      bhfmAction = "NONE";
      MailBoxStatus = MAILBOX_OPEN;
      bhfmMailBoxItems = BankHelperOnInboxUpdate();
      MailBoxStatus = MAILBOX_RECOVER;
      BankHelperDatas["all_mails"] = bhfmMailBoxItems;
    end

    local nMails = GetInboxNumItems();
    if (nMails > 0) then
      local i;
      for i = 1, nMails, 1 do
        bhfmMailBoxItem = BankHelperGetHeaderInfo(i);
        if (isContribMail(bhfmMailBoxItem)) then
          -- Read the message
          LogDebug(string.format("  BankHelperFetchMails(%s): GetInboxText(%d)", source, i), 0.8, 0.8, 0.8);
          LogDebug(string.format("BankHelperFetchMails(%s): END action=%s", source, bhfmAction), 0.8, 0.8, 0.0);

          if (not bhfmMailBoxItem.wasRead) then
            if (bhfmMailBoxItem.noMessage) then
              bhfmAction = "WAIT_READ_NO_MESSAGE";
            else
              bhfmAction = "WAIT_READ_MESSAGE";
            end
            GetInboxText(i);
          else
            -- Simulate "MAIL_INBOX_UPDATE" event
            bhfmAction = "WAIT_READ_NO_MESSAGE";
            BankHelperFetchMails("MAIL_INBOX_UPDATE");
          end -- if (not bhfmMailBoxItem.wasRead)

          return;

        end -- if (isContribMail())
      end -- for i = 1, nMails, 1
    end -- if (nMails > 0)

    BankHelperFetchMails("DO_DELETE_EMPTY_MAILS");

    MailBoxStatus = MAILBOX_OPEN;
    bhfmAction = "NONE";
    bhfmMailBoxItem = nil;
    BankHelperOnInboxUpdate();

  elseif (source == "MAIL_INBOX_UPDATE") then
    if (bhfmAction == "WAIT_READ_NO_MESSAGE") then
      bhfmWaitDelay = 0;
      if (bhfmMailBoxItem.hasItem) then
        bhfmAction = "WAIT_TIMER_TAKE_ITEM";
      elseif (bhfmMailBoxItem.money > 0) then
        bhfmAction = "WAIT_TIMER_TAKE_MONEY";
      else
        BHPrint(string.format("Invalid mail %d", bhfmMailBoxItem.index), 0.8, 0.1, 0.1);
        bhfmAction = "NONE";
      end
    elseif (bhfmAction == "WAIT_READ_MESSAGE") then
      bhfmAction = "WAIT_READ_MESSAGE_TEXT";
      bhfmWaitDelay = 0;
    elseif (bhfmAction == "WAIT_READ_MESSAGE_TEXT") then
      local bodyText, texture, isTakeable, isInvoice = GetInboxText(bhfmMailBoxItem.index);
      bhfmMailBoxItem.bodyText = bodyText;
      bhfmMailBoxItem.texture = texture;
      bhfmMailBoxItem.isTakeable = isTakeable;
      bhfmMailBoxItem.isInvoice = isInvoice;

      bhfmWaitDelay = 0;
      if (bhfmMailBoxItem.hasItem) then
        bhfmAction = "WAIT_TIMER_TAKE_ITEM";
      elseif (bhfmMailBoxItem.money > 0) then
        bhfmAction = "WAIT_TIMER_TAKE_MONEY";
      else
        BHPrint(string.format("Invalid mail %d", bhfmMailBoxItem.index), 0.8, 0.1, 0.1);
        bhfmAction = "NONE";
      end
    elseif (bhfmAction == "WAIT_MONEY_TAKEN") then
      bhfmAction = "WAIT_TIMER_TO_DELETE_MESSAGE";
    elseif (bhfmAction == "WAIT_ICON_MESSAGE_UPDATE_THEN_DELETE") then
      bhfmAction = "WAIT_MESSAGE_DELETE";
    elseif (bhfmAction == "WAIT_ICON_MESSAGE_UPDATE") then
      bhfmWaitDelay = 0;
      bhfmAction = "WAIT_TIMER_TO_DELETE_MESSAGE";
    elseif (bhfmAction == "WAIT_MESSAGE_DELETE") then

      MailBoxStatus = MAILBOX_OPEN;
      BankHelperOnInboxUpdate();
      MailBoxStatus = MAILBOX_RECOVER;

      bhfmWaitDelay = 0;
      bhfmAction = "WAIT_TIMER_DO_NEXT_MAIL";
    else
      LogDebug(string.format("BankHelperFetchMails(%s): END action=%s - Unexpected MAIL_INBOX_UPDATE event", source, bhfmAction), 0.8, 0.8, 0.0);
    end
  -- end source == "MAIL_INBOX_UPDATE"
  elseif (source == "BAG_UPDATE") then
    if (bhfmAction == "WAIT_BAG_UPDATE") then
      if (bhfmMailBoxItem.money > 0) then
        bhfmAction = "WAIT_TIMER_TAKE_MONEY";
        bhfmWaitDelay = 0;
      elseif (bhfmMailBoxItem.noMessage) then
        bhfmAction = "WAIT_ICON_MESSAGE_UPDATE_THEN_DELETE";
      else
        bhfmAction = "WAIT_ICON_MESSAGE_UPDATE";
      end
    end -- WAIT_BAG_UPDATE
  elseif (source == "UI_ERROR_MESSAGE") then
    BHPrint(string.format("Error: bags full or unique item?"), 0.8, 0.1, 0.1);
    if (bhfmAction == "WAIT_BAG_UPDATE") then
      bhfmAction = "NONE";
      MailBoxStatus = MAILBOX_OPEN;
    end
  elseif (source == "DO_DELETE_EMPTY_MAILS") then
    -- TODO
  else
    BHPrint(string.format("BankHelperFetchMails(%s): END action=%s - Unexpected call", source, bhfmAction), 0.8, 0.8, 0.0);
  end -- if (source == "xx")

  LogDebug(string.format("BankHelperFetchMails(%s): END action=%s", source, bhfmAction), 0.8, 0.8, 0.0);
end

function BankHelperOnUpdate(elapse)
  if (MailBoxStatus ~= MAILBOX_RECOVER) then
    return;
  end

  bhfmWaitDelay = bhfmWaitDelay + elapse;

  if (bhfmWaitDelay < MAIL_ACTION_DELAY) then
    -- wait MAIL_ACTION_DELAY seconds
    return;
  end

  if (bhfmAction == "WAIT_TIMER_TO_DELETE_MESSAGE") then
    local index = bhfmMailBoxItem.index;
    local mailBoxItem = BankHelperGetHeaderInfo(index);

    bhfmAction = "WAIT_MESSAGE_DELETE";
    bhfmWaitDelay = 0;
    if ((not mailBoxItem.hasItem or mailBoxItem.hasItem == 0) and mailBoxItem.money == 0) then
      DeleteInboxItem(index);
    else
      BHPrint(string.format("  BankHelperOnUpdate(%s) - Error mail %d as an item or money", bhfmAction, index), 0.8, 0.8, 0.8);
      MailBoxStatus = MAILBOX_OPEN;
      bhfmAction = "NONE";
    end

  elseif (bhfmAction == "WAIT_TIMER_TAKE_ITEM") then
    local index = bhfmMailBoxItem.index;
    bhfmMailBoxItem.itemName, bhfmMailBoxItem.itemTexture, bhfmMailBoxItem.itemCount, bhfmMailBoxItem.itemQuality, bhfmMailBoxItem.itemCanUse = GetInboxItem(index);
    bhfmAction = "WAIT_BAG_UPDATE";
    bhfmMailBoxItem.itemTaken = false;
    bhfmMailBoxItem.itemsBagsPreTake = BankHelperGetBagsItemsList();
    TakeInboxItem(index);
  elseif (bhfmAction == "WAIT_TIMER_TAKE_MONEY") then
    bhfmAction = "WAIT_MONEY_TAKEN";
    TakeInboxMoney(bhfmMailBoxItem.index);
  elseif (bhfmAction == "WAIT_TIMER_DO_NEXT_MAIL") then
    if (not bhfmMailBoxItem.hasItem) then
      if (bhfmMailBoxItem.money > 0) then
        BankHelperAddMouvement(bhfmMailBoxItem);
      end
    elseif (bhfmMailBoxItem.itemTaken == false) then
      local itemId;
      bhfmMailBoxItem.itemTaken = true;
      bhfmMailBoxItem.itemsBagsPostTake = BankHelperGetBagsItemsList();
      itemId = BankHelperGetAddItemId(bhfmMailBoxItem.itemsBagsPreTake, bhfmMailBoxItem.itemsBagsPostTake);
      bhfmMailBoxItem.itemId = itemId;
      -- Update the player's items count:
      if (itemId == 0) then
        BHPrint(string.format("Item ID for %s not found", bhfmMailBoxItem.itemName), 1.0, 0.1, 0.8);
      else
        BankHelperAddItemDescription(itemId);
        local count = 0;
        if (not BankHelperDatas["players"][PlayerName]["items"][itemId]) then
          BankHelperDatas["players"][PlayerName]["items"][itemId] = 0;
        else
          count = BankHelperDatas["players"][PlayerName]["items"][itemId];
        end
        count = count + bhfmMailBoxItem.itemCount;
        BankHelperDatas["players"][PlayerName]["items"][itemId] = count;
      end
      -- Add the contribution:
      BankHelperAddMouvement(bhfmMailBoxItem);
    else
      BHPrint(string.format("BankHelperOnUpdate(): %s Something wrong", bhfmAction), 0.8, 0.1, 0.1);
    end

    bhfmMailBoxItem = nil;
    bhfmAction = "NONE";
    BankHelperFetchMails("DO_NEXT_MAIL");
  elseif (bhfmWaitDelay >= MAIL_ACTION_TIMEOUT_DELAY) then
    if (bhfmAction == "WAIT_READ_MESSAGE_TEXT") then
      BHPrint("Delay timeout WAIT_READ_MESSAGE_TEXT", 0.2, 0.8, 0.3);
      BankHelperFetchMails("MAIL_INBOX_UPDATE");
    end
  end
end

-- ================================================
-- Record send mail
-- ================================================
local BH_BlizzSetSendMailMoney = SetSendMailMoney;
local function BankHeperSetSendMailMoney(copper)
  local ret = BH_BlizzSetSendMailMoney(copper);
  if (ret == 1) then
    BankHelperSendMailInfos.money = -copper;
    LogDebug(string.format("BankHeperSetSendMailMoney(%d)", copper));
  end
  return ret;
end
SetSendMailMoney = BankHeperSetSendMailMoney;

local BH_BlizzSetSendMailCOD = SetSendMailCOD;
local function BankHelperSetSendMailCOD(copper)
  BH_BlizzSetSendMailCOD(copper);
  BankHelperSendMailInfos.money = copper;
  BankHelperSendMailInfos.cod = true;
  LogDebug(string.format("BankHelperSetSendMailCOD(%d)", copper));
end
SetSendMailCOD = BankHelperSetSendMailCOD;

local BH_BlizzPickupContainerItem = PickupContainerItem;
local function BankHeperPickupContainerItem(bag, slot)
  BH_BlizzPickupContainerItem(bag, slot);
  if (MailBoxStatus == MAILBOX_OPEN) then
    local itemLink = GetContainerItemLink(bag, slot);
    if (itemLink) then
      BankHelperSendMailInfos.itemLink = itemLink;
      BankHelperSendMailInfos.itemId = GetItemID(itemLink);
      LogDebug(string.format("BankHeperPickupContainerItem(): %s", itemLink));
    end
  end
end
PickupContainerItem = BankHeperPickupContainerItem;

local BH_BlizzClickSendMailItemButton = ClickSendMailItemButton;
local function BankHelperClickSendMailItemButton()
  BH_BlizzClickSendMailItemButton();
  if (MailBoxStatus == MAILBOX_OPEN) then
    local name, texture, count, quality = GetSendMailItem();
    BankHelperSendMailInfos.itemName = name;
    BankHelperSendMailInfos.itemTexture = texture;
    BankHelperSendMailInfos.itemCount = count;
    BankHelperSendMailInfos.itemQuality = quality;
    if (name) then
      LogDebug(string.format("BankHelperClickSendMailItemButton: [%s]x%d", name, count));
    else
      LogDebug("BankHelperClickSendMailItemButton: no item attached");
    end
  end
end
ClickSendMailItemButton = BankHelperClickSendMailItemButton;

local BH_BlizzSendMail = SendMail;
local function BankHelperSendMail(recipient, subject, body)
  BH_BlizzSendMail(recipient, subject, body);
  LogDebug(string.format("BankHelperSendMail(%s, %s, %s)", recipient, subject, body));
  if (MailBoxStatus == MAILBOX_OPEN) then
    BankHelperSendMailInfos.to = recipient;
    BankHelperSendMailInfos.subject = subject;
    BankHelperSendMailInfos.bodyText = body;
    BankHelperSendMailInfos.sender = UnitName("player");
    BankHelperSendMailInfos.sendDate = time();
  end
end
SendMail = BankHelperSendMail;

function BankHelperOnSendMailEvent(mailSent)
  if (mailSent == false) then
    BankHelperSendMailInfos = {};
    return;
  end

  if (not BankHelperSendMailInfos.cod) then
    BankHelperSendMailInfos.cod = false;
  end

  if (not BankHelperSendMailInfos.money) then
    BankHelperSendMailInfos.money = 0;
  end

  if (not BankHelperSendMailInfos.itemCount) then
    BankHelperSendMailInfos.itemCount = 0;
  end

  if (BankHelperSendMailInfos.itemName) then
    local itemId = BankHelperSendMailInfos.itemId;
    local itemName = BankHelperSendMailInfos.itemName;
    local itemCount = BankHelperSendMailInfos.itemCount;

    if (not BankHelperDatas["players"][PlayerName]["items"][itemId]) then
      BankHelperDatas["players"][PlayerName]["items"][itemId] = 0;
      BHPrint(string.format("L'item %s n'était pas présent dans les sacs, pensez à ouvrir la banque!", itemName), 1.0, 1.0, 0.0);
    end

    itemCount = BankHelperDatas["players"][PlayerName]["items"][itemId] - itemCount;
    if (itemCount < 0) then
      BHPrint(string.format("L'item %s n'était pas en quantité suffisante dans les sacs, pensez à ouvrir la banque!", itemName), 1.0, 1.0, 0.0);
      itemCount = 0;
    end
    BankHelperDatas["players"][PlayerName]["items"][itemId] = itemCount;
    BankHelperAddItemDescription(itemId);
  end

  if (BankHelperSendMailInfos.money > 0 and not BankHelperSendMailInfos.cod) then
    BankHelperDatas["players"][PlayerName]["money"] = BankHelperDatas["players"][PlayerName]["money"] - BankHelperSendMailInfos.money;
  end

  BankHelperAddMouvement(BankHelperSendMailInfos);
  BankHelperSendMailInfos = {};
end
