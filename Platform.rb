require File.expand_path(File.join(File.dirname(__FILE__), 'Device.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'OSMINENBI.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'XMLNBI.rb'))

class Platform
	DEVICES = {\
		"CMS"=>{:LoginPrompt=>"", :PasswordPrompt=>""}, \
		"E348"=>{:LoginPrompt=>"User name:", :PasswordPrompt=>"Password"}, \
		"E348C"=>{:LoginPrompt=>"Username:", :PasswordPrompt=>"Password:"}, \
		"E312C"=>{:LoginPrompt=>"User name:", :PasswordPrompt=>"Password:"}, \
		"C7"=>{:LoginPrompt=>"", :PasswordPrompt=>""}, \
		"E7"=>{:LoginPrompt=>"Username:", :PasswordPrompt=>"Password:"}, \
		"E5111"=>{:LoginPrompt=>"User name:", :PasswordPrompt=>"Password:"}, \
		"E5120"=>{:LoginPrompt=>"User name:", :PasswordPrompt=>"Password:"}, \
		"E5121"=>{:LoginPrompt=>"User name:", :PasswordPrompt=>"Password:"}, \
		"XMLNBI"=>{}, \
		"C7"=>{}
	}

	def initialize devicetable
		@device = {}
		File.open(devicetable, "r") do |file|
			file.each_with_index do |str, number|
				unless str.strip =~ /^#/
					unless str.strip.empty?
						sp = str.rstrip.split("|")
						if (6 != sp.size) || (not DEVICES.keys.include?(sp[0]))
							raise "wrong configuration in devicetable: #{str}\n"
						else
							name = sp[0]
							ip = sp[1]
							port = sp[2].to_i
							user = sp[3]
							password = sp[4]
							cmdprompt = sp[5]
						end

						begin 
							if "CMS" == name
						  		@device[name] = OSMINENBI::OSMINEServer.new ip, port, cmdprompt
						  	elsif "XMLNBI" == name
						  		@device[name] = XMLNBI::XMLServer.new ip, user, password
						  	elsif "C7" == name
						  		@device[name] = Device::DeviceCLI.new ip, port, cmdprompt
						  		@device[name].execute("ACT-USER::#{user}:asfdf::#{password};")
						  		@device[name].execute("INH-MSG-ALL:::INHMSG::ALL;")
							else
								dev_para = DEVICES[name]
								@device[name] = Device::DeviceCLI.new ip, port, cmdprompt
								unless dev_para[:LoginPrompt].empty?
									@device[name].login dev_para[:LoginPrompt], user, dev_para[:PasswordPrompt], password
								end
							end
						rescue =>e
							puts e.to_s
							puts e.backtrace
							self.exit()
							Process.exit(false)
						end
					end
				end
			end
		end

		# puts @device
	end

	def execute device, cmd_str 
		if @device[device]
			@device[device].execute cmd_str
		else
			"No device #{device} exist, pls check devicetable\n"
		end
	end

	def retrieve device
		if "CMS" == device
			@device[device].retrieve
		end
	end

	def exit
		@device.keys.each do |d|
			@device[d].exit if @device[d]
		end
	end
end