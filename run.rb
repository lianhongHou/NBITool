require File.expand_path(File.join(File.dirname(__FILE__), 'NBITestSuit.rb'))


exec_dir =  'C:\MyWork\NBITesting\XMLNBI\C7'
report_dir = 'C:\MyWork\NBITesting\XMLNBI\Report\CMS 12.01.152\C7'

cover_items = [\
	["CMS server:", "12.01.114"], \
	["C7 SW :", "8.0.301.459"],\
	["E3-12C F/W:", "V3.1.06.1 | 12/19/2012"],\
	["E3-48 F/W:", "V1.0.50.5 | 2012-11-16"],\
	["E7-2 F/W:", "2.1.90.74"]\
]

begin 
	@testSuit = NBITestsuit.new exec_dir, report_dir, cover_items

	@testSuit.run

	8.times do |t|
		r = @testSuit.rerun_failed()
		break if (0 == r )
	end
rescue =>e
	puts e.to_s
ensure
	@testSuit.exit
end