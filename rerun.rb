require File.expand_path(File.join(File.dirname(__FILE__), 'NBITestsuit.rb'))

if __FILE__ == $0
	exec_dir = 'C:\MyWork\NBITesting\XMLNBI\C7'
	summary_xlsx = 'C:\MyWork\NBITesting\XMLNBI\Report\CMS 12.01.152\C7\summary.xlsx'
	
	begin
		@testSuit = NBITestsuit.new exec_dir, summary_xlsx
		8.times do |t|
			r = @testSuit.rerun_failed()
			break if (0 == r )
		end		
	rescue =>e
		puts e.to_s
	ensure
		@testSuit.exit
	end
end
