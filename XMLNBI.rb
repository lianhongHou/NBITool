module XMLNBI
  require 'net/http'
  require 'open-uri'
  require 'nokogiri'

  class XmlSessionError < StandardError; end
  class InvalidSessionId < XmlSessionError; end
  class InvalidParameter < XmlSessionError; end
  class InvalidXMLRequest < XmlSessionError; end

  class XMLServer
    @@port = "18080"
    @@xml4login = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" \
    + "<soapenv:Envelope xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\">" \
    + "<soapenv:Body>" \
    + "<auth message-id=\"1\">" \
    + "<login>"  \
    + "<UserName>%s</UserName>"  \
    + "<Password>%s</Password>" \
    + "</login>"  \
    + "</auth>"  \
    + "</soapenv:Body>"  \
    + "</soapenv:Envelope>"

    def initialize host, user, password
      @host = host
      @http = Net::HTTP.new(@host, @@port)
      @http.open_timeout = 60
      @http.read_timeout = 600
      @http.start()
      
      rsp = send_request(@@xml4login%[user, password])
      @sessionId = rsp.scan(/<SessionId>(\d+)<\/SessionId>/i)[0][0]
    end

    def execute xml
      raise InvalidParameter unless xml.instance_of?(String)

      xml.gsub!(/ sessionid="\d+"/i) {|m| m.split("=")[0] + "=" + "\"#{@sessionId}\""}

      rst = send_request(xml)
      rst
    end

    def exit
      @http.finish()
    end

    private
    def send_request xml
      uri = "http://#{@host}:#{@@port}/"
      xmls = xml.to_s
      if xmls.include?("Msap")
        uri << "cmsweb/nc"
      elsif xmls.include?("E5100")
        uri << "cmsweb/nc"
      elsif xmls.include?("AeCMSNetwork")
        uri << "cmsae/ae/netconf"
      elsif xmls.include?("nodename") and not xmls.include?("AeCMSNetwork")
        uri << "cmsexc/ex/netconf"
      else
        uri << "cmsweb/nc"
        # raise InvalidXMLRequest, xml
      end

      req = Net::HTTP::Post.new(uri)
      req['content-type'] = "text/plain;charset=UTF-8"

      req.body = xmls
      rsp = @http.request(req)
      rst = Nokogiri::XML(rsp.body,&:noblanks).to_xml
      rst.gsub!("<?xml version=\"1.0\"?>", "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
      rst
    end
  end
end

if __FILE__ == $0
  xmler = XMLNBI::XMLServer.new("10.245.252.104", "rootgod", "root")
  s = ""
  File.open('C:\MyWork\XMLNBI\E72\xmlreq\create-data_svc.xml', 'r+') do |f|
    s << f.read
  end
  puts xmler.execute(s)
end