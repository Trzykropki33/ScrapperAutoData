require 'nokogiri'
require 'open-uri'
require 'prawn'
require 'sidekiq'
require 'net/http'



class DataScapper
  BASE_URL = 'https://www.auto-data.net'

  def scrap_brands
    url = "#{BASE_URL}/pl/allbrands"
    doc = Nokogiri::HTML(URI.open(url))

    puts doc
    brand_links = doc.css('.marki_blok').map { |a| a['href'] }

    all_cars = []

    brand_links.each do |brand_link|
      all_cars << BASE_URL + brand_link
    end

    puts all_cars

    all_cars

  end


  def scrap_model(brand)
    url = "#{brand}"
    doc = Nokogiri::HTML(URI.open(url))

    brand_models = doc.css('.modeli')
    puts "Oto modele po 2020"

    models = []

    brand_models.each do |model|
      red = model.at_css('.redcolor')
      green = model.at_css('.greencolor')

      if red
        text = red.text.strip
        end_year = text.split('-').last.strip.to_i
        if end_year >= 2020
          models << "#{BASE_URL}#{model['href']}"
        end
      elsif green
        models << "#{BASE_URL}#{model['href']}"
      end
    end

    puts models
    models
  end



  def scrap_version(model)
    puts
    url = "#{model}"
    doc = Nokogiri::HTML(URI.open(url))

    puts model
    models_version = doc.css('.position')
    puts "Oto wersje po 2020"

    versions = []

    models_version.each do |ver|
      red = ver.at_css('.end')
      green = ver.at_css('.cur')

      if red
        text = red.text.strip
        end_year = text.split('-').last.strip.to_i
        if end_year >= 2020
          versions << "#{BASE_URL}#{ver['href']}"
        end
      elsif green
        versions << "#{BASE_URL}#{ver['href']}"
      end
    end

    versions
  end

  def scrap_config(version)
    puts
    url = "#{version}"
    doc = Nokogiri::HTML(URI.open(url))

    rows = doc.xpath("/html/body/div[2]/table")

    puts "Oto Konfig po 2020"
    configs = []
    rows.css('th.i').each do |row|
      green = row.css('span.cur')
      red = row.css('span.end')

      if red
        text = red.text.strip
        end_year = text.split('-').last.to_i
        if end_year >= 2020
          configs <<  "#{BASE_URL}#{row.search('a').attribute('href').value}"
        end
      elsif green
        configs <<  "#{BASE_URL}#{row.search('a').attribute('href').value}"
      end
      puts configs
    end
    configs
  end


  def technical_data(config_url)
    puts config_url
    puts "Techniczne dane: #{config_url}"
    doc = Nokogiri::HTML(URI.open(config_url))

    file_name="Report_#{DateTime.now.strftime("%Y%m%d_%H%M%S").to_s}.csv"
    file_name1="Report_#{DateTime.now.strftime("%Y%m%d_%H%M%S").to_s}x.csv"


    CSV.open(file_name1, 'w') do |csv|
      table = doc.xpath("/html/body/div[2]/table")

      table.search('tr').each do |row|
        if row.css('.no').any?
          next
        end
        if row.css('.no2').any?
          next
        end
        th = row.search('th')
        td = row.search('td')
        if td.nil? || td.nil?
          next
        end
        csv << [th.text,td.text]
        #puts "#{th.text} : #{td.text}"
      end
     end

    # CSV.open(file_name, 'w') do |csv|
    #   csv << ['Key', 'Value']
    #
    #     doc.xpath('/html/body/div[2]/table').each do |table|
    #         table.xpath('.//tr').each do |row|
    #             if row.xpath('./th[not(contains(@class, "no")) or @colspan="2"]').any?
    #             # key = row.xpath('./th').text.strip
    #             # value = row.xpath('./td').text.strip
    #             komorki = row.xpath('./td')
    #             unless komorki.count == 2
    #
    #               key = komorki.first.text.strip
    #               value = komorki.last.text.strip
    #             end
    #
    #             csv << [key,value] unless key.nil? || value.nil?
    #           end
    #         end
    #       end

      doc.css('table.tech.specs').each do |table|
        table.css('tr').each do |row|
          key = row_at.css('th')&.text&.strip
          value = row_at.css('td')&.text&.strip

          if key && value && !key.empty? && !value.empty?
            csv  << [key, value]
          end
        end
      end
    end
  end

end