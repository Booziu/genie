-- written by lance!
json = require('json')
util.require_natives("1676318796")

if json == nil then 
    util.toast("You must have JSON installed to use this script. Install it on the repository.")
    util.stop_script()
end
local endpoint = "https://api.openai.com/v1/completions"
local store_dir = filesystem.store_dir() .. '\\genie\\'
local api_key_dir = store_dir .. 'api_key.txt'
local cooldowns = {}

if not filesystem.is_dir(store_dir) then
    filesystem.mkdirs(store_dir)
end

if not filesystem.exists(api_key_dir) then 
    local file = io.open(api_key_dir,'w')
    file:write("None")
    file:close()
end

local f = io.open(api_key_dir,'r')
local api_key = f:read('a')
f:close()

if api_key == "None" then 
    util.toast("No OpenAI API key is set. You must set one to use this script.")
    util.toast("Do NOT share your API key with anyone. DO NOT share api_key.txt, or any contents of your Lua Scripts/store/openai folder")
    menu.action(menu.my_root(), "Enter OpenAI API key", {"setopenaikey"}, "DO NOT SHARE THIS.\nClick and paste in your API key", function(on_click)
        menu.show_command_box("setopenaikey ")
    end, function(on_command)
        if not string.startswith(on_command, 'sk-') then 
            util.toast("Invalid API key.")
        else
            local file = io.open(api_key_dir,'w')
            file:write(on_command)
            file:close()
            util.toast("OpenAI API key written to file. Restarting script.")
            util.restart_script()
        end
    end)
end

-- just so i dont need a huge else block lol
while api_key == "None" do 
    util.yield()
end

menu.divider(menu.my_root(), "AI settings")

local cooldown = 5
menu.slider(menu.my_root(), "Cooldown", {"openaicooldown"}, "In seconds. This prevents users from spamming the AI (and running your costs up). Messages sent during this cooldown are ignored, and your own messages have no cooldown.", 1, 120, 5, 1, function(sec)
    cooldown = sec
end)

local max_tokens = 150
menu.slider(menu.my_root(), "Max tokens", {"openaimaxtokens"}, "Essentially, this is the max response length. Tokens are parts of words.", 1, 500, 150, 1, function(max)
    max_tokens = max
end)

local temperature = 0.8
menu.slider_float(menu.my_root(), "Temperature", {"openaitemperature"}, "From OpenAI docs:\nHigher values like 0.8 will make the output more random, while lower values like 0.2 will make it more focused and deterministic.", 0, 200, 80, 1, function(temp)
    temperature = temp / 100
end)

local system_message = "You are a helpful assistant."
menu.text_input(menu.my_root(), "Behavior", {"chataibehavior"}, "Tell the AI what it is, and what it does. This will affect how it responds and is also called a \"system message\".", function(msg)
    system_message = msg
end, system_message)

local ai_prefix = '!'
menu.text_input(menu.my_root(), "Prefix", {"chataiprefix"}, "Chat messages must begin with this prefix or they will not be sent to the AI.", function(prefix)
    ai_prefix = prefix
end, ai_prefix)

menu.divider(menu.my_root(), "Permissions")

local allow_friends = false
menu.toggle(menu.my_root(), "Allow friends", {"openaifriends"}, "Allow your friends to use the AI. If you have any.", function(on)
    allow_friends = on
end)

local allow_strangers = false
menu.toggle(menu.my_root(), "Allow strangers", {"openaistrangers"}, "Allow absolute strangers to use the AI. Probably not advised.", function(on)
    allow_strangers = on
end)

local allow_me = true
menu.toggle(menu.my_root(), "Allow me", {"openaime"}, "Allows the AI to respond to your messages.", function(on)
    allow_me = on
end, true)



menu.divider(menu.my_root(), "Caution")

menu.action(menu.my_root(), "Reset OpenAI API key", {"resetopenaikey"}, "DO NOT SHARE THIS.\nClick and paste in your API key", function(on_click)
    menu.show_command_box("setopenaikey ")
end, function(on_command)
    if not string.startswith(on_command, 'sk-') then 
        util.toast("Invalid API key.")
    else
        local file = io.open(api_key_dir,'w')
        file:write(on_command)
        file:close()
        util.toast("API key written to file. Restarting script.")
        util.restart_script()
    end
end)

menu.divider(menu.my_root(), "Misc")
async_http.init("gist.githubusercontent.com", "/stakonum/d4e2f55f6f72d2cf7ec490b748099091/raw", function(result)
    menu.hyperlink(menu.my_root(), "Join Discord", result, "")
end)
async_http.dispatch()


local temperature = 0.8
local function ask_ai(prompt)
    async_http.init('api.openai.com', '/v1/chat/completions', function(data)
        if data['error'] ~= nil then 
            util.toast("OpenAI error: " .. data['error']['message'])
        end
        local response = json.decode(data)
        chat.send_message(response['choices'][1]['message']['content'], false, true, true)
    end, function()
        util.toast('!!! OpenAI connection failed.')
    end)
    async_http.add_header("Authorization", "Bearer " .. api_key)
    local messages = {
        {
            role = 'system',
            content = system_message
        },
        {
            role = 'user',
            content = prompt
        }
    }
    local payload = {
        model = 'gpt-3.5-turbo',
        max_tokens = max_tokens,
        temperature = temperature,
        messages = messages
    }
    async_http.set_post("application/json", json.encode(payload))
    async_http.dispatch()
end

local handle_ptr = memory.alloc(13*8)
local function is_friend(pid)
    NETWORK.NETWORK_HANDLE_FROM_PLAYER(pid, handle_ptr, 13)
    return NETWORK.NETWORK_IS_FRIEND(handle_ptr)
end

chat.on_message(function(sender, reserved, text, team_chat, networked, is_auto)
    -- ensure the chat is not openai itself or some automated mechanism
    if not string.startswith(text, ai_prefix) then 
        return 
    end
    if not is_auto then 
        -- check permission
        if (is_friend(sender) and allow_friends) or (sender == players.user() and allow_me) or allow_strangers then
            -- is user on cooldown
            if cooldowns[sender] ~= nil and sender ~= players.user() then 
                return 
            end
            if sender == players.user() and not allow_me then 
                return 
            end
            ask_ai(text)
            -- apply cooldown
            cooldowns[sender] = true 
            util.yield(cooldown * 1000)
            cooldowns[sender] = nil
        end
    end
end)