require 'digest'
require 'zlib'

def brute_force_token(email, unix_time, actual_token)
  chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_'
  
  # جميع دوال الهاش الممكنة
  hash_functions = [
    ->(e) { Zlib.crc32(e) },
    ->(e) { Digest::MD5.hexdigest(e)[0..7].to_i(16) },
    ->(e) { Digest::SHA1.hexdigest(e)[0..7].to_i(16) },
    ->(e) { Digest::SHA256.hexdigest(e)[0..7].to_i(16) },
    ->(e) { Digest::SHA512.hexdigest(e)[0..7].to_i(16) },
    ->(e) { Digest::SHA1.hexdigest(e)[8..15].to_i(16) }, # جزء مختلف من الهاش
    ->(e) { Digest::SHA256.hexdigest(e)[8..15].to_i(16) }
  ]
  
  # جميع العمليات الرياضية الممكنة
  operations = [:+, :^, :*, :<<, :>>, :-, :|, :&]
  
  # نطاق أوسع للإزاحة والـ Modulo
  shifts = (0..31) # تغطية جميع الإزاحات الممكنة
  modulos = [1000, 10000, 65536, 2**32, 2**64, 2**128]
  
  # أطوال التوكن الممكنة
  token_lengths = [20, 24, 32]
  
  # البحث بدون Parallel
  hash_functions.each do |hash_func|
    operations.each do |op|
      shifts.each do |shift|
        modulos.each do |mod|
          token_lengths.each do |len|
            # حساب الهاش
            email_hash = hash_func.call(email) >> shift % mod
            
            # توليد البذرة
            seed = unix_time.send(op, email_hash) % (2**32)
            
            # توليد التوكن
            srand(seed)
            token = (0...len).map { chars[rand(64)] }.join
            
            # إذا تطابق التوكن، إرجاع الإعدادات
            if token == actual_token
              return {
                hash_func: hash_func,
                operation: op,
                shift: shift,
                modulo: mod,
                seed: seed,
                token_length: len,
                token: token
              }
            end
          end
        end
      end
    end
  end
  
  nil
end

# بيانات الاختبار
test_cases = [
  {
    email: "cw_17556241@hotmail.com",
    time: 1737759820,
    actual_token: "ogWyndFh6yX8jpfkKg5y"
  },
  {
    email: "bloggeer090@gmail.com",
    time: 1737759820,
    actual_token: "tWLwk7aE_u9_VAuEY7GL"
  }
]

# تشغيل Bruteforce
test_cases.each do |tc|
  puts "Bruteforcing for: #{tc[:email]}"
  result = brute_force_token(tc[:email], tc[:time], tc[:actual_token])
  
  if result
    puts "✅ Success! Found correct settings:"
    puts "Hash Function: #{result[:hash_func]}"
    puts "Operation: #{result[:operation]}"
    puts "Shift: #{result[:shift]}"
    puts "Modulo: #{result[:modulo]}"
    puts "Token Length: #{result[:token_length]}"
    puts "Seed: #{result[:seed]}"
    puts "Token: #{result[:token]}"
  else
    puts "❌ Failed to find matching combination"
  end
  puts "\n"
end
