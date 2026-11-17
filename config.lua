Config = {}

-- Better in server.cfg, where nobody can see it: set azurite_discord_token "your token"
Config.Token = ''

-- Your Discord server ID (right click the server icon > Copy Server ID)
Config.Guild = ''

-- Minutes a player's picture, name and roles are kept before asking Discord again
Config.CacheMinutes = 5

-- Picture size in pixels: 64, 128, 256 or 512
Config.Size = 128

-- Animated pictures play as GIFs
Config.Animated = true

-- Use the picture a player set just for your Discord server, when they have one
Config.ServerAvatars = true

-- Players without Discord linked get the default Discord picture instead of nothing
Config.Fallback = true
