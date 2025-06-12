require './lib/scrapper'
require 'csv'


scrapper = DataScapper.new
#
# all = scrapper.scrap_brands
# models = scrapper.scrap_model(all[32])
# version = scrapper.scrap_version(models[2])
# config = scrapper.scrap_config(version[0])
# scrapper.technical_data(config)

config = ""
all = scrapper.scrap_brands
all.each do |brand|
  next if brand != "https://www.auto-data.net/pl/tesla-brand-197"
  models = scrapper.scrap_model(brand)
  models.each do |model|
    version = scrapper.scrap_version(model)
    version.each do |vers|
      config = scrapper.scrap_config(vers)
    end
  end
end
scrapper.technical_data(config)

puts scrapper.all_heads
