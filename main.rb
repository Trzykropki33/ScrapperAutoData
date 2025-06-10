require './lib/scrapper'
require 'csv'


scrapper = DataScapper.new

all = scrapper.scrap_brands

models = scrapper.scrap_model(all[22])

version = scrapper.scrap_version(models[0])

config = scrapper.scrap_config(version[1])

puts
puts "Oto url = #{config[0]}"
puts

scrapper.technical_data(config[1])
#
# models.each do |model|
#   scrapper.scrap_version(model)
# end


models = []
#
# all.each do |brand|
#   models < scrapper.scrap_model(brand)
# end
