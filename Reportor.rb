
module Report
	require 'WIN32OLE'
	require "Date"

	class ReportorError < StandardError;end
	class NotValidParameterError < ReportorError;end 

	Summary_file_name = "summary\.xlsx"
	Directory_name = "directory"
	Cover_name = "cover"

	class Directory
		Result_attr = "a"
		Testcase_attr = "b"
		Detail_attr = "c"
		First_attr = Result_attr
		Last_attr = Detail_attr
		First_item = 2

		def mark_pass row
			@directory.Range("#{Result_attr}#{row}:#{Detail_attr}#{row}").Interior.ColorIndex = 0
		end

		def highlight row
			@directory.Range("#{First_attr}#{row}:#{Last_attr}#{row}").Interior.ColorIndex = 4
		end

		def mark_failed row
			@directory.Range("#{First_attr}#{row}:#{Last_attr}#{row}").Interior.ColorIndex = 3
		end

		def get_result row
			@directory.Range("#{Result_attr}#{row}").Value
		end

		def set_result row, str
			@directory.Range("#{Result_attr}#{row}").Value = str
			unless "Pass"== str
				mark_failed row
			else
				mark_pass row
				@failed_case.delete row
			end				
		end

		def get_testcase row
			cell = @directory.Range("#{Testcase_attr}#{row}")
			# puts "Address: #{cell.Hyperlinks(1).Address}"
			{:text=>cell.Value, :hyperlnk=>cell.Hyperlinks(1).Address}
		end			

		def set_testcase row, str, hyperlnk = nil
			cellpath = "#{Testcase_attr}#{row}"
			hyperlnk = @directory.Range(cellpath).Value unless hyperlnk
			@hyperlinks.Add(@directory.Range(cellpath), hyperlnk) #absolute hyperlink
			@directory.Range(cellpath).Value = str
		end

		def get_detailreport row
			@directory.Range("#{Detail_attr}#{row}").Value
		end

		def set_detailreport row, str, hyperlnk = nil
			cellpath = "#{Detail_attr}#{row}"
			hyperlnk = @directory.Range(cellpath).Value unless hyperlnk
			@hyperlinks.Add(@directory.Range(cellpath), hyperlnk) #relative hyperlink
			@directory.Range(cellpath).Value = str
		end

		def initialize sheet
			@directory = sheet
			@directory.Columns(Result_attr).ColumnWidth = 10
			@directory.Columns(Testcase_attr).ColumnWidth = 120
			@directory.Columns(Detail_attr).ColumnWidth = 80

			@dir_row = First_item
			@total_case = 0
			@failed_case = []

			@hyperlinks = @directory.Hyperlinks
		end

		attr_reader :total_case

		def failed_case
			@failed_case.dup
		end

		def change result, row
			rks = result.keys
			set_result(row, result[:result]) if rks.include?(:result)
			set_testcase(row, result[:testcase][:name], result[:testcase][:where]) if rks.include?(:testcase)
			set_detailreport(row, result[:detail][:name], result[:detail][:where]) if rks.include?(:detail)

			save()
		end

		def append result
			@failed_case << @dir_row 

			change result, @dir_row

			@dir_row += 1
			@total_case += 1
		end

		def save
			@directory.Parent.Save
		end

		def reconstruct
			ur = @directory.UsedRange
			row_cnt = ur.Row + ur.Rows.Count
			# puts "row_cnt: %d"%row_cnt

			(@dir_row...row_cnt).each do |row|
				@total_case += 1
				if "Pass" != get_result(row)
					@failed_case << row
				end
			end	
			@dir_row += @total_case		
		end

		def exit

		end
	end

	class Cover
		COVERITEM = ["Start time:", "Total cases:", "Failed cases:", "End time:"]
		Attr_col = "c"
		Value_col = "d"

		def initialize sheet, items=[]
			@cover = sheet

			ur = @cover.UsedRange
			if (2 == ur.Row+ur.Rows.Count) #blank sheet
				start_row = 8
				init_items start_row, items
			end
		end

		def reconstruct
			ur = @cover.UsedRange
			@cover_tail = ur.Row + ur.Rows.Count

			init_items @cover_tail
		end

		def exit total_case, failed_case
			@cover.Range("#{Attr_col}#{@cover_tail-2}").Value = COVERITEM[1]
			@cover.Range("#{Attr_col}#{@cover_tail-1}").Value = COVERITEM[2]
			@cover.Range("#{Attr_col}#{@cover_tail}").Value = COVERITEM[3]

			@cover.Range("#{Value_col}#{@cover_tail-2}").Value = total_case
			@cover.Range("#{Value_col}#{@cover_tail-1}").Value = failed_case
			@cover.Range("#{Value_col}#{@cover_tail}").Value = DateTime.now.asctime
		end

		private
		def init_items start_row, items=[]
			@cover_tail = start_row + COVERITEM.size + items.size - 1

			acol = "#{Attr_col}#{start_row}:#{Attr_col}#{@cover_tail}"
			@cover.Range(acol).Borders.Weight = 3
			@cover.Range(acol).Borders.ColorIndex = 14
			@cover.Range(acol).Borders.Linestyle = 9
			# sheet.Range(acol).Interior.ColorIndex = 23
			@cover.Range(acol).Font.Bold = true# 
			@cover.Columns(Attr_col).ColumnWidth = 40

			vcol = "#{Value_col}#{start_row}:#{Value_col}#{@cover_tail}"
			@cover.Range(vcol).Borders.Weight = 1
			@cover.Range(vcol).Borders.ColorIndex = 14
			@cover.Range(vcol).Borders.Linestyle = 12
			# sheet.Range(vcol).Interior.ColorIndex = 25
			@cover.Columns(Value_col).ColumnWidth = 40

			rge = "#{Attr_col}#{start_row}:#{Value_col}#{@cover_tail}"
			@cover.Range(rge).HorizontalAlignment = -4108 #middle

			@cover.Range("#{Attr_col}#{start_row}").Value = COVERITEM[0]
			@cover.Range("#{Value_col}#{start_row}").Value = DateTime.now.asctime

			i = 1
			items.each do |it|
				break unless (it.instance_of?(Array) && (2 == it.size))

				r = start_row+i
				@cover.Range("#{Attr_col}#{r}").Value = it[0]
				@cover.Range("#{Value_col}#{r}").Value = it[1]

				i += 1
			end
		end
	end

	class Summary
		def self.instance_of? summary
			rst = false
			re = Regexp.new "%s$"%[Summary_file_name.gsub("\.", "\\.")]
			if summary =~ re
				rst = true
			end
			rst
		end

		def initialize dir, items=[]
			sum_ins = self.class.instance_of? dir
			if sum_ins
				@dir = File.dirname dir
			else
				@dir = dir
			end
			
			@excel = WIN32OLE.new("excel.application")
			@excel.Visible = true

			if sum_ins
				init_exist()
			else
				init_nonexist(items)
			end
		end

		attr_reader :directory, :cover
		
		def exit
			@cover.exit @directory.total_case, @directory.failed_case.size

			@directory.exit
			
			@book.Save
			@book.Saved = true
			@book.Close

			@excel.Quit
		end

		private
		def init_nonexist items
			@book = @excel.Workbooks.Add
	
			cov = @book.Worksheets(1)
			cov.name = Cover_name
			cov.Select
			@cover = Cover.new(cov, items)

			dirt = @book.Worksheets(2)
			dirt.name = Directory_name
			dirt.Select
			@directory = Directory.new(dirt)

			@book.SaveAs("%s\\%s"%[@dir, Summary_file_name])
		end

		def init_exist
			@book = @excel.Workbooks.Open("%s\\%s"%[@dir, Summary_file_name])
			
			@cover = Cover.new(@book.Worksheets(Cover_name))
			@cover.reconstruct

			@directory = Directory.new(@book.Worksheets(Directory_name))
			@directory.reconstruct
		end
	end 

	class Detail
		Rest_attr = "a"
		Step_attr = "b"
		Resp_attr = "c"
		def initialize dir
			@dir = dir
			@excel = WIN32OLE.new("excel.application")
			# @excel.Visible = true	
		end
		
		def report results, filename
			book = @excel.Workbooks.Add
			sheet = book.Worksheets(1)
			sheet.Select# 
			hyperlinks = sheet.Hyperlinks

			row = 2
			results.each do |rlst_hash|
				step_cell = sheet.Range("#{Step_attr}#{row}")			
				if rlst_hash[:step].is_a?(Hash)
					hyperlinks.Add(step_cell, rlst_hash[:step][:hyperlnk])
					step_cell.Value = rlst_hash[:step][:text]
				else
					step_cell.Value = rlst_hash[:step]
				end

				rst_cell = sheet.Range("#{Resp_attr}#{row}")
				if rlst_hash[:response].is_a?(Hash)
					hyperlinks.Add(rst_cell, rlst_hash[:response][:hyperlnk])
					rst_cell.Value = rlst_hash[:response][:text]
				else
					rst_cell.Value = rlst_hash[:response]
				end

				sheet.Range("#{Rest_attr}#{row}").Value = rlst_hash[:result]	
				unless "Pass" == rlst_hash[:result]
					sheet.Range("#{Rest_attr}#{row}:#{Resp_attr}#{row}").Interior.ColorIndex = 3
				end

				row += 1
			end

			sheet.Columns(Rest_attr).ColumnWidth = 10
			sheet.Columns(Step_attr).ColumnWidth = 120
			sheet.Columns(Resp_attr).ColumnWidth = 120

			path = "%s\\%s"%[@dir, filename]
			if File.file? path
				File.delete path
			end

			book.SaveAs(path)
			book.Close			
		end

		def exit
			@excel.Quit
		end
	end
end