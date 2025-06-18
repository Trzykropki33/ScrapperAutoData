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
  def extract_first_known_value(data, with_unit: true)
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
      "brak danych"
    end
  end

  def get_date_of_production(data1,data2=nil)
    return nil if data1.nil?
    year_match = data1.match(/(\d{4})\s*r/i)
    unless data2.nil?
      end_match = data2.match(/(\d{4})\s*r/i)
      return "od #{year_match} do #{end_match}"
    end
    "od #{data1}"
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
          value = "brak danych"
        end

        if ["Długość", "Szerokość", "Wysokość", "Rozstaw osi","Szerokość ze rozłożonymi lusterkami","głębokość brodzenia", "Rozstaw kół przednich", "Rozstaw kół tylnych", "zwis przedni", "zwis tylny", "Układ silnika","Średnica cylindrów","Prześwit", "Szerokość ze złożonymi lusterkami","Minimalna średnica skrętu","Minimalna pojemność bagażnika","Zbiornik paliwa","Maksymalna pojemność bagażnika","Dopuszczalna masa ładunku na dachu","Masa własna","Maksymalne obciążenie","Dopuszczalna masa całkowita przyczepy bez hamulców","Dopuszczalna masa całkowita przyczepy z hamulcami przy ruszaniu na wzniesieniu o nachyleniu 12%","Zużycie paliwa - Cykl mieszany","Prędkość maksymalna","Moment obrotowy Silnik elektryczny"].include?(key)
          value = extract_first_known_value(value)
        end

        if ["Moment obrotowy"].include?(key)
          value = convert_nm_extra(value)
        end

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
            data_map["Opony opcjonalne"] = "brak danych"
          else
            data_map["Opony opcjonalne"] = data[1]
          end
        end

        if ["Rozmiar felg"].include?(key)
          data = split_rims(value)
          value = data[0]
          if data[1].nil?
            data_map["Felgi opcjonalne"] = "brak danych"
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
            value = "brak danych"
          end
        end

        if ["Średnie zużycie energii"].include?(key)
          value = extract_kwh(value)
        end

        if ["Emisje CO2"].include?(key)
          value = extract_co2(value)
        end

        @all_heads << key
        data_map[key] = value
      end

      data_map["Link"] = line
      @all_heads << "Link"

      @all_data << data_map
    end
    save_to_csv
  end

  def save_to_csv
    file_name = "Report_#{DateTime.now.strftime('%Y%m%d_%H%M%S')}.csv"

    #db_head = ["Pełna nazwa","Marka","Model","Link","Liczba drzwi","Liczba miejsc","Średnica zawracania","Promień skrętu","Długość","Szerokość","Szerokość z lusterkami bocznymi","Wysokość","Rozstaw osi","Rozstaw kół - przód","Rozstaw kół - tył","Zwis przedni","Zwis tylny","Prześwit","Długość z hakiem holowniczym","Szerokość ze złożonymi lusterkami bocznymi","Szerokość przy otwartych drzwiach z przodu","Szerokość przy otwartych drzwiach z tyłu","Wysokość z relingami dachowymi","Wysokość z anteną","Wysokość przy otwartej klapie bagażnika","Wysokość przy otwartej pokrywie silnika","Prześwit 4x4","Odległość oparcia fotela przedniego od kierownicy","Długość kolumny kierownicy","Odległość oparcia przedniego od komory silnika","Odległość od siedziska przedniego do dachu","Wysokość siedziska przedniego","Długość siedziska przedniego","Wysokość oparcia przedniego","Odległość pomiędzy siedzeniami przednimi i tylnymi","Odległość od siedziska tylnego do dachu","Odległość od podłogi do siedziska tylnego","Długość siedziska tylnego","Wysokość oparcia tylnego","Szerokość nad podłokietnikami z przodu","Szerokość nad podłokietnikami z tyłu","Szerokość na wysokości podłokietników z przodu","Szerokość na wysokości podłokietników z tyłu","Przestrzeń wsiadania z przodu - szerokość","Przestrzeń wsiadania z przodu - wysokość","Przestrzeń wsiadania z tyłu - szerokość","Przestrzeń wsiadania z tyłu - wysokość","Zakres przesuwania foteli przednich","Całkowita długość wnętrza kabiny","Całkowita szerokość wnętrza kabiny","Całkowita wysokość wnętrza kabiny","Maksymalna pojemność bagażnika (siedzenia złożone)","Minimalna pojemność bagażnika (siedzenia rozłożone)","Szerokość pomiędzy nadkolami","Wysokość bagażnika","Szerokość bagażnika","Długość do oparcia tylnej kanapy","Długość ze złożoną tylną kanapą","Wysokość progu załadowczego","Kąt natarcia","Kąt rampowy","Kąt zejścia","Kąt przechyłu bocznego","Możliwość podjazdu","Głębokość brodzenia","Maksymalna ładowność","Dopuszczalne obciążenie dachu","Powierzchnia „przejrzysta” przedniej szyby","Całkowita powierzchnia „przejrzysta” szyb","Produkowany","Pojemność skokowa","Typ silnika","Moc silnika","Maksymalny moment obrotowy","Moc silnika (spalinowy)","Maksymalny moment obrotowy (spalinowy)","Moc silnika (elektryczny)","Maksymalny moment obrotowy (elektryczny)","Montaż silnika","Doładowanie","Umiejscowienie wałka rozrządu","Liczba cylindrów","Układ cylindrów","Liczba zaworów","Stopień sprężania","Zapłon","Typ wtrysku","Liczba silników","Średnica cylindra × skok tłoka","Układ paliwowy","Dodatkowe informacje","Rodzaj układu kierowniczego","Opony podstawowe","Opony opcjonalne","Felgi podstawowe","Felgi opcjonalne","Rozstaw śrub","Rodzaj hamulców (przód)","Rodzaj hamulców (tył)","Hamowanie (100 do 0km/h) z ABS","Typ układu hamulcowego","Grubość tarcz hamulcowych (przód)","Grubość tarcz hamulcowych (tył)","Średnica tarcz hamulcowych (przód)","Średnica tarcz hamulcowych (tył)","Rodzaj zawieszenia (przód)","Rodzaj zawieszenia  (tył)","Amortyzatory","Rodzaj skrzyni","Nazwa skrzyni","Liczba stopni","Rodzaj napędu","Rodzaj sprzęgła","Prędkość maksymalna","Przyspieszenie (od 0 do 100km/h)","400 metrów ze startu zatrzymanego","1000 metrów ze startu zatrzymanego","Średnie spalanie (cykl mieszany)","Spalanie na trasie (na autostradzie)","Spalanie w mieście","Pojemność akumulatora brutto","Typ ładowarki","Chłodzenie akumulatora","Pojemność akumulatora netto","Metodologia pomiaru zasięgu","Zużycie energii","Maksymalny zasięg przy oszczędnej jeździe na długiej trasie","Średni maksymalny zasięg","Średni minimalny zasięg","Maksymalna moc ładowania DC","Maksymalna moc ładowania AC","Stacja szybkiego ładowania","Gniazdko 3F/Stacja AC","Gniazdko 1F","Pojemność zbiornika paliwa","Zasięg (cykl mieszany)","Zasięg (autostrada)","Zasięg (miasto)","Emisja CO₂","Norma emisji spalin","Minimalna masa własna pojazdu (bez obciążenia)","Maksymalna masa całkowita pojazdu (w pełni obciążonego)","Maksymalna masa przyczepy z hamulcami","Maksymalna masa przyczepy bez hamulców","Maksymalny nacisk na hak","Pojemność akumulatora","Pojemność akumulatora w wersji z klimatyzacja","System start&stop","Kod silnika"]
    #match_head = ["Pełna nazwa","Marka","Model","Link","Liczba drzwi","Liczba miejsc","null","Minimalna średnica skrętu","Długość","Szerokość","Szerokość ze rozłożonymi lusterkami","Wysokość","Rozstaw osi","Rozstaw kół przednich","Rozstaw kół tylnych","zwis przedni","zwis tylny","Prześwit","null","Szerokość ze złożonymi lusterkami","null","null","null","null","null","null","Prześwit","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","Maksymalna pojemność bagażnika","Minimalna pojemność bagażnika","null","null","null","null","null","null","Kąt natarcia","kąt rampowy","Kąt zejścia","null","null","głębokość brodzenia","null","Dopuszczalna masa ładunku na dachu","null","null","Początek produkcji","null","Układ silnika","null","Moment obrotowy","null","null","null","Moment obrotowy Silnik elektryczny","null","Porty ładowania","Układ rozrządu","Liczba cylindrów","null","Liczba zaworów cylindra","Stopień sprężania","null","Układ wtrysku paliwa","null","Średnica cylindrów","null","null","Układ kierowniczy","Rozmiar opon","Opony opcjonalne","Rozmiar felg","Felgi opcjonalne","null","Hamulce przednie","Hamulce tylne","100 km/h - 0","null","null","null","null","null","Zawieszenie przednie","Zawieszenie tylne","null","Ilość biegów i rodzaj skrzyni biegów","null","Ilość biegów i rodzaj skrzyni biegów","Napęd","null","Prędkość maksymalna","Przyspieszenie 0 - 100 km/h","null","null","Zużycie paliwa - Cykl mieszany","null","null","Pojemność brutto akumulatora","null","null","null","null","Średnie zużycie energii","null","null","null","null","null","null","null","null","Zbiornik paliwa","null","null","null","Emisje CO2","Standard ekologiczny","Masa własna","Maksymalne obciążenie","null","Dopuszczalna masa całkowita przyczepy bez hamulców","Dopuszczalna masa całkowita przyczepy z hamulcami przy ruszaniu na wzniesieniu o nachyleniu 12%","Pojemność brutto akumulatora","null","null","Model/Kod silnika"]

    match_head = [
      "rok Produkcji",
      "paliwo",
      "marka",
      "model",
      "Wersja",
      "pojemność",
      "Silnik:",
      "Układ zasilania:",
      "St. sprzężania:",
      "MOC SILNIKA kM",
      "MOC SILNIKA kW",
      "przy obr/min",
      "Maks. moment obrotowy w Nm",
      "0-100 km/h:",
      "V-max:",
      "zużycie paliwa miasto",
      "zużycie paliwa trasa",
      "średnie zużycie paliwa",
      "ilość oleju silnikowego",
      "rodzaj oleju silnikowego",
      "ilość oleju skrzynia biegów",
      "rodzaj oleju skrzynia biegów",
      "rodzaj płynu hamulcowego",
      "ilość płynu hamulcowego",
      "rodzaj płynu chłodniczego",
      "ilość płynu chłodniczego",
      "rozmiar kół",
      "tech_data"
    ]

    db_head = [
      "Produkowany",
      "Typ wtrysku",
      "Marka",
      "Model",
      "Pełna nazwa",
      "Pojemność skokowa",
      "Typ silnika",
      "Układ paliwowy",
      "Stopień sprężania",
      "Moc silnika",
      "Moc silnika (spalinowy)",
      "przy obr/min",
      "Maksymalny moment obrotowy",
      "Przyspieszenie (od 0 do 100km/h)",
      "Prędkość maksymalna",
      "Spalanie w mieście",
      "Spalanie na trasie (na autostradzie)",
      "Średnie spalanie (cykl mieszany)",
      "ilość oleju silnikowego",  # załóżmy, że to pole istnieje
      "rodzaj oleju silnikowego", # j.w.
      "ilość oleju skrzynia biegów",
      "rodzaj oleju skrzynia biegów",
      "rodzaj płynu hamulcowego",
      "ilość płynu hamulcowego",
      "rodzaj płynu chłodniczego",
      "ilość płynu chłodniczego",
      "Opony podstawowe",
      "tech_data"
    ]


    transition_map = db_head.zip(match_head).to_h

    CSV.open(file_name, 'w', col_sep: ";") do |csv|
      csv << db_head

      @all_data.each do |row|
        next if row.nil?
        csv << db_head.map do |header|
          local_key = transition_map[header]
          if local_key.nil? || local_key.downcase == "null" || row[local_key].nil?  ||  row[local_key] == ""
            "brak danych"
          else
            if row[local_key] == "Zaloguj się, aby zobaczyć."
              row[local_key] == "brak danych"
            end
              if header == "Rodzaj skrzyni"
                row[local_key].match(/(automatyczna|manualna|półautomatyczna|dwusprzęgłowa|bezstopniowa)/i)
              elsif header == "Liczba stopni"
                row[local_key].match(/(\d+)\s*bieg(?:ów|i)?/i)
              elsif header == "Nazwa skrzyni"
                row[local_key].match(/skrzynia biegów\s+(.+)$/i)
              elsif header == "Produkowany"
                get_date_of_production(row["Początek produkcji"],row["Koniec produkcji"])
              else
                row[local_key] || "brak danych"
              end
          end
        end
      end
    end
  end
end