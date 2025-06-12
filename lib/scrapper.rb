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
    doc = Nokogiri::HTML(URI.open(url))

    brand_links = doc.css('.marki_blok').map { |a| a['href'] }

    all_cars = []

    brand_links.each do |brand_link|
      all_cars << BASE_URL + brand_link
    end

    all_cars

  end


  def scrap_model(brand)
    url = "#{brand}"
    doc = Nokogiri::HTML(URI.open(url))

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



  def scrap_version(model)
    url = "#{model}"
    doc = Nokogiri::HTML(URI.open(url))

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

  def scrap_config(version)
    url = "#{version}"
    doc = Nokogiri::HTML(URI.open(url))

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
  def convert_measure(data)
    data[/\d+\s*mm/]
  end

  def technical_data(config_url)
    config_url.each do |line|
      begin
        raise "Niepoprawny URL: #{line}" unless line =~ /^https?:\/\//
        doc = Nokogiri::HTML(URI.open(line))
      rescue => e
        puts "Błąd podczas otwierania URL: #{e.message}"
        next
      end
      table = doc.xpath("/html/body/div[2]/table")
      data_map = {}

      table.search('tr').each do |row|
        next if row.css('.no, .no2').any?
        th = row.at('th')
        td = row.at('td')
        next if th.nil? || td.nil?

        key = th.text.gsub(/\s+/, ' ').strip
        value = td.text.gsub(/\s+/, ' ').strip.gsub(";", " ")

        if ["Długość", "Szerokość", "Wysokość", "Rozstaw osi"].include?(key)
          value = convert_measure(value)
        end

        @all_heads << key
        data_map[key] = value
      end

      data_map["Link"] = line  # dodaj ręcznie link
      @all_heads << "Link"

      # Uzupełnij nazwę, markę, model jeśli masz sposób na ich pozyskanie
      # np. data_map["Pełna nazwa"] = get_name(doc)

      @all_data << data_map
    end
    puts @all_heads
    save_to_csv
  end

  def save_to_csv
    file_name = "Report_#{DateTime.now.strftime('%Y%m%d_%H%M%S')}.csv"

    db_head = ["Pełna nazwa","Marka","Model","Link","Liczba drzwi","Liczba miejsc","Średnica zawracania","Promień skrętu","Długość","Szerokość","Szerokość z lusterkami bocznymi","Wysokość","Rozstaw osi","Rozstaw kół - przód","Rozstaw kół - tył","Zwis przedni","Zwis tylny","Prześwit","Długość z hakiem holowniczym","Szerokość ze złożonymi lusterkami bocznymi","Szerokość przy otwartych drzwiach z przodu","Szerokość przy otwartych drzwiach z tyłu","Wysokość z relingami dachowymi","Wysokość z anteną","Wysokość przy otwartej klapie bagażnika","Wysokość przy otwartej pokrywie silnika","Prześwit 4x4","Odległość oparcia fotela przedniego od kierownicy","Długość kolumny kierownicy","Odległość oparcia przedniego od komory silnika","Odległość od siedziska przedniego do dachu","Wysokość siedziska przedniego","Długość siedziska przedniego","Wysokość oparcia przedniego","Odległość pomiędzy siedzeniami przednimi i tylnymi","Odległość od siedziska tylnego do dachu","Odległość od podłogi do siedziska tylnego","Długość siedziska tylnego","Wysokość oparcia tylnego","Szerokość nad podłokietnikami z przodu","Szerokość nad podłokietnikami z tyłu","Szerokość na wysokości podłokietników z przodu","Szerokość na wysokości podłokietników z tyłu","Przestrzeń wsiadania z przodu - szerokość","Przestrzeń wsiadania z przodu - wysokość","Przestrzeń wsiadania z tyłu - szerokość","Przestrzeń wsiadania z tyłu - wysokość","Zakres przesuwania foteli przednich","Całkowita długość wnętrza kabiny","Całkowita szerokość wnętrza kabiny","Całkowita wysokość wnętrza kabiny","Maksymalna pojemność bagażnika (siedzenia złożone)","Minimalna pojemność bagażnika (siedzenia rozłożone)","Szerokość pomiędzy nadkolami","Wysokość bagażnika","Szerokość bagażnika","Długość do oparcia tylnej kanapy","Długość ze złożoną tylną kanapą","Wysokość progu załadowczego","Kąt natarcia","Kąt rampowy","Kąt zejścia","Kąt przechyłu bocznego","Możliwość podjazdu","Głębokość brodzenia","Maksymalna ładowność","Dopuszczalne obciążenie dachu","Powierzchnia „przejrzysta” przedniej szyby","Całkowita powierzchnia „przejrzysta” szyb","Produkowany","Pojemność skokowa","Typ silnika","Moc silnika","Maksymalny moment obrotowy","Moc silnika (spalinowy)","Maksymalny moment obrotowy (spalinowy)","Moc silnika (elektryczny)","Maksymalny moment obrotowy (elektryczny)","Montaż silnika","Doładowanie","Umiejscowienie wałka rozrządu","Liczba cylindrów","Układ cylindrów","Liczba zaworów","Stopień sprężania","Zapłon","Typ wtrysku","Liczba silników","Średnica cylindra × skok tłoka","Układ paliwowy","Dodatkowe informacje","Rodzaj układu kierowniczego","Opony podstawowe","Opony opcjonalne","Felgi podstawowe","Felgi opcjonalne","Rozstaw śrub","Rodzaj hamulców (przód)","Rodzaj hamulców (tył)","Hamowanie (100 do 0km/h) z ABS","Typ układu hamulcowego","Grubość tarcz hamulcowych (przód)","Grubość tarcz hamulcowych (tył)","Średnica tarcz hamulcowych (przód)","Średnica tarcz hamulcowych (tył)","Rodzaj zawieszenia (przód)","Rodzaj zawieszenia  (tył)","Amortyzatory","Rodzaj skrzyni","Nazwa skrzyni","Liczba stopni","Rodzaj napędu","Rodzaj sprzęgła","Prędkość maksymalna","Przyspieszenie (od 0 do 100km/h)","400 metrów ze startu zatrzymanego","1000 metrów ze startu zatrzymanego","Średnie spalanie (cykl mieszany)","Spalanie na trasie (na autostradzie)","Spalanie w mieście","Pojemność akumulatora brutto","Typ ładowarki","Chłodzenie akumulatora","Pojemność akumulatora netto","Metodologia pomiaru zasięgu","Zużycie energii","Maksymalny zasięg przy oszczędnej jeździe na długiej trasie","Średni maksymalny zasięg","Średni minimalny zasięg","Maksymalna moc ładowania DC","Maksymalna moc ładowania AC","Stacja szybkiego ładowania","Gniazdko 3F/Stacja AC","Gniazdko 1F","Pojemność zbiornika paliwa","Zasięg (cykl mieszany)","Zasięg (autostrada)","Zasięg (miasto)","Emisja CO₂","Norma emisji spalin","Minimalna masa własna pojazdu (bez obciążenia)","Maksymalna masa całkowita pojazdu (w pełni obciążonego)","Maksymalna masa przyczepy z hamulcami","Maksymalna masa przyczepy bez hamulców","Maksymalny nacisk na hak","Pojemność akumulatora","Pojemność akumulatora w wersji z klimatyzacja","System start&stop","Kod silnika"]
    match_head = ["null","Marka","Model","Link","Liczba drzwi","Liczba miejsc","null","Minimalna średnica skrętu","Długość","Szerokość","Szerokość ze rozłożonymi lusterkami","Wysokość","Rozstaw osi","Rozstaw kół przednich","Rozstaw kół tylnych","zwis przedni","zwis tylny","Prześwit","null","Szerokość ze złożonymi lusterkami","null","null","null","null","null","null","Prześwit","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","null","Maksymalna pojemność bagażnika","Minimalna pojemność bagażnika","null","null","null","null","null","null","Kąt natarcia","kąt rampowy","Kąt zejścia","null","null","głębokość brodzenia","null","Dopuszczalna masa ładunku na dachu","null","null","[Początek produkcji x Koniec produkcji]","null","Układ silnika","null","Moment obrotowy","null","null","null","Moment obrotowy Silnik elektryczny","null","Porty ładowania","Układ rozrządu","Liczba cylindrów","null","Liczba zaworów cylindra","Stopień sprężania","null","Układ wtrysku paliwa","null","Średnica cylindrów","null","null","Układ kierowniczy","Rozmiar opon","Rozmiar opon","Rozmiar felg","Rozmiar felg","null","Hamulce przednie","Hamulce tylne","100 km/h - 0","null","null","null","null","null","Zawieszenie przednie","Zawieszenie tylne","null","Ilość biegów i rodzaj skrzyni biegów","null","Ilość biegów i rodzaj skrzyni biegów","Napęd","null","Prędkość maksymalna","Przyspieszenie 0 - 100 km/h","null","null","Zużycie paliwa - Cykl mieszany","null","null","Pojemność brutto akumulatora","null","null","null","null","Średnie zużycie energii","null","null","null","null","null","null","null","null","Zbiornik paliwa","null","null","null","Emisje CO2","Standard ekologiczny","Masa własna","Maksymalne obciążenie","null","Dopuszczalna masa całkowita przyczepy bez hamulców","Dopuszczalna masa całkowita przyczepy z hamulcami przy ruszaniu na wzniesieniu o nachyleniu 12%","Pojemność brutto akumulatora","null","null","[Model/Kod silnika]"]

    # Mapa przejścia: db_header => odpowiadający klucz w danych lokalnych
    transition_map = db_head.zip(match_head).to_h

    CSV.open(file_name, 'w', col_sep: ";") do |csv|
      # Zapisz nagłówki z docelowego schematu
      csv << db_head

      @all_data.each do |row|
        csv << db_head.map do |header|
          local_key = transition_map[header]

          if local_key.nil? || local_key.downcase == "null"
            "Brak danych"
          else
            row[local_key] || "Brak danych"
          end
        end
      end
    end
  end


  # def save_to_csv
  #   file_name = "Report_#{DateTime.now.strftime('%Y%m%d_%H%M%S')}.csv"
  #
  #
  #   CSV.open(file_name, 'w', col_sep: ";") do |csv|
  #     csv << sorted_heads
  #     @all_data.each do |row|
  #       csv << sorted_heads.map { |key| row[key] || "Brak danych" }
  #     end
  #   end
  # end


  # def technical_data(config_url)
  #
  #   file_name = "Report_#{DateTime.now.strftime('%Y%m%d_%H%M%S')}.csv"
  #   head = ["Pełna nazwa","Marka","Model","Link","Liczba drzwi","Liczba miejsc","Średnica zawracania","Promień skrętu","Długość","Szerokość","Szerokość z lusterkami bocznymi","Wysokość","Rozstaw osi","Rozstaw kół - przód","Rozstaw kół - tył","Zwis przedni","Zwis tylny","Prześwit","Długość z hakiem holowniczym","Szerokość ze złożonymi lusterkami bocznymi","Szerokość przy otwartych drzwiach z przodu","Szerokość przy otwartych drzwiach z tyłu","Wysokość z relingami dachowymi","Wysokość z anteną","Wysokość przy otwartej klapie bagażnika","Wysokość przy otwartej pokrywie silnika","Prześwit 4x4","Odległość oparcia fotela przedniego od kierownicy","Długość kolumny kierownicy","Odległość oparcia przedniego od komory silnika","Odległość od siedziska przedniego do dachu","Wysokość siedziska przedniego","Długość siedziska przedniego","Wysokość oparcia przedniego","Odległość pomiędzy siedzeniami przednimi i tylnymi","Odległość od siedziska tylnego do dachu","Odległość od podłogi do siedziska tylnego","Długość siedziska tylnego","Wysokość oparcia tylnego","Szerokość nad podłokietnikami z przodu","Szerokość nad podłokietnikami z tyłu","Szerokość na wysokości podłokietników z przodu","Szerokość na wysokości podłokietników z tyłu","Przestrzeń wsiadania z przodu - szerokość","Przestrzeń wsiadania z przodu - wysokość","Przestrzeń wsiadania z tyłu - szerokość","Przestrzeń wsiadania z tyłu - wysokość","Zakres przesuwania foteli przednich","Całkowita długość wnętrza kabiny","Całkowita szerokość wnętrza kabiny","Całkowita wysokość wnętrza kabiny","Maksymalna pojemność bagażnika (siedzenia złożone)","Minimalna pojemność bagażnika (siedzenia rozłożone)","Szerokość pomiędzy nadkolami","Wysokość bagażnika","Szerokość bagażnika","Długość do oparcia tylnej kanapy","Długość ze złożoną tylną kanapą","Wysokość progu załadowczego","Kąt natarcia","Kąt rampowy","Kąt zejścia","Kąt przechyłu bocznego","Możliwość podjazdu","Głębokość brodzenia","Maksymalna ładowność","Dopuszczalne obciążenie dachu","Powierzchnia „przejrzysta” przedniej szyby","Całkowita powierzchnia „przejrzysta” szyb","Produkowany","Pojemność skokowa","Typ silnika","Moc silnika","Maksymalny moment obrotowy","Moc silnika (spalinowy)","Maksymalny moment obrotowy (spalinowy)","Moc silnika (elektryczny)","Maksymalny moment obrotowy (elektryczny)","Montaż silnika","Doładowanie","Umiejscowienie wałka rozrządu","Liczba cylindrów","Układ cylindrów","Liczba zaworów","Stopień sprężania","Zapłon","Typ wtrysku","Liczba silników","Średnica cylindra × skok tłoka","Układ paliwowy","Dodatkowe informacje","Rodzaj układu kierowniczego","Opony podstawowe","Opony opcjonalne","Felgi podstawowe","Felgi opcjonalne","Rozstaw śrub","Rodzaj hamulców (przód)","Rodzaj hamulców (tył)","Hamowanie (100 do 0km/h) z ABS","Typ układu hamulcowego","Grubość tarcz hamulcowych (przód)","Grubość tarcz hamulcowych (tył)","Średnica tarcz hamulcowych (przód)","Średnica tarcz hamulcowych (tył)","Rodzaj zawieszenia (przód)","Rodzaj zawieszenia  (tył)","Amortyzatory","Rodzaj skrzyni","Nazwa skrzyni","Liczba stopni","Rodzaj napędu","Rodzaj sprzęgła","Prędkość maksymalna","Przyspieszenie (od 0 do 100km/h)","400 metrów ze startu zatrzymanego","1000 metrów ze startu zatrzymanego","Średnie spalanie (cykl mieszany)","Spalanie na trasie (na autostradzie)","Spalanie w mieście","Pojemność akumulatora brutto","Typ ładowarki","Chłodzenie akumulatora","Pojemność akumulatora netto","Metodologia pomiaru zasięgu","Zużycie energii","Maksymalny zasięg przy oszczędnej jeździe na długiej trasie","Średni maksymalny zasięg","Średni minimalny zasięg","Maksymalna moc ładowania DC","Maksymalna moc ładowania AC","Stacja szybkiego ładowania","Gniazdko 3F/Stacja AC","Gniazdko 1F","Pojemność zbiornika paliwa","Zasięg (cykl mieszany)","Zasięg (autostrada)","Zasięg (miasto)","Emisja CO₂","Norma emisji spalin","Minimalna masa własna pojazdu (bez obciążenia)","Maksymalna masa całkowita pojazdu (w pełni obciążonego)","Maksymalna masa przyczepy z hamulcami","Maksymalna masa przyczepy bez hamulców","Maksymalny nacisk na hak","Pojemność akumulatora","Pojemność akumulatora w wersji z klimatyzacja","System start&stop","Kod silnika"]
  #
  #   CSV.open(file_name, 'w') do |csv|
  #     config_url.each do |line|
  #     doc = Nokogiri::HTML(URI.open(line))
  #
  #       table = doc.xpath("/html/body/div[2]/table")
  #       data_map = {}
  #       final_string = ""
  #       table.search('tr').each do |row|
  #         next if row.css('.no, .no2').any?
  #
  #         th = row.at('th')
  #         td = row.at('td')
  #
  #         next if th.nil? || td.nil?
  #
  #         key = th.text.gsub(/\s+/, ' ').strip
  #         value = td.text.gsub(/\s+/, ' ').strip
  #         value = value.gsub(";"," ")
  #
  #         if key == "Długość" || key == "Szerokość" || key == "Wysokość" || key == "Rozstaw osi"
  #           value = convert_measure(value)
  #         end
  #         data_map[key] = value
  #
  #       end
  #
  #         head.each do |header|
  #           value = data_map[header]
  #           if header == "Link"
  #             final_string += "#{line};"
  #           elsif value.nil? || value == "" || value == "Zaloguj się, aby zobaczyć."
  #             final_string << "Brak danych;"
  #           else
  #             final_string += "#{value.to_s};"
  #           end
  #         end
  #     csv << final_string.split(";")
  #     end
  #   end
  # end
  #
  # def convert_measure(data)
  #   return  data[/\d+\s*mm/]
  # end
  #
  # def validation_heads(heads)
  #
  # end

end