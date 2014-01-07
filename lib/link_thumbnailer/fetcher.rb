require 'net/http/persistent'

module LinkThumbnailer

  class Fetcher

    attr_accessor :url

    def fetch(url, redirect_count = 0)
      if redirect_count > LinkThumbnailer.configuration.redirect_limit
        raise ArgumentError, "too many redirects (#{redirect_count})"
      end

      self.url = url.is_a?(URI) ? url : URI(url)

      if self.url.is_a?(URI::HTTP)
        http                        = Net::HTTP::Persistent.new('linkthumbnailer')
        http.headers['User-Agent']  = LinkThumbnailer.configuration.user_agent
        
        if defined? @cookie && !@cookie.blank?
          http.headers['Cookie'] = @cookie
        end
        
        http.verify_mode            = OpenSSL::SSL::VERIFY_NONE unless LinkThumbnailer.configuration.verify_ssl
        http.open_timeout           = LinkThumbnailer.configuration.http_timeout
        resp                        = http.request(self.url)
        case resp
        when Net::HTTPSuccess
          if resp.header['Content-Encoding'].eql?('gzip')   
            sio = StringIO.new( resp.body )
            gz = Zlib::GzipReader.new( sio )
            body = gz.read()      
          else
            resp.body
          end
        when Net::HTTPRedirection
          location = resp['location'].start_with?('http') ? resp['location'] : "#{self.url.scheme}://#{self.url.host}#{resp['location']}"
          
          @cookie = resp.response['set-cookie'].split('; ')[0] if resp.response['set-cookie']

          fetch(location, redirect_count + 1)
        else resp.error!
        end
      end
    end

  end

end
