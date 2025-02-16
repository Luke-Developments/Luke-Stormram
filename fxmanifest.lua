game 'gta5'

author 'Luke Developments'
description 'Door Breach script for ox_doorlock made by Luke Developments'
version '0.5'

shared_scripts {
  '@ox_lib/init.lua'
}

client_script 'client.lua'

server_script 'server.lua'

dependencies {
  'ox_lib',
  'ox_target',
  'ox_inventory',
  'ox_doorlock',
}

lua54 'yes'
