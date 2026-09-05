#--------------------------------------------------------------------------
# * Add "Ruby" directory to load path and import archipelago_rb
#--------------------------------------------------------------------------
    ruby_directory = File.join(Dir.pwd, "Ruby")
    is_mac = defined?(System) && System.respond_to?(:is_mac?) && System.is_mac?
    $:.push(ruby_directory) unless is_mac
    if File.directory?(ruby_directory)
        Dir.glob(File.join(ruby_directory, '**', '*')).each do |path|
            $:.push(path) if File.directory?(path)
        end
    end
    require 'archipelago_rb'
    require 'io/console'
    require 'json'

#==============================================================================
#==============================================================================
    class Hash
        unless method_defined?(:index)
            def index(value)
                key(value)
            end
        end
    end

#==============================================================================
# ** CONSOLE SPAM FILTER
#==============================================================================
    SPAM_FILTER_PATTERN = "BUG: Bitmap drawText with outline and translucent text is broken"

    class << $stdout
        alias bs2_filter_puts puts
        def puts(*args)
            return if args.length == 1 && args[0].to_s.include?(SPAM_FILTER_PATTERN)
            bs2_filter_puts(*args)
        end

        alias bs2_filter_write write
        def write(*args)
            return 0 if args.length == 1 && args[0].to_s.include?(SPAM_FILTER_PATTERN)
            bs2_filter_write(*args)
        end
    end

#==============================================================================
# ** AP ACTIVITY LOG FILE
#==============================================================================
    AP_ACTIVITY_LOG_FILE = "archipelago_activity.log"

#==============================================================================
# ** CONFIGURATION
#==============================================================================
    $archipelago_gamename = "black_souls2"
    $archipelago_items_handling = Archipelago::ItemsHandlingFlags::REMOTE_ALL
    $load_autoconnect = true
    $receive_items_outside_map = false

    progressive_methods = {}
    receiveditem_methods = {}

    $name_based_receiveditem_methods = {
        'Mist Crash Chamber' => '$game_switches[1101] = true',
        'Mist Fuming Forest' => '$game_switches[1102] = true',
        'Mist Spore Forest' => '$game_switches[1103] = true',
        'Mist Dodgson Bridge' => '$game_switches[1104] = true',
        'Mist Liddell Cemetary' => '$game_switches[1105] = true',
        'Mist Pond of Bloody Tears' => '$game_switches[1106] = true',
        'Mist Mental Ward' => '$game_switches[1107] = true',
        'Mist Mushroom Village' => '$game_switches[1108] = true',
        'Mist Library Dream' => '$game_switches[1109] = true',
        'Mist Upper Lutwidge Town' => '$game_switches[1110] = true',
        'Mist Slaughterhouse' => '$game_switches[1111] = true',
        'Mist Billingsgate Fish Market' => '$game_switches[1112] = true',
        'Mist Ox Ward University' => '$game_switches[1113] = true',
        'Mist Sick Clock Tower' => '$game_switches[1114] = true',
        "Mist Jubjub's Nest" => '$game_switches[1115] = true',
        'Mist Riverside' => '$game_switches[1116] = true',
        'Mist Red Castle Frissel' => '$game_switches[1117] = true',
        "Mist Duchess' Mansion" => '$game_switches[1118] = true',
        'Mist Infinite Food' => '$game_switches[1119] = true',
        'Mist Queensland' => '$game_switches[1120] = true',
        'Mist Deep Sea' => '$game_switches[1121] = true',
        'Mist Crimean Nursing Graveyard' => '$game_switches[1122] = true',
        'Mist Florence Arena' => '$game_switches[1123] = true',
        'Mist Windless Valley' => '$game_switches[1124] = true',
        'Mist Black Knight Arena' => '$game_switches[1125] = true',
        'Mist White Castletown' => '$game_switches[1126] = true',
        "Mist Jabberwock's Lair" => '$game_switches[1127] = true',
        'Covenant: Node' => '$game_switches[1150] = true',
        'Covenant: Bill' => '$game_switches[1151] = true',
        'Covenant: Dodo' => '$game_switches[1152] = true',
        'Covenant: Tweedledee & Tweedledum' => '$game_switches[1153] = true; $game_switches[1154] = true',
        'Covenant: Capitellar' => '$game_switches[1155] = true',
        'Covenant: Mock Turtle' => '$game_switches[1157] = true',
        'Covenant: Walrus' => '$game_switches[1158] = true',
        'Covenant: Queen of Hearts' => '$game_switches[1159] = true',
        'Covenant: Hatta' => '$game_switches[1160] = true',
        'Covenant: Maid Victoria' => '$game_switches[1161] = true',
        'Covenant: Best Girl Prickett' => '$game_switches[1162] = true',
        'Covenant: Kuti' => '$game_switches[1163] = true',
        'Covenant: Bandersnatch' => '$game_switches[1164] = true',
        'Covenant: Sho' => '$game_switches[1165] = true',
    }

    $ap_excluded_item_names = [
        "Herb Flask",
        "Herb Flask (M)",
        "Bloody Key",
        "Lamp Spark",
    ]

    ringlink_enabled = false
    $ringlink_conversion_rate = 1

#==============================================================================
# ** CODE -- setup helpers (unchanged from Archipelago_RGSS3)
#==============================================================================
    def get_rng_from_str(string)
        range_regex = /\((\d+)(\.{2,3})(\d+)\)/
        ranges = []
        string.scan(range_regex) do |match|
            start_value = match[0].to_i
            end_value = match[2].to_i
            inclusive = match[1] == '..'
            ranges << (inclusive ? (start_value..end_value) : (start_value...end_value))
        end
        ranges.empty? ? false : ranges
    end

    def replace_rng_with_pl(string)
        range_regex = /\((\d+)(\.{2,3})(\d+)\)/
        ranges = string.scan(range_regex)
        string = string.gsub(range_regex, "\uFFFC") if ranges.any?
        return string
    end

    def replace_pl_with_int(string, ints)
        i = -1
        modified_string = string.gsub(/\uFFFC/) do |match|
            i += 1
            ints[i]
        end
        return modified_string
    end

    def expand_progressive_methods(progressive_methods)
        expanded_progressive_methods = {}
        progressive_methods.each do |key, value|
            iterate_to = 0
            pro_method_array = []
            value.each do |pro_method|
                ranges = get_rng_from_str(pro_method)
                if ranges
                    modding_string = replace_rng_with_pl(pro_method)
                    ranges.each do |range|
                        iterate_to = range.to_a.length if (iterate_to == 0) || (range.to_a.length < iterate_to)
                    end
                    iterate_to.times do |i|
                        ints_to_add = []
                        ranges.each { |range| ints_to_add << (range.to_a[i]) }
                        pro_method_array << replace_pl_with_int(modding_string, ints_to_add)
                    end
                else
                    pro_method_array << pro_method
                end
            end
            expanded_progressive_methods[key] = pro_method_array
        end
        expanded_progressive_methods
    end

    def expand_receiveditem_methods(receiveditem_methods)
        expanded_receiveditem_methods = {}
        receiveditem_methods.each do |key, value|
            if key.is_a?(Range)
                ranges = get_rng_from_str(value)
                if ranges
                    modding_string = replace_rng_with_pl(value)
                    key.each_with_index do |v, i|
                        ints_to_add = []
                        ranges.each { |range| ints_to_add << (range.to_a[i]) }
                        expanded_receiveditem_methods[v] = replace_pl_with_int(modding_string, ints_to_add)
                    end
                else
                    key.each { |v| expanded_receiveditem_methods[v] = value }
                end
            else
                expanded_receiveditem_methods[key] = value
            end
        end
        expanded_receiveditem_methods
    end

    $expanded_progressive_methods = expand_progressive_methods(progressive_methods)
    $expanded_receiveditem_methods = expand_receiveditem_methods(receiveditem_methods)

    $progressive_counts = {}
    def progressive(key)
        if $expanded_progressive_methods.include?(key)
            $progressive_counts[key] = 0 unless $progressive_counts.include?(key)
            eval_target = $expanded_progressive_methods[key].fetch($progressive_counts[key], "puts \"[Archipelago_Combined] No defined method for index #{$progressive_counts[key]} in key #{key}!\"")
            eval(eval_target)
            $progressive_counts[key] += 1
        else
            puts "[Archipelago_Combined] Key \"#{key}\" not found in progressive_methods!"
        end
    end

    def text_input(prompt)
        Input.update; Graphics.update
        text = ""
        Input.text_input = true
        until Input.triggerex?(:RETURN)
            if Input.pressex?(:LCTRL) || Input.pressex?(:RCTRL)
                Input.clipboard = text if Input.triggerex?(:C)
                text << Input.clipboard if Input.triggerex?(:V)
            elsif Input.triggerex?(:BACKSPACE) || Input.timeex?(:BACKSPACE) >= 0.75
                text = text.chop
            else
                got = Input.gets
                text << got unless got.nil? || got.empty?
            end
            Input.update; Graphics.update
            $stdout.clear_screen
            puts "#{prompt} #{text}"
        end
        Input.text_input = false
        $stdout.clear_screen
        return text
    end

    def get_connect_details
        config_path = File.join(Dir.pwd, "archipelago.json")
        if File.exist?(config_path)
            config = JSON.parse(File.read(config_path))
            $archipelago.connect_info["hostname"] = config["hostname"].empty? ? "archipelago.gg" : config["hostname"]
            $archipelago.connect_info["port"] = config["port"].to_i
            $archipelago.connect_info["name"] = config["name"]
            $archipelago.connect_info["password"] = config["password"] unless config["password"].empty?
        else
            puts "[Archipelago_Combined] archipelago.json not found in game directory!"
            puts "[Archipelago_Combined] Please create it with hostname, port, name and password fields."
        end
    end

    class Scene_APConnectInput < Scene_Base
        def start
            super
            draw_image
        end
        def post_start
            super
            begin_text_input
            SceneManager.goto(Scene_Map)
        end
        def draw_image
            @pic = Sprite.new
            @pic.bitmap = Cache.custom("Pictures/text_input")
        end
        def begin_text_input
            get_connect_details
            $archipelago.connect
        end
        def update
            super
        end
    end

    module Archipelago
        class Client
            def get_connect
                SceneManager.call(Scene_APConnectInput) unless @client_connect_status == Archipelago::ConnectStatus::CONNECTED
            end
        end
    end

