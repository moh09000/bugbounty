require 'digest'

def predict_token(email, unix_time)
  chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
  email_hash = Digest::SHA1.hexdigest(email)[0..5].to_i(16)
  seed = unix_time ^ email_hash
  srand(seed)
  (0..19).map { chars[rand(64)] }.join
end

# Example usage with provided data
requests = [
  { email: 'cw_17556241@hotmail.com', time: 1737759820, token: 'ogWyndFh6yX8jpfkKg5y' },
  { email: 'bloggeer090@gmail.com', time: 1737759820, token: 'tWLwk7aE_u9_VAuEY7GL' },
  { email: 'cw_17556241@hotmail.com', time: 1737759931, token: 'Snxs-jMXnoktHxriruhK' },
  { email: 'bloggeer090@gmail.com', time: 1737759931, token: 'k9rK-y2nLx4yMxysa_zC' }
]

requests.each do |req|
  predicted = predict_token(req[:email], req[:time])
  puts "Email: #{req[:email]} | Time: #{req[:time]}"
  puts "Predicted Token: #{predicted}"
  puts "Actual Token:    #{req[:token]}\n\n"
end
