require "net/http"
require "digest"
require "open3"
require "json"
require "date"
require "time"
require "descriptive_statistics"
URL = URI("http://developer.itsmarta.com/BRDRestService/RestBusRealTimeService/GetAllBus")
MARTA_TIMESTAMP_FORMAT = "%m/%d/%Y %I:%M:%S %p"
MY_TIMESTAMP_FORMAT = "%Y-%m-%d-%H:%M:%S"

def prettify_json(response)
  # requires https://stedolan.github.io/jq/
  Open3.popen2("jq .") {|stdin,stdout,t|
    stdin.print response
    stdin.close
    stdout.read
  }
end

def stats_for(response, request_time)
  parsed = JSON.parse(response)
  ages = parsed.map do |hash|
    time = parse_marta_timestamp(hash.fetch("MSGTIME"))
    request_time - time
  end
  max = ages.max
  min = ages.min
  percentiles = Hash[[10, 50, 90].map{|percentile|
    [percentile, ages.percentile(percentile)] 
  }]
  "max #{max}, min #{min}, percentiles #{percentiles}"
end

def whole_number?(number)
  number % 1 == 0
end

def parse_marta_timestamp(string)
  Time.strptime(string, MARTA_TIMESTAMP_FORMAT)
end

def monitor
  digest = nil
  loop do
    request_time = Time.now
    timestamp = request_time.strftime(MY_TIMESTAMP_FORMAT)
    puts "requesting at #{timestamp}"
    response = Net::HTTP.get(URL)
    new_digest = Digest::SHA256.digest(response)
    unless digest.nil?
      changed = new_digest != digest
      puts "changed? #{changed}" unless digest.nil?
    end
    digest = new_digest
    if changed || digest.nil?
      puts stats_for(response, request_time)
      prettified = prettify_json(response)
      File.open("output/response_#{timestamp}.txt", "w") {|f| f.write(prettified) }
    end
    sleep 2
  end
end

monitor