#==============================================================================
# ** BS2Randomizer -- trimmed to enemy + door shuffling only.
#==============================================================================
module BS2Randomizer
    CONFIG_FILE = "RandomizerConfig.txt"
    DEFAULTS = {
        "seed" => "12345",
        "enemy_randomization" => "true",
        "room_transition_randomization" => "false",
        "regional_transition_randomization" => "false",
        "regional_randomization" => "false",
        "shop_item_randomization" => "false",
        "non_ap_item_randomization" => "true"
    }

    INTRO_MAP_IDS = [185, 7, 110]
    NEVER_SHUFFLE_ITEM_IDS = [69, 70, 95]


    BLOODY_KEY_ITEM_ID = 68
    CRASH_CHAMBER_MAP_ID = 1

    MAP_REGION_IDS = {1=>51,2=>2,3=>1003,4=>1003,5=>2,6=>1003,7=>7,8=>8,9=>9,10=>28,11=>11,12=>12,13=>11,14=>11,15=>11,16=>37,17=>9,18=>38,19=>81,20=>12,21=>12,22=>12,23=>9,24=>24,25=>25,26=>26,27=>26,28=>28,29=>29,30=>30,31=>31,32=>31,33=>34,34=>34,35=>35,36=>36,37=>37,38=>38,39=>39,40=>39,41=>41,42=>81,43=>24,44=>45,45=>45,46=>46,47=>47,48=>48,49=>49,50=>12,51=>51,52=>51,53=>51,54=>51,55=>51,56=>2,57=>46,58=>58,59=>1003,60=>46,61=>34,62=>34,63=>37,64=>37,65=>37,66=>12,67=>12,68=>12,69=>12,70=>12,71=>38,72=>38,73=>38,74=>38,75=>41,76=>41,77=>41,78=>41,79=>41,80=>41,81=>81,82=>81,83=>81,84=>81,85=>12,86=>25,87=>38,88=>38,89=>38,90=>38,91=>25,92=>25,93=>25,94=>25,95=>30,96=>30,97=>7,98=>7,99=>7,100=>101,101=>101,102=>30,103=>30,104=>35,105=>30,106=>30,107=>31,108=>31,109=>31,110=>7,111=>31,112=>11,113=>26,114=>11,115=>81,116=>81,117=>28,118=>28,119=>28,120=>28,121=>7,122=>28,123=>28,124=>28,125=>28,126=>47,127=>47,128=>47,129=>47,130=>1003,131=>2,132=>51,133=>47,134=>36,135=>36,136=>51,137=>36,138=>36,139=>139,140=>28,141=>139,142=>36,143=>36,144=>36,145=>36,146=>31,147=>36,148=>36,149=>9,150=>9,151=>8,152=>101,153=>8,154=>9,155=>9,156=>156,157=>24,158=>24,159=>24,160=>24,161=>45,162=>45,163=>45,164=>45,165=>46,166=>2,167=>46,168=>46,169=>46,170=>46,171=>48,172=>48,173=>46,174=>46,175=>48,176=>12,177=>46,178=>49,179=>49,180=>31,181=>101,182=>47,183=>36,184=>34,185=>7,186=>7,187=>7,188=>7,189=>7,190=>7,191=>7,192=>7,193=>49,194=>49,195=>7,196=>139,197=>139,198=>101,199=>11,200=>41,201=>26,202=>202,203=>202,204=>202,205=>202,206=>202,207=>202,208=>202,209=>202,210=>202,211=>202,212=>202,213=>202,214=>202,215=>101,216=>202,217=>202,218=>202,219=>202,220=>202,221=>202,222=>202,223=>202,224=>202,225=>202,226=>202,227=>202,228=>202,229=>202,230=>202,231=>202,232=>202,233=>202,234=>202,235=>202,236=>202,237=>202,238=>202,239=>202,240=>202,241=>202,242=>202,243=>202,244=>202,245=>202,246=>202,247=>202,248=>202,249=>202,250=>202,251=>202,252=>26,253=>202,254=>202,255=>202,256=>202,257=>202,258=>202,259=>202,260=>46,261=>31,262=>202,263=>202,264=>202,265=>202,266=>202,267=>202,268=>202,269=>202,270=>202,271=>202,272=>202,273=>49,274=>46,275=>46,276=>46,277=>46,278=>202,279=>46,280=>202,281=>202,282=>202,283=>202,284=>202,285=>202,286=>202,287=>202,288=>202,289=>202,290=>202,291=>202,292=>202,293=>202,294=>202,295=>202,296=>202,297=>202,298=>202,299=>202,300=>202,301=>202,302=>202,303=>202,304=>31,305=>202,306=>202,307=>202,308=>202,309=>202,310=>310,311=>47,312=>310,313=>310,314=>310,315=>202,316=>310,317=>310,318=>310,319=>310,320=>310,321=>310,322=>310,323=>310,324=>310,325=>310,326=>310,327=>310,328=>310,329=>310,330=>310,331=>331,332=>331,333=>331,334=>331,335=>331,336=>331,337=>331,338=>331,339=>331,340=>331,341=>331,342=>331,343=>331,344=>331,345=>331,346=>331,347=>331,348=>331,349=>331,350=>331,351=>331,352=>331,353=>331,354=>331,355=>331,356=>331,357=>331,358=>310,359=>331,360=>331,361=>331,362=>331,363=>331,364=>331,365=>331,366=>331,367=>331,368=>331,369=>331,370=>331,371=>331,372=>331,373=>331,374=>331,375=>331,376=>331,377=>331,378=>331,379=>331,380=>331,381=>331,382=>331,383=>331,384=>331,385=>331,386=>331,387=>331,388=>7,389=>7,390=>7,391=>7,392=>331,393=>331,394=>331,395=>331,396=>331,397=>202,398=>331,399=>331,400=>331,401=>331,402=>331,403=>202,404=>202,405=>202,406=>202,407=>202,408=>202,409=>331,410=>331}

    def self.config
        return @config if @config
        @config = DEFAULTS.clone
        if File.exist?(CONFIG_FILE)
            File.readlines(CONFIG_FILE).each do |line|
                line = line.strip
                next if line.empty? || line[0,1] == "#" || !line.include?("=")
                key, value = line.split("=", 2)
                @config[key.strip.downcase] = value.strip
            end
        end
        @config
    end

    def self.enabled?(key)
        v = config[key].to_s.downcase
        v == "true" || v == "1" || v == "yes" || v == "on"
    end

    def self.seed
        config["seed"].to_i
    end

    def self.hash_value(text)
        h = seed & 0x7fffffff
        text.to_s.each_byte { |b| h = ((h * 1103515245) + b + 12345) & 0x7fffffff }
        h
    end

    def self.pick(pool, key)
        return nil if pool.nil? || pool.empty?
        pool[hash_value(key) % pool.length]
    end

    def self.region_for_map(map_id)
        MAP_REGION_IDS[map_id.to_i] || map_id.to_i
    end

    def self.regional_mode?
        enabled?("regional_randomization") || enabled?("regional_transition_randomization")
    end

    def self.never_shuffle_item?(id)
        NEVER_SHUFFLE_ITEM_IDS.include?(id.to_i)
    end

    def self.protected_bloody_key?(interpreter, params)
        map_id(interpreter) == CRASH_CHAMBER_MAP_ID && params && params[0].to_i == BLOODY_KEY_ITEM_ID
    end

    def self.map_id(interpreter)
        interpreter.instance_variable_get(:@map_id).to_i
    end

    def self.intro_map?(interpreter)
        INTRO_MAP_IDS.include?(map_id(interpreter))
    end

    def self.transfer_key(interpreter, params)
        map_id   = interpreter.instance_variable_get(:@map_id).to_i
        event_id = interpreter.instance_variable_get(:@event_id).to_i
        index    = interpreter.instance_variable_get(:@index).to_i
        [map_id, event_id, index, params[1].to_i, params[2].to_i, params[3].to_i].join(":")
    end

    #--------------------------------------------------------------------
    # AP-facing location naming. MUST match generate_manual_apworld.py's
    # location_name()/KIND_LABELS exactly.
    #--------------------------------------------------------------------
    KIND_LABELS = { "item" => "Item", "weapon" => "Weapon", "armor" => "Armor" }

    #--------------------------------------------------------------------
    #--------------------------------------------------------------------
    REGION_ITEM_POOLS = {2=>[1, 3, 4, 5, 6, 10, 11, 12, 13, 18, 20, 22, 23, 26, 30, 31, 33, 35, 36, 37, 38, 39, 40, 47, 48, 49, 50, 53, 60, 61, 63, 64, 77, 90, 214, 336, 364],7=>[1, 2, 3, 4, 5, 6, 7, 18, 30, 49, 63, 67],8=>[8, 9, 10, 14, 23, 28, 30, 34, 42, 44, 47, 50, 53, 54, 57, 59, 63, 223, 362],9=>[2, 6, 8, 10, 11, 13, 14, 16, 22, 23, 28, 34, 41, 43, 49, 60, 62, 63, 79, 103, 207, 326, 332, 350],11=>[6, 12, 13, 14, 19, 20, 33, 35, 45, 46, 49, 51, 56, 57, 58, 61, 71, 77, 78, 79, 85, 94],12=>[1, 2, 3, 6, 7, 10, 14, 15, 18, 19, 22, 23, 27, 28, 38, 40, 42, 48, 49, 51, 54, 57, 62, 63, 98, 205, 213, 341],24=>[6, 13, 14, 15, 19, 24, 29, 44, 49, 59, 88, 102, 208, 211, 292],25=>[1, 6, 9, 10, 11, 12, 13, 14, 18, 22, 23, 26, 27, 28, 32, 33, 38, 39, 40, 42, 49, 50, 51, 53, 54, 56, 63, 94, 203, 212, 320],26=>[2, 7, 9, 10, 12, 17, 18, 19, 21, 25, 60, 78, 92],28=>[6, 9, 10, 12, 13, 15, 20, 22, 23, 25, 27, 28, 29, 33, 34, 40, 41, 42, 43, 44, 47, 49, 56, 61, 94],29=>[9, 17, 20, 23, 27, 28, 29],30=>[3, 6, 8, 11, 20, 23, 26, 27, 28, 31, 37, 42, 49, 51, 52, 56, 58, 63, 90, 204],31=>[1, 7, 8, 9, 10, 13, 15, 17, 18, 21, 23, 24, 25, 28, 31, 41, 42, 46, 49, 56, 57, 58, 59, 61, 62, 63, 72, 89, 91, 94, 97, 101, 104, 105, 106, 206, 215, 216, 219, 293, 339, 343],34=>[1, 2, 4, 5, 6, 9, 10, 14, 16, 18, 21, 22, 23, 25, 26, 27, 34, 35, 38, 39, 48, 49, 54, 65, 74, 81, 83, 191, 199, 322],35=>[1, 3, 5, 9, 11, 12, 15, 16, 23, 24, 25, 26, 27, 28, 33, 39, 49, 52, 59, 64, 321],36=>[1, 3, 5, 7, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 23, 25, 27, 28, 30, 31, 34, 40, 41, 46, 47, 49, 53, 59, 64, 210, 335, 338, 360],37=>[1, 3, 5, 8, 11, 14, 18, 19, 21, 23, 25, 26, 27, 32, 37, 38, 39, 40, 41, 47, 49, 63, 76, 221, 224, 349],38=>[1, 6, 7, 9, 11, 13, 20, 23, 27, 28, 40, 47, 49, 52, 54, 59, 63, 64, 209, 331, 355],39=>[2, 4, 9, 10, 11, 12, 13, 14, 20, 21, 22, 24, 26, 27, 28, 52, 61, 344],41=>[1, 2, 11, 13, 14, 16, 18, 20, 21, 23, 24, 27, 28, 29, 31, 40, 41, 42, 47, 49, 58, 65, 73, 76, 90],45=>[1, 2, 6, 7, 9, 10, 11, 12, 13, 15, 16, 17, 18, 19, 23, 24, 25, 28, 32, 34, 39, 42, 43, 44, 45, 52, 54, 57, 58, 59, 64, 73, 76, 77, 79, 217, 361],46=>[1, 9, 10, 11, 12, 13, 15, 16, 23, 24, 25, 29, 45, 47, 49, 56, 59, 63, 64, 71, 78, 79, 80, 82, 89, 94, 180, 181, 182, 183, 222, 225],47=>[3, 5, 6, 9, 11, 13, 18, 23, 24, 28, 30, 31, 32, 33, 40, 42, 50, 53, 56, 201, 218, 220, 291, 354],49=>[9, 10, 11, 12, 13, 14, 15, 16, 330],51=>[3, 5, 9, 11, 15, 17, 18, 20, 23, 26, 30, 32, 35, 36, 37, 46, 47, 49, 53, 56, 68, 71, 88, 219, 357],58=>[197],81=>[1, 2, 7, 8, 9, 10, 11, 12, 13, 14, 15, 18, 20, 21, 22, 23, 25, 26, 27, 28, 32, 33, 34, 35, 37, 40, 42, 46, 49, 50, 52, 53, 54, 58, 60, 64, 77, 202],101=>[1, 2, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 23, 25, 29, 49, 56, 57, 63, 71, 80, 88, 194, 215, 291, 292, 293, 327, 328, 329, 333, 340, 341, 345, 352, 353, 356, 358, 376, 377],139=>[6, 8, 11, 12, 15, 17, 18, 28, 44, 61, 64, 71, 79, 85, 86, 94, 226, 342],156=>[10, 14, 24],202=>[9, 10, 11, 12, 13, 14, 15, 16, 17, 24, 59, 60, 79, 84, 95, 96],310=>[3, 6, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 25, 31, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 49, 52, 54, 56, 60, 62, 64, 79, 84, 85, 86, 89, 94, 98, 99, 100, 101, 103, 108, 190, 191, 227, 298, 363, 367, 368],331=>[1, 2, 6, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 28, 29, 32, 34, 35, 43, 45, 46, 49, 50, 51, 56, 60, 76, 77, 79, 80, 84, 86, 94, 97, 101, 102, 104, 105, 106, 107, 108, 229, 230, 231, 232, 300, 301, 303, 365, 366, 376, 377],1003=>[4, 9, 12, 13, 14, 16, 18, 21, 23, 25, 26, 37, 38, 40, 46, 47, 57, 59, 61, 62, 63, 71]}
    REGION_WEAPON_POOLS = {2=>[222],8=>[104],9=>[391],11=>[299],12=>[167, 361, 373],26=>[421, 457],28=>[379],29=>[101, 122, 133, 144, 155, 166, 188, 221, 232, 282, 323],30=>[145],34=>[112, 200],36=>[355],37=>[156],39=>[178, 211],41=>[101, 266],45=>[311, 385],47=>[277, 311],51=>[255, 397],81=>[244],101=>[134, 288, 310, 403, 409, 415, 433, 451, 469, 476, 482],139=>[309],310=>[463],1003=>[233]}
    REGION_ARMOR_POOLS = {2=>[5, 6, 7, 31, 42, 65, 80, 81, 82],7=>[152],8=>[28, 34, 133, 134],9=>[56, 111, 116, 129],11=>[71, 72, 73],12=>[11, 86, 120, 124],24=>[12, 107, 138],25=>[18, 75, 121, 122],26=>[54, 122],28=>[58, 84, 114, 142],30=>[20, 30, 83, 117, 127],31=>[118, 169],34=>[14, 16, 22, 24, 46, 52, 66, 76, 79, 89, 99, 101],35=>[21, 48, 228],36=>[3, 19, 27, 35, 39, 59],37=>[15, 23, 26, 40, 47, 91, 104, 140],38=>[44, 84, 98],41=>[1, 2, 17, 25, 51, 153],45=>[4, 29, 36, 55, 85, 125, 135, 139, 158],46=>[61, 63, 131, 152],47=>[13, 57, 83, 128],49=>[100],51=>[43, 77, 79],81=>[32, 41, 94, 109],101=>[49, 50, 54, 67, 82, 86, 87, 88, 100, 113, 123, 125, 129, 137, 143, 144, 145, 146, 147, 148, 154, 155, 156, 216, 230, 231, 236, 242],139=>[62, 149],202=>[220],310=>[161, 183, 195, 214, 215, 219, 221, 222, 238],331=>[37, 147, 164, 179, 186, 189, 192, 198, 213, 218, 225, 226, 227, 229, 230, 231, 232, 233, 234, 235, 239, 241],1003=>[45, 93, 101]}

    def self.region_pool(kind, map_id)
        region = region_for_map(map_id)
        case kind.to_s
        when "item"   then REGION_ITEM_POOLS[region] || []
        when "weapon" then REGION_WEAPON_POOLS[region] || []
        when "armor"  then REGION_ARMOR_POOLS[region] || []
        else []
        end
    end

    def self.display_name(kind, id)
        case kind.to_s
        when "item"   then $data_items[id] && $data_items[id].name
        when "weapon" then $data_weapons[id] && $data_weapons[id].name
        when "armor"  then $data_armors[id] && $data_armors[id].name
        end
    end

    def self.excluded_by_name?(kind, id)
        name = display_name(kind, id)
        return false unless name
        defined?($ap_excluded_item_names) && $ap_excluded_item_names.include?(name)
    end


    def self.has_ap_location?(kind, id)
        return false if excluded_by_name?(kind, id)
        name = display_name(kind, id)
        return false unless name
        candidates = ap_location_pool[name]
        candidates && !candidates.empty?
    end

    #--------------------------------------------------------------------
    #--------------------------------------------------------------------
    def self.non_ap_region_pool(kind, map_id)
        region_pool(kind, map_id).select do |id|
            !has_ap_location?(kind, id) && !excluded_by_name?(kind, id)
        end
    end

    def self.shuffled_non_ap_item_id(kind, map_id, original_id)
        return original_id unless enabled?("non_ap_item_randomization")
        ids = non_ap_region_pool(kind, map_id)
        return original_id unless ids.include?(original_id.to_i)
        cache_key = "nonap:" + region_for_map(map_id).to_s + ":" + kind.to_s
        permutation_for_ids(ids, cache_key)[original_id.to_i] || original_id
    end

    def self.build_ap_randomized_items!
        $ap_randomized_items = {}
       
        [[$data_items, "items", "item"], [$data_weapons, "weapons", "weapon"], [$data_armors, "armors", "armor"]].each do |data, plural, kind|
            next unless data
            data.each_with_index do |obj, id|
                next if id == 0 || obj.nil?
                $ap_randomized_items[[plural, id]] = true if has_ap_location?(kind, id)
            end
        end
        $ap_randomized_items
    end

    #--------------------------------------------------------------------
    #--------------------------------------------------------------------
    AP_LOCATION_POOL_FILE = "ap_location_pool.json"

    def self.ap_location_pool
        return @ap_location_pool if @ap_location_pool
        @ap_location_pool = {}
        if File.exist?(AP_LOCATION_POOL_FILE)
            @ap_location_pool = JSON.parse(File.read(AP_LOCATION_POOL_FILE))
        else
            puts "[Archipelago_Combined] WARNING: #{AP_LOCATION_POOL_FILE} not found next to the game exe -- AP location checks will not work. Copy the file there."
        end
        @ap_location_pool
    end

    #--------------------------------------------------------------------
    # ** Multi-location item disambiguation
    #--------------------------------------------------------------------
    MULTI_LOCATION_ITEM_DISAMBIGUATION = {
        "Flame Stoneplate Ring" => {96 => "SH: Flame Stoneplate Ring", 126 => "FF: Flame Stoneplate Ring"},
        "Poisonbite Ring" => {42 => "IF: Poisonbite Ring", 62 => "RGC: Poisonbite Ring"},
        "Ring of White Crow" => {93 => "BFM: Ring of White Crow", 26 => "BoG: Ring of White Crow"},
        "Sorcerer's Staff" => {70 => "MW: Sorcerer's Staff", 34 => "RGC: Sorcerer's Staff"},
        "Thunder Stoneplate Ring" => {71 => "SF: Thunder Stoneplate Ring", 118 => "ORS: Thunder Stoneplate Ring"},
        "Ring of Heaven" => {9 => "OWU: Ring of Heaven", 101 => "LD: Ring of Heaven (exchange for Soul of the Bright Star)"},
        "Spell Stoneplate Ring" => {66 => "MW: Spell Stoneplate Ring", 101 => "LD: Spell Stoneplate Ring (exchange for Soul of the Pregnant Cake)"},
        "Ring of Steel Protection" => {131 => "LT: Ring of Steel Protection", 101 => "LD: Ring of Steel Protection (exchange for Soul of the Gray Eagle)"},
    }

    $ap_item_occurrence_counters = Hash.new(0)

    def self.ap_location_name(kind, map_id, original_id)
        display_name = case kind.to_s
                        when "item"   then $data_items[original_id] && $data_items[original_id].name
                        when "weapon" then $data_weapons[original_id] && $data_weapons[original_id].name
                        when "armor"  then $data_armors[original_id] && $data_armors[original_id].name
                        end
        return nil unless display_name

        disambiguation = MULTI_LOCATION_ITEM_DISAMBIGUATION[display_name]
        if disambiguation
            matched = disambiguation[map_id.to_i]
            return matched if matched
            puts "[Archipelago_Combined] WARNING: '#{display_name}' granted from map #{map_id}, which isn't in its disambiguation table -- falling back to occurrence-count guessing, this pickup's check may be wrong."
        end

        candidates = ap_location_pool[display_name]
        return nil if candidates.nil? || candidates.empty?

        key = [kind.to_s, original_id]
        idx = $ap_item_occurrence_counters[key]
        $ap_item_occurrence_counters[key] += 1
        if idx >= candidates.length
            puts "[Archipelago_Combined] WARNING: saw '#{display_name}' (#{kind}) #{idx + 1} times, but only #{candidates.length} location(s) exist for it in the pool. Wrapping around -- this pickup's check may be wrong."
            idx = idx % candidates.length
        end
        candidates[idx]
    end

    #--------------------------------------------------------------------
    # Enemy randomization stays local/seeded (unaffected by AP).
    #--------------------------------------------------------------------
    REGION_TROOP_POOLS = {2=>[4, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 176, 286, 287, 288, 369, 629],8=>[31, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 183, 229],9=>[141, 142, 143, 184, 185, 240, 243, 244, 245, 246, 247, 248, 249, 289, 290],11=>[331, 334, 335, 336, 337, 338, 339, 346, 347, 348, 369],12=>[141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 181, 199, 200, 366],24=>[187, 218, 219],25=>[96, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 117, 128, 179, 223, 227, 228, 239, 289, 290],26=>[116, 208, 209, 211, 289, 290, 332, 333, 371],28=>[154, 155, 156, 157, 158, 159, 239, 343, 356, 357, 360, 361],29=>[177],30=>[28, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 180, 271, 367, 369, 370],31=>[133, 134, 135, 136, 137, 138, 139, 182, 201, 220, 221, 230, 368, 369, 591],34=>[15, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 90, 188, 189, 237, 270, 273, 364, 369],35=>[202, 210, 238, 251, 252, 253, 254, 255, 256, 258, 369],36=>[90, 186, 203, 204, 208, 209, 215, 254, 256, 257, 258, 259, 260, 261, 262, 263, 264, 265, 266, 267, 268, 269, 289, 290, 369],37=>[62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 190, 191, 222, 225, 237, 369],38=>[15, 73, 74, 75, 76, 77, 78, 79, 80, 192, 193, 194, 238, 289, 290, 369],39=>[76, 80, 81, 195],41=>[83, 84, 85, 86, 87, 88, 89, 90, 91, 196, 197, 238],45=>[168, 169, 212, 213, 231, 241, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 291],46=>[141, 142, 143, 163, 209, 214, 233, 289, 290, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302, 303, 304, 305, 306, 308],47=>[129, 130, 131, 216, 217, 232, 239, 369, 523],48=>[309, 310, 311, 312],49=>[313, 314, 315, 316, 317, 318, 319, 320, 321, 322, 323, 324, 325, 326, 327, 328, 358, 372, 373],51=>[1, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 173, 174, 223, 286, 287, 288, 363],58=>[175],81=>[15, 36, 90, 93, 94, 95, 96, 97, 98, 99, 100, 101, 178, 198, 272],101=>[226],139=>[332, 337, 341, 342, 344, 349, 350, 351, 352, 353, 354],156=>[205, 206, 207],202=>[500, 501, 538, 539, 622, 623, 624, 625, 626, 627],310=>[542, 546, 549, 550, 551, 552, 553, 554, 555, 556, 557, 558, 559, 560, 561, 562, 563, 564, 566, 567, 568, 569, 600],331=>[90, 544, 571, 572, 573, 574, 575, 576, 577, 578, 579, 580, 581, 582, 583, 584, 585, 586, 587, 588, 589, 590, 591, 592, 593, 594, 601, 603, 604, 606, 608, 609, 610, 611, 613, 614, 615, 616, 617, 620],1003=>[16, 17, 19, 25, 35, 208, 209, 237, 286, 287, 288, 289, 290]}

    def self.troop_pool
        return @troop_pool if @troop_pool
        @troop_pool = []
        if $data_troops
            $data_troops.each_with_index do |troop, id|
                next if id == 0 || troop.nil?
                members = troop.respond_to?(:members) ? troop.members : []
                next if members.nil? || members.empty?
                @troop_pool << id
            end
        end
        @troop_pool
    end

    def self.permutation_for_ids(ids, cache_key)
        @permutation_maps ||= {}
        return @permutation_maps[cache_key] if @permutation_maps[cache_key]
        ids = ids.uniq.clone
        result = {}
        if ids.length == 1
            result[ids[0]] = ids[0]
        elsif ids.length > 1
            shuffled = ids.clone
            state = hash_value("perm:" + cache_key.to_s) & 0x7fffffff
            i = shuffled.length - 1
            while i > 0
                state = (state * 1103515245 + 12345) & 0x7fffffff
                j = state % i
                tmp = shuffled[i]; shuffled[i] = shuffled[j]; shuffled[j] = tmp
                i -= 1
            end
            ids.each_with_index { |id, idx| result[id] = shuffled[idx] }
        end
        @permutation_maps[cache_key] = result
    end

    def self.region_troop_pool(map_id)
        REGION_TROOP_POOLS[region_for_map(map_id)] || []
    end

    #--------------------------------------------------------------------
    # ** Original (pre-randomization) troop id for a battle command
    #--------------------------------------------------------------------
    def self.original_troop_id(interpreter)
        params = interpreter.instance_variable_get(:@params) || []
        if params[0].to_i == 0
            params[1].to_i
        elsif params[0].to_i == 1 && defined?($game_variables) && $game_variables
            $game_variables[params[1].to_i].to_i
        else
            0
        end
    end

    def self.random_troop(interpreter)
        mid = map_id(interpreter)
        original_id = original_troop_id(interpreter)

        if regional_mode?
            ids = region_troop_pool(mid).select { |id| troop_pool.include?(id) }
            return original_id if original_id > 0 && !ids.include?(original_id)
            return nil if ids.empty? || original_id <= 0
            permutation_for_ids(ids, "region:" + region_for_map(mid).to_s + ":troop")[original_id] || original_id
        else
            pick(troop_pool, "enemy:#{mid}:#{interpreter.instance_variable_get(:@event_id)}:#{interpreter.instance_variable_get(:@index)}")
        end
    end

    #--------------------------------------------------------------------

    #--------------------------------------------------------------------
    DOOR_GROUPS = [[["11:51:1:11:51:31"],11,6,42,2,0,1],[["11:52:1:11:6:42"],11,51,31,2,0,0],[["12:5:11:69:5:33"],12,7,8,2,2,3],[["69:15:12:12:7:8"],69,5,33,2,2,2],[["50:6:0:176:12:26","50:2:0:176:12:26","50:7:0:176:12:26"],50,12,26,0,2,5],[["176:5:0:50:12:26","176:3:0:50:12:26","176:4:0:50:12:26"],176,12,26,0,2,4],[["66:25:11:68:10:9"],66,57,6,2,2,7],[["68:3:11:66:57:6"],68,10,9,2,2,6],[["68:2:11:69:5:18"],68,40,9,2,2,10],[["68:7:11:69:10:44"],68,9,28,2,2,11],[["69:2:11:68:40:9"],69,5,18,2,2,8],[["69:11:11:68:9:28"],69,10,44,2,2,9],[["100:108:0:100:33:53"],100,33,11,4,2,13],[["100:109:0:100:33:11"],100,33,53,4,2,12],[["100:110:0:100:7:11"],100,7,53,6,2,15],[["100:111:0:100:7:53"],100,7,11,6,2,14],[["347:16:10:409:16:40"],347,13,46,2,0,17],[["409:34:10:347:13:46"],409,16,40,2,0,16],[["3:13:13:59:15:14"],3,6,3,0,0,19],[["59:2:1:3:6:3"],59,15,14,8,2,18],[["5:23:10:12:14:23"],5,20,7,0,0,21],[["12:6:1:5:20:7"],12,14,23,8,0,20],[["8:48:14:151:14:43"],8,41,10,2,0,23],[["151:3:1:8:41:10"],151,14,43,8,2,22],[["9:13:11:155:40:36"],9,18,66,0,0,25],[["155:3:1:9:18:66"],155,40,36,8,0,24],[["9:15:12:150:9:18"],9,44,63,2,2,27],[["150:2:2:9:44:63"],150,9,18,8,2,26],[["12:3:12:66:21:43"],12,21,8,2,0,29],[["66:12:1:12:21:8"],66,21,43,0,2,28],[["13:8:1:14:14:29"],13,21,27,8,0,31],[["14:3:1:13:21:27"],14,14,29,2,0,30],[["14:4:1:14:36:8"],14,10,8,8,0,33],[["14:5:1:14:10:8"],14,36,8,2,0,32],[["14:6:1:14:66:29"],14,40,28,8,0,35],[["14:7:1:14:40:28"],14,66,29,2,0,34],[["14:8:1:15:16:10"],14,61,8,8,0,37],[["15:3:1:14:61:8"],15,16,10,2,0,36],[["20:8:11:21:9:29"],20,17,25,2,0,39],[["21:2:1:20:17:25"],21,9,29,8,2,38],[["26:4:2:28:22:13"],26,7,38,6,2,41],[["28:5:2:26:7:38"],28,22,13,2,2,40],[["28:5:2:201:7:38"],28,22,13,2,2,43],[["201:4:2:28:22:13"],201,7,38,6,2,42],[["31:90:2:261:3:3"],31,87,42,8,0,45],[["261:4:1:31:87:42"],261,3,3,2,2,44],[["33:3:11:34:27:68"],33,36,8,2,0,47],[["34:23:1:33:36:8"],34,27,68,8,0,46],[["36:7:17:135:14:33"],36,11,15,0,0,49],[["135:11:1:36:11:15"],135,14,33,8,0,48],[["36:8:1:134:32:38"],36,20,9,0,0,51],[["134:17:1:36:20:9"],134,32,38,0,0,50],[["37:13:1:37:0:13"],37,63,13,0,0,53],[["37:14:1:37:63:13"],37,0,13,6,0,52],[["41:6:11:75:16:68","41:6:13:75:16:68"],41,15,21,2,0,55],[["75:2:1:41:15:21","75:4:1:41:15:21"],75,16,68,8,0,54],[["50:8:1:67:126:17","50:9:1:67:126:17"],50,12,53,8,2,57],[["67:35:11:50:12:53","67:35:11:50:12:53"],67,126,17,0,0,56],[["57:23:52:165:19:33"],57,15,7,2,0,59],[["165:9:1:57:15:7"],165,19,33,8,0,58],[["66:26:11:67:29:23"],66,51,18,0,0,64],[["66:21:11:67:11:23"],66,43,18,2,0,66],[["66:24:11:67:53:23"],66,40,34,0,0,67],[["66:27:1:67:1:14"],66,26,10,0,0,65],[["67:6:1:66:51:18"],67,29,23,0,2,60],[["67:20:1:66:26:10"],67,1,14,0,0,63],[["67:5:1:66:43:18"],67,11,23,0,2,61],[["67:7:1:66:40:34"],67,53,23,0,2,62],[["69:12:13:69:30:38"],69,30,44,2,0,69],[["69:13:1:69:30:44"],69,30,38,8,2,68],[["69:14:11:85:12:117"],69,30,23,0,0,71],[["85:3:1:69:30:23"],85,12,117,8,2,70],[["112:2:1:114:25:3"],112,26,18,8,2,73],[["114:28:11:112:26:18"],114,25,3,2,0,72],[["115:4:11:116:17:28"],115,11,11,2,0,75],[["116:5:1:115:11:11"],116,17,28,8,0,74],[["134:11:11:142:12:53"],134,7,2,0,0,77],[["142:2:1:134:7:2"],142,12,53,8,2,76],[["160:4:1:160:14:21"],160,32,28,8,0,79],[["160:14:10:160:32:28"],160,14,21,0,0,78],[["164:10:1:164:21:32","164:11:1:164:21:32","164:9:1:164:21:32","164:6:1:164:21:32"],164,21,32,8,2,80],[["165:14:11:167:17:38"],165,19,3,0,0,82],[["167:4:1:165:19:3"],167,17,38,0,0,81],[["328:3:15:329:15:28"],328,11,36,2,0,84],[["329:113:1:328:11:36"],329,15,28,8,2,83],[["346:9:12:359:11:23"],346,9,7,2,0,86],[["359:7:1:346:9:7"],359,11,23,8,2,85],[["356:2:5:378:8:6","356:3:5:378:8:6"],356,20,8,2,0,88],[["378:1:12:356:20:8","378:1:12:356:20:8"],378,8,6,0,0,87],[["1:6:15:1:15:43"],1,20,54,2,0,90],[["1:31:11:1:20:54"],1,15,43,2,2,89],[["1:85:11:51:54:63"],1,25,23,2,0,92],[["51:19:1:1:25:23"],51,54,63,0,0,91],[["2:9:1:52:18:7"],2,70,26,8,0,94],[["52:18:21:2:70:26"],52,18,7,0,0,93],[["3:8:1:4:78:16","3:9:1:4:78:16","3:7:1:4:78:16","3:6:1:4:78:16","3:5:1:4:78:16"],3,1,16,0,0,96],[["4:14:1:3:1:16","4:15:1:3:1:16","4:13:1:3:1:16","4:12:1:3:1:16","4:11:1:3:1:16"],4,78,16,0,0,95],[["4:6:1:6:37:73","4:7:1:6:37:73","4:8:1:6:37:73"],4,49,1,2,2,98],[["6:9:2:4:49:1","6:10:2:4:49:1","6:11:2:4:49:1"],6,37,73,0,0,97],[["4:18:1:130:11:38"],4,65,11,0,0,100],[["130:3:1:4:65:11"],130,11,38,0,0,99],[["5:22:13:166:11:18"],5,10,39,0,0,102],[["166:5:1:5:10:39"],166,11,18,8,2,101],[["6:14:1:8:36:71","6:12:1:8:36:71","6:13:1:8:36:71"],6,39,1,2,0,104],[["8:6:1:6:39:1","8:4:1:6:39:1","8:5:1:6:39:1"],8,36,71,8,0,103],[["8:8:1:153:11:48","8:7:1:153:11:48"],8,8,1,2,0,106],[["153:7:1:8:8:1","153:8:1:8:8:1"],153,11,48,8,0,105],[["9:4:1:153:14:3"],9,19,88,8,2,108],[["153:9:2:9:19:88"],153,14,3,2,0,107],[["9:14:12:23:15:11"],9,49,83,0,0,110],[["23:6:1:9:49:83"],23,15,11,0,2,109],[["10:13:1:125:3:15","10:12:1:125:4:15"],10,30,1,0,0,112],[["125:8:3:10:30:1","125:9:3:10:31:1"],125,3,15,0,0,111],[["10:39:1:11:61:40"],10,13,96,0,0,114],[["11:2:3:10:13:96"],11,61,40,0,0,113],[["11:11:1:114:49:22","11:10:1:114:49:22"],11,31,9,2,0,117],[["11:13:1:114:13:22","11:12:1:114:13:22"],11,11,9,2,0,118],[["114:5:1:11:31:9","114:4:1:11:31:9"],114,49,22,8,0,115],[["114:6:1:11:11:9","114:7:1:11:11:9"],114,13,22,8,0,116],[["11:14:2:13:43:25","11:15:2:13:43:25"],11,1,44,6,0,120],[["13:9:1:11:1:44","13:10:1:11:1:44"],13,43,25,4,0,119],[["15:4:1:139:72:5"],15,15,29,8,0,122],[["139:4:1:15:15:29"],139,72,5,2,0,121],[["16:5:1:63:19:5"],16,6,17,8,0,124],[["63:25:13:16:6:17"],63,19,5,2,0,123],[["18:2:1:73:20:12"],18,8,18,8,0,126],[["73:18:5:18:8:18"],73,20,12,0,0,125],[["19:6:1:77:7:6","19:7:1:77:6:6"],19,3,1,2,0,128],[["77:6:1:19:3:1","77:7:1:19:3:1"],77,7,6,0,0,127],[["22:5:2:69:41:41"],22,13,15,8,2,130],[["69:57:11:22:13:15"],69,41,41,2,0,129],[["23:7:1:107:24:8"],23,33,91,8,2,132],[["107:6:4:23:33:91"],107,24,8,0,0,131],[["24:4:1:156:31:13"],24,12,23,0,2,134],[["156:2:12:24:12:23"],156,31,13,0,0,133],[["24:5:3:157:14:62"],24,12,13,4,0,136],[["157:2:1:24:12:13"],157,14,62,6,2,135],[["25:6:1:56:24:108"],25,13,14,0,0,138],[["56:43:1:25:13:14"],56,24,108,8,0,137],[["25:8:1:86:1:18","25:9:1:86:1:18","25:10:1:86:1:18","25:11:1:86:1:18","25:12:1:86:1:18"],25,28,26,4,0,140],[["86:15:1:25:28:26","86:16:1:25:28:26","86:17:1:25:28:26","86:18:1:25:28:26","86:19:1:25:28:26"],86,1,18,6,0,139],[["26:6:1:93:30:1","26:11:1:93:30:1"],26,15,68,8,0,142],[["93:9:1:26:15:68","93:10:1:26:15:68"],93,30,1,2,0,141],[["26:16:2:113:1:20"],26,26,66,4,0,144],[["113:3:1:26:26:66"],113,1,20,6,2,143],[["26:17:14:27:13:18"],26,16,2,0,0,146],[["27:2:1:26:16:2"],27,13,18,8,2,145],[["28:77:1:117:48:52","28:78:1:117:48:52","28:79:1:117:48:52"],28,1,14,6,0,148],[["117:3:1:28:1:14","117:4:1:28:1:14","117:5:1:28:1:14"],117,48,52,0,0,147],[["30:9:2:92:32:16","30:10:2:92:32:16"],30,5,7,2,0,150],[["92:5:2:30:5:7","92:4:2:30:5:7"],92,32,16,8,0,149],[["30:11:2:95:3:1","30:12:2:95:4:1"],30,36,28,8,0,152],[["95:3:2:30:36:28","95:4:2:30:36:28"],95,3,1,2,0,151],[["30:13:2:102:1:19","30:14:2:102:1:19"],30,68,14,4,0,154],[["102:5:2:30:68:14","102:6:2:30:68:14"],102,1,19,6,0,153],[["31:3:2:32:18:26"],31,30,37,8,2,156],[["32:6:2:31:30:37"],32,18,26,8,2,155],[["31:30:1:107:16:43","31:29:1:107:16:43","31:31:1:107:16:43"],31,50,1,2,0,158],[["107:3:1:31:50:1","107:2:1:31:50:1","107:4:1:31:50:1"],107,16,43,8,0,157],[["31:32:1:146:20:19"],31,1,67,6,0,160],[["146:2:1:31:1:67"],146,20,19,4,0,159],[["31:27:2:105:19:9","31:26:2:105:19:9","31:28:2:105:19:9"],31,7,15,8,0,162],[["105:5:1:31:7:15","105:4:1:31:7:15","105:6:1:31:7:15"],105,19,9,2,2,161],[["31:33:1:108:1:33","31:35:1:108:1:33","31:36:1:108:1:33"],31,98,56,4,0,164],[["108:3:1:31:98:56","108:2:1:31:98:56","108:4:1:31:98:56"],108,1,33,6,0,163],[["32:10:12:111:15:20"],32,17,4,0,0,166],[["111:2:1:32:17:4"],111,15,20,0,2,165],[["33:13:6:184:12:7"],33,35,93,8,0,168],[["184:2:1:33:35:93"],184,12,7,8,2,167],[["33:16:1:58:1:28","33:15:1:58:1:28","33:17:1:58:1:28"],33,68,93,0,0,170],[["58:6:1:33:68:93","58:5:1:33:68:93","58:7:1:33:68:93"],58,1,28,0,0,169],[["33:19:1:37:63:56"],33,1,89,6,0,172],[["37:12:1:33:1:89"],37,63,56,0,0,171],[["34:96:1:62:24:30","34:110:1:62:24:30","34:111:1:62:24:30","34:112:1:62:24:30","34:113:1:62:24:30"],34,27,28,0,0,174],[["62:33:1:34:27:28","62:34:1:34:27:28","62:32:1:34:27:28","62:35:1:34:27:28","62:36:1:34:27:28"],62,24,30,8,0,173],[["34:170:1:61:6:44"],34,7,9,8,0,176],[["61:25:1:34:7:9"],61,6,44,2,0,175],[["35:7:1:36:11:33"],35,3,1,2,0,178],[["36:6:1:35:3:1"],36,11,33,8,0,177],[["35:69:1:104:14:28","35:68:1:104:14:28"],35,57,1,2,0,180],[["104:3:1:35:57:1","104:4:1:35:57:1"],104,14,28,8,0,179],[["37:21:1:63:44:4"],37,30,5,2,0,183],[["37:20:1:63:18:53"],37,12,38,2,0,184],[["63:16:1:37:30:5"],63,44,4,2,0,181],[["63:17:1:37:12:38"],63,18,53,8,0,182],[["37:24:1:65:21:1","37:22:1:65:21:1","37:23:1:65:21:1"],37,4,63,0,0,186],[["65:49:1:37:4:63","65:47:1:37:4:63","65:48:1:37:4:63"],65,21,1,2,0,185],[["37:27:1:64:1:14","37:25:1:64:1:14","37:28:1:64:1:14","37:26:1:64:1:14"],37,63,16,0,0,188],[["64:4:1:37:63:16","64:5:1:37:63:16","64:3:1:37:63:16","64:6:1:37:63:16"],64,1,14,6,0,187],[["38:7:1:64:22:1","38:5:1:64:22:1","38:6:1:64:22:1"],38,62,39,0,0,190],[["64:8:1:38:62:39","64:7:1:38:62:39","64:9:1:38:62:39"],64,22,1,2,0,189],[["38:8:1:72:10:1","38:9:1:72:9:1"],38,27,39,8,0,192],[["72:3:1:38:27:39","72:2:1:38:26:39"],72,10,1,2,0,191],[["38:11:1:73:38:17","38:10:1:73:38:17"],38,1,17,6,0,194],[["73:3:1:38:1:17","73:2:1:38:1:17"],73,38,17,4,0,193],[["38:13:1:71:17:38","38:12:1:71:17:38"],38,72,1,2,0,196],[["71:3:1:38:72:1","71:2:1:38:72:1"],71,17,38,8,0,195],[["39:104:1:71:69:1","39:105:1:71:69:1","39:106:1:71:69:1"],39,40,43,8,0,198],[["71:4:1:39:40:43","71:6:1:39:40:43","71:5:1:39:40:43"],71,69,1,2,0,197],[["41:4:1:73:6:1","41:3:1:73:6:1","41:5:1:73:6:1"],41,15,35,8,0,200],[["73:5:1:41:15:35","73:6:1:41:15:35","73:7:1:41:15:35"],73,6,1,2,0,199],[["42:10:1:82:38:14","42:11:1:82:38:14"],42,1,10,6,0,203],[["42:9:1:82:38:32","42:8:1:82:38:32"],42,1,29,6,0,204],[["82:6:1:42:1:10","82:7:1:42:1:10"],82,38,14,4,0,201],[["82:5:1:42:1:29","82:4:1:42:1:29"],82,38,32,4,0,202],[["42:12:1:115:11:19"],42,19,1,2,0,206],[["115:3:1:42:19:1"],115,11,19,8,0,205],[["42:14:1:84:6:28","42:13:1:84:6:28"],42,49,1,2,0,208],[["84:4:1:42:49:1","84:3:1:42:49:1"],84,6,28,8,0,207],[["43:2:1:160:36:1"],43,15,43,0,0,210],[["160:6:1:43:15:43"],160,36,1,0,0,209],[["44:5:1:161:120:1","44:3:1:161:120:1","44:4:1:161:120:1","44:6:1:161:120:1"],44,11,23,0,0,213],[["44:10:1:161:70:2"],44,1,3,6,0,214],[["161:106:1:44:11:23","161:105:1:44:11:23","161:104:1:44:11:23","161:107:1:44:11:23"],161,120,1,0,0,211],[["161:2:1:44:1:3"],161,70,2,0,0,212],[["44:21:7:65:3:100"],44,24,3,2,2,216],[["65:2:6:44:24:3"],65,3,100,2,2,215],[["45:8:3:161:1:147","45:7:3:161:1:147"],45,38,45,0,0,218],[["161:111:1:45:38:45","161:101:1:45:38:45"],161,1,147,0,0,217],[["46:3:1:57:14:88"],46,14,4,2,0,220],[["57:20:42:46:14:4"],57,14,88,8,0,219],[["47:2:4:55:33:10"],47,6,3,0,0,222],[["55:11:1:47:6:3"],55,33,10,0,2,221],[["47:3:1:126:1:10","47:4:1:126:1:10","47:5:1:126:1:10","47:6:1:126:1:10"],47,21,45,4,0,224],[["126:10:1:47:21:45","126:9:1:47:21:45","126:8:1:47:21:45","126:7:1:47:21:45"],126,1,10,6,0,223],[["48:2:1:101:21:12"],48,14,178,0,0,226],[["101:6:11:48:14:178"],101,21,12,0,0,225],[["49:55:1:178:22:35"],49,22,3,2,0,228],[["178:2:1:49:22:3"],178,22,35,8,0,227],[["51:3:13:53:23:78"],51,23,59,2,0,230],[["53:14:1:51:23:59"],53,23,78,8,0,229],[["51:20:11:54:10:19"],51,38,30,0,0,232],[["54:3:1:51:38:30"],54,10,19,0,0,231],[["53:33:3:55:13:96"],53,8,25,0,0,234],[["55:9:1:53:8:25"],55,13,96,0,0,233],[["53:45:20:132:30:36"],53,48,24,0,0,236],[["132:3:1:53:48:24"],132,30,36,8,0,235],[["53:50:10:53:51:25"],53,23,38,8,0,238],[["53:51:5:53:23:38"],53,51,25,8,0,237],[["53:55:10:53:24:21"],53,15,38,8,0,240],[["53:69:5:53:15:38"],53,24,21,8,0,239],[["57:14:13:177:12:78"],57,14,35,0,0,242],[["177:3:1:57:14:35"],177,12,78,0,0,241],[["57:61:7:169:8:11"],57,4,79,2,2,244],[["169:10:7:57:4:79"],169,8,11,2,2,243],[["57:102:1:260:1:8","57:103:1:260:1:8"],57,30,53,4,0,246],[["260:7:1:57:30:53","260:12:1:57:30:53"],260,1,8,6,0,245],[["57:105:1:275:38:8","57:104:1:275:38:8"],57,1,53,6,0,248],[["275:6:1:57:1:53","275:5:1:57:1:53"],275,38,8,4,0,247],[["60:6:1:170:35:16","60:5:1:170:35:16","60:7:1:170:35:16"],60,19,1,0,0,250],[["170:13:1:60:19:1","170:11:1:60:19:1","170:12:1:60:19:1"],170,35,16,0,0,249],[["71:7:3:74:12:28","71:8:3:74:12:28"],71,4,1,2,0,252],[["74:2:1:71:4:1","74:3:1:71:4:1"],74,12,28,8,0,251],[["71:8:7:87:15:28","71:7:7:87:15:28","71:9:7:87:15:28"],71,4,1,2,0,254],[["87:4:1:71:4:1","87:3:1:71:4:1","87:5:1:71:4:1"],87,15,28,8,0,253],[["74:13:6:74:12:13","74:13:5:74:12:13"],74,12,13,8,2,255],[["75:13:1:76:1:7"],75,21,15,4,0,258],[["75:11:1:76:1:28"],75,21,33,4,0,259],[["76:3:1:75:21:15"],76,1,7,6,0,256],[["76:4:1:75:21:33"],76,1,28,6,0,257],[["75:12:2:77:18:37"],75,11,33,6,0,263],[["75:14:1:77:18:20"],75,11,23,6,0,264],[["75:15:1:77:18:5"],75,11,12,6,0,265],[["77:9:1:75:11:33"],77,18,37,4,0,260],[["77:8:1:75:11:23"],77,18,20,4,0,261],[["77:10:1:75:11:12"],77,18,5,4,0,262],[["76:83:1:200:1:12"],76,21,16,0,0,267],[["200:4:1:76:21:16"],200,1,12,0,0,266],[["77:2:1:78:5:33","77:4:1:78:4:33"],77,7,3,2,0,269],[["78:5:1:77:7:3","78:6:1:77:6:3"],78,5,33,8,0,268],[["77:7:1:81:2:1","77:6:1:81:3:1"],77,6,6,0,0,271],[["81:7:1:77:6:6","81:6:1:77:7:6"],81,2,1,2,0,270],[["78:7:1:79:11:33"],78,23,28,4,0,274],[["78:8:1:79:11:18"],78,23,8,4,0,275],[["79:3:1:78:23:28"],79,11,33,6,0,272],[["79:4:1:78:23:8"],79,11,18,6,0,273],[["81:8:6:82:12:1"],81,23,9,2,0,277],[["82:3:1:81:23:9"],82,12,1,8,0,276],[["82:8:1:83:3:3"],82,3,26,2,0,279],[["83:6:2:82:3:26"],83,3,3,2,0,278],[["83:4:1:84:54:28","83:3:1:84:54:28","83:5:1:84:54:28"],83,40,1,2,0,281],[["84:7:1:83:40:1","84:5:1:83:40:1","84:8:1:83:40:1"],84,54,28,8,0,280],[["86:5:1:91:8:14"],86,30,13,2,0,284],[["86:6:1:91:44:14"],86,58,13,2,0,285],[["91:4:1:86:30:13"],91,8,14,8,0,282],[["91:5:1:86:58:13"],91,44,14,8,0,283],[["86:7:3:129:34:89"],86,60,73,2,0,287],[["129:6:1:86:60:73"],129,34,89,8,0,286],[["86:9:1:93:1:46","86:8:1:93:1:46","86:10:1:93:1:46","86:11:1:93:1:46","86:12:1:93:1:46"],86,68,45,4,0,289],[["93:4:1:86:68:45","93:3:1:86:68:45","93:5:1:86:68:45","93:6:1:86:68:45","93:7:1:86:68:45"],93,1,46,6,0,288],[["87:13:1:88:28:15","87:12:1:88:28:15","87:14:1:88:28:15"],87,1,15,6,0,291],[["88:4:1:87:1:15","88:3:1:87:1:15","88:5:1:87:1:15"],88,28,15,4,0,290],[["88:12:1:89:15:1","88:13:1:89:15:1","88:14:1:89:15:1"],88,15,28,8,0,293],[["89:4:1:88:15:28","89:3:1:88:15:28","89:5:1:88:15:28"],89,15,1,2,0,292],[["89:13:1:90:1:15","89:12:1:90:1:15","89:14:1:90:1:15"],89,28,15,4,0,295],[["90:3:1:89:28:15","90:4:1:89:28:15","90:5:1:89:28:15"],90,1,15,6,0,294],[["91:6:1:92:7:18"],91,11,7,2,0,297],[["92:3:1:91:11:7"],92,7,18,8,0,296],[["93:8:1:94:10:18"],93,25,44,2,0,299],[["94:3:1:93:25:44"],94,10,18,8,0,298],[["93:9:1:201:15:68","93:10:1:201:15:68"],93,30,1,2,0,301],[["201:5:1:93:30:1","201:3:1:93:30:1"],201,15,68,8,0,300],[["95:5:1:105:16:32","95:6:1:105:16:32"],95,36,25,2,0,303],[["105:3:1:95:36:25","105:2:1:95:36:25"],105,16,32,8,0,302],[["95:7:1:103:27:28","95:8:1:103:27:28","95:9:1:103:27:28"],95,27,18,2,0,305],[["103:26:2:95:27:18","103:28:2:95:27:18","103:27:2:95:27:18"],103,27,28,8,0,304],[["95:32:1:95:10:10"],95,42,11,8,2,307],[["95:36:11:95:42:11"],95,10,10,2,0,306],[["96:3:2:102:33:20","96:2:2:102:33:20","96:4:2:102:33:20"],96,1,16,6,0,310],[["96:5:1:102:8:1"],96,42,38,8,0,311],[["102:8:2:96:1:16","102:9:2:96:1:16","102:7:2:96:1:16"],102,33,20,4,0,308],[["102:10:2:96:42:38"],102,8,1,2,0,309],[["100:8:1:101:31:36"],100,20,9,2,1,313],[["101:18:5:100:20:9"],101,31,36,6,1,312],[["101:13:1:152:6:7"],101,15,40,0,0,315],[["152:30:1:101:15:40"],152,6,7,2,0,314],[["102:11:2:106:12:21"],102,19,10,2,0,317],[["106:2:1:102:19:10"],106,12,21,8,0,316],[["102:2:2:103:68:28","102:3:2:103:68:28","102:4:2:103:68:28"],102,17,22,2,0,319],[["103:29:2:102:17:22","103:30:2:102:17:22","103:31:2:102:17:22"],103,68,28,8,0,318],[["107:22:2:304:15:44"],107,39,31,8,2,321],[["304:5:2:107:39:31"],304,15,44,8,2,320],[["108:6:1:109:15:68","108:5:1:109:15:68","108:7:1:109:15:68"],108,41,1,2,0,323],[["109:5:1:108:41:1","109:4:1:108:41:1","109:6:1:108:41:1"],109,15,68,8,0,322],[["108:6:1:180:15:68","108:5:1:180:15:68","108:7:1:180:15:68"],108,41,1,2,0,325],[["180:6:1:108:41:1","180:4:1:108:41:1","180:5:1:108:41:1"],180,15,68,8,0,324],[["113:9:2:252:3:5"],113,29,20,4,0,327],[["252:2:2:113:29:20"],252,3,5,2,0,326],[["117:6:1:118:33:9"],117,1,58,6,0,329],[["118:4:1:117:1:58"],118,33,9,4,0,328],[["118:3:2:119:25:48"],118,17,5,0,2,331],[["119:5:2:118:17:5"],119,25,48,8,2,330],[["118:9:1:123:28:12"],118,1,19,0,0,334],[["118:5:1:123:28:22"],118,1,29,0,0,335],[["123:4:1:118:1:19"],123,28,12,0,0,332],[["123:5:1:118:1:29"],123,28,22,0,0,333],[["118:6:1:124:56:4"],118,1,4,0,0,337],[["124:4:1:118:1:4"],124,56,4,0,0,336],[["118:7:1:120:29:13"],118,1,9,0,0,339],[["120:4:1:118:1:9"],120,29,13,0,0,338],[["118:8:1:122:29:12"],118,1,14,0,0,341],[["122:3:1:118:1:14"],122,29,12,0,0,340],[["118:91:2:140:11:18"],118,5,1,0,2,343],[["140:3:2:118:5:1"],140,11,18,0,2,342],[["123:6:1:124:56:11"],123,1,12,0,0,345],[["124:3:1:123:1:12"],124,56,11,0,0,344],[["124:5:2:125:14:22"],124,12,15,0,2,347],[["125:3:2:124:12:15"],125,14,22,8,2,346],[["126:11:1:127:1:14","126:12:1:127:1:14","126:13:1:127:1:14"],126,108,12,4,0,349],[["127:2:1:126:108:12","127:3:1:126:108:12","127:4:1:126:108:12"],127,1,14,6,0,348],[["126:52:1:182:28:10"],126,46,4,6,0,352],[["126:57:1:182:15:10"],126,37,4,4,0,353],[["182:4:1:126:46:4"],182,28,10,4,0,350],[["182:6:1:126:37:4"],182,15,10,6,0,351],[["127:6:1:128:1:5","127:5:1:128:1:5","127:7:1:128:1:5"],127,40,14,4,0,355],[["128:2:1:127:40:14","128:4:1:127:40:14","128:3:1:127:40:14"],128,1,5,6,0,354],[["127:9:1:133:14:23"],127,26,13,2,0,357],[["133:2:1:127:26:13"],133,14,23,8,0,356],[["128:5:4:129:32:11"],128,22,5,2,0,359],[["129:5:1:128:22:5"],129,32,11,0,2,358],[["134:15:1:148:35:3","134:16:1:148:34:3"],134,16,38,0,0,361],[["148:10:1:134:16:38","148:11:1:134:15:38"],148,35,3,0,0,360],[["135:13:1:145:63:9","135:14:1:145:63:9","135:15:1:145:63:9"],135,1,27,0,0,363],[["145:2:1:135:1:27","145:4:1:135:1:27","145:5:1:135:1:27"],145,63,9,0,0,362],[["135:17:1:148:1:28","135:16:1:148:1:28","135:18:1:148:1:28"],135,28,27,0,0,366],[["135:19:1:148:1:8","135:20:1:148:1:8","135:23:1:148:1:8"],135,28,15,0,0,367],[["148:3:1:135:28:27","148:4:1:135:28:27","148:6:1:135:28:27"],148,1,28,0,0,364],[["148:7:1:135:28:15","148:8:1:135:28:15","148:9:1:135:28:15"],148,1,8,0,0,365],[["135:27:1:144:28:4","135:26:1:144:28:4","135:25:1:144:28:4","135:24:1:144:28:4"],135,1,15,0,0,369],[["144:5:1:135:1:15","144:6:1:135:1:15","144:4:1:135:1:15","144:7:1:135:1:15"],144,28,4,0,0,368],[["135:30:1:143:12:14","135:29:1:143:12:14","135:31:1:143:12:14"],135,14,4,0,0,371],[["143:4:1:135:14:4","143:3:1:135:14:4","143:5:1:135:14:4"],143,12,14,0,0,370],[["138:2:1:148:13:26"],138,14,28,0,0,373],[["148:12:1:138:14:28"],148,13,26,0,0,372],[["139:10:1:141:12:35"],139,38,125,8,2,375],[["141:3:2:139:38:125"],141,12,35,8,2,374],[["141:4:1:196:12:18"],141,12,1,2,0,377],[["196:2:1:141:12:1"],196,12,18,8,0,376],[["142:3:1:143:32:23"],142,12,1,0,0,379],[["143:2:1:142:12:1"],143,32,23,0,0,378],[["144:3:1:145:33:3"],144,14,28,0,2,381],[["145:6:3:144:14:28"],145,33,3,0,0,380],[["144:10:1:147:68:52","144:9:1:147:68:52","144:11:1:147:68:52"],144,1,12,0,0,383],[["147:28:1:144:1:12","147:27:1:144:1:12","147:29:1:144:1:12"],147,68,52,0,0,382],[["147:60:5:183:9:9"],147,53,40,8,2,385],[["183:10:50:147:53:40"],183,9,9,6,2,384],[["149:2:1:155:30:5"],149,14,31,8,0,387],[["155:67:1:149:14:31"],155,30,5,0,0,386],[["149:3:11:156:31:63"],149,13,13,0,2,389],[["156:28:2:149:13:13"],156,31,63,0,1,388],[["152:32:1:181:23:20","152:31:1:181:23:20"],152,1,14,0,0,391],[["181:5:1:152:1:14","181:4:1:152:1:14"],181,23,20,0,0,390],[["152:75:1:198:6:4"],152,3,16,0,0,393],[["198:2:1:152:3:16"],198,6,4,2,0,392],[["152:37:11:202:31:10"],152,50,14,2,1,395],[["202:6:12:152:50:14"],202,31,10,2,1,394],[["154:2:1:155:54:9"],154,15,40,0,0,398],[["154:5:15:155:31:3"],154,21,21,2,0,399],[["155:6:1:154:15:40"],155,54,9,0,0,396],[["155:66:11:154:21:21"],155,31,3,0,0,397],[["155:8:17:155:99:16"],155,60,23,2,0,401],[["155:9:1:155:60:23"],155,99,16,0,2,400],[["157:3:1:158:32:38"],157,37,7,0,2,403],[["158:3:3:157:37:7"],158,32,38,0,0,402],[["158:4:1:159:52:14"],158,9,43,0,0,405],[["159:5:1:158:9:43"],159,52,14,0,0,404],[["158:5:1:160:41:28"],158,23,1,0,0,407],[["160:5:1:158:23:1"],160,41,28,0,0,406],[["159:4:2:160:14:28"],159,41,14,0,0,409],[["160:3:1:159:41:14"],160,14,28,0,0,408],[["161:108:1:162:1:24","161:109:1:162:1:24","161:110:1:162:1:24"],161,138,141,0,0,411],[["162:3:1:161:138:141","162:4:1:161:138:141","162:5:1:161:138:141"],162,1,24,0,0,410],[["165:13:1:168:8:48","165:12:1:168:7:48"],165,3,3,0,0,413],[["168:10:2:165:3:3","168:11:2:165:3:3"],168,8,48,0,0,412],[["165:15:1:173:12:15"],165,7,8,2,0,415],[["173:2:1:165:7:8"],173,12,15,0,0,414],[["165:16:1:174:12:18"],165,31,8,0,0,417],[["174:2:1:165:31:8"],174,12,18,0,0,416],[["165:37:2:202:18:21"],165,35,3,2,1,419],[["202:13:2:165:35:3"],202,18,21,0,1,418],[["167:2:1:168:19:11","167:3:1:168:18:11"],167,6,6,0,0,421],[["168:9:2:167:6:6","168:8:2:167:6:6"],168,18,11,0,0,420],[["168:7:2:170:20:28","168:2:2:170:20:28"],168,38,8,0,0,423],[["170:8:1:168:38:8","170:9:1:168:38:8"],170,20,28,0,0,422],[["168:12:2:169:10:18"],168,29,8,0,0,425],[["169:5:1:168:29:8"],169,10,18,0,0,424],[["178:4:1:273:24:34","178:3:1:273:24:34","178:5:1:273:24:34"],178,21,12,2,0,427],[["273:3:1:178:21:12","273:2:1:178:21:12","273:4:1:178:21:12"],273,24,34,8,0,426],[["182:8:1:311:14:23"],182,15,9,2,0,429],[["311:2:1:182:15:9"],311,14,23,8,0,428],[["194:2:1:273:15:8"],194,13,34,8,0,431],[["273:5:1:194:13:34"],273,15,8,2,0,430],[["196:3:11:197:11:48"],196,16,3,2,0,433],[["197:2:1:196:16:3"],197,11,48,0,0,432],[["198:18:1:215:6:4"],198,6,20,0,0,435],[["215:2:1:198:6:20"],215,6,4,0,0,434],[["260:13:6:274:12:15"],260,18,25,2,0,438],[["260:13:11:274:12:15"],260,18,25,2,2,439],[["274:3:1:260:18:25"],274,12,15,8,0,436],[["274:4:278:260:18:25"],274,12,15,8,0,437],[["275:7:1:276:15:18","275:8:1:276:14:18"],275,6,6,2,0,441],[["276:16:1:275:6:6","276:17:1:275:5:6"],276,15,18,8,0,440],[["310:21:1:312:9:8"],310,7,23,8,0,443],[["312:11:13:310:7:23"],312,9,8,2,0,442],[["312:12:15:323:9:18"],312,4,35,2,0,445],[["323:13:1:312:4:35"],323,9,18,8,0,444],[["312:20:2:317:10:9"],312,38,10,2,2,447],[["317:3:15:312:38:10"],317,10,9,2,0,446],[["312:23:1:316:8:18","312:21:1:316:8:18","312:22:1:316:8:18"],312,50,32,2,0,449],[["316:5:1:312:50:32","316:4:1:312:50:32","316:2:1:312:50:32"],316,8,18,8,0,448],[["312:46:1:328:12:88","312:45:1:328:11:88"],312,24,1,2,0,451],[["328:20:1:312:24:1","328:21:1:312:23:1"],328,12,88,8,0,450],[["313:7:14:314:11:7"],313,57,5,2,0,453],[["314:33:1:313:57:5"],314,11,7,2,0,452],[["316:8:1:319:10:20","316:7:1:319:10:20","316:9:1:319:10:20"],316,8,6,2,0,455],[["319:4:1:316:8:6","319:2:1:316:8:6","319:3:1:316:8:6"],319,10,20,8,0,454],[["316:13:2:317:10:9"],316,27,9,2,2,457],[["317:3:20:316:27:9"],317,10,9,2,0,456],[["316:14:14:318:50:18"],316,47,9,2,0,460],[["316:15:14:318:10:18"],316,33,9,2,0,461],[["318:7:1:316:47:9"],318,50,18,8,0,458],[["318:6:1:316:33:9"],318,10,18,8,0,459],[["317:3:25:319:36:9"],317,10,9,2,0,463],[["319:10:2:317:10:9"],319,36,9,2,2,462],[["317:3:30:321:25:10"],317,10,9,2,0,465],[["321:19:2:317:10:9"],321,25,10,2,2,464],[["319:5:1:321:12:19","319:7:1:321:12:19","319:6:1:321:12:19"],319,11,5,2,0,467],[["321:13:1:319:11:5","321:15:1:319:11:5","321:14:1:319:11:5"],321,12,19,8,0,466],[["319:14:13:320:11:38"],319,49,9,2,0,470],[["319:15:13:320:43:38"],319,62,9,2,0,471],[["320:23:1:319:49:9"],320,11,38,8,0,468],[["320:22:1:319:62:9"],320,43,38,8,0,469],[["321:3:12:322:16:38"],321,51,10,2,0,473],[["322:13:1:321:51:10"],322,16,38,8,0,472],[["321:31:12:324:10:28"],321,66,10,2,0,475],[["324:3:1:321:66:10"],324,10,28,8,0,474],[["321:24:12:358:11:23"],321,30,10,2,0,477],[["358:4:1:321:30:10"],358,11,23,8,0,476],[["329:128:16:330:33:92"],329,15,10,2,0,479],[["330:4:1:329:15:10"],330,33,92,8,0,478],[["331:10:13:348:52:18"],331,6,6,2,0,481],[["348:7:1:331:6:6"],348,52,18,0,0,480],[["331:14:1:332:1:21","331:11:1:332:1:21","331:15:1:332:1:21","331:16:1:332:1:21"],331,28,10,4,0,483],[["332:5:1:331:28:10","332:4:1:331:28:10","332:6:1:331:28:10","332:7:1:331:28:10"],332,1,21,6,0,482],[["332:9:1:333:1:10","332:8:1:333:1:10","332:10:1:333:1:10","332:11:1:333:1:10","332:12:1:333:1:10"],332,118,22,4,0,485],[["333:85:1:332:118:22","333:84:1:332:118:22","333:81:1:332:118:22","333:82:1:332:118:22","333:83:1:332:118:22"],333,1,10,6,0,484],[["333:88:1:335:11:28","333:87:1:335:11:28","333:89:1:335:11:28"],333,23,1,2,0,487],[["335:5:1:333:23:1","335:3:1:333:23:1","335:4:1:333:23:1"],335,11,28,8,0,486],[["333:91:1:334:9:1","333:90:1:334:9:1"],333,24,23,8,0,489],[["334:4:1:333:24:23","334:5:1:333:24:23"],334,9,1,2,0,488],[["334:10:1:338:1:11"],334,23,31,4,0,491],[["338:3:1:334:23:31"],338,1,11,6,0,490],[["335:6:1:337:12:18","335:7:1:337:12:18"],335,13,1,2,0,493],[["337:4:1:335:13:1","337:3:1:335:13:1"],337,12,18,8,0,492],[["336:10:1:337:12:1","336:9:1:337:12:1","336:11:1:337:12:1","336:18:1:337:12:1","336:17:1:337:12:1"],336,48,498,8,0,495],[["337:7:1:336:48:498","337:6:1:336:48:498","337:8:1:336:48:498","337:11:1:336:48:498","337:12:1:336:48:498"],337,12,1,0,0,494],[["336:29:1:343:19:38","336:25:1:343:19:38","336:27:1:343:19:38","336:26:1:343:19:38"],336,50,1,2,0,497],[["343:13:1:336:50:1","343:10:1:336:50:1","343:11:1:336:50:1","343:12:1:336:50:1"],343,19,38,8,0,496],[["336:32:1:341:10:17"],336,34,200,2,0,499],[["341:4:1:336:34:200"],341,10,17,8,0,498],[["338:9:1:340:7:101"],338,16,5,2,0,501],[["340:4:1:338:16:5"],340,7,101,8,0,500],[["339:7:1:342:22:1","339:6:1:342:22:1","339:5:1:342:22:1","339:8:1:342:22:1"],339,11,18,8,0,503],[["342:11:1:339:11:18","342:10:1:339:11:18","342:8:1:339:11:18","342:9:1:339:11:18"],342,22,1,2,0,502],[["339:12:1:347:14:88","339:9:1:347:14:88","339:10:1:347:14:88","339:11:1:347:14:88"],339,11,1,2,0,505],[["347:56:1:339:11:1","347:51:1:339:11:1","347:52:1:339:11:1","347:53:1:339:11:1"],347,14,88,8,0,504],[["339:13:13:345:6:48"],339,33,10,2,0,507],[["345:6:1:339:33:10"],345,6,48,8,0,506],[["340:5:1:343:2:9"],340,54,10,2,0,509],[["343:6:1:340:54:10"],343,2,9,2,0,508],[["342:4:1:344:28:14","342:3:1:344:28:14"],342,1,76,6,0,511],[["344:6:1:342:1:76","344:7:1:342:1:76"],344,28,14,4,0,510],[["343:9:1:344:1:14","343:7:1:344:1:14","343:8:1:344:1:14"],343,43,9,4,0,513],[["344:4:1:343:43:9","344:3:1:343:43:9","344:5:1:343:43:9"],344,1,14,6,0,512],[["345:25:1:409:33:82"],345,1,19,6,0,515],[["409:21:1:345:1:19"],409,33,82,4,0,514],[["346:11:1:350:16:7"],346,7,48,8,0,517],[["350:10:1:346:7:48"],350,16,7,2,0,516],[["346:14:1:409:2:57"],346,21,11,4,0,519],[["409:23:1:346:21:11"],409,2,57,6,0,518],[["346:17:1:410:30:98"],346,1,22,6,0,521],[["410:3:11:346:1:22"],410,30,98,2,0,520],[["347:21:1:349:33:70","347:22:1:349:33:70","347:23:1:349:33:70","347:24:1:349:33:70"],347,1,49,6,0,524],[["347:25:1:349:33:23","347:26:1:349:33:23","347:27:1:349:33:23"],347,1,25,6,0,525],[["349:7:1:347:1:49","349:8:1:347:1:49","349:10:1:347:1:49","349:9:1:347:1:49"],349,33,70,4,0,522],[["349:5:1:347:1:25","349:3:1:347:1:25","349:6:1:347:1:25"],349,33,23,4,0,523],[["347:29:1:351:12:23","347:28:1:351:12:23","347:30:1:351:12:23"],347,16,1,2,0,527],[["351:4:1:347:16:1","351:3:1:347:16:1","351:5:1:347:16:1"],351,12,23,8,0,526],[["347:99:1:410:33:14","347:97:1:410:33:14","347:98:1:410:33:14"],347,1,17,6,0,529],[["410:7:1:347:1:17","410:8:1:347:1:17","410:6:1:347:1:17"],410,33,14,4,0,528],[["351:6:2:352:12:38"],351,12,2,2,0,531],[["352:3:1:351:12:2"],352,12,38,8,2,530],[["352:4:1:353:23:108"],352,12,5,2,1,533],[["353:59:1:352:12:5"],353,23,108,8,1,532],[["353:56:11:375:9:13"],353,18,52,0,0,535],[["375:6:1:353:18:52"],375,9,13,8,0,534],[["353:61:1:356:1:16","353:60:1:356:1:16","353:62:1:356:1:16","353:63:1:356:1:16"],353,58,26,4,0,537],[["356:8:1:353:58:26","356:7:1:353:58:26","356:5:1:353:58:26","356:6:1:353:58:26"],356,1,16,6,0,536],[["353:55:11:377:9:13"],353,40,57,0,0,539],[["377:2:1:353:40:57"],377,9,13,8,0,538],[["353:70:11:376:9:13"],353,43,33,0,0,541],[["376:2:1:353:43:33"],376,9,13,8,0,540],[["353:71:11:354:9:13"],353,18,43,0,0,543],[["354:2:1:353:18:43"],354,9,13,8,0,542],[["353:72:1:355:9:13"],353,6,45,0,0,545],[["355:3:1:353:6:45"],355,9,13,0,0,544],[["356:26:1:360:1:36","356:27:1:360:1:36","356:28:1:360:1:36"],356,78,23,4,0,547],[["360:13:1:356:78:23","360:14:1:356:78:23","360:15:1:356:78:23"],360,1,36,6,0,546],[["357:20:1:410:4:21"],357,10,30,8,0,549],[["410:12:13:357:10:30"],410,4,21,2,0,548],[["360:17:1:361:20:28"],360,14,21,2,0,551],[["361:9:1:360:14:21"],361,20,28,8,0,550],[["368:4:2:369:6:1"],368,9,19,0,0,553],[["369:9:1:368:9:19"],369,6,1,0,0,552],[["369:11:1:370:1:14"],369,21,15,0,0,555],[["370:14:1:369:21:15"],370,1,14,0,0,554],[["373:2:5:373:21:13","373:2:9:373:21:13","373:2:13:373:21:13","373:2:18:373:21:13"],373,21,13,8,2,556],[["409:29:1:410:33:62","409:31:1:410:33:62","409:30:1:410:33:62"],409,1,40,6,0,558],[["410:66:1:409:1:40","410:10:1:409:1:40","410:9:1:409:1:40"],410,33,62,4,0,557],[["33:64:1:35:11:68"],33,9,2,2,0,560],[["35:5:1:33:9:2"],35,11,68,0,0,559],[["79:5:1:80:15:28","79:7:1:80:15:28","79:6:1:80:15:28"],79,16,8,2,0,562],[["80:4:1:79:16:8","80:6:1:79:16:8","80:5:1:79:16:8"],80,15,28,8,0,561],[["137:2:1:143:12:8","137:4:1:143:12:8","137:3:1:143:12:8"],137,10,31,0,0,564],[["143:7:1:137:10:31","143:6:1:137:10:31","143:8:1:137:10:31"],143,12,8,0,0,563],[["199:2:68:199:22:9"],199,21,11,2,2,566],[["199:2:80:199:21:11"],199,22,9,4,2,565],[["261:15:84:261:29:18","261:15:91:261:29:18"],261,29,18,2,2,567],[["51:30:15:51:16:15"],51,18,12,2,2,569],[["51:31:12:51:18:12"],51,16,15,2,2,568]]

    def self.pair_door_groups(groups, seed_key, result)
        groups = groups.clone
        state = hash_value(seed_key) & 0x7fffffff
        i = groups.length - 1
        while i > 0
            state = (state * 1103515245 + 12345) & 0x7fffffff
            j = state % (i + 1)
            tmp = groups[i]; groups[i] = groups[j]; groups[j] = tmp
            i -= 1
        end
        i = 0
        while i + 1 < groups.length
            a = groups[i]; b = groups[i + 1]
            destination_b = [b[1], b[2], b[3], b[4], b[5]]
            destination_a = [a[1], a[2], a[3], a[4], a[5]]
            a[0].each { |key| result[key] = destination_b }
            b[0].each { |key| result[key] = destination_a }
            i += 2
        end
    end

    def self.global_door_map
        return @global_door_map if @global_door_map
        @global_door_map = {}
        pair_door_groups(DOOR_GROUPS, "door_group_shuffle_global", @global_door_map)
        @global_door_map
    end

    def self.regional_door_map
        return @regional_door_map if @regional_door_map
        @regional_door_map = {}
        groups_by_region = {}
        DOOR_GROUPS.each_with_index do |group, group_id|
            other_id = group[6].to_i
            next if other_id < 0 || other_id >= DOOR_GROUPS.length
            other = DOOR_GROUPS[other_id]
            region_a = region_for_map(group[1])
            region_b = region_for_map(other[1])
            next unless region_a == region_b
            groups_by_region[region_a] ||= []
            groups_by_region[region_a] << group
        end
        groups_by_region.each do |region_id, groups|
            pair_door_groups(groups, "door_group_shuffle_region:" + region_id.to_s, @regional_door_map)
        end
        @regional_door_map
    end

    def self.door_map
        regional_mode? ? regional_door_map : global_door_map
    end

    def self.shuffled_destination(interpreter, params)
        return nil if DOOR_GROUPS.empty?
        door_map[transfer_key(interpreter, params)]
    end

    #--------------------------------------------------------------------
    # ** AP-interception exclusion by event
    #--------------------------------------------------------------------
    AP_INTERCEPTION_EXCLUDED_EVENTS = {
        [101, 5] => true,  # Library Dream weapon upgrade NPC
        [51, 95] => true,  # Crash Chamber Cheshire Cat's Gift NPC -- whichever gift is chosen must always grant vanilla, never intercepted as an AP check (the only AP-tracked gift option, Ring of Life, already has its own real location elsewhere)
    }

    def self.excluded_event?(interpreter)
        key = [map_id(interpreter), interpreter.instance_variable_get(:@event_id)]
        AP_INTERCEPTION_EXCLUDED_EVENTS.key?(key)
    end

    #--------------------------------------------------------------------
    # ** NG+ item preservation
    #----------------------------------------------------------------------
    AP_PROTECTED_FROM_REMOVAL = {
        [101, 11] => ["Train Ticket", "Gate Pass", "Edith's Ring",
                       "Silver Ring of Avarice", "Golden Ring of Avarice"],
    }

    def self.protected_from_removal?(interpreter, kind, id)
        key = [map_id(interpreter), interpreter.instance_variable_get(:@event_id)]
        names = AP_PROTECTED_FROM_REMOVAL[key]
        return false unless names
        names.include?(display_name(kind, id))
    end

    #--------------------------------------------------------------------
    # ** Mist fog wall barriers
    #--------------------------------------------------------------------
    MIST_FOG_WALL_TRIGGERS = {
        [52, 22] => 1101,
        [181, 6] => 1109,
        [58, 8] => 1104, [58, 9] => 1104, [58, 10] => 1104,
        [58, 11] => 1104, [58, 12] => 1104, [58, 13] => 1104,
        [33, 72] => 1105,
        [65, 60] => 1106,
        [85, 2] => 1107,
        [73, 14] => 1103,
        [79, 14] => 1118, [79, 15] => 1118, [79, 16] => 1118,
        [93, 13] => 1112,
        [105, 16] => 1111,
        [108, 9] => 1116, [108, 10] => 1116, [108, 11] => 1116,
        [143, 43] => 1117, [143, 44] => 1117, [143, 42] => 1117,
        [153, 18] => 1110,
        [149, 6] => 1113,
        [158, 9] => 1114,
        [43, 9] => 1115,
        [170, 16] => 1120,
        [40, 11] => 1108,
        [83, 30] => 1119,
        [141, 8] => 1121,
        [127, 28] => 1102, [127, 29] => 1102,
        [328, 23] => 1122,
        [329, 110] => 1123,
        [344, 8] => 1124,
        [350, 4] => 1125,
        [351, 13] => 1126,
        [109, 8] => 1127,
    }

    def self.mist_fog_wall_switch(map_id, event_id)
        MIST_FOG_WALL_TRIGGERS[[map_id, event_id]]
    end

    #--------------------------------------------------------------------
    # ** Mist unlock triggers -- checked on interaction
    #--------------------------------------------------------------------
    MIST_FOG_WALL_INTERACT_TRIGGERS = {
        [52, 22] => ['Mist Crash Chamber', 'Crash Chamber: Mist Crash Chamber'],
        [181, 6] => ['Mist Library Dream', 'LD: Mist Library Dream'],
        [58, 8] => ['Mist Dodgson Bridge', 'LT: Mist Dodgson Bridge'],
        [58, 9] => ['Mist Dodgson Bridge', 'LT: Mist Dodgson Bridge'],
        [58, 10] => ['Mist Dodgson Bridge', 'LT: Mist Dodgson Bridge'],
        [58, 11] => ['Mist Dodgson Bridge', 'LT: Mist Dodgson Bridge'],
        [58, 12] => ['Mist Dodgson Bridge', 'LT: Mist Dodgson Bridge'],
        [58, 13] => ['Mist Dodgson Bridge', 'LT: Mist Dodgson Bridge'],
        [33, 72] => ['Mist Liddell Cemetary', 'LC: Mist Liddell Cemetary'],
        [65, 60] => ['Mist Pond of Bloody Tears', 'PoBT: Mist Pond of Bloody Tears'],
        [85, 2] => ['Mist Mental Ward', 'MW: Mist Mental Ward'],
        [73, 14] => ['Mist Spore Forest', 'SF: Mist Spore Forest'],
        [79, 14] => ["Mist Duchess' Mansion", "Duchess' Mansion: Mist Duchess' Mansion"],
        [79, 15] => ["Mist Duchess' Mansion", "Duchess' Mansion: Mist Duchess' Mansion"],
        [79, 16] => ["Mist Duchess' Mansion", "Duchess' Mansion: Mist Duchess' Mansion"],
        [93, 13] => ['Mist Billingsgate Fish Market', 'Billingsgate Fish Market: Mist Billingsgate Fish Market'],
        [105, 16] => ['Mist Slaughterhouse', 'Slaughterhouse: Mist Slaughterhouse'],
        [108, 9] => ['Mist Riverside', 'CR: Mist Riverside'],
        [108, 10] => ['Mist Riverside', 'CR: Mist Riverside'],
        [108, 11] => ['Mist Riverside', 'CR: Mist Riverside'],
        [143, 43] => ['Mist Red Castle Frissel', 'Red Castle Frissel: Mist Red Castle Frissel'],
        [143, 44] => ['Mist Red Castle Frissel', 'Red Castle Frissel: Mist Red Castle Frissel'],
        [143, 42] => ['Mist Red Castle Frissel', 'Red Castle Frissel: Mist Red Castle Frissel'],
        [153, 18] => ['Mist Upper Lutwidge Town', 'ULT: Mist Upper Lutwidge Town'],
        [149, 6] => ['Mist Ox Ward University', 'Ox Ward University: Mist Ox Ward University'],
        [158, 9] => ['Mist Sick Clock Tower', 'Sick Clock Tower: Mist Sick Clock Tower'],
        [43, 9] => ["Mist Jubjub's Nest", "Jubjub's Nest: Mist Jubjub's Nest"],
        [170, 16] => ['Mist Queensland', 'QL: Mist Queensland'],
        [40, 11] => ['Mist Mushroom Village', 'Mushroom Village: Mist Mushroom Village'],
        [83, 30] => ['Mist Infinite Food', 'Infinite Food: Mist Infinite Food'],
        [141, 8] => ['Mist Deep Sea', 'Deep Sea: Mist Deep Sea'],
        [127, 28] => ['Mist Fuming Forest', 'Fuming Forest: Mist Fuming Forest'],
        [127, 29] => ['Mist Fuming Forest', 'Fuming Forest: Mist Fuming Forest'],
        [328, 23] => ['Mist Crimean Nursing Graveyard', 'Crimean Nursing Graveyard: Mist Crimean Nursing Graveyard'],
        [329, 110] => ['Mist Florence Arena', 'Florence Arena: Mist Florence Arena'],
        [344, 8] => ['Mist Windless Valley', 'Windless Valley: Mist Windless Valley'],
        [350, 4] => ['Mist Black Knight Arena', 'Black Knight Arena: Mist Black Knight Arena'],
        [351, 13] => ['Mist White Castletown', 'White Castletown: Mist White Castletown'],
        [109, 8] => ["Mist Jabberwock's Lair", "Jabberwock's Lair: Mist Jabberwock's Lair"],
    }

    def self.check_mist_fog_wall_interact_trigger(map_id, event_id)
        key = [map_id, event_id]
        return unless MIST_FOG_WALL_INTERACT_TRIGGERS.key?(key)
        item_name, location_name = MIST_FOG_WALL_INTERACT_TRIGGERS[key]
        ArchipelagoLocations.send_check(location_name)
    end

    #--------------------------------------------------------------------
    # ** Covenant NPC access gating
    #--------------------------------------------------------------------
    COVENANT_NPC_TRIGGERS = {
        [101, 9] => 1150,   # Node
        [62, 84] => 1151,   # Bill
        [37, 53] => 1152,   # Dodo
        [22, 3] => 1153,    # Tweedledee
        [22, 4] => 1154,    # Tweedledum
        [74, 6] => 1155,    # Capitellar
        [27, 3] => 1157,    # Mock Turtle
        [125, 10] => 1158,  # Walrus
        [137, 7] => 1159,   # Queen of Hearts
        [156, 25] => 1160,  # Hatta
        [45, 12] => 1161,   # Maid Victoria
        [169, 8] => 1162,   # Best Girl Pricket
        [197, 4] => 1163,   # Kuti
        [133, 5] => 1164,   # Bandersnatch
        [340, 7] => 1165,   # Sho
    }
    COVENANT_BLOCKED_MESSAGE = "She thinks you are too ugly to speak with right now."

    def self.covenant_npc_switch(map_id, event_id)
        COVENANT_NPC_TRIGGERS[[map_id, event_id]]
    end

    #--------------------------------------------------------------------
    # ** Covenant unlock triggers -- checked on interaction
    #--------------------------------------------------------------------
    COVENANT_NPC_INTERACT_TRIGGERS = {
        [101, 9] => ['Covenant: Node', 'LD: Covenant: Node'],
        [62, 84] => ['Covenant: Bill', 'RGC: Covenant: Bill'],
        [37, 53] => ['Covenant: Dodo', 'PoBT: Covenant: Dodo'],
        [22, 3] => ['Covenant: Tweedledee & Tweedledum', 'MW: Covenant: Tweedledee & Tweedledum'],
        [22, 4] => ['Covenant: Tweedledee & Tweedledum', 'MW: Covenant: Tweedledee & Tweedledum'],
        [74, 6] => ['Covenant: Capitellar', 'SF: Covenant:  Caterpillar Shisha'],
        [27, 3] => ['Covenant: Mock Turtle', 'BoG: Covenant: Mock Turtle'],
        [125, 10] => ['Covenant: Walrus', "Oysters' Rotted Sea: Covenant: Walrus"],
        [137, 7] => ['Covenant: Queen of Hearts', 'Garden of the Heart: Covenant: Queen of Hearts'],
        [156, 25] => ['Covenant: Hatta', 'Endless Tea Party: Covenant: Hatta'],
        [45, 12] => ['Covenant: Maid Victoria', 'ASH: Covenant: Maid Victoria'],
        [169, 8] => ['Covenant: Best Girl Prickett', 'QL: Covenant: Best Girl Prickett'],
        [197, 4] => ['Covenant: Kuti', 'Deep Sea: Covenant: Kuti'],
        [133, 5] => ['Covenant: Bandersnatch', 'FF: Covenant: Bandersnatch'],
        [340, 7] => ['Covenant: Sho', 'Windless Valley: Covenant: Sho'],
    }

    def self.check_covenant_npc_interact_trigger(map_id, event_id)
        key = [map_id, event_id]
        return unless COVENANT_NPC_INTERACT_TRIGGERS.key?(key)
        item_name, location_name = COVENANT_NPC_INTERACT_TRIGGERS[key]
        ArchipelagoLocations.send_check(location_name)
    end

    #--------------------------------------------------------------------
    # ** Boss arena maps
    #--------------------------------------------------------------------
    BOSS_ARENA_MAP_IDS = [
        58,   # Dodgson Bridge
        52,   # CC
        181,  # LD
        65,   # PoBT
        85,   # MW
        93,   # BFM
        105,  # SH
        108,  # Riverside
        180,  # Jabberwock's Lair
        137,  # RCF
        153,  # ULT
        158,  # Sick Clock Tower
        43,   # Jubjub's Nest
        170,  # Queensland
        40,   # MV
        83,   # IF
        141,  # Deep Sea
        127,  # FF
        328,  # Crimean Nursing Graveyard
        329,  # Florence's Arena
        344,  # Windless Valley
        350,  # Black Knight's Arena
        351,  # Unicorn/Lion White Castletown
        73,   # Spore Forest
        80,   # DM
        149,  # OWU
    ]

    LOCKED_DOOR_TRANSFER_TRIGGERS = {
        [51, 3] => {location: "Crash Chamber: Entered Rabbit Hole", requires_switch: nil},
        [9, 11] => {location: "OWU: Through Oxward Gate", requires_switch: 390},
        [65, 4] => {location: "PoBT: Door to Elizabeth", requires_switch: nil},
        [6, 3] => {location: "LT: Door to PoF", requires_switch: nil},
    }

    def self.check_locked_door_transfer_trigger(interpreter)
        key = [map_id(interpreter), interpreter.instance_variable_get(:@event_id)]
        entry = LOCKED_DOOR_TRANSFER_TRIGGERS[key]
        return unless entry
        return if entry[:requires_switch] && !(defined?($game_switches) && $game_switches && $game_switches[entry[:requires_switch]])
        ArchipelagoLocations.send_check(entry[:location])
    end

    #--------------------------------------------------------------------
    # ** Locked game-variable-threshold checks
    #----------------------------------------------------------------------
    def self.check_locked_variable_trigger(variable_id, threshold, location_name)
        return unless defined?($game_variables) && $game_variables && $game_variables[variable_id].to_i >= threshold
        ArchipelagoLocations.send_check(location_name)
    end

    #--------------------------------------------------------------------
    # ** Boss soul grants via battle victory
    #----------------------------------------------------------------------
    BOSS_SOUL_TROOP_TRIGGERS = {
        291 => [["Arbiter's Scythe", "ASH: Arbiter's Scythe"]],
        30 => [['Fairy Tale Scrap Two', 'LT: Fairy Tale Scrap Two']],
        31 => [['Fairy Tale Scrap One', 'ULT: Fairy Tale Scrap One']],
        32 => [['Fairy Tale Scrap Three', 'LT: Fairy Tale Scrap Three']],
        174 => [['Soul of the Head-Hunting Beast', 'CC: Soul of the Head-Hunting Beast'], ['Soul of the Dragon Hunter', 'CC: Soul of the Dragon Hunter']],
        175 => [['Soul of Distraction', 'LT: Soul of Distraction']],
        178 => [['Soul of the Pregnant Cake', 'IF: Soul of the Pregnant Cake']],
        179 => [['Soul of the Bellcaller', 'BFM: Soul of the Bellcaller']],
        180 => [['Soul of the Butcher', 'SH: Soul of the Butcher']],
        181 => [['Soul of the Gray Eagle', 'MW: Soul of the Gray Eagle'], ["Edith's Ring", "MW: Edith's Ring"]],
        182 => [['Soul of Conceit', 'CR: Soul of Conceit']],
        183 => [['Soul of Jack', 'ULT: Soul of Jack']],
        185 => [['Soul of the Dean', 'OWU: Soul of the Dean']],
        186 => [
            ['Soul of the Knight of Hearts', 'RCF: Soul of the Knight of Hearts'],
            ['Soul of the Knight of Spades', 'RCF: Soul of the Knight of Spades'],
            ['Soul of the Knight of Clubs', 'RCF: Soul of the Knight of Clubs'],
        ],
        187 => [['Soul of the Bright Star', 'SCT: Soul of the Bright Star']],
        192 => [['Soul of the Old Knight', 'SF: Soul of the Old Knight'], ['Great Sword', 'SF: Great Sword']],
        195 => [["Soul of the Giant's Home", "MV: Soul of the Giant's Home"]],
        214 => [['Soul of the Slave Emperor', 'QL: Soul of the Slave Emperor']],
        218 => [['Soul of the Jubjub', 'SCT: Soul of the Jubjub']],
        220 => [['Soul of the Jabberwock', 'CR: Soul of the Jabberwock']],
        373 => [['Soul of the Jabberwock', 'CR: Soul of the Jabberwock']],
        222 => [['Soul of Queen of Torture Tools', 'PoBT: Soul of Queen of Torture Tools'], ['Sorcery [Meteor Shower]', 'PoBT: Sorcery [Meteor Shower]']],
        216 => [['Soul of the Bandersnatch', 'FF: Soul of the Bandersnatch']],
        331 => [["Soul of the God's Odd Fish", "Ship Graveyard: Soul of the God's Odd Fish"]],
        341 => [['Soul of the Deep Sea Knight', 'DS: Soul of the Deep Sea Knight']],
        544 => [["Soul of the Winterbell's Wind", "White Castletown: Soul of the Winterbell's Wind"]],
        568 => [['Soul of the Wet Nurses', 'Crimean Nursing Graveyard: Soul of the Wet Nurses']],
        569 => [['Soul of Florence', 'Crimean Nursing Graveyard: Soul of Florence']],
        614 => [['Soul of the White Unicorn', 'Winterbell: Soul of the White Unicorn']],
        616 => [['Soul of the White Lion', 'Winterbell: Soul of the White Lion']],
        71 => [['Bloodbite Ring', 'PoBT: Bloodbite Ring']],  # Sadistic Mistress Brownrigg
        60 => [["Sorcerer's Staff", "RGC: Sorcerer's Staff"]],  # Cotton the Witch
        91 => [['Ring of Rebellion', "DM: Ring of Rebellion"]],  # Monster Butler Archibald
        115 => [['Empty Ring', 'BFM: Empty Ring']],  # Hollow Soldier Christie
        126 => [["Resurrectionist's Ring", "SH: Resurrectionist's Ring"]],  # Corpse Thief Hare
        127 => [["Knight's Ring", "SH: Knight's Ring"]],  # Fleeing Knight Jim
        128 => [["Shoeshiner's Ring", "BFM: Shoeshiner's Ring"]],
        159 => [['Sorcery [Requiem]', 'ORS: Sorcery [Requiem]']],
        139 => [['Ring of Goddess', 'CR: Ring of Goddess']],  # Wainwright the Sinful
        152 => [['Dusk Crown Ring', 'MW: Dusk Crown Ring']],  # Dark Doctor Harold
        171 => [["Barber's Ring", "ULT: Barber's Ring"]],  # Barber Todd
        225 => [['Fairy Tale [Bluebeard]', 'PoBT: Fairy Tale [Bluebeard]']],  # Bluebeard
        226 => [['Fairy Tale [Rascal]', 'LD: Fairy Tale [Rascal]']],  # Farthest Beast Rascal
        228 => [['Fairy Tale [The Crab and The Monkey]', 'BFM: Fairy Tale [The Crab and The Monkey]']],  # The Great Monkey-Killing Crab
        229 => [['Fairy Tale [Boy Who Cried Wolf]', 'ULT: Fairy Tale [Boy Who Cried Wolf]']],  # Boy Who Cried Wolf
        230 => [['Fairy Tale [The Dog and The Shadow]', 'CR: Fairy Tale [The Dog and The Shadow]']],  # Greedy Dog
        231 => [['Fairy Tale [The Gigantic Turnip]', 'NF: Fairy Tale [The Gigantic Turnip]']],  # The Gigantic Turnip
        232 => [['Fairy Tale [Mt. Kachi Kachi]', 'FF: Fairy Tale [Mt. Kachi Kachi]']],  # Tanuki of the Crackling Mountain
        233 => [['Fairy Tale [Pooh Bear]', 'QL: Fairy Tale [Pooh Bear]']],  # Winnie the Pooh
        268 => [['Red Shield', 'RCF: Red Shield']],  # Franklin Bollvolt I
        269 => [["Champion's Ring", "RCF: Champion's Ring"]],  # Fist Duelist Byron
        271 => [['Sloppy', 'SH: Sloppy'], ['Squishy', 'SH: Squishy']],  # Acid Practitioner Haigh -- grants both
        272 => [['Poisonbite Ring', 'IF: Poisonbite Ring']],  # Teacup Poisoner Graham
        295 => [['Ring of the Clown Murderer', 'QL: Ring of the Clown Murderer']],  # Killer Clown Gacy
        342 => [["Blackbeard's Ring", "Deep Sea: Blackbeard's Ring"]],  # Blackbeard Edward
        343 => [['Pirate Handgun', 'ORS: Pirate Handgun']],  # Captain Kid
        370 => [['Ring of My Struggle', 'SH: Ring of My Struggle']],  # Repulsive Hindley
        567 => [['Two-Faced Buckler', 'Crimean Nursing Graveyard: Two-Faced Buckler']],  # Mad Devil Hyde
        35 => [["Angel's Ring", "LT: Angel's Ring"]],  # Angel Manufacturer Amelia
        29 => [['Ring of Fear', 'LT: Ring of Fear']],  # Frederick of Fear
        116 => [["Cannibal's Shield", "BoG: Cannibal's Shield"]],  # Cannibal Sawney Bean
        210 => [['Fairy Tale [The Fox and The Grapes]', 'GotH: Fairy Tale [The Fox and The Grapes]']],  # Grape Guardbeast
        5 => [['Butcher Greataxe', 'RH: Butcher Greataxe']],  # Ketch the Executioner
        270 => [['Fairy Tale [Wolf and ××× Young Goats]', 'LC: Fairy Tale [Wolf and ××× Young Goats]']],  # The Seven Little Goats
    }

    def self.grant_boss_souls_for_troop(troop_id)
        pairs = BOSS_SOUL_TROOP_TRIGGERS[troop_id]
        return unless pairs
        pairs.each { |item_name, location_name| ArchipelagoLocations.send_check(location_name) }
    end

    #--------------------------------------------------------------------
    # ** Shop item randomization
    #--------------------------------------------------------------------
    EXCLUDED_SHOP_TRIGGERS = {
        [152, 35] => true,
    }

    def self.shop_excluded?(map_id, event_id)
        EXCLUDED_SHOP_TRIGGERS[[map_id, event_id]] == true
    end

    def self.shop_replacement_pool
        return @shop_replacement_pool if @shop_replacement_pool
        @shop_replacement_pool = []
        [[$data_items, 0, "item"], [$data_weapons, 1, "weapon"], [$data_armors, 2, "armor"]].each do |data, type_code, kind|
            next unless data
            data.each_with_index do |obj, id|
                next if id == 0 || obj.nil?
                next if obj.name.to_s.strip.empty?  # skip blank/ghost database entries
                next if excluded_by_name?(kind, id)
                next if has_ap_location?(kind, id)
                @shop_replacement_pool << [type_code, id]
            end
        end
        @shop_replacement_pool
    end

    def self.shop_entry_original_price(entry)
        type_code, item_id, price_type, price = entry
        return price if price_type == 1
        data = case type_code
               when 0 then $data_items[item_id]
               when 1 then $data_weapons[item_id]
               when 2 then $data_armors[item_id]
               end
        data ? data.price : 0
    end

    SHOP_ENTRY_PROTECTED = {
        [101, 5] => ["Master Key"],
    }

    def self.shop_entry_protected?(entry)
        protected_names = SHOP_ENTRY_PROTECTED[[$ap_current_shop_map_id, $ap_current_shop_event_id]]
        return false unless protected_names
        type_code, item_id = entry[0], entry[1]
        kind = case type_code
               when 0 then "item"
               when 1 then "weapon"
               when 2 then "armor"
               end
        protected_names.include?(display_name(kind, item_id))
    end

    SHOP_ENTRY_FORCED_PRESENT = {
        [101, 5] => ["Master Key"],
    }

    def self.find_item_id_by_name(name)
        $data_items.each_with_index do |item, idx|
            return idx if item && item.name == name
        end
        nil
    end

    def self.inject_forced_shop_entries(map_id, event_id, goods)
        forced_names = SHOP_ENTRY_FORCED_PRESENT[[map_id, event_id]]
        return goods unless forced_names
        present_names = goods.map { |e| display_name("item", e[1]) if e[0] == 0 }.compact
        missing = forced_names - present_names
        return goods if missing.empty?
        injected = missing.map do |name|
            item_id = find_item_id_by_name(name)
            next nil unless item_id
            [0, item_id, 0, $data_items[item_id].price]
        end.compact
        goods + injected
    end

    def self.shuffled_shop_entry(entry)
        return entry if shop_entry_protected?(entry)
        pool = shop_replacement_pool
        return entry if pool.empty?
        type_code, item_id = entry[0], entry[1]
        key = "shop:#{type_code}:#{item_id}"
        replacement = pick(pool, key)
        return entry unless replacement
        new_type, new_id = replacement
        [new_type, new_id, 1, shop_entry_original_price(entry)]
    end
