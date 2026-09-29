//
//  Depolama.swift
//  Afelay
//
//  Veriler UserDefaults yerine Application Support içinde JSON dosyalarında tutulur.
//  Yazma işlemi arka plan kuyruğunda ve geciktirmeli (debounce) yapılır; böylece
//  hızlı ardışık değişikliklerde arayüz kilitlenmez.
//  Fotoğraflar JSON'un içinde DEĞİL, ayrı dosyalarda saklanır (asıl takılma sebebi buydu).
//

import Foundation
import UIKit
import ImageIO

nonisolated enum Dosya {
    static let kategoriler = "kategoriler.json"
    static let urunler = "urunler.json"
    static let islemler = "islemler.json"
    static let gorevler = "gorevler.json"
}

nonisolated final class Depolama: @unchecked Sendable {
    static let shared = Depolama()

    let kokKlasor: URL
    private let kuyruk = DispatchQueue(label: "com.afelay.depolama", qos: .utility)
    private var bekleyen: [String: Data] = [:]     // yalnızca `kuyruk` üzerinde kullanılır
    private var zamanlanmis = false                // yalnızca `kuyruk` üzerinde kullanılır
    private let fm = FileManager.default

    private init() {
        let taban = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                  in: .userDomainMask,
                                                  appropriateFor: nil,
                                                  create: true))
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        kokKlasor = taban.appendingPathComponent("AfelayVeri", isDirectory: true)
        try? FileManager.default.createDirectory(at: kokKlasor, withIntermediateDirectories: true)
    }

    func url(_ ad: String) -> URL { kokKlasor.appendingPathComponent(ad) }

    // MARK: Okuma / yazma

    func oku<T: Decodable>(_ tip: T.Type, _ ad: String) -> T? {
        guard let d = try? Data(contentsOf: url(ad)) else { return nil }
        return try? JSONDecoder().decode(tip, from: d)
    }

    /// Geciktirmeli yazma. Kodlama da arka planda yapılır.
    func yaz<T: Encodable>(_ deger: T, _ ad: String) {
        kuyruk.async { [self] in
            guard let data = try? JSONEncoder().encode(deger) else { return }
            bekleyen[ad] = data
            guard !zamanlanmis else { return }
            zamanlanmis = true
            kuyruk.asyncAfter(deadline: .now() + 0.5) { [self] in bosalt() }
        }
    }

    /// Beklemeden diske yazar; başarı durumunu döndürür (göç için).
    @discardableResult
    func hemenYaz<T: Encodable>(_ deger: T, _ ad: String) -> Bool {
        guard let d = try? JSONEncoder().encode(deger) else { return false }
        do { try d.write(to: url(ad), options: .atomic); return true } catch { return false }
    }

    /// Uygulama arka plana alınırken bekleyen her şeyi diske basar.
    /// Ana thread'i bloklamaz; bitince `bitince` ana thread'de çağrılır.
    func hemenKaydet(bitince: (@Sendable () -> Void)? = nil) {
        kuyruk.async { [self] in
            bosalt()
            if let bitince { DispatchQueue.main.async { bitince() } }
        }
    }

    private func bosalt() {
        zamanlanmis = false
        let isler = bekleyen
        bekleyen.removeAll()
        for (ad, data) in isler {
            try? data.write(to: url(ad), options: .atomic)
        }
    }

    func dosyaSil(_ ad: String) {
        try? fm.removeItem(at: url(ad))
    }
}

// MARK: - Resim deposu

