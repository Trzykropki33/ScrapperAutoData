  class ImportAutocentrumWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker
  sidekiq_options queue: :import_autocentrum, retry: false

  def perform(file_path)

    header = ["Liczba drzwi", "Liczba miejsc", "Średnica zawracania", "Promień skrętu", "Długość", "Szerokość", "Wysokość", "Rozstaw osi", "Rozstaw kół - przód", "Rozstaw kół - tył", "Prześwit", "Długość z hakiem holowniczym", "Szerokość z lusterkami bocznymi", "Szerokość ze złożonymi lusterkami bocznymi", "Szerokość przy otwartych drzwiach z przodu", "Szerokość przy otwartych drzwiach z tyłu", "Wysokość z relingami dachowymi", "Wysokość z anteną", "Wysokość przy otwartej klapie bagażnika", "Wysokość przy otwartej pokrywie silnika", "Zwis przedni", "Zwis tylny", "Prześwit 4x4", "Maksymalna pojemność bagażnika (siedzenia złożone)", "Minimalna pojemność bagażnika (siedzenia rozłożone)", "Długość do oparcia tylnej kanapy", "Długość ze złożoną tylną kanapą", "Wysokość progu załadowczego", "Szerokość pomiędzy nadkolami", "Wysokość bagażnika", "Szerokość bagażnika", "Odległość od siedziska przedniego do dachu", "Odległość od siedziska tylnego do dachu", "Szerokość nad podłokietnikami z przodu", "Szerokość nad podłokietnikami z tyłu", "Szerokość na wysokości podłokietników z przodu", "Szerokość na wysokości podłokietników z tyłu", "Odległość oparcia fotela przedniego od kierownicy", "Długość kolumny kierownicy", "Odległość oparcia przedniego od komory silnika", "Wysokość siedziska przedniego", "Długość siedziska przedniego", "Wysokość oparcia przedniego", "Odległość pomiędzy siedzeniami przednimi i tylnymi", "Odległość od podłogi do siedziska tylnego", "Długość siedziska tylnego", "Wysokość oparcia tylnego", "Przestrzeń wsiadania z przodu - szerokość", "Przestrzeń wsiadania z przodu - wysokość", "Przestrzeń wsiadania z tyłu - szerokość", "Przestrzeń wsiadania z tyłu - wysokość", "Zakres przesuwania foteli przednich", "Całkowita długość wnętrza kabiny", "Całkowita szerokość wnętrza kabiny", "Całkowita wysokość wnętrza kabiny", "Kąt natarcia", "Kąt rampowy", "Kąt zejścia", "Kąt przechyłu bocznego", "Możliwość podjazdu", "Głębokość brodzenia", "Maksymalna ładowność", "Dopuszczalne obciążenie dachu", "Powierzchnia przejrzysta przedniej szyby", "Całkowita powierzchnia przejrzysta szyb", "Produkowany", "Pojemność skokowa", "Typ silnika", "Moc silnika", "Maksymalny moment obrotowy", "Montaż silnika", "Umiejscowienie wałka rozrządu", "Liczba cylindrów", "Układ cylindrów", "Liczba zaworów", "Stopień sprężania", "Średnica cylindra × skok tłoka", "Typ wtrysku", "Doładowanie", "Zapłon", "Układ paliwowy", "Dodatkowe informacje", "Opony podstawowe", "Opony opcjonalne", "Rodzaj hamulców (przód)", "Rodzaj hamulców (tył)", "Hamowanie (100 do 0km/h) z ABS", "Typ układu hamulcowego", "Grubość tarcz hamulcowych (przód)", "Grubość tarcz hamulcowych (tył)", "Średnica tarcz hamulcowych (przód)", "Średnica tarcz hamulcowych (tył)", "Rodzaj", "Felgi podstawowe", "Felgi opcjonalne", "Rodzaj zawieszenia (przód)", "Rodzaj zawieszenia (tył)", "Amortyzatory", "Rodzaj skrzyni", "Liczba biegów", "Rodzaj napędu", "Nazwa skrzyni", "Typ 4x4", "Nazwa 4x4", "Rozdział momentu obrotowego (przód : tył)", "System start&stop", "Rodzaj sprzęgła", "Prędkość maksymalna", "Przyspieszenie (od 0 do 100km/h)", "400 metrów ze startu zatrzymanego", "1000 metrów ze startu zatrzymanego", "Średnie spalanie (cykl mieszany)", "Spalanie w trasie (na autostradzie)", "Spalanie w mieście", "Pojemność zbiornika paliwa", "Zasięg (cykl mieszany)", "Zasięg (autostrada)", "Zasięg (miasto)", "Emisja CO", "Norma emisji spalin", "Minimalna masa własna pojazdu (bez obciążenia)", "Maksymalna masa całkowita pojazdu (w pełni obciążonego)", "Maksymalna masa przyczepy z hamulcami", "Maksymalna masa przyczepy bez hamulców", "Maksymalny nacisk na hak", "Pojemność akumulatora", "Pojemność akumulatora w wersji z klimatyzacja", "Rodzaj skrzyni", "Rodzaj napędu", "Nazwa skrzyni", "Liczba stopni", "Typ 4x4", "Nazwa 4x4", "Rozdział momentu obrotowego (przód : tył)", "System start&stop", "Rodzaj sprzęgła", "Prędkość maksymalna", "Przyspieszenie (od 0 do 100km/h)", "400 metrów ze startu zatrzymanego", "1000 metrów ze startu zatrzymanego", "Średnie spalanie (cykl mieszany)", "Spalanie w trasie (na autostradzie)", "Spalanie w mieście", "Pojemność zbiornika paliwa", "Zasięg (cykl mieszany)", "Zasięg (autostrada)", "Zasięg (miasto)", "Emisja CO", "Norma emisji spalin", "Minimalna masa własna pojazdu (bez obciążenia)", "Maksymalna masa całkowita pojazdu (w pełni obciążonego)", "Maksymalna masa przyczepy z hamulcami", "Maksymalna masa przyczepy bez hamulców", "Maksymalny nacisk na hak", "Pojemność akumulatora", "Pojemność akumulatora w wersji z klimatyzacja"].uniq

    begin
      CSV.foreach(file_path, headers: true, col_sep: ';') do |row|

        tech_data = {}
        header.each{|x| tech_data[x] = row[x] if row[x].present?}

        data = row['url'].split('dane-techniczne/')[1].split('/')

        hash = ImportAutocentrumWorker.url_data(data)

        if row['Produkowany'].present?
          hash[:production_from] = row['Produkowany'].scan(/\d+/)[0]
          hash[:production_to] = row['Produkowany'].scan(/\d+/)[1]
        end

        hash[:engine] = ImportAutocentrumWorker.engine(row)
        hash[:engine_capacity] = row['Pojemność skokowa'].match(/\d+/)[0] if row['Pojemność skokowa'].present?

        if row['Moc silnika'].present?
          power = row['Moc silnika'].split('przy')
          hash[:engine_power] = power[0].strip
          hash[:engine_power_hp] = power[0].scan(/\d+/)[0]
          hash[:engine_power_kw] = power[0].scan(/\d+/)[1]
          hash[:rpm_for_engine_power] = power[1].strip if power[1]
        end

        hash[:fuel] = ImportAutocentrumWorker.fuel_type(row['Typ silnika'])
        hash[:fuel_injection] = row['Typ wtrysku']
        hash[:bore_x_stroke] = row['Średnica cylindra × skok tłoka']
        hash[:compression_ratio] = row['Stopień sprężania']
        hash[:max_torque] = row['Maksymalny moment obrotowy'].scan(/\d+/)[0]
        hash[:rpm_for_torque] = row['Maksymalny moment obrotowy'].scan(/\d+/)[1..-1].join('-') if row['Maksymalny moment obrotowy'].present?
        hash[:acceleration] = row['Przyspieszenie (od 0 do 100km/h)']
        hash[:max_speed] = row['Prędkość maksymalna']
        hash[:combustion_city] = row['Spalanie w mieście'].match(/\d+(\.|,)\d+/)[0] if row['Spalanie w mieście'].present?
        hash[:combustion_highway] = row['Spalanie w trasie (na autostradzie)'].match(/\d+(\.|,)\d+/)[0] if row['Spalanie w trasie (na autostradzie)'].present?
        hash[:combustion_average] = row['Średnie spalanie (cykl mieszany)'].match(/\d+(\.|,)\d+/)[0] if row['Średnie spalanie (cykl mieszany)'].present?

        hash[:tech_data] = tech_data

        VehicleSpec.create(hash)
      end
    rescue Exception => e
      puts e
    ensure
      File.delete file_path
    end
  end

  def self.url_data(arr)
    hash = {
        brand: ImportAutocentrumWorker.adjust_brand_name(arr[0].gsub('-',' ')),
        vehicle_model: arr[1].gsub('-',' ')
    }
    # arr[0] - brand
    # arr[1] - model
    #
    # depends on amount of data from arr[2] to arr[arr.lenght-1]
    # generation, body

    case arr.length
    when 4
      hash[:model_version] = arr[2].gsub('-',' ')
    when 5
      hash[:model_version] = "#{arr[2].gsub('-',' ')} - #{arr[3].gsub('-',' ')}"
    end

    hash
  end

  def self.adjust_brand_name(name)
    list = {
        'mercedes' => 'mercedes-benz'
    }
    list[name] ? list[name] : name
  end

  def self.fuel_type(fuel)
    case fuel
    when "benzynowy"
      "benzyna"
    when "diesel"
      "olej napędowy"
    else
      ""
    end
  end

  def self.engine(row)
    data = []
    if row['Pojemność skokowa'].present?
      engine = row['Pojemność skokowa'].match(/\d+/)[0]
      engine = (engine.to_f/1000).round(1)
      data << "#{engine} l"
    end

    data << row['Umiejscowienie wałka rozrządu'] if row['Umiejscowienie wałka rozrządu'].present?
    data << "ilość cylindrów: #{row['Liczba cylindrów']}" if row['Liczba cylindrów'].present?
    data << "układ cylindrów: #{row['Układ cylindrów']}" if row['Układ cylindrów'].present?
    data << "liczba zaworów: #{row['Liczba zaworów']}" if row['Liczba zaworów'].present?
    data << row['Doładowanie'] if row['Doładowanie'].present?


    data.reject{|x| !x.present?}.join(', ')
  end

end
