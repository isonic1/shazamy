require 'webrick'
require 'webrick/httpproxy'
require 'nokogiri'
require 'colorize'
require 'json'


class Shazamy
  
  def handler
        
    handler = proc do |req, res|
      
      host1 = "macct.shazam.com"
      host2 = "ocdn.shazamid.com"
  
      if res.status == 200 then
    
        if req.host == host1 && req.request_method == "POST" && res.body.size > 500 
          puts "\nParsing Shazam JSON".green

          json = JSON.parse(res.body)
          json_title = json['matches'][0]['title'] if !json['matches'][0]['title'].nil?
          json_band = json['matches'][0]['description'] if !json['matches'][0]['description'].nil?
          json_cover_art = json['matches'][0]['images']['image400'] if !json['matches'][0]['images']['image400'].nil?
          json_sample = json['matches'][0]['itunes']['previewurl'] if !json['matches'][0]['itunes']['previewurl'].nil?
          json_itunes = json['matches'][0]['itunes']['purchaseurl'] if !json['matches'][0]['itunes']['purchaseurl'].nil? 
          json_stores = json['matches'][0]['stores'].map.each { |x| x[1]['actions'] }.map.each { |x| x.map.each { |x| x['uri'] if x['type'] == 'uri' }.compact }.flatten
      
          puts " \njson_title: #{json_title}"
          puts " json_band: #{json_band}"
          puts " json_cover_art: #{json_cover_art}"
          puts " json_itunes: #{json_itunes}"
          puts " json_stores: #{json_stores}\n"
        end
    
        if req.host == host2 && req.request_method == "GET"
          puts "\nParsing Shazam XML".green
      
          string_io = StringIO.new(res.body)
          gzip = Zlib::GzipReader.new(string_io)
          page = gzip.read()
          xml = Nokogiri::XML(page)

          title = xml.css("track/ttitle").text if !xml.css("track/ttitle").text.nil?
          band = xml.css("tartists/tartist").text if !xml.css("tartists/tartist").text.nil?
          if !xml.css("tmetadata/tmetadatum").find { |x| x[:key] == 'Album' }.nil?
            album = xml.css("tmetadata/tmetadatum").find { |x| x[:key] == 'Album' }.text
          end
          if !xml.css("tmetadata/tmetadatum").find { |x| x[:key] == 'Label' }.nil?
            label = xml.css("tmetadata/tmetadatum").find { |x| x[:key] == 'Label' }.text
          end
          if !xml.css("tmetadata/tmetadatum").find { |x| x[:key] == 'Released' }.nil?
            year = xml.css("tmetadata/tmetadatum").find { |x| x[:key] == 'Released' }.text
          end
          if !xml.css("tmetadata/tmetadatum").find { |x| x[:key] == 'Genre' }.nil?
            genre = xml.css("tmetadata/tmetadatum").find { |x| x[:key] == 'Genre' }.text
          end
          cover_art_url = xml.css("tcoverart").text if !xml.css("tcoverart").text.nil?
          sample = xml.css("taudiosample").text if !xml.css("taudiosample").text.nil?
          itunes = xml.css("addOn/content")[0].text if !xml.css("addOn/content")[0].text.nil?
          
          puts " \nxml_title: #{title}"
          puts " xml_band: #{band}"
          puts " xml_album: #{album}"
          puts " xml_label: #{label}"
          puts " xml_year: #{year}"
          puts " xml_genre: #{genre}"
          puts " xml_cover_art: #{cover_art_url}"
          puts " xml_sample_url: #{sample}"
          puts " xml_itunes_url: #{itunes}\n"
          #
          # DO WHAT YOU WILL WITH THIS DATA HERE!!!
          #
        end
      end
    end
  end
  
  def run(port)
    begin
      puts "Enabling Web Proxy. Please Enter Password Twice!\n".green
      `networksetup -setwebproxy "Wi-Fi" 127.0.0.1 #{port}`
      `networksetup -setwebproxystate "Wi-Fi" on`
      puts "Starting Proxy!".green
      proxy = WEBrick::HTTPProxyServer.new Logger: WEBrick::Log.new("/dev/null"), 
                                            AccessLog: [], 
                                            Port: port, 
                                            ProxyContentHandler: handler
                                            
      #puts "Proxy Starting...\n".green
      proxy.start
    rescue Interrupt
      puts "\nGot Interrupt. Stopping...".red
    ensure
      #if trap 'INT' do proxy.shutdown end
      if proxy
        proxy.stop
        puts "Proxy Stopped!\n".red
        puts "Disabling Web Proxy. Please Enter Password!\n".green
        `networksetup -setwebproxystate "Wi-Fi" off`
      end
    end
  end
end

Shazamy.new.run ARGV[2]