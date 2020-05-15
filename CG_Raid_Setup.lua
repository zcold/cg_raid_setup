local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")

local CG_Raid_Setup = LibStub("AceAddon-3.0"):NewAddon("CG_Raid_Setup", "AceConsole-3.0", "AceEvent-3.0")
local app_name = "CG_Raid_Setup"
local app_display_name = "CG Raid Setup"

-- return lower case name without realm
local function get_name(name_realm)
  return string.match(name_realm:lower(), "([^%s]+)-")
end

local function get_display(name)
  localizedClass, englishClass, classIndex = UnitClass(name);
  _, _, _, color = GetClassColor(englishClass)
  return "|c" .. color .. " "..name.."|r"
end

function CG_Raid_Setup:UpdateCDSetup(setup, name, group, slot)
  group = tostring(group)
  slot = slot or -1
  slot = tostring(slot)
  -- clear one group
  if name == nil then
    if slot == "-1" then
      CG_DATA[setup][group]= {}
      return
    end
  end

  -- clear one slot
  if name == nil then
    CG_DATA[setup][group][slot] = nil
    for n, gs in pairs(CG_DATA[setup].name_group) do
      if (gs.group == group) and (gs.slot == slot) then
        CG_DATA[setup].name_group[n] = nil
        break
      end
    end
    return
  end

  name = name:lower()

  -- clear current setup
  for gi=1,8 do
    for si=1,5 do
      if CG_DATA[setup][tostring(gi)][tostring(si)] == name then
        CG_DATA[setup][tostring(gi)][tostring(si)] = nil
        CG_DATA[setup].name_group[name] = nil
      end
    end
  end

  -- put player to a group, dont care slot
  if slot == "-1" then
    for si=1,5 do
      if CG_DATA[setup][group][tostring(si)] == nil then
        CG_DATA[setup][group][tostring(si)] = name
        CG_DATA[setup].name_group[name] = {group = group, slot = tostring(si)}
        return
      end
    end
  end

  -- put playr to group.slot
  if CG_DATA[setup][group][slot] ~= nil then
    self:Print("WARNING: Group "..group.." slot "..slot.." was occupied by "..CG_DATA[setup][group][slot])
  end
  CG_DATA[setup][group][slot] = name
  CG_DATA[setup].name_group[name] = {group = group, slot = slot}
end