nonisolated enum ResimDeposu {
    static let klasor: URL = {
        let u = Depolama.shared.kokKlasor.appendingPathComponent("Resimler", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }()

    static func buyukUrl(_ ad: String) -> URL { klasor.appendingPathComponent(ad + ".jpg") }
    static func kucukUrl(_ ad: String) -> URL { klasor.appendingPathComponent(ad + "_k.jpg") }

    /// Seçilen fotoğrafı küçülterek kaydeder, dosya adını döndürür. Arka planda çağrılmalı.
    static func kaydet(_ veri: Data) -> String? {
        let ad = UUID().uuidString
        guard let buyuk = olcekle(veri, maks: 1400),
              let bd = buyuk.jpegData(compressionQuality: 0.8) else { return nil }
        do { try bd.write(to: buyukUrl(ad), options: .atomic) } catch { return nil }
        if let kucuk = olcekle(veri, maks: 320), let kd = kucuk.jpegData(compressionQuality: 0.7) {
            try? kd.write(to: kucukUrl(ad), options: .atomic)
        }
        return ad
    }

    /// Göç sırasında kullanılır: yeniden kodlamadan olduğu gibi yazar (hızlı).
    static func hamKaydet(_ veri: Data, ad: String) -> String? {
        do { try veri.write(to: buyukUrl(ad), options: .atomic); return ad } catch { return nil }
    }

    /// Küçük sürüm yoksa büyükten üretip diske yazar.
    static func kucukVeri(_ ad: String) -> Data? {
        if let d = try? Data(contentsOf: kucukUrl(ad)) { return d }
        guard let buyukVeri = try? Data(contentsOf: buyukUrl(ad)),
              let img = olcekle(buyukVeri, maks: 320),
              let d = img.jpegData(compressionQuality: 0.7) else { return nil }
        try? d.write(to: kucukUrl(ad), options: .atomic)
        return d
    }

    static func buyukVeri(_ ad: String) -> Data? {
        try? Data(contentsOf: buyukUrl(ad))
    }

    /// Çözümlemeyi (decode) de burada yapar; böylece ana thread'de çizim
    /// anında çözümleme olmaz ve kaydırma takılmaz.
    static func kucukGorsel(_ ad: String) -> UIImage? {
        guard let d = kucukVeri(ad), let i = UIImage(data: d) else { return nil }
        return i.preparingForDisplay() ?? i
    }

    static func buyukGorsel(_ ad: String) -> UIImage? {
        guard let d = buyukVeri(ad), let i = UIImage(data: d) else { return nil }
        return i.preparingForDisplay() ?? i
    }

    static func sil(_ ad: String?) {
        guard let ad, !ad.isEmpty else { return }
        try? FileManager.default.removeItem(at: buyukUrl(ad))
        try? FileManager.default.removeItem(at: kucukUrl(ad))
    }

    /// Artık hiçbir kayıtta kullanılmayan görselleri temizler (açılışta bir kez).
    static func temizle(kullanilan: Set<String>) {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            guard let dosyalar = try? fm.contentsOfDirectory(atPath: klasor.path) else { return }
            for d in dosyalar {
                let temel = d.replacingOccurrences(of: "_k.jpg", with: "")
                              .replacingOccurrences(of: ".jpg", with: "")
                if !kullanilan.contains(temel) {
                    try? fm.removeItem(at: klasor.appendingPathComponent(d))
                }
            }
        }
    }

    static func tumunuSil() {
        let fm = FileManager.default
        try? fm.removeItem(at: klasor)
        try? fm.createDirectory(at: klasor, withIntermediateDirectories: true)
    }

    /// ImageIO ile tam çözümleme yapmadan ölçekler (bellek dostu).
    static func olcekle(_ veri: Data, maks: CGFloat) -> UIImage? {
        let kaynakSecenek = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let kaynak = CGImageSourceCreateWithData(veri as CFData, kaynakSecenek) else { return nil }
        let secenekler: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maks
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(kaynak, 0, secenekler as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Bellek içi görsel önbelleği

/// UIImage'i arka plan görevinden ana thread'e taşımak için basit sarmalayıcı.
nonisolated final class ResimKutusu: @unchecked Sendable {
    let gorsel: UIImage
    init(_ g: UIImage) { gorsel = g }
}

nonisolated final class ResimOnbellek: @unchecked Sendable {
    static let shared = ResimOnbellek()

    private let kucukler = NSCache<NSString, UIImage>()
    private let buyukler = NSCache<NSString, UIImage>()

    private init() {
        kucukler.countLimit = 300
        buyukler.countLimit = 12
    }

    func hazir(_ ad: String) -> UIImage? { kucukler.object(forKey: ad as NSString) }

    func kucuk(_ ad: String) async -> UIImage? {
        if let v = kucukler.object(forKey: ad as NSString) { return v }
        let kutu = await Task.detached(priority: .utility) {
            ResimDeposu.kucukGorsel(ad).map(ResimKutusu.init)
        }.value
        guard let img = kutu?.gorsel else { return nil }
        kucukler.setObject(img, forKey: ad as NSString)
        return img
    }

    func buyuk(_ ad: String) async -> UIImage? {
        if let v = buyukler.object(forKey: ad as NSString) { return v }
        let kutu = await Task.detached(priority: .userInitiated) {
            ResimDeposu.buyukGorsel(ad).map(ResimKutusu.init)
        }.value
        guard let img = kutu?.gorsel else { return nil }
        buyukler.setObject(img, forKey: ad as NSString)
        return img
    }

    func temizle() {
        kucukler.removeAllObjects()
        buyukler.removeAllObjects()
    }
}

// MARK: - Eski sürümden göç (UserDefaults -> dosya)

nonisolated extension Depolama {
    private static let gocAnahtari = "DosyaGocu_v3"

    struct GocSonucu {
        var kategoriler: [Kategori] = []
        var urunler: [Urun] = []
        var islemler: [Islem] = []
        var gocYapildi = false
    }

    /// Eski UserDefaults verisini bir kereye mahsus dosyalara taşır.
    func gocEtVarsa() -> GocSonucu {
        var sonuc = GocSonucu()
        let ud = UserDefaults.standard
        if ud.bool(forKey: Self.gocAnahtari) { return sonuc }

        // Yeni dosyalar zaten varsa göçe gerek yok.
        if fm.fileExists(atPath: url(Dosya.urunler).path) || fm.fileExists(atPath: url(Dosya.kategoriler).path) {
            ud.set(true, forKey: Self.gocAnahtari)
            return sonuc
        }

        yedekAl()

        // 1) v2 verisi
        if let d = ud.data(forKey: "KategoriAgaci_v2"),
           let eski = try? JSONDecoder().decode([EskiKategori].self, from: d) {
            sonuc.kategoriler = eski.map { Kategori(id: $0.id, isim: $0.isim, ustId: $0.ustId) }
        }
        if let d = ud.data(forKey: "UrunListesi_v2"),
           let eski = try? JSONDecoder().decode([EskiUrun].self, from: d) {
            for e in eski {
                var u = Urun(id: e.id, isim: e.isim, aciklama: e.aciklama,
                             alisFiyati: e.alisFiyati, satisFiyati: e.satisFiyati,
                             miktar: e.miktar, kategoriId: e.kategoriId)
                if let veri = e.resimData, !veri.isEmpty {
                    u.resimAdi = ResimDeposu.hamKaydet(veri, ad: e.id.uuidString)
                }
                sonuc.urunler.append(u)
            }
        }
        if let d = ud.data(forKey: "IslemListesi"),
           let eski = try? JSONDecoder().decode([Islem].self, from: d) {
            sonuc.islemler = eski
        }

        // 2) v2 hiç yoksa en eski (düz ilaç listesi) sürümü dene
        if sonuc.kategoriler.isEmpty && sonuc.urunler.isEmpty {
            enEskidenAl(&sonuc)
        }

        let yazildi = hemenYaz(sonuc.kategoriler, Dosya.kategoriler)
            && hemenYaz(sonuc.urunler, Dosya.urunler)
            && hemenYaz(sonuc.islemler, Dosya.islemler)

        if yazildi {
            ud.set(true, forKey: Self.gocAnahtari)
            // Büyük veriyi UserDefaults'tan çıkar (açılışı yavaşlatıyordu). Yedeği dosyada duruyor.
            for k in ["UrunListesi_v2", "KategoriAgaci_v2", "IslemListesi", "IlacListesi", "KategoriListesi"] {
                ud.removeObject(forKey: k)
            }
            sonuc.gocYapildi = true
        }
        return sonuc
    }

    private func enEskidenAl(_ sonuc: inout GocSonucu) {
        guard let data = UserDefaults.standard.data(forKey: "IlacListesi"),
              let eski = try? JSONDecoder().decode([EskiIlac].self, from: data) else { return }

        var katMap: [String: UUID] = [:]
        if let eskiKat = UserDefaults.standard.array(forKey: "KategoriListesi") as? [String] {
            for ad in eskiKat where katMap[ad] == nil {
                let k = Kategori(isim: ad)
                katMap[ad] = k.id
                sonuc.kategoriler.append(k)
            }
        }
        for e in eski {
            let ad = e.kategori.isEmpty ? "Genel" : e.kategori
            var kid = katMap[ad]
            if kid == nil {
                let k = Kategori(isim: ad)
                sonuc.kategoriler.append(k)
                katMap[ad] = k.id
                kid = k.id
            }
            var u = Urun(id: e.id, isim: e.isim, aciklama: e.aciklama,
                         alisFiyati: e.alisFiyati, satisFiyati: e.satisFiyati,
                         miktar: e.miktar, kategoriId: kid)
            if let veri = e.resimData, !veri.isEmpty {
                u.resimAdi = ResimDeposu.hamKaydet(veri, ad: e.id.uuidString)
            }
            sonuc.urunler.append(u)
        }
    }

    /// Göçten önce ham eski veriyi dosyaya yedekler.
    private func yedekAl() {
        let ud = UserDefaults.standard
        for k in ["UrunListesi_v2", "KategoriAgaci_v2", "IslemListesi", "IlacListesi"] {
            if let d = ud.data(forKey: k) {
                try? d.write(to: url("yedek_\(k).json"), options: .atomic)
            }
        }
    }
}
