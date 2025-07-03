require 'nokogiri'
require 'open-uri'
require 'prawn'
require 'sidekiq'
require 'net/http'

class DataScapper
  BASE_URL = 'https://www.auto-data.net'

  attr_accessor :all_heads, :all_data

  def initialize
    @all_heads = Set.new
    @all_data = []
  end
  def scrap_brands
    url = "#{BASE_URL}/pl/allbrands"

    begin
      raise "Niepoprawny URL: #{url}" unless url =~ /^https?:\/\//
      doc = Nokogiri::HTML(URI.open(url))
    rescue => e
      puts "Błąd podczas otwierania URL: #{e.message}"
    end
    brand_links = doc.css('.marki_blok').map { |a| a['href'] }

    all_cars = []

    brand_links.each do |brand_link|
      all_cars << BASE_URL + brand_link
    end

    all_cars
  end

  def scrap_model(url)
    begin
      raise "Niepoprawny URL: #{url}" unless url =~ /^https?:\/\//
      doc = Nokogiri::HTML(URI.open(url))
    rescue => e
      puts "Błąd podczas otwierania URL: #{e.message}"
    end

    brand_models = doc.css('.modeli')

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
    models
  end



  def scrap_version(url)
    begin
      raise "Niepoprawny URL: #{url}" unless url =~ /^https?:\/\//
      doc = Nokogiri::HTML(URI.open(url))
    rescue => e
      puts "Błąd podczas otwierania URL: #{e.message}"
    end



    models_version = doc.css('.position')

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

  def scrap_config(url)
    begin
      raise "Niepoprawny URL: #{url}" unless url =~ /^https?:\/\//
      doc = Nokogiri::HTML(URI.open(url))
    rescue => e
      puts "Błąd podczas otwierania URL: #{e.message}"
    end

    rows = doc.xpath("/html/body/div[2]/table")

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
    end
    configs
  end
  def extract_first_known_value(data, with_unit: false)
    return nil if data.nil?

    patterns = [
      /(\d+(?:\.\d+)?)\s*mm/i,
      /(\d+(?:\.\d+)?)\s*l\/100\s*km/i,
      /(\d+(?:\.\d+)?)\s*kWh\/100\s*km/i,
      /(\d+(?:\.\d+)?)\s*m(?![a-z])/i,
      /(\d+(?:\.\d+)?)\s*l(?![a-z])/i,
      /(\d+(?:\.\d+)?)\s*kg/i,
      /(\d+(?:\.\d+)?)\s*km\/h/i,
      /(\d+(?:\.\d+)?)\s*nm/i,
      /(\d+(?:\.\d+)?)\s*cm3/i,
    ]

    patterns.each do |regex|
      match = data.match(regex)
      return with_unit ? match[0] : match[1].to_f if match
    end

    nil
  end



  def convert_nm_extra(data)
    return nil if data.nil?
    match = data.match(/(\d+(?:[.,]\d+)?)\s*Nm\s*@\s*(\d+)(?:-\d+)?\s*obr\./)

    if match
      torque = match[1].gsub(',', '.') # Zamień przecinek na kropkę, jeśli występuje
      rpm = match[2]
      "#{torque} Nm przy #{rpm} obr/min"
    else
      ""
    end
  end

  def get_date_of_production(data1,data2=nil)
    return nil if data1.nil?
    year_match = data1.match(/(\d{4})/i)
    unless data2.nil?
      end_match = data2.match(/(\d{4})/i)
      return "#{year_match}-#{end_match}"
    end
    "#{data1}"
  end


  def extract_car_name(url)
    path = URI.parse(url).path
    parts = path.split('/')
    words = parts[2].split('-')

    words.map! { |p| p.capitalize }
    words.pop
    words.join(" ")
  end

  def split_engine_model(data)
    return nil if data.nil? || data.strip.empty?
    data.gsub(/[\/\-\s]/, "")
  end

  def split_tires(data)
    return nil if data.nil? || data.strip.empty?
    tires = data.scan(/\d{3}\/\d{2}\s*R\d{2}/)
    return tires
  end

  def split_rims(data)
    return nil if data.nil? || data.strip.empty?
    rims = data.scan(/\d+(?:\.\d+)?J\s*x\s*\d+/)
    return rims
  end

  def extract_kwh(data)
    return nil if data.nil? || data.strip.empty?
    energy = data.match(/(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)\s*kWh\/100\s*km/)
    return nil unless energy
    "#{energy[1]} kWh/100 km"
  end

  def extract_co2(data)
    return nil if data.nil?

    if data =~ /(\d+)(?:\s*-\s*\d+)?\s*g\/km/i
      "#{$1} g/km"
    else
      nil
    end
  end

  def extract_cycle_type(header)
    match = header.match(/(Zużycie paliwa - Cykl (miejski|pozamiejski|mieszany))/i)
    match[1] if match
  end


  def technical_data(config_url)
    config_url.each do |line|
      puts line
      begin
        raise "Niepoprawny URL: #{line}" unless line =~ /^https?:\/\//
        doc = Nokogiri::HTML(URI.open(line))
      rescue => e
        puts "Błąd podczas otwierania URL: #{e.message}"
        next
      end
      table = doc.xpath("/html/body/div[2]/table")
      data_map = {}
      data_map["Pełna nazwa"] = extract_car_name(line)
      table.search('tr').each do |row|
        next if row.css('.no, .no2').any?
        th = row.at('th')
        td = row.at('td')
        next if th.nil? || td.nil?

        key = th.text.gsub(/\s+/, ' ').strip
        value = td.text.gsub(/\s+/, ' ').strip.gsub(";", " ")

        if value == "Zaloguj się, aby zobaczyć."
          value = ""
        end

        if ["Długość", "Szerokość", "Wysokość","Moment obrotowy", "Rozstaw osi","Szerokość ze rozłożonymi lusterkami","głębokość brodzenia", "Rozstaw kół przednich", "Rozstaw kół tylnych", "zwis przedni", "zwis tylny", "Układ silnika","Średnica cylindrów","Prześwit", "Szerokość ze złożonymi lusterkami","Minimalna średnica skrętu","Minimalna pojemność bagażnika","Zbiornik paliwa","Maksymalna pojemność bagażnika","Dopuszczalna masa ładunku na dachu","Masa własna","Maksymalne obciążenie","Dopuszczalna masa całkowita przyczepy bez hamulców","Dopuszczalna masa całkowita przyczepy z hamulcami przy ruszaniu na wzniesieniu o nachyleniu 12%","Zużycie paliwa - Cykl mieszany","Prędkość maksymalna","Moment obrotowy Silnik elektryczny","Ilość oleju w silniku","płyn chłodzący"].include?(key)
          value = extract_first_known_value(value)
        end

        # if ["Moment obrotowy"].include?(key)
        #   value = convert_nm_extra(value)
        # end

        if ["Liczba miejsc"].include?(key)
          value = value[/\d+/]
        end

        if ["Model/Kod silnika"].include?(key)
          value = split_engine_model(value)
        end

        if ["Rozmiar opon"].include?(key)
          data = split_tires(value)
          value = data[0]
          if data[1].nil?
            data_map["Opony opcjonalne"] = ""
          else
            data_map["Opony opcjonalne"] = data[1]
          end
        end

        if ["Rozmiar felg"].include?(key)
          data = split_rims(value)
          value = data[0]
          if data[1].nil?
            data_map["Felgi opcjonalne"] = ""
          else
            data_map["Felgi opcjonalne"] = data[1]
          end
        end

        if ["Napęd"].include?(key)
          if value == "Napęd na wszystkie koła (4x4)"
            value = "4x4"
          elsif value == "Napęd na tylne koła"
            value = "na tylną oś"
          elsif value == "Napęd na przednie koła"
            value = "na przednią oś"
          else
            value = ""
          end
        end

        if ["Średnie zużycie energii"].include?(key)
          value = extract_kwh(value)
        end

        if ["Emisje CO2"].include?(key)
          value = extract_co2(value)
        end

        if [
          "Zużycie paliwa - Cykl miejski",
          "Zużycie paliwa - Cykl pozamiejski",
          "Zużycie paliwa - Cykl mieszany"
        ].any? { |pattern| key.include?(pattern) }
          key = extract_cycle_type(key)
          value = value.to_s
          value = value[/(\d+(?:\.\d+)?)/]
          #puts "#{key} : #{value}"
        end

        @all_heads << key
        data_map[key] = value
      end

      t_data_head = ["Długość","Szerokość","Wysokość","Rozstaw osi","Liczba drzwi","Liczba miejsc","Ilość biegów","Napęd","Rodzaj skrzyni","Rozmiar opon ","Rozmiar felg","Zbiornik paliwa","Masa własna","Minimalna pojemność bagażnika","Maksymalna pojemność bagażnika"]
      data="{"
      t_data_head.each do |key|

        if data_map["Ilość biegów i rodzaj skrzyni biegów"].nil?
          data += "\"#{key}\": \"null\","
        elsif key == "Ilość biegów"
          data += "\"#{key}\": \"#{data_map["Ilość biegów i rodzaj skrzyni biegów"][/\d+/].to_i}\","
        elsif key == "Rodzaj skrzyni"
          data +=  "\"#{key}\": \"#{data_map["Ilość biegów i rodzaj skrzyni biegów"][/skrzynia biegów\s+(.*)/i,1]}\","
        else
          data += "\"#{key}\": \"#{data_map[key]}\","
        end
      end
      data.chomp!(",")
      data += "}"
      data_map["tech_data"] = data
      #puts data

      data_map["Link"] = line
      @all_heads << "Link"

      data_map["Produkowany"] = get_date_of_production(data_map["Początek produkcji"],data_map["Koniec produkcji"])
      @all_heads << "Produkowany"

      @all_data << data_map
    end
    save_to_csv
  end

  def save_to_csv
    file_name = "Report_#{DateTime.now.strftime('%Y%m%d_%H%M%S')}.csv"

    db_head =     ["rok produkcji","paliwo",    "marka","model","Wersja",   "pojemność w cm³",  "Silnik:",              "Układ zasilania:",     "Średnica × skok tłoka:", "St. sprężania:",   "MOC SILNIKA kM","MOC SILNIKA kW","przy obr/min","Maks. moment obrotowy w Nm","0-100 km/h:",                "V-max:",             "zużycie paliwa miasto",        "zużycie paliwa trasa",     "średnie zużycie paliwa", "ilość oleju silnikowego","rodzaj oleju silnikowego",       "ilość oleju skrzynia biegów","rodzaj oleju skrzynia biegów","rodzaj płynu hamulcowego","ilość płynu hamulcowego","rodzaj płynu chłodniczego","ilość płynu chłodniczego","rozmiar kół","tech_data"]
    match_head =  ["Produkowany",  "Typ paliwa","Marka","Model","Generacja","Pojemność silnika","Modyfikacja (Silnik)", "Układ wtrysku paliwa", "Średnica cylindrów",     "Stopień sprężania","Moc",            "Moc",          "Moc",         "Moment obrotowy",           "Przyspieszenie 0 - 100 km/h","Prędkość maksymalna","Zużycie paliwa - Cykl miejski", "Zużycie paliwa - Cykl pozamiejski", "Zużycie paliwa - Cykl mieszany",                "Ilość oleju w silniku",  "Specyfikacja oleju silnikowego", "null",                       "null",                        "null",                    "null",                   "null",                     "płyn chłodzący",          "Rozmiar opon","tech_data"]

    transition_map = db_head.zip(match_head).to_h
    CSV.open(file_name, 'w', col_sep: ";") do |csv|
      csv << db_head

      @all_data.each do |row|
        next if row.nil?
        csv << db_head.map do |header|
          local_key = transition_map[header]
          #puts "header: #{header}, local_key: #{local_key}"
          if local_key.nil? || local_key.downcase == "null" || row[local_key].nil?  ||  row[local_key] == ""
            ""
          else
            if row[local_key] == "Zaloguj się, aby zobaczyć."
              row[local_key] == ""
            end
              if header == "Silnik:"
                if row["Pojemność silnika"].nil? || row["Liczba cylindrów"].nil? || row["Konfiguracja silnika"].nil?
                  return ""
                end
                liters = extract_first_known_value(row["Pojemność silnika"], with_unit: false) / 1000
                liters = (liters * 10).ceil / 10.0
                "#{ liters } L, ilość cylindrów: #{ row["Liczba cylindrów"] }, układ cylindrów: #{ row["Konfiguracja silnika"] }"
              elsif header == "pojemność w cm³"
                extract_first_known_value(row["Pojemność silnika"], with_unit: false).to_i
              elsif header == "MOC SILNIKA kM"
                if row["Moc"].nil?
                  return ""
                end
                row["Moc"].match(/\d+/)
              elsif header == "MOC SILNIKA kW"
                if row["Moc"].nil?
                  return ""
                end
                kW = row["Moc"][/\d+/].to_f
                kW = (kW * 0.74).to_i
                kW
              elsif header == "przy obr/min"
                if row["Moc"].nil?
                  return ""
                end
                row["Moc"].match(/\s+\d+/).to_s
              elsif header == "0-100 km/h:"
                if row[local_key].nil?
                  return ""
                end
                row[local_key][/(\d+(?:\.\d+)?)/]
              else
                row[local_key] || ""
              end
          end
        end
      end
    end
  end
end