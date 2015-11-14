require File.expand_path(File.join(File.dirname(__FILE__), 'Platform.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'Reportor.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'Log.rb'))
require File.expand_path(File.join(File.dirname(__FILE__), 'Testcase.rb'))

class NBITestsuit
	DriverDir = "\\driver"
	DevicesTableFile = "DevicesTable.txt"

	def initialize execDir, reportdir, cover_items=[]
		@execDir = execDir
		@driverDir = @execDir + DriverDir
		if reportdir =~ /.xlsx$/
			@reportDir = reportdir.split("\\")[0...-1].join("\\")
		else
			@reportDir = reportdir
		end

		devicetable = "#{@execDir}\\#{DevicesTableFile}"
		begin
			@devs = Platform.new(devicetable)
			@logs = Logs.new "%s\\logs.log"%[@reportDir]
			@detail = Report::Detail.new(@reportDir) # detail report share same dir as log file
			# here use parameter 'reportdir' directly so that we can rerun failed testcase when 'reportdir' is a file summary.xlsx
			@summary = Report::Summary.new	reportdir, cover_items  
			@cover = @summary.cover
			@directory = @summary.directory			
		rescue =>e
			puts e.to_s
			puts e.backtrace
			exit
		end
	end

	def run
		dir_traverse(@driverDir, Regexp.new(".txt$")) do |file|
			fn = file.gsub(@driverDir, "").gsub(/^\\/,"")

			res = execute(fn)

			rh = {}
		 	rh[:result] = res[0]
			rh[:testcase] = {:name=>fn, :where=>file}
			rh[:detail] = {:name=>res[1], :where=>".\\#{res[1]}"}
			@directory.append rh
		end
	end

	def rerun_failed
		suc = 0
		fca = @directory.failed_case
		fca.each do |row|
			@directory.highlight(row)

			tia = @directory.get_testcase(row)
			res = execute(tia[:text])

			rh = {}
		 	rh[:result] = res[0]
			rh[:testcase] = {:name=>tia[:text], :where=>"#{@driverDir}\\#{tia[:text]}"}
			rh[:detail] = {:name=>res[1], :where=>".\\#{res[1]}"}
			@directory.change(rh, row)

			suc += 1 if "Pass" == res[0]
		end
		suc
	end

	def exit
		@summary.exit if @summary
		@detail.exit if @detail
		@logs.exit if @logs
		if @devs
			@devs.execute("CMS", "canc-user::rootgod:exit;\n")
			@devs.exit 
		end
	end

	def login user, password
		@devs.execute("CMS", "act-user::rootgod:sdf::root;\n"%[user, password]).include? "COMPLD"
	end

	private
	def execute shortPath
		begin
			results = CaseExecutor.new(@driverDir + "\\" + shortPath, @execDir).exec do |target, str|
				if "RETRIEVE" == str
					@devs.retrieve target
				else
			 		@devs.execute(target, str)
			 	end 
			end

			rspdir = @reportDir.dup
			shortPath.gsub(/.txt/, "").split("\\").each do |sd|
				rspdir << "\\#{sd}"
				Dir.mkdir(rspdir, 0777) unless Dir.exist?(rspdir)
			end

			results[:detail].each do |hs|
				rstep = hs[:step]
				if rstep.is_a?(Hash) and rstep[:text] =~ /^xsend/
					xmlfn = "Result_" + rstep[:text].split("\\")[-1]
					File.open(rspdir + "\\" + xmlfn, 'w+') do |f|
						f.write hs[:response]
					end 
					hs[:response] = {:text=>xmlfn, :hyperlnk=>".\\"+xmlfn}				
				end
			end

			reportfile = shortPath.gsub(/.txt/, "") + "\\details.xlsx" #+ shortPath.split("\\")[-1].gsub(/.txt/, ".xlsx") 
			@detail.report(results[:detail], reportfile)

			[results[:final], reportfile]
		rescue EOFError =>eof
			raise eof, "EOFError: %s"%[shortPath]
		rescue =>e
			bt = ""
			e.backtrace.each do |line|
				bt << "#{line}\n"
			end
			@logs.append "%s(%d)\: %s\n%s\n%s"%[__FILE__, __LINE__, shortPath, e.to_s, bt] 

			["Failed", @logs.log_name.split("\\")[-1]]
		end	
	end

	def dir_traverse(dir_name, regexp, &block)
	  Dir.open(dir_name) do |dir|
	    dir.each do |sd|
	      if [".", ".."].include? sd
	        next
	      end
	      fd = "%s\\%s"%[dir_name, sd]
	      if File.directory?(fd)
	        dir_traverse(fd, regexp, &block) 
	      elsif sd =~ regexp
	          block.call fd #yield fd
	      end
	    end
	  end
	end	
end

if __FILE__ == $0

end