end

module BattleManager
    class << self
        alias bs2ap_process_victory process_victory
        def process_victory
            troop_id = $game_troop.instance_variable_get(:@troop_id) if defined?($game_troop) && $game_troop
            BS2Randomizer.grant_boss_souls_for_troop(troop_id) if troop_id

            if defined?($ap_pending_arena_soul_troop_id) && $ap_pending_arena_soul_troop_id
                BS2Randomizer.grant_boss_souls_for_troop($ap_pending_arena_soul_troop_id)
                $ap_pending_arena_soul_troop_id = nil
            end
            bs2ap_process_victory
        end
    end
end

class Game_Event < Game_Character
    alias bs2ap_event_start start
    def start
        BS2Randomizer.check_mist_fog_wall_interact_trigger($game_map.map_id, @id)
        switch_id = BS2Randomizer.mist_fog_wall_switch($game_map.map_id, @id)
        if switch_id && !$game_switches[switch_id]
            $game_message.add("The fog is too dense to push through here.")
            return
        end
        #------------------------------------------------------------------
        # Covenant unlock
        #------------------------------------------------------------------
        BS2Randomizer.check_covenant_npc_interact_trigger($game_map.map_id, @id)
        covenant_switch_id = BS2Randomizer.covenant_npc_switch($game_map.map_id, @id)
        if covenant_switch_id && !$game_switches[covenant_switch_id]
            $game_message.add(BS2Randomizer::COVENANT_BLOCKED_MESSAGE)
            return
        end
        bs2ap_event_start
    end
