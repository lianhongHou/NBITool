require 'net/telnet'

module Device
	class DeviceCLI
		def initialize ip, port, prompt
			prompt_reg = Regexp.new prompt
			@telnet = Net::Telnet.new("Host"=>ip, "Port"=>port, "Prompt"=>prompt_reg, "FailEOF"=>true)
		end

		def login login_prompt, user, password_prompt, password
			login_reg = Regexp.new login_prompt
			password_reg = Regexp.new password_prompt

			@telnet.login("LoginPrompt"=>login_reg, "Name"=>user, "PasswordPrompt"=>password_reg, "Password"=>password) #{|c| print c}
		end

		def execute cmd_str
			cmd = cmd_str.rstrip
			str = ''
			#block below is for E7-2 who need a "RETURN" to continue after "--MORE--"
			str << @telnet.cmd("String"=>cmd, "Timeout"=>60) do |c| 
				if c =~ /--MORE--/
					@telnet.write "\015"
				end
			end

			str
		end

		def exit
			begin
				@telnet.cmd "exit"
			rescue =>e
				puts e.to_s
			end
			@telnet.close
		end	
	end
end