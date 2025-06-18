require './lib/scrapper'
require 'csv'


scrapper = DataScapper.new

# all = scrapper.scrap_brands
# models = scrapper.scrap_model(all[22])
# version = scrapper.scrap_version(models[2])
# config = scrapper.scrap_config(version[0])
# scrapper.technical_data(config)

# configs = []
# all = scrapper.scrap_brands
#
# all.each do |brand|
#   #puts "Scrapping brand: #{brand}"
#
#   brand_models = scrapper.scrap_model(brand)
#   brand_models.each do |model|
#     model_versions = scrapper.scrap_version(model)
#     model_versions.each do |vers|
#       configs << scrapper.scrap_config(vers)
#     end
#   end
# end
#
# File.open("configs", "w") do |f|
#   configs.each do |config|
#     f.puts config
#   end
# end
#
# puts "Scrapped brands: #{all.length}"
# puts "Scrapped configs: #{configs.length}"
configs = []
start = Time.now
File.open("configs", "r") do |f|
  f.each_line do |line|
    configs << line.strip
  end
end
ends =  Time.now

puts "Czytanie danych : #{(ends - start)}"

start = Time.now
scrapper.technical_data(configs[300...310])
ends =  Time.now
puts "Scrapowanie Danych : #{(ends - start)}"



