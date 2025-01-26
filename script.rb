require 'openssl'
require 'digest'

def generate_hmac_token(email, unix_time, secret_key)
  data = "#{email}:#{unix_time}"  # Combine email and Unix time
  OpenSSL::HMAC.hexdigest('sha256', secret_key, data)  # Generate HMAC with secret key
end

# Example brute-force function
def brute_force_hmac(email, unix_time, actual_token)
  chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
  possible_secrets = ['secret1', 'secret2', 'key123', 'password']  # Example secrets to try

  possible_secrets.each do |secret|
    token = generate_hmac_token(email, unix_time, secret)
    if token == actual_token
      return { secret: secret, token: token }
    end
  end

  nil
end

# Example use
email = "cw_17556241@hotmail.com"
unix_time = 1737759820
actual_token = "ogWyndFh6yX8jpfkKg5y"

result = brute_force_hmac(email, unix_time, actual_token)
if result
  puts "Found matching secret: #{result[:secret]}"
else
  puts "No match found"
end