end


#==============================================================================
# ** AP location-check dispatch + item receiving
#==============================================================================
module ArchipelagoLocations
    $ap_item_id_to_name = {}
    $ap_location_name_to_id = {}

    def self.log_ap_activity(text)
        File.open(AP_ACTIVITY_LOG_FILE, "a", encoding: "UTF-8") do |f|
            f.puts("[#{Time.now.strftime('%H:%M:%S')}] #{text}")
        end
    rescue => e
        puts "[Archipelago_Combined] Could not write to #{AP_ACTIVITY_LOG_FILE}: #{e.message}"
    end

    $ap_datapackage_ready = false

    def self.request_datapackage!
        $archipelago.client_socket.send([{ cmd: "GetDataPackage", games: [$archipelago_gamename] }].to_json)
    end

    def self.ingest_datapackage(msg)
        game_data = msg["data"]["games"][$archipelago_gamename]
        return unless game_data
        (game_data["item_name_to_id"] || {}).each { |name, id| $ap_item_id_to_name[id] = name }
        $ap_location_name_to_id = game_data["location_name_to_id"] || {}
        $ap_datapackage_ready = true
        puts "[Archipelago_Combined] DataPackage loaded: #{$ap_item_id_to_name.length} items, #{$ap_location_name_to_id.length} locations"
    end

    def self.resolve_location_id(name)
        $ap_location_name_to_id[name]
    end

    def self.resolve_item_name(item_id)
        $ap_item_id_to_name[item_id]
    end

    $ap_checked_locations = {}

    def self.check!(kind, map_id, original_id)
        name = BS2Randomizer.ap_location_name(kind, map_id, original_id)
        return unless name # not a real AP-tracked location (or pool file missing)
        send_check(name)
    end

    def self.send_check(name)
        return if $ap_checked_locations[name] # don't re-send a check we already sent this session
        unless $ap_datapackage_ready

            Thread.new { sleep 0.5; send_check(name) }
            return
        end
        id = resolve_location_id(name)
        unless id
            puts "[Archipelago_Combined] Location '#{name}' not found in DataPackage -- check locations.json for a typo/mismatch."
            return
        end
        $ap_checked_locations[name] = true
        $archipelago.client_socket.send([{ cmd: "LocationChecks", locations: [id] }].to_json)
        ArchipelagoLocations.log_ap_activity("CHECKED: #{name}")
    end


    def self.name_to_db_lookup
        return @name_to_db_lookup if @name_to_db_lookup
        @name_to_db_lookup = {}
        [[$data_items, :item], [$data_weapons, :weapon], [$data_armors, :armor]].each do |data, type|
            next unless data
            data.each_with_index do |obj, id|
                next if id == 0 || obj.nil? || obj.name.to_s.empty?
                @name_to_db_lookup[obj.name.to_s] ||= [type, id] # first match wins on name collisions
            end
        end
        @name_to_db_lookup
    end

    def self.grant_from_name(name)
        # User-defined overrides for special (non-database) AP items take
        # priority.
        if defined?($name_based_receiveditem_methods) && $name_based_receiveditem_methods[name.to_s]
            eval($name_based_receiveditem_methods[name.to_s])
            return true
        end

        type, id = name_to_db_lookup[name.to_s]
        return false unless type
        case type
        when :item   then $game_party.gain_item($data_items[id], 1)
        when :weapon then $game_party.gain_item($data_weapons[id], 1)
        when :armor  then $game_party.gain_item($data_armors[id], 1)
        end
        true
    end
