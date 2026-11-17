# azurite_discord

Discord profile pictures, names and roles for FiveM. Free, and used by every Azurite resource to show each player's own picture in the menus.

## Install

1. Create a bot at https://discord.com/developers/applications, then copy its token under **Bot > Reset Token**.
2. Invite the bot to your Discord server. It needs no permissions.
3. Put `azurite_discord` in your resources folder and add this to `server.cfg`, before your Azurite resources:

```cfg
set azurite_discord_token "your bot token"
ensure azurite_discord
```

4. Put your Discord server ID in `config.lua` (`Config.Guild`).

Players who are not in your Discord server still get their own picture. Players without Discord linked get the default Discord picture.

## Exports (server)

```lua
exports.azurite_discord:GetAvatar(source)
exports.azurite_discord:GetName(source)
exports.azurite_discord:GetRoles(source)
exports.azurite_discord:HasRole(source, 'role id or name')
exports.azurite_discord:HasRole(source, { 'role id', 'another' })
exports.azurite_discord:GetProfile(source)
exports.azurite_discord:GetDiscordId(source)
exports.azurite_discord:Refresh(source)
```

Results are kept for `Config.CacheMinutes`. Call `Refresh` after a player changes their picture or roles to read them again straight away.
