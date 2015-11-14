
class TestcaseError < StandardError;end
class TestcaseNonexist < TestcaseError;end
class XMLReqNonexist < TestcaseError;end

class CaseExecutor
	# caseFullpath is the full path of test case.
	# execDir is default path used by content of test case, not used by OSMINE
	def initialize caseFullpath, referDir = nil  
		@referDir = referDir
		raise TestcaseNonexist, caseFullpath unless File.exist?(caseFullpath)		
		@content = []
		File.open(caseFullpath, "r") do |file|
			file.each_with_index do |str, number|
				unless str.strip =~ /^#/
					unless str.strip.empty?
						unless str =~ /^wait\|/
							@content << str
						end
					end
				end
			end
		end

		@content
	end

	def exec 
		results = {:final=>"Pass", :detail=>[]}

		curr_dev = ""
		late_rsp = ""
		@content.each_with_index do |line, idx|
			rlst = {}
			sp = line.split "|"
			if (3 == sp.size)
				case sp[0]
				when "send"
					curr_dev.clear
					curr_dev = sp[1]

					resp = yield sp[1], sp[2]
					
					late_rsp = resp #.squeeze

					rlst[:step] = line
					rlst[:response] = resp
					rlst[:result] = "Pass"
				when "expect"
					rlst[:step] = line
					rlst[:response] = ""
					if curr_dev == sp[1]
						#delete redundant space and tailed "\n"
						 if checkreuslt(late_rsp, sp[2]) #late_rsp.include? sp[2].squeeze.rstrip
						 		rlst[:result] = "Pass"
						 else
						 		rlst[:result] = "Failed"
						 end
					else
						if "CMS" == sp[1]
							rlst[:response] << yield("CMS", "RETRIEVE")
							if checkreuslt(rlst[:response], sp[2]) #rlst[:response].squeeze.include? sp[2].squeeze.rstrip
								rlst[:result] = "Pass"
							else
							 	rlst[:result] = "Failed"
							end	
						else
							rlst[:result] = "command is wrong"
						end
					end
				when "unexpect"
					rlst[:step] = line
					rlst[:response] = ""
					if curr_dev == sp[1]
						 unless checkreuslt(late_rsp, sp[2]) #late_rsp.include? sp[2].squeeze.rstrip
						 		rlst[:result] = "Pass"
						 else
						 		rlst[:result] ; "Failed"
						 end
					else
						if "CMS" == sp[1]
							rlst[:response] << yield("CMS", "RETRIEVE")
							unless checkreuslt(rlst[:response], sp[2]) #rlst[:response].squeeze.include? sp[2].squeeze.rstrip
								rlst[:result] = "Pass"
							else
							 	rlst[:result] = "Failed"
							end	
						else
							rlst[:result] = "command is wrong"						
						end
					end
				when "xsend"
					curr_dev.clear
					curr_dev = sp[1]

					fc = ""
					xmlpath = @referDir+"\\"+sp[2].strip
					File.open(xmlpath, "r+") do |f|
						fc = f.read.strip
					end
					resp = yield sp[1], fc

					late_rsp = resp #.squeeze

					rlst[:step] = {:text=>line.strip, :hyperlnk=>xmlpath}
					rlst[:response] = resp
					rlst[:result] = "Pass"					
				when "xpect"
					rspXMLPath = @referDir + "\\#{sp[2].strip}"
					break unless File.exist? rspXMLPath

					rlst[:step] = {:text=>line.strip, :hyperlnk=>rspXMLPath}
					rlst[:response] = ""
					rlst[:result] = "Pass"

					l = late_rsp.split("\n").map {|x| x.strip}
					r = []
					File.open(rspXMLPath, "r+") do |fi|
						r = fi.read.split("\n").map {|x| x.strip}
					end
					i = l.size
					i = r.size if i>r.size
					i.times do |n|
						if l[n] != r[n]
				 			rlst[:result] = "Failed"
				 			break
						end
					end

				else
					rlst[:steps] = line
					rlst[:response] = ""
					rlst[:result] = "command is unknown"					
				end

				results[:detail] << rlst
				unless "Pass" == rlst[:result]
					results[:final] = "Failed"
					return results 
				end
			else
				puts "line #{idx} of test case is wrong"	
			end			
		end
		results
	end

	def checkreuslt rst, exp
		rt = false
		texp = exp.gsub(/\n$/, '')
		if (texp =~ /^\//) && (texp =~ /\/$/)
			re = Regexp.new(texp.split("/")[1])
			rt = true if rst =~ re
		elsif rst.squeeze.include? exp.squeeze.rstrip
			rt = true
		end
		rt
	end
end