end

#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
class Game_Interpreter
    alias bs2r4_command_201 command_201
    alias bs2r4_command_301 command_301
    alias bs2r4_command_126 command_126
    alias bs2r4_command_127 command_127
    alias bs2r4_command_128 command_128
    alias bs2r4_command_121 command_121
    alias bs2r6_command_117 command_117
    alias bs2r9_command_302 command_302

    #--------------------------------------------------------------------
    # ** Shop item randomization -- excluded shops
    #--------------------------------------------------------------------
    def command_302
        map_id = $game_map ? $game_map.map_id : nil
        $ap_shop_randomization_excluded = BS2Randomizer.shop_excluded?(map_id, @event_id)
        # Captured here (not available at all within Scene_Shop#prepare
        # itself, which runs later from a different context) so
        # shuffled_shop_entry can check per-slot protections below.
        $ap_current_shop_map_id = map_id
        $ap_current_shop_event_id = @event_id
        puts "[Archipelago_Combined][DEBUG] Shop opened: map_id=#{map_id}, event_id=#{@event_id}"
        bs2r9_command_302
    end

    #--------------------------------------------------------------------
    # ** DeathLink -- broadcast on local death
    #--------------------------------------------------------------------
    DEATH_LINK_COMMON_EVENT_ID = 11

    def command_117
        if @params[0] == DEATH_LINK_COMMON_EVENT_ID && $ap_death_link_enabled &&
           $archipelago && $archipelago.client_connect_status == Archipelago::ConnectStatus::CONNECTED
            deathlink_packet = [{
                cmd: "Bounce",
                tags: ["DeathLink"],
                data: {
                    time: Time.now.to_i,
                    source: $archipelago.connect_info["name"],
                    cause: "#{$archipelago.connect_info['name']} died.",
                },
            }].to_json
            $archipelago.client_socket.send(deathlink_packet)
        end
        bs2r6_command_117
    end

