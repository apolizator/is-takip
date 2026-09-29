//
//  Modeller.swift
//  Afelay
//
//  Tüm veri modelleri. Çözümleme (decode) her alanda "yoksa varsayılan"
//  şeklinde yapılır; böylece ileride alan eklendiğinde eski kayıtlar bozulmaz.
//

import Foundation

// MARK: - Kategori (sınırsız iç içe dallanma)

nonisolated struct Kategori: Identifiable, Codable, Hashable {
    var id = UUID()
    var isim: String
    var ustId: UUID? = nil          // nil => ana seviye
    var not: String = ""
    var resimAdi: String? = nil

    init(id: UUID = UUID(), isim: String, ustId: UUID? = nil, not: String = "", resimAdi: String? = nil) {
        self.id = id
        self.isim = isim
        self.ustId = ustId
        self.not = not
        self.resimAdi = resimAdi
    }

    enum CodingKeys: String, CodingKey { case id, isim, ustId, not, resimAdi }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isim = try c.decodeIfPresent(String.self, forKey: .isim) ?? "Kategori"
        ustId = try c.decodeIfPresent(UUID.self, forKey: .ustId)
        not = try c.decodeIfPresent(String.self, forKey: .not) ?? ""
        resimAdi = try c.decodeIfPresent(String.self, forKey: .resimAdi)
    }
}

// MARK: - Ürün

nonisolated struct Urun: Identifiable, Codable, Hashable {
    var id = UUID()
    var isim: String
    var aciklama: String = ""
    var alisFiyati: Double = 0
    var satisFiyati: Double = 0
    var miktar: Int = 0
    var kategoriId: UUID? = nil
    var resimAdi: String? = nil

    var birimKar: Double { satisFiyati - alisFiyati }
    var toplamKar: Double { birimKar * Double(miktar) }
    var satisDegeri: Double { satisFiyati * Double(miktar) }
    var maliyet: Double { alisFiyati * Double(miktar) }

    init(id: UUID = UUID(), isim: String, aciklama: String = "", alisFiyati: Double = 0,
         satisFiyati: Double = 0, miktar: Int = 0, kategoriId: UUID? = nil, resimAdi: String? = nil) {
        self.id = id
        self.isim = isim
        self.aciklama = aciklama
        self.alisFiyati = alisFiyati
        self.satisFiyati = satisFiyati
        self.miktar = miktar
        self.kategoriId = kategoriId
        self.resimAdi = resimAdi
    }

    enum CodingKeys: String, CodingKey {
        case id, isim, aciklama, alisFiyati, satisFiyati, miktar, kategoriId, resimAdi
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isim = try c.decodeIfPresent(String.self, forKey: .isim) ?? "Ürün"
        aciklama = try c.decodeIfPresent(String.self, forKey: .aciklama) ?? ""
        alisFiyati = try c.decodeIfPresent(Double.self, forKey: .alisFiyati) ?? 0
        satisFiyati = try c.decodeIfPresent(Double.self, forKey: .satisFiyati) ?? 0
        miktar = try c.decodeIfPresent(Int.self, forKey: .miktar) ?? 0
        kategoriId = try c.decodeIfPresent(UUID.self, forKey: .kategoriId)
        resimAdi = try c.decodeIfPresent(String.self, forKey: .resimAdi)
    }
}

// MARK: - İşlem (alış / satış hareketi)

nonisolated enum IslemTipi: String, Codable {
    case alis = "Alış"
    case satis = "Satış"
}

