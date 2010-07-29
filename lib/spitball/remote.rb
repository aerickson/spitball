require 'net/http'
require 'uri'

class Spitball::Remote

  WAIT_SECONDS = 30

  def initialize(gemfile, host, port)
    @gemfile = gemfile
    @host = host
    @port = port
  end

  def copy_to(path)
    File.open(path, 'w') do |f|
      f.write get_tarball_data
    end
  end

  def get_tarball_data
    url = URI.parse("http://#{@host}:#{@port}/create")
    res = Net::HTTP.start(url.host, url.port) do |http|
      http.post(url.path, @gemfile)
    end

    case res.code
    when '201' # Created
      Net::HTTP.get(URI.parse(res['Location']))
    when '202' # Accepted
      (WAIT_SECONDS / 2).times do
        sleep 2
        try = Net::HTTP.get_response(URI.parse(res['Location']))
        next if try.code != '200'
        return try.body
      end

      raise SpitballServerFailure, "Spitball build timed out. The build failed or it's just taking a while..."
    else
      raise SpitballServerFailure, "Expected 2xx response code. Got #{res.code}."
    end
  rescue URI::InvalidURIError => e
    raise SpitballClientError, e.message
  end

end