-- update raid setup option
function CG_Raid_Setup:UpdateGroupSetup(name)
  local order_index = 0
  self.options.args[name] = {name = name, type = "group", args = {}}
  if CG_DATA[name].enabled == true then
    -- indict current active setup
    self.options.args[name].name = "> "..name.." <"
  end
  -- Enable this setup
  order_index = order_index + 1
  self.options.args[name].args.setup_enable = {
    order = order_index,
    name = "Enabled",
    type = "toggle",
    width = "full",
    set = function(info, enabled)
      CG_DATA[name].enabled = enabled
      if enabled then
        self.options.args[name].name = "> "..name.."<"
      else
        self.options.args[name].name = name
      end
      for setup, _ in pairs(CG_DATA) do
        if setup ~= name then
          CG_DATA[name].enabled = false
        end
      end
    end,
    get = function(info) return CG_DATA[name].enabled end,
  }

  -- Add special memeber to group, choose group
  order_index = order_index + 1
  self.options.args[name].args.member_group = {
    order = order_index,
    name = "Member group",
    desc = "Member group",
    type = "select",
    values = {1, 2, 3, 4, 5, 6, 7, 8},
    set = function(info, g) CG_DATA[name].current_g = g end,
    get = function(info)
      CG_DATA[name].current_g = CG_DATA[name].current_g or 8
      return CG_DATA[name].current_g
    end,
  }

  -- Add special memeber to group, input player name
  order_index = order_index + 1
  self.options.args[name].args.special_member = {
    -- Offline guild member can be added
    -- All online player can be added
    order = order_index,
    name = "Special member",
    desc = "Special memebr to invite, e.g. in other guild or in other rank.",
    type = "input",
    set = function(info, m)
      local display = get_display(m)
      CG_DATA[name].current_member = m:lower()
      for player_name, rc in pairs(self.guild_member_info) do
        if player_name == m:lower() then
          self:Print(m .. " is in guild.")
          self:UpdateCDSetup(name, m:lower(), CG_DATA[name].current_g)
          CG_DATA[name].special_member = CG_DATA[name].special_member or {}
          if self.guild_member_info[m:lower()] ~= nil then
            CG_DATA[name].special_member[m:lower()] = self.guild_member_info[m:lower()].display
          else
            CG_DATA[name].special_member[m:lower()] = get_display(m:lower())
          end
          self:UpdateGroupSetup(name)
          return
        end
      end
      if UnitIsPlayer(m) then
        self:Print("Added "..m.." to group "..CG_DATA[name].current_g)
        self:UpdateCDSetup(name, m, CG_DATA[name].current_g)
      end
      self:UpdateGroupSetup(name)
    end,
    get = function(info) return CG_DATA[name].current_member end,
  }
  order_index = order_index + 1
  self.options.args[name].args.member_rank = {
  -- Raid member guild rank
    order = order_index,
    name = "Member rank",
    desc = "Member rank: " .. (self.guild_ranks[CG_DATA[name].member_rank] or ""),
    type = "select",
    values = self.guild_ranks,
    get = function(info) return CG_DATA[name].member_rank end,
    disabled = true
  }
  order_index = order_index + 1
  self.options.args[name].args.min_officer_rank = {
  -- Officer guild rank
    order = order_index,
    name = "Min officer rank",
    desc = "Min officer rank: " .. (self.guild_ranks[CG_DATA[name].min_officer_rank] or ""),
    type = "select",
    values = self.guild_ranks,
    get = function(info) return CG_DATA[name].min_officer_rank end,
    disabled = true
  }
  order_index = order_index + 1
  self.options.args[name].args.invite_prefix = {
  -- Auto invite prefix
    order = order_index,
    name = "Invite prefix",
    type = "input",
    set = function(info, invite_prefix)
        CG_DATA[name].invite_prefix = invite_prefix
        CG_Raid_Setup:UpdateInvitePrefixDesc()
      end,
    get = function(info) return CG_DATA[name].invite_prefix end,
  }
  order_index = order_index + 1
  self.options.args[name].args.invite_this_setup = {
    order = order_index,
    name = "Invite this setup",
    type = "execute",
    func = function(info, ...)
      ConvertToRaid()
      for g=1,8 do
        for s=1,5 do
          local p = CG_DATA[name][tostring(g)][tostring(s)]
          if p ~= nil then
            if p ~= self.my_name then
              InviteUnit(p)
            end
          end
        end
      end
    end,
    width = 1,
    confirm = function() return "Invite all? Party will be converted to raid." end,
  }
  order_index = order_index + 1
  self.options.args[name].args.regroup_setup = {
  -- TODO: arrange this raid setup
    order = order_index,
    name = "Rearrange setup",
    desc = "Rearrange this setup",
    type = "execute",
    func = function(info, ...) self:RearrangeGroup(name) end,
  }
  order_index = order_index + 1
  self.options.args[name].args.remove_this_setup = {
  -- Remove raid setup
    order = order_index,
    name = "Remove this setup",
    type = "execute",
    func = function(info, ...) self.options.args[name] = nil; CG_DATA[name] = nil end,
    width = 1,
    confirm = function() return "Remove setup group ".. name .." ?" end,
  }
  order_index = order_index + 1
  self.options.args[name].args.hline = {
  -- hline
    order = order_index,
    name = "",
    type = "header",
    width = "full",
  }
  self:FilterPlayers(name)
  order_index = order_index + 1
  for i=1,8 do
    local base_order = 10*math.floor((i-1)/2)
    self.options.args[name].args[tostring(i)] = {
    -- One raid group
      order = order_index + i + base_order,
      name = "GROUP " .. i,
      type = "description",
      width = 1
    }
    for j=1,5 do
      self.options.args[name].args[""..i.."_"..j] = {
      -- One group slot
        order = order_index + i + base_order + (j*2),
        name = "",
        type = "select",
        width = 1,
        values = self.guild_members[name],
        set = function(info, index_in_member)
          local g, p = string.gmatch(info[2], "(%d)_(%d)")()
          local player_name = string.match(self.guild_members[name][index_in_member], " ([^%s]+)|")
          self:UpdateCDSetup(name, player_name, g, p)
          CG_Raid_Setup:UpdateGroupSetup(name)
        end,
        get = function(info)
          local g, p = string.gmatch(info[2], "(%d)_(%d)")()
          local player_name = CG_DATA[name][g][p]
          if player_name == nil then return -1 end
          for i, display in ipairs(self.guild_members[name]) do
            if string.match(display, " ([^%s]+)|") == player_name then return i end
          end
          return -1
        end,
      }
    end
  end
  self.options.args[name].args["more_options"] = {
    order = 200,
    name = "More",
    type = "group",
    args = {}
  }
  self.options.args[name].args["more_options"].args.rename_setup = {
    order = 300,
    name = "Rename Setup",
    type = "input",
    set = function(info, new_setup)
      if CG_DATA[new_setup] ~= nil then
        self:Print(new_setup .. " already exists.")
        return
      end
      CG_DATA[new_setup] = CG_DATA[info[1]]
      CG_DATA[info[1]] = nil
      ReloadUI()
    end,
    confirm = function () return "Need reload UI to rename." end,
  }
  self.options.args[name].args["more_options"].args.hline = {
    order = 301,
    name = "",
    type = "header",
    width = "full",
  }
  self.options.args[name].args["more_options"].args.export_str = {
    order = 400,
    name = "Export string",
    desc = "Export this setup.",
    type = "input",
    multiline = 16,
    width = "full",
    get = function(info)
      local result = ""
      -- [setup name]:[member_rank].[min_officer_rank],
      result = result..name..":"
      result = result..CG_DATA[name].member_rank.."."..CG_DATA[name].min_officer_rank ..","
      -- [invite_prefix]:[current_g].[special_member splited by |],
      result = result..CG_DATA[name].invite_prefix..":"
      result = result..CG_DATA[name].current_g.."."
      local members = ""
      local member_count = 0
      for n, d in pairs(CG_DATA[name].special_member) do
        member_count = member_count + 1
        members = members..n..":"
        members = members..d.."."
        members = members.."0,"
      end
      result = result..member_count..","
      result = result..members
      --[name]:[group].[slot],
      for name, gs in pairs(CG_DATA[name].name_group) do
        result = result..name..":"..gs.group.."."..gs.slot..","
      end
      return result:gsub("|", "="):gsub(" ", "-")
    end,
  }