nonisolated struct Islem: Identifiable, Codable, Hashable {
    var id = UUID()
    var urunId: UUID
    var urunIsmi: String
    var tip: IslemTipi
    var tarih: Date
    var adet: Int
    var birimFiyat: Double
    var kisi: String
    var kar: Double

    var tutar: Double { birimFiyat * Double(adet) }

    init(id: UUID = UUID(), urunId: UUID, urunIsmi: String, tip: IslemTipi, tarih: Date,
         adet: Int, birimFiyat: Double, kisi: String, kar: Double) {
        self.id = id
        self.urunId = urunId
        self.urunIsmi = urunIsmi
        self.tip = tip
        self.tarih = tarih
        self.adet = adet
        self.birimFiyat = birimFiyat
        self.kisi = kisi
        self.kar = kar
    }

    // Eski kayıtlarla uyum: ilacId/ilacIsmi -> urunId/urunIsmi
    enum CodingKeys: String, CodingKey {
        case id
        case urunId = "ilacId"
        case urunIsmi = "ilacIsmi"
        case tip, tarih, adet, birimFiyat, kisi, kar
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        urunId = try c.decodeIfPresent(UUID.self, forKey: .urunId) ?? UUID()
        urunIsmi = try c.decodeIfPresent(String.self, forKey: .urunIsmi) ?? "Ürün"
        tip = try c.decodeIfPresent(IslemTipi.self, forKey: .tip) ?? .alis
        tarih = try c.decodeIfPresent(Date.self, forKey: .tarih) ?? Date()
        adet = try c.decodeIfPresent(Int.self, forKey: .adet) ?? 0
        birimFiyat = try c.decodeIfPresent(Double.self, forKey: .birimFiyat) ?? 0
        kisi = try c.decodeIfPresent(String.self, forKey: .kisi) ?? "—"
        kar = try c.decodeIfPresent(Double.self, forKey: .kar) ?? 0
    }
}

// MARK: - Görev / Günlük

nonisolated enum GorevTuru: String, Codable, CaseIterable, Identifiable {
    case not
    case alim
    case satim
    case yer
    case is_

    var id: String { rawValue }

    var baslik: String {
        switch self {
        case .not:   return "Not"
        case .alim:  return "Alım"
        case .satim: return "Satış"
        case .yer:   return "Yer"
        case .is_:   return "İş"
        }
    }

    var simge: String {
        switch self {
        case .not:   return "note.text"
        case .alim:  return "cart.fill"
        case .satim: return "tag.fill"
        case .yer:   return "mappin.and.ellipse"
        case .is_:   return "hammer.fill"
        }
    }

    /// Tamamlanmamış / tamamlanmış hâl için kısa durum yazısı.
    func durumYazisi(_ tamamlandi: Bool) -> String {
        switch self {
        case .not:   return tamamlandi ? "Kapatıldı" : "Not"
        case .alim:  return tamamlandi ? "Alındı" : "Alınacak"
        case .satim: return tamamlandi ? "Satıldı" : "Satılacak"
        case .yer:   return tamamlandi ? "Gidildi" : "Gidilecek"
        case .is_:   return tamamlandi ? "Yapıldı" : "Yapılacak"
        }
    }
}

nonisolated struct Gorev: Identifiable, Codable, Hashable {
    var id = UUID()
    var metin: String
    var tur: GorevTuru = .not
    var tarih: Date = Date()
    var tamamlandi: Bool = false
    var olusturma: Date = Date()

    init(id: UUID = UUID(), metin: String, tur: GorevTuru = .not, tarih: Date = Date(),
         tamamlandi: Bool = false, olusturma: Date = Date()) {
        self.id = id
        self.metin = metin
        self.tur = tur
        self.tarih = tarih
        self.tamamlandi = tamamlandi
        self.olusturma = olusturma
    }

    enum CodingKeys: String, CodingKey { case id, metin, tur, tarih, tamamlandi, olusturma }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        metin = try c.decodeIfPresent(String.self, forKey: .metin) ?? ""
        tur = try c.decodeIfPresent(GorevTuru.self, forKey: .tur) ?? .not
        tarih = try c.decodeIfPresent(Date.self, forKey: .tarih) ?? Date()
        tamamlandi = try c.decodeIfPresent(Bool.self, forKey: .tamamlandi) ?? false
        olusturma = try c.decodeIfPresent(Date.self, forKey: .olusturma) ?? Date()
    }
}

// MARK: - Özet (bir dalın toplamı)

