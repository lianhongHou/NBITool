
class LogsError < StandardError;end
class InvalidParameterError < LogsError;end
	
class Logs
	def initialize filename
		raise InvalidParameterError, "should be a file ended with .log" unless filename =~ /\.log/

		@log_name = filename
		@log = File.open(filename, "a+") # create & append
		@order = 0
	end

	attr_reader :log_name

	def reconstruct
		@order = 0
		@log.each do |line|
			if line =~ /^\s*\d+\) /
				@order += 1
			end
		end
	end

	def append str
		num = @log.write "\n%d) %s"%[@order, str] 
		@log.flush
		@order += 1 
	end

	def exit
		@log.close
	end
end