fx_version 'cerulean'
game 'gta5'

author 'BETCHES'
description 'QBCore Car Radio with YouTube And Mp3 Links Support'
version '2.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    '@xsound/client/cl_xsound.lua',
    'client/client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/logo.png'
}

dependencies {
    'xsound'
}

lua54 'yes'