end

function CG_Raid_Setup:FilterPlayers(setup)
  self.guild_members[setup] = {""}
  CG_DATA[setup].min_officer_rank = CG_DATA[setup].min_officer_rank or 0
  CG_DATA[setup].member_rank = CG_DATA[setup].member_rank or 0
  for player_name, rc in pairs(self.guild_member_info) do
    if (rc.rank == CG_DATA[setup].member_rank) then
      self.guild_members[setup][#self.guild_members[setup]+1] = rc.display
    end
    if (rc.rank <= CG_DATA[setup].min_officer_rank) then
      self.guild_members[setup][#self.guild_members[setup]+1] = rc.display
    end
  end
  table.sort(self.guild_members[setup])
  CG_DATA[setup].special_member = CG_DATA[setup].special_member or {}
  for _, display in pairs(CG_DATA[setup].special_member) do
    self.guild_members[setup][#self.guild_members[setup]+1] = display
  end
end

function CG_Raid_Setup:UpdateInvitePrefixDesc()
  for setup, args in pairs(CG_DATA) do
    local prefix = args.invite_prefix or ""
    local invite_prefix_desc = "Player whisper " .. prefix
    invite_prefix_desc = invite_prefix_desc .. " 7 will be invited and put in group 7."
    invite_prefix_desc = invite_prefix_desc .. " Play whisper "
    invite_prefix_desc = invite_prefix_desc .. prefix .. " will be invite only."
    self.options.args[setup].args["invite_prefix"].desc = invite_prefix_desc
  end
end

function CG_Raid_Setup:GetGuildInfo()
  self.guild_member_info = {}
  self.guild_members = {}
  self.guild_ranks = {}
  self.higher_guild_ranks = {}
  numTotalMembers, _, _ = GetNumGuildMembers();
  if numTotalMembers == 0 then
    self.guild_member_info = CG_SELF.guild_member_info
    self.guild_ranks = CG_SELF.guild_ranks
    self.higher_guild_ranks = CG_SELF.higher_guild_ranks
    return
  end
  for i=1, numTotalMembers, 1 do
    name, rank, rankIndex, level, class, zone, note,
    officernote, online, status, classFileName,
    achievementPoints, achievementRank, isMobile, isSoREligible, standingID = GetGuildRosterInfo(i)
    if not name then
      break
    end
    name = get_name(name)
    _, _, _, color = GetClassColor(string.upper(class))
    self.guild_member_info[name:lower()] = {
      rank = tonumber(rankIndex),
      display = "|c" .. color .. " "..name.."|r"
    }
    self.guild_ranks[rankIndex] = rank
    self.higher_guild_ranks[rankIndex] = rank
  end
  CG_SELF.guild_member_info = self.guild_member_info
  CG_SELF.guild_ranks = self.guild_ranks
  CG_SELF.higher_guild_ranks = self.higher_guild_ranks
end

-- construct top level options
function CG_Raid_Setup:NewOptions()
  self.options = {name = app_display_name, handler = CG_Raid_Setup, type = "group", args = {}}
  local index = 0
  self.options.args.member_rank = {
    order = index,
    name = "Raid member rank",
    desc = "All players in this rank can be selected.",
    type = "select",
    values = self.guild_ranks,
    get = function(info)
      return self.member_rank or 0
    end,
    set = function(info, r)
      self.member_rank = r
      self.min_officer_rank = math.min(r, self.min_officer_rank or r)
    end,
  }
  index = index + 1
  self.options.args.min_officer_rank = {
    order = index,
    name = "Minimum officer rank",
    desc = "All players in at least this rank can be selected. Should be less than raid member rank.",
    type = "select",
    values = self.guild_ranks,
    get = function(info) return self.min_officer_rank or 0 end,
    set = function(info, r) self.min_officer_rank = math.min(r, self.member_rank or r) end,
  }
  index = index + 1
  self.options.args.add_setup = {
    order = index,
    name = "Add setup",
    desc = "Add new raid setup",
    type = "input",
    confirm = function(info, name) return "Add setup " .. name .. "?" end,
    set = function(info, name)
      if CG_DATA[name] ~= nil then
        self:Print("Setup " .. name .. " already exists.")
        return
      end
      CG_DATA[name] = {
        member_rank = self.member_rank or 0,
        min_officer_rank = self.min_officer_rank or 0,
        enabled = false,
        invite_prefix = name,
        name_group = {},
        name = name,
      }
      for gi=1,8 do
        CG_DATA[name][tostring(gi)] = {}
      end
      CG_Raid_Setup:UpdateGroupSetup(name)
      self:Print("Setup " .. name .. " added.")
    end,
  }
  index = index + 1
  self.options.args.reset_all = {
    order = index,
    name = "  To reset all data, type /cgc reset",
    type = "description",
    width = 1
  }

  index = 0
  self.import_options = {name = app_display_name.." Import", handler = CG_Raid_Setup, type = "group", args = {}}
  self.import_options.args.import_current = {
    order = index,
    name = "Import current raid setup",
    desc = "Save current raid setup",
    type = "input",
    set = function (info)
      if IsInRaid() then
        self:UpdateRaidInfo()
        self:Print("TODO: import current raid setup")
      end
    end,
  }
  index = index + 1
  self.import_options.args.hline = {
    order = index,
    name = "",
    type = "header",
    width = "full",
  }
  index = index + 1
  self.import_options.args.import_string = {
    order = index,
    name = "Import from string",
    desc = "Import string.",
    type = "input",
    multiline = 16,
    width = "full",
    set = function(info, s)
      local state = "name"
      local current_index = 0
      local setup = ""
      for n, g, s in string.gmatch(s, "([^%s:.,]+):([^%s:.,]+).([^%s:.,]+),") do
        if state == "name" then
          setup = n
          CG_DATA[setup] = {}
          CG_DATA[setup].enable = false
          CG_DATA[setup].name_group = {}
          CG_DATA[setup].member_rank = tonumber(g)
          CG_DATA[setup].min_officer_rank = tonumber(s)
          CG_DATA[setup].current_g = 8
          CG_DATA[setup].special_member = {}
          for i=1,8 do
            CG_DATA[setup][tostring(i)] = {}
          end
          state = "invite_prefix"
        elseif state == "invite_prefix" then
          CG_DATA[setup].invite_prefix = n
          CG_DATA[setup].current_g = tonumber(g)
          state = tonumber(s)
        elseif state == "name_group" then
          CG_DATA[setup].name_group[n] = {group=g, slot=s}
          CG_DATA[setup][g][s] = n
        else
          if current_index < state then
            current_index = current_index + 1
            CG_DATA[setup].special_member[n] = g:gsub("-", " "):gsub("=", "|")
          else
            CG_DATA[setup].name_group[n] = {group=g, slot=s}
            CG_DATA[setup][g][s] = n
            state = "name_group"
          end
        end
      end
      self:FilterPlayers(setup)
      self:UpdateGroupSetup(setup)
    end
  }
end

function CG_Raid_Setup:OnInitialize()
  if CG_SELF == {} then
    self:Print("need reload to make this work.")
        --ReloadUI()
  end
  CG_DATA = CG_DATA or {}
  CG_SELF = CG_SELF or {}
  self.my_name, _= UnitName("player")
  self.my_name = self.my_name:lower()
  self:GetGuildInfo()
  self:NewOptions()
  for name, _ in pairs(CG_DATA) do
    self:UpdateGroupSetup(name)
  end
  self:UpdateInvitePrefixDesc()
  AceConfig:RegisterOptionsTable(self.options.name, self.options, {"cgc"})
  AceConfig:RegisterOptionsTable(self.import_options.name, self.import_options, {"cgc_import"})
  self.optionsFrame = AceConfigDialog:AddToBlizOptions(self.options.name, app_display_name)
  self.importFrame = AceConfigDialog:AddToBlizOptions(self.import_options.name, self.import_options.name)
  self:RegisterEvent("CHAT_MSG_WHISPER")
  self:RegisterEvent("CHAT_MSG_BN_WHISPER")
  self:RegisterChatCommand("cgc", "ChatCommand")
  self:Print("Initialized type /cgc for options")
end

function CG_Raid_Setup:ChatCommand(input)
  if not input or input:trim() == "" then
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    return
  end

  if input == "reset" then
    CG_DATA = nil
    CG_SELF = nil
    ReloadUI()
    self:Print("CG Raid Setup has been reset.")
    return
  end

  LibStub("AceConfigCmd-3.0"):HandleCommand("cgc", app_name, input)
end

-- invite player
-- TODO: put the player to the wanted group
function CG_Raid_Setup:InviteGroup(msg, player_name)
  for name, args in pairs(CG_DATA) do
    if args.enabled then
      msg = msg:gsub("^%s+", "")
      print(msg, player_name)
      if string.match(msg, args.invite_prefix) then
        if self.my_name ~= player_name then
          if GetNumGroupMembers() == 5 then ConvertToRaid() end
          InviteUnit(player_name)
        end
        return
      end
      if string.match(msg, args.invite_prefix.." ") then
        print(msg, player_name)
        local group = tonumber(string.match(msg, "%d") or "-1")
        if self.my_name ~= player_name then
          if GetNumGroupMembers() == 5 then
            ConvertToRaid()
          end
          InviteUnit(player_name)
        end
      end
    end
  end
end

-- invite from whisper
function CG_Raid_Setup:CHAT_MSG_WHISPER(event, ...)
  self:InviteGroup(
    select(1, ...),
    get_name(select(2, ...)))
end

-- invite from BN whisper
function CG_Raid_Setup:CHAT_MSG_BN_WHISPER(event, ...)
  local msg = select(1, ...)
  local presence_id = select(13, ...)
  if presence_id and BNIsFriend(presence_id) then
    local index = BNGetFriendIndex(presence_id);
    if index then
      local presenceID, presenceName, battleTag, isBattleTagPresence, toonName, toonID = BNGetFriendInfo(index);
      return self:InviteGroup(msg, toonName)
    end
  end
end

function CG_Raid_Setup:UpdateRaidInfo()
  self.current_players_in_group = {}
  self.current_raid_group = {}
  for i=1,8 do self.current_players_in_group[i] = 0 end
  for i=1,GetNumGroupMembers() do
    name, _, group = GetRaidRosterInfo(i)
    name = name:lower()
    group = tonumber(group)
    self.current_players_in_group[group] = self.current_players_in_group[group] + 1
    self.current_raid_group[name] = { index = i, group = group }
  end
end

function CG_Raid_Setup:PutInGroup(setup, name, ig)
  local grp_ok = false
  if CG_DATA[setup].name_group[name] == nil then
    self:Print(name.." no preferred group")
  else
    local want = tonumber(CG_DATA[setup].name_group[name].group)
    local index = ig.index
    local now = ig.group
    if now ~= want then
      if self.current_players_in_group[want] < 5 then
      -- move to empty slot
        SetRaidSubgroup(index, want)
        grp_ok = true
      else
      -- swap with another player
        for current_name, current_ig in pairs(self.current_raid_group) do
          if current_name ~= name then
            if current_ig.group == want and CG_DATA[setup].name_group[current_name] ~= want then
              -- swap to a player not in this group
              SwapRaidSubgroup(ig.index, current_ig.index)
              grp_ok = true
              break
            end
          end
        end
      end
    else
      grp_ok = true
    end
    if not grp_ok then
      self:Print("分组不成功 ".. want .." 满了.")
    end
  end
end

function CG_Raid_Setup:RearrangeGroup(setup)
  if not IsInRaid() then
    return
  end
  local grp_ok = false
  local name_group = {}
  self:UpdateRaidInfo()
  for g=1,8 do
    for s=1,5 do
      local n = CG_DATA[setup][tostring(g)][tostring(s)]
      if n ~= nil then
        if self.current_raid_group[n] ~= nul then
          self:PutInGroup(setup, n, self.current_raid_group[n])
        end
      end
    end
  end
end
