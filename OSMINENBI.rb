require 'net/telnet'

module OSMINENBI	
	class OSMINEIDEError < StandardError;end
	class InvalidParameterError < OSMINEIDEError;end

	class OSMINEServer
		RL_TIMES = 3
		def initialize ip, port, prompt="Command>"
			@ip, @port, @cmd_prompt = ip, port, prompt

			connect()
		end

		def connect
			@telnet = Net::Telnet.new("Host"=>@ip, "Port"=>@port, "Prompt"=>@cmd_prompt)
			@telnet.waitfor("String"=>@cmd_prompt, "Timeout"=>60) #, "FailEOF"=>true
		end

		def execute cmd_str
			begin 
				if cmd_str == "\n"
					connect()
					return
				else
					ctag = cmd_str.split(":")[3].strip
					ctag = ctag.split(";")[0] if ctag.include?(";")
				end
			rescue =>e
				raise InvalidParameterError, e.to_s
			end

			# if cmd_str =~ /^canc-user/i
			# 	@telnet.print cmd_str
			# 	return
			# end

			rsp = ''
			4.times do |ti|
				@telnet.print("%s\n"%cmd_str.strip)

				rsp.clear
				rsp << get_rsp(ctag)

				if rsp.include? "IP #{ctag}"
					rsp.clear
					rsp << get_rsp(ctag)
				end

				if rsp.include? "RL #{ctag}"
					sleep 8
					next
				end

				unless rsp.empty?
					match = (rsp =~ /\n.*\d{2}-\d{2}-\d{2} \d{2}\:\d{2}\:\d{2}/)
					if match
						rsp = rsp[match, rsp.size-1]
					end				
				end

				break
			end		
			rsp
		end

		def retrieve
			rsp = get_rawrsp()
			re = Regexp.new("%s$" % @cmd_prompt)
			rsp.gsub(re, '').strip
		end

		def exit
			@telnet.close
		end

		private
			def get_rawrsp
				rsp = ''
				#EOFError (the remote end closes the connection ) has not been processed yet. , "FailEOF"=>true
				@telnet.waitfor("String"=>@cmd_prompt, "Timeout"=>60) do |str|
					rsp << str if str
					STDOUT.flush
				end
				rsp
			end

			def get_rsp ctag
				ct1 = " #{ctag} "
				ct2 = " #{ctag}\n"

				res = ''
				2.times do |ts|
					rsp = get_rawrsp()
					rspa = rsp.split(@cmd_prompt)
					mts = rspa.each do |rsps|
						if rsps.include?(ct1) || rsps.include?(ct2)
							break rsps
						end
					end
					if mts.instance_of? String
						res << mts
						break
					end
				end

				res.strip
			end
	end

end