end


#------------------------------------------------------------------------
# ** DeathLink -- safe remote-death injection
#--------------------------------------------------------------------------
class Scene_Map < Scene_Base
    alias bs2r11_update update
    def update
        bs2r11_update
        if defined?($ap_pending_deathlinks) && $ap_pending_deathlinks && !$ap_pending_deathlinks.empty? &&
           $game_map && $game_map.interpreter && !$game_map.interpreter.running?
            $ap_pending_deathlinks.pop(true) rescue nil
            $game_map.interpreter.setup($data_common_events[Game_Interpreter::DEATH_LINK_COMMON_EVENT_ID].list)
        end

        (1..10).each do |n|
            BS2Randomizer.check_locked_variable_trigger(11, n, "LD: Progression #{n}")
        end

        prevent_covenant_purge = defined?($ap_prevent_covenant_purge) ? $ap_prevent_covenant_purge : true
        if prevent_covenant_purge && defined?($game_variables) && $game_variables && $game_variables[11].to_i >= 10
            $game_switches[602] = true
        end
    end
end


class Game_Interpreter


    #--------------------------------------------------------------------
    # ** Endings / goal
    #--------------------------------------------------------------------
    ENDING_TRIGGERS = {
        "true_ending" => [
            {map_id: 391, event_id: 2, switch_id: 792},
        ],
        "good_ending" => [
            {map_id: 187, event_id: 6, switch_id: 513},
        ],
        "common_endings" => [
            {map_id: 175, event_id: 6, switch_id: 507},  # A Ending
            {map_id: 175, event_id: 6, switch_id: 509},  # C Ending
            {map_id: 175, event_id: 6, switch_id: 510},  # D Ending
            {map_id: 175, event_id: 6, switch_id: 511},  # E Ending
        ],
        "ending_f" => [
            {map_id: 179, event_id: 3, switch_id: 512},  # F Ending
        ],
    }
    AP_CLIENT_STATUS_GOAL = 30


    ENDING_G_TRIGGER = {map_id: 187, event_id: 6, switch_id: 513}

    def command_121
        trigger = ENDING_G_TRIGGER
        if BS2Randomizer.map_id(self) == trigger[:map_id] &&
           instance_variable_get(:@event_id) == trigger[:event_id] &&
           @params[0] <= trigger[:switch_id] && trigger[:switch_id] <= @params[1] &&
           @params[2] == 0
            ArchipelagoLocations.send_check("Crash Chamber: Ending G Achieved")
        end

        triggers = ENDING_TRIGGERS[$ap_goal] || []
        triggers.each do |trigger|
            next unless BS2Randomizer.map_id(self) == trigger[:map_id]
            next unless instance_variable_get(:@event_id) == trigger[:event_id]
            next unless @params[0] <= trigger[:switch_id] && trigger[:switch_id] <= @params[1]
            next unless @params[2] == 0 # 0 = ON, 1 = OFF
            if $archipelago && $archipelago.client_connect_status == Archipelago::ConnectStatus::CONNECTED
                $archipelago.update_status(AP_CLIENT_STATUS_GOAL)
                $archipelago.say("!release")
            end
        end
        bs2r4_command_121
    end

    def command_201

        BS2Randomizer.check_locked_door_transfer_trigger(self)

        if !BS2Randomizer.intro_map?(self) && BS2Randomizer.enabled?("room_transition_randomization") && @params[0] == 0
            destination = BS2Randomizer.shuffled_destination(self, @params)
            if destination
                original = @params
                @params = [0, destination[0], destination[1], destination[2], destination[3], destination[4]]
                begin
                    return bs2r4_command_201
                ensure
                    @params = original
                end
            end
        end
        bs2r4_command_201
    end

    def command_301
        if !BS2Randomizer.intro_map?(self) && BS2Randomizer.enabled?("enemy_randomization")

            if BS2Randomizer::BOSS_ARENA_MAP_IDS.include?(BS2Randomizer.map_id(self))
                original_id = BS2Randomizer.original_troop_id(self)
                $ap_pending_arena_soul_troop_id =
                    BS2Randomizer::BOSS_SOUL_TROOP_TRIGGERS.key?(original_id) ? original_id : nil
            else
                $ap_pending_arena_soul_troop_id = nil
            end
            troop_id = BS2Randomizer.random_troop(self)
            if troop_id
                original = @params
                @params = [0, troop_id, @params[2], @params[3]]
                begin
                    return bs2r4_command_301
                ensure
                    @params = original
                end
            end
        else
            $ap_pending_arena_soul_troop_id = nil
        end
        bs2r4_command_301
    end


    def command_126
        if BS2Randomizer.protected_from_removal?(self, "item", @params[0])
            value = operate_value(@params[1], @params[2], @params[3])
            return true if value < 0
        end
        excluded = BS2Randomizer.excluded_event?(self)
        $ap_excluded_event_grant = true if excluded
        begin
            if !BS2Randomizer.intro_map?(self) && !BS2Randomizer.never_shuffle_item?(@params[0]) &&
               !BS2Randomizer.protected_bloody_key?(self, @params) &&
               !excluded &&
               !BS2Randomizer.excluded_by_name?("item", @params[0])
                value = operate_value(@params[1], @params[2], @params[3])
                if value > 0
                    name = BS2Randomizer.ap_location_name("item", BS2Randomizer.map_id(self), @params[0].to_i)
                    if name
                        ArchipelagoLocations.send_check(name)
                        vanilla_name = BS2Randomizer.display_name("item", @params[0].to_i)
                        bs2r4_command_126 if ["Drink Me", "Eat Me"].include?(vanilla_name)
                        return true
                    end
                    if BS2Randomizer.region_pool("item", BS2Randomizer.map_id(self)).include?(@params[0].to_i)
                        shuffled = BS2Randomizer.shuffled_non_ap_item_id("item", BS2Randomizer.map_id(self), @params[0].to_i)
                        if shuffled != @params[0].to_i
                            original = @params
                            @params = [shuffled, @params[1], @params[2], @params[3]]
                            begin
                                return bs2r4_command_126
                            ensure
                                @params = original
                            end
                        end
                    end
                    # No AP location and no shuffle target -- fall through to
                    # vanilla grant rather than silently dropping the item.
                end
            end
            bs2r4_command_126
        ensure
            $ap_excluded_event_grant = false if excluded
        end
    end

    def command_127
        if BS2Randomizer.protected_from_removal?(self, "weapon", @params[0])
            value = operate_value(@params[1], @params[2], @params[3])
            return true if value < 0
        end
        excluded = BS2Randomizer.excluded_event?(self)
        $ap_excluded_event_grant = true if excluded
        begin
            if !BS2Randomizer.intro_map?(self) && !excluded && !BS2Randomizer.excluded_by_name?("weapon", @params[0])
                value = operate_value(@params[1], @params[2], @params[3])
                if value > 0
                    name = BS2Randomizer.ap_location_name("weapon", BS2Randomizer.map_id(self), @params[0].to_i)
                    if name
                        ArchipelagoLocations.send_check(name)
                        return true
                    end
                    if BS2Randomizer.region_pool("weapon", BS2Randomizer.map_id(self)).include?(@params[0].to_i)
                        shuffled = BS2Randomizer.shuffled_non_ap_item_id("weapon", BS2Randomizer.map_id(self), @params[0].to_i)
                        if shuffled != @params[0].to_i
                            original = @params
                            @params = [shuffled, @params[1], @params[2], @params[3], @params[4]]
                            begin
                                return bs2r4_command_127
                            ensure
                                @params = original
                            end
                        end
                    end
                end
            end
            bs2r4_command_127
        ensure
            $ap_excluded_event_grant = false if excluded
        end
    end

    def command_128
        if BS2Randomizer.protected_from_removal?(self, "armor", @params[0])
            value = operate_value(@params[1], @params[2], @params[3])
            return true if value < 0
        end
        excluded = BS2Randomizer.excluded_event?(self)
        $ap_excluded_event_grant = true if excluded
        begin
            if !BS2Randomizer.intro_map?(self) && !excluded && !BS2Randomizer.excluded_by_name?("armor", @params[0])
                value = operate_value(@params[1], @params[2], @params[3])
                if value > 0
                    name = BS2Randomizer.ap_location_name("armor", BS2Randomizer.map_id(self), @params[0].to_i)
                    if name
                        ArchipelagoLocations.send_check(name)
                        return true
                    end
                    if BS2Randomizer.region_pool("armor", BS2Randomizer.map_id(self)).include?(@params[0].to_i)
                        shuffled = BS2Randomizer.shuffled_non_ap_item_id("armor", BS2Randomizer.map_id(self), @params[0].to_i)
                        if shuffled != @params[0].to_i
                            original = @params
                            @params = [shuffled, @params[1], @params[2], @params[3], @params[4]]
                            begin
                                return bs2r4_command_128
                            ensure
                                @params = original
                            end
                        end
                    end
                end
            end
            bs2r4_command_128
        ensure
            $ap_excluded_event_grant = false if excluded
        end
    end
