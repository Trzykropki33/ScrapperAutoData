def technical_data(config_url)
  puts
  puts config_url
  puts "Techniczne dane: #{config_url}"
  # doc = Nokogiri::HTML(URI.open(url))
  #
  #   CSV.open(output_file, 'w') do |csv|
  #     csv << ['Key', 'Value']
  #
  #     doc.css('.table.tech.specs').each do |table|
  #       table.css('tr').each do |row|
  #         key = row_at.css('th')&.text&.strip
  #         value = row_at.css('td')&.text&.strip
  #
  #         if key && value && !key.empty? && !value.empty?
  #           csv  << [key, value]
  #         end
  #       end
  #     end
  #   end
  end