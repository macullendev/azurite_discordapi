fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'azurite_discord'
author 'Azurite Studios'
description 'Discord API integration for Azurite resources'
version '1.0.0'

client_script 'client/client.lua'

server_scripts {
  'config.lua',
  'server/server.lua'
}