end

#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
class Scene_Shop < Scene_MenuBase
    alias bs2r5_prepare prepare
    def prepare(goods, purchase_only)
        kind_name = ->(tc) { case tc; when 0 then "item"; when 1 then "weapon"; when 2 then "armor"; end }
        puts "[Archipelago_Combined][DEBUG] Shop goods BEFORE: " + goods.map { |e| "#{BS2Randomizer.display_name(kind_name.call(e[0]), e[1])} (type=#{e[0]}, id=#{e[1]})" }.join(", ")
        goods = BS2Randomizer.inject_forced_shop_entries($ap_current_shop_map_id, $ap_current_shop_event_id, goods)
        if BS2Randomizer.enabled?("shop_item_randomization") && !$ap_shop_randomization_excluded
            goods = goods.map { |entry| BS2Randomizer.shuffled_shop_entry(entry) }
        end
        puts "[Archipelago_Combined][DEBUG] Shop goods AFTER: " + goods.map { |e| "#{BS2Randomizer.display_name(kind_name.call(e[0]), e[1])} (type=#{e[0]}, id=#{e[1]})" }.join(", ")
        bs2r5_prepare(goods, purchase_only)
    end
end

#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
class Game_Actor < Game_Battler
    alias bs2ap_trade_item_with_party trade_item_with_party
    def trade_item_with_party(new_item, old_item)
        $ap_equip_transfer = true
        begin
            bs2ap_trade_item_with_party(new_item, old_item)
        ensure
            $ap_equip_transfer = false
        end
    end
