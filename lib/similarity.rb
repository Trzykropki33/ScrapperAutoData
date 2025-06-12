require 'fuzzy_match'

source = File.readlines("./header_orginal.txt", chomp: true)
target = File.readlines("./Auto-Dna-headers.txt", chomp: true)

fuzzy = FuzzyMatch.new(target)

mapping = {}

File.open("Auto-Dna-headers-sortesssd-code.txt", "w") do |file|
  source.each do |src|
    match = fuzzy.find(src)
    mapping[src] = match
    file << "#{match}\n"
  end
end

puts mapping