nonisolated struct Ozet: Hashable {
    var adet: Int = 0            // toplam stok adedi
    var urunSayisi: Int = 0      // kaç çeşit ürün
    var maliyet: Double = 0
    var satisDegeri: Double = 0
    var kar: Double = 0

    static let bos = Ozet()

    mutating func ekle(_ u: Urun) {
        adet += u.miktar
        urunSayisi += 1
        maliyet += u.maliyet
        satisDegeri += u.satisDegeri
        kar += u.toplamKar
    }

    mutating func topla(_ o: Ozet) {
        adet += o.adet
        urunSayisi += o.urunSayisi
        maliyet += o.maliyet
        satisDegeri += o.satisDegeri
        kar += o.kar
    }
}

// MARK: - Yardımcı taşıyıcılar

/// Al/Sat sayfasında ürün + işlem tipini birlikte taşır.
nonisolated struct IslemHedef: Identifiable {
    let id = UUID()
    let urun: Urun
    let tip: IslemTipi
}

/// Kategori seçici için hazır yol listesi.
nonisolated struct KategoriSecim: Identifiable, Hashable {
    let id: UUID
    let yol: String
}

/// Depo sekmesindeki gezinme adresleri.
nonisolated enum DepoYol: Hashable {
    case kategori(UUID)
    case urun(UUID)
}

// MARK: - Eski sürüm modelleri (yalnızca göç için okunur)

nonisolated struct EskiKategori: Decodable {
    let id: UUID
    let isim: String
    let ustId: UUID?

    enum CodingKeys: String, CodingKey { case id, isim, ustId }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isim = try c.decodeIfPresent(String.self, forKey: .isim) ?? "Kategori"
        ustId = try c.decodeIfPresent(UUID.self, forKey: .ustId)
    }
}

nonisolated struct EskiUrun: Decodable {
    let id: UUID
    let isim: String
    let aciklama: String
    let alisFiyati: Double
    let satisFiyati: Double
    let miktar: Int
    let kategoriId: UUID?
    let resimData: Data?

    enum CodingKeys: String, CodingKey {
        case id, isim, aciklama, alisFiyati, satisFiyati, miktar, kategoriId, resimData
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isim = try c.decodeIfPresent(String.self, forKey: .isim) ?? "Ürün"
        aciklama = try c.decodeIfPresent(String.self, forKey: .aciklama) ?? ""
        alisFiyati = try c.decodeIfPresent(Double.self, forKey: .alisFiyati) ?? 0
        satisFiyati = try c.decodeIfPresent(Double.self, forKey: .satisFiyati) ?? 0
        miktar = try c.decodeIfPresent(Int.self, forKey: .miktar) ?? 0
        kategoriId = try c.decodeIfPresent(UUID.self, forKey: .kategoriId)
        resimData = try c.decodeIfPresent(Data.self, forKey: .resimData)
    }
}

/// En eski sürüm: düz "ilaç" listesi, kategori düz metindi.
nonisolated struct EskiIlac: Decodable {
    let id: UUID
    let isim: String
    let aciklama: String
    let alisFiyati: Double
    let satisFiyati: Double
    let miktar: Int
    let resimData: Data?
    let kategori: String

    enum CodingKeys: String, CodingKey {
        case id, isim, aciklama, alisFiyati, satisFiyati, miktar, resimData, kategori
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isim = try c.decodeIfPresent(String.self, forKey: .isim) ?? "Ürün"
        aciklama = try c.decodeIfPresent(String.self, forKey: .aciklama) ?? ""
        alisFiyati = try c.decodeIfPresent(Double.self, forKey: .alisFiyati) ?? 0
        satisFiyati = try c.decodeIfPresent(Double.self, forKey: .satisFiyati) ?? 0
        miktar = try c.decodeIfPresent(Int.self, forKey: .miktar) ?? 0
        resimData = try c.decodeIfPresent(Data.self, forKey: .resimData)
        kategori = try c.decodeIfPresent(String.self, forKey: .kategori) ?? ""
    }
}