end

#--------------------------------------------------------------------------
#--------------------------------------------------------------------------
class Game_Party < Game_Unit
    alias bs2ap_gain_item gain_item
    def gain_item(item, amount, include_equip = false)
        if item && amount > 0 && !$ap_giving && !$ap_equip_transfer && !$ap_excluded_event_grant
            kind = case item
                   when RPG::Item   then "item"
                   when RPG::Weapon then "weapon"
                   when RPG::Armor  then "armor"
                   end
            if kind && !BS2Randomizer.excluded_by_name?(kind, item.id) && BS2Randomizer.has_ap_location?(kind, item.id)
                current_map_id = $game_map ? $game_map.map_id : 0
                name = BS2Randomizer.ap_location_name(kind, current_map_id, item.id)
                if name
                    ArchipelagoLocations.send_check(name)
                    return # don't grant locally -- AP will send the real item back
                end
            end
        end
        bs2ap_gain_item(item, amount, include_equip)
    end
end

#==============================================================================
#==============================================================================
    def restart_archipelago

        BS2Randomizer.build_ap_randomized_items!

        $ap_tags = []
        $ap_tags.append("RingLink") if $ringlink_enabled

        $archipelago = Archipelago::Client.new
        $archipelago.connect_info["game"] = $archipelago_gamename
        $archipelago.connect_info["items_handling"] = $archipelago_items_handling
        $archipelago.connect_info["tags"] = $ap_tags

        unhandled_items = Queue.new
        $ap_pending_deathlinks = Queue.new
        $archipelago.add_listener("DataPackage") { |msg| ArchipelagoLocations.ingest_datapackage(msg) }

        $archipelago.add_listener("Connected") do |msg|
            $ap_goal = (msg["slot_data"] || {})["goal"] || "true_ending"
            $ap_death_link_enabled = (msg["slot_data"] || {})["death_link"] == true
            # Defaults to true (matching the YAML option's own default) if
            # somehow missing from slot_data, rather than silently treating
            # an old/incompatible server response as "off".
            slot_data = msg["slot_data"] || {}
            $ap_auto_meet_red_hood = slot_data.key?("auto_meet_red_hood") ? slot_data["auto_meet_red_hood"] == true : true
            $ap_prevent_covenant_purge = slot_data.key?("prevent_covenant_purge") ? slot_data["prevent_covenant_purge"] == true : true
            if $ap_death_link_enabled && !$ap_tags.include?("DeathLink")
                $ap_tags << "DeathLink"
                connect_update_packet = [{
                    cmd: "ConnectUpdate",
                    tags: $ap_tags,
                    items_handling: $archipelago_items_handling,
                }].to_json
                $archipelago.client_socket.send(connect_update_packet)
            end
            ArchipelagoLocations.request_datapackage!
            Thread.new do
                loop do
                    ready = $receive_items_outside_map || SceneManager.scene_is?(Scene_Map)
                    if ready
                        item = unhandled_items.pop(true) rescue nil
                        if item
                            unless $ap_datapackage_ready
                                unhandled_items.push(item)
                                sleep 0.5
                                next
                            end
                            $ap_giving = true
                            begin
                                name = ArchipelagoLocations.resolve_item_name(item)
                                handled = name ? ArchipelagoLocations.grant_from_name(name) : false
                                if handled
                                    ArchipelagoLocations.log_ap_activity("RECEIVED: #{name}")
                                else
                                    ArchipelagoLocations.log_ap_activity("RECEIVED (unhandled): #{name.inspect} (id #{item})")
                                    eval_target = $expanded_receiveditem_methods.fetch(item, "puts \"[Archipelago_Combined] No defined method for ReceivedItem ID #{item}!\"")
                                    eval(eval_target)
                                end
                            ensure
                                $ap_giving = false
                            end
                            sleep 0.1
                        else
                            sleep 0.1
                        end
                    else
                        sleep 0.5
                    end
                    break if $archipelago.client_connect_status == Archipelago::ConnectStatus::DISCONNECTED
                end
            end
        end

        $receiveditems_index = 0
        $archipelago.add_listener("ReceivedItems") do |msg|
            item_counter = msg["index"]
            msg["items"].each do |item|
                if $receiveditems_index <= item_counter
                    unhandled_items.push(item["item"])
                    $receiveditems_index += 1
                end
                item_counter += 1
            end
        end

        $archipelago.add_listener("Bounced") do |msg|
            if $ap_death_link_enabled && msg["tags"] && msg["tags"].include?("DeathLink") &&
               msg["data"] && msg["data"]["source"] != $archipelago.connect_info["name"]
                $ap_pending_deathlinks.push(true)
            end
        end

        if $ringlink_enabled
            $archipelago.add_listener("Bounced") do |msg|
                if msg["tags"].include?("RingLink") and $ringlink_uuid != msg["data"]["source"]
                    $game_party.gain_gold_ringlink((msg["data"]["amount"] * $ringlink_conversion_rate).to_i)
                end
            end
        end
    end

    module Cache
        def self.custom(filename)
            load_bitmap("Custom/Graphics/", filename)
        end
    end

    module DataManager
        def self.make_save_contents
            contents = {}
            contents[:system]        = $game_system
            contents[:timer]         = $game_timer
            contents[:message]       = $game_message
            contents[:switches]      = $game_switches
            contents[:variables]     = $game_variables
            contents[:self_switches] = $game_self_switches
            contents[:actors]        = $game_actors
            contents[:party]         = $game_party
            contents[:troop]         = $game_troop
            contents[:map]           = $game_map
            contents[:player]        = $game_player
            contents[:AP_connect_info] = $archipelago.connect_info if $load_autoconnect
            contents[:AP_receiveditems_index] = $receiveditems_index
            contents[:AP_progressive_counts] = $progressive_counts
            contents[:AP_ringlink_enabled] = $ringlink_enabled
            contents[:AP_ringlink_conversion_rate] = $ringlink_conversion_rate
            contents[:AP_checked_locations] = $ap_checked_locations
            contents
        end

        def self.extract_save_contents(contents)
            $game_system        = contents[:system]
            $game_timer         = contents[:timer]
            $game_message       = contents[:message]
            $game_switches      = contents[:switches]
            $game_variables     = contents[:variables]
            $game_self_switches = contents[:self_switches]
            $game_actors        = contents[:actors]
            $game_party         = contents[:party]
            $game_troop         = contents[:troop]
            $game_map           = contents[:map]
            $game_player        = contents[:player]

            auto_meet_red_hood = defined?($ap_auto_meet_red_hood) ? $ap_auto_meet_red_hood : true
            if auto_meet_red_hood
                $game_switches[14] = true
                $game_variables[9] = [$game_variables[9].to_i, 1].max
                $game_switches[178] = true
            end
            if $load_autoconnect && contents[:AP_connect_info]
                $archipelago.connect_info = contents[:AP_connect_info]
                config_path = File.join(Dir.pwd, "archipelago.json")
                if File.exist?(config_path)
                    config = JSON.parse(File.read(config_path))
                    $archipelago.connect_info["hostname"] = config["hostname"] unless config["hostname"].to_s.empty?
                    $archipelago.connect_info["port"] = config["port"].to_i unless config["port"].to_s.empty?
                end
            end
            $receiveditems_index = contents[:AP_receiveditems_index]
            $progressive_counts = contents[:AP_progressive_counts]
            $ringlink_enabled = contents[:AP_ringlink_enabled]
            $ringlink_conversion_rate = contents[:AP_ringlink_conversion_rate]
            $ap_checked_locations = contents[:AP_checked_locations] if contents[:AP_checked_locations]
        end

        def self.load_game(index)
            load_game_without_rescue(index)
            $archipelago.connect if $load_autoconnect
        rescue
            false
        end

        class << self
            alias bs2r_setup_new_game setup_new_game
            def setup_new_game
                bs2r_setup_new_game
                # New-game counterpart to the extract_save_contents force
                # above -- see the comment there for the full reasoning.
                auto_meet_red_hood = defined?($ap_auto_meet_red_hood) ? $ap_auto_meet_red_hood : true
                if auto_meet_red_hood
                    $game_switches[14] = true
                    $game_variables[9] = [$game_variables[9].to_i, 1].max
                    $game_switches[178] = true
                end
            end
        end
    end

    module Scene_Title_Disconnect
        def start
            $archipelago.disconnect if $archipelago
            restart_archipelago
            super
        end
    end
    Scene_Title.prepend(Scene_Title_Disconnect)

    $ringlink_uuid = rand(0..1000000)
    module RingLink_Methods
        def gain_gold(amount)
            ringlink_packet = [{cmd: "Bounce", tags: ["RingLink"], data: {time: Time.now.to_i, source: $ringlink_uuid, amount: amount * $ringlink_conversion_rate}}].to_json
            $archipelago.client_socket.send(ringlink_packet) if $ringlink_enabled
            super(amount)
        end
        def gain_gold_ringlink(amount)
            @gold = [[@gold + amount, 0].max, max_gold].min
        end
    end
    Game_Party.prepend(RingLink_Methods)
